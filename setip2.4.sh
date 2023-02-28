#!/bin/bash

read -p "old ip:" old_ip
export old_ip
read -p "new ip:" new_ip
export new_ip
read -p "new domain:" new_domain
export new_domain
read -p "username:" my_username
export my_username
read -p "email:" my_email
export my_email
read -p "password:" my_password
export my_password
sed -i "s/$old_ip/$new_ip/g" /opt/freeswitch/etc/freeswitch/vars.xml
sed -i "s/$old_ip/$new_ip/g" /opt/freeswitch/etc/freeswitch/sip_profiles/external.xml
sed -i "s/$old_ip/$new_ip/g" /etc/bigbluebutton/nginx/sip.nginx
sed -i "s/$old_ip/$new_ip/g" /usr/local/bigbluebutton/bbb-webrtc-sfu/config/default.yml
sed -i '8,23d' /etc/nginx/sites-available/bigbluebutton
sed -i "/server_name/c\server_name $new_domain ;" /etc/nginx/sites-available/bigbluebutton
rm -rf /etc/letsencrypt/renewal/*
certbot --nginx -n -d $new_domain --agree-tos -m info@tehranserver.ir
killall nginx
bbb-conf --setip $new_domain
cd ~/greenlight
docker-compose down
rm -rf ~/greenlight/db ~/greenlight/log ~/greenlight/storage
sed -i "/BIGBLUEBUTTON_ENDPOINT/c\BIGBLUEBUTTON_ENDPOINT=https:\/\/$new_domain\/bigbluebutton/" ~/greenlight/.env
secret2=$(bbb-conf --secret | grep Secret: | sed 's/Secret://' | sed 's/ //g')
export secret2
sed -i "/BIGBLUEBUTTON_SECRET=/c\BIGBLUEBUTTON_SECRET=$secret2" ~/greenlight/.env
sed -i "/SAFE_HOSTS/c\SAFE_HOSTS=$new_domain" ~/greenlight/.env
docker run --rm --env-file .env bigbluebutton/greenlight:v2 bundle exec rake conf:check
docker-compose up -d
service nginx restart
bbb-conf --restart
sed -i "s/workshops.tehranclass.ir/$new_domain/g" /etc/zabbix/zabbix_agentd.conf
service zabbix-agent restart
docker exec greenlight-v2 bundle exec rake user:create["$my_username","$my_email","$my_password","admin"]
bbb-conf --secret


