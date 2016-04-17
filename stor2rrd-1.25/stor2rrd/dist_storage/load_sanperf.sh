#!/bin/sh
# version 0.13

# Parameters:
# Param1 - SAN name

#set -x 

PATH=$PATH:/usr/bin:/bin:/usr/local/bin:/opt/freeware/bin
export PATH

# it is necessary as files need to be readable also for WEB server user
umask 022

# Load STORAGE2RRD configuration
dir=`dirname $0`
CFG="$dir/etc/stor2rrd.cfg"
. $CFG
DEBUG=0

PERL5LIB=$BINDIR:$PERL5LIB
export PERL5LIB

# Load "magic" setup
if [ -f "$dir/etc/.magic" ]; then
  . $dir/etc/.magic
fi

UPGRADE=0
if [ ! -f $dir/tmp/$version ]; then
  UPGRADE=1
fi

if [ "$INPUTDIR" = "." ]; then
   INPUTDIR=`pwd`
   export INPUTDIR
fi
if [ x"$STORAGE_USER" = "x" ]; then
  echo "STORAGE_USER does not seem to be set up, correct it in stor2rrd.cfg"
  exit 0
fi
if [ x"$SAN_CFG" = "x" ]; then
  echo "SAN_CFG does not seem to be set up, correct it in stor2rrd.cfg"
  exit 0
fi
if [ x"$PERL" = "x" ]; then
  echo "PERL does not seem to be set up, correct it in stor2rrd.cfg"
  exit 0
fi
if [ x"$SAMPLE_RATE" = "x" ]; then
  echo "SAMPLE_RATE does not seem to be set up, correct it in stor2rrd.cfg"
  exit 0
fi

cd $INPUTDIR

# Check if it runs under the right user
install_user=`ls -lX etc/stor2rrd.cfg|awk '{print $3}'`  # must be X to do not cut user name to 8 chars
running_user=`id |awk -F\( '{print $2}'|awk -F\) '{print $1}'`
if [ ! "$install_user" = "$running_user" ]; then
  echo "You probably trying to run it under wrong user"
  echo "STOR2RRD files are owned by : $install_user"
  echo "You are : $running_user"
  echo "STOR2RRD should run only under user which owns installed package"
  echo "Do you want to really continue? [n]:"
  read answer
  if [ "$answer"x = "x" -o "$answer" = "n" -o "$anwer" = "N" ]; then
    exit
  fi
fi

#SNMP version in etc/san-list.cfg
SNMP_VERSION=`cat $SAN_CFG|sed 's/#.*$//'|egrep "^SNMP_VERSION"|egrep -v "^#"|sed -e 's/^SNMP_VERSION=//'`
export SNMP_VERSION

#SNMP port in etc/san-list.cfg
SNMP_PORT=`cat $SAN_CFG|sed 's/#.*$//'|egrep "^SNMP_PORT"|egrep -v "^#"|sed -e 's/^SNMP_PORT=//'`
export SNMP_PORT

date=`date`
SAMPLE_RATE_DEF=$SAMPLE_RATE
for line in `cat $SAN_CFG|sed 's/#.*$//'|egrep ".*:.*:.*:"|egrep -v "^#"`
do
  # Only SAN load ....
  # IP:SAN::
  SAN_IP=`echo $line | awk 'BEGIN{FS=":"}{print $1}'`
  export SAN_IP

  SAN_TYPE=`echo $line | awk 'BEGIN{FS=":"}{print $3}'`
  export SAN_TYPE

  SAMPLE_RATE=$SAMPLE_RATE_DEF
  echo "$SAN_IP: $date : starting"

  if [ ! "$SAMPLE_RATE_min"x = "x" -a -f "$INPUTDIR/tmp/$SAN_IP-run" ]; then
    #(( SAMPLE_RATE = SAMPLE_RATE_min * 60 ))
    SAMPLE_RATE=`echo "$SAMPLE_RATE_min*60"|bc`
    # check how offten it should run as per timestamp and skip it if it too early
    time_last_tmp=`$PERL -e '$inp=shift;$st_name=shift;$v = (stat("$inp/tmp/$st_name-run"))[9]; print "$v\n";' $INPUTDIR $SAN_IP`
    time_act=`date "+%s"`
    d=`date`
    #(( time_last = SAMPLE_RATE + time_last - 50 )) # put 50 sec to make sure
    grace_time=50
    time_last=`expr $SAMPLE_RATE + $time_last_tmp - $grace_time`
    echo "$SAN_IP: $d : $time_last -gt $time_act  -- $SAMPLE_RATE -- $INPUTDIR/tmp/$SAN_IP-run"
    if [ $time_last -gt $time_act ]; then
      echo "Skipping now   : $SAN_IP: not process this time due to sample_rate : $SAMPLE_RATE"
      continue
    else
      # go further for the data load
      touch "$INPUTDIR/tmp/$SAN_IP-run"
    fi
  else 
    touch "$INPUTDIR/tmp/$SAN_IP-run"
  fi
  echo "Continue now   : $SAN_IP: sample_rate : $SAMPLE_RATE"
  export SAMPLE_RATE

  DATEEXT=`date "+%Y%m%d"`
  DATETIMEEXT=`date "+%Y%m%d-%H%M"`
  ERRLOG_SAN="$ERRLOG-${SAN_IP}"
  OUTLOG="$INPUTDIR/logs/output.log-${SAN_IP}"
  export ERRLOG_SAN OUTLOG

  $BINDIR/san_stor_load.sh $SAN_IP 2>>$ERRLOG_SAN 1>>$OUTLOG &
  if [ ! $? -eq 0 ]; then
    echo "`date` : An error occured in sanperf.pl, check $ERRLOG and output of $0" >> $ERRLOG 
    echo "`date` : An error occured in sanperf.pl, check $ERRLOG and output of $0" 
  fi

  # check VSAN IDs
  if [ "$SAN_TYPE" = "BRCD" ] && [ "$SNMP_VERSION" == 3 ]; then
    SNMP3_USER=`echo $line | awk 'BEGIN{FS=":"}{print $2}'`
    export SNMP3_USER

    check_vsan_id=0
    vsan_tmp="$INPUTDIR/tmp/$SAN_IP-check-vsan"
    if [ ! -f $vsan_tmp ]; then
      check_vsan_id=1
    fi
    if [ -f $vsan_tmp ]; then
      last_mod_time=`$PERL -e '$vsan_tmp=shift;$v = (stat("$vsan_tmp"))[9]; print "$v\n";' $vsan_tmp`
      act_time=`date +%s`
      time_diff=`expr $act_time - $last_mod_time`
      if [ $time_diff -gt 3600 ]; then
        check_vsan_id=1
      fi
    fi

    if [ "$check_vsan_id" == 1 ]; then
      $BINDIR/check_vsan.sh 2>>$ERRLOG_SAN 1>$vsan_tmp
    fi
  fi

done

# wait for all jobs to let see the ouput
for job in `jobs -p`
do
    echo "Waiting for $job"
    wait $job
done

# update output files to rrd
$PERL -w $BINDIR/san_rrdupdate.pl 2>>$ERRLOG
