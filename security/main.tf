# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

resource "aws_security_group" "bastion_access" {
  name_prefix        = "bastion_access"
  description = "Allow SSH inbound traffic to bastion host"
  vpc_id      = "${var.vpc}"

  ingress {
    from_port   = 22 
    to_port     = 22 
    protocol    = "tcp"
    prefix_list_ids = ["${var.ingress_prefix}"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags {
    Name = "bastion_access"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_security_group" "mongo_private" {
  name_prefix        = "mongo_private"
  description = "Allow all intra-Mongo traffic plus client and bastion access"
  vpc_id      = "${var.vpc}"

  ingress {
    from_port   = 22 
    to_port     = 22 
    protocol    = "tcp"
    security_groups = ["${aws_security_group.bastion_access.id}"]
  }
  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    security_groups = ["${aws_security_group.mongo_client.id}"]
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self = true
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags {
    Name = "mongo_private"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_security_group" "mongo_client" {
  name_prefix        = "mongo_client"
  description = "Allow client access to Mongo"
  vpc_id      = "${var.vpc}"

  ingress {
    from_port   = 22 
    to_port     = 22 
    protocol    = "tcp"
    security_groups = ["${aws_security_group.bastion_access.id}"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags {
    Name = "mongo_client"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_iam_instance_profile" "mongo_profile" {
  name_prefix = "mongo_profile"
  role = "${aws_iam_role.mongo_ec2_role.name}"
}

resource "aws_iam_role" "mongo_ec2_role" {
  name_prefix = "mongo_ec2_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
  tags {
    Name = "mongo_ec2_role"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_iam_role_policy_attachment" "mongo_ec2_role_ssm_policy" {
  role       = "${aws_iam_role.mongo_ec2_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}
resource "aws_iam_role_policy_attachment" "mongo_ec2_role_s3_policy" {
  role       = "${aws_iam_role.mongo_ec2_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}
resource "aws_iam_role_policy_attachment" "mongo_ec2_role_cw_policy" {
  role       = "${aws_iam_role.mongo_ec2_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
resource "aws_iam_role_policy_attachment" "mongo_ec2_role_cwagent_policy" {
  role       = "${aws_iam_role.mongo_ec2_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentAdminPolicy"
}

resource "aws_iam_role_policy" "mongo_ec2_access" {
  name_prefix = "mongo_ec2_access"
  role = "${aws_iam_role.mongo_ec2_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ssm:Get*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "ec2:AssociateAddress"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "ec2:AttachVolume"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "ec2:CreateSnapshot"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "ec2:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "lambda_role" {
  name_prefix = "lambda_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "lambda.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
  tags {
    Name = "lambda_role"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_iam_role_policy_attachment" "lambda-basicpolicy-attach" {
  role       = "${aws_iam_role.lambda_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_ssm_access" {
  name_prefix = "lambda_ssm_access"
  role = "${aws_iam_role.lambda_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ssm:Get*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "ssm:StartAutomationExecution"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "ssm:SendCommand"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "ssm:PutParameter"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_sqs_access" {
  name_prefix = "lambda_sqs_access"
  role = "${aws_iam_role.lambda_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sqs:ReceiveMessage"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "sqs:GetQueueAttributes"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "sqs:DeleteMessage"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_sfn_access" {
  name_prefix = "lambda_sfn_access"
  role = "${aws_iam_role.lambda_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "states:StartExecution"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "states:ListExecutions"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_asg_access" {
  name_prefix = "lambda_asg_access"
  role = "${aws_iam_role.lambda_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "autoscaling:CompleteLifecycleAction*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "ec2:CreateVolume"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "ec2:CreateTags"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "ec2:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "autoscaling_notify_role" {
  name_prefix = "autoscaling_notify_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "autoscaling.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
  tags {
    Name = "autoscaling_notify_role"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_iam_role_policy_attachment" "autoscale-basicpolicy-attach" {
  role       = "${aws_iam_role.autoscaling_notify_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AutoScalingNotificationAccessRole"
}

resource "aws_iam_role" "ssm_automation_role" {
  name_prefix = "ssm_automation_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ssm.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
  tags {
    Name = "ssm_automation_role"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_iam_role_policy" "ssm_ec2_access" {
  name_prefix = "ssm_ec2_access"
  role = "${aws_iam_role.ssm_automation_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:AssociateAddress"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "ec2:AttachVolume"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "ec2:AttachNetworkInterface"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "ec2:CreateSnapshot"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "ssm:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "ssm:List*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "ssm:SendCommand"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "sqs:SendMessage"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "ec2:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "sfn_role" {
  name_prefix = "sfn_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "states.${var.Region}.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
  tags {
    Name = "sfn_role"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_iam_role_policy" "sfn_lambda" {
  name_prefix = "sfn_lambda_access"
  role = "${aws_iam_role.sfn_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "lambda:InvokeFunction"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "dlm_role" {
  name_prefix = "dlm_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "dlm.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
  tags {
    Name = "dlm_role"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_iam_role_policy" "dlm_access" {
  name_prefix = "dlm_access"
  role = "${aws_iam_role.dlm_role.id}"

  policy = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Effect": "Allow",
         "Action": [
            "ec2:CreateSnapshot",
            "ec2:DeleteSnapshot",
            "ec2:DescribeVolumes",
            "ec2:DescribeSnapshots"
         ],
         "Resource": "*"
      },
      {
         "Effect": "Allow",
         "Action": [
            "ec2:CreateTags"
         ],
         "Resource": "arn:aws:ec2:*::snapshot/*"
      }
   ]
}
EOF
}

resource "aws_iam_role" "mw_role" {
  name_prefix = "mw_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": [ "ssm.amazonaws.com", "sns.amazonaws.com" ]
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
  tags {
    Name = "mw_role"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_iam_role_policy_attachment" "mw_policy" {
  role       = "${aws_iam_role.mw_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMMaintenanceWindowRole"
}
