#!/bin/ksh
#
# Script for lock & unlock GUI configuration files
# When it is locked then no one is allowed to modify configuration from the GUI (Custom Groups, Alerting, VMware configuration, ...)
#
# Usage: 
#  su - lpar2rrd
#  cd /home/lpar2rrd/lpar2rrd
#  ./bin/gui-config-permission.sh [lock|unlock]
#
#

pwd=`pwd`
if [ -d "etc" ]; then
   path="etc"
else
  if [ -d "../etc" ]; then
    path="../etc"
  else
    echo "problem with actual directory, assure you are in LPAR2RRD home"
    exit
  fi
fi
CFG="$pwd/$path/lpar2rrd.cfg"
if [ ! -f $CFG ]; then
  echo "$0: problem with finding etc/lpar2rrd.cfg, exiting"
  exit 1;
fi
. $CFG

FILES="etc/web_config/custom_groups.cfg etc/web_config/vmware.cfg etc/web_config/alerting.cfg .vmware/credstore/vicredentials.xml"
DIRS="etc/web_config .vmware/credstore/"

if [ "$1"x = "x" ]; then
  echo "Usage: $0 [lock|unlock]"
  exit 1
fi

if [ "$1" = "lock" ]; then
  for file in $FILES
  do
    if [ -f "$file" ]; then
      echo "Locking $file"
      chmod 444 $file 2>/dev/null
      if [ ! $? -eq 0 ]; then
        rm -f $file-lock
        mv $file $file-lock
        cp $file-lock $file
        chmod -f 444 $file
      fi
    fi
  done
  for dir in $DIRS  
  do
    if [ -d "$dir"  ]; then
      echo "Locking $dir"
      chmod -f 555 $dir
    fi
  done
  exit 0
fi

if [ "$1" = "unlock" ]; then
  for dir in $DIRS  
  do
    if [ -d "$dir"  ]; then
      echo "Unlocking $dir"
      chmod -f 777 $dir
    fi
  done
  for file in $FILES
  do
    if [ -f "$file" ]; then
      echo "Unlocking $file"
      if [ -f $file-lock -a `diff $file $file-lock 2>/dev/null | wc -l|sed 's/ //g'` -eq 0 ]; then
        rm -f $file
        mv -f $file-lock $file
      fi
      chmod -f 666 $file 2>/dev/null
    fi
  done
  exit 0
fi

echo "Usage: $0 [lock|unlock]"
exit 1

