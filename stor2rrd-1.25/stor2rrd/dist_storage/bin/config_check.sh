#!/bin/ksh
# version 0.13

# Parameters:
# Param1 - Storage name

#set -x

PATH=$PATH:/usr/bin:/bin:/usr/local/bin:/opt/freeware/bin
export PATH

# it is necessary as files need to be readable also for WEB server user
umask 022

if [ ! -d "etc" ]; then
  if [ -d "../etc" ]; then
    cd ..
  else
    echo "Problem with actual directory, assure you are in LPAR2RRD home"
    echo "Then run : sh ./bin/config_check.sh"
    exit
  fi
fi

LHOME=`pwd|sed -e 's/bin//' -e 's/\/\//\//' -e 's/\/$//'` # it must be here
pwd=`pwd`


# Load STOR2RRD configuration
CFG="$pwd/etc/stor2rrd.cfg"
. $CFG
DEBUG=0

# Load "magic" setup
if [ -f "$pwd/etc/.magic" ]; then
  . $pwd/etc/.magic
fi

# correct BINDIR, it contains: ./bin/bin when it runs as ./bin/config_check.sh
BINDIR=`echo "$BINDIR"|sed 's/\/bin\/bin/\/bin/'`
INPUTDIR=`echo "$INPUTDIR"|sed 's/\/bin$//'`

PERL5LIB=$PERL5LIB:$BINDIR
export PERL5LIB


if [ "$INPUTDIR" = "." ]; then
   INPUTDIR=`pwd`
   export INPUTDIR
fi
if [ x"$STORAGE_USER" = "x" ]; then
  echo "STORAGE_USER does not seem to be set up, correct it in stor2rrd.cfg"
  exit 0
fi
if [ x"$DS8_CLIDIR" = "x" ]; then
  echo "DS8_CLIDIR does not seem to be set up, correct it in stor2rrd.cfg"
fi
if [ x"$STORAGE_CFG" = "x" ]; then
  echo "STORAGE_CFG does not seem to be set up, correct it in stor2rrd.cfg"
fi
if [ x"$PERL" = "x" ]; then
  echo "PERL does not seem to be set up, correct it in stor2rrd.cfg"
  exit 0
fi
if [ x"$SAMPLE_RATE" = "x" ]; then
  echo "SAMPLE_RATE does not seem to be set up, correct it in stor2rrd.cfg"
fi
if [ x"$SAN_CFG" = "x" ]; then
  echo "SAN_CFG does not seem to be set up, correct it in stor2rrd.cfg"
  exit 0
fi
if [ x"$DS5_CLIDIR" = "x" ]; then
  echo "DS5_CLIDIR does not seem to be set up, correct it in stor2rrd.cfg"
fi


count=0
date=`date`
SAMPLE_RATE_DEF=$SAMPLE_RATE
for line in `cat $STORAGE_CFG|sed 's/#.*$//'|egrep ":DS8K:"|egrep -v "^#"`
do
  # Only DS8K load ....
  # Name:DS8K:DEVID:HMC1:HMC2:
  STORAGE_NAME=`echo $line | awk 'BEGIN{FS=":"}{print $1}'`
  STORAGE_TYPE=`echo $line | awk 'BEGIN{FS=":"}{print $2}'`
  DS8_DEVID=`echo $line | awk 'BEGIN{FS=":"}{print $3}'`
  DS8_HMC1=`echo $line | awk 'BEGIN{FS=":"}{print $4}'`
  DS8_HMC2=`echo $line | awk 'BEGIN{FS=":"}{print $5}'`
  SAMPLE_RATE_min=`echo $line | awk 'BEGIN{FS=":"}{print $8}'`

  SAMPLE_RATE=$SAMPLE_RATE_DEF

  if [ "$DS8_HMC2"x = "x" ]; then
    echo "$STORAGE_NAME: Some problem with storage cfg, check $STORAGE_CFG line: $line"
    continue
  fi

  echo "========================="
  echo "STORAGE: $STORAGE_NAME: $STORAGE_TYPE "
  echo "========================="

  if [ ! -f "$DS8_CLIDIR/dscli" ]; then
    echo "DSCLI binnary does not exist here : $DS8_CLIDIR/dscli"
    echo "If it is installed then configure proper path in etc/stor2rrd.cfg, param DS8_CLIDIR"
    continue
  fi
  if [ "$DS8_HMC2"x = "x" ]; then
    echo "  $DS8_CLIDIR/dscli -hmc1 $DS8_HMC1 -user $STORAGE_USER whoami"
    $DS8_CLIDIR/dscli -hmc1 $DS8_HMC1 -user $STORAGE_USER whoami
    echo "  $DS8_CLIDIR/dscli -hmc1 $DS8_HMC1 -user $STORAGE_USER ver -l"
    $DS8_CLIDIR/dscli -hmc1 $DS8_HMC1 -user $STORAGE_USER ver -l
  else
    echo "  $DS8_CLIDIR/dscli -hmc1 $DS8_HMC1 -hmc2 $DS8_HMC2 -user $STORAGE_USER whoami"
    $DS8_CLIDIR/dscli -hmc1 $DS8_HMC1 -hmc2 $DS8_HMC2 -user $STORAGE_USER whoami
    echo "  $DS8_CLIDIR/dscli -hmc1 $DS8_HMC1 -hmc2 $DS8_HMC2 -user $STORAGE_USER ver -l"
    $DS8_CLIDIR/dscli -hmc1 $DS8_HMC1 -hmc2 $DS8_HMC2 -user $STORAGE_USER ver -l
  fi
  echo ""
  (( count = count + 1 ))
