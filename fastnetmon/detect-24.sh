#!/bin/bash
#####RUN THIS IN BACKGROUND OR IN A SCREEN SESSION#####
####IT WILL MONITOR THE /24 NETWORKS####
# Threshold value
threshold=11000000000

# File to store already detected networks with timestamps
detected_file="detected_networks.txt"

# Ensure the file exists
touch "$detected_file"

# Loop indefinitely
while true; do
  current_time=$(date +%s) # Get the current timestamp in seconds

  # Remove entries older than 5 minutes
  if [[ -s $detected_file ]]; then
    # Ensure the temporary file exists
    > "${detected_file}.tmp"
    while IFS=" " read -r network timestamp; do
      if (( current_time - timestamp > 300 )); then
        # Run the command to delete the network from the BGP RIB
        echo "Removing network $network from BGP RIB"
        /opt/fastnetmon-community/libraries/gobgp_3_12_0/gobgp global rib del "$network" community 666:666
      else
        # Keep entries that are still within the 5-minute window
        echo "$network $timestamp" >> "${detected_file}.tmp"
      fi
    done < "$detected_file"
    mv "${detected_file}.tmp" "$detected_file"
  fi

  # Run the ClickHouse query to get the latest bits_incoming for all networks
  clickhouse-client --query="SELECT network, any(bits_incoming) AS bits FROM fastnetmon.network_metrics GROUP BY network;" | while read -r line; do
    # Skip header lines
    [[ "$line" =~ "network" || "$line" =~ "└" || "$line" =~ "┌" ]] && continue

    # Extract network and bits_incoming values
    network=$(echo "$line" | awk '{print $1}')
    bits=$(echo "$line" | awk '{print $2}')

    # Check if bits_incoming exceeds the threshold
    if (( bits > threshold )); then
      # Check if the network is already detected
      if ! grep -q "^$network " "$detected_file"; then
        # Run the command to add the network to the BGP RIB
        echo "Adding network $network to BGP RIB"
        echo "Subnet $network is under attack and it has been redirected to ddos protection path for 5 minutes" | mail -s "Subnet $network is under attack" -a "From: sender@tehranserver.ir" noc@tehranserver.ir
        /opt/fastnetmon-community/libraries/gobgp_3_12_0/gobgp global rib add "$network" community 666:666
        # Add the network and the current timestamp to the detected file
        echo "$network $current_time" >> "$detected_file"
      fi
    fi
  done

  # Wait for 1 second before checking again
  sleep 1
done
