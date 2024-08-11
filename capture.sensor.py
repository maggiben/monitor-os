import sys
import json
import datetime
import argparse
from pymongo import MongoClient

# Function to parse the input data
def parse_input(input_data, sensor_name):
    lines = input_data.strip().split("\n")
    data = {}
    data["sensor"] = sensor_name
    current_section = None

    for line in lines:
        if line.startswith(f"[{sensor_name}:") and line.endswith("]"):
            current_section = line.strip("[").strip(f"{sensor_name}").strip(":").strip("]")
            data[current_section] = {}
        elif line.startswith("[") and line.endswith("]"):
            current_section = None
        else:
            if current_section:
                try:
                    key, value = map(str.strip, line.split(":", 1))
                    data[current_section][key] = value
                except ValueError:
                    continue

    return data

# Main function to handle argument parsing and processing
def main():
    parser = argparse.ArgumentParser(description='Process sensor data and save as JSON.')
    parser.add_argument('-s', '--sensor', required=True, help='Name of the sensor')
    args = parser.parse_args()
    
    # Read input from stdin
    input_data = sys.stdin.read()
    
    # Parse the input data
    parsed_data = parse_input(input_data, args.sensor)
    
    # Add a timestamp
    timestamp = datetime.datetime.now().isoformat()
    parsed_data['timestamp'] = timestamp
    
    # Convert the Python object to a JSON string
    json_string = json.dumps(parsed_data, indent=4)

    # Save to MongoDB
    # client = MongoClient("mongodb://admin:admin@100.127.213.29:27017/")
    # db = client["dexterlab"]
    # collection = db["sensors"]
    # collection.insert_one(parsed_data)

    # # Save to JSON file
    # json_filename = f"{args.sensor}.json"
    # with open(json_filename, "w") as json_file:
    #     json.dump(parsed_data, json_file, indent=4)
    
    # print(f"Data saved to {json_filename}")
    print(json_string)

if __name__ == "__main__":
    main()
