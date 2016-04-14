#!/bin/sh

charlimit_def='Tokumei'
read -p "Site title [$charlimit_def]: " charlimit
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

echo 'Installing dependencies.'
apt-get -y update
apt-get -y install nginx 9base git golang tor imagemagick curl

echo 'Configuring Tor.'
echo 'HiddenServiceDir /var/lib/tor/hidden_service' >/etc/tor/torrc
echo 'HiddenServicePort 80 127.0.0.1:80' >>/etc/tor/torrc
service tor restart
while [ ! -f /var/lib/tor/hidden_service/hostname ]; do
    sleep 1
done
domain=$(cat /var/lib/tor/hidden_service/hostname)

echo 'Configuring nginx.'
cat <<EOF >/etc/nginx/sites-available/default
server {
    server_name $domain www.$domain;

    access_log off;
    error_log off;

    root /var/www/tokumei/sites/\$host/;
    index index.html;

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

service nginx restart

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

sed -i "s/^charlimit=.*$/charlimit=$charlimit/;
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

cd ../bin/aux

cat <<EOF >update.rc
#!/usr/bin/env rc

apt-get update
apt-get upgrade
cd /var/www/tokumei
git pull
EOF

chmod +x update.rc

(crontab -l 2>/dev/null; echo '0 0 * *   * PATH=$PATH:/usr/lib/plan9/bin /var/www/tokumei/bin/aux/trending.rc') | crontab -
(crontab -l 2>/dev/null; echo '0 0 * *   0 PATH=$PATH:/usr/lib/plan9/bin /var/www/tokumei/bin/aux/update.rc') | crontab -

echo 'Installing and starting cgd.'
mkdir -p /usr/local/go
GOPATH=/usr/local/go go get github.com/uriel/cgd
/usr/local/go/bin/cgd -f -c /var/www/tokumei/bin/werc.rc >/dev/null 2>1 &

echo 'Done installing Tokumei. Your site should be available over Tor at http://'$domain'/.'
