#!/bin/sh
#
# STOR2RRD update script
# usage : ./update.sh
#         ./update.sh nocheck  # consistency check of RRDTool files is excluded
#
#

LANG=C
export LANG

check=1
if [ ! "$1"x = "x" ]; then
  if [ "$1" = "nocheck" ]; then
    check=0
  fi
fi

DEBUG_UPD=0
ID=`id -un`

umask 022

# test if "ed" command does not exist, it might happen especially on some Linux distros
ed << END 2>/dev/null 1>&2
q
END
if [ $? -gt 0 ]; then
  echo "ERROR: "ed" command does not seem to be installed or in $PATH"
  echo "Exiting ..."
  exit 1
fi


if [ -d $HOME/stor2rrd ]; then
  HOME1=$HOME/stor2rrd
fi

if [ `ps -ef|egrep "/load.sh"|grep -v grep|grep stor2|wc -l` -gt 0 ]; then
  echo "STOR2RRD is apparently running, can it be stopped? [y]:"

  # check if it is running from the image, then no wait for the input
  answer="y"
  if [ "$VM_IMAGE"x = "x" ]; then
    read answer
  else
    if [ $VM_IMAGE -eq 0 ]; then
      read answer
    else
      echo ""
      echo "yes"
    fi
  fi

  if [ "$answer"x = "x" -o "$answer" = "y" -o "$answer" = "Y" ]; then
    kill `ps -ef|egrep "load.sh|storage.pl|rrdtool"|grep -v grep|grep stor2|awk '{print $2}'|xargs` 2>/dev/null
    sleep 3
    if [ `ps -ef|egrep "load.sh|storage.pl|rrdtool"|grep -v grep||grep stor2|wc -l` -gt 0 ]; then
      echo "STOR2RRD could not be stopped, pls check following processes and cancel them manually if necessary"
      echo "ps -ef|egrep \"load.sh|storage.pl|rrdtool\"|grep -v grep|grep stor2"
      echo ""
      ps -ef|egrep "load.sh|storage.pl|rrdtool"|grep -v grep|grep stor2
      echo ""
    fi
  fi
fi

os_aix=` uname -a|grep AIX|wc -l`
if [ $os_aix -eq 0 ]; then
  ECHO_OPT="-e"
else
  ECHO_OPT=""
fi


echo "STOR2RRD upgrade under user : \"$ID\"" 
echo ""
if [ -f "$HOME/.stor2rrd_home" ]; then
  HOME1=`cat "$HOME/.stor2rrd_home"`
fi

if [ ! "$HOME1"x = "x" -a -d "$HOME1" ]; then
  echo $ECHO_OPT "Where is STOR2RRD actually located [$HOME1]: \c"
else
  if [ x"$HOME1" = "x" ]; then
    echo $ECHO_OPT "Where is STOR2RRD actually located: \c"
  else
    echo $ECHO_OPT "Where is STOR2RRD actually located [$HOME1]: \c"
  fi
fi

# check if it is running from the image, then no wait for the input
if [ "$VM_IMAGE"x = "x" ]; then
  read HOMELPAR
else
  if [ $VM_IMAGE -eq 0 ]; then
    read HOMELPAR
  else
    echo ""
    echo "$HOME1"
  fi
fi

if [ x"$HOMELPAR" = "x" ]; then
  HOMELPAR=$HOME1
fi


# Check if it runs under the right user
check_file="$HOMELPAR/bin/storage.pl"
if [ ! -f "$check_file" ]; then
  check_file="$HOMELPAR/storage.pl"
  if [ ! -f "$check_file" ]; then
    echo "STOR2RRD product has not been found in: $HOMELPAR"
    exit 1
  fi
fi

install_user=`ls -lX "$check_file"|awk '{print $3}'` # must be X to do not cut user name to 8 chars
running_user=`id |awk -F\( '{print $2}'|awk -F\) '{print $1}'`
if [ ! "$install_user" = "$running_user" ]; then
  echo "You probably trying to run it under wrong user"
  echo "STOR2RRD files are owned by : $install_user"
  echo "You are : $running_user"
  echo "STOR2RRD update should run only under user which owns installed package"
  echo "Do you want to really continue? [n]:"
  # check if it is running from the image, then no wait for the input
  read answer
  if [ "$answer"x = "x" -o "$answer" = "n" -o "$answer" = "N" ]; then
    exit 1
  fi
fi


INPUTDIR=$HOMELPAR
CFG=$HOMELPAR/etc/stor2rrd.cfg
cp -p $CFG $CFG-backup

if [ ! -f "$CFG" ]; then
 echo "Could not find config file $CFG, STOR2RRD is not installed there, exiting"
 exit 1
fi

if [ -f stor2rrd.tar.Z ]; then
  which uncompress >/dev/null 2>&1 
  if [ $? -eq 0 ]; then 
     uncompress -f stor2rrd.tar.Z 
  else 
     which gunzip >/dev/null 2>&1 
     if [ $? -eq 0 ]; then 
       gunzip -f stor2rrd.tar.Z 
     else 
       echo "Could not locate uncompress or gunzip commands. exiting" 
       exit  1
     fi 
  fi 
fi

if [ -f stor2rrd.tar ]; then
  tar xf stor2rrd.tar
else
  echo "looks like it is already extracted, tar is missing"
fi

cd dist_storage

