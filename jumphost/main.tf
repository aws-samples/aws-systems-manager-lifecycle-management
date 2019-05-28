// Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

resource "aws_instance" "jumphost" {
  ami           = "${var.ami}"
  instance_type = "${var.instance_type}"
  key_name = "${var.key}"
  vpc_security_group_ids = ["${var.sg}"]
  subnet_id = "${var.subnet}"

  tags {
    Name = "jumphost"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