done
if [ $count -gt 0 ]; then
  echo ""
  echo "$STORAGE_USER user on all IBM DS8K must belong to \"monitor\" role at least"
  echo ""
fi

count=0
for line in `cat $STORAGE_CFG|sed 's/#.*$//'|egrep ":SWIZ:"|egrep -v "^#"`
do
        # Name:SWIZ:DEVID:HMC1:HMC2:
        STORAGE_NAME=`echo $line | awk 'BEGIN{FS=":"}{print $1}'`
        STORAGE_TYPE=`echo $line | awk 'BEGIN{FS=":"}{print $2}'`

        # SVC/Storwize Storage Family
        SVC_IP=`echo $line | awk 'BEGIN{FS=":"}{print $3}'`
        #SVC_USER=`echo $line | awk 'BEGIN{FS=":"}{print $4}'`
        SVC_USER=$STORAGE_USER
        if [ ! x"$STORAGE_USER_SWIZ" = "x" ]; then
          SVC_USER=$STORAGE_USER_SWIZ
        fi
        SVC_KEY=`echo $line | awk 'BEGIN{FS=":"}{print $4}'`
        SVC_DIR="$INPUTDIR/data/$STORAGE_NAME"
        SVC_INTERVAL=`expr $SAMPLE_RATE / 60`

        if [ "$SVC_IP"x = "x" ]; then
                echo "$STORAGE_NAME: Some problem with storage cfg. Storage IP must be set. Check $STORAGE_CFG line: $line"
                continue
        fi

        echo "========================="
        echo "STORAGE: $STORAGE_NAME: $STORAGE_TYPE"
        echo "========================="

        if [ "$SVC_KEY"x = "x" ]; then
          echo "  ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=no $STORAGE_USER@$SVC_IP  \"lscurrentuser\""
          ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=no $STORAGE_USER@$SVC_IP  "lscurrentuser" >/dev/null
	  if [ $? -eq 0 ]; then
            ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=no $STORAGE_USER@$SVC_IP  "lscurrentuser"|grep Administrator >/dev/null
	    if [ $? -eq 0 ]; then
              echo "  connection ok"          
            else 
              echo "  current account does not have Administration access!!"          
              echo "$STORAGE_USER user on all IBM SVC/Storwize must belong to \"admin\" or \"Administrator\" UserRole"
              ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=no $STORAGE_USER@$SVC_IP  "lscurrentuser"
            fi
          else 
            echo "  connection failed!!"          
          fi
        else
          echo "  ssh -o ConnectTimeout=15 -i $SVC_KEY  $STORAGE_USER@$SVC_IP  \"lscurrentuser\""
          ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=no -i $SVC_KEY  $STORAGE_USER@$SVC_IP  "lscurrentuser" >/dev/null
	  if [ $? -eq 0 ]; then
            ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=no -i $SVC_KEY  $STORAGE_USER@$SVC_IP  "lscurrentuser"|grep Administrator >/dev/null
	    if [ $? -eq 0 ]; then
              echo "  connection ok"          
            else 
              echo "  current account does not have Administration access!!"          
              echo "$STORAGE_USER user on all IBM SVC/Storwize must belong to \"admin\" or \"Administrator\" UserRole"
              ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=no -i $SVC_KEY  $STORAGE_USER@$SVC_IP  "lscurrentuser"
            fi
          else 
            echo "  connection failed!!"          
          fi
        fi
        echo ""
        (( count = count + 1 ))
