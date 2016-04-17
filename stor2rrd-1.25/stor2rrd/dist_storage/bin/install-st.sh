#!/bin/ksh
#set -x

PATH=$PATH:/usr/bin:/bin
export PATH
umask 0022

if [ ! -d $WEBDIR ]; then
   echo "WEBDIR does not exist, supply it as the first parametr"
   exit 1
fi
if [ ! -d $INPUTDIR ]; then
   echo "Source does not exist, supply it as the second parametr"
   exit 1
fi
if [ ! -f $PERL ]; then
   echo "perl path is invalid, correct it and re-run the tool"
   exit 1
fi


type_amenu="A" # aggregated items under subsystem menu
type_lmenu="L" # item under subsystem
type_removed="R"
type_gmenu="G" # global menu
type_cmenu="C" # custom group menu
type_fmenu="F" # favourites menu
type_smenu="S" # subsystem menu
type_tmenu="T" # tail menu
type_hmenu="H" # storage menu
type_wmenu="W" # SAN switch  menu
type_xmenu="X" # capacity overview
type_xmenu="X" # capacity overview
type_version="O" # free(open)/full version (1/0)
type_qmenu="Q" # version

gmenu_created=0


if [ "$TMPDIR_STOR"x = "x" ]; then
  TMPDIR_STOR="$INPUTDIR/tmp"
fi
MENU_OUT=$TMPDIR_STOR/menu.txt-tmp
MENU_OUT_FINAL=$TMPDIR_STOR/menu.txt
rm -f $MENU_OUT



ALIAS_CFG="$INPUTDIR/etc/alias.cfg"
ALIAS=0
CGI_DIR="stor2rrd-cgi"
AGG_LIST="sum_io_total sum_data_totam sum_io sum_data io_rate data_rate sum_capacity real used read_io write_io read write cache_hit r_cache_hit w_cache_hit r_cache_usage w_cache_usage resp resp_t resp_t_r resp_t_w  read_io_b write_io_b read_b write_b resp_t_b resp_t_r_b resp_t_w_b sys compress tier0 tier1 tier2 pprc_rio pprc_wio pprc_data_r pprc_data_w pprc_rt_r pprc_rt_w read_pct top write_pend clean_usage middle_usage phys_usage operating_rate"
SUBSYSTEM_LIST="POOL RANK MDISK VOLUME DRIVE PORT CPU-NODE HOST CPU-CORE NODE-CACHE"
# avoid CPU-CORE on purpose
if [ -L "$INPUTDIR/data/$hmc/MDISK" ]; then 
  # SVC
  FIRST_GLOBAL="sum_io"
  FIRST_GLOBAL_SUB="MDISK"
  #FIRST="sum_data" # POOL, RANK
  #FIRST_SECOND="data_rate" # PORT
else
  if [ -L "$INPUTDIR/data/$hmc/DS5K" -o -L "$INPUTDIR/data/$hmc/HUS" -o -L "$INPUTDIR/data/$hmc/NETAPP" -o -L "$INPUTDIR/data/$hmc/3PAR" -o -L "$INPUTDIR/data/$hmc/VSPG" ]; then
    FIRST_GLOBAL="sum_io_total"
    FIRST_GLOBAL_SUB="POOL"
  else 
    # DS8K
    FIRST_GLOBAL="sum_io"
    FIRST_GLOBAL_SUB="RANK"
    #FIRST="read" # POOL, RANK
    #FIRST_SECOND="data_rate" # PORT
  fi
fi
TMPDIR_STOR=$INPUTDIR/tmp
INDEX=$INPUTDIR/html
pwd=`pwd`
TIME=`$PERL -e '$v = time(); print "$v\n"'`

if [ "$ACCOUTING"x = "x" ]; then
  ACCOUTING=0
fi

if [ $DEBUG ]; then echo "installing WWW : install-html.sh "; fi
if [ $DEBUG ]; then echo "Host identif   : $UNAME "; fi

if [ -f $BINDIR/premium.sh ]; then
  . $BINDIR/premium.sh
fi

if [ -f "$ALIAS_CFG" ]; then 
  ALIAS=1
fi

# create skeleton of menu
menu () {
  a_type=$1
  a_hmc=`echo "$2"|sed 's/:/===double-col===/g'`
  a_server=`echo "$3"|sed 's/:/===double-col===/g'`
  a_lpar=`echo "$4"|sed 's/:/===double-col===/g'`
  a_text=`echo "$5"|sed 's/:/===double-col===/g'`
  a_url=`echo "$6"|sed -e 's/:/===double-col===/g' -e 's/ /%20/g'`
  a_lpar_wpar=`echo "$7"|sed 's/:/===double-col===/g'` # lpar name when wpar is passing
  a_last_time=$8


  #if [ ! "$LPARS_EXCLUDE"x = "x" -a `echo "$4"|egrep "$LPARS_EXCLUDE"|wc -l|sed 's/ //g'` -eq 1 ]; then
  #  # excluding some LPARs based on a string : LPARS_EXCLUDE --> etc/.magic
  #  echo "lpar exclude   : $2:$2:$4 - exclude string: $LPARS_EXCLUDE"
  #  return 1
  #fi

  if [ "$a_type" = "$type_gmenu" -a $gmenu_created -eq 1 ]; then
    return # print global menu once
  fi

  echo "$a_type:$a_hmc:$a_server:$a_lpar:$a_text:$a_url:$a_lpar_wpar:$a_last_time" >> $MENU_OUT

}

# create custm group list
custom_group() {
  CUSTOM_CFG="$INPUTDIR/etc/web_config/custom_groups.cfg"
  if [ -f "$CUSTOM_CFG" ]; then
    for line_space in `egrep -v "#" $CUSTOM_CFG 2>/dev/null|sed -e 's/ *$//g' -e 's/\\\:/===colon===/g' |cut -d : -f 1,4|sed -e 's/===colon===/\:/g' -e 's/ *$//g' -e 's/ /=====space=====/g'|sort|uniq`
    do
      line=`echo $line_space|sed 's/=====space=====/ /g'`
      cgroup=`echo "$line"|cut -d : -f 2`
      cgroup_space=`echo "$line"|cut -d : -f 2|sed 's/ /%20/g'`
      type=`echo "$line"| cut -d : -f 1`
      if [ "$cgroup"x = "x" -o "$type"x = "x" ]; then
        echo "error cgroup   : $type_cmenu : CUSTOM GROUPS : $type:$cgroup : something is null: $line, skipping" 
        continue
      fi
      if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_cmenu : CUSTOM GROUPS : $type:$cgroup"; fi
      menu "$type_cmenu" "$cgroup_space" "$cgroup" "/$CGI_DIR/detail.sh?host=custom-group&type=$type&name=$cgroup_space&storage=na&item=custom&gui=1&none=none"
    done
  fi
}

