// Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

output "JumpHostIP" {
  value = "${aws_instance.jumphost.public_ip}"
}
