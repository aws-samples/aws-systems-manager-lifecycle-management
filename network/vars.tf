// Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

variable "vpccidr" {
  default = "10.20.0.0/16"
}
variable "ProjectTag" {
}
variable "AppPublicCIDRA" {
  default = "10.20.1.0/24"
}
variable "AppPublicCIDRB" {
  default = "10.20.2.0/24"
}
variable "AppPublicCIDRC" {
  default = "10.20.3.0/24"
}
variable "AppPrivateCIDRA" {
  default = "10.20.4.0/24"
}
variable "AppPrivateCIDRB" {
  default = "10.20.5.0/24"
}
variable "AppPrivateCIDRC" {
  default = "10.20.6.0/24"
}
variable "Environment" {
}
