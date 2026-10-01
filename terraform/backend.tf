terraform {
  required_version = ">= 1.6.0"

  # This bucket and the DynamoDB lock table are created automatically by the
  # Jenkinsfile's "Bootstrap Terraform state backend" stage before this ever
  # runs, using create-tfstate-bucket.sh. If you ever change the bucket name
  # here, update TFSTATE_BUCKET in the Jenkinsfile to match exactly.
  backend "s3" {
    bucket         = "fastapi-cicd-tfstate-revglen"
    key            = "fastapi-cicd/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
