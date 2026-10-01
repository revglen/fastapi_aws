terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket         = "REPLACE_WITH_YOUR_TF_STATE_BUCKET"
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