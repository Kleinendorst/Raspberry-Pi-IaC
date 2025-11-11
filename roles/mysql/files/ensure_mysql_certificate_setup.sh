#!/bin/bash
echo "Running as $(whoami)..."
certsPath="/home/thomas/mysql/certs"
target_host_mysql_id=999

if [[ ! -e "$certsPath" ]]; then
    echo "Certs directory doesn't exist, creating certs directory: $certsPath..."
    mkdir "$certsPath"
fi

echo "Downloading ISRG root certificate..."
curl -s https://letsencrypt.org/certs/isrgrootx1.pem -o "$certsPath/isrgrootx1.pem"
echo "Combining ca certificate and root certificate..."
cat /etc/letsencrypt/live/mysql.kleinendorst.info/chain.pem "$certsPath/isrgrootx1.pem" > "$certsPath/ca.pem"

echo "Copying certificates..."
cert_files='/etc/letsencrypt/live/mysql.kleinendorst.info/cert.pem /etc/letsencrypt/live/mysql.kleinendorst.info/privkey.pem'
for srcPath in $cert_files; do
    echo "Copying: $srcPath to $certsPath..."
    cp -L "$srcPath" "$certsPath"
done

chown "$target_host_mysql_id:$target_host_mysql_id" $certsPath/*
chmod 0600 $certsPath/*