# Read original configuration
WEBDIR=`sed 's/#.*$//g' $CFG|egrep "WEBDIR=" | tail -1|awk -F = '{print $2}'    |sed -e 's/\//\\\\\\\\\//g' -e 's/ //g'|sed 's/ /\\\\ /g'`
DS8_USER=`sed 's/#.*$//g' $CFG|egrep "DS8_USER=" | tail -1|awk -F = '{print $2}'|sed -e 's/	//g' -e 's/ //g'`
STORAGE_USER=`sed 's/#.*$//g' $CFG|egrep "STORAGE_USER=" | tail -1|awk -F = '{print $2}'|sed -e 's/	//g' -e 's/ //g'`
DS8_CLIDIR=`sed 's/#.*$//g' $CFG|egrep "DS8_CLIDIR=" | tail -1|awk -F = '{print $2}'|sed -e 's/\//\\\\\\\\\//g' -e 's/ //g'|sed 's/ /\\\\ /g'` 
DS5_CLIDIR=`sed 's/#.*$//g' $CFG|egrep "DS5_CLIDIR=" | tail -1|awk -F = '{print $2}'|sed -e 's/\//\\\\\\\\\//g' -e 's/ //g'|sed 's/ /\\\\ /g'` 
HUS_CLIDIR=`sed 's/#.*$//g' $CFG|egrep "HUS_CLIDIR=" | tail -1|awk -F = '{print $2}'|sed -e 's/\//\\\\\\\\\//g' -e 's/ //g'|sed 's/ /\\\\ /g'` 
VSP_CLIDIR=`sed 's/#.*$//g' $CFG|egrep "VSP_CLIDIR=" | tail -1|awk -F = '{print $2}'|sed -e 's/\//\\\\\\\\\//g' -e 's/ //g'|sed 's/ /\\\\ /g'` 
STORAGE_CFG=`sed 's/#.*$//g' $CFG|egrep "STORAGE_CFG=" | tail -1|awk -F = '{print $2}'|sed -e 's/\//\\\\\\\\\//g' -e 's/ //g'|sed 's/ /\\\\ /g'` 
SAN_CFG=`sed 's/#.*$//g' $CFG|egrep "SAN_CFG=" | tail -1|awk -F = '{print $2}'|sed -e 's/\//\\\\\\\\\//g' -e 's/ //g'|sed 's/ /\\\\ /g'` 
eval ERRLOG=` sed 's/#.*$//g' $CFG|egrep "ERRLOG=" | tail -1|awk -F = '{print $2}'| sed -e 's/ //g'|sed 's/ /\\\\ /g'`
ERRLOG=`echo $ERRLOG  |sed 's/\//\\\\\\\\\//g'` # It us due to $INPUTDIR which is used in old version and its evaulation, no other way
eval ERRLOG_DS8K=`sed 's/#.*$//g' $CFG|egrep "ERRLOG_DS8K=" | tail -1|awk -F = '{print $2}'|sed -e 's/stor2rrdlogs/stor2rrd\/logs/' -e 's/ //g'|sed 's/ /\\\\ /g'`
ERRLOG_DS8K=`echo $ERRLOG_DS8K  |sed 's/\//\\\\\\\\\//g'`
PERL=`sed 's/#.*$//g' $CFG|egrep "PERL=" | tail -1|awk -F = '{print $2}'|sed -e 's/\//\\\\\\\\\//g' -e 's/ //g'|sed 's/ /\\\\ /g'` 
PERL_act=`sed 's/#.*$//g' $CFG|egrep "PERL=" | tail -1|awk -F = '{print $2}'|sed -e 's/ //g'|sed 's/ /\\\\ /g'` 
RRD=`sed 's/#.*$//g' $CFG|egrep "RRDTOOL=" | tail -1|awk -F = '{print $2}' |sed -e 's/\//\\\\\\\\\//g' -e 's/ //g'|sed 's/ /\\\\ /g'` 
SAMPLE_RATE=`sed 's/#.*$//g' $CFG|egrep "SAMPLE_RATE=" | tail -1|awk -F = '{print $2}'|sed -e 's/	//g' -e 's/ //g'`
VOLUME_IO_MAX=`sed 's/#.*$//g' $CFG|egrep "VOLUME_IO_MAX=" | tail -1|awk -F = '{print $2}'|sed -e 's/	//g' -e 's/ //g'`
VOLUME_DATA_MAX=`sed 's/#.*$//g' $CFG|egrep "VOLUME_DATA_MAX=" | tail -1|awk -F = '{print $2}'|sed -e 's/	//g' -e 's/ //g'`
VOLUME_RESPONSE_MAX=`sed 's/#.*$//g' $CFG|egrep "VOLUME_RESPONSE_MAX=" | tail -1|awk -F = '{print $2}'|sed -e 's/	//g' -e 's/ //g'`
VOLUME_CACHE_MAX=`sed 's/#.*$//g' $CFG|egrep "VOLUME_CACHE_MAX=" | tail -1|awk -F = '{print $2}'|sed -e 's/	//g' -e 's/ //g'`
RRDHEIGHT=`sed 's/#.*$//g' $CFG|egrep "RRDHEIGHT=" $CFG|egrep -v "#|DASHB_"| tail -1|awk -F = '{print $2}'|sed -e 's/	//g' -e 's/ //g'`
RRDWIDTH=`sed 's/#.*$//g' $CFG|egrep "RRDWIDTH=" $CFG|egrep -v "#|DASHB_"| tail -1|awk -F = '{print $2}'|sed -e 's/	//g' -e 's/ //g'`
DASHB_RRDHEIGHT=`sed 's/#.*$//g' $CFG|egrep "DASHB_RRDHEIGHT=" | tail -1|awk -F = '{print $2}'|sed -e 's/	//g' -e 's/ //g'`
DASHB_RRDWIDTH=`sed 's/#.*$//g' $CFG|egrep "DASHB_RRDWIDTH=" | tail -1|awk -F = '{print $2}'|sed -e 's/	//g' -e 's/ //g'`
PERL5LIB=`sed 's/#.*$//g' $CFG|egrep "PERL5LIB=" | tail -1|awk -F = '{print $2}'|sed -e 's/ //g'|sed 's/ /\\\\ /g'` # --> it is further modifified below !!!
DEBUG=`sed 's/#.*$//g' $CFG|egrep "DEBUG=" | tail -1|awk -F = '{print $2}'|sed -e 's/	//g' -e 's/ //g'`
PICTURE_COLOR=`sed 's/#.*$//g' $CFG|egrep "PICTURE_COLOR=" | tail -1|awk -F = '{print $2}'|sed -e 's/	//g' -e 's/ //g'`
TOPTEN=`sed 's/#.*$//g' $CFG|egrep "TOPTEN=" | tail -1|awk -F = '{print $2}'|sed -e 's/	//g' -e 's/ //g'`
LEGEND_HEIGHT=`sed 's/#.*$//g' $CFG|egrep "LEGEND_HEIGHT=" | tail -1|awk -F = '{print $2}'|sed 's/ /\\\\ /g'`

# find out if LIBPATH is set
aix_libpath=`sed 's/#.*$//g' $CFG|egrep "LIBPATH=" |grep freeware| wc -l`


WEBDIR_PLAIN=`echo $WEBDIR | sed 's/\\\//g'`

if [ -f ../version.txt ]; then
  # actually installed version
  version_new=`cat ../version.txt|tail -1`
fi

if [ -f $HOMELPAR/etc/version.txt ]; then
  version=`egrep "[0-9]\.[0-9]" $HOMELPAR/etc/version.txt|tail -1`
  VER=`egrep "[0-9]\.[0-9]" $HOMELPAR/etc/version.txt|tail -1|sed 's/-.*$//'`  # get only major version info
else
  # old version of getting version
  if [ `grep "# version " $CFG|wc -l` -eq 1 ]; then
    VER=`egrep "# version " $CFG|tail -1|awk '{print $3}'`
  else
    VER=`egrep "version=" $CFG|tail -1|awk -F= '{print $2}'`
  fi
  version=$VER
fi
  
if [ "$STORAGE_USER"X = "X" ]; then
  STORAGE_USER=$DS8_USER
fi

if [ "$DS8_CLIDIR"X = "X" ]; then
  DS8_CLIDIR=`echo "/opt/ibm/dscli"|sed -e 's/\//\\\\\\\\\//g' -e 's/ //g'`
fi

if [ "$DS5_CLIDIR"X = "X" ]; then
  DS5_CLIDIR=`echo "/usr/SMclient"|sed -e 's/\//\\\\\\\\\//g' -e 's/ //g'`
fi

