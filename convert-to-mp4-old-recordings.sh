#!/bin/bash

ls /var/bigbluebutton/published/presentation/ > list.txt

lines=$(cat list.txt)
home="/var/www/bigbluebutton-default/recording/"
bbb="bbb-mp4.js"
for line in $lines
  do
    running=$(ps -ef | grep bbb-mp4 | awk -F" " 'NR==1{print $11}' | awk -F/ '{print $5}')
    if [[ ! -f "/var/www/bigbluebutton-default/recording/$line.mp4" ]] && [[ "${running}" != "$bbb" ]];then
    echo "converting started for $line.mp4"
    /var/www/bbb-mp4/bbb-mp4.sh $line
    sleep 10
    elif [[ "${running}" == "$bbb" ]];then
    echo "a process is already running"
    elif [[ -f "/var/www/bigbluebutton-default/recording/$line.mp4" ]];then
    echo "$line.mp4 file is already exist"
    fi
  done

