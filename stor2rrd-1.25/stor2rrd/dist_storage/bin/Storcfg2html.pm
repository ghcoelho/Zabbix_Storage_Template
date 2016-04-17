package Storcfg2html;  #
use POSIX qw(strftime);

use strict;
my $upgrade=$ENV{UPGRADE};


sub cfg_ds8k {
  my ($host, $wrkdir, $webdir, $act_time, $DEBUG, $st_type) = @_;

  # exlucde $wrkdir/$host/config.html here, it is not really necessary
  if ( $st_type =~ /NETAPP/ ) {
    print "*********** Netapp config is not done yet\n";
    return 0;
  }
  if ( ! -f "$wrkdir/$host/pool.cfg" || ! -f "$wrkdir/$host/VOLUME/volumes.cfg" ) {
    main::error ("$host: Can't open one of storage core config files (fresh install?): $wrkdir/$host/pool.cfg || $wrkdir/$host/VOLUME/volumes.cfg");
    main::error ("$host: Wait for download config from the storage if it is just after new fresh install or newly added storage ".__FILE__.":".__LINE__) && return 2;
  }

  # runs that once a day
  my $file = "$wrkdir/../tmp/config-$host.touch";
  if ( -f "$file" && $upgrade == 0 ) {
    my $ret = once_a_day ($file);
    if ( $ret == 0 ) {
      print "creating cfg   : not this time - same day\n" if $DEBUG ;
      return 1;
    }
  }
  `touch "$file"`;
  print "creating cfg   : $host\n" if $DEBUG ;

  $file = "$wrkdir/$host/config.html";
  open(FCFGR, "< $file") || main::error ("$host: Can't open $file : $! : (ignore after fresh install) ".__FILE__.":".__LINE__) && return 0;

  # POOL capacity --> load translate table
  open(FHR, "< $wrkdir/$host/pool.cfg") || main::error ("$host: Can't open $wrkdir/$host/pool.cfg : $! ".__FILE__.":".__LINE__) && return 0;
  my @lines_translate = <FHR>;
  close(FHR);


  my $file_cfg_text = "$wrkdir/$host/config_sys_storage.txt";
  my @lines = <FCFGR>;
  my $rank_cfg_processing = 0;
  my $vol_cfg_processing = 0;
  my $port_cfg_processing = 0; 
  my $host_cfg_processing = 0; 
  my $pool_cfg_processing = 0; 
  my $system_cfg_processing = 0; 
  my $cfg_processing = 0; 
  my @rank_cfg_id = "";
  my @rank_detail = "";
  my @pool_cfg_id = "";
  my @pool_name_id = "";
  my @pool_detail = "";
  my @system_name = "";
  my @system_value = "";
  my $rank_cfg_indx = 0;
  my @pool_name = "";
  my $pool_name_indx = 0;
  my @vol_nicks = "";
  my @vol_id = "";
  my @vol_pool = "";
  my @port_list = "";
  my @port_detail = "";
  my @host_list = "";
  my @host_detail = "";
  my $t1 = "";
  my $t2 = "";
  my $t3 = "";
  my $t4 = "";
  my $t5 = "";
  my $t6 = "";
  my $t7 = "";
  my $t8 = "";
  my $t9 = "";
  my $t10 = "";
  my $t11 = "";
  my $t12 = "";
  my @lines_valid = "";
  my $found = 0;
  my $indx = 0;
  my $config_data_text = "";


  foreach my $line (@lines) {
    chomp ($line);

    if ( $line =~ m/^LD ID,LD name/ || $line =~ m/^CPG ID,CPG name/ || $line =~ m/^Volume ID,Volume name/ || $line =~ m/^,id,status/ ||  $line =~ m/^,,name,/ || $line =~ m/^,id,status,/ || $line =~ m/^lun_id,,/ || $line =~ m/html>/ || $line =~ m/^---/ || $line =~ /^Port ID/ || $line =~ /^Rank ID/ || $line =~ /^Volume ID/ || $line =~ /^mdisk_id,/ || $line =~ /^volume_id,/ || $line =~ /^drive_id,/ || $line =~ /^port_name,/ || $line =~ /^id,name,/ || $line =~ /^	/ ) {
      next; 
    }
    $line =~ s/^0x//;

    if ( $line =~ m/Configuration Data/ ) {
      $cfg_processing = 1;
      $indx = 0;
    }
    if  ( $cfg_processing == 1 ) {
      if ( $line eq '' || $line =~ m/^ *$/ ) {
        $cfg_processing = 0;
        if ( defined($config_data_text) && ! $config_data_text eq '' ) {
          # write doen storage config section as 1 line
          open(FCCF, "> $file_cfg_text") || main::error ("$host: Can't open $file_cfg_text: $! ".__FILE__.":".__LINE__) && return 0;
          print FCCF "$config_data_text\n";
          close(FCCF);
        }
      }
      else {
        (my $name_param, my $value) = split (/:/,$line);
        if ( defined($value) && ! $value eq '' && $line !~ m/^ *$/ ) {
          $value =~ s/ //g;
          $config_data_text .= "$value,";
        }
      }
    }

    if ( $line =~ m/Logical Drive Level Configuration/ || $line =~ m/Raid Group Level Configuration/ || $line =~ m/Rank Level Configuration/ || $line =~ m/Managed Disk Level Configuration/ ) {
      $rank_cfg_processing = 1;
      $indx = 0;
      next;
    }

    if ( $line =~ m/Volume Level Configuration/ || $line =~ m/VOLUME Level Configuration/) {
      $vol_cfg_processing = 1;
      $indx = 0;
      next;
    }

    if ( $line =~ m/Port Level Configuration/ || $line =~ m/PORT Level Configuration/ ) {
      $port_cfg_processing = 1;
      $indx = 0;
      next;
    }

    if ( $line =~ m/Host Level Configuration/ || $line =~ m/HOST Level Configuration/ ) {
      $host_cfg_processing = 1;
      $indx = 0;
      next;
    }

    if ( $line =~ m/Pool Level Configuration/ || $line =~ m/POOL Level Configuration/) {
      $pool_cfg_processing = 1;
      $indx = 0;
      next;
    }

    if ( $line =~ m/System Level Configuration/ ) {
      $system_cfg_processing = 1;
      $indx = 0;
      next;
    }

    if ( $system_cfg_processing == 1 ) {
      if ($line =~ m/^$/ ) {
        $system_cfg_processing=0;
        $indx = 0;
        next; # end of cfg
      }
      my ($sys_name,$sys_value) = split(/,/,$line);
      $system_name[$indx] = $sys_name;
      $system_value[$indx] = $sys_value;
      $indx++;
    }


    if ($pool_cfg_processing && ( $st_type =~ m/^XIV$/ || $st_type =~ m/^3PAR$/ ) ) {
      # Only for XIV
      if ($line =~ m/^$/ ) {
        $pool_cfg_processing=0;
        $indx = 0;
        next; # end of cfg
      }
      if ($line =~ m/^name,id,status/ ) {
        next;
      }
      if ( $st_type =~ m/^3PAR$/ ) {
        ($pool_name_id[$indx], $pool_name[$indx]) = split (/,/,$line);
      }
      else {
        ($pool_name[$indx], $pool_name_id[$indx]) = split (/,/,$line);
      }
      $pool_detail[$indx] = $line;
      $indx++;
      next;
    }

    if ($pool_cfg_processing && ( $st_type =~ m/^DS5K$/ || $st_type =~ m/^HUS$/ )) {
      # Only for DS5K 
      if ($line =~ m/^$/ ) {
        $pool_cfg_processing=0;
        $indx = 0;
        next; # end of cfg
      }
      if ($line =~ m/^name,id,status/ || $line =~ m/^,id,status,,,capacity/ ) {
        next;
      }
      if ( $st_type =~ m/^HUS$/ ) {
        (my $trash1,$pool_name[$indx] ) = split (/,/,$line);
      }
      else {
        ($pool_name[$indx] ) = split (/,/,$line);
      }
      $pool_name_id[$indx] = -1;
      foreach my $linep (@lines_translate) {
        chomp ($linep);
        (my $id, my $name) = split (/:/,$linep);
        if ( ! defined ($name) && $name eq ''  ) {
          next;
        }
        if ( $name eq $pool_name[$indx] ) {
          $pool_name_id[$indx] = $id;
          last;
        }
      }
      if ( $pool_name_id[$indx] == -1  ) {
        next; # do not increment $indx++ here as something is wrong with this line
      }
      $pool_detail[$indx] = $line;
      $indx++;
      next;
    }

    if ($host_cfg_processing) {
      if ($line =~ m/^$/ ) {
        $host_cfg_processing=0;
        $indx = 0;
        next; # end of cfg
      }
      ($t1, $t2, $host_list[$indx], $t3, $t4, $t5, $t6, $host_detail[$indx]) = split (/,/,$line);
      $indx++;
    }

    if ($port_cfg_processing) {
      if ($line =~ m/^$/ ) {
        $port_cfg_processing=0;
        $indx = 0;
        next; # end of cfg
      }
      $port_detail[$indx] = $line;
      $line =~ s/,.*$//;
      $port_list[$indx] = $line;
      $indx++;
    }

    if ($vol_cfg_processing) {
      if ($line =~ m/^$/ ) {
        $vol_cfg_processing=0;
        $indx = 0;
        next; # end of cfg
      }
      $lines_valid[$indx] = $line;
      $indx++;
    }

    if ($rank_cfg_processing) {
      if ($line =~ m/^$/ ) {
        $rank_cfg_processing=0;
        next; # end of cfg
      }

      if ( $st_type =~ m/^HUS$/ ) {
        $rank_cfg_id[$indx] = $line;
        $indx++;
        next;
      }

      # create an array with mapping table between ranks and pools
      my $rank_id_cfg_item = "na";
      my $pool_id_cfg_item = "na";
      my $pool_name_cfg_item = "na";

      if ( $st_type =~ m/^3PAR$/ ) {
        ($rank_id_cfg_item, $t3, my $pool_id_cfg_item_tmp, $pool_name_cfg_item ) = split(/,/,$line);
        # LD ID,LD name,CPG ID,CPG name,RAID,Status,Owner,Use,Total size [MB],Used size [MB],
        # 29,tp-1-sd-0.0,1,FC_r5,5,normal,0/1,C-SD,61440,61440,
        if ( isdigit($pool_id_cfg_item_tmp) == 0 || $pool_id_cfg_item_tmp =~ m/^-$/ ) {
          next; # could be storage system ranks ..
        }
        $pool_id_cfg_item = $pool_id_cfg_item_tmp;   # just for bacward compatability with DS8K
      }
      if ( $st_type =~ m/^SWIZ$/ ) {
        ($rank_id_cfg_item, $t3, $t4, $t5, $t6, my $pool_id_cfg_item_tmp, $pool_name_cfg_item) = split(/,/,$line);
        $pool_id_cfg_item = $pool_id_cfg_item_tmp;   # just for bacward compatability with DS8K
      }
      if ( $st_type =~ m/^DS8K$/ ) {
        ($rank_id_cfg_item, $pool_id_cfg_item, $t3, $t4, $t5, $t6, $t7 ,$t8, $pool_name_cfg_item) = split(/,/,$line);
      }
      $pool_id_cfg_item =~ s/^.*\///;
      $rank_cfg_id[$rank_cfg_indx] = $rank_id_cfg_item;
      $rank_detail[$rank_cfg_indx] = $line;
      $pool_cfg_id[$rank_cfg_indx] = $pool_id_cfg_item;

      # save actual pool cfg
      my $found = -1;
      foreach my $pool_item (@pool_name) {
        if ( $pool_item =~ m/^$pool_name_cfg_item$/ ) {
          $found = $pool_name_indx;
          last;
        }
      }
      if ( $found == -1 ) {
        $pool_name[$pool_name_indx] = $pool_name_cfg_item;
        $pool_name_id[$pool_name_indx] = $pool_id_cfg_item;
        #print "003 $pool_name[$pool_name_indx] - $pool_name_id[$pool_name_indx]\n";
        $pool_name_indx++;
        my $pool_number = $pool_id_cfg_item; # there is still P letter
        $pool_number =~ s/^P//;
      }

      $rank_cfg_indx++; 
    }
  }  # foreach


  # volume per  volume ID sort per nicks
  @lines_valid = sort { (split ',', $a)[2] cmp (split ',', $b)[2] } @lines_valid;
  $found = 0;
  $indx = 0;
  # following to keep one volume pool ID  per each volume
  my $indx_all_vols = 0;
  my @vol_pool_id = "";
  my @vol_id_one = "";
  my @vol_detail = "";

  foreach my $line (@lines_valid) {
    chomp ($line);

    if ( $line eq '' ) {
      next;
    }

    my $id = "";
    my $sn = "";
    my $nick = "";
    my $p_id = "";

    if ( $st_type =~ m/^3PAR$/ ) {
      ($id, $nick, $p_id) = split(/,/,$line);
      # Volume ID,Volume name,CPG ID,CPG name,Status,Provisioning,Type,Copy Of,Admin size [MB],Snap size [MB],User size [MB],Real size [MB],Virtual size [MB],
      # 315,ESX7-boot,1,FC_r5,normal,tpvv,base,---,256,512,25088,25856,307200,
    }
    if ( $st_type =~ m/^SWIZ$/ ) {
      ($id, $sn, $nick, $t10, $t1, $t2, $p_id) = split(/,/,$line);
        # 0000,0,A3201023rvg,0,io_grp0,online,0,PRDSK1_SAS_600,53687091200,striped,,,,,60050768028201BDA000000000000001,0,1,not_empty,0,no,0
    }
    if ( $st_type =~ m/^DS8K$/ ) {
      ($id, $sn, $nick, $t10, $t1, $t2, $t3, $t4, $p_id) = split(/,/,$line);
        # Volume ID,Volume SN,Volume Nickname,LSS Number,Volume Number,Volume Size,Volume Type,Host Maps,Pool ID
        # 0x0000,IBM.2107-75ANXXX/0000,INPH10,0x00,0x00,1.000000,FB 512,IBM.2107-75ANXXX/V4:IBM.2107-75AXXXX/V5,IBM.2107-75ANXXX/P0
    }
    if ( $st_type =~ m/^XIV$/ ) {
      ($id, $sn, $nick, $t10, $t1, $t2, $p_id) = split(/,/,$line);
      # volume_id,id,name,,,,pool_id,pool_name,capacity,,,,,,vdisk_UID,,,,,,
      # 00102884,IBM.2810-6001573-102884,vio_3p_03,,,,102780,VIO_3P,51539607552,,,,,,001738000625006D,,,,,,
    }
    if ( $st_type =~ m/^DS5K$/ || $st_type =~ m/^HUS$/ ) {
      ($id, $sn, $nick, $t10, $t1, $t2, $p_id, my $p_name) = split(/,/,$line);
      # volume_id,id,name,,,,pool_id,pool_name,capacity (MB),,,,,,vdisk_UID,,,,,,interface_type
      # 60080e500018469e00000f334d885f69,,ADS11_ASRV11LPAR10_BOOT0,,,,,ADS11_SATA_ARRAY1,30720,,,,,,,,,,,,Serial ATA (SATA)
      # find out pool ID, this does not come with volume info
      foreach my $linep (@lines_translate) {
        chomp ($linep);
        (my $id, my $name) = split (/:/,$linep);
        if ( ! defined ($name) && $name eq '' ) {
          next; # separe it as it $name can be "0" 
        }
        if (  defined ($p_name) && $name eq $p_name) {
          $p_id = $id;
          last;
        }
      }
    }

    if ( ! defined ($id) || $id eq '' ) {
      next; # something strange ...
    }

    if ( ! defined($nick) || $nick eq '' ) {
      $nick = $id;
    }

    $p_id =~ s/.*\///;
    $vol_id_one[$indx_all_vols] = $id;
    $vol_pool_id[$indx_all_vols] = $p_id;
    $vol_detail[$indx_all_vols] = $line;
    $indx_all_vols++;
    #print "088 $indx_all_vols : $id : $p_id : $line\n";


    if ( $vol_nicks[$indx] eq '' ) {
      # only for the first run!
      $vol_nicks[$indx] = $nick;
      $vol_id[$indx] = $id.";";
      next;
    }
    

    if ( $vol_nicks[$indx] =~ m/^$nick$/ ) {
      $vol_id[$indx] .= $id.";";
    }
    else {
      $indx++;
      $vol_nicks[$indx] = $nick;
      $vol_id[$indx] = $id.";";
    }
  }

  # print timestamp of config.html
  $file = "$wrkdir/$host/config.html";
  my $run_time = (stat("$file"))[9];
  my $ltime = localtime($run_time);


  # standard
  create_html ($st_type,0,$ltime,$webdir,$wrkdir,$host,$DEBUG,$act_time,\@port_list,\@pool_cfg_id,\@rank_cfg_id,\@pool_name_id,\@vol_id_one,\@vol_nicks,\@vol_id,\@vol_pool_id,\@vol_detail,\@rank_detail,\@port_detail,\@pool_detail,\@lines_translate,\@system_name,\@system_value);

  # detailed (verbose)
  create_html ($st_type,1,$ltime,$webdir,$wrkdir,$host,$DEBUG,$act_time,\@port_list,\@pool_cfg_id,\@rank_cfg_id,\@pool_name_id,\@vol_id_one,\@vol_nicks,\@vol_id,\@vol_pool_id,\@vol_detail,\@rank_detail,\@port_detail,\@pool_detail,\@lines_translate,\@system_name,\@system_value);

  return 0;
}

