#!/bin/ksh
# usage:
# cd /home/stor2rrd/stor2rrd
# ksh ./check_rrdtool_stor2rrd.sh
#  --> then it prints wrong source files on the stderr (screen) ...
#  --> printed files are corrupted, remove them manually
#
# ERROR: fetching cdp from rra at /stor2rrd/bin/stor2rrd.pl line 2329
# ERROR: reading the cookie off /opt/stor2rrd/data/Carolina-9117-MMD-XXXX/hmc/lane_new_test.rrm faild at
# ERROR: short read while reading header rrd->stat_head
#
# You can schedulle it regulary once a day from crontab, it will send an email to $EMAIL addr
# 0 0 * * * cd /home/stor2rrd/stor2rrd; ./bin/check_rrdtool_stor2rrd.sh > /var/tmp/check_rrdtool.out 2>&1


if [ -f etc/.magic ]; then 
  . etc/.magic
  # set that in etc/.magic to avoid overwriting after the upgrade
  #EMAIL="me@me.com"
  #EMAIL_ON=1
  # export 
else
  EMAIL_ON=0
fi

SILENT=0
if [ ! "$1"x = "x" ]; then
  if [ "$1" = "silent" ]; then
    SILENT=1
  fi
fi

#Run that from /home/stor2rrd/stor2rrd

addr=data
error=0
tmp="/tmp/check_rrdtool.sh-$$"
count=0

os_aix=` uname -a|grep AIX|wc -l|sed 's/ //g'`
if [ $os_aix -eq 0 ]; then
  ECHO_OPT="-e"
else
  ECHO_OPT=""
fi
if [ -f /usr/bin/echo ]; then
  ECHO="/usr/bin/echo $ECHO_OPT"
else
  ECHO="echo $ECHO_OPT"
fi

thousand=0
for RRDFILE_space in `find $addr -name "*.rr[a-z]" |sed 's/ /===space===/g'`
do
  RRDFILE=`echo "$RRDFILE_space"|sed 's/===space===/ /g'`
  (( count = count + 1 ))
  (( thousand = thousand + 1 ))
  if [ $thousand -eq 100 ]; then
    $ECHO  ".\c"
    thousand=0
  fi
  #echo "$RRDFILE"
  last=`rrdtool last "$RRDFILE" 2>>$tmp-error`
  if [ $? -gt 0 ]; then
    (( error = error + 1 ))
    if [ $SILENT -eq 0 ]; then
      echo "  rm $RRDFILE"| tee -a $tmp
      #ls -l $RRDFILE| tee -a $tmp
    else
      echo "rm  $RRDFILE" >> $tmp
    fi
    continue
  fi
  rrdtool fetch "$RRDFILE" AVERAGE -s $last-60 -e $last-60 >/dev/null 2>>$tmp-error
  if [ $? -gt 0 ]; then
    (( error = error + 1 ))
    if [ $SILENT -eq 0 ]; then
      echo "  rm $RRDFILE"| tee -a $tmp
      #ls -l $RRDFILE| tee -a $tmp
    else
      echo "rm  $RRDFILE" >> $tmp
    fi
  fi
  # RRDTool error: ERROR: fetching cdp from rra (sometime can be corrupted only old records when "fetch" and "last" are ok
  rr_1st_var=`rrdtool info "$RRDFILE"  |egrep "^ds"|head -1|sed -e 's/ds\[//' -e 's/\].*//'`
  rrdtool graph mygraph.png -a PNG --start 900000000  --end=now  DEF:x="$RRDFILE":$rr_1st_var:AVERAGE PRINT:x:AVERAGE:%2.1lf >/dev/null 2>>$tmp-error
  if [ $? -gt 0 ]; then
    (( error = error + 1 ))
    if [ $SILENT -eq 0 ]; then
      echo "  rm $RRDFILE"| tee -a $tmp
      #ls -l "$RRDFILE"| tee -a $tmp
    else
      echo "rm  $RRDFILE" >> $tmp
    fi
    continue
  fi
done

if [ $SILENT -eq 0 ]; then
  echo "Checked files: $count"| tee -a $tmp
else 
  echo ""
fi


if [ $error -eq 0 ]; then
  if [ $error -eq 0 ]; then
    echo ""
    echo "No corrupted files have been found"
    echo ""
  else
    echo ""
    echo "Printed files are corrupted, remove them manually"
    echo ""
    if [ $EMAIL_ON -eq 1 ]; then
      cat $tmp| mailx -s "LPAR2RRD corrupted files" $EMAIL
    fi
  fi
  rm -f $tmp
  rm -f $tmp-error
else
  if [ $error -eq 0 ]; then
    echo "No corrupted files have been found"
  else
    echo "*********************************************************************************"
    echo "There are $error corrupted RRDTool database files, delete them to avoid problems!"
    echo "Get the list of files: cat $tmp"
    echo "Get the list errors: cat $tmp-error"
    echo "*********************************************************************************"
  fi
fi


