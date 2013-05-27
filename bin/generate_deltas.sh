#!/bin/sh

# find . -type d \( -path dir1 -o -path dir2 -o -path dir3 \) -prune -o -print

filesize=$1

TARGET="/tmp/rdiff-signatures/${filesize}"
mkdir -p $TARGET

while read path; do
 checksum=$(echo $path | shasum | cut -d ' ' -f1)
 command="rdiff signature $(printf %q "$path") $TARGET/$checksum"
 eval $command
done <  /tmp/filelist_gt100k.txt.4

# no trailing slash for paths!
# use or as condition
# $1: minimum file size


