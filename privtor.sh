#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "Tokumei installation must be run as root!" 1>&2;
    exit
fi

filesizelimit_def='104857600'
read -p "Attachment file size limit (bytes) [$filesizelimit_def]: " filesizelimit
filesizelimit=${filesizelimit:-$filesizelimit_def}
filesizelimit_human=$(echo "$filesizelimit" | awk '{ split( "K M G" , v )
    s=0
    while($1>1024) {
        $1/=1024
        s++
    }
    print int($1) v[s]
}')

siteTitle_def='Tokumei'
read -p "Site title [$siteTitle_def]: " siteTitle
siteTitle=${siteTitle:-$siteTitle_def}

siteSubTitle_def='Anonymous microblogging'
read -p "Site subtitle [$siteSubTitle_def]: " siteSubTitle
siteSubTitle=${siteSubTitle:-$siteSubTitle_def}

meta_description_def='What you have to say is more important than who you are'
read -p "Site description [$meta_description_def]: " meta_description
meta_description=${meta_description:-$meta_description_def}

offset_def='150'
read -p "Recent posts [$offset_def]: " offset
offset=${offset:-$offset_def}

charlimit_def='300'
read -p "Post character limit [$charlimit_def]: " charlimit
charlimit=${charlimit:-$charlimit_def}

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

echo 'Installing dependencies...'
apt-get -y update
apt-get -y install nginx 9base git golang tor curl libimage-exiftool-perl

echo 'Configuring Tor...'
echo 'HiddenServiceDir /var/lib/tor/hidden_service' >/etc/tor/torrc
echo 'HiddenServicePort 80 127.0.0.1:80' >>/etc/tor/torrc
service tor restart
while [ ! -f /var/lib/tor/hidden_service/hostname ]; do
    sleep 1
done
domain=$(cat /var/lib/tor/hidden_service/hostname)

echo 'Configuring nginx...'
cat <<EOF >/etc/nginx/sites-available/default
server {
    server_name $domain www.$domain;

    access_log off;
    error_log off;

    client_max_body_size $filesizelimit_human;

    root /var/www/$domain/sites/\$host/;
    index index.html;

    location = / {
        return 301 http://\$host/p/recent;
    }
    location / {
        try_files \$uri @werc;
    }
    location /pub/ {
        root /var/www/$domain;
        try_files \$uri =404;
    }
    location = /favicon.ico {
        root /var/www/$domain;
        try_files /var/www/$domain/sites/\$host/\$uri /pub/default_favicon.ico =404;
    }

    error_page 404 = @werc;

    location @werc {
        include fastcgi_params;
        fastcgi_pass localhost:3333;
    }
}
EOF

ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/$domain

service nginx restart

echo 'Installing Tokumei...'
mkdir -p /var/www
git clone https://git.kfarwell.org/tokumei /var/www/$domain

cd /var/www/$domain/sites
ln -s tokumei.co $domain
ln -s tokumei.co www.$domain

charlimit=$(printf '%s\n' "$charlimit" | sed 's/[[\.*^$(){}?+|/]/\\&/g')
filesizelimit=$(printf '%s\n' "$filesizelimit" | sed 's/[[\.*^$(){}?+|/]/\\&/g')
offset=$(printf '%s\n' "$offset" | sed 's/[[\.*^$(){}?+|/]/\\&/g')
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

sed -i "s/^offset=.*$/offset=$offset/;
		s/\/www\/tokumei/\/www\/$domain/" ../bin/aux/trending.rc

cd ..
PATH=$PATH:/usr/lib/plan9/bin ./bin/aux/addwuser.rc "$user_name" "$user_password" posters repliers

(crontab -l 2>/dev/null; echo '0 0 * *   * PATH=$PATH:/usr/lib/plan9/bin /var/www/'$domain'/bin/aux/trending.rc') | crontab -

echo 'Installing and starting cgd...'
mkdir -p /usr/local/go
GOPATH=/usr/local/go go get github.com/uriel/cgd
/usr/local/go/bin/cgd -f -c /var/www/$domain/bin/werc.rc >/dev/null 2>1 &

echo 'Done installing Tokumei. Your site should be available over Tor at http://'$domain'/.'
