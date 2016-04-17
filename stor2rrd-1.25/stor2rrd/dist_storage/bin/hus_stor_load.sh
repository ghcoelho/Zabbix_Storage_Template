#!/bin/ksh
# stderr and stdour redirection is done already when this script is called

PROC=`ps -ef | egrep 'husperf.pl *'$STORAGE_NAME' *$' | grep -v grep | wc -l|sed 's/ //g'`
if [ $PROC -lt 3 ]; then
  $PERL -w $BINDIR/husperf.pl $STORAGE_NAME  
else
  date_act=`date "+%Y-%m-%d_%H:%M"`
  echo "$0: $date_act : Command husperf.pl is already running for $STORAGE_NAME, cannot start the next one"  
  echo "$0: $date_act : Command husperf.pl is already running for $STORAGE_NAME, cannot start the next one"  2>>$ERRLOG_HUS
  exit 1
fi

$PERL -w $BINDIR/data_load.pl $STORAGE_NAME 
if [ ! $? -eq 0 ]; then
  date_act=`date "+%Y-%m-%d_%H:%M"`
  echo "hus_stor_load.sh: $date_act : Command data_load.pl ends with return code $?" 2>>$ERRLOG
  exit 1
fi

