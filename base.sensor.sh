#!/bin/bash
VERSION="0.0.6"
HOSTNAME=$(hostname)
# Get the name of the script
SCRIPT_FILE_NAME=$(basename $0)
PENV=/home/bmaggi/.platformio/penv/bin

# Function to process last-flow.txt and generate the output string
function process_flow_file() {
    local file_name="last-flow.txt"
    local message=""
  
    # Check if the file exists
    if [[ -f $file_name ]]; then
    # Read the file contents
    local file_content
    file_content=$(<"$file_name")

    # Extract the flow values using a regular expression
    if [[ $file_content =~ flow:\ \[(.*)\] ]]; then
        # Get the captured group with flow values
        local flow_values="${BASH_REMATCH[1]}"

        # Convert flow values into an array
        IFS=', ' read -r -a flow_array <<< "$flow_values"

        # Loop through the flow array and generate the output string
        for i in "${!flow_array[@]}"; do
            message+="plant_$i: ${flow_array[$i]}\n"
        done

        # Print the generated message
        echo "$message"
        return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

function get_sensor_data() {
    if [[ $HOSTNAME == *"weather"* ]]; then # only run if hostname contains the word weather for weather monitoring stations
        # Run the sensor command and capture its output
        local sensor_output=$($PENV/python3 /garden-weather/serial-command.py -m "get-sensor" 2> /dev/null)
        
        # Extract and display the values for humidity, temperature, and soil moisture sensors
        local humidity=$(echo "$sensor_output" | grep -oP '(?<=humidity: )\S+')
        local temperature=$(echo "$sensor_output" | grep -oP '(?<=temperature: )\S+')

        echo "humidity: $humidity"
        echo "temperature: $temperature"

        # Loop through the soil moisture sensors
        for i in {0..3}; do
            soil_moisture=$(echo "$sensor_output" | grep -oP "(?<=soil_moisture_$i: )\S+")
            echo "soil_moisture_$i: $soil_moisture"
        done
    else
        # Get the temperature
        local temperature=$(vcgencmd measure_temp 2>/dev/null | awk -F'=' '{print $2}')
        echo "temperature: $temperature"
    fi
}

# Script info
SCRIPT_UPDATE_TIME=$(stat -c %y $SCRIPT_FILE_NAME)
echo "[$HOSTNAME:script]"
echo "version: $VERSION"
echo "file: $SCRIPT_FILE_NAME"
echo "last_update: $SCRIPT_UPDATE_TIME"

# Get the size of /snapshots
SNAPSHOT_SIZE=$(du -hs /snapshots 2>/dev/null | awk '{print $1}')
SNAPSHOT_TOTAL=$(ls /snapshots | grep jpg | wc -l 2>/dev/null)
# Print the results
echo "[$HOSTNAME:snapshots]"
echo "size: $SNAPSHOT_SIZE"
echo "total: $SNAPSHOT_TOTAL"

# Get the available space on the root partition
AVAILABLE_SPACE=$(df -Bh / 2>/dev/null | grep -E '^/dev' | awk -F' ' '{print "total:", $2} {print "used:", $3} {print "free: " $4} {print "usage: " $5}')
# Print the results
echo "[$HOSTNAME:hdd]"
printf "%b\n" "$AVAILABLE_SPACE"

# Get Sensor data
echo "[$HOSTNAME:sensors]"
get_sensor_data

# Get Watering flow status TODO: move to special host scritps
if [[ $HOSTNAME == "indoor-smart-water" ]]; then
    FLOW=$(process_flow_file)
    if [ $? -eq 0 ]; then
        # Print the results
        echo "[$HOSTNAME:flow]"
        printf "%b\n" "$FLOW"
    fi
fi

# Get the load averages
# Get the number of CPU cores
CPU_CORES=$(nproc)

# Extract load averages from uptime command
CPU_LOAD_AVERAGES=$(uptime | awk -F'load average: ' '{print $2}' | tr -d ' ')

# Extract individual load averages
CPU_LOAD_1=$(echo $CPU_LOAD_AVERAGES | cut -d, -f1)
CPU_LOAD_5=$(echo $CPU_LOAD_AVERAGES | cut -d, -f2)
CPU_LOAD_15=$(echo $CPU_LOAD_AVERAGES | cut -d, -f3)

# Calculate CPU utilization for each load average
CPU_LOAD_AVERAGE_1=$(awk -v cores=$CPU_CORES '{print ($1 / cores) * 100}' <<< "$CPU_LOAD_1")
CPU_LOAD_AVERAGE_5=$(awk -v cores=$CPU_CORES '{print ($1 / cores) * 100}' <<< "$CPU_LOAD_5")
CPU_LOAD_AVERAGE_15=$(awk -v cores=$CPU_CORES '{print ($1 / cores) * 100}' <<< "$CPU_LOAD_15")

# Print the results
echo "[$HOSTNAME:cpu]"
echo "load_avg_1m: $CPU_LOAD_AVERAGE_1"
echo "load_avg_5m: $CPU_LOAD_AVERAGE_5"
echo "load_avg_15m: $CPU_LOAD_AVERAGE_15"

 # Get the RAM status
RAM_STATUS=$(free 2>/dev/null | grep Mem)
RAM_TOTAL=$(echo $RAM_STATUS | awk '{print $2}')
RAM_USED=$(echo $RAM_STATUS | awk '{print $3}')
RAM_FREE=$(echo $RAM_STATUS | awk '{print $4}')
# Print the results
echo "[$HOSTNAME:ram]"
echo "total: $RAM_TOTAL"
echo "used: $RAM_USED"
echo "free: $RAM_FREE"

# Get network throughput
# Network interface (usually wlan0 for WiFi)
INTERFACE="wlan0"
RX_BYTES=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes) # Fetch RX bytes
TX_BYTES=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes) # Fetch TX bytes
PING_TIME=$(ping -c 1 google.com | awk -F'[ =]' '/time=/{print "ping:", $11"ms"}')
# Print the results
echo "[$HOSTNAME:network]"
echo "RX: $RX_BYTES"
echo "TX: $TX_BYTES"
echo $PING_TIME

# Get system uptime
UPTIME=$(uptime)
DATE=$(date --iso-8601=seconds)
echo "[$HOSTNAME:uptime]"
echo "uptime: $UPTIME"
echo "date: $DATE"

