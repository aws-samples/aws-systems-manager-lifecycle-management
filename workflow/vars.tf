# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "ProjectTag" { }
variable "Environment" { }
variable "LambdaRoleArn" { }
variable "SfnRoleArn" { }
variable "SSMRoleArn" { }
variable "BucketName" { }
variable "data_vol_iops" {
  default = "1000"
}
