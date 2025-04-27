#!/bin/bash

read -p "old ip:" old_ip
export old_ip
read -p "new ip:" new_ip
export new_ip
read -p "old domain:" old_domain
export old_domain
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
sed -i "s/$old_ip/$new_ip/g" /usr/share/bigbluebutton/nginx/sip.nginx
sed -i "s/$old_ip/$new_ip/g" /usr/local/bigbluebutton/bbb-webrtc-sfu/config/default.yml
sed -i "s/$old_ip/$new_ip/g" /etc/bigbluebutton/bbb-webrtc-sfu/production.yml
sed -i "s/$old_ip/$new_ip/g" /etc/haproxy/haproxy.cfg
sed -i "s/$old_domain/$new_domain/g" /etc/nginx/sites-available/bigbluebutton
sed -i "s/$old_domain/$new_domain/g" /etc/turnserver.conf
sed -i "s/$old_ip/$new_ip/g" /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties
sed -i "s/$old_ip/$new_ip/g" /etc/turnserver.conf
sed -i "s/$old_domain/$new_domain/g" /etc/letsencrypt/renewal-hooks/deploy/haproxy
sed -i "s/$old_domain/$new_domain/g" /etc/bigbluebutton/turn-stun-servers.xml
systemctl restart coturn
rm -rf /etc/letsencrypt/renewal/*
rm -rf /etc/letsencrypt/live/*
rm -rf /etc/letsencrypt/archive/*
rm -rf /etc/haproxy/certbundle.pem
killall nginx
sudo certbot certonly --standalone -n -d $new_domain --agree-tos -m info@tehranserver.ir
sudo -E bash -c 'cat /etc/letsencrypt/live/$new_domain/fullchain.pem /etc/letsencrypt/live/$new_domain/privkey.pem > /etc/haproxy/certbundle.pem'
systemctl restart haproxy
bbb-conf --setip $new_domain
cd ~/greenlight-v3/
docker-compose down
rm -rf ~/greenlight-v3/data
sed -i "/BIGBLUEBUTTON_ENDPOINT/c\BIGBLUEBUTTON_ENDPOINT=https:\/\/$new_domain\/bigbluebutton/" ~/greenlight-v3/.env
secret2=$(bbb-conf --secret | grep Secret: | sed 's/Secret://' | sed 's/ //g')
export secret2
sed -i "/BIGBLUEBUTTON_SECRET=/c\BIGBLUEBUTTON_SECRET=$secret2" ~/greenlight-v3/.env
#sed -i "/SAFE_HOSTS/c\SAFE_HOSTS=$new_domain" ~/greenlight/.env #Deprycated
#docker run --rm --env-file .env bigbluebutton/greenlight:v3 bundle exec rake conf:check
docker-compose up -d
echo "Sleep 90 Seconds"
sleep 90
service nginx restart
bbb-conf --restart
sed -i "s/$old_domain/$new_domain/g" /etc/zabbix/zabbix_agentd.conf
service zabbix-agent restart
docker exec greenlight-v3 bundle exec rake user:create["$my_username","$my_email","$my_password","Administrator"]
bbb-conf --secret

echo "Installation is complete."
