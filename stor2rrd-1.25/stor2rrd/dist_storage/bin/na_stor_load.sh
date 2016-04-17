#!/bin/ksh
# stderr and stdour redirection is done already when this script is called

PROC=`ps -ef | egrep 'naperf.pl *'$STORAGE_NAME' *$' | grep -v grep | wc -l| sed 's/ //g'`
if [ $PROC -lt 3 ]; then
	$PERL $BINDIR/naperf.pl $STORAGE_NAME
fi

$PERL -w $BINDIR/data_load.pl $STORAGE_NAME
if [ ! $? -eq 0 ]; then
	echo "naperf_ssh.sh: Command data_load.pl ends with return code $?" 2>>$ERRLOG
	exit 1
fi

