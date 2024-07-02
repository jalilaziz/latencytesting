#!/bin/bash

# Binance WebSocket API endpoint
BINANCE_API_ENDPOINT="wss://stream.binance.com/stream?streams=btcusdt@bookTicker"

# Number of pings to perform
NUM_PINGS=100

# Function to perform latency test
test_latency() {
  TOTAL_TIME=0
  for i in $(seq 1 $NUM_PINGS); do
    START_TIME=$(date +%s%N | cut -b1-13)
    curl -s -o /dev/null -w "%{time_connect}" $BINANCE_API_ENDPOINT
    END_TIME=$(date +%s%N | cut -b1-13)
    LATENCY=$((END_TIME - START_TIME))
    TOTAL_TIME=$((TOTAL_TIME + LATENCY))
    echo "Latency: $LATENCY ms" >> /var/log/latency_test_result.log
  done
  AVG_LATENCY=$((TOTAL_TIME / NUM_PINGS))
  echo "Average Latency: $AVG_LATENCY ms" >> /var/log/latency_test_result.log
}

# Run the latency test
test_latency

echo "Latency testing complete."
echo "Average Latency: $AVG_LATENCY ms Ou"
