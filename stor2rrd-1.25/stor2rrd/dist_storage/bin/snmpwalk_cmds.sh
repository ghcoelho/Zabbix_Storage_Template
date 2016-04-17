
switch_ip="<switch_IP>"
community_string="public"
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


#brcd
echo 1.3.6.1.2.1.1.1
$snmpwalk -v 1 -c $community_string $switch_ip 1.3.6.1.2.1.1.1
echo ""
echo 1.3.6.1.2.1.1.5
$snmpwalk -v 1 -c $community_string $switch_ip 1.3.6.1.2.1.1.5
echo ""
echo 1.3.6.1.4.1.1588.2.1.1.1.6.2.1.3
$snmpwalk -v 1 -c $community_string $switch_ip 1.3.6.1.4.1.1588.2.1.1.1.6.2.1.3
echo ""
echo 1.3.6.1.4.1.1588.2.1.1.1.6.2.1.4
$snmpwalk -v 1 -c $community_string $switch_ip 1.3.6.1.4.1.1588.2.1.1.1.6.2.1.4
echo ""
echo 1.3.6.1.2.1.75.1.1.1
$snmpwalk -v 1 -c $community_string $switch_ip 1.3.6.1.2.1.75.1.1.1
echo ""
echo 1.3.6.1.2.1.75.1.1.2
$snmpwalk -v 1 -c $community_string $switch_ip 1.3.6.1.2.1.75.1.1.2
echo ""
echo 1.3.6.1.3.94.4.5.1.6
$snmpwalk -v 1 -c $community_string $switch_ip 1.3.6.1.3.94.4.5.1.6
echo ""
echo 1.3.6.1.3.94.4.5.1.7
$snmpwalk -v 1 -c $community_string $switch_ip 1.3.6.1.3.94.4.5.1.7
echo ""
echo 1.3.6.1.3.94.4.5.1.4
$snmpwalk -v 1 -c $community_string $switch_ip 1.3.6.1.3.94.4.5.1.4
echo ""
echo 1.3.6.1.3.94.4.5.1.5
$snmpwalk -v 1 -c $community_string $switch_ip 1.3.6.1.3.94.4.5.1.5
echo ""
echo 1.3.6.1.3.94.4.5.1.8
$snmpwalk -v 1 -c $community_string $switch_ip 1.3.6.1.3.94.4.5.1.8
echo ""
echo 1.3.6.1.3.94.4.5.1.40
$snmpwalk -v 1 -c $community_string $switch_ip 1.3.6.1.3.94.4.5.1.40
echo ""
echo 1.3.6.1.3.94.1.10.1.17
$snmpwalk -v 1 -c $community_string $switch_ip 1.3.6.1.3.94.1.10.1.17
echo ""
echo 1.3.6.1.3.94.1.10.1.15
$snmpwalk -v 1 -c $community_string $switch_ip 1.3.6.1.3.94.1.10.1.15
echo ""
echo 1.3.6.1.3.94.1.10.1.10
$snmpwalk -v 1 -c $community_string $switch_ip 1.3.6.1.3.94.1.10.1.10
echo ""
echo 1.3.6.1.3.94.4.5.1.45
$snmpwalk -v 1 -c $community_string $switch_ip 1.3.6.1.3.94.4.5.1.45
echo ""
echo 1.3.6.1.3.94.1.12.1.4
$snmpwalk -v 1 -c $community_string $switch_ip 1.3.6.1.3.94.1.12.1.4
echo ""
echo 1.3.6.1.3.94.1.12.1.5
$snmpwalk -v 1 -c $community_string $switch_ip 1.3.6.1.3.94.1.12.1.5
echo ""
echo 1.3.6.1.3.94.1.12.1.8
$snmpwalk -v 1 -c $community_string $switch_ip 1.3.6.1.3.94.1.12.1.8
echo ""
echo 1.3.6.1.3.94.1.7.1.3
$snmpwalk -v 1 -c $community_string $switch_ip 1.3.6.1.3.94.1.7.1.3
echo ""
echo 1.3.6.1.3.94.1.10.1.3
$snmpwalk -v 1 -c $community_string $switch_ip 1.3.6.1.3.94.1.10.1.3
echo ""

echo "swFCPortTxWords-32bit counter"
$snmpwalk -v $version -c $community_string $switch_ip 1.3.6.1.4.1.1588.2.1.1.1.6.2.1.11