if [ "$HUS_CLIDIR"X = "X" ]; then
  HUS_CLIDIR=`echo "/usr/stonavm"|sed -e 's/\//\\\\\\\\\//g' -e 's/ //g'`
fi

if [ "$VSP_CLIDIR"X = "X" ]; then
  VSP_CLIDIR=`echo "/usr"|sed -e 's/\//\\\\\\\\\//g' -e 's/ //g'`
fi

if [ "$VOLUME_DATA_MAX"X = "X" ]; then
  VOLUME_DATA_MAX=1024
fi

if [ "$VOLUME_IO_MAX"X = "X" ]; then
  VOLUME_IO_MAX=50
fi

if [ "$VOLUME_RESPONSE_MAX"X = "X" ]; then
  VOLUME_RESPONSE_MAX=2
fi

if [ "$VOLUME_CACHE_MAX"X = "X" ]; then
  VOLUME_CACHE_MAX=1024
fi

if [ "$TOPTEN"X = "X" ]; then
  TOPTEN=11
fi

if [ "$SAN_CFG"X = "X" ]; then
  SAN_CFG=`echo "$HOMELPAR/etc/san-list.cfg" |sed -e 's/\//\\\\\\\\\//g' -e 's/ //g'`
fi

if [ "$RRDHEIGHT"X = "X" -o $RRDHEIGHT -eq 50 ]; then
  RRDHEIGHT=150
fi

if [ "$RRDWIDTH"X = "X" -o $RRDWIDTH -eq 120 ]; then
  RRDWIDTH=700 
fi

if [ "$DASHB_RRDHEIGHT"X = "X" ]; then
  DASHB_RRDHEIGHT=50
fi

if [ "$DASHB_RRDWIDTH"X = "X" ]; then
  DASHB_RRDWIDTH=120
fi

if [ "$LEGEND_HEIGHT"X = "X" ]; then
  LEGEND_HEIGHT=120
fi

if [ "$DEBUG"X = "X" ]; then
  DEBUG=1
fi

if [ "$PICTURE_COLOR"X = "X" -o "$PICTURE_COLOR" = "D3D2D2" -o "$PICTURE_COLOR" = "E3E2E2" ]; then
  PICTURE_COLOR=F7FCF8
fi

if [ "$DEBUG"X = "X" ]; then
  DEBUG=1
fi

echo "$PERL5LIB"|grep ":" >/dev/null 2>&1
if [ ! $? -eq 0 ]; then
    PERL5LIB=/opt/freeware/lib/perl/5.8.8:/opt/freeware/lib/perl/5.8.0:/usr/opt/perl5/lib/site_perl/5.8.2:/usr/lib/perl5/vendor_perl/5.8.5:/usr/share/perl5:/usr/lib/perl5:/usr/opt/perl5/lib/site_perl/5.8.8/aix-thread-multi:/opt/freeware/lib/perl5/vendor_perl/5.8.8/ppc-thread-multi
fi

# add actual paths
PPATH="/opt/freeware/lib/perl
/usr/opt/perl5/lib/site_perl
/usr/lib/perl5/vendor_perl
/usr/lib64/perl5/vendor_perl"

if [ ! -f $PERL_act ]; then
  echo "ERROR: Perl has not been found here: $PERL_act"
  echo "exiting, adjust right Perl path in etc/stor2rrd.cfg"
fi

perl_version=`$PERL_act -e 'print "$]\n"'|sed -e 's/0/\./g' -e 's/\.\.\.\./\./g' -e 's/\.\.\./\./g' -e 's/\.\./\./g' -e 's/ //g'`
PLIB=`for ppath in $PPATH
do
  echo $PERL5LIB|grep "$ppath/$perl_version"  >/dev/null
  if [ ! $? -eq 0 ]; then
    echo "$ppath/$perl_version"
   fi
done|xargs|sed -e 's/ /\:/g' -e 's/\:\:/\:/g'`


if [ `echo "$PERL5LIB"|grep aix-thread-multi|wc -l` -eq 0 ]; then
  PERL5LIB="$PERL5LIB:/usr/opt/perl5/lib/site_perl/5.8.8/aix-thread-multi"
fi
if [ `echo "$PERL5LIB"|grep ppc-thread-multi|wc -l` -eq 0 ]; then
  PERL5LIB="$PERL5LIB:/opt/freeware/lib/perl5/vendor_perl/5.8.8/ppc-thread-multi"
fi

PERL5LIB=`echo "$PLIB:$PERL5LIB"|sed -e 's/\//\\\\\\\\\//g' -e 's/ //g'`


if [ "$VER" = "" ]; then
  # very old version did not have version string inside, so putting here something low
  VER="1"
fi

VER_ORG=`echo $VER|sed 's/\.//g'`

if [ $DEBUG_UPD -eq 1 ]; then
  echo "
	$WEBDIR
	$HMC_USER
	$HMC_LIST
	$HMC_HOSTAME
	$MANAGED_SYSTEMS_EXCLUDE
	$PERL
	$RRDTOOL
	$SRATE
	$VER
	$WEBDIR_PLAIN
	$HWINFO
	$SYS_CHANG
	$RRDHEIGHT
	$RRDWIDTH
	$PERL5LIB
	$PICTURE_COLOR
	$DEBUG
  	$EXPORT_TO_CSV
  	$HEA
  	$STEP_HEA
  	$TOPTEN
  	$LPM
  	$LPM_LPAR_EXCLUDE
  	$LPM_SERVER_EXCLUDE
  	$LPM_HMC_EXCLUDE
  "
fi


if [ $VER_ORG -lt 116 ]; then
  # just forkaround for those which got the premium one as part of 1.20 beta testing
  rm -f $HOMELPAR/bin/premium.*
fi

if [ -f $HOMELPAR/bin/premium.pl -a ! -f bin/premium.pl ]; then
  echo ""
  echo "You are going to instal a free version over a full version!!!"
  echo "This is not supported and it will not work"
  echo "Type \"yes\" to delete full version features from your environment:"
  # check if it is running from the image, then no wait for the input
  if [ "$VM_IMAGE"x = "x" ]; then
    read full
  else
    if [ $VM_IMAGE -eq 0 ]; then
      read full
    else
      echo "yes"
      full="yes"
    fi
  fi
  if [ "$full" = "yes" ]; then
    rm $HOMELPAR/bin/premium.*
    echo "Full version features have been deleted."
  else
    echo "Full version features persist there, it might lead to errors."
  fi
fi

echo "Backing up original version : $version to $HOMELPAR/BACKUP-INSTALL/stor2rrd-$version"
if [ ! -d $HOMELPAR/BACKUP-INSTALL ]; then
  mkdir $HOMELPAR/BACKUP-INSTALL
fi
if [ ! -d $HOMELPAR/BACKUP-INSTALL/stor2rrd-$version ]; then
  mkdir $HOMELPAR/BACKUP-INSTALL/stor2rrd-$version
fi

