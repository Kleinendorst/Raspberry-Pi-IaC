#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
# Inspiration of script from: https://borgbackup.readthedocs.io/en/stable/quickstart.html#automating-backups

logInfo() { printf '%(%Y-%m-%d %H:%m:%S)T [INFO]: %s\n' -1 "$*" >&2; }

configurationFileLocation=$1

# Working on the bulk directory which is mounted on a very big SSD, this way we don't have to wory about
# running out of disk space. Note however that borg specifically might make use of cache directories
# in the home directory which aren't on this disk, let's tackle this problem when it actually starts failing...
workDirPath=/bulk/backup_work_dir
borgRepoDir="$workDirPath/borg_backups" # Used throughout the script
logInfo "Creating working directory at: $workDirPath..."
mkdir -p "$workDirPath"

cleanup() {
    logInfo "Backup interrupted"
    # rm -f "$workDirPath" # TODO: Enable
    exit 2
}
trap 'cleanup' INT TERM

# region: ------ DB_BACKUPS -----------------------------------------------------------------------
createDatabaseBackup() {
    host=$1
    dbname=$2
    username=$3
    password=$4
    targetFolderPath=$5

    logInfo "Dumping database: $dbname to $targetFolderPath..."

    # Getting the correct version tools installed on the host proofed to be a very frustrating experience.
    # So instead we'll do the dumping on the container.
    postgresContainerName='postgres-postgres-1'
    containerDumpPath=/dump.sql

    logInfo "Dumping database $dbname on container: $postgresContainerName..."
    docker exec "$postgresContainerName" bash -c "(export PGPASSWORD='$password'; pg_dump $dbname \
        --file $containerDumpPath \
        --host $host \
        --username $username)"

    logInfo "Extracting the archive from the container..."
    docker cp "$postgresContainerName:$containerDumpPath" "$targetFolderPath/$dbname.sql" 2>/dev/null

    logInfo "Removing the file from the docker container..."
    docker exec "$postgresContainerName" rm "$containerDumpPath"
}

createAllDatabaseBackups() {
    nrOfConfigurations="$(yq '.database_backups | length' <"$configurationFileLocation")"
    logInfo "Backing up from $nrOfConfigurations database configurations..."

    postgresBackupDirectory="$workDirPath/postgres"
    mkdir -p "$postgresBackupDirectory"

    for ((i = 0 ; i < "$nrOfConfigurations" ; i++)); do
        dbConfiguration="$(yq ".database_backups[$i]" <"$configurationFileLocation")"
        host="$(echo "$dbConfiguration" | jq -r '.host')"
        dbname="$(echo "$dbConfiguration" | jq -r '.dbname')"
        username="$(echo "$dbConfiguration" | jq -r '.username')"
        password="$(echo "$dbConfiguration" | jq -r '.password')"
        targetFolderPath="$postgresBackupDirectory"

        createDatabaseBackup "$host" "$dbname" "$username" "$password" "$targetFolderPath"
    done
}
# endregion: --- DB_BACKUPS -----------------------------------------------------------------------

# region: ------ DOCKER_VOLUME_BACKUPS ------------------------------------------------------------
createDockerVolumeBackup() {
    containerName=$1
    volumeName=$2
    specificVolumeBackupPath=$3

    logInfo "Backup up Docker volume: $volumeName from running container: $containerName..."

    logInfo "Stopping container: $containerName..."
    docker stop "$containerName"

    logInfo "Starting new container which copies over files..."
    start=$SECONDS
    docker run --rm -v "$volumeName:/volume" -v "$specificVolumeBackupPath:/target" --entrypoint "ash"\
        alpine -c "cp -rf /volume/* /target/"

    elapsedSeconds=$(( SECONDS - start ))
    logInfo "Copying succeeded (in $elapsedSeconds seconds), restarting container..."
    docker start "$containerName"
}

createAllDockerVolumeBackups() {
    nrOfConfigurations="$(yq '.docker_volume_backups | length' <"$configurationFileLocation")"
    logInfo "Backing up from $nrOfConfigurations docker configurations..."

    dockerVolumeBackupPath="$workDirPath/docker_volumes"
    mkdir -p "$dockerVolumeBackupPath"

    for ((i = 0 ; i < "$nrOfConfigurations" ; i++)); do
        dockerConfiguration="$(yq ".docker_volume_backups[$i]" <"$configurationFileLocation")"
        containerName="$(echo "$dockerConfiguration" | jq -r '.container_name')"
        volumeName="$(echo "$dockerConfiguration" | jq -r '.volume_name')"

        specificVolumeBackupPath="$dockerVolumeBackupPath/$volumeName"
        mkdir -p "$specificVolumeBackupPath"

        createDockerVolumeBackup "$containerName" "$volumeName" "$specificVolumeBackupPath"
    done
}
# endregion: --- DOCKER_VOLUME_BACKUPS ------------------------------------------------------------

# region: ------ BORG_BACKUPS ---------------------------------------------------------------------
createArchiveInRepository() {
    logInfo "Creating new archive in Borg repository (at $borgRepoDir)..."

    (
        cd "$workDirPath"

        # Note that BORG_PASSPHRASE is supposed to be set, otherwise a passowrd prompt will be present...
        borg create --stats --verbose --show-rc --compression zstd,11 \
            "$borgRepoDir::{fqdn}-{now:%Y-%m-%d}" \
            ./docker_volumes ./postgres

        logInfo "Pruning old backups..."
        # Copied from: https://borgbackup.readthedocs.io/en/stable/quickstart.html as it seems
        # like good defaults.
        borg prune --verbose --glob-archives '{fqdn}-*' --show-rc \
            --keep-daily 7 --keep-weekly 4 --keep-monthly 6 \
            "$borgRepoDir"

        logInfo "Compacting repository..."
        borg compact --verbose --show-rc "$borgRepoDir"
    )
}
# endregion: --- BORG_BACKUPS ---------------------------------------------------------------------

# region: ------ PREPARE_BACKUP_FILES -------------------------------------------------------------
createAllDatabaseBackups
echo
createAllDockerVolumeBackups
echo
# TODO: fetchOldBackupRepositoryFromCloud
createArchiveInRepository
# endregion: --- PREPARE_BACKUP_FILES -------------------------------------------------------------