print_voltop () {

echo "<div  id=\"tabs\"> <ul>"
if [ -f "$WEBDIR/glob-VOLUME-top-avrg-d.html-tmp" ]; then
  mv "$WEBDIR/glob-VOLUME-top-avrg-d.html-tmp" "$WEBDIR/glob-VOLUME-top-avrg-d.html"
  echo "</tbody></table>" >> "$WEBDIR/glob-VOLUME-top-avrg-d.html"
  echo  "<li><a href=\"glob-VOLUME-top-avrg-d.html\">Daily</a></li>"
fi
if [ -f "$WEBDIR/glob-VOLUME-top-avrg-w.html-tmp" ]; then
  mv "$WEBDIR/glob-VOLUME-top-avrg-w.html-tmp" "$WEBDIR/glob-VOLUME-top-avrg-w.html"
  echo "</tbody></table>" >> "$WEBDIR/glob-VOLUME-top-avrg-w.html"
  echo  "<li><a href=\"glob-VOLUME-top-avrg-w.html\">Weekly</a></li>"
fi
if [ -f "$WEBDIR/glob-VOLUME-top-avrg-m.html-tmp" ]; then
  mv "$WEBDIR/glob-VOLUME-top-avrg-m.html-tmp" "$WEBDIR/glob-VOLUME-top-avrg-m.html"
  echo "</tbody></table>" >> "$WEBDIR/glob-VOLUME-top-avrg-m.html"
  echo  "<li><a href=\"glob-VOLUME-top-avrg-m.html\">Monthly</a></li>"
fi
if [ -f "$WEBDIR/glob-VOLUME-top-max-d.html-tmp" ]; then
  mv "$WEBDIR/glob-VOLUME-top-max-d.html-tmp" "$WEBDIR/glob-VOLUME-top-max-d.html"
  echo "</tbody></table>" >> "$WEBDIR/glob-VOLUME-top-max-d.html"
  echo  "<li><a href=\"glob-VOLUME-top-max-d.html\">Daily max</a></li>"
fi
if [ -f "$WEBDIR/glob-VOLUME-top-max-w.html-tmp" ]; then
  mv "$WEBDIR/glob-VOLUME-top-max-w.html-tmp" "$WEBDIR/glob-VOLUME-top-max-w.html"
  echo "</tbody></table>" >> "$WEBDIR/glob-VOLUME-top-max-w.html"
  echo  "<li><a href=\"glob-VOLUME-top-max-w.html\">Weekly max</a></li>"
fi
if [ -f "$WEBDIR/glob-VOLUME-top-max-m.html-tmp" ]; then
  mv "$WEBDIR/glob-VOLUME-top-max-m.html-tmp" "$WEBDIR/glob-VOLUME-top-max-m.html"
  echo "</tbody></table>" >> "$WEBDIR/glob-VOLUME-top-max-m.html"
  echo  "<li><a href=\"glob-VOLUME-top-max-m.html\">Monthly max</a></li>"
fi
echo "   </ul> </div>"
}


#
# real start of the script
#

if [ -f "$WEBDIR/glob-VOLUME-top-avrg-d.html-tmp" ]; then
  print_voltop > "$WEBDIR/glob-volumes-top.html"
fi

if [ -f $INPUTDIR/bin/premium.pl ]; then # BINDIR cannot be used here as it is relative
  menu "$type_version" "0" "" "" "" "" ""
else
  menu "$type_version" "1" "" "" "" "" ""
fi

if [ $UPGRADE -eq 0 ]; then
  if [ ! -f $TMPDIR_STOR/$version-run ]; then
    if [ $DEBUG -eq 1 ]; then echo "Apparently nothing new, install_html.sh exiting"; fi
    exit 0
  else
    if [ $DEBUG -eq 1 ]; then echo "Apparently some changes in the env, install_html.sh continuing"; fi
  fi
else
  if [ $DEBUG -eq 1 ]; then echo "Looks like there was an upgrade, re-newing web pages"; fi
  touch $TMPDIR_STOR/$version
fi

version_act=$version
if [ -f $INPUTDIR/etc/version.txt ]; then
  # actually installed version include patch level (in $version is not patch level)
  version_act=`cat $INPUTDIR/etc/version.txt|tail -1`
fi
menu "$type_qmenu" "$version_act"

cp "$INPUTDIR/html/not_implemented.html" "$WEBDIR/" 

if [ ! -f "$WEBDIR/gui-help.html" ]; then
  # copy of help file
  cp "$INPUTDIR/html/gui-help.html" "$WEBDIR/" 
fi
if [ $UPGRADE -eq 1 ]; then
  cp "$INPUTDIR/html/gui-help.html" "$WEBDIR/"
fi


if [ $UPGRADE -eq 1 -o ! -f "$WEBDIR/hist_reports.html" -o ! -f $INPUTDIR/html/noscript.html -o ! -f $INPUTDIR/html/wipecookies.html -o ! -f "$WEBDIR/index.html" -o ! -f "$WEBDIR/gui-help.html" -o ! -f "$WEBDIR/hist_reports.html" -o ! -f "$WEBDIR/dashboard.html" ]; then
  cp "$INPUTDIR/html/dashboard.html" "$WEBDIR/"
  cp "$INPUTDIR/html/gui-help.html" "$WEBDIR/"
  cp "$INPUTDIR/html/index.html" "$WEBDIR/"
  cp "$INPUTDIR/html/wipecookies.html" "$WEBDIR/"
  cp "$INPUTDIR/html/noscript.html" "$WEBDIR/"
  cp "$INPUTDIR/html/hist_reports.html" "$WEBDIR/"
  cp "$INPUTDIR/html/test.html" "$WEBDIR/"
  cp "$INPUTDIR/html/robots.txt" "$WEBDIR/"
  cp "$INPUTDIR/html/favicon.ico" "$WEBDIR/"
fi

if [ ! -d "$WEBDIR/jquery" -o $UPGRADE -eq 1 -o ! -d "$WEBDIR/css" ]; then
  cd $INPUTDIR/html
  tar cf - jquery | (cd $WEBDIR ; tar xf - )
  cd - >/dev/null
fi

if [ ! -d "$WEBDIR/css" -o $UPGRADE -eq 1 ]; then
  cd $INPUTDIR/html
  tar cf - css | (cd $WEBDIR ; tar xf - )
  cd - >/dev/null
fi

#
# Main section
#