echo "Saving actual distribution and compressing logs"
cp -R $HOMELPAR/logs $HOMELPAR/BACKUP-INSTALL/stor2rrd-$version/ 2>/dev/null
rm -f $HOMELPAR/logs/* # clean up logs
gzip -f9 $HOMELPAR/BACKUP-INSTALL/stor2rrd-$version/logs/* 1>/dev/null 2>&1 #compress old logs

cp -R $HOMELPAR/etc $HOMELPAR/bin $HOMELPAR/BACKUP-INSTALL/stor2rrd-$version/ 2>/dev/null
cp $HOMELPAR/*.cfg $HOMELPAR/*.txt $HOMELPAR/*.sh $HOMELPAR/BACKUP-INSTALL/stor2rrd-$version/ 2>/dev/null
mv $HOMELPAR/*.sh $HOMELPAR/*.pl $HOMELPAR/*.pm $HOMELPAR/BACKUP-INSTALL/stor2rrd-$version/ 2>/dev/null
mv $HOMELPAR/stor2rrd-[1-9]* $HOMELPAR/BACKUP-INSTALL/  2>/dev/null # move away old backups


#cp $HOMELPAR/etc/stor2rrd.cfg $HOMELPAR/etc/stor2rrd.cfg-org
cp -R $HOMELPAR/html $HOMELPAR/stor2rrd-cgi $HOMELPAR/bin $HOMELPAR/BACKUP-INSTALL/stor2rrd-$version/ 2>/dev/null

# save cfg
mv $HOMELPAR/etc/storage-list.cfg $HOMELPAR/etc/storage-list.cfg-org
if [ -f $HOMELPAR/etc/san-list.cfg ]; then
  mv $HOMELPAR/etc/san-list.cfg $HOMELPAR/etc/san-list.cfg-org # since 1.14
fi
mv $HOMELPAR/etc/alias.cfg $HOMELPAR/etc/alias.cfg-org

# stopping svcperf.pl processes (SVC/Storwize)
if [ `ps -ef|grep svcperf.pl|grep perl|awk '{print $2}'|wc -l ` -gt 0 ]; then
  kill `ps -ef|grep svcperf.pl|grep perl|awk '{print $2}'|xargs`
  sleep 3
fi

echo "Copy new version to the target destination"
cp -R * $HOMELPAR/

COLLECTOR=0
if [ ! -f "$HOMELPAR/etc/.magic" -a -f "$HOMELPAR/etc/.magic-install" ]; then
  mv "$HOMELPAR/etc/.magic-install" "$HOMELPAR/etc/.magic"
  chmod 644 "$HOMELPAR/etc/.magic"
fi
if [ -f "$HOMELPAR/etc/.magic" ]; then
  . "$HOMELPAR/etc/.magic"
  if [ ! "$DO_NOT_SAVE_DATA"x = "x" ]; then
    if [ $DO_NOT_SAVE_DATA -eq 1 ]; then
      COLLECTOR=1
    fi
  fi
fi

if [ $COLLECTOR -eq 0 ]; then
  #  put WEB files immediately after the upgrade to do not have to wait for the end of upgrade
  echo "Copy GUI files : $HOMELPAR/www"
  cp $HOMELPAR/html/*html $HOMELPAR/www
  cp $HOMELPAR/html/*ico $HOMELPAR/www
  cp $HOMELPAR/html/*png $HOMELPAR/www

  pwd_org=`pwd`
  cd $HOMELPAR/html
  tar cf - jquery | (cd $HOMELPAR/www; tar xf - )
  tar cf - css    | (cd $HOMELPAR/www; tar xf - )
  cd $pwd_org >/dev/null
  if [ ! -f "$HOMELPAR/tmp/menu.txt" -a -f "$HOMELPAR/html/menu_default.txt" ]; then
    #place default menu.txt
    cp $HOMELPAR/html/menu_default.txt $HOMELPAR/tmp/menu.txt
  fi
  chown -R $ID $HOMELPAR/html
  chmod -R 755 $HOMELPAR/html # must be due tue subdirs jquery, images ...
fi


echo "Configuring new stor2rrd.cfg"
eval ' sed -e 's/WEBDIR=.*/WEBDIR=$WEBDIR/g' \
           -e 's/RRDTOOL=.*/RRDTOOL=$RRD/g' -e 's/SAMPLE_RATE=.*/SAMPLE_RATE=$SAMPLE_RATE/g' \
           -e 's/DS8_USER=.*/DS8_USER=$DS8_USER/g' -e 's/DS8_CLIDIR=.*/DS8_CLIDIR=$DS8_CLIDIR/g' \
           -e 's/DS5_CLIDIR=.*/DS5_CLIDIR=$DS5_CLIDIR/g' -e 's/HUS_CLIDIR=.*/HUS_CLIDIR=$HUS_CLIDIR/g' \
	   -e 's/PERL=.*/PERL=$PERL/g' -e 's/RRDHEIGHT=.*/RRDHEIGHT=$RRDHEIGHT/g' \
	   -e 's/RRDWIDTH=.*/RRDWIDTH=$RRDWIDTH/g' -e 's/PERL5LIB=.*/PERL5LIB=$PERL5LIB/g' \
           -e 's/DASHB_RRDHEIGHT=.*/DASHB_RRDHEIGHT=$DASHB_RRDHEIGHT/g' -e 's/DASHB_RRDWIDTH=.*/DASHB_RRDWIDTH=$DASHB_RRDWIDTH/g' \
	   -e 's/PICTURE_COLOR=.*/PICTURE_COLOR=$PICTURE_COLOR/g' -e 's/DEBUG=.*/DEBUG=$DEBUG/g' \
	   -e 's/TOPTEN=.*/TOPTEN=$TOPTEN/g' -e 's/ERRLOG=.*/ERRLOG=$ERRLOG/g' \
	   -e 's/ERRLOG_DS8K=.*/ERRLOG_DS8K=$ERRLOG_DS8K/g' \
	   -e 's/VOLUME_RESPONSE_MAX=.*/VOLUME_RESPONSE_MAX=$VOLUME_RESPONSE_MAX/g' \
	   -e 's/VOLUME_IO_MAX=.*/VOLUME_IO_MAX=$VOLUME_IO_MAX/g' \
	   -e 's/VOLUME_CACHE_MAX=.*/VOLUME_CACHE_MAX=$VOLUME_CACHE_MAX/g' \
	   -e 's/VOLUME_DATA_MAX=.*/VOLUME_DATA_MAX=$VOLUME_DATA_MAX/g' \
	   -e 's/STORAGE_USER=.*/STORAGE_USER=$STORAGE_USER/g' -e 's/LEGEND_HEIGHT=.*/LEGEND_HEIGHT=$LEGEND_HEIGHT/g' \
           -e 's/SAN_CFG=.*/SAN_CFG=$SAN_CFG/g' -e 's/VSP_CLIDIR=.*/VSP_CLIDIR=$VSP_CLIDIR/g' \
       	   -e 's/STORAGE_CFG=.*/STORAGE_CFG=$STORAGE_CFG/g' $HOMELPAR/etc/stor2rrd.cfg > $HOMELPAR/etc/stor2rrd.cfg-new '
