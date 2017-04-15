#!/bin/bash

# Include the path to LZBENCH
export PATH=$PWD/lzbench/:$PATH

./0-check-commmands.sh

mkdir example
cd example

echo "Using partial mode"

../1-scan-files.sh /home/
../2-select-files-partial-mode.py 100 10 files-* > filelist-selection.txt

# Example just runs: ls -lah
# ../4-run-scanner.sh 1 4 "/bin/ls -lah"

# Clean stuff
../4-clean-before-run.sh

# Run the scanner
../4-run-scanner-partial-mode.sh 1 4 $PWD/../plugins/lzbench/run-partial-mode.sh

# Import data into the DB
../5-create-db.py ../plugins/lzbench/parse.py "/home/" thread-output-*

# Analysis
../plugins/lzbench/simple.R


exit 0

echo "Using full mode"

../1-scan-files.sh /home/
../2-select-files.py 100 10 files-* > filelist-selection.txt

# Sample just runs: ls -lah
# ../4-run-scanner.sh 1 4 "/bin/ls -lah"

# Clean stuff
../4-clean-before-run.sh

# Include the path to LZBENCH
../4-run-scanner.sh 1 4 $PWD/../plugins/lzbench/run.sh

# Import data into the DB
../5-create-db.py ../plugins/lzbench/parse.py "/home/" thread-output-*

# Analysis
../plugins/lzbench/simple.R
