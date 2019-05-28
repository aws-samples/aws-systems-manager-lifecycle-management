# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

resource "aws_lambda_function" "lifecycle_fn" {
  filename         = "workflow/lifecycle_fn.zip"
  function_name    = "${var.ProjectTag}_${var.Environment}_lifecycle_fn"
  role             = "${var.LambdaRoleArn}"
  handler          = "index.handler"
  source_code_hash = "${base64sha256(file("workflow/lifecycle_fn.zip"))}"
  runtime          = "python3.7"
  memory_size = "1024"
  timeout = "300"

  tags {
    Name = "lifecycle_fn"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }

  environment {
    variables = {
      DOCNAME = "${aws_ssm_document.init_rs_server.name}",
      QUEUEURL = "${aws_sqs_queue.workflow_queue.id}",
      PIOPS = "${var.data_vol_iops}"
    }
  }
}

resource "aws_sns_topic" "lifecycle_topic" {
  name_prefix = "lifecycle-topic-"
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id_prefix  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lifecycle_fn.function_name}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${aws_sns_topic.lifecycle_topic.arn}"
}

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = "${aws_sns_topic.lifecycle_topic.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.lifecycle_fn.arn}"
}

data "template_file" "ssm_doc_init" {
  template = "${file("${path.module}/ssm_doc_init.tpl")}"

  vars {
    SSMRoleArn = "${var.SSMRoleArn}"
    PlaybookUrl = "s3://${var.BucketName}/init.yaml"
  }
}

data "template_file" "ansible_rs_init" {
  template = "${file("${path.module}/ansible_rs_init.tpl")}"
}

resource "aws_ssm_document" "init_rs_server" {
  name          = "init_rs_server"
  document_type = "Automation"
  document_format = "YAML"
  tags {
    Name = "init_rs_server_ssm_doc"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }

  content = "${data.template_file.ssm_doc_init.rendered}"
}

resource "aws_s3_bucket" "templatebucket" {
  bucket = "${var.BucketName}"
  acl    = "private"
  versioning {
    enabled = true
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "AES256"
      }
    }
  }
  tags = {
    Name = "mongo-template-bucket"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_s3_bucket_object" "ansible_rs_init_obj" {
  key                    = "init.yaml"
  bucket                 = "${aws_s3_bucket.templatebucket.id}"
  content = "${data.template_file.ansible_rs_init.rendered}"
}