if [ `cat $HOMELPAR/etc/stor2rrd.cfg-new|wc -l|sed 's/ //g'`  -eq 0 ]; then
  echo ""
  echo "ERROR: Configuration of $HOMELPAR/etc/stor2rrd.cfg failed, original file is kept"
  echo "       This might cause unpredictable problems, contact STOR2RRD support in case anything is not working fine after the update"
  echo ""
  cp $CFG-backup $CFG
else
  mv $HOMELPAR/etc/stor2rrd.cfg-new $HOMELPAR/etc/stor2rrd.cfg
fi
rm -f $CFG-backup


if [ $aix_libpath -eq 0 ]; then
  # comment out LIBPATH on AIX to avoid including /opt/freeware/bin which can cause a problem in some situations
ed $HOMELPAR/etc/stor2rrd.cfg << EOF 2>/dev/null 1>&2
g/export LIBPATH=/s/export LIBPATH=/#export LIBPATH=/g
g/  LIBPATH=/s/  LIBPATH=/ #LIBPATH=/g
w
q
EOF
fi



# save last template
mv $HOMELPAR/etc/storage-list.cfg $HOMELPAR/etc/storage-list.cfg.example 
if [ -f $HOMELPAR/etc/san-list.cfg-org ]; then
  mv $HOMELPAR/etc/san-list.cfg $HOMELPAR/etc/san-list.cfg.example 
fi
mv $HOMELPAR/etc/alias.cfg $HOMELPAR/etc/alias.cfg.example

# return cfg
mv $HOMELPAR/etc/storage-list.cfg-org $HOMELPAR/etc/storage-list.cfg
if [ -f $HOMELPAR/etc/san-list.cfg-org ]; then
 mv $HOMELPAR/etc/san-list.cfg-org $HOMELPAR/etc/san-list.cfg
fi
mv $HOMELPAR/etc/alias.cfg-org $HOMELPAR/etc/alias.cfg

if [ `grep SANPORT $HOMELPAR/etc/alias.cfg 2>/dev/null| wc -l | sed 's/ //g'` -eq 0 ]; then
  echo "#" >> $HOMELPAR/etc/alias.cfg
  echo "# for SAN switches:" >> $HOMELPAR/etc/alias.cfg
  echo "#SANPORT:switch_name:port_name:your_alias" >> $HOMELPAR/etc/alias.cfg
  echo "#SANPORT:SAN-switch1:2:ALIAS_for_port2" >> $HOMELPAR/etc/alias.cfg
fi

if [ `grep SNMP_PORT $HOMELPAR/etc/san-list.cfg 2>/dev/null| wc -l | sed 's/ //g'` -eq 0 ]; then
  echo "#" >> $HOMELPAR/etc/san-list.cfg
  echo "# Define your SNMP port If you using another then default 161" >> $HOMELPAR/etc/san-list.cfg
  echo "#SNMP_PORT=161" >> $HOMELPAR/etc/san-list.cfg
  echo "#" >> $HOMELPAR/etc/san-list.cfg
fi

# must be removed here before chown ...
rm -f $HOMELPAR/realt-error.log
rm -f $HOMELPAR/logs/error-cgi.log 

echo "Setting file/dir permissions, it might take some time in huge environments"
chown $ID $HOMELPAR
if [ ! $? -eq 0 ]; then
  echo "Problem with ownership of $HOMELPAR"
  echo "Fix it and run it again : chown  $ID $HOMELPAR" 
  exit 1
