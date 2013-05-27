#!/bin/sh

for exp in 10 20; do
    for mult in 1 5 10 50 100 500 ; do
      size=$(echo $mult*2^$exp | bc)
      time dd if=/dev/urandom of=$size bs=$size count=1
      time rdiff signature $size > $size.sig
      #printf "\x01" | dd of=b.bin bs=1 seek=0x100 count=1 conv=notrunc
    done
done