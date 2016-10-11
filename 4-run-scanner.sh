#!/bin/bash

start=$1
count=$2
execution="$3"

if [[ "$start" == "" ||  "$count" == "" || "$execution" == "" ]] ; then
  echo "Synopsis: $0 <START-thread> <thread-count> <execution plugin>"
  exit 1
fi

START=$start
END=$(($start+$count - 1))

# manage two tables, one for the files that have been completed and one that are currently ongoing
echo "create table completed (filename text, thread int, CONSTRAINT name_unique UNIQUE (filename));" | sqlite3 status.db
echo "create table ongoing (filename text, position int, thread int PRIMARY KEY);" | sqlite3 status.db

function sql_wrapper() {
  SQL="$1"
  while true ; do
    RES=$(echo "$SQL;" | sqlite3 status.db 2>&1)
    if [[ $? == 0 ]] ; then
      if [[ "$2" != "false" ]]; then
        echo $RES
      fi
      return
    fi
    echo $RES | grep "database is locked" >/dev/null
    if [[ $? == 0 ]] ; then
      sleep 0.1$THREAD
    else
      echo "ERROR: $RES"
      return
    fi
  done
}


function run_thread (){
 # ) >> thread-progress-$T.txt 2>&1 &
 THREAD="$1"
 POS=$(sql_wrapper "select position from ongoing where thread = $THREAD UNION  ALL SELECT "0" LIMIT 1" )

 FILE_COUNT=$(cat thread-filelist-$THREAD |wc -l)
 TAIL=$(($FILE_COUNT - $POS))
 echo Starting thread $T pos $POS with \"$execution\"
 PROC_FILES_START=$(sql_wrapper "select count(*) from completed where thread = $THREAD")

 set +m
 tail -n $TAIL thread-filelist-$THREAD | while IFS= read -r LINE; do
   FILE=$(echo $LINE | cut -d " " -f 2-)
   SIZE=$(echo $LINE | cut -d " " -f 1)
   FILE_PROCESSING=$(sql_wrapper "replace into ongoing (filename,position,thread) VALUES(\"$FILE\", $POS, $THREAD); select thread from ongoing where filename = \"$FILE\" union select filename from completed where filename = \"$FILE\"")

   POS=$(($POS + 1))

   if [[ "$FILE_PROCESSING" != "$THREAD" ]] ; then
 	    echo "Already processed: $FILE" >> thread-output-$THREAD
 		  continue
 	 fi
   echo $T processing $FILE
   if [[ ! -e "$FILE" ]] ; then
     echo "Processing invalid, file deleted: $FILE" >> thread-output-$THREAD
     sql_wrapper "insert into completed (filename, thread) VALUES(\"$FILE\", $THREAD)" false
     continue
   fi

   SIZE_OBSERVED=$(stat -c "%s" "$FILE")
   if [[ "$SIZE_OBSERVED" != "$SIZE" ]] ; then
     echo "Processing invalid, size changed $SIZE != $SIZE_OBSERVED: $FILE" > thread-tmp-$THREAD 2>&1
   else
     # run the command
     echo "Processing: $SIZE $FILE" > thread-tmp-$THREAD
     $execution "$FILE" >> thread-tmp-$THREAD 2>&1

     SIZE_OBSERVED=$(stat -c "%s" "$FILE")
     if [[ "$SIZE_OBSERVED" != "$SIZE" ]] ; then
       echo "Processing invalid, size changed $SIZE != $SIZE_OBSERVED: $FILE" > thread-tmp-$THREAD 2>&1
     fi
   fi

   cat thread-tmp-$THREAD >> thread-output-$THREAD

   sql_wrapper "insert into completed (filename, thread) VALUES(\"$FILE\", $THREAD)" false
 done
 sql_wrapper "replace into ongoing (filename,position,thread) VALUES(\"\", $FILE_COUNT, $THREAD)" false
 rm thread-tmp-$THREAD 2>/dev/null

 PROC_FILES_END=$(sql_wrapper "select count(*) from completed where thread = $THREAD")
 echo "$T completed, processed: " $(($PROC_FILES_END - $PROC_FILES_START)) files
}



alias time="/usr/bin/time"

for T in $(seq $START $END); do
  run_thread $T &
done

wait

echo "Done"
