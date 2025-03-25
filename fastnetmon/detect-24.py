#!/bin/python3

import subprocess
import json
import time
import os
import logging
from datetime import datetime, timedelta
import threading

# Configure logging
log_file = "monitoring.log"
logging.basicConfig(
    filename=log_file,
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)

output_file = 'high_traffic_ips.json'
protected_prefixes_file = 'protected_prefixes.json'
attack_start_time = {}
ddos_protected = {}
normalized_prefixes = {}

def run_command():
    command = 'clickhouse-client --query="SELECT network, any(bits_incoming) AS bits FROM fastnetmon.network_metrics GROUP BY network"'
    result = subprocess.run(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return result.stdout

def parse_output(output):
    lines = output.strip().split('\n')
    data = {}
    for line in lines:
        parts = line.split()
        if len(parts) < 2:
            continue
        ip_range, bits = parts[0], parts[1]
        try:
            data[ip_range] = int(bits)
        except ValueError:
            continue
    return data

def save_to_json(filename, data):
    try:
        # Convert datetime objects to string before saving
        json_data = {key: value.isoformat() if isinstance(value, datetime) else value for key, value in data.items()}
        with open(filename, 'w') as f:
            json.dump(json_data, f, indent=4)
    except Exception as e:
        logging.error(f"Failed to save data to {filename}: {e}")

def load_json(filename):
    try:
        with open(filename, 'r') as f:
            data = json.load(f)
            # Convert string timestamps back to datetime
            return {key: datetime.fromisoformat(value) if isinstance(value, str) else value for key, value in data.items()}
    except Exception:
        return {}

def execute_protection_command(ip_range):
    command = f'sudo /opt/fastnetmon-community/libraries/gobgp_3_12_0/gobgp global rib add "{ip_range}" community 666:666'
    try:
        result = subprocess.run(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if result.returncode == 0:
            logging.info(f"Protection applied for {ip_range}")
        else:
            logging.error(f"Failed to apply protection for {ip_range}: {result.stderr}")
        return result.returncode
    except Exception as e:
        logging.error(f"Exception while applying protection for {ip_range}: {e}")
        return -1

def execute_restoration_command(ip_range):
    command = f'sudo /opt/fastnetmon-community/libraries/gobgp_3_12_0/gobgp global rib del "{ip_range}" community 666:666'
    try:
        result = subprocess.run(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if result.returncode == 0:
            logging.info(f"Protection removed for {ip_range}")
        else:
            logging.error(f"Failed to remove protection for {ip_range}: {result.stderr}")
        return result.returncode
    except Exception as e:
        logging.error(f"Exception while removing protection for {ip_range}: {e}")
        return -1

def schedule_restoration(ip_range):
    time.sleep(12000)  # 120 minutes
    execute_restoration_command(ip_range)
    if ip_range in ddos_protected:
        del ddos_protected[ip_range]
    save_to_json(protected_prefixes_file, ddos_protected)

def check_and_save(data):
    threshold = 4000000000
    current_time = datetime.now()

    for ip_range, bits in data.items():
        if bits > threshold:
            if ip_range in ddos_protected:
                continue
            if ip_range not in attack_start_time:
                attack_start_time[ip_range] = current_time
                logging.info(f"New attack detected: {ip_range} with {bits} bits")
                save_to_json(output_file, attack_start_time)
            else:
                attack_duration = current_time - attack_start_time[ip_range]
                if attack_duration > timedelta(minutes=5):
                    if ip_range not in ddos_protected:
                        ret = execute_protection_command(ip_range)
                        if ret == 0:
                            ddos_protected[ip_range] = current_time
                            save_to_json(protected_prefixes_file, ddos_protected)
                            restoration_thread = threading.Thread(target=schedule_restoration, args=(ip_range,))
                            restoration_thread.daemon = True
                            restoration_thread.start()
        else:
            if ip_range in attack_start_time:
                if ip_range not in normalized_prefixes:
                    normalized_prefixes[ip_range] = current_time
                    logging.info(f"Traffic normalized: {ip_range} is back to normal")
                else:
                    if current_time - normalized_prefixes[ip_range] > timedelta(minutes=5):
                        del attack_start_time[ip_range]
                        del normalized_prefixes[ip_range]
                        save_to_json(output_file, attack_start_time)
                        logging.info(f"Attack entry removed after 5 minutes of normalization: {ip_range}")

def main():
    global attack_start_time, ddos_protected
    # Load previous attack data on startup
    attack_start_time = load_json(output_file)
    ddos_protected = load_json(protected_prefixes_file)

    while True:
        output = run_command()
        data = parse_output(output)
        check_and_save(data)
        time.sleep(1)

if __name__ == "__main__":
    logging.info("Starting monitoring script")
    main()

