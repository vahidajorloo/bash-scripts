#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 <ip/24>"
    exit 1
}

# Ensure the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
    usage
fi

IP_24=$1

# Validate IP/24 format
if ! [[ $IP_24 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.0/24$ ]]; then
    echo "Error: $IP_24 is not in the correct IP/24 format."
    exit 1
fi

# Ask the user whether to add or delete the route
echo "Do you want to add or delete the route?"
select ACTION in "Add" "Delete"; do
    case $ACTION in
        Add)
            echo "Adding route..."
            sudo /opt/fastnetmon-community/libraries/gobgp_3_12_0/gobgp global rib add $IP_24 community 666:666
            sudo /opt/fastnetmon-community/libraries/gobgp_3_12_0/gobgp global rib
            echo "Route added successfully."
            break
            ;;
        Delete)
            echo "Deleting route..."
            sudo /opt/fastnetmon-community/libraries/gobgp_3_12_0/gobgp global rib del $IP_24 community 666:666
            sudo /opt/fastnetmon-community/libraries/gobgp_3_12_0/gobgp global rib
            echo "Route deleted successfully."
            break
            ;;
        *)
            echo "Invalid option. Please choose Add or Delete."
            ;;
    esac
done
