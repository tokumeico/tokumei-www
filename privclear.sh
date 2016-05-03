#!/bin/sh

domain_def='tokumei.co'
read -p "Domain [$domain_def]: " domain
domain=${domain:-$domain_def}

charlimit_def='300'
read -p "Post character limit [$charlimit_def]: " charlimit
charlimit=${charlimit:-$charlimit_def}

filesizelimit_def='104857600'
read -p "Attachment file size limit (bytes) [$filesizelimit_def]: " filesizelimit
filesizelimit=${filesizelimit:-$filesizelimit_def}

siteTitle_def='Tokumei'
read -p "Site title [$siteTitle_def]: " siteTitle
siteTitle=${siteTitle:-$siteTitle_def}

siteSubTitle_def='Anonymous microblogging'
read -p "Site subtitle [$siteSubTitle_def]: " siteSubTitle
siteSubTitle=${siteSubTitle:-$siteSubTitle_def}

meta_description_def='What you have to say is more important than who you are'
read -p "Site description [$meta_description_def]: " meta_description
meta_description=${meta_description:-$meta_description_def}

email_def='user@example.com'
read -p "Admin email address [$email_def]: " email
email=${email:-$email_def}

bitcoin_def='1Q31UMtim2ujr3VX5QcS3o95VF2ceiwzzc'
read -p "Bitcoin donation address [$bitcoin_def]: " bitcoin
bitcoin=${bitcoin:-$bitcoin_def}

paypal_business_def='NCX75ZH9GLZD6'
read -p "PayPal donation business ID [$paypal_business_def]: " paypal_business
paypal_business=${paypal_business:-$paypal_business_def}

paypal_location_def='CA'
read -p "PayPal donation location [$paypal_location_def]: " paypal_location
paypal_location=${paypal_location:-$paypal_location_def}

paypal_name_def='Tokumei'
read -p "PayPal donation name [$paypal_name_def]: " paypal_name
paypal_name=${paypal_name:-$paypal_name_def}

paypal_currency_def='USD'
read -p "PayPal donation currency [$paypal_currency_def]: " paypal_currency
paypal_currency=${paypal_currency:-$paypal_currency_def}

rssDesc_def=$siteTitle' RSS'
read -p "RSS feed description [$rssDesc_def]: " rssDesc
rssDesc=${rssDesc:-$rssDesc_def}

webmaster_def=$email' (John Smith)'
read -p "RSS feed webmaster [$webmaster_def]: " webmaster
webmaster=${webmaster:-$webmaster_def}

user_name_def='tokumeister'
read -p "Admin username [$user_name_def]: " user_name
user_name=${user_name:-$user_name_def}

user_password_def=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 24 | sed 1q)
read -p "Admin password [$user_password_def]: " user_password
user_password=${user_password:-$user_password_def}

echo 'Installing dependencies.'
apt-get -y update
apt-get -y install nginx 9base git golang curl

echo 'Configuring nginx.'
mkdir -p /etc/nginx/ssl
chmod -R 600 /etc/nginx/ssl
openssl dhparam -out /etc/nginx/ssl/dhparams.pem 4096

cat <<EOF >/etc/nginx/sites-available/default
server {
    server_name $domain www.$domain;
    return 301 https://\$host\$request_uri;

    access_log off;
    error_log off;
}

server {
    listen 443;

    ssl on;
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;

    add_header Strict-Transport-Security "max-age=31536000";

    ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';
    ssl_dhparam /etc/nginx/ssl/dhparams.pem;

    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    server_name $domain www.$domain;

    access_log off;
    error_log off;

    root /var/www/tokumei/sites/\$host/;
    index index.html;

    location = / {
        return 301 https://\$host/p/recent;
    }
    location / {
        try_files \$uri @werc;
    }
    location /pub/ {
        root /var/www/tokumei;
        try_files \$uri =404;
    }
    location = /favicon.ico {
        root /var/www/tokumei;
        try_files /var/www/tokumei/sites/\$host/\$uri /pub/default_favicon.ico =404;
    }

    error_page 404 = @werc;

    location @werc {
        include fastcgi_params;
        fastcgi_pass localhost:3333;
    }
}
EOF

