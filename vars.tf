# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "region" {
  default = "us-west-2"
}
variable "ProjectTag" {
  default = "MongoDB"
}
variable "Environment" {
  default = "Test"
}
variable "BucketName" { }
variable "LogBucketName" { }
variable "amis" {
  type = "map"
  default = {
    "us-east-1" = "ami-0080e4c5bc078760e"
    "us-west-2" = "ami-01e24be29428c15b2"
  }
}

variable "ingress_prefix" {}
variable "sshkey" {}
variable "rs_instance_type" {
  default = "r4.2xlarge"
}
variable "data_vol_iops" {
  default = "1000"
}
variable "num_rs_members" {
  default = "3"
}
