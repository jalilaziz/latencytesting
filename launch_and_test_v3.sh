#!/bin/bash

# Define parameters
AMI_ID="ami-061a125c7c02edb39" # Replace with the latest Amazon Linux 2 AMI ID for Tokyo
INSTANCE_TYPE="t2.micro"
KEY_NAME="LatencyTesting" # Replace with your key pair name
SECURITY_GROUP_IDS="sg-0c5747c8e9a83a8a5" # Replace with your security group ID
SUBNET_IDS=("subnet-0d52f57a224ba5ea9" "subnet-0f48cf2f68fbd4749" "subnet-0a1df730283fb2767") # Replace with your subnet IDs for each AZ
PLACEMENT_GROUPS=("ClusterPG1" "ClusterPG2" "ClusterPG3")
AZS=("ap-northeast-1a" "ap-northeast-1c" "ap-northeast-1d")
REGION="ap-northeast-1"

# Create placement groups
create_placement_groups() {
  for PG in "${PLACEMENT_GROUPS[@]}"; do
    aws ec2 create-placement-group --group-name "$PG" --strategy cluster --region "$REGION"
    echo "Created placement group $PG"
  done
}

# Launch instances in each placement group and AZ
launch_instances() {
  for i in "${!PLACEMENT_GROUPS[@]}"; do
    PG="${PLACEMENT_GROUPS[$i]}"
    AZ="${AZS[$i]}"
    SUBNET_ID="${SUBNET_IDS[$i]}"

    echo "Launching instance in $AZ with placement group $PG..."
    INSTANCE_ID=$(aws ec2 run-instances \
      --image-id "$AMI_ID" \
      --count 1 \
      --instance-type "$INSTANCE_TYPE" \
      --key-name "$KEY_NAME" \
      --security-group-ids "$SECURITY_GROUP_IDS" \
      --subnet-id "$SUBNET_ID" \
      --placement "GroupName=$PG,AvailabilityZone=$AZ" \
      --query 'Instances[0].InstanceId' \
      --output text \
      --region "$REGION")

    echo "Instance $INSTANCE_ID launched in $AZ with placement group $PG"

    # Optional: Wait until instance is running
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"
    echo "Instance $INSTANCE_ID is running"
  done
}

# Perform latency testing
perform_latency_testing() {
  BINANCE_API_ENDPOINT="wss://stream.binance.com/stream?streams=btcusdt@bookTicker"
  NUM_PINGS=100

  for i in "${!PLACEMENT_GROUPS[@]}"; do
    PG="${PLACEMENT_GROUPS[$i]}"
    AZ="${AZS[$i]}"
    SUBNET_ID="${SUBNET_IDS[$i]}"

    INSTANCE_ID=$(aws ec2 describe-instances \
      --filters "Name=placement-group-name,Values=$PG" \
      --query "Reservations[*].Instances[*].InstanceId" \
      --output text \
      --region "$REGION")

    PUBLIC_IP=$(aws ec2 describe-instances \
      --instance-ids "$INSTANCE_ID" \
      --query "Reservations[0].Instances[0].PublicIpAddress" \
      --output text \
      --region "$REGION")

    echo "Testing latency for instance $INSTANCE_ID in $PG at $PUBLIC_IP"

    TOTAL_TIME=0
    for _ in $(seq 1 $NUM_PINGS); do
      START_TIME=$(date +%s%N | cut -b1-13)
      curl -s -o /dev/null -w "%{time_connect}" "$BINANCE_API_ENDPOINT"
      END_TIME=$(date +%s%N | cut -b1-13)
      LATENCY=$((END_TIME - START_TIME))
      TOTAL_TIME=$((TOTAL_TIME + LATENCY))
    done
    AVG_LATENCY=$((TOTAL_TIME / NUM_PINGS))
    echo "Placement Group: $PG, Availability Zone: $AZ, Average Latency: $AVG_LATENCY ms" >> /var/log/latency_test_result.log
  done
}

# Main function
main() {
  create_placement_groups
  launch_instances
  perform_latency_testing
}

main
