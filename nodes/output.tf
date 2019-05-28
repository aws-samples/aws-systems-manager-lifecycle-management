// Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

output "EIPs" {
  value = "${aws_network_interface.eip.*.private_ip}"
}
