// Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

provider "aws" {
  region     = "${var.region}"
}

module "network" {
  source = "./network"

  ProjectTag =  "${var.ProjectTag}"
  Environment =  "${var.Environment}"
}

module "security" {
  source = "./security"

  ProjectTag =  "${var.ProjectTag}"
  Environment =  "${var.Environment}"
  vpc =  "${module.network.VpcId}"
  ingress_prefix =  "${var.ingress_prefix}"
  Region = "${var.region}"
}
 module "nodes" {
    source = "./nodes"
    ProjectTag =  "${var.ProjectTag}"
    Environment =  "${var.Environment}"

    ami = "${lookup(var.amis, var.region)}"
    key = "${var.sshkey}"
    iam_profile =  "${module.security.IamProfileName}"
    sg = ["${module.security.mongo_private_id}"]
    zone = "${module.network.ZoneID}"
    LambdaFnName = "${module.workflow.LambdaFnName}"
    LambdaFnArn = "${module.workflow.LambdaFnArn}"
    LifecycleTopicArn = "${module.workflow.LifecycleTopicArn}"
    LifecycleRoleArn = "${module.security.ASGRoleArn}"
    dlm_lifecycle_role_arn = "${module.security.DlmRoleArn}"
    mw_role_arn = "${module.security.MwRoleArn}"
    BucketName =  "${var.LogBucketName}"
    instance_type = "${var.rs_instance_type}"
    subnets = ["${module.network.SubnetIdPrivateA}","${module.network.SubnetIdPrivateB}","${module.network.SubnetIdPrivateC}"]
    data_vol_iops = "${var.data_vol_iops}"
    num_rs_members = "${var.num_rs_members}"

 }
module "workflow" {
  source = "./workflow"

  ProjectTag =  "${var.ProjectTag}"
  Environment =  "${var.Environment}"
  BucketName =  "${var.BucketName}"
  LambdaRoleArn = "${module.security.LambdaRoleArn}"
  SfnRoleArn = "${module.security.SfnRoleArn}"
  SSMRoleArn = "${module.security.SSMRoleArn}"
  data_vol_iops = "${var.data_vol_iops}"
}
module "jumphost" {
  source = "./jumphost"
  ProjectTag =  "${var.ProjectTag}"
  Environment =  "${var.Environment}"
  sg = ["${module.security.bastion_access_id}","${module.security.mongo_client_id}"]
  key = "${var.sshkey}"
  ami = "${lookup(var.amis, var.region)}"
  subnet = "${module.network.SubnetIdPublicA}"

}