sub create_html {
  my ($st_type,$verbose,$ltime,$webdir,$wrkdir,$host,$DEBUG,$act_time,$port_list_tmp,$pool_cfg_id_tmp,$rank_cfg_id_tmp,$pool_name_id_tmp,$vol_id_one_tmp,$vol_nicks_tmp,$vol_id_tmp,$vol_pool_id_tmp,$vol_detail_tmp,$rank_detail_tmp,$port_detail_tmp,$pool_detail_tmp,$lines_translate_tmp,$system_name_tmp,$system_value_tmp) = @_;
  my @port_list = @{$port_list_tmp};
  my @port_detail = @{$port_detail_tmp};
  my @pool_cfg_id = @{$pool_cfg_id_tmp};
  my @pool_detail = @{$pool_detail_tmp};
  my @rank_cfg_id = @{$rank_cfg_id_tmp};
  my @rank_detail = @{$rank_detail_tmp};
  my @system_name = @{$system_name_tmp};
  my @system_value = @{$system_value_tmp};
  my @lines_translate = @{$lines_translate_tmp};
  my @pool_name_id = @{$pool_name_id_tmp};
  my @vol_id_one = @{$vol_id_one_tmp};
  my @vol_nicks = @{$vol_nicks_tmp};
  my @vol_id = @{$vol_id_tmp};
  my @vol_pool_id = @{$vol_pool_id_tmp};
  my @vol_detail = @{$vol_detail_tmp};
  my $indx = 0;

  print "creating cfg   : $host verbose:$verbose\n" if $DEBUG ;
  my $file_gui = "$webdir/$host/gui-config-detail.html";
  if ( $verbose == 1 ) {
    $file_gui = "$webdir/$host/gui-config-detail-verb.html";
  }
  open(FCFGG, "> $file_gui") || main::error ("$host: Can't open $file_gui: $! ".__FILE__.":".__LINE__) && return 0;

  my $port_col = "#AAAAFF";
  my $pool_col = "#FF8080";
  my $rank_col = "#FFFF80";
  my $vol_col = "#80FF80";
  
  my $head =  "<table><tr>
               <td bgcolor=\"$pool_col\"> <font size=\"-1\">POOL</font></td>
               <td bgcolor=\"$rank_col\"> <font size=\"-1\">RAID GROUP</font></td>
               <td bgcolor=\"$vol_col\"> <font size=\"-1\">VOLUME</font></td>
               </tr></table>\n";
  if ( $st_type =~ m/^DS5K$/ || $st_type =~ m/^XIV$/ || $st_type =~ m/^HUS$/ ) { 
    $head =  "<table><tr>
               <td bgcolor=\"$pool_col\"> <font size=\"-1\">POOL</font></td>
               <td bgcolor=\"$vol_col\"> <font size=\"-1\">VOLUME</font></td>
               </tr></table>\n";
  }
  print FCFGG "$head";

  if ( $verbose ) {
    print FCFGG "<a href=\"$host/gui-config-detail.html\">Summary</a> / <a href=\"$host/config.html\">Text</a>\n";
  }
  else {
    print FCFGG "<a href=\"$host/gui-config-detail-verb.html\">Detailed</a> / <a href=\"$host/config.html\">Text</a>\n";
  }

  my $pool_i = 0;
  my $rank_i = 0;
  my $port_i = 0;
  my $vol_i = 0;

  # Total storage space usage
  # go through all ranks and summ used and free space at first
  my $rank_i_pool = 0;
  my $pool_indx = 0;
  my $pool_used = 0;
  my $pool_tot = 0;
  my $pool_free = 0;
  my $raid = "";
  if ( $st_type =~ m/^DS8K$/ || $st_type =~ m/^SWIZ$/ || $st_type =~ m/^3PAR/ ) { 
    foreach my $l (@rank_cfg_id) {
      my $cap = 0;
      my $used = 0;
      if ( $st_type =~ m/^SWIZ$/ ) {
        #(my $t1, my $t2, my $etype, $cap, $raid, my $t3, my $t4, my $t5, my $t6, $used) = split(/,/,$rank_detail[$rank_i_pool]);
        # not done yet --PH
        $cap = 0;
      }
      else {
        if ( $st_type =~ m/^3PAR$/ ) {
          (my $t1, my $t2, my $pool_id_tmp, my $t7, $raid, my $t3, my $t4, my $t5, $cap, $used) = split(/,/,$rank_detail[$rank_i_pool]);
          # LD ID,LD name,CPG ID,CPG name,RAID,Status,Owner,Use,Total size [MB],Used size [MB],
          # 78,tp-0-sa-0.1,0,FC_r1,1,normal,1/0,C-SA,4096,64,
          if ( isdigit($pool_id_tmp) == 0 || $pool_id_tmp =~ m/^-$/ ) {
            $rank_i_pool++;
            next; # storage system ranks, skkip them, they do not have pool ID
          }
        }
        else {
          (my $t1, my $t2, my $etype, $cap, $raid, my $t3, my $t4, my $t5, my $t6, $used) = split(/,/,$rank_detail[$rank_i_pool]);
        }
      }
      if ( isdigit($cap) == 0 ||  isdigit($used) == 0 ) {
        main::error ("$host: Can't get size ifo of RANK $l : $rank_detail[$rank_i_pool] ".__FILE__.":".__LINE__);
        $rank_i_pool++;
        next;
      }
      if ( isdigit($cap) && isdigit($used) ) {
        $pool_used = $pool_used + $used;
        $pool_tot = $pool_tot + $cap;
      }
      $rank_i_pool++;
    }
  }
  if ( $st_type =~ m/^DS5K$/ || $st_type =~ m/^XIV$/ || $st_type =~ m/^HUS$/ ) { 
    my $cap = 0;
    my $free = 0;
    foreach my $line_p (@pool_detail) {
      (my $t1, my $t2, my $t8, my $t7, my $t9, $cap, my $t10, $free) = split(/,/,$line_p);
      if ( ! defined ($free) || $free eq '' ) {
        $free = 0;
      }
      if ( isdigit($cap) && isdigit($free) ) {
        my $used = $cap - $free;
        $pool_used = $pool_used + $used;
        $pool_tot = $pool_tot + $cap;
      }
    }
  }

  # conversion to TB 
  if ( $pool_used > 0 && $pool_tot > 0 ) {
    $pool_free = $pool_tot - $pool_used;
  }
  if ( $st_type =~ m/^3PAR$/ ) {
    $pool_used = $pool_used / 1024;
    $pool_tot = $pool_tot / 1024;
    $pool_free = $pool_free / 1024;
  }
  my $pool_used_tb = sprintf("%.2f",($pool_used / 1024 ));
  $pool_used = $pool_used_tb."&nbsp;TB";
  my $pool_tot_tb = sprintf("%.2f",($pool_tot / 1024));
  $pool_tot  = $pool_tot_tb."&nbsp;TB";
  my $pool_free_tb = sprintf("%.2f",($pool_free / 1024));
  $pool_free = $pool_free_tb."&nbsp;TB";

  if ($verbose ) {
    if ( $st_type =~ m/^SWIZ$/ ) {
      print FCFGG "<center><h3>$host</font></h3>\n";
      # --PH dodelat totals for Storwize
    }
    else {
      print FCFGG "<center><h3>$host <font size=\"-1\"><br>(Free:$pool_free, Size:$pool_tot, Used:$pool_used)</font></h3>\n";
      # print capacity info into static file, it is used as a workaround for the GUI source
      print_capacity_static ("$wrkdir/$host","total $pool_tot\nfree $pool_free\nused $pool_used\n",$act_time,\@system_name,\@system_value);
    }
  }
  else {
    print FCFGG "<center><h3>$host</h3>\n";
  }
  print FCFGG "<table border=\"0\"  style=\"border-collapse: collapse\"><tr>\n"; # global table, each column is nested table
  print FCFGG "<td valign=\"top\"><table border=\"3\" style=\"border-collapse: collapse\" BORDERCOLOR=\"$pool_col\"><tr>\n";

  # PORT
  # no PORTs here, do not see usefullness
  #foreach my $l (@port_list) {
  #  (my $t1, my $t2,  my $t3, my $t4, my $wwn) = split(/,/,$port_detail[$port_i]);
  #  $port_i++;
  #}


  # go through all pools
  #@pool_name_id = sort { lc $a cmp lc $b } @pool_name_id; # sort it out
  # no no, do not sort it out here, it is a problem for DS5K!!

  my $pool_processing = 0;

  foreach my $pool_tmp (@pool_name_id) {
   if ( $pool_tmp eq '' ) {
     $pool_i++;
     next;
   }

   $pool_used = 0;
   $pool_tot = 0;
   $pool_free = 0;

   $pool_processing = 1;
   if ( $st_type =~ m/^DS8K$/ ) {
    # POOL
    # at first figue out total space and used space per ranks
    $rank_i_pool = 0;
    foreach my $l (@rank_cfg_id) {
      if ( $pool_cfg_id[$rank_i_pool] =~ m/^$pool_name_id[$pool_i]$/ ) {
        my $cap = 0;
        my $used = 0;
        (my $t1, my $t2, my $etype, $cap, my $raid, my $t3, my $t4, my $t5, my $t6, $used) = split(/,/,$rank_detail[$rank_i_pool]);
        if ( isdigit($cap) && isdigit($used) ) {
          my $used_tb = sprintf("%.2f",($used / 1024));
          my $cap_tb = sprintf("%.2f",($cap / 1024));
          $pool_used = $pool_used + $used_tb;
          $pool_tot = $pool_tot + $cap_tb;
        }
      }
      $rank_i_pool++;
    }
   }

   my $pool_id = $pool_name_id[$pool_i];
   $pool_id =~ s/^P//;
   if ( main::ishexa($pool_id) == 0 ) {
     # SVC: there could be ranks without pool ID, happens during some migrations on the storage ...
     #main::error ("$host: wrong pool ID : $pool_name_id[$pool_i] ".__FILE__.":".__LINE__);
     $pool_i++;
     next;
   }

   if ( $st_type =~ m/^SWIZ$/ ) {
     # get allocation of pools for SVC --> POOL/0-cap.rrd
     my $ret = get_rrd_last_pool_size ("$wrkdir/$host/POOL/$pool_id-cap.rrd");
     if ( $ret =~ m/^na$/ ) {
       # wrong parsed RRD or no data
       $pool_used = 0;
       $pool_tot  = 0; 
       $pool_free = 0; 
     }
     else {
       ($pool_tot,$pool_free) = split (/:/,$ret);
       $pool_used = sprintf("%.2f",($pool_tot - $pool_free));
     }
   }

  my $pool_name = "";
  if ( $st_type =~ m/^DS5K$/ || $st_type =~ m/^XIV$/ || $st_type =~ m/^HUS$/ || $st_type =~ m/^3PAR$/ ) {
    if ( $st_type =~ m/^HUS$/ ) {
      (my $t2, $pool_name, my $t8, my $t7, my $t9, $pool_tot, my $t10, $pool_free) = split(/,/,$pool_detail[$pool_i]);
    }
    else {
      if ( $st_type =~ m/^3PAR$/ ) {
        (my $t1, $pool_name, $pool_tot, my $pool_use_tmp) = split(/,/,$pool_detail[$pool_i]);
        # CPG ID,CPG name,User Total Capacity [MB],User Used Capacity [MB],Snapshot Total Capacity [MB],Snapshot Used Capacity [MB],Admin Total Capacity [MB],Admin Used Capacity [MB],
        # 1,FC_r5,895488,895488,809472,35712,12288,2432,
        if ( isdigit($pool_tot) == 0 || isdigit($pool_use_tmp) == 0 ) {
          $pool_i++;
          next;
        }
        $pool_free = $pool_tot - $pool_use_tmp;
      }
      else {
        ($pool_name, my $t2, my $t8, my $t7, my $t9, $pool_tot, my $t10, $pool_free) = split(/,/,$pool_detail[$pool_i]);
      }
    }
    if ( ! defined ($pool_free) || $pool_free eq '' ) {
      $pool_free = 0;
    }
    if ( isdigit($pool_tot) && isdigit($pool_free) ) {
      $pool_used = $pool_tot - $pool_free;
    }
    else {
      $pool_i++;
      next;
    }
    # conversion to TB
    if ( $st_type =~ m/^3PAR$/ ) {
      $pool_used = $pool_used / 1024;
      $pool_tot = $pool_tot / 1024;
      $pool_free = $pool_free / 1024;
    }
    my $pool_used_tb = sprintf("%.2f",($pool_used / 1024));
    $pool_used = $pool_used_tb;
    my $pool_tot_tb = sprintf("%.2f",($pool_tot / 1024));
    $pool_tot  = $pool_tot_tb;
    my $pool_free_tb = sprintf("%.2f",($pool_free / 1024));
    $pool_free = $pool_free_tb;
  }

   if ( isdigit($pool_used) && isdigit($pool_tot) && $pool_used > 0 && $pool_tot > 0 ) {
     $pool_free = sprintf("%.2f",($pool_tot - $pool_used));
   }
   $pool_used .= "&nbsp;TB";
   $pool_tot  .= "&nbsp;TB";
   $pool_free .= "&nbsp;TB";

   # POOL capacity --> must translate name
   if ( $st_type =~ m/^DS8K$/ || $st_type =~ m/^SWIZ$/ || $st_type =~ m/^3PAR$/ ) {
     $pool_name = $pool_id;
     foreach my $linep (@lines_translate) {
       chomp ($linep);
       (my $id, my $name) = split (/:/,$linep);
       if ( $id =~ m/^$pool_id$/ ) {
         $pool_name = $name;
         last;
       }
     }
   }


    print FCFGG "<td valign=\"top\"><table border=\"0\"  style=\"border-collapse: collapse\">\n";
    if ($verbose ) {
      print FCFGG "<tr><td nowrap align=\"center\" bgcolor=\"$pool_col\"><a href=\"/stor2rrd-cgi/detail.sh?host=$host&amp;type=POOL&amp;name=$pool_id&amp;storage=$st_type&amp;none=none\">$pool_name</a><TABLE border=\"0\" width=\"100%\"><tr><td><font size=\"-1\">Free:<b>$pool_free&nbsp;</b></font></td></tr><tr><td><font size=\"-1\">Size:<b>$pool_tot</b></font></td><td><font size=\"-1\">Used:<b>$pool_used</b></font></td></tr></table>    </td></tr>\n";
    }
    else {
      print FCFGG "<tr><td  title=\"size:$pool_used&nbsp;used:$pool_tot&nbsp;free:$pool_free\" nowrap align=\"center\" bgcolor=\"$pool_col\"><a href=\"/stor2rrd-cgi/detail.sh?host=$host&amp;type=POOL&amp;name=$pool_id&amp;storage=$st_type&amp;none=none\">$pool_name</a></td></tr>\n";
    }       


    # RANK
    # select all ranks under specific pool
    $rank_i = 0;
    my $cap_tot = 0;
    my $used_tot = 0;
    foreach my $l (@rank_cfg_id) {
      if ( $st_type =~ m/^XIV$/ || $st_type =~ m/^DS5K$/ || $st_type =~ m/^HUS/ ) {
        last;
      }
      if ( $pool_cfg_id[$rank_i] =~ m/^$pool_name_id[$pool_i]$/ ) {
        my $cap = 0;
        my $used = 0;
        my $etype = "na";
        my $raid = "na";
        if ( $st_type =~ m/^SWIZ$/ ) {
          #(my $t1, my $t2, my $etype, my $cap, my $raid, my $t3, my $t4, my $t5, my $t6, my $used) = split(/,/,$rank_detail[$rank_i]);
          # not done yet --PH
          $cap = 0;
        }
        else {
          if ( $st_type =~ m/^3PAR$/ ) {
            (my $t1, my $t2, my $pool_id_tmp, my $t7, $raid, my $t3, my $t4, my $t5, $cap, $used) = split(/,/,$rank_detail[$rank_i]);
            # LD ID,LD name,CPG ID,CPG name,RAID,Status,Owner,Use,Total size [MB],Used size [MB],
            # 78,tp-0-sa-0.1,0,FC_r1,1,normal,1/0,C-SA,4096,64,
            if ( isdigit($pool_id_tmp) == 0 || $pool_id_tmp =~ m/^-$/ ) {
              $rank_i++;
              next; # storage system ranks, skkip them, they do not have pool ID
            }
          }
          else {
            (my $t1, my $t2, $etype, $cap, $raid, my $t3, my $t4, my $t5, my $t6, $used) = split(/,/,$rank_detail[$rank_i]);
          }
        }
        if ( isdigit($cap) == 0 ||  isdigit($used) == 0 ) {
          main::error ("$host: Can't get size of RANK $pool_cfg_id[$rank_i]: $rank_detail[$rank_i] ".__FILE__.":".__LINE__);
          $rank_i++;
          next;
        }
        if ( $st_type =~ m/^3PAR$/ ) {
          $cap = $cap / 1024;
          $used = $used / 1024;
        }
        my $cap_tb = sprintf("%.2f",($cap / 1024));
        my $used_tb = sprintf("%.2f",($used / 1024));
        $cap = $cap_tb."&nbsp;TB";
        $used = $used_tb."&nbsp;TB";
        if ($verbose ) {
          if ( $st_type =~ m/^SWIZ$/ ) {
            # no details for MDISK yet .....
            print FCFGG "<tr><td title=\"size:$cap&nbsp;used:$used&nbsp;RAID:$raid&nbsp;type:$etype\" nowrap align=\"center\" bgcolor=\"$rank_col\"><a href=\"/stor2rrd-cgi/detail.sh?host=$host&amp;type=RANK&amp;name=$l-P$pool_name_id[$pool_i]&amp;storage=$st_type&amp;none=none\">$l</a></td></tr>\n";
          }
          else {
            print FCFGG "<tr><td nowrap align=\"center\" bgcolor=\"$rank_col\"><a href=\"/stor2rrd-cgi/detail.sh?host=$host&amp;type=RANK&amp;name=$l-$pool_name_id[$pool_i]&amp;storage=$st_type&amp;none=none\">$l</a><TABLE border=\"0\" width=\"100%\"><tr><td><font size=\"-1\">Size:<b>$cap&nbsp;</b></font></td><td><font size=\"-1\">Used:<b>$used</b></font></td></tr></table>   </td></tr>\n";
          }
        }
        else {
          if ( $st_type =~ m/^SWIZ$/ ) {
            print FCFGG "<tr><td title=\"size:$cap&nbsp;used:$used&nbsp;RAID:$raid&nbsp;type:$etype\" nowrap align=\"center\" bgcolor=\"$rank_col\"><a href=\"/stor2rrd-cgi/detail.sh?host=$host&amp;type=RANK&amp;name=$l-P$pool_name_id[$pool_i]&amp;storage=$st_type&amp;none=none\">$l</a></td></tr>\n";
          }
          else {
            print FCFGG "<tr><td title=\"size:$cap&nbsp;used:$used&nbsp;RAID:$raid&nbsp;type:$etype\" nowrap align=\"center\" bgcolor=\"$rank_col\"><a href=\"/stor2rrd-cgi/detail.sh?host=$host&amp;type=RANK&amp;name=$l-$pool_name_id[$pool_i]&amp;storage=$st_type&amp;none=none\">$l</a></td></tr>\n";
          }
        }
        $cap_tot = $cap_tot + $cap_tb;
        $used_tot = $used_tot + $used_tb;
      }
      $rank_i++;
    }
    if ( isdigit($pool_tot) && $pool_tot > 0 ) {
      my $free_tot = $cap_tot - $used_tot;
      print_capacity_static ("$wrkdir/$host","total $cap_tot\nfree $free_tot\nused $used_tot\n",$act_time,\@system_name,\@system_value);
    }

    # mdisk name translation, must be global one
    my @volume_trans = "";
    if ( -f "$wrkdir/$host/VOLUME/volumes.cfg" ) {
      if ( $st_type =~ m/^SWIZ$/ || $st_type =~ m/^XIV$/ || $st_type =~ m/^DS5K$/ || $st_type =~ m/^HUS$/ || $st_type =~ m/^3PAR$/ ) {
        open(FHR, "< $wrkdir/$host/VOLUME/volumes.cfg") || main::error ("$host: Can't open $wrkdir/$host/VOLUME/volumes.cfg : $! ".__FILE__.":".__LINE__) && return 0;
        @volume_trans = <FHR>;
        close(FHR);
      }
    }

  
    # VOLUME
    # select all volumess under specific pool
    $vol_i = 0;
    foreach my $l (@vol_id_one) {
      #print "$l : $vol_pool_id[$vol_i] - $pool_name_id[$pool_i]\n";
      if ( $vol_pool_id[$vol_i] =~ m/^$pool_name_id[$pool_i]$/ ) {
        my $sn = "na";
        my $alias = "na";
        my $lss = "na";
        my $size = "na";
        my $vtype = "na";
        my $l_translated = $l;
        my $size_tmp = 0;
        my $vol_id_text = "VOL&nbsp;ID:<b>$l</b>";
        if ( $st_type =~ m/^SWIZ$/ || $st_type =~ m/^DS5K$/ || $st_type =~ m/^XIV$/ || $st_type =~ m/^HUS$/ || $st_type =~ m/^3PAR$/ ) {
          if ( $st_type =~ m/^HUS$/ ) {
            ($alias, $sn, my $t1, my $t2, my $t3, my $t4, my $t5, my $t6, $size_tmp) = split(/,/,$vol_detail[$vol_i]);
          }
          else {
            if ( $st_type =~ m/^3PAR$/ ) {
              (my $t1, $alias, my $pool_id_tmp, my $t3, my $t4, my $t5, my $vtype, my $t7, my $t8, my $t9, $size_tmp) = split(/,/,$vol_detail[$vol_i]);
              # Volume ID,Volume name,CPG ID,CPG name,Status,Provisioning,Type,Copy Of,Admin size [MB],Snap size [MB],User size [MB],Real size [MB],Virtual size [MB],
              # 315,ESX7-boot,1,FC_r5,normal,tpvv,base,---,256,512,25088,25856,307200,
              if ( isdigit($pool_id_tmp) == 0 ) {
                $vol_i++;
                next; # storage system volumes internal or snapshots
              } 
              $lss = "na";
            }
            else {
              (my $t1, $sn, $alias, my $t2, my $t3, my $t4, my $t5, my $t6, $size_tmp) = split(/,/,$vol_detail[$vol_i]);
            }
          }
          if ( $st_type =~ m/^SWIZ$/ ) {
            $size = sprintf ("%6.2f",$size_tmp/1073741824) ; 
          }
          else {
            if ( $st_type =~ m/^XIV$/ ) {
              $size = sprintf ("%6.2f",$size_tmp) ; 
            }
            else {
              $size = sprintf ("%6.2f",$size_tmp/1024) ; 
            }
            $l_translated = $alias;
            $vol_id_text = ""; # do not show that very long Volume ID
          }
        }
        else {
          (my $t1, $sn, $alias, $lss, my $t2, $size, $vtype) = split(/,/,$vol_detail[$vol_i]);
          $size =~ s/00$//;
          $size =~ s/00$//;
          $size =~ s/00$//;
          $size =~ s/\.$//;
        }
        $size .= "&nbsp;GB";
        if ( $st_type =~ m/^SWIZ$/ ) {
          # SWIZ volume translation
          foreach my $line_v (@volume_trans) {
            chomp ($line_v);
            if ( $line_v !~ m/ : / ) {
              next; # something is wrong ...
            }
            ( my $name_v, my $id_v ) = split (/ : /,$line_v);
            if ( $id_v eq '' ) {
              next; # something is wrong ...
            }
            $id_v =~ s/;.*//;
            if ( $id_v =~ m/^$l$/ ) { # rather string comparsion, although both should be numbers
              $l_translated = $name_v;
              last;
            }
          }
        }
        if ($verbose ) {
          if ( $st_type =~ m/^SWIZ$/ || $st_type =~ m/^DS5K$/ || $st_type =~ m/^XIV$/ || $st_type =~ m/^HUS$/ || $st_type =~ m/^3PAR$/ ) {
            print FCFGG "<tr><td nowrap align=\"center\" bgcolor=\"$vol_col\"><a href=\"/stor2rrd-cgi/detail.sh?host=$host&amp;type=VOLUME&amp;name=$l_translated&amp;storage=$st_type&amp;none=none\">$alias</a><TABLE border=\"0\" width=\"100%\"><tr><td><font size=\"-1\">Size:<b>$size&nbsp;</b></font></td><td><font size=\"-1\">$vol_id_text</font></td></tr></table>   </td></tr>\n";
          }
          else {
            print FCFGG "<tr><td nowrap align=\"center\" bgcolor=\"$vol_col\"><a href=\"/stor2rrd-cgi/detail.sh?host=$host&amp;type=VOLUME&amp;name=$alias&amp;storage=$st_type&amp;none=none\">$alias</a><TABLE border=\"0\" width=\"100%\"><tr><td><font size=\"-1\">Size:<b>$size&nbsp;</b></font></td><td><font size=\"-1\">$vol_id_text</font></td></tr><tr><td><font size=\"-1\">LSS:<b>$lss</b></font></td><td><font size=\"-1\">Type:<b>$vtype</b></font></td></tr></table>   </td></tr>\n";
          }
        }
        else {
          if ( $st_type =~ m/^SWIZ$/ || $st_type =~ m/^DS5K$/ || $st_type =~ m/^XIV$/ || $st_type =~ m/^HUS$/ || $st_type =~ m/^3PAR$/ ) {
            print FCFGG "<tr><td title=\"size:$size&nbsp;&nbsp;\" nowrap align=\"center\" bgcolor=\"$vol_col\"><a href=\"/stor2rrd-cgi/detail.sh?host=$host&amp;type=VOLUME&amp;name=$l_translated&amp;storage=$st_type&amp;none=none\">$alias</a></td></tr>\n";
          }
          else {
            print FCFGG "<tr><td title=\"size:$size&nbsp;LSS:$lss&nbsp;SN:$sn&nbsp;Vol&nbsp;type:$vtype\" nowrap align=\"center\" bgcolor=\"$vol_col\"><a href=\"/stor2rrd-cgi/detail.sh?host=$host&amp;type=VOLUME&amp;name=$alias&amp;storage=$st_type&amp;none=none\">$alias&nbsp;&nbsp;$l</a></td></tr>\n";
          }
        }
      }
      $vol_i++;
    }
    print FCFGG "</table></td>\n";
    $pool_i++;
  }
  print FCFGG "</tr></table>\n";
  print FCFGG "</tr></table>\n";

  print FCFGG "<br></center>It is updated once day, last update : $ltime\n<br>\n";

  close (FCFGG);

  # only for situation when HUS does not have pool defined ab capacity needs to be printed out for DB purposes
  if ( $pool_processing == 0 && $st_type =~ m/^HUS/ ) {
    my $cap_tot = 0;
    my $used_tot = 0;
    foreach my $l (@rank_cfg_id) {
      (my $t1, my $t2, my $t8, my $t9, my $t7, my $cap, my $t5, my $t3, my $t4, my $used) = split(/,/,$l);
      if ( isdigit($cap) == 0 ||  isdigit($used) == 0 ) {
        main::error ("$host: Can't get size info of RANK $l ".__FILE__.":".__LINE__);
        next;
      }
      my $cap_tb = sprintf("%.2f",($cap / 1024));
      my $used_tb = sprintf("%.2f",($used / 1024));
      $cap_tot = $cap_tot + $cap_tb;
      $used_tot = $used_tot + $used_tb;
    }
    if ( isdigit($cap_tot) && $cap_tot > 0 && isdigit($used_tot) && $used_tot > 0 ) {
      my $free_tot = $cap_tot - $used_tot;
      print_capacity_static ("$wrkdir/$host","total $cap_tot\nfree $free_tot\nused $used_tot\n",$act_time,"","");
    }
  }


  return 1;
}


