#!/bin/bash 
#
# setup reverse proxy using nginx, certbot and containers.

Help () {
	echo
	echo "Create an nginx reverse proxy with renewable Let's Encrypt certificates."
	echo "!!! In most cases, this will need to be run as root or via sudo !!!"
	echo "Usage:"
	echo "  rev-prox.sh -C <config dir>"
	echo "  Setup an nginx reverse proxy container with the config in the provideded directory"
	echo 
	echo "  rev-prox.sh -i "
	echo "  Setup an nginx reverse proxy in interactive mode"
	echo
	echo "  rev-prox.sh -h|--help "
	echo "  Display this help information"
	exit
}
Interactive () {
	echo "Let's create your config for rev-prox"
	echo "What is the fully qualified domain name of the server?"
	read FQDN
	echo "What is the adminstrative email address you would liek to use for the certificate?"
	read EMAIL
	echo "Would you like to specify a specific version of nginx container?"
	echo "If not, we will use \"latest\""
	read NGINX
	if [ -z $NGINX ]; then
		NGINX="latest"
	fi
	echo "Would you like to specify a specific version of the certbot container"
	echo "If not, we will use \"latest\""
	read CERTBOT
	if [ -z $CERTBOT ]; then
		CERTBOT="latest"
	fi
	echo "What is the IP or fully qualified domain name of the upstream server?"
	read UPSTREAM
	echo "What is the TCP port the upstream server is listening on?"
	read FWD_PORT
	echo "What TCP port do you want the proxy to listen on?"
	read LISTEN_PORT
	echo "Do you want to run create and start the proxy now?"
	read GO
	echo "Would you like to create a docker-compose fragment?"
	read COMPFRAG
	echo "Should I create a cron entry to renew the Let's Encrypt cert?"
	read CRON
	mv /etc/rev-prox.d/rev-prox.rc /etc/rev-prox.d/rev-prox.rc.orig
	for opt in FQDN NGINX EMAIL CERTBOT UPSTREAM FWD_PORT LISTEN_PORT GO COMPFRAG CRON; do 
		echo "$opt=\"${!opt}\"" | tee -a /etc/rev-prox.d/rev-prox.rc
	done
	cp config/*tmpl /etc/rev-prox.d/
	if [ $GO != "yes" ]; then
		exit
	fi

}

# 0.5 Ensure existing directories
if ! [ -d /etc/letsencrypt ]; then
	mkdir -p /etc/letsencrypt
fi
if ! [ -d /etc/rev-prox.d ]; then
	mkdir -p /etc/rev-prox.d
fi

case $1 in 
	-i)
	echo " Interactive setup "
	Interactive
	;;
	-C)
	echo " Setting config directory"
	;;
	-h|--help)
	Help
	;;
	*)
	;;
esac


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
#1. start a web server for Let's Encrypt registration
docker run -d --rm \
	--name nginx-server \
	-v $CONFIGD/nginx-setup.conf:/etc/nginx/conf.d/default.conf \
	-v /etc/letsencrypte:/etc/letsencrypt:ro \
	-v /tmp/acme_challenge:/tmp/acme_challenge \
	-p 80:80 \
	-p $LISTEN_PORT:$LISTEN_PORT \
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
      -p 443:443 \
      nginx:$NGINX
#5. setup renwal of cert via ???? cron?1. start a web server for LetEncrypt registration
echo "To renew ( or just check for renewal), run:"
echo -e "\t docker run -it --rm --name certbot-setup \\"  > /usr/local/bin/rev-prox-cert-update.sh 
echo -e "\t-v /etc/letsencrypt:/etc/letsencrypt \\" >> /usr/local/bin/rev-prox-cert-update.sh 
echo -e "\t-v /tmp/acme_challenge:/tmp/acme_challenge \\" >> /usr/local/bin/rev-prox-cert-update.sh 
echo -e "\tcertbot/certbot:$CERTBOT certonly  \\" >> /usr/local/bin/rev-prox-cert-update.sh 
echo -e "\t--webroot -w /tmp/acme_challenge -d $FQDN  \\" >> /usr/local/bin/rev-prox-cert-update.sh 
echo -e "\t--text --agree-tos --email scott@immauss.com \\" >> /usr/local/bin/rev-prox-cert-update.sh 
echo -e "\t--rsa-key-size 4096 --verbose \\" >> /usr/local/bin/rev-prox-cert-update.sh 
echo -e "\t--keep-until-expiring  --preferred-challenges=http" >> /usr/local/bin/rev-prox-cert-update.sh 
chmod 755 /usr/local/bin/rev-prox-cert-update.sh
echo "Or just run the script we created at:"
echo -e "\t /usr/local/bin/rev-prox-cert-update.sh"

#6. Provide startup cmnd and/or compose fragment
echo "The proxy is started with the \"--rm\" option, so if you stop it, it's gone."
echo "That's OK. "
echo -e "\tdocker run -d \\" > /usr/local/bin/rev-prox-start.sh 
echo -e "\t--name nginx-proxy \\" >> /usr/local/bin/rev-prox-start.sh 
echo -e "\t-v $CONFIGD/nginx-rev-proxy.conf:/etc/nginx/conf.d/default.conf \\" >> /usr/local/bin/rev-prox-start.sh 
echo -e "\t-v /etc/letsencrypt:/etc/letsencrypt:ro \\" >> /usr/local/bin/rev-prox-start.sh 
echo -e "\t-v /tmp/acme_challenge:/tmp/acme_challenge \\" >> /usr/local/bin/rev-prox-start.sh 
echo -e "\t-p 80:80 \\" >> /usr/local/bin/rev-prox-start.sh 
echo -e "\t-p 443:443 \\" >> /usr/local/bin/rev-prox-start.sh 
echo -e "\tnginx:$NGINX" >> /usr/local/bin/rev-prox-start.sh 
chmod 755 /usr/local/bin/rev-prox-start.sh
echo "Or just run the script we created at:"
echo -e "\t/usr/local/bin/rev-prox-start.sh"
