#!/bin/bash

# This is the file scanner

if [[ "$1" == "" ]] ; then
  echo "Synopsis: $0 <directory to scan>"
  exit 1
fi

TARGET="$1"
dirs=$(ls $TARGET)

function scanner(){
	ls -lR --file-type  --time-style=iso  $1  2>/dev/null
}

for d in $dirs ; do
  if [[ -d "$TARGET/$d" ]]; then
    echo "Scanning $d"
    (  scanner $TARGET/$d ) > files-$d.txt &
    if [[ $(jobs|wc -l) -gt 100 ]] ; then
       echo "Waiting"
       wait
    fi
  fi
done

wait
