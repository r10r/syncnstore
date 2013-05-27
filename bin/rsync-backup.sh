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

# http://samba.2283325.n4.nabble.com/xattrs-on-symlinks-td2505771.html
#
# http://help.bombich.com/discussions/questions/5941-rsync-error-get_xattr_names-llistxattr-no-such-file-or-directory
# when using --link-dest the receiver outputs a log of error messages

# --prune-empty-dirs is not working
# https://lists.samba.org/archive/rsync/2009-October/023981.html
# removing empty directories does not work either (find . -type d -emptyf -exec rmdir {} \;)
# on qnap because busybox find does not have the '-empty' option

# create backup locally in a sparse image transfer afterwards (avoid expensive roundtrips)


LOCKFILE="/tmp/rsync-backup.lock"
PROG=$0
RSYNC="/tmp/homebrew/rsync-3.0.9/rsync"
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

#    COMPARE_DEST=$(ssh ${REMOTE} "ls -r ${DST} | cut -f  1" | xargs -I {} echo "--compare-dest=${DST}{}" | tr '\n' ' ')
     COMPARE_DEST="--compare-dest=${DST}/2013_05_14-14:00:21"

    RSYNC_BASE_OPTIONS="-ax --stats -S -H -X -e ssh --prune-empty-dirs"
    RSYNC_CMD_OPTIONS="--timeout=${IO_TIMEOUT} --exclude-from=${EXCLUDE} --log-file ${RSYNC_LOGFILE}"
    RSYNC_CMD="sudo $RSYNC ${RSYNC_BASE_OPTIONS} ${RSYNC_CMD_OPTIONS}  ${COMPARE_DEST} ${SRC} ${REMOTE}:${DST}/${NEW}"

    echo "Executing command: ${RSYNC_CMD}"
    if [ "$1" != "test" ]; then
        ${RSYNC_CMD}
        compress_rsync_logfile
        rsync_status=$?
        # TODO check errors (in itemize changes?)
        # ignore error 23 for now
        if [ $rsync_status -ne 0 -a  $rsync_status -ne 23 ]; then
            log "Rsync failed with status ${rsync_status}"
          exit 1
        fi
    fi
}

function compress_rsync_logfile {
    # compress logfile
    if tar czf ${RSYNC_LOGFILE}.tar.gz $RSYNC_LOGFILE; then
      rm -f $RSYNC_LOGFILE
    fi
}

function strip_logfile {
    mv $LOGFILE $LOGFILE.orig
    cat $LOGFILE.orig | grep -v "rsync: get_xattr_names: llistxattr(.*) failed: No such file or directory (2)" > $LOGFILE
    rm $LOGFILE.orig

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
echo "-- Stop backup $(date)"
log "Backup finished"
strip_logfile
rm $LOCKFILE
exit 0
