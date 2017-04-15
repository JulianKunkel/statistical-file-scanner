#!/bin/bash
FILE="$1"
LZ=lzbench

echo "File types"
file -b "$FILE"
cdo filedes "$FILE"

echo "Starting RUN"
$LZ -eall -o3 -p3 -b10240 -R -z "$FILE" |sed "s#$FILE##"

