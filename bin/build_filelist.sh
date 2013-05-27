#!/bin/sh

build_filelist() {
    find / \
      -path /tmp -prune \
      -o -path /private/tmp -prune \
      -o -path /dev -prune \
      -o -path /Volumes -prune \
      -o -path /.Spotlight-V100 -prune \
      -o -path /.fseventsd -prune \
      -o -type f -and -size +$1 -print \
      > $2
}

size="$1"
filelist="/tmp/filelist_gt${size}.txt"

echo "Building filelist: $filelist"
time build_filelist $size $filelist