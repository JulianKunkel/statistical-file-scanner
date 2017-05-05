#!/bin/bash
FILE="$1"
LZ=lzbench

echo "File types"
file -b "$FILE"
cdo filedes "$FILE"

echo "Starting RUN"
$LZ -m4000 -eall -o4 -p3 -z "$FILE" |sed "s#$FILE##"
#$LZ -m4000 "-elz4fast,17/pithy,0" -o4 -p3 -z -v "$FILE" |sed "s#$FILE##"