sub isdigit
{
  my $digit = shift;
  my $text = shift;

  if ( ! defined ($digit) ) {
    return 0;
  }
  if ( $digit eq '' ) {
    return 0;
  }
  if ( $digit eq 'U' ) {
    return 1;
  }

  my $digit_work = $digit;
  $digit_work =~ s/[0-9]//g;
  $digit_work =~ s/\.//;
  $digit_work =~ s/^-//;
  $digit_work =~ s/e//;
  $digit_work =~ s/\+//;
  $digit_work =~ s/\-//;

  if (length($digit_work) == 0) {
    # is a number
    return 1;
  }

  #if (($digit * 1) eq $digit){
  #  # is a number
  #  return 1;
  #}

  # NOT a number
  return 0;
}

# returns 1 when next day after modification the file in the argument
# returns 0 when there is not next day
sub once_a_day {
  my $file = shift;

  # return 1;
  if ( ! -f $file ) {
    return 0;
  }
  else {
    my $run_time = (stat("$file"))[9];
    (my $sec,my $min,my $h,my $aday,my $m,my $y,my $wday,my $yday,my $isdst) = localtime(time());
    ($sec,$min,$h,my $png_day,$m,$y,$wday,$yday,$isdst) = localtime($run_time);
    if ( $aday == $png_day ) {
      # If it is the same day then return 0
      return 0;
    }
    else {
       # diff day
       return 1;
    }
  }
}

