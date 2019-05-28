# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

import boto3
import json
import logging
import traceback
import os
import time

# Create AWS clients
sfn = boto3.client('stepfunctions')
ssm = boto3.client('ssm')

# Environment variables
sfn_arn = os.environ['SFN_ARN']

# Constants
LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)
TIME_BUFFER_MS = 1000 # leave this much time to call SFN

"""
This function needs to check if the step function is already executing.
If so, requeue the message.
Otherwise, invoke the workflow.

Example input:
{
  "Records": [
    {
      "messageId": "26abc43a-b123-496f-a0ab-9958d3cb1ffc",
      "receiptHandle": "AQEBStD9V6E/nFu/6dNOIA3kTi675uaq244W70Em0gTlDwXyBABZAFwMn8oa4lo+j4+TPc24XSEzQhDV1t1/BY8ipHZ/NBHkTiYOZAJ0a5WGn+qgAFFnePxQHJr79IOvFbIiVJdwL5fXP6tz/zmwsAWtkM9HjAKJFQED+99/1mMrQ0HBm+czYuKpamuc6KqMRR9M4bTPNF5JahASAZdCKM1N+g4kiAK8KQW0SHU75MfG7TV5UipDxj0racmWafKOGmnGzJZ8rTQ5z60a3y4ubFgrDIW1XNWvYDWFgWaS9BxeaWcrTuGy0hc5O23sBwoETC3rBDE7HjihRfKflEhuzSXvrNi0dZ3Tk+kVONiyh6LyTZPEU1SpU22kv2fG9ymFNbfonPpfYgNDa3KPfsAoQ8weYJfmvf0vpOpm9O2E0qHHWZugkVs1VOa/3c+ItzofQ0I9",
      "body": "Ready",
      "attributes": {
        "ApproximateReceiveCount": "1",
        "SentTimestamp": "1546475202745",
        "SenderId": "AROAJC5KZI7IJT32AJOM2:a6f5aaa5-63ba-4f88-a403-2db84a73c916",
        "ApproximateFirstReceiveTimestamp": "1546475202756"
      },
      "messageAttributes": {
        "Role": {
          "stringValue": "rsmember",
          "stringListValues": [],
          "binaryListValues": [],
          "dataType": "String"
        },
        "Project": {
          "stringValue": "MongoDB",
          "stringListValues": [],
          "binaryListValues": [],
          "dataType": "String"
        },
        "Environment": {
          "stringValue": "Test",
          "stringListValues": [],
          "binaryListValues": [],
          "dataType": "String"
        },
        "ID": {
          "stringValue": "2",
          "stringListValues": [],
          "binaryListValues": [],
          "dataType": "String"
        }
      },
      "md5OfBody": "e7d31fc0602fb2ede144d18cdffd816b",
      "md5OfMessageAttributes": "6f870103b245e182b5d55c6ff822430d",
      "eventSource": "aws:sqs",
      "eventSourceARN": "arn:aws:sqs:us-west-2:102165494304:lifecycle-queue-20190102234252928100000001",
      "awsRegion": "us-west-2"
    }
  ]
}

Example output:
{
    "nodes": {
        "id": [
            instance id,
            instance id
        ],
        "dns": [
            dns name,
            dns name
        ]
      },
      "project": project,
      "environment": environment,
      "role": role
}
"""

class WorkflowAlreadyRunningException(Exception): pass

def handler(event, context):

    try:
        LOGGER.info("SQS metadata: {0}".format(json.dumps(event)))
        attributes = event['Records'][0]['messageAttributes']
        role = attributes['Role']['stringValue']
        project = attributes['Project']['stringValue']
        environment = attributes['Environment']['stringValue']
        iid = attributes['ID']['stringValue']
        LOGGER.info("Got node ready message: {0}/{1}/{2}/{3}".format(project,environment,role, iid))

        # In this loop, we first check if the function is close to timing out.
        # If so, we raise an exception and quit.
        # Otherwise, we check if any SFN executions are in progress.
        # If so, we go through the loop again; otherwise we proceed.
        while True:
            LOGGER.info("Checking if SFN is running...")
            response = sfn.list_executions(
                stateMachineArn=sfn_arn,
                statusFilter='RUNNING',
                maxResults=1
            )
            numExecutions = len(response['executions'])
            if numExecutions < 1:
                break
            timeRemaining = context.get_remaining_time_in_millis()
            if timeRemaining < TIME_BUFFER_MS:
                LOGGER.info("SFN is running, requeueing message")
                raise WorkflowAlreadyRunningException("SFN workflow already running")
            time.sleep(5)

            
        LOGGER.info("SFN is not running, invoking")

        instance_list = []
        LOGGER.info("Looking up instance IDs")
        response = ssm.get_parameters_by_path(
            Path="/{0}/{1}/{2}/instanceid/".format(project, environment, role),
            Recursive=True
        )
        for param in response['Parameters']:
            instance_list.append(param['Value'])

        LOGGER.info("Getting DNS names from SSM")
        dnsnames = []
        response = ssm.get_parameters_by_path(
            Path="/{0}/{1}/{2}/dns/".format(project, environment, role),
            Recursive=True
        )
        for param in response['Parameters']:
            dnsnames.append(param['Value'])
        LOGGER.info("Got DNS from SSM: {0}".format(str(dnsnames)))

        sfn_input = {}
        sfn_input['nodes'] = {}
        sfn_input['nodes']['id'] = instance_list
        sfn_input['nodes']['dns'] = dnsnames
        sfn_input['project'] = project
        sfn_input['environment'] = environment
        sfn_input['role'] = role

        LOGGER.info("SFN input: {0}".format(json.dumps(sfn_input)))

        response = sfn.start_execution(
            stateMachineArn=sfn_arn,
            input=json.dumps(sfn_input)
        )
        LOGGER.info("Launched SFN execution {0}".format(response['executionArn']))
    except WorkflowAlreadyRunningException as wfe:
        raise wfe
    except Exception as e:
        trc = traceback.format_exc()
        LOGGER.error("Failed processing SQS event {0}: {1}\n\n{2}".format(json.dumps(event), str(e), trc))
        raise e