done


count=0
for line in `cat $STORAGE_CFG|sed 's/#.*$//'|egrep ":XIV:"|egrep -v "^#"`
do
        # Storage name alias:XIV:_xiv_ip_:_password_:
        STORAGE_NAME=`echo $line | awk 'BEGIN{FS=":"}{print $1}'`
        STORAGE_TYPE=`echo $line | awk 'BEGIN{FS=":"}{print $2}'`

        export STORAGE_NAME STORAGE_TYPE

        # XiV Storage Family
        XIV_IP=`echo $line | awk 'BEGIN{FS=":"}{print $3}'`
        XIV_USER=$STORAGE_USER
        if [ ! x"$STORAGE_USER_XIV" = "x" ]; then
          XIV_USER=$STORAGE_USER_XIV
        fi
        XIV_PASSWD=`echo $line | awk 'BEGIN{FS=":"}{print $4}'`
        XIV_DIR="$INPUTDIR/data/$STORAGE_NAME"
        XIV_INTERVAL=$SAMPLE_RATE
        export XIV_IP XIV_USER XIV_PASSWD XIV_DIR XIV_INTERVAL

        if [ "$XIV_IP"x = "x" ]; then
                echo "Some problem with storage cfg. Storage IP must be set. Check $STORAGE_CFG line: $line"
                continue
        fi

        ERRLOG_XIV="$ERRLOG-${STORAGE_NAME}"
        OUTLOG_XIV="$INPUTDIR/logs/${STORAGE_NAME}.output_xiv.log"
        export ERRLOG_XIV OUTLOG_XIV

        WBEMCLI="/usr/bin/wbemcli"
        if [ ! -f $WBEMCLI ]; then
          WBEMCLI="/opt/freeware/bin/wbemcli"
          if [ ! -f $WBEMCLI ]; then
            WBEMCLI="/usr/local/bin/wbemcli"
            if [ ! -f $WBEMCLI ]; then
              echo "XIV Error: could not found wbemcli binnary, searched /usr/bin/wbemcli, /opt/freeware/bin/wbemcli, /usr/local/bin/wbemcli"
              break
            fi
          fi
        fi
       
        echo "========================="
        echo "STORAGE: $STORAGE_NAME: $STORAGE_TYPE"
        echo "========================="

        echo "  $WBEMCLI -noverify -nl ei https://$XIV_USER:$XIV_PASSWD@$XIV_IP:5989/root/ibm:IBMTSDS_StorageSystem"
	$WBEMCLI -noverify -nl ei https://$XIV_USER:$XIV_PASSWD@$XIV_IP:5989/root/ibm:IBMTSDS_StorageSystem
        echo ""          
        (( count = count + 1 ))
done
if [ $count -gt 0 ]; then
  echo ""
  echo "$STORAGE_USER user on all IBM XIV category \"readonly\""
  echo ""
fi

