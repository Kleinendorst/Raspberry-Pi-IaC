#!/bin/bash
echo "Running as $(whoami)..."
certsPath="/home/postgres/certs"
target_host_postgres_id=70

if [[ ! -e "$certsPath" ]]; then
    echo "Certs directory doesn't exist, creating certs directory: $certsPath..."
    mkdir "$certsPath"
fi

echo "Copying certificates..."
cert_files='/etc/letsencrypt/live/postgres.kleinendorst.info/fullchain.pem /etc/letsencrypt/live/postgres.kleinendorst.info/privkey.pem'
for srcPath in $cert_files; do
    echo "Copying: $srcPath to $certsPath..."
    cp -L "$srcPath" "$certsPath"

    newFileName="$certsPath/$(basename $srcPath)"
    chown "$target_host_postgres_id:$target_host_postgres_id" "$newFileName"
    chmod 0600 "$newFileName"
done
