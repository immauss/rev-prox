# The Goal #
Uber simple method for creating a reverse proxy container to use in any project with Let's Encrypt certificates.

## WIP ##

16 Aug 2022
- - - - 
For now, you can get a container running with the rev-prox.sh script. You'll need to run it as root or with sudo. 
Step 1: Check the rev-prox.rc.tmpl in ./config Modify as needed
Step 2: sudo ./rev-prox.sh -C config 

You should know have a container with nginx running as a referse-proxy. :D

Still To Do:

- [ ] Run as interactive script to fill in config.
- [ ] Create docker-compose fragment 
- [ ] Generate/add cron entry to update certificate with ACME
- [ ] Improve this ReadMe
- [ ] Actual documentation
- [ ] ?????


Reference:
  https://leangaurav.medium.com/simplest-https-setup-nginx-reverse-proxy-letsencrypt-ssl-certificate-aws-cloud-docker-4b74569b3c61
  https://github.com/leangaurav/nginx_https_docker
Basic steps needed:
1. start a web server for Let's Encrypt registration
2. Run the certbot to get the new cert
3. destroy webserver from 1. 
4. Start reverse proxy with certs from 2
5. setup renwal of cert via ???? cron? 

Details.
- Should be a script to:
  - Fill in email address and FQDN 
  - start and stop as needed
  - ask for local port number to foward to
  - generate start command and/or generate compose service fragment
- Script should use containers, but not necassarily compose ... 
- use rc/config to set FQDN, email address, ports, output, ngxinx container version
- should have option for specifing config file with default set in /etc




