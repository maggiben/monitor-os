import time
import serial
import argparse
import glob
import sys

def find_serial_port():
    ports = glob.glob('/dev/ttyUSB*')
    for port in ports:
        try:
            ser = serial.Serial(port, 115200, timeout=1)
            ser.close()  # Close the port if it opens successfully
            return port
        except serial.SerialException:
            continue
    return None

def send_ping_and_get_response():
    try:
        # Command line parse
        parser = argparse.ArgumentParser(description='Serial Command Interface')
        parser.add_argument('-m', '--message', required=False, help='Message to send to the serial port')
        parser.add_argument('-r', '--retries', type=int, default=3, help='Number of retries for the serial communication (default=3)')
        args = parser.parse_args()

        retries = args.retries

        # Send the message and wait for a response, with retries
        command = args.message or 'ping'
        response = None

        for attempt in range(retries):
            # Find the first available serial port
            serial_port = find_serial_port()
            if serial_port is None:
                print(f"Attempt {attempt + 1}: No available serial port found.", file=sys.stderr)
                time.sleep(1)  # Wait before retrying
                continue

            try:
                # Open the serial port
                ser = serial.Serial(serial_port, 115200, timeout=1)
                time.sleep(2)  # Wait for the serial connection to initialize

                ser.write(f"{command}\n".encode())

                # Wait for a response
                response = ser.readline().decode(errors='ignore').strip()

                # Close the serial port
                ser.close()

                if response: 
                    print(response)
                    return 0  # Exit with status 0 indicating success
                else:
                    print(f"Attempt {attempt + 1} failed, on serial port {serial_port} retrying...", file=sys.stderr)

            except serial.SerialException as e:
                print(f"Attempt {attempt + 1}: Error opening or using the serial port: {e}", file=sys.stderr)

        if not response:
            print("No response received after retries.", file=sys.stderr)
            return 1  # Exit with status 1 indicating failure

    except serial.SerialException as e:
        print(f"Error during serial communication: {e}", file=sys.stderr)
        return 1  # Exit with status 1 indicating failure

if __name__ == "__main__":
    exit_code = send_ping_and_get_response()
    sys.exit(exit_code)
