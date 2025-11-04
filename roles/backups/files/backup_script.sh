#!/usr/bin/env bash
# Inspiration of script from: https://borgbackup.readthedocs.io/en/stable/quickstart.html#automating-backups
configurationFileLocation=$1

# region: ------ HELPER_FUNCTIONS ------------------------------------------------------------------
logInfo() { printf '%(%Y-%m-%d %H:%m:%S)T [INFO]: %s\n' -1 "$*" >&2; }
# endregion: --- HELPER_FUNCTIONS ------------------------------------------------------------------

workDirPath=/mnt/tmpfs
logInfo "Creating working directory at: $workDirPath..."
mkdir -p "$workDirPath"
logInfo "Mounting temporary (in ram) filesystem at: $workDirPath..."
# See: https://unix.stackexchange.com/questions/188536/how-to-make-a-temporary-file-in-ram#188540
mount -t tmpfs -o size=500m tmpfs /mnt/tmpfs

logInfo "Changing work directory to: $workDirPath..."
cd $workDirPath || exit 1

cleanup() {
    # Exiting from the temporary working directory is necessary
    # otherwise umount results in a "umount: /mnt/tmpfs: target is busy."
    # error. This is because this script's process is keeping the device busy.
    logInfo "Exiting current working directory..."
    cd ~ || exit 1
    logInfo "Unmounting temporary filesystem..."
    umount "$workDirPath"
}
trap 'logInfo "Backup interrupted"; cleanup; exit 2' INT TERM
trap 'logInfo "Backup completed, cleaning up..."; cleanup' EXIT

# region: ------ DB_BACKUPS -----------------------------------------------------------------------
createPostgresDatabaseBackup() {
    host=$1
    dbname=$2
    username=$3
    password=$4
    targetFolderPath=$5

    logInfo "Dumping Postgres database: $dbname to $targetFolderPath..."

    # Getting the correct version tools installed on the host proofed to be a very frustrating experience.
    # So instead we'll do the dumping on the container.
    postgresContainerName='postgres-postgres-1'

    logInfo "Dumping database $dbname on container: $postgresContainerName..."
    docker exec "$postgresContainerName" bash -c "(export PGPASSWORD='$password'; pg_dump $dbname \
        --host $host \
        --username $username)" > "$targetFolderPath/$dbname.sql"
}

createAllPostgresDatabaseBackups() {
    nrOfConfigurations="$(yq '.database_backups.postgres | length' <"$configurationFileLocation")"
    logInfo "Backing up from $nrOfConfigurations postgres database configurations..."

    postgresBackupDirectory="$workDirPath/postgres"
    mkdir -p "$postgresBackupDirectory"

    for ((i = 0 ; i < "$nrOfConfigurations" ; i++)); do
        dbConfiguration="$(yq ".database_backups.postgres[$i]" <"$configurationFileLocation")"
        host="$(echo "$dbConfiguration" | jq -r '.host')"
        dbname="$(echo "$dbConfiguration" | jq -r '.dbname')"
        username="$(echo "$dbConfiguration" | jq -r '.username')"
        password="$(echo "$dbConfiguration" | jq -r '.password')"
        targetFolderPath="$postgresBackupDirectory"

        createPostgresDatabaseBackup "$host" "$dbname" "$username" "$password" "$targetFolderPath"
    done
}
# endregion: --- DB_BACKUPS -----------------------------------------------------------------------

# region: ------ BORG_BACKUPS ---------------------------------------------------------------------
createArchiveInRepository() {
    logInfo "Creating new Postgres archive in Borg repository (at $BORG_REPO)..."

    (
        cd "$workDirPath" || exit 1

        logInfo "Stopping all containers for which backups should be stored..."
        targetDockerContainers="$(yq -r '.docker_mount_backups | map(.container_name) | unique | join(" ")' <"$configurationFileLocation")"
        stopCommand="docker stop $targetDockerContainers"
        logInfo "Running: $stopCommand..."
        $stopCommand

        targetDockerMounts="$(yq -r '.docker_mount_backups | map(.mount_path) | join(" ")' <"$configurationFileLocation")"
        logInfo "Storing these mounts into backup: $targetDockerMounts..."

        # Note that both BORG_PASSPHRASE and BORG_REPO should be set, otherwise a password prompt will be present...
        logInfo "Running borg backup command for database backups and docker mounts: $targetDockerMounts..."
        borg create --stats --verbose --show-rc --compression zstd,11 \
            "::{fqdn}-{now:%Y-%m-%d}" \
            $targetDockerMounts ./postgres

        logInfo "Starting all containers for which backups should be stored..."
        startCommand="docker start $targetDockerContainers"
        logInfo "Running: $startCommand..."
        $startCommand

        logInfo "Pruning old backups..."
        # Copied from: https://borgbackup.readthedocs.io/en/stable/quickstart.html as it seems
        # like good defaults.
        borg prune --verbose --glob-archives '{fqdn}-*' --show-rc \
            --keep-daily 7 --keep-weekly 4 --keep-monthly 6

        logInfo "Compacting repository..."
        borg compact --verbose --show-rc
    )
}
# endregion: --- BORG_BACKUPS ---------------------------------------------------------------------

# region: ------ PREPARE_BACKUP_FILES -------------------------------------------------------------
createAllPostgresDatabaseBackups
echo
createArchiveInRepository
# endregion: --- PREPARE_BACKUP_FILES -------------------------------------------------------------
