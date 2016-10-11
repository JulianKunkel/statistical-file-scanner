#!/bin/bash
mkdir example

cd example
../1-scan-files.sh /home/
../2-select-files.py 100 10 files-* > filelist-selection.txt

# Sample just runs: ls -lah
# ../4-run-scanner.sh 1 4 "/bin/ls -lah"

# Clean stuff
../4-clean-before-run.sh

# Include the path to LZBENCH
export PATH=/home/julian/Dokumente/DKRZ/wr-git/file-scanner/final/lzbench/:$PATH
../4-run-scanner.sh 1 4 $PWD/../plugins/lzbench/run.sh

# Import data into the DB
../5-create-db.py ../plugins/lzbench/parse.py "/home/" thread-output-*

# Analysis
../plugins/lzbench/simple.R