for line in `cat $STORAGE_CFG|sed 's/#.*$//'|egrep ":DS5K:"|egrep -v "^#"`
do
        # Storage name alias:XIV:_xiv_ip_:_password_:
        STORAGE_NAME=`echo $line | awk 'BEGIN{FS=":"}{print $1}'`
        STORAGE_TYPE=`echo $line | awk 'BEGIN{FS=":"}{print $2}'`
        DS5K_USER=`echo $line | awk 'BEGIN{FS=":"}{print $3}'`
        DS5K_PW=`echo $line | awk 'BEGIN{FS=":"}{print $4}'`

        export STORAGE_NAME STORAGE_TYPE

        DS5_PASSWD=`echo $line | awk 'BEGIN{FS=":"}{print $4}'`
        DS5_DIR="$INPUTDIR/data/$STORAGE_NAME"
        DS5_INTERVAL=$SAMPLE_RATE
        export DS5_IP DS5_USER DS5_PASSWD DS5_DIR DS5_INTERVAL

        ERRLOG_DS5="$ERRLOG-${STORAGE_NAME}"
        OUTLOG_DS5="$INPUTDIR/logs/${STORAGE_NAME}.output_ds5.log"
        export ERRLOG_DS5 OUTLOG_DS5

        if [ ! -f $DS5_CLIDIR/SMcli ]; then
          echo "DS5K Error: could not found SMcli binnary : $DS5_CLIDIR/SMcli, Install SMcli or update DS5_CLIDIR in etc/stor2rrd.cfg"
          break
        fi
       
        echo "========================="
        echo "STORAGE: $STORAGE_NAME: $STORAGE_TYPE"
        echo "========================="

        if [ "$DS5K_PW"x = "x" ]; then
          # no user/pw is set
          echo "  $DS5_CLIDIR/SMcli -n $STORAGE_NAME -e -c \"show storageSubsystem summary;\""
	  if [ `$DS5_CLIDIR/SMcli -n $STORAGE_NAME -e -c "show storageSubsystem summary;"| grep "SMcli completed successfully"|wc -l|sed 's/ //g'` -gt 0 ]; then
            echo "  connection ok"          
          else 
            echo "  connection failed!!"          
          fi
        else
          # no user/pw is set
          echo "  $DS5_CLIDIR/SMcli -n $STORAGE_NAME -R $DS5K_USER -p $DS5K_PW -e -c \"show storageSubsystem summary;\""
	  if [ `$DS5_CLIDIR/SMcli -n $STORAGE_NAME -R $DS5K_USER -p $DS5K_PW -e -c "show storageSubsystem summary;"| grep "SMcli completed successfully"|wc -l|sed 's/ //g'` -gt 0 ]; then
            echo "  connection ok"          
          else 
            echo "  connection failed!!"          
          fi
        fi
        echo ""          
done
echo ""



# Hitachi libraries and variables
#AIX
LIBPATH=$LIBPATH:$HUS_CLIDIR/lib
#HP-UX
SHLIB_PATH=$SHLIB_PATH:$HUS_CLIDIR/lib
#Linux
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HUS_CLIDIR/lib
STONAVM_HOME=$HUS_CLIDIR
STONAVM_ACT=on
STONAVM_RSP_PASS=on
export  LIBPATH SHLIB_PATH LD_LIBRARY_PATH STONAVM_HOME STONAVM_ACT STONAVM_RSP_PASS

for line in `cat $STORAGE_CFG|sed 's/#.*$//'|egrep ":HUS:"|egrep -v "^#"`
do
        # Storage name alias:XIV:_xiv_ip_:_password_:
        STORAGE_NAME=`echo $line | awk 'BEGIN{FS=":"}{print $1}'`
        STORAGE_TYPE=`echo $line | awk 'BEGIN{FS=":"}{print $2}'`

        export STORAGE_NAME STORAGE_TYPE

        ERRLOG_HUS="$ERRLOG-${STORAGE_NAME}"
        OUTLOG_HUS="$INPUTDIR/logs/${STORAGE_NAME}.output_hus.log"
        export ERRLOG_HUS OUTLOG_HUS

        if [ ! -f $HUS_CLIDIR/auperform ]; then
          echo "HUS Error: could not found HSNM2 binnary : $HUS_CLIDIR/auperform, Install HSNM2 CLI or update HUS_CLIDIR in etc/stor2rrd.cfg"
          break
        fi
       
        echo "========================="
        echo "STORAGE: $STORAGE_NAME: $STORAGE_TYPE"
        echo "========================="

        echo "  $HUS_CLIDIR/auunitinfo -unit $STORAGE_NAME"
	if [ `$HUS_CLIDIR/auunitinfo -unit "$STORAGE_NAME" 2>/dev/null| wc -l|sed 's/ //g'` -gt 10 ]; then
          echo "  connection ok"
        else 
          echo "  connection failed!!"
        fi
        echo ""
done
echo ""

count=0
for line in `cat $STORAGE_CFG|sed 's/#.*$//'|egrep ":NETAPP:"|egrep -v "^#"`
do
        # Name:SWIZ:DEVID:HMC1:HMC2:
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

        if [ "$NA_IP"x = "x" ]; then
          echo "$STORAGE_NAME: Some problem with storage cfg. Storage IP/hostname must be set. Check $STORAGE_CFG line: $line"
          continue
        fi

        echo "========================="
        echo "STORAGE: $STORAGE_NAME: $STORAGE_TYPE/$STORAGE_MODE"
        echo "========================="

        echo "  ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=no -p $NA_PORT_SSH $NA_USER@$NA_IP  \"?\""
        ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=no -p $NA_PORT_SSH $NA_USER@$NA_IP  "?" >/dev/null
        if [ $? -eq 0 ]; then
          echo "  SSH connection OK"
          echo "  Testing API connection..."
          $PERL $BINDIR/na_apitest.pl
        else 
          echo "  SSH connection failed!!!"
        fi
        echo ""
        (( count = count + 1 ))
