// Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

data "aws_availability_zones" "available" {}

resource "aws_vpc" "VPC" {
  cidr_block       = "${var.vpccidr}"
  enable_dns_support = "true"
  enable_dns_hostnames = "true"

  tags {
    Name = "VPC"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_internet_gateway" "IGW" {
  vpc_id = "${aws_vpc.VPC.id}"

  tags {
    Name = "IGW"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_route53_zone" "mongozone" {
  name = "${lower(var.Environment)}.${lower(var.ProjectTag)}.local"

  vpc {
    vpc_id     = "${aws_vpc.VPC.id}"
  }
  tags {
    Name = "PrivateZone"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}


resource "aws_subnet" "SubnetPublicA" {
  vpc_id     = "${aws_vpc.VPC.id}"
  cidr_block = "${var.AppPublicCIDRA}"
  map_public_ip_on_launch = "true"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "SubnetPublicA"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_subnet" "SubnetPublicB" {
  vpc_id     = "${aws_vpc.VPC.id}"
  cidr_block = "${var.AppPublicCIDRB}"
  map_public_ip_on_launch = "true"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "SubnetPublicB"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_subnet" "SubnetPublicC" {
  vpc_id     = "${aws_vpc.VPC.id}"
  cidr_block = "${var.AppPublicCIDRC}"
  map_public_ip_on_launch = "true"
  availability_zone = "${data.aws_availability_zones.available.names[2]}"

  tags {
    Name = "SubnetPublicC"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_subnet" "SubnetPrivateA" {
  vpc_id     = "${aws_vpc.VPC.id}"
  cidr_block = "${var.AppPrivateCIDRA}"
  map_public_ip_on_launch = "false"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "SubnetPrivateA"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_subnet" "SubnetPrivateB" {
  vpc_id     = "${aws_vpc.VPC.id}"
  cidr_block = "${var.AppPrivateCIDRB}"
  map_public_ip_on_launch = "false"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "SubnetPrivateB"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_subnet" "SubnetPrivateC" {
  vpc_id     = "${aws_vpc.VPC.id}"
  cidr_block = "${var.AppPrivateCIDRC}"
  map_public_ip_on_launch = "false"
  availability_zone = "${data.aws_availability_zones.available.names[2]}"

  tags {
    Name = "SubnetPrivateC"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_route_table" "RouteTablePublic" {
  vpc_id = "${aws_vpc.VPC.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.IGW.id}"
  }

  tags {
    Name = "PublicRT"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_route_table" "RouteTablePrivateA" {
  vpc_id = "${aws_vpc.VPC.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.NatGatewayA.id}"
  }

  tags {
    Name = "PrivateRTA"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_route_table" "RouteTablePrivateB" {
  vpc_id = "${aws_vpc.VPC.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.NatGatewayB.id}"
  }

  tags {
    Name = "PrivateRTB"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_route_table" "RouteTablePrivateC" {
  vpc_id = "${aws_vpc.VPC.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.NatGatewayC.id}"
  }

  tags {
    Name = "PrivateRTC"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_route_table_association" "SubnetRouteTableAssociatePublicA" {
  subnet_id      = "${aws_subnet.SubnetPublicA.id}"
  route_table_id = "${aws_route_table.RouteTablePublic.id}"
}
resource "aws_route_table_association" "SubnetRouteTableAssociatePublicB" {
  subnet_id      = "${aws_subnet.SubnetPublicB.id}"
  route_table_id = "${aws_route_table.RouteTablePublic.id}"
}
resource "aws_route_table_association" "SubnetRouteTableAssociatePublicC" {
  subnet_id      = "${aws_subnet.SubnetPublicC.id}"
  route_table_id = "${aws_route_table.RouteTablePublic.id}"
}
resource "aws_route_table_association" "SubnetRouteTableAssociatePrivateA" {
  subnet_id      = "${aws_subnet.SubnetPrivateA.id}"
  route_table_id = "${aws_route_table.RouteTablePrivateA.id}"
}
resource "aws_route_table_association" "SubnetRouteTableAssociatePrivateB" {
  subnet_id      = "${aws_subnet.SubnetPrivateB.id}"
  route_table_id = "${aws_route_table.RouteTablePrivateB.id}"
}
resource "aws_route_table_association" "SubnetRouteTableAssociatePrivateC" {
  subnet_id      = "${aws_subnet.SubnetPrivateC.id}"
  route_table_id = "${aws_route_table.RouteTablePrivateC.id}"
}

resource "aws_nat_gateway" "NatGatewayA" {
  allocation_id = "${aws_eip.EIPNatGWA.id}"
  subnet_id     = "${aws_subnet.SubnetPublicA.id}"
  tags {
    Name = "NatGWA"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_nat_gateway" "NatGatewayB" {
  allocation_id = "${aws_eip.EIPNatGWB.id}"
  subnet_id     = "${aws_subnet.SubnetPublicB.id}"
  tags {
    Name = "NatGWB"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_nat_gateway" "NatGatewayC" {
  allocation_id = "${aws_eip.EIPNatGWC.id}"
  subnet_id     = "${aws_subnet.SubnetPublicC.id}"
  tags {
    Name = "NatGWC"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_eip" "EIPNatGWA" {
  vpc      = true
  tags {
    Name = "EIPNatGWA"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_eip" "EIPNatGWB" {
  vpc      = true
  tags {
    Name = "EIPNatGWB"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_eip" "EIPNatGWC" {
  vpc      = true
  tags {
    Name = "EIPNatGWC"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
