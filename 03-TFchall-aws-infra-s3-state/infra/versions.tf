####################################################
# Define terraform versions and required providers 
####################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "30days-tfchall-infra-aws-state"
    key = "infra.tfstate"
    region = "eu-west-3"
    dynamodb_table = "tf-state-lock"
    encrypt = true
  }
}