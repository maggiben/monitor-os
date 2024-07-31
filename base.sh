#!/bin/bash

# File containing the sensor names
SENSORS_LIST_FILE="sensors.txt" # sensor list
SENSOR_WORKDIR="/monitor"
SENSOR_SCRIPT="base.sensor.sh" # sensor script

# Read the sensor names into an array
mapfile -t SENSORS < "$SENSORS_LIST_FILE"

check_sensor_update() {
    local sensor_ip=$1
    local local_file=$2
    local remote_file="$SENSOR_WORKDIR/$(basename $local_file)"

    # Calculate the SHA-256 checksum of the local file
    local_local_hash=$(sha256sum "$local_file" | awk '{ print $1 }')

    # Calculate the SHA-256 checksum of the remote file
    remote_remote_hash=$(ssh "$sensor_ip" sha256sum "$remote_file" | awk '{ print $1 }')

    # Compare the hashes
    if [ "$local_local_hash" != "$remote_remote_hash" ]; then
        return 1
    else
        return 0
    fi
}

# Function to install sensor update
install_sensor_update() {
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

echo "["
# Iterate over each sensor name
for SENSOR_NAME in "${SENSORS[@]}"; do
    # Get the IP address of the sensor from the output of network-devices.sh
    SENSOR_IP=$(sudo docker exec tailscaled tailscale status | grep "$SENSOR_NAME" | awk '{print $1}')
    if [ -n "$SENSOR_IP" ]; then
        check_sensor_update $SENSOR_IP $SENSOR_SCRIPT
        if [ $? -eq 1 ]; then
            install_sensor_update $SENSOR_IP $SENSOR_SCRIPT
        fi
        # Get the base sensor data
        BASE_SENSOR_DATA=$(ssh $SENSOR_IP "cd /$SENSOR_WORKDIR && ./$SENSOR_SCRIPT" 2>/dev/null | srvenv/bin/python capture.sensor.py -s $SENSOR_NAME | jq)
        # echo $BASE_SENSOR_DATA","
        # printf "%b\n" "$BASE_SENSOR_DATA"
        printf "%b\n" "$BASE_SENSOR_DATA, "
    else
        echo "Sensor $SENSOR_NAME not found in network-devices.sh output."
    fi
done
echo  "]"

sleep 120