# workaround for sorting 
HLIST=`for m in $INPUTDIR/data/*; do echo "$m"|sed 's/ /====spacce====/g'; done|sort -fr|xargs -n 1024`
for dir1 in $HLIST
do

  # workaround for managed names with a space inside
  dir1_space=`echo "$dir1"|sed 's/====spacce====/ /g'`
  hmc=`basename "$dir1_space"`
  # exclude sym links 
  if [ -L "$dir1" ]; then
    continue
  fi

  if [ ! -d "$dir1" ]; then
    continue
  fi

  configured=`egrep "^$hmc:" $INPUTDIR/etc/storage-list.cfg|sed 's/^ *//g'|wc -l|sed 's/ //g'`
  if [ $configured -eq 0 ]; then
    # already unconfigured, then skip it
    continue
  fi

  st_type="DS8K"
  if [ -f "$INPUTDIR/data/$hmc/SWIZ" ]; then
    st_type="SWIZ"
  fi
  if [ -f "$INPUTDIR/data/$hmc/XIV" ]; then
    st_type="XIV"
  fi
  if [ -f "$INPUTDIR/data/$hmc/DS5K" ]; then
    st_type="DS5K"
  fi
  if [ -f "$INPUTDIR/data/$hmc/HUS" ]; then
    st_type="HUS"
  fi
  if [ -f "$INPUTDIR/data/$hmc/NETAPP" ]; then
    st_type="NETAPP"
  fi
  if [ -f "$INPUTDIR/data/$hmc/3PAR" ]; then
    st_type="3PAR"
  fi
  if [ -f "$INPUTDIR/data/$hmc/VSPG" ]; then
    st_type="VSPG"
  fi



  if [ $gmenu_created -eq 0 ]; then
    if [ $ACCOUTING -eq 1 ]; then # accounting for DHL
      if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_gmenu : Accounting "; fi
      menu "$type_gmenu" "accounting" "Accounting" "/$CGI_DIR/acc.sh?sort=server"
    fi

    if [ `ls -l $INPUTDIR/data/*/DS5K 2>/dev/null| wc -l| sed 's/ //g'` -gt 0 -o `ls -l $INPUTDIR/data/*/SAN-* 2>/dev/null| wc -l| sed 's/ //g'` -gt 0 -o `ls -l $INPUTDIR/data/*/HUS 2>/dev/null| wc -l| sed 's/ //g'` -gt 0 -o `ls -l $INPUTDIR/data/*/3PAR 2>/dev/null| wc -l| sed 's/ //g'` -gt 0 ]; then
      # Global health status
      # only for SAN switches and DS5K so far (1.20)
      if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_gmenu : HEALTH STATUS"; fi
      menu "$type_gmenu" "glob_hs" "HEALTH STATUS" "/$CGI_DIR/glob_hs.sh"
    fi

    if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_gmenu : Capacity"; fi
    menu "$type_gmenu" "capacity" "Capacity"  "capacity.html"

    if [ -f "$WEBDIR/glob-volumes-top.html" ]; then
      if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_gmenu : Global Volumes TOP"; fi
      menu "$type_gmenu" "voltop" "Volumes TOP"  "glob-volumes-top.html"
    fi

    if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_gmenu : Alerting configuration"; fi
    menu "$type_gmenu" "alerting" "Alerting configuration"  "/$CGI_DIR/alcfg.sh"

    if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_gmenu : CUSTOM GROUPS"; fi
    menu "$type_gmenu" "cgroups" "CUSTOM GROUPS" "whatever"
    gmenu_created=1 # it will not print global menu items

    # add Custom groups
    if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_cmenu : CUSTOM GROUPS : Configuration"; fi
    menu "$type_cmenu" "group_config" "<b>Configuration</b>" "/$CGI_DIR/cgrps.sh"
    custom_group # print custom group list
  fi
  if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_hmenu : $hmc"; fi
  menu "$type_hmenu" "$hmc" 
  if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_hmenu : $hmc Configuration"; fi
  menu "$type_hmenu" "$hmc" "Configuration" "$hmc/gui-config-detail.html"
  #menu "$type_hmenu" "$hmc" "Historical reports" "hist_reports.html"







  if [ $DEBUG -eq 1 -a $st_type = "HUS" -o $st_type = "VSPG" ]; then
    echo "adding to menu : $type_hmenu : $hmc Mapping"
    menu "$type_hmenu" "$hmc" "Mapping" "$hmc/mapping.html"
  fi


  # Historical report form are different per each storage type
  hreport_form="hist_reports-$st_type.html"
  if [ ! -f "$INPUTDIR/html/$hreport_form" ]; then
    hreport_form="hist_reports.html"
  fi
  if [ "$st_type" = "DS5K" ]; then
    hreport_form="hist_reports-$st_type-v1.html"
    if [ -f "$INPUTDIR/data/$hmc/DS5K-v2" ]; then
      hreport_form="hist_reports-$st_type-v2.html"
    fi
  fi
  menu "$type_hmenu" "$hmc" "Historical reports" "$hreport_form"
  if [ $UPGRADE -eq 1 -o ! -f "$WEBDIR/$hreport_form" ]; then
    cp "$INPUTDIR/html/$hreport_form" "$WEBDIR"
  fi
  if [ "$st_type" = "DS5K"  -o "$st_type" = "HUS" -o "$st_type" = "3PAR" ]; then
    health_status="health_status.html"
    if [ -f "$WEBDIR/$hmc/$health_status" ]; then
      menu "$type_hmenu" "$hmc" "Health status" "$hmc/$health_status"
    fi
  fi

  # capacity overview for selected storage platforms
  if [ "$st_type" = "3PAR" -o "$st_type" = "NETAPP" -o "$st_type" = "HUS" -o "$st_type" = "DS5K" -o "$st_type" = "SWIZ" -o "$st_type" = "DS8K" -o "$st_type" = "XIV" -o "$st_type" = "VSPG" ]; then
      menu "$type_xmenu" "$hmc" "POOL" "" "" "" "/$CGI_DIR/detail-graph.sh?host=$hmc&type=POOL&name=cap_total&item=sum&time=d"
  fi



  for subs in $SUBSYSTEM_LIST
  do
    cd $INPUTDIR/data/"$hmc" 

    if [ ! -d "$subs" -o -L "$subs" ]; then
      continue
    fi


    # workaround for managed names with a space inside
    #dir2_space=`echo "$dir2"|sed 's/====spacce====/ /g'`
    #managedname=`basename "$dir2_space"`
    managedname=$subs

    if [ "$managedname" = "iostats" -o "$managedname" = "tmp" ]; then
      continue
    fi

    if [ `echo "$SUBSYSTEM_LIST" | egrep " $managedname|$managedname "|wc -l|sed 's/ //g'` -eq 0 ]; then
      continue
    fi

    managedname_head=$managedname

    if [ -f "$INPUTDIR/data/$hmc/SWIZ"  -a "$managedname" = "RANK" ]; then 
      managedname_head="Managed&nbsp;disk"
    fi

    if [ -f "$INPUTDIR/data/$hmc/3PAR" -a "$managedname" = "RANK" ]; then 
      managedname_head="RAID&nbsp;GROUP"
    fi

    if [ -f "$INPUTDIR/data/$hmc/HUS" -a "$managedname" = "RANK" ]; then 
      managedname_head="RAID&nbsp;GROUP"
    fi

    if [ -f "$INPUTDIR/data/$hmc/VSPG" -a "$managedname" = "RANK" ]; then
      managedname_head="RAID&nbsp;GROUP"
    fi

    if [ -f "$INPUTDIR/data/$hmc/NETAPP" -a "$managedname" = "RANK" ]; then
      managedname_head="RAID&nbsp;GROUP"
    fi

    if [ -f "$INPUTDIR/data/$hmc/SWIZ"  -a "$managedname" = "CPU-CORE" ]; then 
      # avoid CPU_CORE for SVC
      continue
    fi

    if [ "$managedname" = "CPU-NODE" ]; then 
      managedname_head="CPU&nbsp;util"
    fi
    if [ "$managedname" = "CPU-CORE" ]; then 
      managedname_head="CPU&nbsp;util"
    fi
    if [ "$managedname" = "NODE-CACHE" ]; then 
      managedname_head="CACHE"
    fi
    if [ "$managedname" = "NODE-CACHE" -a ! -f "$INPUTDIR/data/$hmc/HUS" ]; then 
      continue # NODE-CACHE only for HUS
    fi


    drive_exist=`ls -l $INPUTDIR/data/$hmc/DRIVE/*rr* 2>/dev/null|wc -l|sed 's/ //g'`
    nnodecache_exist=`ls -l $INPUTDIR/data/$hmc/NODE-CACHE/*rr* 2>/dev/null|wc -l|sed 's/ //g'`

    # workaround for sorting 
    # here must be a list with predefined sorting and then check if it exist
    for managed1base in $SUBSYSTEM_LIST
    do
      if [ ! -d "../$managed1base" -o -L "../$managed1base" ]; then
        continue # exclude other stuff
      fi

      managed1base_head=$managed1base
      if [ -f "$INPUTDIR/data/$hmc/SWIZ" -a "$managed1base" = "RANK" ]; then 
        managed1base_head="Managed&nbsp;disk"
      fi
      if [ -f "$INPUTDIR/data/$hmc/HUS" -a "$managed1base" = "RANK" ]; then 
        managed1base_head="RAID&nbsp;GROUP"
      fi
      if [ -f "$INPUTDIR/data/$hmc/VSPG" -a "$managedname" = "RANK" ]; then
      managedname_head="RAID&nbsp;GROUP"
      fi
      if [ -f "$INPUTDIR/data/$hmc/3PAR" -a "$managed1base" = "RANK" ]; then 
        managed1base_head="RAID&nbsp;GROUP"
      fi
      if [ -f "$INPUTDIR/data/$hmc/NETAPP" -a "$managed1base" = "RANK" ]; then 
        managed1base_head="RAID&nbsp;GROUP"
      fi
      if [ "$managed1base" = "DRIVE" -a $drive_exist -eq 0 ]; then 
        continue  # SVC and DS8k do not have DRIVES stats
      fi
      if [ "$managed1base" = "CPU-NODE" ]; then 
        managed1base_head="CPU&nbsp;util"
      fi
      if [ "$managed1base" = "CPU-CORE" ]; then 
        managed1base_head="CPU&nbsp;util"
      fi
      if [ "$managed1base" = "NODE-CACHE" -a $nnodecache_exist -gt 0 ]; then 
        managed1base_head="CACHE"
      fi
    done

    if [ "$managedname" = "DRIVE" -a $drive_exist -eq 0 ]; then 
      continue  # SVC and DS8k do not have DRIVES stats
    fi
    if [ "$managedname" = "NODE-CACHE" -a $nnodecache_exist -eq 0 ]; then 
      continue  # 
    fi

    if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_smenu : $hmc $managedname_head"; fi
    menu "$type_smenu" "$hmc" "$managedname_head" 

    c_io=0
    c_data=0
    c_resp=0
    c_capacity=0
    c_cache=0
    c_cache_node=0 # HUS
    c_sys=0
    c_pprc=0
    c_top=0
    c_operating=0

    for lpar in $AGG_LIST
    do
      if [ "$managedname" = "HOST" ]; then  
        break # HOST does not have aggregates
      fi
      item_sum="sum"
      if [ -f "$TMPDIR_STOR/$hmc/$managedname-$lpar-d.cmd" ]; then
        if [ "$lpar" = "resp" -o "$lpar" = "resp_t" -o "$lpar" = "resp_t_r" -o "$lpar" = "resp_t_w" -o "$lpar" = "resp_t_r_b" -o "$lpar" = "resp_t_w_b" ]; then
          if [ $c_resp -gt 0 ]; then  
            continue
          fi
          (( c_resp = c_resp + 1 ))
          lpar_name="Response time"
          lpar="resp"
        fi
        if [ "$lpar" = "sum_io_total" -o "$lpar" = "sum_io" -o "$lpar" = "io" -o "$lpar" = "io_rate" -o "$lpar" = "read_io" -o "$lpar" = "write_io" -o "$lpar" = "read_io_b" -o "$lpar" = "write_io_b" ]; then
          if [ $c_io -gt 0 ]; then  
            continue
          fi
          (( c_io = c_io + 1 ))
          lpar_name="IO"  
          lpar="io"
        fi
        if [ "$lpar" = "sum_data_total" -o "$lpar" = "sum_data" -o "$lpar" = "data" -o "$lpar" = "data_rate" -o "$lpar" = "read" -o "$lpar" = "write" -o "$lpar" = "read_b" -o "$lpar" = "write_b" ]; then
          if [ $c_data -gt 0 ]; then  
            continue
          fi
          (( c_data = c_data + 1 ))
          lpar_name="Data"
          lpar="data"
        fi
        if [ "$lpar" = "phys_usage" -o "$lpar" = "middle_usage" -o "$lpar" = "clean_usage" -o "$lpar" = "write_pend" ]; then
          if [ $c_cache_node -gt 0 ]; then  
            continue
          fi
          (( c_cache_node = c_cache_node + 1 ))
          lpar_name="Total"
          lpar="cache-node"
        fi
        if [ "$lpar" = "operating_rate" ]; then
          if [ $c_operating -gt 0 ]; then  
            continue
          fi
          (( c_operating = c_operating + 1 ))
          lpar_name="Operating"
          lpar="operating"
        fi
        if [ "$lpar" = "sys" -o "$lpar" = "compress" ]; then
          if [ $c_sys -gt 0 ]; then  
            continue
          fi
          (( c_sys = c_sys + 1 ))
          lpar_name="Total"
          lpar="cpu"
        fi
        if [ "$lpar" = "sum_capacity" -o "$lpar" = "used" -o "$lpar" = "real" -o "$lpar" = "tier0" -o "$lpar" = "tier2" -o "$lpar" = "tier1" ]; then
          if [ $c_capacity -gt 0 ]; then  
            continue
          fi
          (( c_capacity = c_capacity + 1 ))
          lpar_name="Capacity"
          lpar="cap"
        fi
        if [ "$lpar" = "cache_hit" -o "$lpar" = "read_pct" -o "$lpar" = "r_cache_usage" -o "$lpar" = "w_cache_usage" -o "$lpar" = "r_cache_hit" -o "$lpar" = "w_cache_hit" ]; then
          if [ $c_cache -gt 0 ]; then  
            continue
          fi
          (( c_cache = c_cache + 1 ))
          lpar_name="Cache"
          lpar="cache"
        fi
        if [ "$lpar" = "pprc_rio" -o "$lpar" = "pprc_wio" -o "$lpar" = "pprc_data_r" -o "$lpar" = "pprc_data_w" -o "$lpar" = "pprc_rt_r" -o "$lpar" = "pprc_rt_w" ]; then
          if [ $c_pprc -gt 0 ]; then  
            continue
          fi
          (( c_pprc = c_pprc + 1 ))
          lpar_name="PPRC"
          lpar="pprc"
        fi
        if [ "$lpar" = "top" ]; then
          if [ $c_top  -gt 0 ]; then  
            continue
          fi
          (( c_top  = c_top  + 1 ))
          lpar_name="Top"
          lpar="top"
          item_sum="all"
        fi
        menu "$type_amenu" "$hmc" "$managedname_head" "$lpar" "$lpar_name" "/$CGI_DIR/detail.sh?host=$hmc&type=$managedname&name=$lpar&storage=$st_type&item=$item_sum&gui=1&none=none"
      fi
    done

    managed1base_head=$managedname 
    if [ -f "$INPUTDIR/data/$hmc/SWIZ" -a "$managedname" = "RANK" ]; then 
      # for SWIZ
      managed1base_head="Managed&nbsp;disk"
    fi
    if [ -f "$INPUTDIR/data/$hmc/HUS" -a "$managedname" = "RANK" ]; then 
      managed1base_head="RAID&nbsp;GROUP"
    fi
    if [ -f "$INPUTDIR/data/$hmc/3PAR" -a "$managedname" = "RANK" ]; then 
      managed1base_head="RAID&nbsp;GROUP"
    fi
    if [ -f "$INPUTDIR/data/$hmc/VSPG" -a "$managedname" = "RANK" ]; then
      managed1base_head="RAID&nbsp;GROUP"
    fi
    if [ -f "$INPUTDIR/data/$hmc/NETAPP" -a "$managedname" = "RANK" ]; then
      managed1base_head="RAID&nbsp;GROUP"
    fi
    if [ "$managedname" = "CPU-NODE" ]; then 
      managed1base_head="CPU&nbsp;util"
    fi
    if [ "$managedname" = "CPU-CORE" ]; then 
      managed1base_head="CPU&nbsp;util"
    fi
    if [ "$managedname" = "NODE-CACHE" ]; then 
      managed1base_head="CACHE"
    fi

    #
    # Hosts
    if [ "$managedname" = "HOST" -a -f "$INPUTDIR/data/$hmc/HOST/hosts.cfg" ]; then
      for host_space in `cut -f1 -d ":" "$INPUTDIR/data/$hmc/HOST/hosts.cfg"| sed -e 's/ $//' -e 's/ /+===============+/g'| sort -fn `
      do
        host=`echo "$host_space" | sed 's/+===============+/ /g'`
        host_url=`$PERL -e '$s=shift;$s=~s/ /+/g;;$s=~s/([^A-Za-z0-9\+-])/sprintf("%%%02X",ord($1))/seg;print "$s\n";' "$host"`
        if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_amenu : $hmc:$managedname:$host_url - $host"; fi
        menu "$type_amenu" "$hmc" "$managed1base_head" "$host" "$host" "/$CGI_DIR/detail.sh?host=$hmc&type=$managedname&name=$host_url&storage=$st_type&item=host&gui=1&none=none"
      done
    fi


    #
    # Volumes
    if [ "$managedname" = "VOLUME" ]; then
     # special loop per volumes as there will not be volumes in menu just volumes grouped per nicks
     if [ ! -f "$INPUTDIR/data/$hmc/$managedname/volumes.cfg" ]; then
        if [ $DEBUG -eq 1 ]; then echo "volume no exist: $hmc:$managedname:$INPUTDIR/data/$hmc/$managedname/volumes.cfg "; fi
        continue # volumes stats do not exist there, at least cfg file
     fi
     for ii_space in `awk -F: '{print $1}' "$INPUTDIR/data/$hmc/$managedname/volumes.cfg"|sed -e 's/ $//' -e 's/ /+===============+/g'| sort -fn `
     do
       ii=`echo "$ii_space" | sed 's/+===============+/ /g'`
       ii_url=`$PERL -e '$s=shift;$s=~s/ /+/g;;$s=~s/([^A-Za-z0-9\+-])/sprintf("%%%02X",ord($1))/seg;print "$s\n";' "$ii"`
       #ii_url=`echo $ii| sed -e 's/%\([0-9A-F][0-9A-F]\)/\\\\\x\1/g'`
       al=`egrep "^$managedname:$hmc:$ii:" $ALIAS_CFG 2>/dev/null|awk -F: '{print $4}'`
       if [ ! "$al"x =  "x" ]; then
         if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_lmenu : $hmc:$managedname:$ii_url - $ii - alias: $al"; fi
         menu "$type_lmenu" "$hmc" "$managed1base_head" "$ii" "$al" "/$CGI_DIR/detail.sh?host=$hmc&type=$managedname&name=$ii_url&storage=$st_type&item=lpar&gui=1&none=none"
       else
         if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_lmenu : $hmc:$managedname:$ii_url - $ii"; fi
         menu "$type_lmenu" "$hmc" "$managed1base_head" "$ii" "$ii" "/$CGI_DIR/detail.sh?host=$hmc&type=$managedname&name=$ii_url&storage=$st_type&item=lpar&gui=1&none=none"
       fi
     done

    else

      #
      # POOLs
      if [ "$managedname" = "POOL" ]; then
        pwd=`pwd`
        if [ "$st_type" = "XIV" -o "$st_type" = "DS5K" ]; then
          cd  $INPUTDIR/data/$hmc/VOLUME # XIV has pools in Volumes
        else 
          if [ "$st_type" = "HUS" -o "$st_type" = "NETAPP" -o "$st_type" = "VSPG" ]; then
            cd  $INPUTDIR/data/$hmc/POOL # HUS has pools in POOLs
          else
            cd  $INPUTDIR/data/$hmc/RANK # 3PAR
          fi
        fi

        for i in `find . -print |egrep "\.rrd$"|sed -e 's/\.\///g' -e 's/\.rrd//' -e 's/^.*-P//g'|sort -fn|uniq`
        do
         menu_type_def="$type_lmenu"
         cd $pwd
           if [ $ALIAS -eq 1 ]; then
             al=`egrep "^$managedname:$hmc:$i:" $ALIAS_CFG|awk -F: '{print $4}'`
             #echo "003: $managedname:$hmc:$i: - $al"
             if [ ! "$al"x =  "x" ]; then
               if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_lmenu : $hmc:$managedname:$i - alias: $al"; fi
               menu "$type_lmenu" "$hmc" "$managed1base_head" "$i" "$al" "/$CGI_DIR/detail.sh?host=$hmc&type=$managedname&name=$i&storage=$st_type&item=lpar&gui=1&none=none"
             else 
               name=$i
               # translate index into name
               if [ -f "$INPUTDIR/data/$hmc/pool.cfg" ]; then
                 name=`egrep "^$i:" "$INPUTDIR/data/$hmc/pool.cfg"|awk -F: '{print $2}'`
                 if [ "$name"x = "x" ]; then
                   # name has not been found --> looks like an old POOL
	           name="$i"
                   menu_type_def="$type_removed" # place into removed menu
                 fi
               fi
               if [ $DEBUG -eq 1 ]; then echo "adding to menu : $menu_type_def : $hmc:$managedname:$i - $name"; fi
               menu "$menu_type_def" "$hmc" "$managed1base_head" "$i" "$name" "/$CGI_DIR/detail.sh?host=$hmc&type=$managedname&name=$i&storage=$st_type&item=lpar&gui=1&none=none"
             fi
           else
             name=$i
             # translate index into name
             if [ -f "$INPUTDIR/data/$hmc/pool.cfg" ]; then
               name=`egrep "^$i:" "$INPUTDIR/data/$hmc/pool.cfg"|awk -F: '{print $2}'`
               if [ "$name"x = "x" ]; then
                 # name has not been found --> looks like an old POOL
	         name="$i"
                 menu_type_def="$type_removed" # place into removed menu
               fi
             fi
             if [ $DEBUG -eq 1 ]; then echo "adding to menu : $menu_type_def : $hmc:$managedname:$i "; fi
             menu "$menu_type_def" "$hmc" "$managed1base_head" "$i" "$name" "/$CGI_DIR/detail.sh?host=$hmc&type=$managedname&name=$i&storage=$st_type&item=lpar&gui=1&none=none"
           fi
        done
      else

        #
        # everything rest as PORT, RANKs, .... 
        pwd=`pwd`
        cd  $INPUTDIR/data/$hmc/$managedname
        for ii in `find . -print |egrep "\.rrd$"|sed -e 's/\.\///g' -e 's/\.rrd//'|sed "s/-/ /g" | sort -n -k1 -k2 | sed "s/ /-/g"`  # trick for sorting 1-1 at the end
        do
         menu_type_def="$type_lmenu" 
         cd $pwd
         if [ "$managedname" = "RANK" -a ! -f "$INPUTDIR/data/$hmc/NETAPP" -a ! -f "$INPUTDIR/data/$hmc/HUS" -a ! -f "$INPUTDIR/data/$hmc/VSPG" ]; then 
           i_pool=`echo $ii|grep -- "-P"|wc -l|sed 's/ //g'`
           if [ $i_pool -eq 0 ]; then
             continue # it is something worng, could not found pool name
           fi
         fi
         if [ "$managedname" = "DRIVE" -a -f "$INPUTDIR/data/$hmc/NETAPP" -a -f "$INPUTDIR/data/$hmc/drive.cfg" ]; then 
           i=`egrep "^$ii," $INPUTDIR/data/$hmc/drive.cfg|awk -F, '{print $2}'`
         else 
           i=`echo $ii|sed 's/-P.*//'` # filter pool info for Ranks 
         fi
           if [ $ALIAS -eq 1 ]; then
             al=`egrep "^$managedname:$hmc:$i:" $ALIAS_CFG|awk -F: '{print $4}'`
             #echo "003: $managedname:$hmc:$i: - $al"
             if [ ! "$al"x =  "x" ]; then
               if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_lmenu : $hmc:$managedname:$ii - $i - alias: $al"; fi
               menu "$type_lmenu" "$hmc" "$managed1base_head" "$ii" "$al" "/$CGI_DIR/detail.sh?host=$hmc&type=$managedname&name=$ii&storage=$st_type&item=lpar&gui=1&none=none"
             else 
               name=$i
               # translate index into name for MDISK
               if [ -f "$INPUTDIR/data/$hmc/mdisk.cfg" -a $managedname = "RANK" ]; then
                 name=`egrep "^$i:" "$INPUTDIR/data/$hmc/mdisk.cfg"|awk -F: '{print $2}'`
                 if [ "$name"x = "x" ]; then
                   # name has not been found --> looks like an old RANK
	           name="$i"
                   menu_type_def="$type_removed" # place into removed menu
                 fi
               fi
               if [ $DEBUG -eq 1 ]; then echo "adding to menu : $menu_type_def : $hmc:$managedname:$ii - $i - $name"; fi
               menu "$menu_type_def" "$hmc" "$managed1base_head" "$ii" "$name" "/$CGI_DIR/detail.sh?host=$hmc&type=$managedname&name=$ii&storage=$st_type&item=lpar&gui=1&none=none"
             fi
           else
             name=$i
             # translate index into name for MDISK
             if [ -f "$INPUTDIR/data/$hmc/mdisk.cfg" -a $managedname = "RANK" ]; then
               name=`egrep "^$i:" "$INPUTDIR/data/$hmc/mdisk.cfg"|awk -F: '{print $2}'`
               if [ "$name"x = "x" ]; then
                 # name has not been found --> looks like an old RANK
	         name="$i"
                 menu_type_def="$type_removed" # place into removed menu
               fi
             fi
             if [ $DEBUG -eq 1 ]; then echo "adding to menu : $menu_type_def : $hmc:$managedname:$ii - $i "; fi
             menu "$menu_type_def" "$hmc" "$managed1base_head" "$ii" "$name" "/$CGI_DIR/detail.sh?host=$hmc&type=$managedname&name=$ii&storage=$st_type&item=lpar&gui=1&none=none"
           fi
        done
        cd $pwd
      fi
    fi
  done
