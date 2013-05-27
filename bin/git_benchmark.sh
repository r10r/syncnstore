#!/bin/sh

# generate base file
size=$1
dd if=/dev/urandom of=$size bs=$size count=1
rdiff signature $size > $size.sig

# generate modified files

git init deltastore
git init fullstore

COUNT=$2

generate_modified_files() {
    for i in $(seq $COUNT); do
      cp $size ${size}.$i
#      printf "\x01" | dd of=${size}.$i bs=1 seek=$i count=1 conv=notrunc 1>/dev/null 2>&1
      printf "\x$i" | dd of=${size}.$i bs=2 seek=100 count=1 conv=notrunc 1>/dev/null 2>&1
    done
}

generate_deltas() {
    echo "-- DELTA GENERATION"
    for i in $(seq $COUNT); do
          rdiff delta $size.sig ${size}.$i > ${size}.$i.delta
    done
}

move_files() {
    echo "-- MOVE FILES"
    for i in $(seq $COUNT); do
     mv ${size}.$i fullstore
     mv ${size}.$i.delta deltastore
    done
}


persist() {
    cd $1
    git add -A
    git commit -q -m "foo"
    git gc
    du -hs .git
    cd ..
}

generate_modified_files
time generate_deltas
move_files
echo "-- FULL STORE"
time persist fullstore
echo "-- DELTA STORE"
time persist deltastore
