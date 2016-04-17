#!/bin/ksh

PATH=$PATH:/usr/bin:/bin:/usr/local/bin:/opt/freeware/bin
export PATH

LANG=C
export LANG

# it is necessary as files need to be readable also for WEB server user
umask 022

# Load LPAR2RRD configuration
. `dirname $0`/etc/stor2rrd.cfg

# Load "magic" setup
if [ -f `dirname $0`/etc/.magic ]; then
  . `dirname $0`/etc/.magic
fi


if [ "$INPUTDIR" = "." ]; then
   INPUTDIR=`pwd`
   export INPUTDIR
fi
TMPDIR=$INPUTDIR/tmp

prg_name=`basename $0`
if [ -f "$TMPDIR/$prg_name.pid" ]; then
  PID=`cat "$TMPDIR/$prg_name.pid"`
  if [ ! "$PID"x = "x" ]; then
    ps -ef|grep "$prg_name"|grep "$PID" >/dev/null
    if [ $? -eq 0 ]; then
      echo "There is already running another copy of $prg_name, exiting ..."
      d=`date`
      echo "$d: There is already running another copy of $prg_name, exiting ..." >> $ERRLOG-alrt
      exit 1
    fi
  fi
fi
# ok, there is no other copy of $0
echo "$$" > "$TMPDIR/$prg_name.pid"

PERL5LIB=$BINDIR:$PERL5LIB
export PERL5LIB



cd $INPUTDIR

ALERCFG="etc/alert.cfg"
export ALERCFG

if [ ! -f $ALERCFG ]; then
    if [ $DEBUG -eq 1 ]; then echo "There is no $ALERCFG cfg file"; fi
    exit 0
fi


# Check if it runs under the right user
install_user=`ls -lX $BINDIR/storage.pl|awk '{print $3}'`  # must be X to do not cut user name to 8 chars
running_user=`id |awk -F\( '{print $2}'|awk -F\) '{print $1}'`
if [ ! "$install_user" = "$running_user" ]; then
  echo "You probably trying to run it under wrong user" 
  echo "LPAR2RRD files are owned by : $install_user"
  echo "You are : $running_user"
  echo "LPAR2RRD should run only under user which owns installed package"
  echo "Do you want to really continue? [n]:"
  read answer
  if [ "$answer"x = "x" -o "$answer" = "n" -o "$answer" = "N" ]; then
    exit
  fi
fi

ERRLOG=$ERRLOG-alrt
if [ -f $ERRLOG ]; then
  ERR_START=`wc -l $ERRLOG |awk '{print $1}'`
else
  ERR_START=0
fi 

# Checks
if [ ! -f "$RRDTOOL" ]; then
  echo "Set correct path to RRDTOOL binary in stor2rrd.cfg, it does not exist here: $RRDTOOL"
  exit 0
fi 
ok=0
for i in `echo "$PERL5LIB"|sed 's/:/ /g'` 
do
  if [ -f "$i/RRDp.pm" ]; then
    ok=1
  fi
done
if [ $ok -eq 0 ]; then
  echo "Set correct path to RRDp.pm Perl module in stor2rrd.cfg, it does not exist here : $PERL5LIB"
  exit 0
fi
if [ ! -f "$PERL" ]; then
  echo "Set correct path to Perl binary in stor2rrd.cfg, it does not exist here: $PERL"
  exit 0
fi 

#
# Run alerting for all attached storage manually (usually it runs automatically after each data load
#

STOR2RRD_TIME_ACT=`date +"%Y-%m-%d %H:%M"`
export STOR2RRD_TIME_ACT

for line in `cat $STORAGE_CFG|sed 's/#.*$//'|egrep ":DS5K:|:DS8K:|:XIV:|:SWIZ:"|egrep -v "^#"`
do
  # Only DS5K load ....
  # Name:DS8K:DEVID:HMC1:HMC2:
  STORAGE_NAME=`echo $line | awk 'BEGIN{FS=":"}{print $1}'`
  STORAGE_TYPE=`echo $line | awk 'BEGIN{FS=":"}{print $2}'`
  export STORAGE_NAME STORAGE_TYPE


  $PERL -w $BINDIR/alrt_ext.pl 2>>$ERRLOG 
done

#
# Error handling
# 

if [ -f $ERRLOG ]; then
  ERR_END=`wc -l $ERRLOG |awk '{print $1}'`
else
  ERR_END=0
fi
ERR_TOT=`expr $ERR_END - $ERR_START`
if [ $ERR_TOT -gt 0 ]; then
  echo "An error occured in stor2rrd, check $ERRLOG and output of load.sh"
  echo ""
  echo "$ tail -$ERR_TOT $ERRLOG"
  echo ""
  tail -$ERR_TOT $ERRLOG
  date >> $ERRLOG
fi

exit 0