done


# SAN
count_of_isl=`ls -l $INPUTDIR/data/*/ISL.txt 2>/dev/null| wc -l | sed -e 's/^[ \t]*//g;s/[ \t]*$//'`
count_of_switches=`ls -l $INPUTDIR/data/*/SAN-* 2>/dev/null| wc -l | sed -e 's/^[ \t]*//g;s/[ \t]*$//'`
if [ $count_of_switches -gt 1 ]; then
  menu "$type_wmenu" "Totals"
  if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_wmenu : Totals "; fi
  menu "$type_wmenu" "Totals" "Heatmap" "heatmap.html"
  if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_wmenu : Totals:Heatmap "; fi
  menu "$type_wmenu" "Totals" "Data" "/$CGI_DIR/detail.sh?host=totals&type=DATA&name=totals&storage=SAN-BRCD&item=san_data_sum_tot&gui=1&none=none"
  if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_wmenu : Totals:Data "; fi
  menu "$type_wmenu" "Totals" "Frame" "/$CGI_DIR/detail.sh?host=totals&type=IO&name=totals&storage=SAN-BRCD&item=san_io_sum_tot&gui=1&none=none"
  if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_wmenu : Totals:Frame "; fi
  menu "$type_wmenu" "Totals" "Fabric" "/$CGI_DIR/detail.sh?host=totals&type=IO&name=totals&storage=SAN-BRCD&item=san_fabric&gui=1&none=none"
  if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_wmenu : Totals:Fabric "; fi

  if [ $count_of_isl -gt 0 ]; then
    menu "$type_wmenu" "Totals" "ISL" "/$CGI_DIR/detail.sh?host=totals&type=ISL&name=totals&storage=SAN-BRCD&item=san_isl&gui=1&none=none"
    if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_wmenu : Totals:ISL "; fi
  fi

  menu "$type_wmenu" "Totals" "Health status" "total_health_status.html"
  if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_wmenu : Totals:Health status "; fi
  menu "$type_wmenu" "Totals" "Configuration" "san_configuration.html"
  if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_wmenu : Totals:Configuration "; fi
