#!/bin/ksh
# stderr and stdour redirection is done already when this script is called

#$PERL -w $BINDIR/svcconfig.pl 1>>$OUTLOG_SVC 2>>$ERRLOG_SVC
#if [ ! $? -eq 0 ]; then
#	echo "svc_stor_load.sh: Command svcconfig.pl ends with return code $?" 2>>$ERRLOG_SVC
#	exit 1
#fi

PROC=`ps -ef | egrep 'ds5perf.pl *'$STORAGE_NAME' *$' | grep -v grep | wc -l|sed 's/ //g'`
if [ $PROC -lt 2 ]; then
  $PERL -w $BINDIR/ds5perf.pl $STORAGE_NAME  
else
  date_act=`date "+%Y-%m-%d_%H:%M"`
  echo "$0: $date_act : too many $STORAGE_NAME processes: ds5perf.pl, exiting"
  echo "$0: $date_act : too many $STORAGE_NAME processes: ds5perf.pl, exiting" >> $ERRLOG_SVC
  #exit 1
fi

$PERL -w $BINDIR/data_load.pl $STORAGE_NAME  >/dev/null # stdout to null on purpose here to do not fill up logs
if [ ! $? -eq 0 ]; then
  date_act=`date "+%Y-%m-%d_%H:%M"`
  echo "$0: $date_act : Command data_load.pl ends with return code $?" 2>>$ERRLOG
  exit 1
fi

