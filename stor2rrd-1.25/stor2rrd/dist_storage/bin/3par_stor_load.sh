#!/bin/ksh
# stderr and stdour rediretcion already in calling script

PROC=`ps -ef | egrep 'hp3parperf.pl *'$STORAGE_NAME' *$' | grep -v grep | wc -l|sed 's/ //g'`
if [ $PROC -lt 13 ]; then # normally runs 5 processes per storage
  $PERL -w $BINDIR/hp3parperf.pl $STORAGE_NAME 1>>$OUTLOG_SVC 2>>$ERRLOG_SVC &
else
  date_act=`date "+%Y-%m-%d_%H:%M"`
  echo "$0: $date_act : Command hp3parperf.pl is already running for $STORAGE_NAME, cannot start the next one" 
  echo "$0: $date_act : Command hp3parperf.pl is already running for $STORAGE_NAME, cannot start the next one"  2>>$ERRLOG_SVC
  # exit 1 --> run data_load anyway
fi

$PERL -w $BINDIR/data_load.pl $STORAGE_NAME  >/dev/null # stdout to null on purpose here to do not fill up logs
RET=$?
if [ ! $RET -eq 0 ]; then
  date_act=`date "+%Y-%m-%d_%H:%M"`
  echo "$0: $date_act : Command data_load.pl ends with return code $RET" 2>>$ERRLOG_SVC
  exit 1
fi

