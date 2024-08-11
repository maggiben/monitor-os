#!/bin/bash
VERSION="0.0.6"
HOSTNAME=$(hostname)
# Get the name of the script
SCRIPT_FILE_NAME=$(basename $0)
# Function to convert bytes to human-readable format
convert_to_human_readable() {
    local BYTES=$1
    local UNIT="B"
    local VALUE=$BYTES

    if [ $BYTES -ge 1073741824 ]; then
        UNIT="GB"
        VALUE=$(echo "$BYTES / 1073741824" | bc -l)
    elif [ $BYTES -ge 1048576 ]; then
        UNIT="MB"
        VALUE=$(echo "$BYTES / 1048576" | bc -l)
    elif [ $BYTES -ge 1024 ]; then
        UNIT="KB"
        VALUE=$(echo "$BYTES / 1024" | bc -l)
    fi

    # Round to 2 decimal places
    printf "%.2f %s" $VALUE $UNIT
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

# Get the temperature
TEMPERATURE=$(vcgencmd measure_temp 2>/dev/null | awk -F'=' '{print $2}')
# Print the results
echo "[$HOSTNAME:sensors]"
echo "temperature: $TEMPERATURE"

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
echo "RX: $(convert_to_human_readable $RX_BYTES)"
echo "TX: $(convert_to_human_readable $TX_BYTES)"
echo $PING_TIME

# Get system uptime
UPTIME=$(uptime)
DATE=$(date --iso-8601=seconds)
echo "[$HOSTNAME:uptime]"
echo "uptime: $UPTIME"
echo "date: $DATE"