sub get_rrd_last_pool_size
{
  my $rrd = shift;
  my $step = 3600; # no really matter what is here

  if ( ! -f "$rrd" ) {
    #main::error ("get_rrd_last_pool_size: $rrd : does not exist ".__FILE__.":".__LINE__);
    # do not raise an error, it might be ok after initial install
    return "na";
  }

  RRDp::cmd qq(last "$rrd");
  my $last_tt = RRDp::read;

  # get LAST value from RRD
  RRDp::cmd qq(fetch "$rrd" "AVERAGE" "-s $$last_tt-$step" "-e $$last_tt-$step");
  my $row = RRDp::read;
  chomp($$row);
  my @row_arr = split(/\n/,$$row);
  my $i = 0;
  foreach my $line (@row_arr) {
   chomp($line);
   $i++;
   if ( $i == 3 ) {
     (my $time, my $total_data, my $free_data) = split(/ /,$line);
     if ( ! isdigit($total_data) || ! isdigit($free_data) ) {
       #main::error ("there was expected a digit but a string is there, value: $total_data : $free_data  : $rrd ".__FILE__.":".__LINE__);
       # it probably returned nan, but lets try another run
       next;
     }
     my $total = sprintf("%.2f",$total_data);
     my $free  = sprintf("%.2f",$free_data);

     # go further ony if it is a digit (avoid it when NaNQ (== no data) is there)
     #print "$total $free\n";
     if ($total =~ /\d/ && $free =~ /\d/ ) {
       return "$total:$free";
     }
     else {
       return "na";
     }
   }
  }
  return "na";
}