fi


# SAN - Brocade
# workaround for sorting 
HLIST=`for m in $INPUTDIR/data/*; do echo "$m"|sed 's/ /====spacce====/g'; done|sort -fr|xargs -n 1024`
for dir1 in $HLIST
do

  # workaround for managed names with a space inside
  dir1_space=`echo "$dir1"|sed 's/====spacce====/ /g'`
  hmc=`basename "$dir1_space"`
  # exclude sym links 
  if [ -L "$dir1" ]; then
    continue
  fi

  if [ ! -d "$dir1" ]; then
    continue
  fi

  #configured=`egrep "^$hmc:" $INPUTDIR/etc/san-list.cfg|sed 's/^ *//g'|wc -l|sed 's/ //g'`
  #if [ $configured -eq 0 ]; then
    # already unconfigured, then skip it
    #continue
  #fi


  if [ ! -f "$INPUTDIR/data/$hmc/SAN-BRCD" ]; then
    continue
  fi

  menu "$type_wmenu" "$hmc"
  if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_wmenu : $hmc "; fi

  menu "$type_wmenu" "$hmc" "Configuration" "$hmc/config.html"
  if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_wmenu : $hmc:Configuration "; fi

  menu "$type_wmenu" "$hmc" "Data" "/$CGI_DIR/detail.sh?host=$hmc&type=Data&name=$hmc&storage=SAN-BRCD&item=san_data_sum&gui=1&none=none"
  if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_wmenu : $hmc:Data "; fi
  menu "$type_wmenu" "$hmc" "Frame" "/$CGI_DIR/detail.sh?host=$hmc&type=Frame&name=$hmc&storage=SAN-BRCD&item=san_io_sum&gui=1&none=none"
  if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_wmenu : $hmc:Frame "; fi

  menu "$type_wmenu" "$hmc" "Health status" "$hmc/health_status.html"
  if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_wmenu : $hmc:Health status "; fi
  #menu "$type_hmenu" "$hmc" "Historical reports" "hist_reports.html"

  # Historical report form are different per each storage type
  #menu "$type_wmenu" "$hmc" "Historical reports" "$hreport_form"
  #if [ $UPGRADE -eq 1 -o ! -f "$WEBDIR/$hreport_form" ]; then
  #  cp "$INPUTDIR/html/$hreport_form" "$WEBDIR"
  #fi

  cd $INPUTDIR/data/"$hmc" 

  managedname="SANPORT"
  st_type=SAN-BRCD
  item=san

  if [ ! -f "$INPUTDIR/data/$hmc/PORTS.cfg" ]; then
    continue
  fi

  ports=`ls port*.rrd | sed "s/^port//g" | sort -n`

  for lpar in $ports
  do
    first_name=`echo port$lpar | sed -e "s/.rrd//g"`
    second_name=`grep "^$first_name :" "$INPUTDIR/data/$hmc/PORTS.cfg" | awk -F' : ' '{print $3}'`
    if [ -z "$second_name" ]; then
      lpar_name=$first_name
    else
      lpar_name="$first_name [$second_name]"
    fi
    name=`echo $lpar_name | sed -e "s/^port//g"`

    if [ $ALIAS -eq 1 ]; then
      lpar_n=`echo $first_name | sed -e "s/^port//g"`
      port_al=`egrep "^SANPORT:$hmc:$first_name:" $ALIAS_CFG|awk -F: '{print $4}'`
      port_al2=`egrep "^SANPORT:$hmc:$lpar_n:" $ALIAS_CFG|awk -F: '{print $4}'`
      if [ "$port_al"x = "x" ] && [ "$port_al2"x != "x" ]; then
        port_al="$port_al2"
      fi

      if [ ! "$port_al"x =  "x" ]; then
        menu "$type_lmenu" "$hmc" "$managedname" "$first_name" "$port_al" "/$CGI_DIR/detail.sh?host=$hmc&type=$managedname&name=$first_name&storage=$st_type&item=$item&gui=1&none=none"
        if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_lmenu : $hmc:$managedname:$first_name:$port_al "; fi
      else
        menu "$type_lmenu" "$hmc" "$managedname" "$first_name" "$name" "/$CGI_DIR/detail.sh?host=$hmc&type=$managedname&name=$first_name&storage=$st_type&item=$item&gui=1&none=none"
        if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_lmenu : $hmc:$managedname:$first_name "; fi
      fi
    else
      menu "$type_lmenu" "$hmc" "$managedname" "$first_name" "$name" "/$CGI_DIR/detail.sh?host=$hmc&type=$managedname&name=$first_name&storage=$st_type&item=$item&gui=1&none=none"
      if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_lmenu : $hmc:$managedname:$first_name "; fi
    fi
  done
