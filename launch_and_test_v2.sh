#!/bin/bash

# Define Availability Zones
AZS=("ap-northeast-1a" "ap-northeast-1c" "ap-northeast-1d")

# Define common variables
AMI_ID="ami-061a125c7c02edb39" # Update with the latest Amazon Linux 2 AMI ID for Tokyo
INSTANCE_TYPE="t2.micro"
KEY_NAME="LatencyTesting" # Update with your key pair name
SECURITY_GROUP_ID="sg-0c5747c8e9a83a8a5" # Update with your security group ID
SUBNET_ID="subnet-0f48cf2f68fbd4749" # Update with your subnet ID

# Binance WebSocket API endpoint
BINANCE_API_ENDPOINT="wss://stream.binance.com/stream?streams=btcusdt@bookTicker"

# Number of pings to perform
NUM_PINGS=100

# Function to perform latency test
test_latency() {
  local ip=$1
  for i in $(seq 1 $NUM_PINGS); do
    START_TIME=$(date +%s%N | cut -b1-13)
    curl -s -o /dev/null -w "%{time_connect}" $BINANCE_API_ENDPOINT
    END_TIME=$(date +%s%N | cut -b1-13)
    LATENCY=$((END_TIME - START_TIME))
    TOTAL_TIME=$((TOTAL_TIME + LATENCY))
    echo "Latency to $ip: $LATENCY ms"
    AVG_LATENCY=$((TOTAL_TIME / NUM_PINGS))
  done
}

# Launch instances in each Availability Zone and perform latency test
for AZ in "${AZS[@]}"; do
  echo "Launching instance in $AZ..."
  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP_ID \
    --subnet-id $SUBNET_ID \
    --region ap-northeast-1 \
    --placement AvailabilityZone=$AZ \
    --query 'Instances[0].InstanceId' \
    --output text)

  echo "Waiting for instance $INSTANCE_ID to be running..."
  aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region ap-northeast-1

  INSTANCE_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text \
    --region ap-northeast-1)

  echo "Instance $INSTANCE_ID is running with IP $INSTANCE_IP"
  echo "Testing latency to Binance API from $INSTANCE_IP..."
  test_latency $INSTANCE_IP

  echo "Terminating instance $INSTANCE_ID..."
  aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region ap-northeast-1
  aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID --region ap-northeast-1
  echo "Instance $INSTANCE_ID terminated."
  echo "Availability Zone: $AZ, Average Latency: $AVG_LATENCY ms"
done

echo "Latency testing complete."

