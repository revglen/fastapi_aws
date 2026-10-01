#!/bin/bash
# Run this ONCE, before the first `terraform init`. Creates the S3 bucket and
# DynamoDB table that terraform/backend.tf needs to store its own state.
# This can't be done by Terraform itself, it can't create the bucket it then
# needs to use to store the record of having created it.
set -euo pipefail

REGION="eu-west-1"
BUCKET_NAME="${1:-}"

if [ -z "$BUCKET_NAME" ]; then
    echo "Usage: ./create-tfstate-bucket.sh <globally-unique-bucket-name>"
    echo "Example: ./create-tfstate-bucket.sh fastapi-cicd-tfstate-revglen"
    exit 1
fi

echo "== Creating S3 bucket: $BUCKET_NAME =="
if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null; then
    echo "  Bucket already exists, skipping creation"
else
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION"
    echo "  Created."
fi

echo "== Enabling versioning (lets you recover a previous state file) =="
aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --region "$REGION" \
    --versioning-configuration Status=Enabled

echo "== Blocking public access (state files can contain sensitive values) =="
aws s3api put-public-access-block --bucket "$BUCKET_NAME" --region "$REGION" \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "== Creating DynamoDB lock table: terraform-locks =="
if aws dynamodb describe-table --table-name terraform-locks --region "$REGION" >/dev/null 2>&1; then
    echo "  Table already exists, skipping creation"
else
    aws dynamodb create-table --table-name terraform-locks --region "$REGION" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST
    echo "  Created."
fi

echo ""
echo "Done. Now put this exact bucket name into terraform/backend.tf:"
echo "  bucket = \"$BUCKET_NAME\""