done


# SAN - Cisco
# workaround for sorting 
HLIST=`for m in $INPUTDIR/data/*; do echo "$m"|sed 's/ /====spacce====/g'; done|sort -fr|xargs -n 1024`
for dir1 in $HLIST
do

  # workaround for managed names with a space inside
  dir1_space=`echo "$dir1"|sed 's/====spacce====/ /g'`
  hmc=`basename "$dir1_space"`
  # exclude sym links 
  if [ -L "$dir1" ]; then
    continue
  fi

  if [ ! -d "$dir1" ]; then
    continue
  fi

  #configured=`egrep "^$hmc:" $INPUTDIR/etc/san-list.cfg|sed 's/^ *//g'|wc -l|sed 's/ //g'`
  #if [ $configured -eq 0 ]; then
    # already unconfigured, then skip it
    #continue
  #fi

  if [ ! -f "$INPUTDIR/data/$hmc/SAN-CISCO" ]; then
    continue
  fi

  menu "$type_wmenu" "$hmc"
  if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_wmenu : $hmc "; fi

  menu "$type_wmenu" "$hmc" "Configuration" "$hmc/glob_config.html"
  if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_wmenu : $hmc:Configuration "; fi

  menu "$type_wmenu" "$hmc" "Data" "/$CGI_DIR/detail.sh?host=$hmc&type=Data&name=$hmc&storage=SAN-CISCO&item=san_data_sum&gui=1&none=none"
  if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_wmenu : $hmc:Data "; fi
  menu "$type_wmenu" "$hmc" "Frame" "/$CGI_DIR/detail.sh?host=$hmc&type=Frame&name=$hmc&storage=SAN-CISCO&item=san_io_sum&gui=1&none=none"
  if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_wmenu : $hmc:Frame "; fi

  menu "$type_wmenu" "$hmc" "Health status" "$hmc/health_status.html"
  if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_wmenu : $hmc:Health status "; fi
  #menu "$type_hmenu" "$hmc" "Historical reports" "hist_reports.html"

  # Historical report form are different per each storage type
  #menu "$type_wmenu" "$hmc" "Historical reports" "$hreport_form"
  #if [ $UPGRADE -eq 1 -o ! -f "$WEBDIR/$hreport_form" ]; then
  #  cp "$INPUTDIR/html/$hreport_form" "$WEBDIR"
  #fi

  cd $INPUTDIR/data/"$hmc" 

  managedname="SANPORT"
  st_type=SAN-CISCO
  item=san

  if [ ! -f "$INPUTDIR/data/$hmc/PORTS.cfg" ]; then
    continue
  fi

  #ports=`ls port*.rrd | sed "s/^port//g" | sort -n`
  #ports=`ls port*.rrd | sed "s/^port[a-zA-Z]*//g" | sed "s/-/ /g" | sort -n -k1 -k2 | sed "s/ /-/g"`

  ports=`ls port*.rrd | sed "s/^port\([a-zA-Z]*\)/\1 /g" \
        | sed "s/-/ /g" \
        | sed "s/^fc /111 /g" | sed "s/^Ethernet /222 /g" | sed "s/^GigabitEthernet /333 /g" | sed "s/^fcip /444 /g" | sed "s/^portChannel /555 /g" \
        | sort -n -k1 -k2 -k3 \
        | sed "s/^111 /fc/g" | sed "s/^222 /Ethernet/g" | sed "s/^333 /GigabitEthernet/g" | sed "s/^444 /fcip/g" | sed "s/^555 /portChannel/g" \
        | sed "s/ /-/g"`


  for lpar in $ports
  do
    first_name=`echo port$lpar | sed -e "s/.rrd//g"`
    second_name=`grep "^$first_name :" "$INPUTDIR/data/$hmc/PORTS.cfg" | awk -F' : ' '{print $3}'`
    if [ -z "$second_name" ]; then
      lpar_name=$first_name
    else
      lpar_name="$first_name [$second_name]"
    fi
    name=`echo $lpar_name | sed -e "s/^port//g"`

    if [ $ALIAS -eq 1 ]; then
      lpar_n=`echo $first_name | sed -e "s/^port//g"`
      port_al=`egrep "^SANPORT:$hmc:$first_name:" $ALIAS_CFG|awk -F: '{print $4}'`
      port_al2=`egrep "^SANPORT:$hmc:$lpar_n:" $ALIAS_CFG|awk -F: '{print $4}'`
      if [ "$port_al"x = "x" ] && [ "$port_al2"x != "x" ]; then
        port_al="$port_al2"
      fi

      if [ ! "$port_al"x =  "x" ]; then
        menu "$type_lmenu" "$hmc" "$managedname" "$first_name" "$port_al" "/$CGI_DIR/detail.sh?host=$hmc&type=$managedname&name=$first_name&storage=$st_type&item=$item&gui=1&none=none"
        if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_lmenu : $hmc:$managedname:$first_name:$port_al "; fi
      else
        menu "$type_lmenu" "$hmc" "$managedname" "$first_name" "$name" "/$CGI_DIR/detail.sh?host=$hmc&type=$managedname&name=$first_name&storage=$st_type&item=$item&gui=1&none=none"
        if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_lmenu : $hmc:$managedname:$first_name "; fi
      fi
    else
      menu "$type_lmenu" "$hmc" "$managedname" "$first_name" "$name" "/$CGI_DIR/detail.sh?host=$hmc&type=$managedname&name=$first_name&storage=$st_type&item=$item&gui=1&none=none"
      if [ $DEBUG -eq 1 ]; then echo "adding to menu : $type_lmenu : $hmc:$managedname:$first_name "; fi
    fi
  done
