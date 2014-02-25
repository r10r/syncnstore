#!/bin/bash --posix

# airstation initial
readonly BACKUP_DIR=${BACKUP_DIR:-/mnt/storage/backup}
# delete has no effect here because rsync does not delete from 'compare-dest'
readonly RSYNC_OPTS="--stats --timeout=30 -i -q -avH ${RSYNC_OPTS}"
LOG_PREFIX=""

if which logger 1>/dev/null 2>&1; then
	readonly HAS_LOGGER=true
else
	readonly HAS_LOGGER=false
fi

# $1: message
# $2: severity (optional)
log(){
	local severity=${2:-info}
	# don't use colons and square brackets, as they are
	# used as separators between program and pid 
	local profile="$PROFILE@$TIMESTAMP"

	if $HAS_LOGGER; then
		logger -s -t "backup" -p local0.${severity} "$profile $1"
	else
		echo "backup $profile $1"
	fi
}

log_error() {
	log "$@" error
}

timestamp() {
	date +%Y_%m_%d-%H_%M_%S
}

# Lockfile is remaining to protect backups after a failed backup
#
# $1: the program
# $2: the exit code
handle_error() {
	local program=$1
	local exit_code=$2
	log_error "$program exited with $exit_code"
	return $exit_code
}

# $1: source folder
# $2: target folder
hardlink_files() {
	log "Update hardlinks $1 -> $2"
	# hardlinks only supported by GNU cp command (not on OSX)
	# cp -al $1 $2
	[ -d $2 ] || mkdir -p $2
	rsync --link-dest=$1/ -aH $1/ $2 1>/dev/null 2>&1
#	rsync --link-dest=$1 -avH $1 $2
}

rsync_backup() {
	TIMESTAMP=$1
	PROFILE=$2
	local source=$3
	local profile_dir=$BACKUP_DIR/$PROFILE
	local lockfile=$profile_dir/lock
	local start=`date +%s`

	if ! [ -d $profile_dir ]; then
		log "Creating backup folder $profile_dir"
		mkdir $profile_dir
		touch $profile_dir/excludes.txt
	fi

	if [ -f $lockfile ]; then
		log_error "Existing logfile $lockfile"
		return 2
	else
		touch $lockfile
	fi

	local excludes=$profile_dir/excludes.txt
	local target=$profile_dir/${TIMESTAMP}

	log "Starting backup profile:${PROFILE} source:${source} target:${target}"

	if ! [ -L $profile_dir/first ]; then
		log "Creating first full backup"
		rsync --exclude-from=$excludes $RSYNC_OPTS --log-file ${target}.log \
			$source ${target} || return `handle_error rsync $?`
		ln -s ${target} $profile_dir/first
		hardlink_files ${target} $profile_dir/merged || return `handle_error 'hardlink_files' $?`
	else
		log "Creating incremental backup"
		rsync --exclude-from=$excludes $RSYNC_OPTS --log-file ${target}.log \
			--compare-dest=${profile_dir}/merged $source ${target} || return `handle_error rsync $?`
		# check if directory is empty
		 if ! [ -z "$(ls -A ${target})" ]; then
		 	hardlink_files ${target} ${profile_dir}/merged || return `handle_error 'hardlink_files' $?`
		 fi

		# remove deleted files from merged view
		log "Deleting removed files from ${profile_dir}/merged"
		rsync --exclude-from=$excludes $RSYNC_OPTS \
			--delete $source ${profile_dir}/merged || return `handle_error rsync $?`
	fi

	[ -d ${profile_dir}/last ] && rm ${profile_dir}/last
	ln -s ${target} ${profile_dir}/last
	local end=`date +%s`
	log "Duration $(($end-$start)) seconds"
	unset TIMESTAMP PROFILE
	rm $lockfile
}

if [ "$(basename -- $0)" = "backup.sh" ]; then
	profile=$1
	source=$2
	if [ -z "$profile" ] || [ -z "$source" ]; then
		log "Missing parameters"
		exit 1
	fi
	rsync_backup `timestamp` ${profile} ${source} || exit $?
fi
