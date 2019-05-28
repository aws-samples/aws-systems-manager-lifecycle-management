# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

import boto3
import json
import logging
import traceback
import os
import time

# Create AWS clients
ssm = boto3.client('ssm')

# Constants
LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)

# Env variables
docname = 'AWS-RunShellScript'

"""
Event should be a JSON document:

{ 
    "nodes": {
        "id": [
            instance id,
            instance id
        ],
        "dns": [
            dns name,
            dns name
        ],
        "status": 0
      },
      "rsstatus": {
          "code": 0,
          missing_nodes: [
              m1,
              m2
          ]
      },
      "project": project,
      "environment": environment,
      "role": role

}

"""
def handler(event, context):

    try:
        LOGGER.info("SFN metadata: {0} (type = {1})".format(json.dumps(event), type(event)))
        instanceids = event['nodes']['id']
        dnsnames = event['nodes']['dns']
        project = event['project']
        environment = event['environment']
        role = event['role']
        iid = instanceids[0]

        LOGGER.info("instance-id: %s" % instanceids)

        replSetName = "{0}_{1}_{2}".format(project, environment, role)
        init_rs_cmd = 'rs.initiate( { _id: "' + replSetName + '", members: ['
        for idx in range(len(dnsnames)):
            init_rs_cmd += ' { _id : ' + str(idx) + ', host : "' + dnsnames[idx] + ':27017" },'
        init_rs_cmd = init_rs_cmd[:-1]
        init_rs_cmd += ' ] })'
        LOGGER.info("init RS command: %s" % init_rs_cmd)

        LOGGER.info("Starting doc execution") 
        response = ssm.send_command(
            InstanceIds = [iid],
            DocumentName = docname,
            TimeoutSeconds = 30,
            Parameters = {
                'commands': ["mongo --eval '{0}'".format(init_rs_cmd)]
            },
        )
        command_id = response['Command']['CommandId']
        LOGGER.info("Doc command id: {0}".format(command_id))

        # We need to wait a minute to let the command invocation show up
        time.sleep(5)

        overall_status = 1 # not initialized
        while True:
            LOGGER.info("Checking command status for node {0}".format(iid))
            response = ssm.get_command_invocation( CommandId=command_id, InstanceId = iid)
            status = response['Status']
            if status == 'Failed':
                LOGGER.info("RS {0} init error: {1}".format(iid, response['StatusDetails']))
                overall_status = 0
                break
            if status == 'TimedOut':
                LOGGER.info("RS {0} init error: {1}".format(iid, response['StatusDetails']))
                overall_status = 0
                break
            if status == 'Success':
                stdout_content = response['StandardOutputContent']
                if '"ok" : 1' in stdout_content:
                    LOGGER.info("RS init ok: {0}".format(iid))
                else:
                    LOGGER.info("RS failed init: {0} - {1}".format(iid, stdout_content))
                    overall_status = 0
                break
            time.sleep(5)

        if overall_status == 1:
            LOGGER.info("RS init ok")
        else:
            LOGGER.info("RS failed init")
        return overall_status
    except Exception as e:
        trc = traceback.format_exc()
        LOGGER.error("Failed checking RS status {0}: {1}\n\n{2}".format(json.dumps(event), str(e), trc))
        return 0

