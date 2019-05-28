---
description: Initialize a MongoDB replica set server.
schemaVersion: "0.3"
assumeRole: "${SSMRoleArn}"
parameters:
  EniId:
    type: String
    description: ENI ID
    default: ""
  VolumeIdData:
    type: String
    description: Volume ID for data
    default: ""
  VolumeIdLogs:
    type: String
    description: Volume ID for logs
    default: ""
  InstanceId:
    type: String
    description: EC2 instance ID
    default: ""
  Project:
    type: String
    description: Project
    default: ""
  Environment:
    type: String
    description: Environment
    default: ""
  Role:
    type: String
    description: Role
    default: ""
  ID:
    type: String
    description: ID
    default: ""
  QueueUrl:
    type: String
    description: SQS URL
    default: ""
mainSteps:
- name: get_interfaces
  action: aws:executeAwsApi
  inputs:
    Service: ec2
    Api: DescribeNetworkInterfaces
    NetworkInterfaceIds: ["{{EniId}}"]
  outputs:
  - Name: isAttached
    Selector: "$.NetworkInterfaces[0].Status"
    Type: "String"
- name: Check_if_ENI_attached
  action: aws:branch
  inputs:
    Choices:
    - NextStep: attachENI
      Variable: "{{get_interfaces.isAttached}}"
      StringEquals: "available"
    Default:
      get_data_volume_status
- name: attachENI
  action: aws:executeAwsApi
  inputs:
    Service: ec2
    Api:  AttachNetworkInterface
    InstanceId: "{{InstanceId}}"
    NetworkInterfaceId: "{{EniId}}"
    DeviceIndex: 1
- name: get_data_volume_status
  action: aws:executeAwsApi
  inputs:
    Service: ec2
    Api: DescribeVolumes
    VolumeIds: ["{{VolumeIdData}}"]
  outputs:
  - Name: volStatusData
    Selector: "$.Volumes[0].State"
    Type: "String"
- name: Check_if_data_vol_attached
  action: aws:branch
  inputs:
    Choices:
    - NextStep: attachDataVol
      Variable: "{{get_data_volume_status.volStatusData}}"
      StringEquals: "available"
    Default:
      get_logs_volume_status
- name: attachDataVol
  action: aws:executeAwsApi
  inputs:
    Service: ec2
    Api:  AttachVolume
    InstanceId: "{{InstanceId}}"
    VolumeId: "{{VolumeIdData}}"
    Device: /dev/xvdg
- name: get_logs_volume_status
  action: aws:executeAwsApi
  inputs:
    Service: ec2
    Api: DescribeVolumes
    VolumeIds: ["{{VolumeIdLogs}}"]
  outputs:
  - Name: volStatusLogs
    Selector: "$.Volumes[0].State"
    Type: "String"
- name: Check_if_logs_vol_attached
  action: aws:branch
  isEnd: true
  inputs:
    Choices:
    - NextStep: attachLogsVol
      Variable: "{{get_logs_volume_status.volStatusLogs}}"
      StringEquals: "available"
    Default:
      updateSSMAgent
- name: attachLogsVol
  action: aws:executeAwsApi
  inputs:
    Service: ec2
    Api:  AttachVolume
    InstanceId: "{{InstanceId}}"
    VolumeId: "{{VolumeIdLogs}}"
    Device: /dev/xvdh
- name: updateSSMAgent
  action: aws:runCommand
  inputs:
    DocumentName: AWS-UpdateSSMAgent
    InstanceIds:
    - "{{InstanceId}}"
- name: installCollectd
  action: aws:runCommand
  inputs:
    DocumentName: AWS-RunShellScript
    InstanceIds:
    - "{{InstanceId}}"
    Parameters:
        commands: 
        - yum install -y collectd
- name: installCWAgent
  action: aws:runCommand
  inputs:
    DocumentName: AWS-ConfigureAWSPackage
    InstanceIds:
    - "{{InstanceId}}"
    Parameters:
        action: Install 
        name:  AmazonCloudWatchAgent
- name: startCWAgent
  action: aws:runCommand
  inputs:
    DocumentName: AmazonCloudWatch-ManageAgent
    InstanceIds:
    - "{{InstanceId}}"
    Parameters:
        action: "configure"
        mode:  "ec2"
        optionalConfigurationSource: "ssm"
        optionalConfigurationLocation: "AmazonCloudWatch-mongo"
        optionalRestart: "yes"
- name: installPip
  action: aws:runCommand
  inputs:
    DocumentName: AWS-RunShellScript
    InstanceIds:
    - "{{InstanceId}}"
    Parameters:
        commands: 
        - pip install ansible boto3 botocore
- name: runPlaybook
  action: aws:runCommand
  inputs:
    DocumentName: AWS-RunAnsiblePlaybook
    InstanceIds:
    - "{{InstanceId}}"
    Parameters:
      playbookurl: "${PlaybookUrl}"
      extravars: "Project={{Project}} Role={{Role}} Environment={{Environment}} ID={{ID}}"
- name: notifySqs
  action: aws:executeAwsApi
  inputs:
    Service: sqs
    Api: SendMessage
    QueueUrl: "{{QueueUrl}}"
    MessageBody: "Ready"
    MessageAttributes:
      Project:
        DataType: String
        StringValue: "{{Project}}"
      Environment:
        DataType: String
        StringValue: "{{Environment}}"
      Role:
        DataType: String
        StringValue: "{{Role}}"
      ID:
        DataType: String
        StringValue: "{{ID}}"