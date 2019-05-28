// Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

variable "num_rs_members" {
  default = "3"
}
variable "init_rs_members" {
  default = "3"
}
variable "ProjectTag" { }
variable "Environment" { }
variable "root_vol_iops" {
  default = "1000"
}
variable "root_vol_size" {
  default = "100"
}
variable "data_vol_iops" {
  default = "1000"
}
variable "data_vol_size" {
  default = "100"
}
variable "logs_vol_iops" {
  default = "500"
}
variable "logs_vol_size" {
  default = "50"
}
variable "ami" {}
variable "key" {}
variable "sg" {
  type = "list"
}
variable "subnets" {
  type = "list"
}
variable "iam_profile" {}
variable "zone" {}
variable "LambdaFnName" {}
variable "LambdaFnArn" {}
variable "LifecycleTopicArn" {}
variable "LifecycleRoleArn" {}
variable "dlm_lifecycle_role_arn" {}
variable "mw_role_arn" {}
variable "BucketName" {}
variable "instance_type" {
  default = "r4.2xlarge"
}
