#!/bin/bash
set -euo pipefail

REGION="eu-west-1"
KEY_NAME="jenkins-key"

echo "== Step 2: Terminate the Jenkins EC2 instance =="
INSTANCE_ID=$(aws ec2 describe-instances --region "$REGION" \
    --filters "Name=tag:Name,Values=jenkins-cicd" "Name=instance-state-name,Values=running,stopped" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text
)

if [ "$INSTANCE_ID" != "None" ] && [ -n "$INSTANCE_ID" ]; then
    aws ec2 terminate-instances --region "$REGION" --instance-ids "$INSTANCE_ID"
    echo "  Terminating $INSTANCE_ID, waiting for it to finish..."
    
    aws ec2 wait instance-terminated --region "$REGION" --instance-ids "$INSTANCE_ID"
    echo "  Instance terminated."
else
    echo "  No jenkins-cicd instance found, skipping."
fi

echo "== Step 3: Remove the security group rules this project added =="
VPC_ID=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true \
    --region "$REGION" \
    --query 'Vpcs[0].VpcId' \
    --output text
)
SG_ID=$(aws ec2 describe-security-groups \
    --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values=default \
    --region "$REGION"  \
    --query 'SecurityGroups[0].GroupId' \
    --output text
)

MY_IP="$(curl -s https://checkip.amazonaws.com)/32"
aws ec2 revoke-security-group-ingress --group-id "$SG_ID" --region "$REGION" \
  --protocol tcp --port 22 --cidr "$MY_IP" 2>/dev/null || echo "  Port 22 rule already gone"
aws ec2 revoke-security-group-ingress --group-id "$SG_ID" --region "$REGION" \
  --protocol tcp --port 8080 --cidr 0.0.0.0/0 2>/dev/null || echo "  Port 8080 rule already gone"

echo ""
echo "Done. Two things this script does NOT delete, remove by hand if you want:"
echo "  - The SSH key pair ($KEY_NAME) and the local ${KEY_NAME}.pem file"
echo "  - The S3 state bucket and DynamoDB lock table, only delete these if you"
echo "    won't reuse them for another Terraform project"