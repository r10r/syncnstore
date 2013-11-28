About
==============
Small shell script for doing incremental backups with rsync over ssh.

```
BACKUP_DIR=/var/backups ./backup.sh <profile> root@host.to.backup
```

Only one full backup is made, all other backups are incremental.
A merged backup always reflects the last backup state.

Please run the test script `test_backup.sh` and have a look at the
created directory structure.

```
export BACKUP_DIR=/tmp/backup-test
./test_backup.sh
tree $BACKUP_DIR
```

Profiles
---------------
The profile is a folder relative to `$BACKUP_DIR`.
The profile folder can contain an exclude list
`excludes.txt` that is used by rsync.


Dependencies
---------------

* rsync, cpio, ssh, shell
* Public key authentication to access the host to backup easily