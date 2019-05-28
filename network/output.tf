// Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

output "VpcId" {
  value = "${aws_vpc.VPC.id}"
}
output "SubnetIdPublicA" {
  value = "${aws_subnet.SubnetPublicA.id}"
}
output "SubnetIdPublicB" {
  value = "${aws_subnet.SubnetPublicB.id}"
}
output "SubnetIdPublicC" {
  value = "${aws_subnet.SubnetPublicC.id}"
}
output "SubnetIdPrivateA" {
  value = "${aws_subnet.SubnetPrivateA.id}"
}
output "SubnetIdPrivateB" {
  value = "${aws_subnet.SubnetPrivateB.id}"
}
output "SubnetIdPrivateC" {
  value = "${aws_subnet.SubnetPrivateC.id}"
}
output "ZoneID" {
  value = "${aws_route53_zone.mongozone.zone_id}"
}
