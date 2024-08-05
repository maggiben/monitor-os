#!/bin/bash

# Initialize an associative array to store the maximum flow values for each plant
declare -A max_flows

# Infinite loop to check the status every second
while true; do
    # Execute the Python command and capture the output
    output=$(python3 serial-ping.py -m watering-status 2>/dev/null)
  
    if [ -n "$output" ]; then
        echo $output
        # Extract plant and flow values from the output
        plant=$(echo "$output" | awk -F'>' '{print $2}' | awk -F' ' '{print $2}')
        flow=$(echo "$output" | awk -F'>' '{print $2}' | awk -F' ' '{print $6}')
    
        # Update the max flow value for the plant if the current flow is greater
        if [ -n "$plant" ] && [ -n "$flow" ]; then
            if [ -z "${max_flows[$plant]}" ] || [ "$flow" -gt "${max_flows[$plant]}" ]; then
                max_flows[$plant]=$flow
            fi
        fi
        # Extract the numeric value from the output using awk
        status_value=$(echo "$output" | awk -F'>' '{print $2}' | awk -F' ' '{print $4}')
  
        # Check if status_value is not empty before comparing
        if [ -n "$status_value" ] && [ "$status_value" -eq 128 ]; then
            break
        fi
    else
        # Wait for 1 second before checking again
        sleep 1
    fi
done
# Prepare the final message with the max flow values for each plant
message="😀 I finished watering the plants:"
for plant in "${!max_flows[@]}"; do
  message+=" plant $plant (${max_flows[$plant]}ml)"
done

./pyenv/bin/python3 ./telegram-bot.py "$message"

echo -e "$message"

