#!/bin/sh
# version 0.15
# vim: set filetype=sh :

# Parameters:
# Param1 - Storage name

#set -x 

PATH=$PATH:/usr/bin:/bin:/usr/local/bin:/opt/freeware/bin
export PATH

# if [ `uname -a|grep AIX|wc -l` -eq 1 ]; then
#	export LIBPATH=/opt/freeware/lib:$LIBPATH
# fi


# it is necessary as files need to be readable also for WEB server user
umask 022

# Load STORAGE2RRD configuration
dir=`dirname $0`
CFG="$dir/etc/stor2rrd.cfg"
. $CFG
DEBUG=1

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

SAMPLE_RATE_ORG=$SAMPLE_RATE
for line in `cat $STORAGE_CFG|sed 's/#.*$//'|egrep ":NETAPP:"|egrep -v "^#"`
do
	SAMPLE_RATE=$SAMPLE_RATE_ORG
	# Storage name alias:NETAPP:_netapp_IP_:_password_:
	#`echo $line | awk 'BEGIN{FS=":"}{print $1, $2, $3, $4, $5, $6, $7, $8}' | read STORAGE_NAME STORAGE_TYPE STORAGE_MODE NA_IP NA_PORT_SSH NA_PORT_API NA_USER NA_PASSWD`
	#echo "STORAGE: $STORAGE_NAME $STORAGE_TYPE $STORAGE_MODE $NA_IP $NA_PORT_SSH $NA_PORT_API $NA_USER $NA_PASSWD"

	STORAGE_NAME=`echo $line | awk 'BEGIN{FS=":"}{print $1}'`
	STORAGE_TYPE=`echo $line | awk 'BEGIN{FS=":"}{print $2}'`
	STORAGE_MODE=`echo $line | awk 'BEGIN{FS=":"}{print $3}'`

	# NetApp Storage Family
	NA_IP=`echo $line | awk 'BEGIN{FS=":"}{print $4}'`
	NA_PORT_SSH=`echo $line | awk 'BEGIN{FS=":"}{print $5}'`
	NA_PORT_API=`echo $line | awk 'BEGIN{FS=":"}{print $6}'`
	NA_PROTO_API=`echo $line | awk 'BEGIN{FS=":"}{print $7}'`
	NA_USER=`echo $line | awk 'BEGIN{FS=":"}{print $8}'`
	NA_PASSWD=`echo $line | awk 'BEGIN{FS=":"}{print $9}'`

	export STORAGE_NAME STORAGE_TYPE STORAGE_MODE NA_IP NA_PORT_SSH NA_PORT_API NA_PROTO_API NA_USER NA_PASSWD

	NA_DIR="$INPUTDIR/data/$STORAGE_NAME"
	#SAMPLE_RATE=`echo $line | awk 'BEGIN{FS=":"}{print $12}'`
    #if [ "$SAMPLE_RATE"x = "x" ]; then
	  #SAMPLE_RATE=$SAMPLE_RATE_ORG
    #fi

	export NA_IP NA_USER NA_PASSWD NA_DIR NA_INTERVAL SAMPLE_RATE

	if [ "$NA_IP"x = "x" ]; then
		echo "Some problem with storage cfg. Storage IP must be set. Check $STORAGE_CFG line: $line"
		continue
	fi

	if [ ! -d "$NA_DIR" ]; then
		mkdir "$NA_DIR"
	fi
	if [ ! -d "$NA_DIR/tmp" ]; then
		mkdir "$NA_DIR/tmp"
	fi
	ERRLOG_NA="$ERRLOG-${STORAGE_NAME}"
	OUTLOG_NA="$INPUTDIR/logs/output.log-${STORAGE_NAME}"
	export ERRLOG_NA OUTLOG_NA
	
	$BINDIR/na_stor_load.sh 1>>$OUTLOG_NA 2>>$ERRLOG_NA &
		
	if [ ! $? -eq 0 ]; then
		echo "`date` : An error occured in na_stor_load.sh, check $ERRLOG_NA and output of $0" >> $ERRLOG_NA
		echo "`date` : An error occured in na_stor_load.sh, check $ERRLOG_NA and output of $0" 
	fi
done

# wait for all jobs to let see the ouput
for job in `jobs -p`
do
	echo "Waiting for $job"
	wait $job
done

