#!/bin/bash

# Define the log file location
logfile="/tmp/swap_used_log.json"

# Loop to log swap usage every 5 seconds
while true; do
    # Get the current timestamp in ISO 8601 format
    timestamp=$(date --utc +"%Y-%m-%dT%H:%M:%SZ")

    # Get the swap usage percent using the free command
    swap_used_percent=$(free | grep Swap | awk '{print $3/$2 * 100.0}')

    # Create JSON entry for the swap usage log
    log_entry=$(cat <<EOF
{
  "timestamp": "$timestamp",
  "swap_used_percent": $swap_used_percent
}
EOF
)

    # Log the JSON entry to the logfile
    echo "$log_entry" >> "$logfile"

    # Wait for 5 seconds before the next read
    sleep 5
done
