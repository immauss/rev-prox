#!/bin/bash 
#
# setup reverse proxy using nginx, certbot and containers.
# Options:
# -C config-dir

if [ "$1" == "-C" ]; then
	CONFIG="$2"
else 
	CONFIG="/etc/rev-prox.d"
fi
if [ -d $CONFIG ]; then
	. $CONFIG/rev-prox.rc
else
	echo "$CONFIG does not exist"
	exit
fi
if ! echo $CONFIG | grep "^\/" ; then
	if [ -d ./$CONFIG ]; then
		CONFIGD="$(pwd)/$CONFIG"
	else
		echo " Did you use a relative path for the config? "
		exit
	fi
else
	CONFIGD=$CONFIG
fi
echo "Using $CONFIGD for \$CONFIGs"
# Remove existing proxy if running
if docker ps --all | grep -qis nginx-proxy; then
	docker rm -f nginx-proxy
fi


# echo the variables as set in $CONFIG
for var in $( grep -v "^#" $CONFIG/rev-prox.rc | sed "s/\(^.*\)=\".*$/\1/") ; do 
	echo -e "$var:\t ${!var}"
done

#0. Create configs from templates and variables
echo "Create nginx server config"
sed "s/FQDN/$FQDN/g" $CONFIG/nginx-setup.conf.tmpl > $CONFIG/nginx-setup.conf
echo "Create nginx reverse proxy config"
sed "s/FQDN/$FQDN/g;s/UPSTREAM/$UPSTREAM/g;s/FWD_PORT/$FWD_PORT/;s/LISTEN_PORT/$LISTEN_PORT/g" $CONFIG/nginx-rev-proxy.conf.tmpl > $CONFIG/nginx-rev-proxy.conf 

# 0.5 Ensure existing directories
if ! [ -d /etc/letsencrypt ]; then
	mkdir -p /etc/letsencrypt
fi
#1. start a web server for LetEncrypt registration
docker run -d --rm \
	--name nginx-server \
	-v $CONFIGD/nginx-setup.conf:/etc/nginx/conf.d/default.conf \
	-v /etc/letsencrypte:/etc/letsencrypt:ro \
	-v /tmp/acme_challenge:/tmp/acme_challenge \
	-p 80:80 \
	-p 443:443 \
	nginx:$NGINX
#2. Run the certbot to get the new cert
echo " Sleeping 1 second to let nginx start "
sleep 1
echo "Starting certbot container"
docker run -it --rm --name certbot-setup \
	-v /etc/letsencrypt:/etc/letsencrypt \
       	-v /tmp/acme_challenge:/tmp/acme_challenge \
	certbot/certbot:$CERTBOT certonly  --webroot -w /tmp/acme_challenge -d $FQDN  --text --agree-tos --email scott@immauss.com --rsa-key-size 4096 --verbose --keep-until-expiring  --preferred-challenges=http
#3. destroy webserver from 1.
docker stop nginx-server
#4. Start reverse proxy with certs from 2
docker run -d \
      --name nginx-proxy \
      -v $CONFIGD/nginx-rev-proxy.conf:/etc/nginx/conf.d/default.conf \
      -v /etc/letsencrypt:/etc/letsencrypt:ro \
      -v /tmp/acme_challenge:/tmp/acme_challenge \
      -p 80:80 \
      -p443:443 \
      nginx:$NGINX
#5. setup renwal of cert via ???? cron?1. start a web server for LetEncrypt registration

#6. Provide startup cmnd and/or compose fragment