done


menu "$type_tmenu" "doc" "Documentation" "gui-help.html"
menu "$type_tmenu" "maincfg" "Main configuration cfg"  "/$CGI_DIR/log-cgi.sh?name=maincfg&gui=1"
# do not print storage/SAN configuration as there could be visible passowrds for XIV and DCS3700, it will be without passwords in 1.30+
#menu "$type_tmenu" "scfg" "Storage configuration"  "/$CGI_DIR/log-cgi.sh?name=stcfg&gui=1"
#menu "$type_tmenu" "sancfg" "SAN configuration"  "/$CGI_DIR/log-cgi.sh?name=sancfg&gui=1"
menu "$type_tmenu" "acfg" "Alias configuration" "/$CGI_DIR/log-cgi.sh?name=aliascfg&gui=1"
menu "$type_tmenu" "elog" "Error log" "/$CGI_DIR/log-cgi.sh?name=errlog&gui=1"
menu "$type_tmenu" "errcgi" "Error log cgi-bin" "/$CGI_DIR/log-cgi.sh?name=errcgi&gui=1"

if [ ! "$VI_IMAGE"x = "x" ]; then
  if [ $VI_IMAGE -eq 1 ]; then
    menu "$type_tmenu" "update" "Product upgrade" "/$CGI_DIR/upgrade.sh?cmd=form"
  fi
