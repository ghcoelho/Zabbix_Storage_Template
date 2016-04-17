#!/bin/ksh
#
# Script for off site copy of storage data
# data is saved and presented offsite
#
# Usage: 
#   cd /home/stor2rrd/stor2rrd; ./bin/offsite.sh <remote server> <remote port> <remote user> <remote STOR2RRD working dir> <storage>
#
# Place in crontab something like that:
# 0,10,20,30,40,50 * * * * cd /home/stor2rrd/stor2rrd; ./bin/offsite.sh <remote host> <remote port> <remote user> <remote path> 1>/home/stor2rrd/stor2rrd/logs/offsite.log  2>/home/stor2rrd/stor2rrd/logs/offsite-error.log
# 0,10,20,30,40,50 * * * * cd /home/stor2rrd/stor2rrd; ./bin/offsite.sh stor2rrd-host-ext 22 stor2rrd /home/stor2rrd/stor2rrd/ 1>/home/stor2rrd/stor2rrd/logs/offsite.log  2>/home/stor2rrd/stor2rrd/logs/offsite-error.log
#
# 

if [ "$1"x = "x" ]; then
  echo "$0: 1st parametr <remote server> has not been supplied"
  exit 1  
fi
offsite=$1
if [ "$2"x = "x" ]; then
  echo "$0: 2nd parametr <remote port> has not been supplied"
  exit 1  
fi
offsite_port=$2

if [ "$3"x = "x" ]; then
  echo "$0: 3rd parametr <remote user> has not been supplied"
  exit 1  
fi
user=$3
if [ "$4"x = "x" ]; then
  echo "$0: 4th parametr <remote STOR2RRD working dir> has not been supplied"
  exit 1  
fi
offsite_path=$4

test=0
# all storages
if [ ! "$5"x = "x" ]; then
  if [ "$5" = "--test" ]; then
    test=1
  fi
fi

if [ $test -eq 1 ]; then
  # test of communication only
  storage="storage-test"
  offsite_file=/tmp/stor2rrd-test.tar
  offsite_file_base=`basename $offsite_file`
  touch $offsite_file
  echo "Working for: $offsite_file"
  echo "ssh -p $offsite_port $user@$offsite \" if [ ! -d $offsite_path/data/$storage ]; then mkdir $offsite_path/data/$storage; fi\""
  ssh -p $offsite_port $user@$offsite "if [ ! -d $offsite_path/data/$storage ]; then mkdir $offsite_path/data/$storage; if [ ! $? -eq 0 ]; then exit 1; fi; fi"
  if [ ! $? -eq 0 ]; then
    echo "$0: scp problem, skipping"
    exit 1
  fi

  echo "scp  -P $offsite_port $offsite_file $user@$offsite:$offsite_path/data/$storage \""
  scp  -P $offsite_port $offsite_file $user@$offsite:$offsite_path/data/$storage
  if [ ! $? -eq 0 ]; then
    echo "$0: scp problem, skipping"
    exit 1
  fi
 
  echo "ssh -p $offsite_port $user@$offsite \"cd $offsite_path/data/; ls -l $offsite_path/data/$storage/$offsite_file_base; rm -fr $storage\""
  ssh -p $offsite_port $user@$offsite "cd $offsite_path/data/; ls -l $offsite_path/data/$storage/$offsite_file_base; rm -fr $storage; if [ ! $? -eq 0 ]; then exit 1; fi"
  if [ ! $? -eq 0 ]; then
    echo "$0: ssh problem, skipping"
    exit 1
  fi
  rm -r $offsite_file
  echo ""
  echo "Communication looks good!"
  echo ""
  exit 0
fi



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
CFG="$pwd/$path/stor2rrd.cfg"
if [ ! -f $CFG ]; then
  echo "$0: problem with finding etc/lpar2rrd.cfg in: $CFG , exiting"
  exit 1;
fi
. $CFG

cd $pwd/data
if [ ! $? -eq 0 ]; then
  echo "$0: Could not \"cd $pwd/data\", exiting"
  exit 1
fi

for storage in *
do
  if [ ! -d $pwd/data/$storage ]; then
    echo "$0: problem with finding storage data: $pwd/data/$storage , it is a file, skipping"
    continue
  fi

  cd $pwd/data/$storage
  if [ ! $? -eq 0 ]; then
    echo "$0: Could not \"cd $pwd/data/$storage\", skipping"
    continue
  fi

  if [ ! -d offsite ]; then
    mkdir offsite
    if [ ! $? -eq 0 ]; then
      echo "$0: directory for offsite export could not be created: $pwd/data/$storage/offsite , user rights?? skipping"
      continue
    fi
  fi
  echo ""
  echo "Working for storage: $storage"
  echo ""
  
  mv *_svcperf_* offsite 2>/dev/null
  mv *_svcconf_*out offsite  2>/dev/null
  mv *.svcperf.* offsite 2>/dev/null
  mv *.svcconf.*out offsite  2>/dev/null
  cp -f *xml offsite
  DATE=`date "+%Y%m%d-%H%M"`
  tar cvf offsite_$DATE.tar offsite
  if [ ! $? -eq 0 -o ! -f offsite_$DATE.tar ]; then
    echo "$0: problem when creating tar, skipping"
    continue
  fi
  
  # clean out offsite dir
  rm -f offsite/*  
  
  gzip -f -9 offsite_$DATE.tar
  echo "Output file is ready for sending out: offsite_$DATE.tar.gz"
  LS=`ls -l offsite_$DATE.tar.gz`
  echo "  $LS"
  echo ""
  
  echo "ssh -p $offsite_port $user@$offsite \" if [ ! -d $offsite_path/data/$storage ]; then mkdir $offsite_path/data/$storage; fi\""
  ssh -p $offsite_port $user@$offsite "if [ ! -d $offsite_path/data/$storage ]; then mkdir $offsite_path/data/$storage; if [ ! $? -eq 0 ]; then exit 1; fi; fi"
  if [ ! $? -eq 0 ]; then
    echo "$0: ssh problem, skipping"
    continue
  fi

  # there can be more offsite data file in case of any LAN/WAN issue
  for offsite_file in `ls offsite_*`
  do
    echo ""
    echo "Working for: $offsite_file"
    echo "scp  -P $offsite_port $offsite_file $user@$offsite:$offsite_path/data/$storage"
    scp  -P $offsite_port $offsite_file $user@$offsite:$offsite_path/data/$storage
    if [ ! $? -eq 0 ]; then
      echo "$0: scp problem, skipping"
      continue
    fi
  
    echo "ssh -p $offsite_port $user@$offsite \"cd $offsite_path/data/$storage; tar xf $offsite_file\""
    ssh -p $offsite_port $user@$offsite "cd $offsite_path/data/$storage; tar xf $offsite_file; if [ ! $? -eq 0 ]; then exit 1; fi; mv offsite/* .; if [ ! $? -eq 0 ]; then exit 1; fi; rm -f $offsite_file "
    if [ ! $? -eq 0 ]; then
      echo "$0: ssh problem, skipping"
      continue
    fi
  
    # clean out data file
    #echo "Removing $offsite_file"
    #rm -f $offsite_file
    echo "$storage files has been transfered succesfully"
  done
done # storage
      
