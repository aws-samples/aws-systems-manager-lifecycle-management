# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "IamProfileName" {
  value = "${aws_iam_instance_profile.mongo_profile.name}"
}
output "LambdaRoleArn" {
  value = "${aws_iam_role.lambda_role.arn}"
}
output "SfnRoleArn" {
  value = "${aws_iam_role.sfn_role.arn}"
}
output "DlmRoleArn" {
  value = "${aws_iam_role.dlm_role.arn}"
}
output "MwRoleArn" {
  value = "${aws_iam_role.mw_role.arn}"
}
output "ASGRoleArn" {
  value = "${aws_iam_role.autoscaling_notify_role.arn}"
}
output "SSMRoleArn" {
  value = "${aws_iam_role.ssm_automation_role.arn}"
}
output "bastion_access_id" {
  value = "${aws_security_group.bastion_access.id}"
}
output "mongo_private_id" {
  value = "${aws_security_group.mongo_private.id}"
}
output "mongo_client_id" {
  value = "${aws_security_group.mongo_client.id}"
}
