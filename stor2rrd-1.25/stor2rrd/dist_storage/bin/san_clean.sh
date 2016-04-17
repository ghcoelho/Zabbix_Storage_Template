#!/bin/ksh
#
# . /home/stor2rrd/stor2rrd/etc/stor2rrd.cfg; sh ./bin/san_clean.sh
#

# Load LPAR2RRD configuration
if [ -f `dirname $0`/etc/stor2rrd.cfg ]; then
  . `dirname $0`/etc/stor2rrd.cfg
else
  if [ -f `dirname $0`/../etc/stor2rrd.cfg ]; then
    . `dirname $0`/../etc/stor2rrd.cfg
  fi
fi
if [ `echo $INPUTDIR|egrep "bin$"|wc -l|sed 's/ //g'` -gt 0 ]; then
  INPUTDIR=`dirname $INPUTDIR`

fi

if [ ! -d "$INPUTDIR" ]; then
  echo "Does not exist \$INPUTDIR; have you loaded environment properly? . /home/stor2rrd/stor2rrd/etc/stor2rrd.cfg"
  exit 1
fi


echo "This data (directories) contain SAN switch related data and will be deleted:"
for vmware_file in `ls $INPUTDIR/data/*/SAN-BRCD 2>/dev/null `
do
  vmware_dir=`dirname $vmware_file`
  echo "  $vmware_dir"
done



echo ""
echo "Do you want to continue with removing of them?"
echo "[Y/N]"
read yes

if [ ! "$yes" = "Y" -a ! "$yes" = "y" ]; then
  exit 0
fi


for vmware_file in `ls $INPUTDIR/data/*/SAN-BRCD 2>/dev/null `
do
  vmware_dir=`dirname $vmware_file`
  echo "  removing:  $vmware_dir"
  rm -rf "$vmware_dir"
done

