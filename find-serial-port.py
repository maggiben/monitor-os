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

def print_serial_port():
    # Find the first available serial port
    serial_port = find_serial_port()
    print(serial_port)
if __name__ == "__main__":
    print_serial_port()