# print capacity info into static file, it is used as a workaround for the GUI source
#total 1.23
#free 0.26
#used 0.96

sub print_capacity_static {
  my ($path,$message,$act_time,$system_name_tmp,$system_value_tmp) = @_;
  my @system_name = @{$system_name_tmp};
  my @system_value = @{$system_value_tmp};


  my $file_static = "$path/capacity.txt";
  open(FHRC, "> $file_static") || error ("Can't open $file_static: $! ".__FILE__.":".__LINE__) && return 1;

  my $indx = 0;
  my $free  = "";
  my $total = "";
  my $used = "";
  foreach my $line (@system_name) {
    #only HP 3PAR has capacity stats in conf file per storage total
    if ($line =~ m/^Total Capacity/ ) {
      $total = $system_value[$indx];
    }
    if ($line =~ m/^Free/ ) {
      $free = $system_value[$indx];
    }
    $indx++;
  }
  if (isdigit($total) && isdigit($free) ) { 
    $used = $total - $free;
    $total = sprintf("%.2f",($total / 1048576));
    $free = sprintf("%.2f",($free / 1048576));
    $used = sprintf("%.2f",($used / 1048576));
    $message = "total $total\nfree $free\nused $used\n";
  }

  $message =~ s/&nbsp;//g;
  $message =~ s/TB//g;

  my $start_human = strftime "%H:%M:%S %d.%m.%Y",localtime(time());

  print FHRC "$message\ntime $start_human\n";
  close (FHRC);
  return 1;
}

return 1;

