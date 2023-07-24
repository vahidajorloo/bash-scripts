#!/bin/bash


mp4_path="/var/www/bigbluebutton-default/recording"
published_path="/var/bigbluebutton/published/presentation"


ls $mp4_path | awk -F"." '{print $1}' > mp4_list.txt
ls $published_path > published_list.txt

mp4_lines=$(cat ./mp4_list.txt)
published_lines=$(cat ./published_list.txt)

for line in $mp4_lines
do
  if [[ -d $published_path/$line ]];then
     echo "$line exist"
  elif [[ ! -d $published_path/$line ]];then
     echo "$line doesnt exist, Record deleted."
     rm $mp4_path/$line.mp4
  fi
done
