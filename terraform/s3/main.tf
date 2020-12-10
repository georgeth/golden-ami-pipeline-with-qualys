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

resource "aws_s3_bucket" "golden_ami_config_bucket" {
  bucket = "golden-ami-config-bucket"
  acl    = "private"
  versioning {
    enabled = true
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AED256"
      }
    }
  }
}

resource "aws_s3_bucket_policy" "golden_ami_config_bucket" {
  bucket = aws_s3_bucket.golden_ami_config_bucket.id
  policy = <<_POLICY
{
    "Statement": [
        {
            "Action": [
                "s3:*"
            ],
            "Effect": "Allow",
            "Resource": [
                {
                    "Fn::Join": [
                        "",
                        [
                            "arn:aws:s3:::",
                            {
                                "Ref": "GoldenAMIConfigBucket"
                            },
                            "/*"
                        ]
                    ]
                },
                {
                    "Fn::Join": [
                        "",
                        [
                            "arn:aws:s3:::",
                            {
                                "Ref": "GoldenAMIConfigBucket"
                            }
                        ]
                    ]
                }
            ],
            "Principal": {
                "AWS": [
                    {
                        "Fn::GetAtt": [
                            "ManagedInstanceRole",
                            "Arn"
                        ]
                    },
                    {
                        "Fn::GetAtt": [
                            "AutomationServiceRole",
                            "Arn"
                        ]
                    },
                    {
                         "Fn::GetAtt": [
                            "PublishAMILambdaRole",
                            "Arn"
                        ]
                    }
                ]
            }
        }
    ]
}
_POLICY
}