fi

cp $MENU_OUT $MENU_OUT_FINAL


df $INPUTDIR/data > $INPUTDIR/logs/sys.log 2>/dev/null
ls -l $INPUTDIR/bin >> $INPUTDIR/logs/sys.log 2>/dev/null
crontab -l >> $INPUTDIR/logs/sys.log 2>/dev/null


# back up GUI config files
cd $INPUTDIR/etc
if [ ! -d .web_config ]; then
  mkdir .web_config
fi
if [ ! -f .web_config/Readme.txt ]; then
  echo "here is backup of all modification in GUI configuration files done through the web" > .web_config/Readme.txt
fi

cfg_backup ()
{
  cfg_file=$1
  date_act=`date "+%Y-%m-%d_%H:%M"`
  if [ -f web_config/$cfg_file ]; then
    if [ ! -f .web_config/$cfg_file ]; then
      cp -p web_config/$cfg_file .web_config/$cfg_file
      cp -p web_config/$cfg_file .web_config/$cfg_file-$date_act
    else
      if [ `diff web_config/$cfg_file .web_config/$cfg_file 2>/dev/null| wc -l|sed 's/ //g'` -gt 0 ]; then
        cp -p web_config/$cfg_file .web_config/$cfg_file
        cp -p web_config/$cfg_file .web_config/$cfg_file-$date_act
      fi
    fi
  fi
}

cfg_backup custom_groups.cfg
cfg_backup alerting.cfg

rm -f $TMPDIR_STOR/$version-run
