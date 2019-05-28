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
        iid = instanceids[0]

        LOGGER.info("instance-id: %s" % instanceids)

        LOGGER.info("Starting doc execution") 
        response = ssm.send_command(
            InstanceIds = [iid],
            DocumentName = docname,
            TimeoutSeconds = 30,
            Parameters = {
                'commands': ['mongo --eval "rs.status()"']
            },
        )
        command_id = response['Command']['CommandId']
        LOGGER.info("Doc command id: {0}".format(command_id))

        # We need to wait a minute to let the command invocation show up
        time.sleep(5)

        # Status codes: 1 = not initialized, 2 = need to add nodes, 0 = other/nothing to do
        overall_status = 1 # not initialized
        missing_nodes = []
        while True:
            LOGGER.info("Checking command status for node {0}".format(iid))
            response = ssm.get_command_invocation( CommandId=command_id, InstanceId = iid)
            status = response['Status']
            if status == 'Failed':
                LOGGER.info("RS {0} check error: {1}".format(iid, response['StatusDetails']))
                overall_status = 0
                break
            if status == 'TimedOut':
                LOGGER.info("RS {0} check error: {1}".format(iid, response['StatusDetails']))
                overall_status = 0
                break
            if status == 'Success':
                stdout_content = response['StandardOutputContent']
                for dnsname in dnsnames:
                    if dnsname not in stdout_content:
                        missing_nodes.append(dnsname)
                if "NotYetInitialized" in stdout_content:
                    LOGGER.info("RS ready for init: {0}".format(iid))
                    overall_status = 1
                elif len(missing_nodes) > 0:
                    LOGGER.info("RS needs new nodes: {0} - {1}".format(iid, missing_nodes))
                    overall_status = 2
                else:
                    LOGGER.info("RS not ready for init: {0} - {1}".format(iid, stdout_content))
                    overall_status = 0
                break
            time.sleep(5)

        if overall_status == 1:
            LOGGER.info("RS ready for init")
        elif overall_status == 2:
            LOGGER.info("RS missing nodes")
        else:
            LOGGER.info("RS not ready for init")
        return {'code': overall_status, 'missing_nodes': missing_nodes }
    except Exception as e:
        trc = traceback.format_exc()
        LOGGER.error("Failed checking RS status {0}: {1}\n\n{2}".format(json.dumps(event), str(e), trc))
        return {'code': 0, 'missing_nodes': []}