fi
chown $ID $HOMELPAR/* 2>&1|egrep -v "error-cgi|lost+found"
chown -R $ID $HOMELPAR/stor2rrd-cgi
chown -R $ID $HOMELPAR/MIBs
chown $ID $HOMELPAR/etc 
chown $ID $HOMELPAR/etc/*.cfg
chown $ID $HOMELPAR/etc/*.txt
chown -R $ID $HOMELPAR/logs 2>&1|egrep -v "error-cgi"
chown -R $ID $HOMELPAR/scripts 2>/dev/null
chown -R $ID $HOMELPAR/www   2>/dev/null
if [ ! -d $HOMELPAR/tmp ]; then
  mkdir $HOMELPAR/tmp
fi
chmod 755 $HOMELPAR/tmp 
chmod 755 $HOMELPAR/logs
chmod 755 $HOMELPAR/MIBs
chmod 666 $HOMELPAR/logs/* 2>&1|egrep -v "error-cgi"
chmod 755 $HOMELPAR
chmod 755 $HOMELPAR/bin
chmod -R 755 $HOMELPAR/stor2rrd-cgi
chmod -R o+r $HOMELPAR/www  2>/dev/null
chmod -R o+x $HOMELPAR/www 2>/dev/null
chmod 755 $HOMELPAR/bin/*.pl
chmod 755 $HOMELPAR/bin/*.pm
chmod 755 $HOMELPAR/bin/*.sh
chmod 755 $HOMELPAR/*.sh
chmod 755 $HOMELPAR/etc
# do not touch etc/web_config here!
chmod 644 $HOMELPAR/etc/*.cfg
chmod 644 $HOMELPAR/etc/*.txt
chmod 644 $HOMELPAR/MIBs/*
chmod 755 $HOMELPAR/scripts/* 2>/dev/null
chmod 644 $HOMELPAR/*.txt 2>/dev/null
if [ -f "$HOMELPAR/.magic" ]; then
  chown $ID $HOMELPAR/.magic 2>&1
  chmod 755 $HOMELPAR/.magic 2>&1
fi

if [ ! -d "$HOMELPAR/etc/web_config" ]; then
  mkdir "$HOMELPAR/etc/web_config"
  chmod 777 "$HOMELPAR/etc/web_config"
fi

if [ "$VM_IMAGE"x = "x" ]; then
  # only for non image update, it might take a long time and on image should not happen such things
  chown -R $ID $HOMELPAR/data  2>&1|egrep -v " path name does not exist|No such file or directory"
  chmod -R o+r $HOMELPAR/data 2>&1|egrep -v " path name does not exist|No such file or directory"
  chmod -R o+x $HOMELPAR/data 2>&1|egrep -v " path name does not exist|No such file or directory"
fi

ln -s /var/tmp/stor2rrd-realt-error.log $HOMELPAR/logs/error-cgi.log 2>/dev/null

# some old instances using this one CGI-BIN err log: /var/tmp/storage-realt-error.log
#if [ ! -f /var/tmp/stor2rrd-realt-error.log -a -f /var/tmp/storage-realt-error.log ]; then
#  rm $HOMELPAR/logs/error-cgi.log 
#  ln -s /var/tmp/storage-realt-error.log $HOMELPAR/logs/error-cgi.log 2>/dev/null
#fi

cd $HOMELPAR

if [ ! -d "$WEBDIR_PLAIN" ]; then
  mkdir "$WEBDIR_PLAIN"
fi


# Check whether web user has read&executable rights for CGI dir stor2rrd-cgi
www=`echo "$WEBDIR"|sed 's/\\\//g'`
DIR=""
IFS_ORG=$IFS
IFS="/"
for i in $www
do
  IFS=$IFS_ORG
  NEW_DIR=`echo $DIR$i/`
  #echo "01 $NEW_DIR -- $i -- $DIR ++ $www"
  NUM=`ls -dLl $NEW_DIR |awk '{print $1}'|sed -e 's/d//g' -e 's/-//g' -e 's/w//g' -e 's/\.//g'| wc -c`
  #echo "02 $NUM"
  if [ ! $NUM -eq 7 ]; then
    echo ""
    echo "WARNING, directory : $NEW_DIR has probably wrong rights" 
    echo "         $www dir and its subdirs have to be executable&readable for WEB user"
    ls -lLd $NEW_DIR
    echo ""
  fi
  DIR=`echo "$NEW_DIR/"`
  #echo $DIR
  IFS="/"
done
IFS=$IFS_ORG


# Check whether web user has read&executable rights for CGI dir stor2rrd-cgi
CGI="$HOMELPAR/stor2rrd-cgi"
DIR=""
IFS_ORG=$IFS
IFS="/"
for i in $CGI
do
  IFS=$IFS_ORG
  NEW_DIR=`echo $DIR$i/`
  NUM=`ls -dLl $NEW_DIR |awk '{print $1}'|sed -e 's/d//g' -e 's/-//g' -e 's/w//g' -e 's/\.//g'| wc -c`
  #echo $NUM
  if [ ! $NUM -eq 7 ]; then
    echo ""
    echo "WARNING, directory : $NEW_DIR has probably wrong rights" 
    echo "         it dir has to be executable&readable for WEB user"
    ls -lLd $NEW_DIR
    echo ""
  fi
  DIR=`echo "$NEW_DIR/"`
  #echo $DIR
  IFS="/"
done
IFS=$IFS_ORG


rm -f $HOMELPAR/tmp/[1-9]* 2>/dev/null # do not remove everything as usually, topten files should stay


# change #!bin/ksh in shell script to #!bin/bash on Linux platform
os_aix=` uname -a|grep AIX|wc -l`
os_linux=` uname -a|grep Linux|wc -l`
if [ $os_linux -gt 0 ]; then
  # If Linux then change all "#!bin/sh --> #!bin/bash
  for sh in $HOMELPAR/bin/*.sh
  do
  ed $sh << EOF 2>/dev/null 1>&2
1s/\/ksh/\/bash/
w
q
EOF
  done

  for sh in $HOMELPAR/*.sh
  do
  ed $sh << EOF 2>/dev/null 1>&2
1s/\/ksh/\/bash/
w
q
EOF
  done

  for sh in $HOMELPAR/stor2rrd-cgi/*.sh
  do
  ed $sh << EOF 2>/dev/null 1>&2
1s/\/ksh/\/bash/
w
q
EOF
  done

else 
  # for AIX Solaris etc, all should be already in place just to be sure ...
  # change all "#!bin/bash --> #!bin/ksh
  for sh in $HOMELPAR/bin/*.sh
  do
  ed $sh << EOF 2>/dev/null 1>&2
1s/\/bash/\/ksh/
w
q
EOF
  done

  for sh in $HOMELPAR/*.sh
  do
  ed $sh << EOF 2>/dev/null 1>&2
1s/\/bash/\/ksh/
w
q
EOF
  done

  for sh in $HOMELPAR/stor2rrd-cgi/*.sh
  do
  ed $sh << EOF 2>/dev/null 1>&2
1s/\/bash/\/ksh/
w
q
EOF
  done
fi


# Custom groups
# Refresh custom restriction after the upgrade
rm -f $HOMELPAR/tmp/custom-group/.*-ll.cmd

# remove custom cmd definitions to be sure that they are reinitiated after upgrade,
rm -f $HOMELPAR/tmp/custom-group/*cmd


if [  $COLLECTOR -eq 0 ]; then
  # ulimit check
  # necessary for big aggregated graphs
  # 
  ulimit_message=0
  data=`ulimit -d`
  if [ ! "$data" = "unlimited" -a ! "$data" = "hard" -a ! "$data" = "soft" ]; then
    echo ""
    echo "Warning: increase data ulimit for $ID user, it is actually too low ($data)"
    echo " AIX: chuser  data=-1 $ID"
    echo " Linux: # vi /etc/security/limits.conf"
    echo "        @$ID        soft    data            -1"
    ulimit_message=1
  fi
  stack=`ulimit -s`
  if [ ! "$stack" = "unlimited" -a ! "$stack" = "hard" -a ! "$data" = "soft" ]; then
    echo ""
    echo "Warning: increase stack ulimit for $ID user, it is actually too low ($stack)"
    echo " AIX: chuser  stack=-1 $ID"
    echo " Linux: # vi /etc/security/limits.conf"
    echo "        @$ID        soft    stack           -1"
    ulimit_message=1
  fi
  stack=`ulimit -m`
  if [ ! "$stack" = "unlimited" -a ! "$stack" = "hard" -a ! "$data" = "soft" ]; then
    echo ""
    echo "Warning: increase stack ulimit for $ID user, it is actually too low ($rss)"
    echo " AIX: chuser  rss=-1 $ID"
    ulimit_message=1
  fi
  if [ $ulimit_message -eq 1 ]; then
    echo ""
    echo "Assure that the same limits has even web user (apache/nobody/http)"
    echo ""
  fi
fi


# fix a bug from 0.21  --> remove volumes.cfg (volumes colour table)
find $HOMELPAR/data -name volumes.col -exec rm -f {} \;

#
# update etc/storage-list.cfg by new storage templates
#

#SVC/Storwize
exist=`grep SWIZ $HOMELPAR/etc/storage-list.cfg|wc -l|sed 's/ //g'`
if [ $exist -eq 0 ]; then
  # add storages type in storage-list.cfg
  cat << END >> $HOMELPAR/etc/storage-list.cfg

# IBM V7000 STORWIZE or IBM SVC (both same type SWIZ)
# Storage name alias:SWIZ:_cluster_ip_:_ssh_key_file_:VOLUME_AGG_DATA_LIM:VOLUME_AGG_IO_LIM:SAMPLE_RATE_MINS
#stor_alias:SWIZ:stor_host.example.com:/home/stor2rrd/.ssh/id_stor_alias_rsa
#stor_alias-1:SWIZ:stor_host-1.example.com:/home/stor2rrd/.ssh/id_stor_alias_rsa:1024:512:5


#
# Following poarameters do not have to be used, they are only about replacing defaults
# per storage base
#
# VOLUME_AGG_DATA_LIM/VOLUME_AGG_IO_LIM: data/io limits for displaing volumes in aggregated graphs
#    global defauls are set in etc/stor2rrd.cfg: VOLUME_IO_MAX=100; VOLUME_DATA_MAX=1024
# SAMPLE_RATE_MINS: says how often is downloaded data from the storage in minutes
#                   it replaces global default from stor2rrd.cfg (STEP=300 --> 5mins)
#                   storages with thousands of LUNs/VOLUMEs might need more time to get stats

END
fi

# XIV
exist=`grep XIV $HOMELPAR/etc/storage-list.cfg|wc -l|sed 's/ //g'`
if [ $exist -eq 0 ]; then
  # add storages type in storage-list.cfg
  cat << END >> $HOMELPAR/etc/storage-list.cfg

#
# IBM XIV (available from v1.10)
#
# Storage name alias:XIV:_xiv_ip_:_password_:VOLUME_AGG_DATA_LIM:VOLUME_AGG_IO_LIM:SAMPLE_RATE_MINS
# Password for the user stor2rrd on the storage
#
#xiv01:XIV:xiv_host01.example.com:password
#xiv02:XIV:xiv_host02.example.com:password:1024:512:15

END
fi

# DS5K
exist=`grep DS5K $HOMELPAR/etc/storage-list.cfg|wc -l|sed 's/ //g'`
if [ $exist -eq 0 ]; then
  # add storages type in storage-list.cfg
  cat << END >> $HOMELPAR/etc/storage-list.cfg

#
# IBM DS3000/4000/5000
#
#storage_alias:DS5K:storage_user:user_password:VOLUME_AGG_DATA_LIM:VOLUME_AGG_IO_LIM:SAMPLE_RATE_MINS
#new storages can be configured to use username/password (use "monitoring" account), old ones do not have this option
#
#DS3700:DS5K:monitor:password:256:10:5
#DS5020:DS5K

END
fi

# Hitachi HUS
exist=`grep HUS $HOMELPAR/etc/storage-list.cfg|wc -l|sed 's/ //g'`
if [ $exist -eq 0 ]; then
  # add storages type in storage-list.cfg
  cat << END >> $HOMELPAR/etc/storage-list.cfg

#
# Hitachi HUS
#
#storage_alias:HUS:VOLUME_AGG_DATA_LIM:VOLUME_AGG_IO_LIM:SAMPLE_RATE_MINS
#
#HUS110:HUS:256:10:5
#HUS130:HUS:
#AMS2000-alias:HUS:

END
fi

# HP 3PAR 
exist=`grep 3PAR $HOMELPAR/etc/storage-list.cfg|wc -l|sed 's/ //g'`
if [ $exist -eq 0 ]; then
  # add storages type in storage-list.cfg
  cat << END >> $HOMELPAR/etc/storage-list.cfg

#
# HP 3PAR
#
# Storage name alias:3PAR:storage IP or hostname:_ssh_key_file_:VOLUME_AGG_DATA_LIM:VOLUME_AGG_IO_LIM:SAMPLE_RATE_MINS
#
#3PAR01-alias:3PAR:3par_host.example.com:/home/stor2rrd/.ssh/id_stor_alias_rsa:2048:512:5
#3PAR02-alias:3PAR:3par_host.example.com:

END
fi


# NetApp  
#exist=`grep -i netapp $HOMELPAR/etc/storage-list.cfg|wc -l|sed 's/ //g'`
#if [ $exist -eq 0 ]; then
#  # add storages type in storage-list.cfg
#  cat << END >> $HOMELPAR/etc/storage-list.cfg
#
##
## NetApp
##
## NetApp Alias : NETAPP : NetApp mode (CMODE|7MODE) : hostname|IP : SSH port : API port : API uses SSL/HTTPS (0|1) : API user name : API encrypted password : VOLUME_AGG_DATA_LIM : VOLUME_AGG_IO_LIM : SAMPLE_RATE_MINS
##cmode-alias:NETAPP:CMODE:cmode:22:443:1:stor2rrd:IT5gYGAK:1024:10:0
##7mode-alias:NETAPP:7MODE:7mode:22:443:1:stor2rrd:IT5gYGAK:0:0:0
## to encrypt password use: perl ./bin/spasswd.pl
#
#END
#fi

#
# END of update etc/storage-list.cfg by new storage templates
#


cd $HOMELPAR
if [  $COLLECTOR -eq 0 ]; then
  if [ $os_aix -eq 0 ]; then
    free=`df .|grep -iv filesystem|xargs|awk '{print $4}'`
    freemb=`echo "$free/1048"|bc`
    if [ $freemb -lt 2048 ]; then
      echo ""
      echo "WARNING: free space in $HOMELPAR is too low : $freemb MB"
      echo "         note that 1 storage needs 1 - 2 GB space depends on number of volumes/pools/ranks/disks/mdisks"
    fi
  else
    free=`df .|grep -iv filesystem|xargs|awk '{print $3}'`
    freemb=`echo "$free/2048"|bc`
    if [ $freemb -lt 2048 ]; then
      echo ""
      echo "WARNING: free space in $HOMELPAR is too low : $freemb MB"
      echo "         note that 1 storage needs 1 - 2 GB space depends on number of volumes/pools/ranks/disks/mdisks"
    fi
  fi
fi

if [ $VER_ORG -lt 43 ]; then
  # for SVC/Storwize and stor2rrd less than 0.43 has been wrongly filled up tiered pool capacity data 
  # so remove them ...
  cd $HOMELPAR/data
  for storage in */MDISK
  do
    if [ -L "$storage" ]; then
      storage_name=`dirname $storage`
      tar cf $HOMELPAR/tmp/$storage_name-pool-cap.tar $storage_name/POOL/*-cap.rrd
      echo ""
      echo "Removing wrong tiering pool capacity data: rm -f $storage_name/POOL/*-cap.rrd"
      echo "Backup is here: tmp/$storage_name-pool-cap.tar"
      rm -f $storage_name/POOL/*-cap.rrd
    fi
  done
fi

# setting up the font dir (necessary for 1.3 on AIX)
FN_PATH="<?xml version=\"1.0\"?>
<!DOCTYPE fontconfig SYSTEM \"fonts.dtd\">
<fontconfig>
<dir>/opt/freeware/share/fonts/dejavu</dir>
</fontconfig>"

if [ ! -f "$HOME/.config/fontconfig/.fonts.conf" -o `grep -i deja "$HOME/.config/fontconfig/.fonts.conf" 2>/dev/null|wc -l` -eq 0 ]; then
  if [ ! -d "$HOME/.config" ]; then
    mkdir "$HOME/.config"
  fi
  if [ ! -d "$HOME/.config/fontconfig" ]; then
    mkdir "$HOME/.config/fontconfig"
  fi
  echo $FN_PATH > "$HOME/.config/fontconfig/.fonts.conf"
fi
chmod 644 "$HOME/.config/fontconfig/.fonts.conf"
# no, no, it issues this error: 
# Fontconfig warning: "/opt/freeware/etc/fonts/conf.d/50-user.conf", line 9: reading configurations from ~/.fonts.conf is deprecated.
#if [ ! -f "$HOME/.fonts.conf" ]; then
#  echo $FN_PATH > "$HOME/.fonts.conf"
#  chmod 644 "$HOME/.fonts.conf"
#fi

# for web server user home
if [ ! -d "$HOMELPAR/tmp/home" ]; then
  mkdir "$HOMELPAR/tmp/home"
fi
#if [ ! -f "$HOMELPAR/tmp/home/.fonts.conf" ]; then
#  echo $FN_PATH > "$HOMELPAR/tmp/home/.fonts.conf"
#fi
if [ ! -d "$HOMELPAR/tmp/home/.config" ]; then
  mkdir "$HOMELPAR/tmp/home/.config" 2>/dev/null
  if [ ! $? -eq 0 ]; then
    # Once we saw tmp/home dir created and under apache user what is wrong, it is a workaround
    mv "$HOMELPAR/tmp/home" "$HOMELPAR/tmp/home.$$"
    mkdir "$HOMELPAR/tmp/home/"
    mkdir "$HOMELPAR/tmp/home/.config"
  fi
fi
if [ ! -d "$HOMELPAR/tmp/home/.config/fontconfig" ]; then
  mkdir "$HOMELPAR/tmp/home/.config/fontconfig"
fi
if [ ! -f "$HOMELPAR/tmp/home/.config/fontconfig/fonts.conf" ]; then
  echo $FN_PATH > "$HOMELPAR/tmp/home/.config/fontconfig/fonts.conf"
fi
chmod 755 "$HOMELPAR/tmp/home"
chmod 755 "$HOMELPAR/tmp/home/.config"
chmod 755 "$HOMELPAR/tmp/home/.config/fontconfig"
chmod 644 "$HOMELPAR/tmp/home/.config/fontconfig/fonts.conf"

# Checking installed Perl modules
cd $HOMELPAR
. etc/stor2rrd.cfg; $PERL bin/perl_modules_check.pl $PERL
echo ""
cd - >/dev/null

# cleaning old *cmd files not used sinc 1.0
rm -f $HOMELPAR/tmp/*.cmd
rm -f $HOMELPAR/tmp/*.out

if [ $VER_ORG -lt 111 ]; then
  # set minimal_heartbeat to 1380sec (23minutes) same as is default for 1.00 version
  echo ""
  echo "Setting new RRDTool minimal_heartbeat, it might take a minute"
  for storage in $HOMELPAR/data/*
  do
    if [ ! -d "$storage" ]; then
      continue
    fi
    storage_base=`basename $storage`
    echo "Working for storage: $storage_base ..."
    stor_hb=1380
    if [ -f "$HOMELPAR/data/$storage_base/XIV" ]; then
      stor_hb=1980 # higher heartbeat for XIV
    fi
    for rrd in $storage/*/*rr*
    do
      for item in `rrdtool info $rrd|grep minimal_heartbeat| grep -v $stor_hb| sed -e 's/^.*\[//' -e 's/\].*$//'`
      do
        rrdtool tune $rrd --heartbeat $item:$stor_hb
      done
    done
  done
