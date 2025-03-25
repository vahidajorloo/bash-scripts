#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 <ip/24> <ip/32>"
    exit 1
}

# Ensure the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    usage
fi

IP_24=$1
IP_32=$2

# Validate IP/24 format
if ! [[ $IP_24 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.0/24$ ]]; then
    echo "Error: $IP_24 is not in the correct IP/24 format."
    exit 1
fi

# Validate IP/32 format
if ! [[ $IP_32 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/32$ ]]; then
    echo "Error: $IP_32 is not in the correct IP/32 format."
    exit 1
fi

# Ask the user whether to add or delete the route
echo "Do you want to add or delete the route?"
select ACTION in "Add" "Delete"; do
    case $ACTION in
        Add)
            echo "Adding routes..."
            sudo /opt/fastnetmon-community/libraries/gobgp_3_12_0/gobgp global rib add $IP_24 community 12880:6762
            sudo /opt/fastnetmon-community/libraries/gobgp_3_12_0/gobgp global rib add $IP_32 community 6762:666
            sudo /opt/fastnetmon-community/libraries/gobgp_3_12_0/gobgp global rib
            echo "Routes added successfully."
            break
            ;;
        Delete)
            echo "Deleting routes..."
            sudo /opt/fastnetmon-community/libraries/gobgp_3_12_0/gobgp global rib del $IP_24 community 12880:6762
            sudo /opt/fastnetmon-community/libraries/gobgp_3_12_0/gobgp global rib del $IP_32 community 6762:666
            sudo /opt/fastnetmon-community/libraries/gobgp_3_12_0/gobgp global rib
            echo "Routes deleted successfully."
            break
            ;;
        *)
            echo "Invalid option. Please choose Add or Delete."
            ;;
    esac
done