echo 'Installing SSL certificate.'
cd /opt
git clone https://github.com/letsencrypt/letsencrypt
cd letsencrypt
service nginx stop
./letsencrypt-auto certonly --standalone -d $domain -d www.$domain
chmod 600 /etc/letsencrypt/live/$domain/*
service nginx start

echo 'Installing Tokumei.'
mkdir -p /var/www
git clone https://git.kfarwell.org/tokumei /var/www/tokumei

cd /var/www/tokumei/sites
ln -s tokumei.co $domain
ln -s tokumei.co www.$domain

charlimit=$(printf '%s\n' "$charlimit" | sed 's/[[\.*^$(){}?+|/]/\\&/g')
filesizelimit=$(printf '%s\n' "$filesizelimit" | sed 's/[[\.*^$(){}?+|/]/\\&/g')
siteTitle=$(printf '%s\n' "$siteTitle" | sed 's/[[\.*^$(){}?+|/]/\\&/g')
siteSubTitle=$(printf '%s\n' "$siteSubTitle" | sed 's/[[\.*^$(){}?+|/]/\\&/g')
meta_description=$(printf '%s\n' "$meta_description" | sed 's/[[\.*^$(){}?+|/]/\\&/g')
email=$(printf '%s\n' "$email" | sed 's/[[\.*^$(){}?+|/]/\\&/g')
bitcoin=$(printf '%s\n' "$bitcoin" | sed 's/[[\.*^$(){}?+|/]/\\&/g')
paypal_business=$(printf '%s\n' "$paypal_business" | sed 's/[[\.*^$(){}?+|/]/\\&/g')
paypal_location=$(printf '%s\n' "$paypal_location" | sed 's/[[\.*^$(){}?+|/]/\\&/g')
paypal_name=$(printf '%s\n' "$paypal_name" | sed 's/[[\.*^$(){}?+|/]/\\&/g')
paypal_currency=$(printf '%s\n' "$paypal_currency" | sed 's/[[\.*^$(){}?+|/]/\\&/g')
rssDesc=$(printf '%s\n' "$rssDesc" | sed 's/[[\.*^$(){}?+|/]/\\&/g')
webmaster=$(printf '%s\n' "$webmaster" | sed 's/[[\.*^$(){}?+|/]/\\&/g')

sed -i "s/^#sitePrivate/sitePrivate/;
        s/^charlimit=.*$/charlimit=$charlimit/;
        s/^filesizelimit=.*$/filesizelimit=$filesizelimit/;
        s/^siteTitle=.*$/siteTitle="\'"$siteTitle"\'"/;
        s/^siteSubTitle=.*$/siteSubTitle="\'"$siteSubTitle"\'"/;
        s/^meta_description=.*$/meta_description="\'"$meta_description"\'"/;
        s/^email=.*$/email="\'"$email"\'"/;
        s/^bitcoin=.*$/bitcoin="\'"$bitcoin"\'"/;
        s/^paypal_business=.*$/paypal_business="\'"$paypal_business"\'"/;
        s/^paypal_location=.*$/paypal_location="\'"$paypal_location"\'"/;
        s/^paypal_name=.*$/paypal_name="\'"$paypal_name"\'"/;
        s/^paypal_currency=.*$/paypal_currency="\'"$paypal_currency"\'"/;
        s/^rssDesc=.*$/rssDesc="\'"$rssDesc"\'"/;
        s/^webmaster=.*$/webmaster="\'"$webmaster"\'"/" tokumei.co/_werc/config

sed -i "s/^#dirdir_users_only/dirdir_users_only/;
        s/^#groups_allowed_posts/groups_allowed_posts/" tokumei.co/p/_werc/config

cd ..
PATH=$PATH:/usr/lib/plan9/bin ./bin/aux/addwuser.rc "$user_name" "$user_password" posters repliers

cd bin/aux

cat <<EOF >renew.rc
#!/usr/bin/env rc

cd /opt/letsencrypt
service nginx stop
./letsencrypt-auto certonly --standalone -d $domain -d www.$domain
chmod 600 /etc/letsencrypt/live/$domain/*
service nginx start
EOF

chmod +x renew.rc

(crontab -l 2>/dev/null; echo '0 0 * *   * PATH=$PATH:/usr/lib/plan9/bin /var/www/tokumei/bin/aux/trending.rc') | crontab -
(crontab -l 2>/dev/null; echo '0 0 1 */2 * PATH=$PATH:/usr/lib/plan9/bin /var/www/tokumei/bin/aux/renew.rc') | crontab -

echo 'Installing and starting cgd.'
mkdir -p /usr/local/go
GOPATH=/usr/local/go go get github.com/uriel/cgd
/usr/local/go/bin/cgd -f -c /var/www/tokumei/bin/werc.rc >/dev/null 2>1 &

echo 'Done installing Tokumei.'
