#!/bin/bash

# Define the PID file path
PIDFILE="/tmp/watering/serial.pid"
ALARMPIDFILE="/tmp/watering/alarm.pid"
LOGDIR="./logs"
ALARM_JOB_ID=""
PIDDIR=$(dirname "$PIDFILE")

function create_dir_if_not() {
    # Create the directory if it does not exist
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
        # Optionally, set permissions on the directory
        chmod 755 "$1"
        echo "Pid file created!"
    fi
}

# Check if the PID file exists and if the process is still running
if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
    echo "The application is already running."
    exit 1
fi

create_dir_if_not $PIDDIR
# Write the PID to the file
echo $$ > "$PIDFILE"

# Define a cleanup function
cleanup() {
    echo "Cleaning up..."
    atrm $ALARM_JOB_ID
    rm -f "$PIDFILE"
    rm -f "$ALARMPIDFILE"
    exit
}

# Function to get the next alarm in minutes
function get_next_alarm_minutes() {
    local next_alarm=$(python3 serial-ping.py -m next-alarm 2>/dev/null | awk -F'>' '{print $2}' | awk -F' ' '{print int(($2 + 59) / 60)}')
    local watering_time=$(python3 serial-ping.py -m get-watering-time 2>/dev/null | awk -F'>' '{print $2}' | awk -F' ' '{print int(($2 + 59) / 60)}')
    local next_timer=$(($next_alarm + $watering_time + 1))
    echo "Next alarm: $next_alarm"
    echo "Watering time: $watering_time"
    echo "Next timer: $next_timer"
    return $next_timer
}

# Function to check if an alarm (job) ID is running
check_alarm_running() {
    if [ ! -f "$ALARMPIDFILE" ]; then
        return 1
    fi

    local job_id=$(cat $ALARMPIDFILE);

    # Get the list of scheduled jobs and check if the job ID is present
    atq | grep -q "^$job_id"
  
    # Check the exit status of grep
    if [ $? -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

function run_alarm() {
    get_next_alarm_minutes
    local minutes=$?
    # remove old task data
    local job_id=$(echo "python3 serial-ping.py -m read-task > read-task.txt && rm -f $ALARMPIDFILE && rm -f next-timer.txt" | at now + $minutes minutes 2>&1 | awk '/job/ {print $2}')
    # Extract the job ID from the output
    echo "Alarm will trigger in $minutes minutes from now"
    echo $job_id > "$ALARMPIDFILE"
    # Return
    return $job_id
}

# Check flow function
function check_flow() {
    # Check if read-task.txt exists and is non-empty
    if [ ! -f "read-task.txt" ] || [ ! -s "read-task.txt" ]; then
        return 1
    else
        echo "read-task.txt created flow: [ $(cat read-task.txt | grep -oP 'flow: \[\K[^\]]+') ]"
    fi
    if [ ! -f "last-flow.txt" ]; then
        cat "last-flow.txt" > "last-flow.txt"
    fi

    # Extract the flow values from the output
    local flow=$(cat "read-task.txt" | grep -oP 'flow: \[\K[^\]]+')

    # Read the last flow values from last-flow.txt
    local last_flow=$(cat "last-flow.txt" | grep -oP 'flow: \[\K[^\]]+')

    # Convert the flow values and last flow values to arrays
    IFS=' ' read -r -a current_flow <<< "${flow//[^0-9 ]/}"
    IFS=' ' read -r -a last_flow_array <<< "${last_flow//[^0-9 ]/}"

    
    
    # Calculate the delta change
    local message=""
    local delta=()
    for i in ${!current_flow[@]}; do
        local ml=$((current_flow[i] - last_flow_array[i] | 0))
        delta[i]=$ml
        message="$message Plant $i: {$ml}ml"
    done

    
    local telegram_message="🪴💧 Ive finished watering the plants: $message"
    echo $telegram_message;

    # Call the Telegram bot script with the delta change message
    ./pyenv/bin/python3 ./telegram-bot.py "$telegram_message"

    # Write the new flow values to last-flow.txt
    cat "read-task.txt" > "last-flow.txt"
    
    # Archive the old last-flow.txt file
    mv read-task.txt "$LOGDIR/$(date +flow-%Y%m%d%H%M%S).txt"

    return 0
}


# Trap termination signals to run the cleanup function
trap cleanup SIGINT SIGTERM

# Main application logic
echo "Application started with PID $$"
while true; do
    check_flow
    if [ ! $? -eq 1 ]; then
        echo "Flow: $(cat last-flow.txt)"
    fi
    # Check if alarm is running
    check_alarm_running
    if [ $? -eq 1 ]; then
        # Create a new alarm if none is running
        run_alarm
        ALARM_JOB_ID=$?
        echo "New alarm: $ALARM_JOB_ID created"
    else
        # If already running then just echo the id
        ALARM_JOB_ID=$(cat $ALARMPIDFILE)
        echo "Alarm $ALARM_JOB_ID is running"
    fi
    # Sleep 
    sleep 1
done

# Clean up on exit
cleanup

