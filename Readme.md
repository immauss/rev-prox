Reference:
  https://leangaurav.medium.com/simplest-https-setup-nginx-reverse-proxy-letsencrypt-ssl-certificate-aws-cloud-docker-4b74569b3c61
  https://github.com/leangaurav/nginx_https_docker
Basic steps needed:
1. start a web server for LetEncrypt registration
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