done
echo ""


# 3PAR

for line in `cat $STORAGE_CFG|sed 's/#.*$//'|egrep ":3PAR:"|egrep -v "^#"`
do
        # Name:SWIZ:DEVID:HMC1:HMC2:
        STORAGE_NAME=`echo $line | awk 'BEGIN{FS=":"}{print $1}'`
        STORAGE_TYPE=`echo $line | awk 'BEGIN{FS=":"}{print $2}'`

        # 3PAR/Storwize Storage Family
        PAR_IP=`echo $line | awk 'BEGIN{FS=":"}{print $3}'`
        PAR_USER=$STORAGE_USER
        if [ ! x"$STORAGE_USER_3PAR" = "x" ]; then
          PAR_USER=$STORAGE_USER_3PAR
        fi
        PAR_KEY=`echo $line | awk 'BEGIN{FS=":"}{print $4}'`
        PAR_DIR="$INPUTDIR/data/$STORAGE_NAME"
        PAR_INTERVAL=`expr $SAMPLE_RATE / 60`

        if [ "$PAR_IP"x = "x" ]; then
                echo "$STORAGE_NAME: Some problem with storage cfg. Storage IP must be set. Check $STORAGE_CFG line: $line"
                continue
        fi

        echo "========================="
        echo "STORAGE: $STORAGE_NAME: $STORAGE_TYPE"
        echo "========================="

        if [ "$PAR_KEY"x = "x" ]; then
          echo "  ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=no $STORAGE_USER@$PAR_IP  \"showuser\""
          ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=no $STORAGE_USER@$PAR_IP  "showuser" >/dev/null
	  if [ $? -eq 0 ]; then
            ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=no $STORAGE_USER@$PAR_IP  "showuser"|grep all | grep browse >/dev/null
	    if [ $? -eq 0 ]; then
              echo "  connection ok"          
            else 
              echo "  current account does not have right access role !!"          
              echo "$STORAGE_USER user on all 3PAR should have \"browse\" role and access to all domains"
              ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=no $STORAGE_USER@$PAR_IP  "showuser"
            fi
          else 
            echo "  connection failed!!"          
          fi
        else
          echo "  ssh -o ConnectTimeout=15 -i $PAR_KEY  $STORAGE_USER@$PAR_IP  \"showuser\""
          ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=no -i $PAR_KEY  $STORAGE_USER@$PAR_IP  "showuser" >/dev/null
	  if [ $? -eq 0 ]; then
            ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=no -i $PAR_KEY  $STORAGE_USER@$PAR_IP  "showuser"|grep all | grep browse >/dev/null
	    if [ $? -eq 0 ]; then
              echo "  connection ok"          
            else 
              echo "  current account does not have Administration access!!"          
              echo "$STORAGE_USER user on all 3PAR should have \"browse\" role and access to all domains"
              ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=no -i $PAR_KEY  $STORAGE_USER@$PAR_IP  "showuser"
            fi
          else 
            echo "  connection failed!!"          
          fi
        fi
        echo ""
done

### SAN ###
SNMP_VERSION=`cat $SAN_CFG|sed 's/#.*$//'|egrep "^SNMP_VERSION"|egrep -v "^#"|sed -e 's/^SNMP_VERSION=//'`
export SNMP_VERSION

SNMP_PORT=`cat $SAN_CFG|sed 's/#.*$//'|egrep "^SNMP_PORT"|egrep -v "^#"|sed -e 's/^SNMP_PORT=//'`
export SNMP_PORT

for line in `cat $SAN_CFG|sed 's/#.*$//'|egrep ".*:.*:.*:"|egrep -v "^#"`
do
  SAN_IP=`echo $line | awk 'BEGIN{FS=":"}{print $1}'`
  export SAN_IP

  SAN_TYPE=`echo $line | awk 'BEGIN{FS=":"}{print $3}'`
  export SAN_TYPE

  echo "========================="
  echo "SWITCH: $SAN_IP"
  echo "========================="

  $PERL $BINDIR/san_verify.pl $SAN_IP

  echo ""
  echo ""
done
