#!/bin/bash
# -- About --
#
# * requires SSH public key authentication
# * requires rsync to be executed without password using sudo
# * install cronjob: http://benr75.com/pages/using_crontab_mac_os_x_unix_linux
# * requires the terminal notifier gem

# -- TODO --
#
# * move excludes into profile
# * watchdog (cron scripts that checks if backup was run)


LOCKFILE="/tmp/rsync-backup.lock"
PROG=$0
RSYNC="/usr/local/Cellar/rsync/3.0.9/bin/rsync"
CONF="$HOME/.rsync"
PROFILE=$1
CONFIG_FILE=$CONF/profiles/$PROFILE
DATE="+%Y_%m_%d-%H:%M:%S"
NEW=$(date $DATE)
LOGFILE_BASENAME="$CONF/logs/${PROFILE}_${NEW}"
LOGFILE="$LOGFILE_BASENAME"
RSYNC_LOGFILE="${LOGFILE_BASENAME}.files"
IO_TIMEOUT="30"

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"
NOTIFY="terminal-notifier"

# redirect output (STDERR and STDOUT) to logfile
exec > $LOGFILE 2>&1

function log {
    echo $1
    $NOTIFY -title "RSync Backup [${PROFILE}]" -message "${1}" -open file://$LOGFILE
}

function load_configuration {
    if [ ! -f $CONFIG_FILE ]; then
      echo "Invalid profile: $CONFIG_FILE"
      exit 1
    fi

    echo
    echo ">> Using configuration: $CONFIG_FILE"
    cat $CONFIG_FILE
    . $CONFIG_FILE
    echo

    EXCLUDE="$CONF/excludes"
    echo
    echo ">> Using excludes: $EXCLUDE"
    cat $EXCLUDE
    echo
}

function check_connection {
    # TODO use rsync connection timeout for that ?
    if ! nc -w 1 $REMOTE_HOST $REMOTE_PORT > /dev/null 2>&1; then
      log "${REMOTE_HOST}:${REMOTE_PORT} unreachable"
      exit 1
    fi
}

function create_lockfile {
    if [ -f $LOCKFILE ]; then
      if kill -0 $(cat $LOCKFILE); then
        log "Previous backup $(cat $LOCKFILE) still running"
      else
        log "Dead lockfile"
      fi
      exit 1
    else
      echo $$ > $LOCKFILE
    fi
}

function run_rsync {

    COMPARE_DEST=$(ssh ${REMOTE} "ls -r ${DST} | cut -f  1" | xargs -I {} echo "--compare-dest=${DST}{}" | tr '\n' ' ')

    RSYNC_BASE_OPTIONS="-ax --stats -S -H -X -e ssh"
    RSYNC_CMD_OPTIONS="--timeout=${IO_TIMEOUT} --exclude-from=${EXCLUDE} --log-file ${RSYNC_LOGFILE}"
    RSYNC_CMD="sudo $RSYNC ${RSYNC_BASE_OPTIONS} ${RSYNC_CMD_OPTIONS}  ${COMPARE_DEST} ${SRC} ${REMOTE}:${DST}/${NEW}"

    echo "Executing command: ${RSYNC_CMD}"
    if [ "$1" != "test" ]; then
        ${RSYNC_CMD}
        rsync_status=$?
        if [ $rsync_status -ne 0 ]; then
            log "Rsync failed with status ${rsync_status}"
          exit 1
        fi
    fi
}

function compress_logfile {
    # compress logfile
    if tar czf ${RSYNC_LOGFILE}.tar.gz $RSYNC_LOGFILE; then
      rm -f $RSYNC_LOGFILE
    fi
}

# -v increase verbosity
# -a turns on archive mode (recursive copy + retain attributes)
# -x don't cross device boundaries (ignore mounted volumes)
# -S handles spare files efficiently
# -H preserves hard-links
# --extended-attributes preserves ACLs and Resource Forks
# --delete deletes any files that have been deleted locally
# --delete-excluded deletes any files that are part of the list of excluded files
# --exclude-from reference a list of files to exclude

log "Backup started"
echo "-- Start backup $(date)"
load_configuration
check_connection
create_lockfile
run_rsync
compress_logfile
echo "-- Stop backup $(date)"
log "Backup finished"
rm $LOCKFILE
exit 0
