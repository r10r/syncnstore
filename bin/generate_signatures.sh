#!/bin/sh

filelist=$1
filesize=$2
TARGET="/tmp/rdiff-signatures/${filesize}"
mkdir -p $TARGET

generate_signatures() {
    while read path; do
     checksum=$(echo $path | shasum | cut -d ' ' -f1)
     command="rdiff signature $(printf %q "$path") $TARGET/$checksum"
     eval $command
    done <  $1
}

echo "Generating signatures in $TARGET for filelist: $filelist"
time generate_signatures $filelist