fi

# RRDTool version checking for graph zooming
rrd=`echo $RRD|sed 's/\\\//g'`
$rrd|grep graphv >/dev/null 2>&1
if [ $? -eq 1 -a  $COLLECTOR -eq 0 ]; then
  # suggest RRDTool upgrade
  echo ""
  rrd_version=`$rrd -v|head -1|awk '{print $2}'`
  echo "Condider RRDtool upgrade to version 1.3.5+ (actual one is $rrd_version)"
  echo "This will allow graph zooming: http://www.stor2rrd.com/zoom.html"
  echo ""
fi


# remove color files (in case there has been changed colors)
# necessary for < 1.00 ans 1.00 comes with new colors
if [ $VER_ORG -lt 100 ]; then
  rm -f $HOMELPAR/data/*/*/volumes.col
fi

# force to load DS8k configuration during next run
rm -f $HOMELPAR/tmp/*conf.tmp

# same for SVC
rm -f $HOMELPAR/data/*/*svcconf_*data  
rm -f $HOMELPAR/data/*/svc.config.backup.xml

# forces to run config for DS5K, use only for DS5K!!
for storage in $HOMELPAR/data/*
do
  if  [ -f "$storage/DS5K" ]; then
    rm -f "$storage/config.html"
  fi
done


if [ $VER_ORG -lt 106 ]; then
  # clean out DS8k POOL cmd files (due to new pool front-end data)
  rm -f $HOMELPAR/tmp/*/POOL-*.cmd
