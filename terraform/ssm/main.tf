terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_ssm_document" "golden_ami_automation_doc" {
  name            = "golden_ami_automation_doc"
  document_type   = "Automation"
  document_format = "JSON"
  content         = <<GOLDEN_AMI_AUTO
  {
    "description": "This automation document triggers Golden AMI creation workflow.",
    "schemaVersion": "0.3",
    "assumeRole": {
        "Fn::GetAtt": [
            "AutomationServiceRole",
            "Arn"
        ]
    },
    "parameters": {
        "sourceAMIid": {
            "type": "String",
            "description": "Source/Base AMI to be used for generating your golden AMI",
            "default": "<ENTER AMI ID>"
        },

        "QualysUsername": {
          "default": "/GoldenAMI/Qualys/QualysUsername",
          "description": "SSM parameter name of Qualys username to access API",
          "type": "String"
        },

        "QualysPassword": {
          "default": "/GoldenAMI/Qualys/QualysPassword",
          "description": "SSM parameter name of the Qualys password to access API",
          "type": "String"
        },

        "QualysScannerName": {
          "default": "{{ssm:/GoldenAMI/Qualys/QualysScannerName}}",
          "description": "Scanner name for launching Qualys VM Scan",
          "type": "String"
        },

        "QualysOptionId": {
          "default": "{{ssm:/GoldenAMI/Qualys/QualysOptionId}}",
          "description": "Option ID for launching Qualys VM Scan",
          "type": "String"
        },

        "QualysApiUrl": {
          "type": "String",
          "description": "Your Qualys URL for accessing API",
          "default": {
              "Ref": "qualysApiUrl"
            }
        },

        "productName": {
            "type": "String",
            "description": "The syntax of this parameter is ProductName-ProductVersion.",
            "default": {
                "Ref": "productName"
          }
        },

        "productOSAndVersion": {
            "type": "String",
            "description": "The syntax of this parameter is OSName-OSVersion",
            "default": {
                "Ref": "productOSAndVersion"
            }
          },

        "AMIVersion": {
            "type": "String",
            "description": "Golden AMI Build version number to be created.",
            "default": {
                "Ref": "buildVersion"
            }
          },

        "subnetId": {
            "type": "String",
            "default":{
                "Ref": "subnetPrivate"
            },
            "description": "Subnet in which instances will be launched."
        },

        "securityGroupId": {
            "type": "String",
            "default":{
                "Ref": "secGroup"
            },
            "description": "Security Group that will be attached to the instance. By Default a security group without any inbound access is attached"
        },

        "instanceType": {
            "type": "String",
            "description": "A compatible instance-type for launching an instance",
            "default": {
                "Ref": "instanceType"
            }
        },

        "targetAMIname": {
            "type": "String",
            "description": "Name for the golden AMI to be created",
            "default": "{{productName}}-{{productOSAndVersion}}-{{AMIVersion}}"
          },

        "ApproverUserIAMARN": {
            "type": "String",
            "description": "IAM ARN of the user who has SSM approval permissions.",
            "default": {
                "Ref": "ApproverUserIAMARN"
            }
          },

        "ApproverNotificationArn": {
            "type": "String",
            "description": "SNS Topic ARN on which a notification would be published once the golden AMI candidate is ready for validation.",
            "default": {
                "Ref": "ApproverNotification"
            }
        },

        "ManagedInstanceProfile": {
            "type": "String",
            "description": "Instance Profile. Do not change the default value.",
            "default": {
                "Ref": "ManagedInstanceProfile"
            }
        },

        "SSMInstallationUserData": {
            "type": "String",
            "description": "Base64 encoded SSM installation user-data.",
            "default": "IyEvYmluL2Jhc2gNCg0KZnVuY3Rpb24gZ2V0X2NvbnRlbnRzKCkgew0KICAgIGlmIFsgLXggIiQod2hpY2ggY3VybCkiIF07IHRoZW4NCiAgICAgICAgY3VybCAtcyAtZiAiJDEiDQogICAgZWxpZiBbIC14ICIkKHdoaWNoIHdnZXQpIiBdOyB0aGVuDQogICAgICAgIHdnZXQgIiQxIiAtTyAtDQogICAgZWxzZQ0KICAgICAgICBkaWUgIk5vIGRvd25sb2FkIHV0aWxpdHkgKGN1cmwsIHdnZXQpIg0KICAgIGZpDQp9DQoNCnJlYWRvbmx5IElERU5USVRZX1VSTD0iaHR0cDovLzE2OS4yNTQuMTY5LjI1NC8yMDE2LTA2LTMwL2R5bmFtaWMvaW5zdGFuY2UtaWRlbnRpdHkvZG9jdW1lbnQvIg0KcmVhZG9ubHkgVFJVRV9SRUdJT049JChnZXRfY29udGVudHMgIiRJREVOVElUWV9VUkwiIHwgYXdrIC1GXCIgJy9yZWdpb24vIHsgcHJpbnQgJDQgfScpDQpyZWFkb25seSBERUZBVUxUX1JFR0lPTj0idXMtZWFzdC0xIg0KcmVhZG9ubHkgUkVHSU9OPSIke1RSVUVfUkVHSU9OOi0kREVGQVVMVF9SRUdJT059Ig0KDQpyZWFkb25seSBTQ1JJUFRfTkFNRT0iYXdzLWluc3RhbGwtc3NtLWFnZW50Ig0KIFNDUklQVF9VUkw9Imh0dHBzOi8vYXdzLXNzbS1kb3dubG9hZHMtJFJFR0lPTi5zMy5hbWF6b25hd3MuY29tL3NjcmlwdHMvJFNDUklQVF9OQU1FIg0KDQppZiBbICIkUkVHSU9OIiA9ICJjbi1ub3J0aC0xIiBdOyB0aGVuDQogIFNDUklQVF9VUkw9Imh0dHBzOi8vYXdzLXNzbS1kb3dubG9hZHMtJFJFR0lPTi5zMy5jbi1ub3J0aC0xLmFtYXpvbmF3cy5jb20uY24vc2NyaXB0cy8kU0NSSVBUX05BTUUiDQpmaQ0KDQppZiBbICIkUkVHSU9OIiA9ICJ1cy1nb3Ytd2VzdC0xIiBdOyB0aGVuDQogIFNDUklQVF9VUkw9Imh0dHBzOi8vYXdzLXNzbS1kb3dubG9hZHMtJFJFR0lPTi5zMy11cy1nb3Ytd2VzdC0xLmFtYXpvbmF3cy5jb20vc2NyaXB0cy8kU0NSSVBUX05BTUUiDQpmaQ0KDQpjZCAvdG1wDQpGSUxFX1NJWkU9MA0KTUFYX1JFVFJZX0NPVU5UPTMNClJFVFJZX0NPVU5UPTANCg0Kd2hpbGUgWyAkUkVUUllfQ09VTlQgLWx0ICRNQVhfUkVUUllfQ09VTlQgXSA7IGRvDQogIGVjaG8gQVdTLVVwZGF0ZUxpbnV4QW1pOiBEb3dubG9hZGluZyBzY3JpcHQgZnJvbSAkU0NSSVBUX1VSTA0KICBnZXRfY29udGVudHMgIiRTQ1JJUFRfVVJMIiA+ICIkU0NSSVBUX05BTUUiDQogIEZJTEVfU0laRT0kKGR1IC1rIC90bXAvJFNDUklQVF9OQU1FIHwgY3V0IC1mMSkNCiAgZWNobyBBV1MtVXBkYXRlTGludXhBbWk6IEZpbmlzaGVkIGRvd25sb2FkaW5nIHNjcmlwdCwgc2l6ZTogJEZJTEVfU0laRQ0KICBpZiBbICRGSUxFX1NJWkUgLWd0IDAgXTsgdGhlbg0KICAgIGJyZWFrDQogIGVsc2UNCiAgICBpZiBbWyAkUkVUUllfQ09VTlQgLWx0IE1BWF9SRVRSWV9DT1VOVCBdXTsgdGhlbg0KICAgICAgUkVUUllfQ09VTlQ9JCgoUkVUUllfQ09VTlQrMSkpOw0KICAgICAgZWNobyBBV1MtVXBkYXRlTGludXhBbWk6IEZpbGVTaXplIGlzIDAsIHJldHJ5Q291bnQ6ICRSRVRSWV9DT1VOVA0KICAgIGZpDQogIGZpIA0KZG9uZQ0KDQppZiBbICRGSUxFX1NJWkUgLWd0IDAgXTsgdGhlbg0KICBjaG1vZCAreCAiJFNDUklQVF9OQU1FIg0KICBlY2hvIEFXUy1VcGRhdGVMaW51eEFtaTogUnVubmluZyBVcGRhdGVTU01BZ2VudCBzY3JpcHQgbm93IC4uLi4NCiAgLi8iJFNDUklQVF9OQU1FIiAtLXJlZ2lvbiAiJFJFR0lPTiINCmVsc2UNCiAgZWNobyBBV1MtVXBkYXRlTGludXhBbWk6IFVuYWJsZSB0byBkb3dubG9hZCBzY3JpcHQsIHF1aXR0aW5nIC4uLi4NCmZp"
          },

        "PreUpdateScript": {
            "type": "String",
            "description": "(Optional) URL of a script to run before updates are applied. Default (\"none\") is to not run a script.",
            "default": "none"
        },

        "PostUpdateScript": {
            "type": "String",
            "description": "(Optional) URL of a script to run after package updates are applied. Default (\"none\") is to not run a script.",
            "default": "none"
        },

        "IncludePackages": {
            "type": "String",
            "description": "(Optional) Only update these named packages. By default (\"all\"), all available updates are applied.",
            "default": "all"
        },

        "ExcludePackages": {
            "type": "String",
            "description": "(Optional) Names of packages to hold back from updates, under all conditions. By default (\"none\"), no package is excluded.",
            "default": "none"
        }

    },
    "mainSteps": [
        {
            "name": "startInstances",
            "action": "aws:runInstances",
            "timeoutSeconds": 3600,
            "maxAttempts": 1,
            "onFailure": "Abort",
            "inputs": {
                "ImageId": "{{ sourceAMIid }}",
                "InstanceType": "{{instanceType}}",
                "MinInstanceCount": 1,
                "MaxInstanceCount": 1,
                "SubnetId": "{{ subnetId }}",
                "SecurityGroupIds": [
                    "{{ securityGroupId }}"
                ],
                "UserData": "{{SSMInstallationUserData}}",
                "IamInstanceProfileName": "{{ ManagedInstanceProfile }}"
            }
        },
        {
            "name": "updateOSSoftware",
            "action": "aws:runCommand",
            "maxAttempts": 3,
            "timeoutSeconds": 3600,
            "onFailure": "Abort",
            "inputs": {
                "DocumentName": "AWS-RunShellScript",
                "InstanceIds": [
                    "{{startInstances.InstanceIds}}"
                ],
                "Parameters": {
                    "commands": [
                        "set -e",
                        "[ -x \"$(which wget)\" ] && get_contents='wget $1 -O -'",
                        "[ -x \"$(which curl)\" ] && get_contents='curl -s -f $1'",
                        "eval $get_contents https://aws-ssm-downloads-{{global:REGION}}.s3.amazonaws.com/scripts/aws-update-linux-instance > /tmp/aws-update-linux-instance",
                        "chmod +x /tmp/aws-update-linux-instance",
                        "/tmp/aws-update-linux-instance --pre-update-script '{{PreUpdateScript}}' --post-update-script '{{PostUpdateScript}}' --include-packages '{{IncludePackages}}' --exclude-packages '{{ExcludePackages}}' 2>&1 | tee /tmp/aws-update-linux-instance.log"
                    ]
                }
            }
        },
        {
            "name": "stopInstance",
            "action": "aws:changeInstanceState",
            "timeoutSeconds": 1200,
            "maxAttempts": 1,
            "onFailure": "Abort",
            "inputs": {
                "InstanceIds": [
                    "{{ startInstances.InstanceIds }}"
                ],
                "DesiredState": "stopped"
            }
        },
        {
            "name": "createImage",
            "action": "aws:createImage",
            "timeoutSeconds": 1200,
            "maxAttempts": 1,
            "onFailure": "Continue",
            "inputs": {
                "InstanceId": "{{ startInstances.InstanceIds }}",
                "ImageName": "{{ targetAMIname }}",
                "NoReboot": true,
                "ImageDescription": "AMI created by EC2 Automation"
            }
        },
        {
            "name": "TagTheAMI",
            "action": "aws:createTags",
            "timeoutSeconds": 1200,
            "maxAttempts": 1,
            "onFailure": "Continue",
            "inputs": {
                "ResourceType": "EC2",
                "ResourceIds": [
                    "{{ createImage.ImageId }}"
                ],
                "Tags": [
                    {
                        "Key": "ProductOSAndVersion",
                        "Value": "{{productOSAndVersion}}"
                    },
                    {
                        "Key": "ProductName",
                        "Value": "{{productName}}"
                    },
                    {
                        "Key": "version",
                        "Value": "{{AMIVersion}}"
                    },
                    {
                        "Key": "AMI-Type",
                        "Value": "Golden"
                    }
                ]
            }
        },
        {
            "name": "terminateFirstInstance",
            "action": "aws:changeInstanceState",
            "timeoutSeconds": 1200,
            "maxAttempts": 1,
            "onFailure": "Continue",
            "inputs": {
                "InstanceIds": [
                    "{{ startInstances.InstanceIds }}"
                ],
                "DesiredState": "terminated"
            }
        },
        {
            "name": "createInstanceFromNewImage",
            "action": "aws:runInstances",
            "timeoutSeconds": 1200,
            "maxAttempts": 1,
            "onFailure": "Abort",
            "inputs": {
                "ImageId": "{{ createImage.ImageId }}",
                "InstanceType": "{{instanceType}}",
                "MinInstanceCount": 1,
                "MaxInstanceCount": 1,
                "SubnetId": "{{ subnetId }}",
                "SecurityGroupIds": [
                    "{{ securityGroupId }}"
                ],
                "IamInstanceProfileName": "{{ ManagedInstanceProfile }}"
            }
        },
        {
          "maxAttempts": 3,
          "inputs": {
            "Parameters": {
              "commands": [
                "set -e",
                "INSTANCE_IP=$(curl -s 'http://169.254.169.254/latest/meta-data/local-ipv4')",
                "REGION=\"{{global:REGION}}\"",
                "QualysUsername=$(aws ssm get-parameter --with-decryption --region $REGION --name {{QualysUsername}} --query 'Parameter.Value' --output text)",
                "QualysPassword=$(aws ssm get-parameter --with-decryption --region $REGION --name {{QualysPassword}} --query 'Parameter.Value' --output text)",
                "curl -H \"X-Requested-With: Curl\" -u \"$QualysUsername:$QualysPassword\" -X \"POST\" -d \"action=launch&scan_title=CANDIDATE+AMI+Scan+{{createImage.ImageId}}&ip=$INSTANCE_IP&option_id={{QualysOptionId}}&iscanner_name={{QualysScannerName}}\" \"{{QualysApiUrl}}/api/2.0/fo/scan/\"> vm-scan-launch-log.txt"
              ]
            },
            "InstanceIds": [
              "{{ createInstanceFromNewImage.InstanceIds }}"
            ],
            "DocumentName": "AWS-RunShellScript"
          },
          "name": "LaunchQualysAssessment",
          "action": "aws:runCommand",
          "timeoutSeconds": 3600,
          "onFailure": "Abort"
        },
        {
            "name": "sleep2",
            "action": "aws:sleep",
            "inputs": {
                "Duration": "PT01M"
            }
        },
        {
            "name": "TagNewinstance",
            "action": "aws:createTags",
            "timeoutSeconds": 1200,
            "maxAttempts": 1,
            "onFailure": "Continue",
            "inputs": {
                "ResourceType": "EC2",
                "ResourceIds": [
                    "{{ createInstanceFromNewImage.InstanceIds }}"
                ],
                "Tags": [
                    {
                        "Key": "Type",
                        "Value": "{{createImage.ImageId}}-{{productOSAndVersion}}/{{productName}}/{{AMIVersion}}"
                    },
                     {
                        "Key": "Automation-Instance-Type",
                        "Value": "Golden"
                    }
                ]
            }
        },
        {
            "name": "StoreVersion",
            "action": "aws:invokeLambdaFunction",
            "maxAttempts": 3,
            "timeoutSeconds": 120,
            "onFailure": "Abort",
            "inputs": {
                "FunctionName": { "Ref": "StoreVersionLambdaFunction"},
                "Payload": {
                    "Fn::Join": [
                        "",
                        [
                            "{\"AMI-ID\": \"{{createImage.ImageId}}\",\"topicArn\":\"",
                            "\",\"instanceId\": \"{{ createInstanceFromNewImage.InstanceIds }}\",\"productOS\": \"{{productOSAndVersion}}\",\"productName\": \"{{productName}}\",\"productVersion\": \"{{AMIVersion}}\"}"
                        ]
                    ]
                }
            }
        },
        {
            "name": "sleep",
            "action": "aws:sleep",
            "inputs": {
                "Duration": "PT01M"
            }
        },
        {
          "maxAttempts": 1,
          "inputs": {
            "DesiredState": "terminated",
            "InstanceIds": [
              "{{ createInstanceFromNewImage.InstanceIds }}"
            ]
          },
          "name": "terminateQualysInstance",
          "action": "aws:changeInstanceState",
          "timeoutSeconds": 1200,
          "onFailure": "Continue"
        },
        {
            "name": "addNewVersionParameter",
            "action": "aws:invokeLambdaFunction",
            "timeoutSeconds": 1200,
            "maxAttempts": 1,
            "onFailure": "Abort",
            "inputs": {
                "FunctionName":{ "Ref": "AppendParamLambda"},

                "Payload": "{\"parameterName\":\"/GoldenAMI/{{productOSAndVersion}}/{{productName}}/{{AMIVersion}}\", \"valueToBeCreatedOrAppended\":\"{{createImage.ImageId}}\"}"
            }
        },
        {
            "name": "approve",
            "action": "aws:approve",
            "timeoutSeconds": 172800,
            "onFailure": "Abort",
            "inputs": {
                "NotificationArn": "{{ ApproverNotificationArn }}",
                "Message": "Please check your report from Qualys, and decide whether to approve this AMI- {{createImage.ImageId}}",
                "MinRequiredApprovals": 1,
                "Approvers": [
                    "{{ ApproverUserIAMARN }}"
                ]
            }
        },
         {
            "name": "updateLatestVersionValue",
            "action": "aws:invokeLambdaFunction",
            "timeoutSeconds": 1200,
            "maxAttempts": 1,
            "onFailure": "Abort",
            "inputs": {
                "FunctionName":{ "Ref": "AppendParamLambda"},
                "Payload": "{\"parameterName\":\"/GoldenAMI/latest\", \"valueToBeCreatedOrAppended\":\"{{createImage.ImageId}}\"}"
            }
        }
    ],
    "outputs": [
        "createImage.ImageId"
    ]
  }
