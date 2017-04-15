#!/bin/bash
../2-select-files.py 10000 1 filelist.txt | tee outfilelist.txt

echo 
echo "Please check that the file size is roughly proportional to the number of selections"

CNT=$(grep ^AGAIN thread-filelist-1 |wc -l)

if [ "$CNT" != 9997 ] ;then
	echo "Test failed, number of repeats must be 9997"
	exit 1
fi 

CNT=$(cat outfilelist.txt |grep work | wc -l)

if [ "$CNT" != 3 ] ;then
	echo "Test failed, number of files scanned must be 3"
	exit 1
fi 


echo "Please check that the value above is for largefile the same as in the file " $(grep "/work/largefile" thread-filelist-1 | wc -l)

rm thread-filelist-1
rm outfilelist.txt

exit 0
