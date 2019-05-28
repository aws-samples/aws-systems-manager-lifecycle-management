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
      "initstatus": 0,
      "addstatus": 0,
      "project": project,
      "environment": environment,
      "role": role

}

"""
def handler(event, context):

    try:
        LOGGER.info("SFN metadata: {0} (type = {1})".format(json.dumps(event), type(event)))
        instanceids = event['nodes']['id']
        missing_nodes = event['rsstatus']['missing_nodes']
        iid = instanceids[0]

        LOGGER.info("missing-nodes: %s" % missing_nodes)

        # rs.add( { host: "mongodb3.example.net:27017", priority: 0, votes: 0 } )
        for m in missing_nodes:
            LOGGER.info("Adding node {0} to RS".format(m))
            add_rs_cmd = 'rs.add( { host: "' + m + ':27017", priority: 0, votes: 0 } )'
            LOGGER.info("add RS command: %s" % add_rs_cmd)

            LOGGER.info("Starting doc execution") 
            response = ssm.send_command(
                InstanceIds = [iid],
                DocumentName = docname,
                TimeoutSeconds = 30,
                Parameters = {
                    'commands': ["mongo --eval '{0}'".format(add_rs_cmd)]
                },
            )
            command_id = response['Command']['CommandId']
            LOGGER.info("Doc command id: {0}".format(command_id))

            # We need to wait a minute to let the command invocation show up
            time.sleep(5)

            while True:
                LOGGER.info("Checking command status for node {0}".format(iid))
                response = ssm.get_command_invocation( CommandId=command_id, InstanceId = iid)
                status = response['Status']
                if status == 'Failed':
                    LOGGER.warn("RS {0} add error: {1}".format(iid, response['StatusDetails']))
                    break
                if status == 'TimedOut':
                    LOGGER.warn("RS {0} add error: {1}".format(iid, response['StatusDetails']))
                    break
                if status == 'Success':
                    stdout_content = response['StandardOutputContent']
                    if '"ok" : 1' in stdout_content:
                        LOGGER.info("RS add ok: {0}".format(iid))
                    else:
                        LOGGER.warn("RS failed add : {0} - {1}".format(iid, stdout_content))
                    break
                time.sleep(5)

        return 1 
    except Exception as e:
        trc = traceback.format_exc()
        LOGGER.error("Failed adding node to RS {0}: {1}\n\n{2}".format(json.dumps(event), str(e), trc))
        return 0

