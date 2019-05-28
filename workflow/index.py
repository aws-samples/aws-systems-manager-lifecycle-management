# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

import boto3
import json
import logging
import traceback
import os
import time

# Create AWS clients
asg = boto3.client('autoscaling')
ssm = boto3.client('ssm')
ec2 = boto3.client('ec2')

# Constants
LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)
TEST = 'test'

# Env variables
docname = os.environ['DOCNAME']
queueurl = os.environ['QUEUEURL']
desired_iops = os.environ['PIOPS']

def create_and_register_volume(snapshot_id, project, environment, role, idx, az):

    response = ec2.create_volume(
        Encrypted=True,
        Iops=int(desired_iops),
        VolumeType='io1',
        DryRun=False,
        SnapshotId=snapshot_id,
        AvailabilityZone=az,
        TagSpecifications=[
            {
                'ResourceType': 'volume',
                'Tags': [
                    {
                        'Key': 'Name',
                        'Value': "datavol-{0}-{1}".format(role, idx)
                    },
                    {
                        'Key': 'Project',
                        'Value': project
                    },
                    {
                        'Key': 'Environment',
                        'Value': environment
                    }
                ]
            },
        ]
    )
    ssm.put_parameter(
        Name="/{0}/{1}/{2}/datavol/{3}".format(project, environment, role, idx),
        Value=response['VolumeId'],
        Type='String',
        Overwrite=True
    )
    return response['VolumeId']

def get_latest_snapshot_id(project, environment, role):
    response = ec2.describe_snapshots(
        Filters=[
            {
                'Name': 'tag:Name',
                'Values': [ "datavol-{0}-0".format(role) ]
            },
            {
                'Name': 'tag:Project',
                'Values': [ project ]
            },
            {
                'Name': 'tag:Environment',
                'Values': [ environment ]
            }
        ],
        DryRun=False
    )
    snaps = response['Snapshots']
    latest_snap = sorted(snaps, key=lambda k: k['StartTime'], reverse=True)[0]
    return latest_snap['SnapshotId']

def get_az(instanceid):
    response = ec2.describe_instances(
        InstanceIds=[ instanceid ],
        DryRun=False,
    )
    return response['Reservations'][0]['Instances'][0]['Placement']['AvailabilityZone']

def handler(event, context):

    token = TEST
    hookname = ''
    asgname = ''
    try:
        LOGGER.info("SNS metadata: {0}".format(json.dumps(event)))
        message = json.loads(event['Records'][0]['Sns']['Message'])
        instanceid = message['EC2InstanceId']
        metadata = json.loads(message['NotificationMetadata'])
        hookname = message['LifecycleHookName']
        asgname = message['AutoScalingGroupName']
        token = message['LifecycleActionToken']

        LOGGER.info("instance-id: %s" % instanceid)
        LOGGER.info("metadata: %s" % json.dumps(metadata))

        LOGGER.info("Getting ENI id from SSM")
        response = ssm.get_parameter(
            Name="/{0}/{1}/{2}/eipeni/{3}".format(metadata['project'], metadata['environment'], metadata['role'], metadata['id'])
        )
        eniid = response['Parameter']['Value']
        LOGGER.info("Got ENI id from SSM: {0}".format(eniid))

        LOGGER.info("Getting data volume id from SSM")
        datavolid = ''
        try:
            response = ssm.get_parameter(
                Name="/{0}/{1}/{2}/datavol/{3}".format(metadata['project'], metadata['environment'], metadata['role'], metadata['id'])
            )
            datavolid = response['Parameter']['Value']
            LOGGER.info("Got data volume id from SSM: {0}".format(datavolid))
        except ssm.exceptions.ParameterNotFound:
            LOGGER.info("Data volume ID not found from SSM, creating a new volume from latest snapshot")
            datavolid = create_and_register_volume(get_latest_snapshot_id(metadata['project'], metadata['environment'], metadata['role']), \
                metadata['project'], metadata['environment'], metadata['role'], metadata['id'], \
                get_az(instanceid))
            LOGGER.info("Created data volume id: {0}".format(datavolid))

        LOGGER.info("Getting logs volume id from SSM")
        response = ssm.get_parameter(
            Name="/{0}/{1}/{2}/logsvol/{3}".format(metadata['project'], metadata['environment'], metadata['role'], metadata['id'])
        )
        logsvolid = response['Parameter']['Value']
        LOGGER.info("Got logs volume id from SSM: {0}".format(logsvolid))

        LOGGER.info("Recording instance ID in SSM")
        ssm.put_parameter(
            Name="/{0}/{1}/{2}/instanceid/{3}".format(metadata['project'], metadata['environment'], metadata['role'], metadata['id']),
            Value=instanceid,
            Type='String',
            Overwrite=True
        )

        LOGGER.info("Starting doc execution with queue URL {0}".format(queueurl))
        response = ssm.start_automation_execution(
            DocumentName = docname,
            Parameters = {
                'EniId': [eniid],
                'Project': [metadata['project']],
                'Role': [metadata['role']],
                'Environment': [metadata['environment']],
                'ID': [metadata['id']],
                'VolumeIdLogs': [logsvolid],
                'VolumeIdData': [datavolid],
                'InstanceId': [instanceid],
                'QueueUrl': [queueurl]
            },
        )
        execution_id = response['AutomationExecutionId']
        LOGGER.info("Doc execution id: {0}".format(execution_id))

        while True:
            response = ssm.get_automation_execution( AutomationExecutionId=execution_id)
            status = response['AutomationExecution']['AutomationExecutionStatus']
            if status == 'Failed':
                LOGGER.warn("Execution failed: {0}".format(response['AutomationExecution']['FailureMessage']))
                raise Exception("Execution failed: {0}".format(response['AutomationExecution']['FailureMessage']))
            if status == 'TimedOut':
                LOGGER.warn("Execution timed out")
                raise Exception("Execution timed out")
            if status == 'Success':
                LOGGER.info("Execution succeeded")
                break
            time.sleep(5)

        if token != TEST:
            LOGGER.info("Sending lifecycle completion hook")
            response = asg.complete_lifecycle_action(
                LifecycleHookName=hookname,
                AutoScalingGroupName=asgname,
                LifecycleActionToken=token,
                LifecycleActionResult='CONTINUE'
            )
    except Exception as e:
        trc = traceback.format_exc()
        LOGGER.error("Failed processing lifecycle hook {0}: {1}\n\n{2}".format(json.dumps(event), str(e), trc))
        if token != TEST:
            LOGGER.warn("Sending lifecycle abandon hook")
            response = asg.complete_lifecycle_action(
                LifecycleHookName=hookname,
                AutoScalingGroupName=asgname,
                LifecycleActionToken=token,
                LifecycleActionResult='ABANDON'
            )