GOLDEN_AMI_AUTO
}

resource "aws_ssm_document" "copy_and_share_ami" {
  name            = "copy_and_share_ami"
  document_type   = "Automation"
  document_format = "JSON"
  content         = <<COPY_AND_SHARE_AMI
  {
    "description":"This automation document triggers a workflow to copy and share the golden AMI with other regions/accounts",
    "schemaVersion":"0.3",
    "assumeRole":{
             "Fn::GetAtt": [
                 "AutomationServiceRole",
                 "Arn"
             ]
         },
    "parameters":{

       "MetadataJSON":{
          "type":"String",
          "description":"This parameter contains details of accounts and regions with which AMI needs to be shared. Kindly do not change the structure of the JSON",
          "default":{"Ref":"MetadataJSON"}
       },
       "bucketName":{
          "type":"String",
          "description":"This parameter contains name of the bucket in which template file is stored",
          "default":{"Ref":"GoldenAMIConfigBucket"}
        },
       "templateFileName":{
          "type":"String",
          "description":"This parameter contains name of the template file",
          "default":"simpleEC2-SSMParamInput.json"
       },
       "productName":{
          "type":"String",
          "description":"The syntax of this parameter is ProductName-ProductVersion",
          "default":{ "Ref": "productName" }
       },
       "productOSAndVersion":{
          "type":"String",
          "description":"The syntax of this parameter is OSName-OSVersion",
          "default":{ "Ref": "productOSAndVersion" }
       },
       "buildVersion":{
          "type":"String",
          "description":"This is the build number of the golden AMI to be distributed",
          "default":{ "Ref": "buildVersion" }
       },
       "MetadataParamName":{
          "type":"String",
          "description":"This parameter points to an SSM parameter used for storing some process specific metadata. Kindly Do not change the default value.",
          "default": "/GoldenAMI/{{productOSAndVersion}}/{{productName}}/{{buildVersion}}/temp"
       }
    },
    "mainSteps":[
       {
          "name":"copyamitoregions",
          "action":"aws:invokeLambdaFunction",
          "timeoutSeconds":1200,
          "maxAttempts":1,
          "onFailure":"Abort",
          "inputs":{
             "FunctionName":{ "Ref": "CopyToMultipleRegionsLambdaFunction" },
             "Payload":"{\"MetadataJSON\":\"{{ MetadataJSON }}\",\"ProductName\":\"{{ productName }}\",\"ProductOSAndVersion\":\"{{ productOSAndVersion }}\",\"version\":\"{{ buildVersion }}\",\"AmiIDParamName\":\"/GoldenAMI/{{productOSAndVersion}}/{{productName}}/{{buildVersion}}\", \"MetadataParamName\":\"{{ MetadataParamName }}\"}"
          }
       },
       {
          "name":"sleep",
          "action":"aws:sleep",
          "inputs":{
             "Duration":"PT15M"
          }
       },
       {
          "name":"shareAmiWithAccounts",
          "action":"aws:invokeLambdaFunction",
          "timeoutSeconds":1200,
          "maxAttempts":1,
          "onFailure":"Abort",
          "inputs":{
             "FunctionName":{ "Ref": "CopyToMultipleAccountsLambdaFunction" },
             "Payload":"{\"MetadataJSON\":\"{{ MetadataJSON }}\",\"AmiIDParamName\":\"/GoldenAMI/{{productOSAndVersion}}/{{productName}}/{{buildVersion}}\", \"MetadataParamName\":\"{{ MetadataParamName }}\"}"
          }
       },
       {
          "name":"publishToSC",
          "action":"aws:invokeLambdaFunction",
          "timeoutSeconds":1200,
          "maxAttempts":1,
          "onFailure":"Abort",
          "inputs":{
             "FunctionName":{ "Ref": "PublishAMILambda" },
             "Payload":"{\"bucketName\":\"{{ bucketName }}\", \"amiRegionMappingParamName\":\"{{ MetadataParamName }}\", \"templateFileName\":\"{{templateFileName}}\", \"versionToBeCreated\":\"{{ buildVersion }}\", \"productOSAndVersion\":\"{{ productOSAndVersion }}\", \"productNameAndVersion\":\"{{ productName }}\"}"
          }
       }
    ],
    "outputs":[
       "shareAmiWithAccounts.LogResult",
       "copyamitoregions.LogResult"
    ]
  }
COPY_AND_SHARE_AMI
}

