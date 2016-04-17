#!/bin/sh

# Load STOR2RRD environment
CGID=`dirname $0`
if [ "$CGID" = "." ]; then
  CGID=`pwd`
fi
INPUTDIR_NEW=`dirname $CGID`
. $INPUTDIR_NEW/etc/stor2rrd.cfg
INPUTDIR=$INPUTDIR_NEW
export INPUTDIR 

BINDIR="$INPUTDIR/bin"
export BINDIR

TMPDIR_STOR="$INPUTDIR/tmp"
export TMPDIR_STOR

umask 000
ERRLOG="/var/tmp/stor2rrd-realt-error.log"
export ERRLOG

# Load "magic" setup
if [ -f $INPUTDIR/etc/.magic ]; then
  . $INPUTDIR/etc/.magic
fi

exec $PERL $BINDIR/alert-save.pl 2>>$ERRLOG
