#!/bin/bash
trap ":" INT
file="ssl.file"
lines=$(cat $file)


 for ip in $lines
  do
 
 	 mydomain=$(curl -Lsk -o /dev/null -w %{url_effective} http://"$ip" | awk -F / {'print $3'})
     if [[ $mydomain =~ ^[a-z] ]]; then
 	 echo $mydomain
 	 echo $mydomain >> urls.txt
     else
         echo $ip >> ip.txt
     fi 
  done 
  
 
  
