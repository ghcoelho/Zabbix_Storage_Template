#!/bin/ksh
# stderr and stdour redirection is done already when this script is called

PROC=`ps -ef | egrep 'sanperf.pl *'$SAN_IP' *$' | grep -v grep | wc -l|sed 's/ //g'`
if [ $PROC -lt 3 ]; then
  # use 3 here! Sometimes snmpwalk takes more time than usualy and more processes can exist 
  $PERL $BINDIR/sanperf.pl $SAN_IP
else 
  date_act=`date "+%Y-%m-%d_%H:%M"`
  echo "$0: $date_act : too many $SAN_IP processes: sanperf.pl, exiting" 
  echo "$0: $date_act : too many $SAN_IP processes: sanperf.pl, exiting" >> $ERRLOG_SAN
fi

