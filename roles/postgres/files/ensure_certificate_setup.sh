#!/bin/bash
echo "Running as $(whoami)..."

target_user='postgres'
# This user shouldn't be mapped to postgres on the host but rather to postgres on the container.
# This user has host uid: 558821 (in container it's uid: 70). This number is resolved by getting the start
# of the subuid range for this user and then than adding 70 (-1) to it (since we know that that is the uid
# of the postgres user within the container).
target_path_subuid_start="$(su $target_user -c 'grep $USER /etc/subuid | cut -d ":" -f 2')"
target_host_postgres_id=$(($target_path_subuid_start + 70 - 1))

certsPath="/home/$target_user/certs"

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
    echo "Setting permissions for: $newFileName to uid: $target_host_postgres_id..."

    chown "$target_host_postgres_id:$target_host_postgres_id" "$newFileName"
    chmod 0600 "$newFileName"
done
