#!/bin/ksh

#test path to snmpwalk
snmpwalk="snmpwalk"
`$snmpwalk 1>/dev/null 2>/dev/null`
if [ ! "$?" -eq "1" ]; then
  snmpwalk="/usr/bin/snmpwalk"
  `$snmpwalk 1>/dev/null 2>/dev/null`
  if [ ! "$?" -eq "1" ]; then
    snmpwalk="/opt/freeware/bin/snmpwalk"
    `$snmpwalk 1>/dev/null 2>/dev/null`
    if [ ! "$?" -eq "1" ]; then
      echo "`date` : Path to snmpwalk not found! $0"
      exit 0
    fi
  fi
fi



if [ x"$SAN_IP" = "x" ]; then
  echo "`date` : Switch IP or hostname not found! $0"
  exit 0
fi
if [ x"$SNMP3_USER" = "x" ]; then
  echo "`date` : SNMP security user is not defined! Trying snmpuser1. $0"
  SNMP3_USER=snmpuser1
fi


cnt=1
while [ $cnt -le 128 ]
do
  ttt=`$snmpwalk -u $SNMP3_USER -v 3 -n VF:$cnt $SAN_IP 1.3.6.1.4.1.1588.2.1.1.1.6.2.1.3 > /dev/null 2>&1`
  rc=$?
  if [ $rc = 0 ]; then
    #echo "`date` :VF:$cnt:$rc";
    echo "VF:$cnt";
  fi
  cnt=`expr $cnt + 1`
done
