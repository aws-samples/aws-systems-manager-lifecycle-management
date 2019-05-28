// Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

data "aws_availability_zones" "available" {}

resource "aws_network_interface" "eip" {
  count = "${var.num_rs_members}"
  subnet_id = "${element(var.subnets, count.index % length(var.subnets))}"
  security_groups = ["${var.sg}"]
  tags {
    Name = "eip-rsmember-${count.index}"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }

}


resource "aws_ssm_parameter" "eip-ssm" {
  count = "${var.num_rs_members}"
  name  = "/${var.ProjectTag}/${var.Environment}/rsmember/eip/${count.index}"
  type  = "String"
  value = "${element(aws_network_interface.eip.*.private_ip, count.index)}"
  overwrite = "true"
  tags {
    Name = "ssm-eip-rsmember-${count.index}"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_ssm_parameter" "eipeni-ssm" {
  count = "${var.num_rs_members}"
  name  = "/${var.ProjectTag}/${var.Environment}/rsmember/eipeni/${count.index}"
  type  = "String"
  value = "${element(aws_network_interface.eip.*.id, count.index)}"
  overwrite = "true"
  tags {
    Name = "ssm-eipeni-rsmember-${count.index}"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_ebs_volume" "rs_data" {
  count = "${var.init_rs_members}"
  availability_zone = "${element(data.aws_availability_zones.available.names,count.index % length(var.subnets))}"
  encrypted = "true"
  size = "${var.data_vol_size}"
  iops = "${var.data_vol_iops}"
  type = "io1"

  tags {
    Name = "datavol-rsmember-${count.index}"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_ebs_volume" "rs_logs" {
  count = "${var.num_rs_members}"
  availability_zone = "${element(data.aws_availability_zones.available.names,count.index % length(var.subnets))}"
  encrypted = "true"
  size = "${var.logs_vol_size}"
  iops = "${var.logs_vol_iops}"
  type = "io1"

  tags {
    Name = "logsvol-rsmember-${count.index}"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_ssm_parameter" "rs_data-ssm" {
  count = "${var.init_rs_members}"
  name  = "/${var.ProjectTag}/${var.Environment}/rsmember/datavol/${count.index}"
  type  = "String"
  value = "${element(aws_ebs_volume.rs_data.*.id, count.index)}"
  overwrite = "true"
  tags {
    Name = "ssm-datavol-rsmember-${count.index}"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_ssm_parameter" "rs_logs-ssm" {
  count = "${var.num_rs_members}"
  name  = "/${var.ProjectTag}/${var.Environment}/rsmember/logsvol/${count.index}"
  type  = "String"
  value = "${element(aws_ebs_volume.rs_logs.*.id, count.index)}"
  overwrite = "true"
  tags {
    Name = "ssm-logsvol-rsmember-${count.index}"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_launch_configuration" "rs_lc" {
  name_prefix   = "rs"
  image_id      = "${var.ami}"
  instance_type = "${var.instance_type}"
  iam_instance_profile = "${var.iam_profile}"
  key_name = "${var.key}"
  security_groups = ["${var.sg}"]
  ebs_optimized = "true"
  root_block_device {
    volume_type = "io1"
    volume_size = "${var.root_vol_size}"
    iops = "${var.root_vol_iops}"
  }
}

resource "aws_route53_record" "rs_eip_records" {
  count = "${var.num_rs_members}"
  zone_id = "${var.zone}"
  name = "rs-${count.index}.${lower(var.Environment)}.${lower(var.ProjectTag)}.local"
  type    = "A"
  ttl     = "300"
  records = ["${element(aws_network_interface.eip.*.private_ip, count.index)}"]
}
resource "aws_ssm_parameter" "rs_eip_records-ssm" {
  count = "${var.num_rs_members}"
  name  = "/${var.ProjectTag}/${var.Environment}/rsmember/dns/${count.index}"
  type  = "String"
  value = "${element(aws_route53_record.rs_eip_records.*.fqdn, count.index)}"
  overwrite = "true"
  tags {
    Name = "ssm-dns-rsmember-${count.index}"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_autoscaling_group" "rs_asg" {
  count = "${var.num_rs_members}"
  name_prefix = "rsmember-asg-"
  max_size                  = 1
  min_size                  = 1
  launch_configuration      = "${aws_launch_configuration.rs_lc.name}"
  health_check_type = "EC2"
  desired_capacity   = 1
  vpc_zone_identifier = ["${element(var.subnets, count.index % length(var.subnets))}"]
  enabled_metrics = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"] 

  initial_lifecycle_hook = {
    name                   = "rs_instance_launch"
    heartbeat_timeout      = 600
    lifecycle_transition   = "autoscaling:EC2_INSTANCE_LAUNCHING"
    notification_target_arn = "${var.LifecycleTopicArn}"
    role_arn                = "${var.LifecycleRoleArn}"
    notification_metadata = <<EOF
{
  "role": "rsmember",
  "id": "${count.index}",
  "project": "${var.ProjectTag}",
  "environment": "${var.Environment}"
}
EOF
  }


  tag {
    key                 = "Project"
    value               = "${var.ProjectTag}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "${var.Environment}"
    propagate_at_launch = true
  }
  tag {
    key                 = "Name"
    value = "rsmember-${count.index}"
    propagate_at_launch = true
  }
}

resource "aws_dlm_lifecycle_policy" "mongo_snapshots" {
  description        = "DLM lifecycle policy for MongoDB"
  execution_role_arn = "${var.dlm_lifecycle_role_arn}"
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    schedule {
      name = "2 days of twice-daily snapshots"

      create_rule {
        interval      = 12
        interval_unit = "HOURS"
      }

      retain_rule {
        count = 4
      }

      tags_to_add {
        SnapshotCreator = "DLM"
      }

      copy_tags = true
    }

    target_tags {
      Project = "${var.ProjectTag}"
      Environment = "${var.Environment}"
    }
  }
}

resource "aws_ssm_maintenance_window" "patch_window" {
  name     = "mongo-maintenance-window"
  schedule = "cron(0 0 4 ? * * *)"
  duration = 3
  cutoff   = 1
}

resource "aws_ssm_maintenance_window_target" "patch_target" {
  window_id     = "${aws_ssm_maintenance_window.patch_window.id}"
  resource_type = "INSTANCE"

  targets {
      key    = "tag:Project"
      values = ["${var.ProjectTag}"]
  }
  targets {
    key    = "tag:Environment"
    values = ["${var.Environment}"]
  }
}
resource "aws_ssm_maintenance_window_task" "patch_task" {
  window_id        = "${aws_ssm_maintenance_window.patch_window.id}"
  name             = "mongo-maintenance-window-task"
  description      = "Patch MongoDB"
  task_type        = "RUN_COMMAND"
  task_arn         = "AWS-RunPatchBaseline"
  priority         = 1
  service_role_arn = "${var.mw_role_arn}"
  max_concurrency  = "1"
  max_errors       = "1"

  targets {
    key    = "WindowTargetIds"
    values = ["${aws_ssm_maintenance_window_target.patch_target.id}"]
  }

  task_parameters {
    name   = "Operation"
    values = ["Install"]
  }

  logging_info {
    s3_bucket_name = "${aws_s3_bucket.logbucket.id}"
    s3_region = "${aws_s3_bucket.logbucket.region}" 
    s3_bucket_prefix = "ssm_patch_logs/"
  }
}
resource "aws_s3_bucket" "logbucket" {
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
    Name = "mongo-logs-bucket"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
