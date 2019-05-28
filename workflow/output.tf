# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "LambdaFnName" {
  value = "${aws_lambda_function.lifecycle_fn.function_name}"
}
output "LambdaFnArn" {
  value = "${aws_lambda_function.lifecycle_fn.arn}"
}
output "LifecycleTopicArn" {
  value = "${aws_sns_topic.lifecycle_topic.arn}"
}
