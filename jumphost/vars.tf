// Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

variable "instance_type" {
  default = "t2.large"
}
variable "ami" {}
variable "key" {}
variable "sg" {
  type = "list"
}
variable "subnet" { }
variable "ProjectTag" { }
variable "Environment" { }
