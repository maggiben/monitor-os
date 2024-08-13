#!/bin/bash

# File containing the sensor names
SENSORS_LIST_FILE="sensors.txt" # sensor list
SENSOR_WORKDIR="/monitor"
SENSOR_SCRIPT="base.sensor.sh" # sensor script
API_ENDPOINT="http://localhost:3001/api/devices/generate"
# Get the name of the parent process
PPID_NAME=$(ps -o comm= $PPID)
# Delay between data snapshots
SLEEP=600

# Read the sensor names into an array
mapfile -t SENSORS < "$SENSORS_LIST_FILE"

function check_systemd_sleep() {
    # Check if the script was called by systemd
    if [ "$PPID_NAME" = "systemd" ]; then
        sleep $SLEEP  # or any sleep duration you need
    fi
}

function check_sensor_update() {
    local sensor_ip=$1
    local local_file=$2
    local remote_file="$SENSOR_WORKDIR/$(basename $local_file)"

    # Calculate the SHA-256 checksum of the local file
    local local_local_hash=$(sha256sum "$local_file" | awk '{ print $1 }')

    # Calculate the SHA-256 checksum of the remote file
    local remote_remote_hash=$(ssh "$sensor_ip" sha256sum "$remote_file" | awk '{ print $1 }')

    # Compare the hashes
    if [ "$local_local_hash" != "$remote_remote_hash" ]; then
        return 1
    else
        return 0
    fi
}

# Function to install sensor update
function install_sensor_update() {
  local sensor_ip=$1
  local local_file=$2
  local remote_file="/monitor/$(basename $local_file)"

  # Compress the local file
  gzip -c "$local_file" > "$local_file.gz"

  # Use scp to copy the compressed file to the remote server
  scp "$local_file.gz" "$sensor_ip:$remote_file.gz" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    # Decompress the file on the remote server
    ssh "$sensor_ip" "gunzip -f $remote_file.gz && chmod 755 $remote_file"
    if [ $? -eq 0 ]; then
        rm "$local_file.gz" # Clean up the local compressed file
        return 0 # success
    else
        return 1 # fail to decompress
    fi
  else
    rm "$local_file.gz" # Clean up the local compressed file if scp fails
    return 1 # fail to copy
  fi
}

function get_sensor_data() {
    local first=true  # Flag to check if it's the first item
    echo "["
    # Iterate over each sensor name
    for SENSOR_NAME in "${SENSORS[@]}"; do
        # Get the IP address of the sensor from the output of network-devices.sh
        local sensor_ip=$(sudo docker exec tailscaled tailscale status | grep "$SENSOR_NAME\s" | awk '{print $1}')
        if [ -n "$sensor_ip" ]; then
            check_sensor_update $sensor_ip $SENSOR_SCRIPT
            if [ $? -eq 1 ]; then
                install_sensor_update $sensor_ip $SENSOR_SCRIPT
            fi
            # Get the base sensor data
            local base_sensor_data=$(ssh $sensor_ip "cd $SENSOR_WORKDIR && ./$SENSOR_SCRIPT" 2>/dev/null | srvenv/bin/python capture.sensor.py -s $SENSOR_NAME)
            # Add a comma if it's not the first item
            if [ "$first" = true ]; then
                first=false
            else
                printf ",\n"
            fi

            printf "%b\n" "$base_sensor_data"
        else
            # echo "Sensor $SENSOR_NAME not found in network-devices.sh output."
            return 1
        fi
    done
    echo  "]"
    return 0
}

sensor_data=$(get_sensor_data)
if [ $? -eq 0 ]; then
    # echo $sensor_data
    # Save to DB
    echo $sensor_data
    curl -s -X 'POST' \
        "${API_ENDPOINT}" \
        -H 'accept: application/json' \
        -H 'Content-Type: application/json' \
        --data-binary "$sensor_data" >> /dev/null | jq
fi



check_systemd_sleep
