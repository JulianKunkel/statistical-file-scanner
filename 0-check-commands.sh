#!/bin/bash
echo "Checking commands"

if [ ! -e lzbench ] ; then
  echo "Preparing lzbench"
  git clone https://github.com/JulianKunkel/lzbench.git
  cd lzbench
  make -j 3
  cd ..
fi

# Include the path to LZBENCH
export PATH=$PWD/lzbench/:$PATH

OUT=$(file -v 2>/dev/null)
if [ $? != 0 ] ; then
  echo "Tool file not found!"
  exit 1
fi
OUT=$(cdo -v 2>/dev/null)
if [ $? != 1 ] ; then
  echo "Tool cdo not found!"
  exit 1
fi
OUT=$(sqlite3 -version 2>/dev/null)
if [ $? != 0 ] ; then
  echo "Tool sqlite3 not found!"
  exit 1
fi

echo OK
