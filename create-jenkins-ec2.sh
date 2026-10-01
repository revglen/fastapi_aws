#!/bin/bash

set -euo pipefail

REGION="eu-west-1"
INSTANCE_TYPE="t3.medium"
KEY_NAME="jenkins-key"
VOLUME_SIZE_GB=20
MY_IP="$(curl -s https://checkip.amazonaws.com)/32"

echo "Using the region: $REGION"
echo "Your IP for SSH access: $MY_IP"

set -e

if command -v aws >/dev/null 2>&1; then
    echo "AWS CLI installed: $(aws --version)"
else
    echo "AWS CLI NOT installed"
    exit 1
fi

if aws sts get-caller-identity >/dev/null 2>&1; then
    echo "AWS CLI configured, credentials valid:"
    aws sts get-caller-identity
else
    echo "AWS CLI installed but NOT configured (run 'aws configure')"
    exit 1
fi
# ---- Key pair (skip if it already exists) ----
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" >/dev/null 2>&1; then
    aws ec2 create-key-pair --key-name "$KEY_NAME" --region "$REGION" \
    --query 'KeyMaterial' --output text > "${KEY_NAME}.pem"
    chmod 400 "${KEY_NAME}.pem"
    echo "Created key pair, saved to ${KEY_NAME}.pem"
else
    echo "Key pair $KEY_NAME already exists, skipping creation"
fi

# ---- Default VPC and its default security group ----
VPC_ID=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true \
    --region "$REGION" --query 'Vpcs[0].VpcId' --output text)

SG_ID=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values=default \
  --region "$REGION" --query 'SecurityGroups[0].GroupId' --output text)
echo "Default VPC: $VPC_ID, default security group: $SG_ID"

# ---- Open the ports Jenkins needs (idempotent: ignore "already exists" errors) ----
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --region "$REGION" \
  --protocol tcp --port 8080 --cidr 0.0.0.0/0 2>/dev/null || echo "Port 8080 rule already exists"

aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --region "$REGION" \
  --protocol tcp --port 22 --cidr "$MY_IP" 2>/dev/null || echo "Port 22 rule already exists"

# ---- Latest Ubuntu 22.04 AMI ----
AMI_ID=$(aws ssm get-parameters --region "$REGION" \
--names /aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id \
--query 'Parameters[0].Value' --output text)
echo "Using AMI: $AMI_ID"

# ---- Launch the instance ----
INSTANCE_ID=$(aws ec2 run-instances \
    --region "$REGION" \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --block-device-mappings "
    [{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":${VOLUME_SIZE_GB},\"VolumeType\":\"gp3\"}}]" \
    --user-data file://jenkins-user-data.sh \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=jenkins-cicd}]' \
    --query 'Instances[0].InstanceId' --output text
)

echo "Launched instance: $INSTANCE_ID"
echo "Waiting for it to enter running state..."

aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_ID"

PUBLIC_IP=$(aws ec2 describe-instances --region "$REGION" --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo ""
echo "Instance is running."
echo "Public IP: $PUBLIC_IP"
echo "Jenkins will take 3-5 minutes to finish installing. Then visit:"
echo "  http://${PUBLIC_IP}:8080"
echo ""
echo "SSH in with:  ssh -i ${KEY_NAME}.pem ubuntu@${PUBLIC_IP}"
echo "Get the initial admin password with:"
echo "  ssh -i ${KEY_NAME}.pem ubuntu@${PUBLIC_IP} 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'"