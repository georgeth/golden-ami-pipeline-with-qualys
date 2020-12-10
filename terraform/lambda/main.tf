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

data "archive_file" "config_permission_to_call_lambda" {
  type        = "zip"
  output_path = "${path.module}/config_permission_to_call_lambda.zip"
  source {
    filename = "index.js"
    content  = <<CONFIG_PERMISSION_TO_CALL_LAMBDA
'use strict';
const aws = require('aws-sdk');
const config = new aws.ConfigService();
const ssm = new aws.SSM();
function check(reference, referenceName) {
    if (!reference) { throw new Error(`Error: ${referenceName} is not defined`);}
    return reference;
}
function isOverSized(messageType) {
    check(messageType, 'messageType');
    return messageType === 'OversizedConfigurationItemChangeNotification';
}
function getConfiguration(resourceType, resourceId, captureTime, callback) {
    config.getResourceConfigHistory({ resourceType, resourceId, laterTime: new Date(captureTime), limit: 1 }, (err, data) => {
        if (err) {callback(err, null);}
        const cfgItem = data.configurationItems[0];
        callback(null, cfgItem);
    });}
function convertApiConfiguration(apiCFG) {
    apiCFG.awsAccountId = apiCFG.accountId;
    apiCFG.ARN = apiCFG.arn;
    apiCFG.configurationStateMd5Hash = apiCFG.configurationItemMD5Hash;
    apiCFG.configurationItemVersion = apiCFG.version;
    apiCFG.configuration = JSON.parse(apiCFG.configuration);
    if ({}.hasOwnProperty.call(apiCFG, 'relationships')) {
        for (let i = 0; i < apiCFG.relationships.length; i++) {
            apiCFG.relationships[i].name = apiCFG.relationships[i].relationshipName;
        }}
    return apiCFG;
}
function getConfigurationItem(invokingEvent, callback) {
    check(invokingEvent, 'invokingEvent');
    if (isOverSized(invokingEvent.messageType)) {
        const configurationItemSummary = check(invokingEvent.configurationItemSummary, 'configurationItemSummary');
        getConfiguration(configurationItemSummary.resourceType, configurationItemSummary.resourceId, configurationItemSummary.configurationItemCaptureTime, (err, apiConfigurationItem) => {
            if (err) {callback(err);}
            const configurationItem = convertApiConfiguration(apiConfigurationItem);
            callback(null, configurationItem);
        });} else {
        check(invokingEvent.configurationItem, 'configurationItem');
        callback(null, invokingEvent.configurationItem);
    }
}
function isApplicable(cfgItem, event) {
    check(cfgItem, 'configurationItem');
    check(event, 'event');
    const status = cfgItem.configurationItemStatus;
    const eventLeftScope = event.eventLeftScope;
    return (status === 'OK' || status === 'ResourceDiscovered') && eventLeftScope === false;
}
function checkCompliance(cfgItem, amiIDsApproved) {
    check(cfgItem, 'configurationItem');
    check(cfgItem.configuration, 'configurationItem.configuration');
    check(amiIDsApproved, 'amiIDsApproved');
    if (cfgItem.resourceType !== 'AWS::EC2::Instance') {return 'NOT_APPLICABLE';} else if (amiIDsApproved.indexOf(cfgItem.configuration.imageId) !== -1) {return 'COMPLIANT';}
    return 'NON_COMPLIANT';
}
exports.handler = (event, context, callback) => {
    check(event, 'event');
    const invokingEvent = JSON.parse(event.invokingEvent);
    const ruleParameters = JSON.parse(event.ruleParameters);
    const params = { Names: [ruleParameters.parameterName ],WithDecryption:false };
    ssm.getParameters(params, function(err, data) {
    if (err) console.log(err, err.stack);
    else{
        var amiIDsApproved =data.Parameters[0].Value;
        getConfigurationItem(invokingEvent, (err, cfgItem) => {
        if (err) {callback(err);}
        let compliance = 'NOT_APPLICABLE';
        const putEvaluationsRequest = {};
        if (isApplicable(cfgItem, event)) {compliance = checkCompliance(cfgItem, amiIDsApproved);}
        putEvaluationsRequest.Evaluations = [{ComplianceResourceType: cfgItem.resourceType,ComplianceResourceId: cfgItem.resourceId,ComplianceType: compliance,OrderingTimestamp: cfgItem.configurationItemCaptureTime,},];
        putEvaluationsRequest.ResultToken = event.resultToken;
        config.putEvaluations(putEvaluationsRequest, (error, data) => {
            if (error) { callback(error, null);}
            else if (data.FailedEvaluations.length > 0) {callback(JSON.stringify(data), null);}
            else {callback(null, data);}
        });});}});};
CONFIG_PERMISSION_TO_CALL_LAMBDA
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = <<_LAMBDA_ROLE
{
    "Version": "2012-10-17",
    "Statement": {
        "Action": ["ssm:Get*"],
        "Effect": "Allow",
        "Resource": 
          { "Fn::Join": 
            [
                "",
                [
                    "arn:aws:ssm:", "*",
                    ":",
                    {
                        "Ref":"AWS::AccountId"
                    },
                    ":parameter/GoldenAMI/latest"
                ]
            ]}                    
      } 
}
_LAMBDA_ROLE
}

resource "aws_lambda_function" "check_if_non_golden_ami_exist" {
  function_name = "check_if_non_golden_ami_exist"
  filename      = data.archive_file.config_permission_to_call_lambda.output_path
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "index.handler"
  runtime       = "nodejs4.3"
  timeout       = 30
}

resource "aws_lambda_permission" "config_permission_to_call_lambda" {
  function_name = aws_lambda_function.check_if_non_golden_ami_exist.function_name
  action        = "lambda:InvokeFunction"
  principal     = "config.amazonaws.com"
}
