#!/bin/sh

# Parameters:
# Param1 - Storage name

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
export UPGRADE

if [ "$INPUTDIR" = "." ]; then
   INPUTDIR=`pwd`
   export INPUTDIR
fi
if [ x"$STORAGE_CFG" = "x" ]; then
  echo "STORAGE_CFG does not seem to be set up, correct it in stor2rrd.cfg"
  exit 0
fi
if [ x"$STORAGE_USER" = "x" ]; then
  echo "STORAGE_USER does not seem to be set up, correct it in stor2rrd.cfg"
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


for line in `cat $STORAGE_CFG|sed 's/#.*$//'|egrep ":3PAR:"|egrep -v "^#"`
do
	# Name:SWIZ:DEVID:HMC1:HMC2:
	STORAGE_NAME=`echo $line | awk 'BEGIN{FS=":"}{print $1}'`
	STORAGE_TYPE=`echo $line | awk 'BEGIN{FS=":"}{print $2}'`
	
	export STORAGE_NAME STORAGE_TYPE

	# SVC/Storwize Storage Family
	HP3PAR_IP=`echo $line | awk 'BEGIN{FS=":"}{print $3}'`
	HP3PAR_USER=$STORAGE_USER
        if [ ! x"$STORAGE_USER_3PAR" = "x" ]; then
	  HP3PAR_USER=$STORAGE_USER_3PAR
        fi
	HP3PAR_KEY=`echo $line | awk 'BEGIN{FS=":"}{print $4}'`
	HP3PAR_DIR="$INPUTDIR/data/$STORAGE_NAME"
	HP3PAR_INTERVAL=`expr $SAMPLE_RATE / 60`
	export HP3PAR_IP HP3PAR_USER HP3PAR_KEY HP3PAR_DIR HP3PAR_INTERVAL

	if [ "$HP3PAR_IP"x = "x" ]; then
    		echo "Some problem with storage cfg. Storage IP must be set. Check $STORAGE_CFG line: $line"
    		continue
	fi

	if [ ! -d "$HP3PAR_DIR" ]; then
		mkdir "$HP3PAR_DIR"
	fi
	if [ ! -d "$HP3PAR_DIR/tmp" ]; then
		mkdir "$HP3PAR_DIR/tmp"
	fi
	if [ ! -d "$HP3PAR_DIR/iostats" ]; then
		mkdir "$HP3PAR_DIR/iostats"
	fi
	ERRLOG_SVC="$ERRLOG-${STORAGE_NAME}"
	OUTLOG_SVC="$INPUTDIR/logs/output.log-${STORAGE_NAME}"
        export ERRLOG_SVC OUTLOG_SVC
		
	$BINDIR/3par_stor_load.sh 1>>$OUTLOG_SVC 2>>$ERRLOG_SVC &
	if [ ! $? -eq 0 ]; then
		echo "`date` : An error occured in 3par_stor_load.sh, check $ERRLOG_SVC and output of $0" >> $ERRLOG_SVC
		echo "`date` : An error occured in 3par_stor_load.sh, check $ERRLOG_SVC and output of $0" 
	fi
        # Remove old files
        find $HP3PAR_DIR -name '*_hp3parstate*out' -amin +60 -exec rm -f {} \;
        find $HP3PAR_DIR -name '*_hp3par*out' -atime +7 -exec rm -f {} \;
done

# wait for all jobs to let see the ouput
for job in `jobs -p`
do
    echo "Waiting for $job"
    wait $job
done