resource "aws_ssm_document" "decommission_ami_version" {
  name            = "decommission_ami_version"
  document_type   = "Automation"
  document_format = "JSON"
  content         = <<DECOMMISSION_AMI_VERSION
{
    "description":"This automation document triggers golden AMI build decommissioning workflow",
    "schemaVersion":"0.3",
    "assumeRole":{
             "Fn::GetAtt": [
                 "AutomationServiceRole",
                 "Arn"
             ]
         },
    "parameters":{

       "bucketName":{
          "type":"String",
          "description":"This parameter contains name of the bucket in which CFT template file is stored",
          "default":{"Ref":"GoldenAMIConfigBucket"}
       },
       "templateFileName":{
          "type":"String",
          "description":"The CFT template file-name used for creating the Service Catalog product",
          "default":"simpleEC2-SSMParamInput.json"
       },
       "productName":{
          "type":"String",
          "description":"The syntax of this parameter is ProductName-ProductVersion",
          "default":{ "Ref": "productName" }
       },
       "productOSAndVersion":{
          "type":"String",
          "description":"The syntax of this parameter is OSName-OSVersion",
          "default":{ "Ref": "productOSAndVersion" }
       },
       "buildVersion":{
          "type":"String",
          "description":"Golden AMI build number to be decommissioned.",
          "default":{ "Ref": "buildVersion" }
       },
       "MetadataParamName":{
          "type":"String",
          "description":"This parameter points to an SSM parameter used for storing some process specific metadata. Do not change the default value.",
          "default": "/GoldenAMI/{{productOSAndVersion}}/{{productName}}/{{buildVersion}}/temp"
       }
    },
    "mainSteps":[
       {
          "name":"DecommissionAMIVersionLambda",
          "action":"aws:invokeLambdaFunction",
          "timeoutSeconds":1200,
          "maxAttempts":1,
          "onFailure":"Abort",
          "inputs":{
             "FunctionName":{ "Ref": "DecommissionAMIVersionLambda"},
             "Payload":"{\"bucketName\":\"{{ bucketName }}\", \"amiRegionMappingParamName\":\"{{ MetadataParamName }}\", \"templateFileName\":\"{{templateFileName}}\", \"versionToBeDeleted\":\"{{ buildVersion }}\", \"productOSAndVersion\":\"{{ productOSAndVersion }}\", \"productNameAndVersion\":\"{{ productName }}\"}"
          }
       },
      {
          "name":"DecommissionAMIVersionFromAccountsLambda",
          "action":"aws:invokeLambdaFunction",
          "timeoutSeconds":1200,
          "maxAttempts":1,
          "onFailure":"Abort",
          "inputs":{
             "FunctionName":{ "Ref": "DecommissionAMIVersionFromAccountsLambda"},
             "Payload":"{\"bucketName\":\"{{ bucketName }}\", \"amiRegionMappingParamName\":\"{{ MetadataParamName }}\", \"templateFileName\":\"{{templateFileName}}\", \"versionToBeDeleted\":\"{{ buildVersion }}\", \"productOSAndVersion\":\"{{ productOSAndVersion }}\", \"productNameAndVersion\":\"{{ productName }}\"}"
          }
       }

    ]
}
DECOMMISSION_AMI_VERSION
}

