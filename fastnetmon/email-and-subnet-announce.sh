#!/bin/sh

#
# This script will get following arguments from FastNetMon:
#
#  $1 IP of host which is under attack (incoming attack) or source of attack (outgoing attack)
#  $2 Attack direction: incoming or outgoing
#  $3 Attack bandwidth in packets per second
#  $4 Attack action: ban or unban
#

email_notify="noc@tehranserver.ir"

# For ban action we will receive attack details to stdin
# Please do not remove "cat" command because
# FastNetMon will crash in this case as it expects read of data from script side
#
whitelist_file="/etc/networks_whitelist"

ip="$1"
if grep -q "^$ip$" "$whitelist_file"; then
    echo "IP $ip is in the whitelist. Exiting script."
    /usr/bin/fastnetmon_api_client unban $ip
    exit 0
fi


subnet=$(echo "$ip" | awk -F. '{print $1 "." $2 "." $3 ".0"}')

if [ "$4" = "ban" ]; then
    # This action receives multiple statistics about attack's performance and attack's sample to stdin
    /opt/fastnetmon-community/libraries/gobgp_3_12_0/gobgp global rib add $ip/24 community 12880:6762
    cat | mail -s "FastNetMon Community: IP $1 blocked because $2 attack with power $3 pps" $email_notify;

    # Please add actions to run when we ban host
    exit 0
fi

if [ "$4" = "unban" ]; then
    # No details provided to stdin here
    /opt/fastnetmon-community/libraries/gobgp_3_12_0/gobgp global rib del $ip/24 community 12880:6762
    # Please add actions to run when we unban host
    exit 0
fi

