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
    nodes: {
        id: [
            instance id,
            instance id
        ]
    }
}

We'll only receive the instance ID list.
"""
def handler(event, context):

    try:
        LOGGER.info("SFN metadata: {0} (type = {1})".format(json.dumps(event), type(event)))
        instanceids = event

        LOGGER.info("instance-id: %s" % instanceids)

        LOGGER.info("Starting doc execution") 
        response = ssm.send_command(
            InstanceIds = instanceids,
            DocumentName = docname,
            TimeoutSeconds = 30,
            Parameters = {
                'commands': ['ps -q `cat /var/run/mongodb/mongod.pid`']
            },
        )
        command_id = response['Command']['CommandId']
        LOGGER.info("Doc command id: {0}".format(command_id))

        # We need to wait a minute to let the command invocation show up
        time.sleep(5)

        overall_status = 1 # success
        for iid in instanceids:
            while True:
                LOGGER.info("Checking command status for node {0}".format(iid))
                response = ssm.get_command_invocation( CommandId=command_id, InstanceId = iid)
                status = response['Status']
                if status == 'Failed':
                    LOGGER.info("Node {0} not ready: {1}".format(iid, response['StatusDetails']))
                    overall_status = 0
                    break
                if status == 'TimedOut':
                    LOGGER.info("Node {0} not ready: {1}".format(iid, response['StatusDetails']))
                    overall_status = 0
                    break
                if status == 'Success':
                    stdout_content = response['StandardOutputContent']
                    if "mongod" in stdout_content:
                        LOGGER.info("Node ready (mongod running): {0}".format(iid))
                    else:
                        LOGGER.info("Node not ready (mongod not running): {0} - {1}".format(iid, stdout_content))
                        overall_status = 0
                    break
                time.sleep(5)

        if overall_status == 1:
            LOGGER.info("All nodes ready")
        else:
            LOGGER.info("All nodes not ready")
        return overall_status
    except Exception as e:
        trc = traceback.format_exc()
        LOGGER.error("Failed checking node status {0}: {1}\n\n{2}".format(json.dumps(event), str(e), trc))
        return 0