resource "aws_sqs_queue" "workflow_queue" {
  name_prefix = "lifecycle-queue-"
  fifo_queue                  = false
  visibility_timeout_seconds = 60
  tags = {
    Name = "lifecycle-queue"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_lambda_function" "workflow_fn" {
  filename         = "workflow/workflow_fn.zip"
  function_name    = "${var.ProjectTag}_${var.Environment}_workflow_fn"
  role             = "${var.LambdaRoleArn}"
  handler          = "index-workflow.handler"
  source_code_hash = "${base64sha256(file("workflow/workflow_fn.zip"))}"
  runtime          = "python3.7"
  memory_size = "1024"
  timeout = "10"
  reserved_concurrent_executions = "1"

  environment {
    variables = {
      SFN_ARN = "${aws_sfn_state_machine.sfn_workflow_rs.id}"
    }
  }

  tags {
    Name = "workflow_fn"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }

}

resource "aws_lambda_event_source_mapping" "workflow-sqs" {
  event_source_arn = "${aws_sqs_queue.workflow_queue.arn}"
  function_name    = "${aws_lambda_function.workflow_fn.arn}"
  batch_size = "1"
}

resource "aws_sfn_state_machine" "sfn_workflow_rs" {
  name     = "sfn_workflow_rs"
  role_arn = "${var.SfnRoleArn}"

  definition = <<EOF
{
  "Comment": "This workflow makes sure that the replica set is initialized.",
  "StartAt": "CheckNodeStatus",
  "States": {
    "CheckNodeStatus": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.check_node_status_fn.arn}",
      "Next": "EvaluateNodeStatus",
      "InputPath": "$.nodes.id",
      "OutputPath": "$",
      "ResultPath": "$.nodes.status"
    },
    "EvaluateNodeStatus": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.nodes.status",
          "NumericEquals": 1,
          "Next": "CheckReplicaSetStatus"
        }
      ],
      "Default": "StopNodesNotReady"
    },
    "StopNodesNotReady": {
      "Type": "Succeed"
    },
    "CheckReplicaSetStatus": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.check_rs_status_fn.arn}",
      "Next": "EvaluateRsStatus",
      "OutputPath": "$",
      "ResultPath": "$.rsstatus"
    },
    "EvaluateRsStatus": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.rsstatus.code",
          "NumericEquals": 1,
          "Next": "InitRs"
        },
        {
          "Variable": "$.rsstatus.code",
          "NumericEquals": 2,
          "Next": "AddNodeToRs"
        }
      ],
      "Default": "StopNothingToDo"
    },
    "InitRs": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.init_rs_fn.arn}",
      "Next": "EvaluateRsInitStatus",
      "ResultPath": "$.initstatus",
      "OutputPath": "$"
    },
    "EvaluateRsInitStatus": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.initstatus",
          "NumericEquals": 1,
          "Next": "InitOk"
        }
      ],
      "Default": "StopFailed"
    },
    "AddNodeToRs": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.add_node_rs_fn.arn}",
      "Next": "EvaluateRsAddStatus",
      "ResultPath": "$.addstatus",
      "OutputPath": "$"
    },
    "EvaluateRsAddStatus": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.addstatus",
          "NumericEquals": 1,
          "Next": "AddOk"
        }
      ],
      "Default": "StopFailed"
    },
    "InitOk": {
      "Type": "Succeed"
    },
    "AddOk": {
      "Type": "Succeed"
    },
    "StopNothingToDo": {
      "Type": "Succeed"
    },
    "StopFailed": {
      "Type": "Fail"
    }
  }
}
EOF
}

resource "aws_lambda_function" "check_node_status_fn" {
  filename         = "workflow/check_node_status_fn.zip"
  function_name    = "${var.ProjectTag}_${var.Environment}_check_node_status_fn"
  role             = "${var.LambdaRoleArn}"
  handler          = "check_node_status_fn.handler"
  source_code_hash = "${base64sha256(file("workflow/check_node_status_fn.zip"))}"
  runtime          = "python3.7"
  memory_size = "1024"
  timeout = "60"

  tags {
    Name = "check_node_status_fn"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }

}

resource "aws_lambda_function" "check_rs_status_fn" {
  filename         = "workflow/check_rs_status_fn.zip"
  function_name    = "${var.ProjectTag}_${var.Environment}_check_rs_status_fn"
  role             = "${var.LambdaRoleArn}"
  handler          = "check_rs_status_fn.handler"
  source_code_hash = "${base64sha256(file("workflow/check_rs_status_fn.zip"))}"
  runtime          = "python3.7"
  memory_size = "1024"
  timeout = "60"

  tags {
    Name = "check_rs_status_fn"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }

}

resource "aws_lambda_function" "init_rs_fn" {
  filename         = "workflow/init_rs_fn.zip"
  function_name    = "${var.ProjectTag}_${var.Environment}_init_rs_fn"
  role             = "${var.LambdaRoleArn}"
  handler          = "init_rs_fn.handler"
  source_code_hash = "${base64sha256(file("workflow/init_rs_fn.zip"))}"
  runtime          = "python3.7"
  memory_size = "1024"
  timeout = "60"

  tags {
    Name = "init_rs_fn"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }

}

resource "aws_lambda_function" "add_node_rs_fn" {
  filename         = "workflow/add_node_rs_fn.zip"
  function_name    = "${var.ProjectTag}_${var.Environment}_add_node_rs_fn"
  role             = "${var.LambdaRoleArn}"
  handler          = "add_node_rs_fn.handler"
  source_code_hash = "${base64sha256(file("workflow/add_node_rs_fn.zip"))}"
  runtime          = "python3.7"
  memory_size = "1024"
  timeout = "60"

  tags {
    Name = "add_node_rs_fn"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }

}