fi


if [ $VER_ORG -lt 112 ]; then
  # clean out /var/tmp where 1.09 created 0 sized files without removing them
  echo "Cleaning up ..."
  find /var/tmp -name  "*-*-*-[d,w,m,y]-web-[0-9]*.cmd" -exec rm -f {} \; 2>/dev/null
fi


if [ $os_linux -gt 0 -a  $COLLECTOR -eq 0 ]; then
  # LinuxSE warning
  SELINUX=`ps -ef | grep -i selinux| grep -v grep|wc -l`

  if [ "$SELINUX" -gt 0  ]; then
    GETENFORCE=`getenforce 2>/dev/null`
    if [ "$GETENFORCE" = "Enforcing" ]; then
      echo ""
      echo "Warning!!!!!"
      echo "SELINUX status is Enforcing, it might cause problem during Apache setup"
      echo "like this in Apache error_log: (13)Permission denied: access to /XXXX denied"
      echo ""
    fi
  fi
fi

# Refresh custom restriction after the upgrade
#rm -f $HOMELPAR/tmp/.custom-group/*.cmd
# remove custom cmd definitions to be sure that they are reinitiated after upgrade,
rm -f $HOMELPAR/tmp/custom-group/* 2>/dev/null

# refresh storage configuration files
rm -f $HOMELPAR/tmp/config-*.touch
rm -f $HOMELPAR/tmp/*conf_time
rm -f $HOMELPAR/tmp/*-check-vsan

# do that before ./bin/check_rrdtool.sh to can interupt it
if [ ! "$version_new"x = "x" ]; then
  echo $version_new >> $HOMELPAR/etc/version.txt
fi
echo "$HOMELPAR" > $HOME/.stor2rrd_home 2>/dev/null

echo ""
echo "Upgrade is done"
echo ""
echo "Wait about 15 - 20 minutes, to get fresh data from the storages"

if [ $COLLECTOR -eq 0 ]; then
  echo ""
  echo "Then build a new GUI:"
  echo ""
  echo "$ cd $HOMELPAR"
  echo "$ ./load.sh | tee logs/load.out-initial"
  echo ""
  echo "Wait for finishing of that, then refresh the GUI (Ctrl-F5)"
  echo ""
fi


if [ $COLLECTOR -eq 0 -a "$VM_IMAGE"x = "x" -a $check -eq 1 -a $VER_ORG -lt 120 ]; then
  # not for image so far, it might be too slow
  echo ""
  echo "Checking consistency of all RRDtool DB files, it might take a few minutes in a big environment"
  echo "You can leave it running or interupt it by Ctrl-C and start it whenever later on"
  echo "  just check out the results when it finishes"
  echo "cd $HOMELPAR; ./bin/check_rrdtool_stor2rrd.sh silent"
  cd $HOMELPAR
  ./bin/check_rrdtool_stor2rrd.sh silent
  cd - >/dev/null
fi





