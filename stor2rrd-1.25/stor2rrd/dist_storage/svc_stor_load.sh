#!/bin/ksh
# only SWIZ script
# stderr and stdour rediretcion already in calling script

$PERL -w $BINDIR/svcconfig.pl 
RET=$?
if [ ! $RET -eq 0 ]; then
  date_act=`date "+%Y-%m-%d_%H:%M"`
  echo "$0: $date_act : Command svcconfig.pl ends with return code $RET" 2>>$ERRLOG_SVC
  exit 1
fi

PROC=`ps -ef | egrep 'svcperf.pl *'$STORAGE_NAME' *$' | grep -v grep | wc -l|sed 's/ //g'`
if [ $PROC -lt 2 ]; then
  $PERL -w $BINDIR/svcperf.pl $STORAGE_NAME 1>>$OUTLOG_SVC 2>>$ERRLOG_SVC &
else
  date_act=`date "+%Y-%m-%d_%H:%M"`
  echo "$0: $date_act : Command svcperf.pl is already running for $STORAGE_NAME, cannot start the next one" 
  echo "$0: $date_act : Command svcperf.pl is already running for $STORAGE_NAME, cannot start the next one"  2>>$ERRLOG_SVC
  exit 1
fi

$PERL -w $BINDIR/data_load.pl $STORAGE_NAME 
RET=$?
if [ ! $RET -eq 0 ]; then
  date_act=`date "+%Y-%m-%d_%H:%M"`
  echo "$0: $date_act : Command data_load.pl ends with return code $RET" 2>>$ERRLOG_SVC
  exit 1
fi

