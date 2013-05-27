#!/bin/sh

LISTING="/tmp/lsr_listing.txt"
SIZE_LISTING="/tmp/file_sizes.txt"

# $1: expression
# return: file count
file_count() {
    local command="awk 'BEGIN { count=0; }{ if($1) { count+=1 }} END {print count}' < $SIZE_LISTING"
    echo `eval $command`
}

# $1: divident
# $2: divisor
count_percentage() {
    local command="echo 'scale=4; $1/$2' | bc"
    echo `eval $command`
}
# $1: size begin
# $2: size_end
# $3: total_count
print_stats() {
    local size_begin=$1
    local size_end=$2
    local total_count=$3
    count=$(file_count "\$1>$size_begin && \$1<=$size_end" )
    percentage=$(count_percentage $count $total_count)
    echo ">$1&&<=$size_end" $count $percentage
    count=$(file_count "\$1<=$size_end" )
    percentage=$(count_percentage $count $total_count)
    echo "<=$size_end" $count $percentage
    count=$(file_count "\$1>$size_end" )
    percentage=$(count_percentage $count $total_count)
    echo ">$size_end" $count $percentage
}

[ -f $LISTING ] || ls -lR / > $LISTING
[ -f $SIZE_LISTING ] || awk '{print $5}' < $LISTING   | egrep '^[0-9]+$' > $SIZE_LISTING

TOTAL=$(wc -l $SIZE_LISTING | cut -f 2 -d ' ')

echo $TOTAL

PREVIOUS_SIZE=0
for exp in 10 20 30; do
    for mult in 1 5 10 50 100 500 ; do
      size=$(echo $mult*2^$exp | bc)
      print_stats $PREVIOUS_SIZE $size $TOTAL
#      print_stats $(file_count "\$1<=$size")
#      print_stats $(file_count "\$1<=$size")
#      print_stats $(file_count "\$1>$PREVIOUS_SIZE && \$1<$size")
      PREVIOUS_SIZE=$size
    done
done



# must return 1.0
# bash /Users/ruben/Code/syncnstore/fs_size_stats.sh | awk 'BEGIN { sum=0; } {{ count+=$4 }} END {print count}'