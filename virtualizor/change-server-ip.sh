#!/bin/bash

# Function to validate IP address format
validate_ip() {
    local ip=$1
    local stat=1
    
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

# Function to validate CIDR format
validate_cidr() {
    local cidr=$1
    local ip=${cidr%/*}
    local prefix=${cidr#*/}
    
    validate_ip "$ip"
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    if [[ $prefix =~ ^[0-9]+$ ]] && [ $prefix -ge 0 ] && [ $prefix -le 32 ]; then
        return 0
    else
        return 1
    fi
}

# Get IP addresses and gateways from user input
echo "Please enter the IP addresses in CIDR format (e.g., 192.168.1.10/24)"
read -p "Enter the old IP address with CIDR: " OLD_IP_CIDR
read -p "Enter the new IP address with CIDR: " NEW_IP_CIDR

echo "Please enter the gateway addresses (without CIDR)"
read -p "Enter the old gateway IP: " OLD_GATEWAY
read -p "Enter the new gateway IP: " NEW_GATEWAY

# Validate CIDR IP addresses
if ! validate_cidr "$OLD_IP_CIDR"; then
    echo "Error: Invalid old IP address format (should be CIDR like 192.168.1.10/24)."
    exit 1
fi

if ! validate_cidr "$NEW_IP_CIDR"; then
    echo "Error: Invalid new IP address format (should be CIDR like 192.168.1.20/24)."
    exit 1
fi

# Validate gateway IP addresses
if ! validate_ip "$OLD_GATEWAY"; then
    echo "Error: Invalid old gateway IP address format."
    exit 1
fi

if ! validate_ip "$NEW_GATEWAY"; then
    echo "Error: Invalid new gateway IP address format."
    exit 1
fi

# Extract IP parts without CIDR for XML files
OLD_IP=${OLD_IP_CIDR%/*}
NEW_IP=${NEW_IP_CIDR%/*}

# Update libvirt VM configurations
echo "Updating libvirt VM configurations..."
cd /etc/libvirt/qemu/ 2>/dev/null || { echo "Error: Directory /etc/libvirt/qemu/ not found"; exit 1; }

# Create backup of XML files
BACKUP_DIR="/tmp/libvirt_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp v*.xml "$BACKUP_DIR/" 2>/dev/null

# Update IP in XML files
sed -i "s/listen='$OLD_IP'/listen='$NEW_IP'/g" v*.xml
sed -i "s/address='$OLD_IP'/address='$NEW_IP'/g" v*.xml

echo "Libvirt VM configurations updated successfully."

# Update Netplan configuration
echo "Updating Netplan configuration..."

# Find Netplan configuration file
NETPLAN_FILE=$(find /etc/netplan -name "*.yaml" -o -name "*.yml" | head -n 1)
if [[ -z "$NETPLAN_FILE" ]]; then
    echo "Warning: No Netplan configuration file found."
    exit 0
fi

# Create backup of Netplan file
cp "$NETPLAN_FILE" "$NETPLAN_FILE.backup.$(date +%Y%m%d_%H%M%S)"

# Extract interface information from current Netplan file
PHYSICAL_IFACE=$(grep -A 10 "ethernets:" "$NETPLAN_FILE" | grep -E "^    [a-zA-Z0-9]+:" | head -1 | tr -d ' :')
BRIDGE_IFACE=$(grep -A 10 "bridges:" "$NETPLAN_FILE" | grep -E "^    [a-zA-Z0-9]+:" | head -1 | tr -d ' :')

# Create new Netplan configuration
cat > "$NETPLAN_FILE" << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $PHYSICAL_IFACE:
      dhcp4: no
  bridges:
    $BRIDGE_IFACE:
      addresses:
        - $NEW_IP_CIDR
      interfaces: [ $PHYSICAL_IFACE ]
      routes:
        - to: default
          via: $NEW_GATEWAY
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
EOF

echo "Netplan configuration updated successfully."
echo "New IP: $NEW_IP_CIDR"
echo "New Gateway: $NEW_GATEWAY"

# Apply Netplan changes
read -p "Do you want to apply the Netplan changes now? (y/N): " APPLY_NOW
if [[ "$APPLY_NOW" == "y" || "$APPLY_NOW" == "Y" ]]; then
    netplan apply
    echo "Netplan changes applied."
else
    echo "Remember to run 'netplan apply' to apply the changes."
fi

echo "Script completed successfully. Backups created in:"
echo "Libvirt: $BACKUP_DIR/"
echo "Netplan: $NETPLAN_FILE.backup.$(date +%Y%m%d_%H%M%S)"
