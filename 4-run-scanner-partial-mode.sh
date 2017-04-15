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

function sql_wrapper() {
  THREAD="$1"
  SQL="$2"
  RES=$(echo "$SQL;" | sqlite3 status-$THREAD.db 2>&1)
  if [[ $? == 0 ]] ; then
    if [[ "$2" != "false" ]]; then
      echo $RES
    fi
    return
  fi
  echo "Error, it looks like more than one thread was started with the same thread number! Aborting!"
  exit 1
}


function run_thread (){
 # manage a table to indicate completed files

 THREAD="$1"
 if [ ! -e  status-$THREAD.db ] ; then
  sql_wrapper $THREAD "create table ongoing (filename text, position int, thread int PRIMARY KEY, completed int);"
 fi
 POS=$(sql_wrapper $THREAD "select position from ongoing where thread = $THREAD UNION  ALL SELECT "0" LIMIT 1" )

 FILE_COUNT=$(cat thread-filelist-$THREAD |wc -l)
 TAIL=$(($FILE_COUNT - $POS))
 echo Starting thread $T pos $POS with \"$execution\"
 PROC_FILES_START=$POS
 COMPLETED=0
 set +m
 tail -n $TAIL thread-filelist-$THREAD | while IFS= read -r LINE; do
   FILE=$(echo $LINE | cut -d " " -f 2-)
   SIZE=$(echo $LINE | cut -d " " -f 1)

   if [[ $SIZE == "AGAIN" ]] ; then  # This should not happen!
      echo "It looks like the filelist was created for full mode, but this script is for partial mode only, this leads to wrong results, aborting!"
      exit 1
   fi

   POS=$(($POS + 1))

   echo Thread $THREAD processing $FILE
   if [[ ! -e "$FILE" ]] ; then
     echo "Processing invalid, file deleted: $FILE" >> thread-output-$THREAD
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
     COMPLETED=$(($COMPLETED + 1))
   fi

   cat thread-tmp-$THREAD >> thread-output-$THREAD
   RES=$(sql_wrapper $THREAD "replace into ongoing (filename,position,thread,completed) VALUES(\"$FILE\", $POS, $THREAD, $COMPLETED)" false)
 done
 COMPLETED=$(sql_wrapper $THREAD "select completed from ongoing")
 RES=$(sql_wrapper $THREAD "replace into ongoing (filename,position,thread,completed) VALUES(\"\", $FILE_COUNT, $THREAD,0)" false)
 rm thread-tmp-$THREAD 2>/dev/null

 echo "Thread $THREAD completed, processed: $COMPLETED files"
}

alias time="/usr/bin/time"

for T in $(seq $START $END); do
  run_thread $T &
done

wait

echo "Done"