resource "aws_ssm_document" "run_continuous_inspection" {
  name            = "run_continuous_inspection"
  document_type   = "Automation"
  document_format = "JSON"
  content         = <<RUN_CONTINUOUS_INSPECTION
{
    "description":"This automation document is triggered as part of the continuous vulnerability assessment on all active golden AMIs.",
    "schemaVersion":"0.3",
    "assumeRole":{
             "Fn::GetAtt": [
                 "AutomationServiceRole",
                 "Arn"
             ]
         },
         "parameters": {
               "instanceIDs": {
                 "description": "This parameter contains list of instance-ids on which continuous vulnerability assessment is  performed.",
                 "type": "String"
               },
               "QualysUsername": {
                 "default": "/GoldenAMI/Qualys/QualysUsername",
                 "description": "SSM parameter name of Qualys username to access API",
                 "type": "String"
               },

               "QualysPassword": {
                 "default": "/GoldenAMI/Qualys/QualysPassword",
                 "description": "SSM parameter name of the Qualys password to access API",
                 "type": "String"
               },
               "QualysOptionId": {
                 "default": "/GoldenAMI/Qualys/QualysOptionId",
                 "description": "SSM parameter name of Qualys option id to start scan to access API",
                 "type": "String"
               },

               "QualysScannerName": {
                 "default": "/GoldenAMI/Qualys/QualysScannerName",
                 "description": "SSM parameter name of the Qualys scanner to launch VM scan",
                 "type": "String"
               },

               "QualysApiUrl": {
                 "type": "String",
                 "description": "Your Qualys URL for accessing API",
                 "default": {
                   "Ref":"qualysApiUrl"
                 }
               }
             },

    "mainSteps":[
       {
          "name":"waitForInstance",
          "action":"aws:sleep",
          "inputs":{
             "Duration":"PT01M"
          }
        },
        {
         "maxAttempts": 1,
         "inputs": {
           "Parameters": {
             "commands": [
               "set -e",
               "INSTANCE_IP=$(curl -s 'http://169.254.169.254/latest/meta-data/local-ipv4')",
               "AMI_ID=$(curl -s 'http://169.254.169.254/latest/meta-data/ami-id')",
               "REGION=\"{{global:REGION}}\"",
               "QualysUsername=$(aws ssm get-parameter --with-decryption --region $REGION --name {{QualysUsername}} --query 'Parameter.Value' --output text)",
               "QualysPassword=$(aws ssm get-parameter --with-decryption --region $REGION --name {{QualysPassword}} --query 'Parameter.Value' --output text)",
               "QualysOptionId=$(aws ssm get-parameter --with-decryption --region $REGION --name {{QualysOptionId}} --query 'Parameter.Value' --output text)",
               "QualysScannerName=$(aws ssm get-parameter --with-decryption --region $REGION --name {{QualysScannerName}} --query 'Parameter.Value' --output text)",
               "curl -H \"X-Requested-With: Curl\" -u \"$QualysUsername:$QualysPassword\" -X \"POST\" -d \"action=add&enable_vm=1&enable_pc=1&ips=$INSTANCE_IP\" \"{{QualysApiUrl}}/api/2.0/fo/asset/ip/\"> add-asset-log.txt",
               "curl -H \"X-Requested-With: Curl\" -u \"$QualysUsername:$QualysPassword\" -X \"POST\" -d \"action=launch&scan_title=Golden+AMI+Assessment+amiID+$AMI_ID+{{instanceIDs}}&ip=$INSTANCE_IP&option_id=$QualysOptionId&iscanner_name=$QualysScannerName\" \"{{QualysApiUrl}}/api/2.0/fo/scan/\""
             ]
           },
           "InstanceIds": [
             "{{instanceIDs}}"
           ],
           "DocumentName": "AWS-RunShellScript"
         },
         "name": "LaunchQualysAssessment",
         "action": "aws:runCommand",
         "timeoutSeconds": 3600,
         "onFailure": "Abort"
       },
       {
          "name":"waitForAssessment",
          "action":"aws:sleep",
          "inputs":{
             "Duration":"PT01M"
          }
        },
        {
            "name": "stopAssessmentInstance",
            "action": "aws:changeInstanceState",
            "timeoutSeconds": 1200,
            "maxAttempts": 1,
            "onFailure": "Continue",
            "inputs": {
                "InstanceIds": [
                    "{{instanceIDs}}"
                ],
                "DesiredState": "stopped"
            }
        }
    ]
}
RUN_CONTINUOUS_INSPECTION
}
