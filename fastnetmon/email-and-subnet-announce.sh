#!/bin/sh

#
# This script will get following arguments from FastNetMon:
#
#  $1 IP of host which is under attack (incoming attack) or source of attack (outgoing attack)
#  $2 Attack direction: incoming or outgoing
#  $3 Attack bandwidth in packets per second
#  $4 Attack action: ban or unban
#

email_notify="mail@example.com"

# For ban action we will receive attack details to stdin
# Please do not remove "cat" command because
# FastNetMon will crash in this case as it expects read of data from script side
#
whitelist_file="/etc/networks_whitelist"

ip="$1"

subnet=$(echo "$ip" | awk -F. '{print $1 "." $2 "." $3 ".0"}')


cat > /var/log/fastnetmon_attack_details.log
attack_type=$(cat /var/log/fastnetmon_attack_details.log | grep "Attack type:" | awk '{print $3}')

if [ "$attack_type" = "unknown" ]; then
    # Check if lines 81-100 have the same source IP address
    src_ip_port_count=$(tail -n +80 /var/log/fastnetmon_attack_details.log | head -n 20 | awk '{print $3}' | awk -F":" '{print $1}' | uniq -c | wc -l)

    if [ "$src_ip_port_count" -eq 1 ]; then
        echo "The source ip addresses are the same so this is propably a speedtest or it is legit traffic." >> /var/log/fastnetmon_attack_details.log
        # If source IP and port match, perform actions
        #######FASTNETMON WILL BAN THE IP AT FIRST BUT THE TAG is 111:111 SO IT WONT MAKE ANY PROBLEMS########
        #######WE WAIT 10 SECOND FOR SPEEDTEST TO BE COMPLETED AND THEN UNBAN THE IP ADDRESS AND ITS 111:111 TAG FROM BGP######
        sleep 10
        /usr/bin/fastnetmon_api_client unban $ip
        cat /var/log/fastnetmon_attack_details.log | mail -s "Notify Only: IP $1 has Unknown Traffic And is not Blocked" $email_notify;
        exit 0
    fi
        echo "The attack type is unknown but the source ip addresses are not the same so it is not a speedtest or a legit traffic." >> /var/log/fastnetmon_attack_details.log
fi

if [ "$4" = "ban" ]; then
    # This action receives multiple statistics about attack's performance and attack's sample to stdin
    /opt/fastnetmon-community/libraries/gobgp_3_12_0/gobgp global rib add $ip/24 community 666:666
    cat /var/log/fastnetmon_attack_details.log | mail -s "FastNetMon Community: IP $1 blocked because $2 attack with power $3 pps" $email_notify;

    # Please add actions to run when we ban host
    exit 0
fi

if [ "$4" = "unban" ]; then
    # No details provided to stdin here
    /opt/fastnetmon-community/libraries/gobgp_3_12_0/gobgp global rib del $ip/24 community 666:666
    # Please add actions to run when we unban host
    exit 0
fi
