#!/bin/bash

# TODO
# - add command information to logfile
# - append error output to logfile (separate logfile?)
# - move excludes into profile
# - add mode for syncing into the same directory
# - check if backup host is available !!!

# requires SSH public key authentication
# requires rsync to be executed without password using sudo
# install cronjob: http://benr75.com/pages/using_crontab_mac_os_x_unix_linux
# requires the terminal notifier gem

# add lockfile (prevents two running backup processes)
# itemize changes
# watchdog (cron scripts that checks if backup was run)
# check if connection is available (currently it runs into a rsync)

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

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"
NOTIFY="terminal-notifier"

# redirect output (STDERR and STDOUT) to logfile
exec > $LOGFILE 2>&1

function log {
    echo $1
    $NOTIFY -title "RSync Backup [${PROFILE}]" -message "${1}" -open file://$LOGFILE
}
function load_configuration {
    if [ ! -f $CONFIG_FILE ]
    then
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
    if ! nc -w 1 $REMOTE_HOST $REMOTE_PORT > /dev/null 2>&1
    then
      log "${REMOTE_HOST}:${REMOTE_PORT} unreachable"
      exit 1
    fi
}

function create_lockfile {
    if [ -f $LOCKFILE ]
    then
      if kill -0 $(cat $LOCKFILE)
      then
        log "Previous backup $(cat $LOCKFILE) still running"
      else
        log "Dead lockfile"
      fi
      exit 1
    else
      echo $$ > $LOCKFILE
    fi
}

function copy_reference {
    # find previous backup and create hardlink
    PREVIOUS=$(ssh $REMOTE "ls -r $DST | cut -f  1 | head -n1")

    # copy old folder
    if [ -n "$PREVIOUS" ]
    then
      echo "Using previous backup for reference: $PREVIOUS"
    # disable when syncing to previous directory
      ssh $REMOTE "cp -al $DST/$PREVIOUS $DST/$NEW"
    else
      echo "No previous backup found"
      ssh $REMOTE "mkdir $DST/$NEW"
    fi
}

function run_rsync {
    # insert -n for dry-run
    # sync to new directory
    CMD="sudo $RSYNC -ax --stats -S -H -X -e ssh --delete --exclude-from=$EXCLUDE --timeout=30 --log-file $RSYNC_LOGFILE $SRC $REMOTE:$DST/$NEW"

    # sync to previous directory
    #CMD="sudo $RSYNC -ax --stats -S -H -X -e ssh --delete --exclude-from=$EXCLUDE --log-file $RSYNC_LOGFILE $SRC $REMOTE:$DST/$PREVIOUS"
    echo "Executing command: $CMD"
    $CMD
    rsync_status=$?

    if [ $rsync_status -ne 0 ]
    then
        log "Backup failed"
      exit 1
    fi
}

function compress_logfile {
    # compress logfile
    if tar czf ${RSYNC_LOGFILE}.tar.gz $RSYNC_LOGFILE
    then
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
copy_reference
run_rsync
compress_logfile
echo "-- Stop backup $(date)"
log "Backup finished"
rm $LOCKFILE
exit 0
