#!/bin/bash --posix

export BACKUP_DIR=${BACKUP_DIR:-/tmp/backup-test}

test_log() {
	echo "[TEST] $1"
}

file_linecount() {
	wc -l $1 | sed 's/^ *//' | cut -d' ' -f 1
}
# $1: the file path
# $1: the expected line count
test_file_linecount() {
	test_log "Ensure line count of $1 is $2"
	lc=`file_linecount $1`
	[ $lc -eq $2 ] || test_error "Expected linecount $2 but was $lc"
}

test_file_linecount_ge() {
	test_log "Ensure line count of $1 is greater than $2"
	lc=`file_linecount $1`
	[ $lc -ge $2 ] || test_error "Expected linecount $lc > $2"
}

test_error() {
	test_log "Error: $1"
	tput bel
	exit 1
}

# $1: the file path
# $2: the text content
test_file_should_equal() {
	test_log "Ensure content of $1 equals: $2"
	test_file_should_exist $1
	test_file_linecount $1 1
	content=`cat $1`
	if [ "$content" != "$2" ]; then
		test_log "expected content: $2"
		test_log "actual content  : $content"
		test_error "File content does not match expected"
	fi
}

test_prompt_remove_dir() {
	while true; do
		read -p "Do you wish to remove $1? " yn
		case $yn in
			Yes|yes|y|Y) rm -rf $1; return 0;;
			No|no|n|N) return 1;;
			*) echo "Please answer yes or no";;
		esac
	done
}

test_rsync() {
	t=$1
	p=$2
	s=$3
	# TODO trailing slash is required (OSX only ?)
	rsync_backup $t $p ${s}/
	exit_code=$?
	[ $exit_code -eq 0 ] || test_error "Backup exited with $exit_code"
}

test_directory_should_exist() {
	test_log "Ensure directory $1 exists"
	[ -d $1 ] || test_error "Directory $1 does not exist."
}

# $1: file1
# $2: file2
test_hardlink() {
	test_log "Ensure file $1 hardlink to $2"
	test_file_should_exist $1
	test_file_should_exist $2
	i1=`ls -i $1 | cut -d' ' -f 1`
	i2=`ls -i $2 | cut -d' ' -f 1`
	[ $i1 -eq $i2 ] || test_error "$1 and $2 are not hardlinks. Inode number is not equal."
}

test_file_should_exist() {
	test_log "Ensure file $1 exists"
	[ -f $1 ] || test_error "File $1 not found"
}

test_file_should_not_exist() {
	test_log "Ensure file $1 does not exist"
	[ -f $1 ] && test_error "File $1 should not exist"
}

test_file_should_not_be_empty() {
	test_file_should_exist $1

}

. ./backup.sh

if [ -d $BACKUP_DIR ]; then
	test_prompt_remove_dir $BACKUP_DIR || test_error "Failed to remove existing backup dir: $BACKUP_DIR"
fi

# global test settings
source=$BACKUP_DIR/source
profile=test1
merged=$BACKUP_DIR/$profile/merged

# first backup
test_backup1() {
	test_log "== INITIAL SYNC TEST"
	mkdir -p $source
	echo r1.sync1 > $source/README1
	echo r2.sync1 > $source/README2
	echo r3.sync1 > $source/README3

	t1=`timestamp`
	test_rsync $t1 $profile $source
	dir1=$BACKUP_DIR/$profile/$t1

	test_directory_should_exist $dir1
	test_file_linecount_ge $dir1.log 20
	test_file_should_equal $dir1/README1 "r1.sync1"
	test_file_should_equal $dir1/README2 "r2.sync1"
	test_file_should_equal $dir1/README3 "r3.sync1"

	test_directory_should_exist $merged
	test_hardlink $merged/README1 $dir1/README1
	test_hardlink $merged/README2 $dir1/README2
	test_hardlink $merged/README3 $dir1/README3
}

test_backup2() {
	test_log "== MODIFIED FILE #1 TEST"
	echo r1.sync2 > $source/README1

	t2=`timestamp`
	test_rsync $t2 $profile $source
	dir2=$BACKUP_DIR/$profile/$t2

	test_directory_should_exist $dir2
	test_file_should_exist $dir2.log
	test_file_linecount_ge $dir2.log 17
	test_file_should_equal $dir2/README1 "r1.sync2"
	test_file_should_not_exist $dir2/README2
	test_file_should_not_exist $dir2/README3

	test_directory_should_exist $merged
	test_hardlink $merged/README1 $dir2/README1
	test_hardlink $merged/README2 $dir1/README2
	test_hardlink $merged/README3 $dir1/README3
}

test_backup3() {
	test_log "== MODIFIED FILE #2 TEST"
	echo r2.sync3 > $source/README2

	t3=`timestamp`
	test_rsync $t3 $profile $source
	dir3=$BACKUP_DIR/$profile/$t3

	test_directory_should_exist $dir3
	test_file_should_not_exist $dir3/README1
	test_file_should_equal $dir3/README2 "r2.sync3"
	test_file_should_not_exist $dir3/README3

	test_directory_should_exist $merged
	test_hardlink $merged/README1 $dir2/README1
	test_hardlink $merged/README2 $dir3/README2
	test_hardlink $merged/README3 $dir1/README3
}

test_backup4() {
	test_log "== NEW FILE TEST"
	echo r4.sync4 > $source/README4

	t4=`timestamp`
	test_rsync $t4 $profile $source
	dir4=$BACKUP_DIR/$profile/$t4

	test_directory_should_exist $dir4
	test_file_should_not_exist $dir4/README1
	test_file_should_not_exist $dir4/README2
	test_file_should_not_exist $dir4/README3
	test_file_should_equal $dir4/README4 "r4.sync4"

	test_directory_should_exist $merged
	test_hardlink $merged/README1 $dir2/README1
	test_hardlink $merged/README2 $dir3/README2
	test_hardlink $merged/README3 $dir1/README3
	test_hardlink $merged/README4 $dir4/README4

	test_file_should_not_exist $dir1/README4
	test_file_should_not_exist $dir2/README4
	test_file_should_not_exist $dir3/README4
}

test_backup5() {
	test_log "== REMOVED FILE TEST"
	rm $source/README3

	t5=`timestamp`
	test_rsync $t5 $profile $source
	dir5=$BACKUP_DIR/$profile/$t5

	test_directory_should_exist $dir5
	test_file_should_not_exist $merged/README3
	test_file_should_not_exist $dir5/README3
}

# TODO test logfile creation

test_backup1
sleep 1
test_backup2
sleep 1
test_backup3
sleep 1
test_backup4
sleep 1
test_backup5
