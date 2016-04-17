use strict;
use warnings;
use RRDp;

# get cmd line params
my $version = "$ENV{version}";
my $webdir  = $ENV{WEBDIR};
my $bindir  = $ENV{BINDIR};
my $basedir = $ENV{INPUTDIR};
my $rrdtool = $ENV{RRDTOOL};
my $DEBUG   = $ENV{DEBUG};
my $pic_col = $ENV{PICTURE_COLOR};
my $upgrade = $ENV{UPGRADE};
my $tmp_dir = "$basedir/tmp";
my $wrkdir  = "$basedir/data";

rrdtool_graphv();

my @color=("#FF0000", "#0000FF", "#FFFF00", "#00FFFF", "#FFA500", "#00FF00", "#808080", "#FF00FF", "#800080",
"#FDD017", "#0000A0", "#3BB9FF", "#008000", "#800000", "#ADD8E6", "#F778A1", "#800517", "#736F6E", "#F52887",
"#C11B17", "#5CB3FF", "#A52A2A", "#FF8040", "#2B60DE", "#736AFF", "#1589FF", "#98AFC7", "#8D38C9", "#307D7E",
"#F6358A", "#151B54", "#6D7B8D", "#FDEEF4", "#FF0080", "#F88017", "#2554C7", "#FFF8C6", "#D4A017", "#306EFF",
"#151B8D", "#9E7BFF", "#EAC117", "#E0FFFF", "#15317E", "#6C2DC7", "#FBB917", "#FCDFFF", "#15317E", "#254117",
"#FAAFBE", "#357EC7", "#4AA02C", "#38ACEC", "#C0C0C0");

my $act_time        = localtime();
my $color_max       = 53;
my $no_legend       = "--interlaced";  # just nope string , it is deprecated anyway
my $name_out        = "/var/tmp/stor2rrd-$$.png";
my $delimiter       = "XORUX"; # this is for rrdtool print lines for clickable legend
my $font_def_normal =  "--font=DEFAULT:7:";
my $font_tit_normal =  "--font=TITLE:9:";
my $STEP = 60;

if ( -f "$bindir/premium.pl" ) {
    require "$bindir/premium.pl";
  }
else {
  require "$bindir/standard.pl";
}
my $prem = premium ();
print "STOR2RRD $prem version $version\n" if $DEBUG ;

# run touch tmp/$version-run once a day (first run after the midnight) to force recreation of the GUI
once_a_day ("$basedir/tmp/$version");


### graph or graphv
my $graph_cmd = "graph";
if ( -f "$tmp_dir/graphv" ) {
   $graph_cmd = "graphv";       # if exists - call this function
}

if ( ! -d "$webdir" ) {
   die "Pls set correct path to Web server pages, it does not exist here: $webdir\n";
}

my $disable_rrdtool_tag = "--interlaced";  #just nope string, it is deprecated anyway
my $rrd_ver = $RRDp::VERSION;
if ( isdigit($rrd_ver) && $rrd_ver > 1.35 ) {
  $disable_rrdtool_tag = "--disable-rrdtool-tag";
}

# use 1h alert here to be sure (it hang reading from FIFO in RB)
my $timeout = 3600;
if ( $upgrade == 1 ) {
  $timeout = $timeout * 10;
}
eval {
  my $act_time = localtime();
  local $SIG{ALRM} = sub {die "$act_time: SAN SWITCH : san.pl : died in SIG ALRM : load_san";};
  print "Alarm          : $timeout\n" if $DEBUG ;
  alarm($timeout);

  # start RRD via a pipe
  RRDp::start "$rrdtool";

  print "RRDTool version: $RRDp::VERSION \n";

  load_san();

  # close RRD pipe
  RRDp::end;
  alarm (0);
};

if ($@) {
  if ($@ =~ /died in SIG ALRM/) {
    my $act_time = localtime();
    error ("SAN SWITCH : san.pl : load_san timed out after : $timeout seconds ".__FILE__.":".__LINE__);
  }
  else {
    error ("SAN SWITCH : san.pl : load_san failed: $@ ".__FILE__.":".__LINE__);
    exit (1);
  }
}

exit (0);

sub load_san
{
  # Totals (Data,Frame)
  my @switches_a = <$wrkdir/*\/SAN-*>;
  my @switches_all;
  foreach my $sw_n (@switches_a) {
    chomp $sw_n;
    if ( $sw_n =~ "SAN-BRCD" || $sw_n =~ "SAN-CISCO" ) {
      push(@switches_all, "$sw_n\n");
    }
  }

  my $count_brocade_switches = @switches_all;

  print "Switches found : $count_brocade_switches\n";

  if ( $count_brocade_switches > 1 ) {
    draw_san_total(\@switches_all);

    # Totals health status
    my @total_health_st;
    my $table_legend = "";
    my $tab_indx     = 0;

    foreach my $switch_name (@switches_all) {
      chomp $switch_name;
      $tab_indx++;
      $switch_name =~ s/^$wrkdir\///g;
      $switch_name =~ s/\/SAN-BRCD$//g;
      $switch_name =~ s/\/SAN-CISCO$//g;

      my $sw_table = "$webdir/$switch_name/health_status.html";

      #open(HS, "< $sw_table") || error ("file does not exists : $sw_table ".__FILE__.":".__LINE__) && return 0;
      open(HS, "< $sw_table") || error ("file does not exists : $sw_table ".__FILE__.":".__LINE__);
      my @sw_table_lines = <HS>;
      my $table_line = "@sw_table_lines";
      close (HS);

      my ($html_head, $table, $legend) = split("<br><br><br>",$table_line);
      $table_legend = $legend;

      #if ( $tab_indx == 1 ) { push(@total_health_st, "$html_head\n<br><br><br><center><b>$switch_name</b></center><br>\n$table\n"); }
      #else { push(@total_health_st, "<br><br><br><center><b>$switch_name</b></center><br>$table\n"); }
      push(@total_health_st, "<br><br><br><center><b>$switch_name</b></center><br>$table\n");
    }
    push(@total_health_st, "<br><br><br>\n$table_legend\n");

    open(HST, "> $webdir/total_health_status.html") || error ("file does not exists : $webdir/total_health_status.html ".__FILE__.":".__LINE__) && return 0;
    print HST @total_health_st;
    close (HST);
  }


  # Totals (Fabric)
  my @fabric_all   = <$wrkdir/*\/fabric.txt>;
  @fabric_all      = sort @fabric_all;
  my $fabric_count = 0;
  my @fabric;
  my @fabrics_names;
  my @fabric_all_data;
  my @fabric_legend;
  my @fabric_vsan_legend;

  foreach my $line (@fabric_all) {
    chomp $line;

    # Logical fabric is supported only for SAN brocade! SAN cisco use only vsans!
    my $path_to_sw = $line;
    $path_to_sw =~ s/fabric\.txt$//;
    if ( -f "$path_to_sw/SAN-CISCO" ) { next; }

    open(FA, "< $line") || error ("file does not exists : $line ".__FILE__.":".__LINE__) && return 0;
    my $line_l = <FA>;
    close (FA);

    chomp $line_l;
    push @fabric, "$line_l\n";
    my ($prim_wwn, $sw_wwn, $sw_name, $fab_name) = split(",",$line_l);
    if ( $prim_wwn eq $sw_wwn ) { $fabric_count++; }
    if ( defined $fab_name && $fab_name ne '' ) {
      push @fabrics_names, "$prim_wwn,$sw_wwn,$sw_name,$fab_name\n";
    }
    else {
      push @fabrics_names, "$prim_wwn,$sw_wwn,$sw_name,\n";
    }
  }
  @fabric = sort @fabric;

  if ( $fabric_count > 0 ) {
    my $prim_wwn_last = "";
    my $prim_wwn_indx = 0;

    foreach my $line_fab (@fabric) {
      chomp $line_fab;
      my ($prim_wwn, $sw_wwn, $sw_name, undef) = split(",",$line_fab);

      if ( $prim_wwn ne $prim_wwn_last ) {
        $prim_wwn_indx++;
      }

      my $fabric_name      = "";
      my $fabric_name_last = "";
      my @fab_name_lines   = grep {/^$prim_wwn,/} @fabrics_names;

      foreach my $line_f (@fab_name_lines) {
        chomp $line_f;
        my ($prim_wwn, $sw_wwn, $sw_name, $fab_n) = split(",",$line_f);
        if ( defined $fab_n && $fab_n ne '' && $fabric_name eq '' ) {
          $fabric_name = $fab_n;
        }
        if ( defined $fab_n && $fab_n ne '' ) {
          $fabric_name_last = $fab_n;
        }
        if ( defined $fabric_name && $fabric_name ne '' && defined $fabric_name_last && $fabric_name_last ne '' && $fabric_name ne $fabric_name_last ) {
          error ("Switches in same Fabric haven't same Fabric name in etc/san-list.cfg! ".__FILE__.":".__LINE__);
        }
      }

      if ( ! defined $fabric_name || $fabric_name eq '' ) {
        $fabric_name = "Fabric_$prim_wwn_indx";
      }

      open(FBR, "< $wrkdir/$sw_name/PORTS.cfg") || error ("file does not exists : $wrkdir/$sw_name/PORTS.cfg ".__FILE__.":".__LINE__) && return 0;
      my @files = <FBR>;
      close (FBR);

      my $ports_found = 0;
      foreach my $line (@files) {
        chomp($line);
        my ( $port_name, $rrd ) = split(" : ",$line);
        $ports_found++;

        if ( $rrd eq '' ) { next; }
        push @fabric_legend, "$fabric_name,$sw_name,$port_name,$rrd\n";
        push @fabric_all_data, "$fabric_name,$sw_name,$port_name,$rrd\n";
      }
      if ( $ports_found == 0 ) {
        error ("Could not find ports for $sw_name in $wrkdir/$sw_name/PORTS.cfg ".__FILE__.":".__LINE__);
        return 0;
      }
      $prim_wwn_last = $prim_wwn;
    }
    #print @fabric_all_data;
    #draw_san_fabric(\@fabric_all_data);
  }


  # Totals (vSAN Fabric)
  my @vsan_fabric_all   = <$wrkdir/*\/vsan.txt>;
  @vsan_fabric_all      = sort @vsan_fabric_all;
  my @vsan_fabric;
  foreach my $vsan_line (@vsan_fabric_all) {
    chomp $vsan_line;

    open(VFA, "< $vsan_line") || error ("file does not exists : $vsan_line ".__FILE__.":".__LINE__) && return 0;
    my @vsan_lines_l = <VFA>;
    close (VFA);

    foreach my $vsan_line_l (@vsan_lines_l) {
      chomp $vsan_line_l;
      my ($prim_wwn, $sw_wwn, $sw_name, $vsan_id, $vfab_name, $port_name, $rrd_file) = split(" : ",$vsan_line_l);
      if ( -f "$wrkdir/$sw_name/SAN-BRCD" && -f "$wrkdir/$sw_name/fabric.txt" ) {
        my ($fab_line) = grep {/,$sw_name,/} @fabric_legend;
        my ($fab_name, undef) = split(",",$fab_line);
        if ( defined $fab_name && $fab_name ne '' ) {
          $vsan_line_l = "$fab_name-VF-$vsan_id : $sw_wwn : $sw_name : $vsan_id : $fab_name-VF-$vsan_id : $port_name : $rrd_file";
        }
      }
      push @vsan_fabric, "$vsan_line_l\n";
    }
  }
  @vsan_fabric = sort @vsan_fabric;

  my $vsan_fabric_count = 0;
  my $last_vsan_found   = "";
  foreach (@vsan_fabric) {
    chomp $_;
    my ($prim_fab_wwn, undef) = split(" : ",$_);
    if ($prim_fab_wwn eq $last_vsan_found) {next};
    $last_vsan_found = $prim_fab_wwn;
    $vsan_fabric_count++;
  }

  if ( $vsan_fabric_count > 0 ) {
    my $tot_fab_count = $fabric_count + $vsan_fabric_count;
    print "Fabrics found  : $tot_fab_count (vSAN = $vsan_fabric_count)\n";
  }
  else {
   print "Fabrics found  : $fabric_count\n";
  }

  if ( $vsan_fabric_count > 0 ) {
    my $vsan_fab_idx   = 0;
    my $last_prim_wwn  = "";
    my $last_vfab_name = "";
    foreach (@vsan_fabric) {
      chomp $_;
      my ($prim_wwn, undef, $sw_name, $vsan_id, $vfab_name, $port_name, $rrd_file) = split(" : ",$_);
      if ( $prim_wwn ne $last_prim_wwn || $vfab_name ne $last_vfab_name ) { $vsan_fab_idx++; }
      $last_prim_wwn  = $prim_wwn;
      $last_vfab_name = $vfab_name;

      if ( -f $rrd_file ) {
        push @fabric_vsan_legend, "$vfab_name,$sw_name,$port_name,$rrd_file\n";
        push @fabric_all_data, "$vfab_name,$sw_name,$port_name,$rrd_file\n";
      }
      else {
        error ("Can't find rrd file for $port_name! $rrd_file ".__FILE__.":".__LINE__);
      }
    }
  }
  my $fabric_all_count = @fabric_all_data;
  if ( $fabric_all_count > 0 ) {
    #print @fabric_all_data;
    draw_san_fabric(\@fabric_all_data);
  }


  # Fabric configuration table
  open(FC, "> $webdir/fabric_cfg.html") || error ("file does not exists : $webdir/fabric_cfg.html ".__FILE__.":".__LINE__) && return 0;
  my $logical_fabrics = "";
  ($logical_fabrics)  = @fabric_legend;

  if ( defined $logical_fabrics && $logical_fabrics ne '' ) {
    my $last_found_sec = "";
    print FC "<br><br><br><br><center><table frame=\"box\"><tr>\n";
    foreach my $line (@fabric_legend) {
      chomp $line;
      my ($prim_wwn, undef) = split(",",$line);

      if ( $prim_wwn eq $last_found_sec ) { next; }
      $last_found_sec = $prim_wwn;

      #print FC "<td><table cellpadding=\"5\" frame=\"void\" rules=\"rows\">\n";
      print FC "<td valign=\"top\"><table rules=\"rows\">\n";
      print FC "<tr><th style=\"text-align:center; padding:10px 20px 10px 20px;\"><font color=\"#003399\"><b>$prim_wwn</b></font></th></tr>\n";
      my $last_found_fir = "";
      my @fabric_act = grep {/^$prim_wwn,/} @fabric_all_data;
      foreach my $line_f (@fabric_act) {
        chomp $line_f;
        my (undef, $sw_name, undef) = split(",",$line_f);

        if ( "$prim_wwn,$sw_name" eq $last_found_fir ) { next; }
        $last_found_fir = "$prim_wwn,$sw_name";
        print FC "<tr><td style=\"text-align:center; padding:7px 20px 7px 20px;\"><font color=\"black\"><a href=\"/stor2rrd-cgi/detail.sh?host=$sw_name&type=Frame&name=$sw_name&storage=SAN-BRCD&item=san_io_sum&gui=1&none=none\"><b>$sw_name</b></a></font></td></tr>\n";
      }
      print FC "</table></td>\n";
    }
    print FC "</table></tr></center>\n";
  }

  my $fabric_vsan_legend_count = @fabric_vsan_legend;
  if ( $fabric_vsan_legend_count > 0 ) {
    print FC "<br><br><center><b>vSAN</b><br><table frame=\"box\"><tr>\n";
    my $last_found_sec_vsan = "";
    foreach my $line (@fabric_vsan_legend) {
      chomp $line;
      my ($prim_wwn, undef) = split(",",$line);

      if ( $prim_wwn eq $last_found_sec_vsan ) { next; }
      $last_found_sec_vsan = $prim_wwn;

      #print FC "<td><table cellpadding=\"5\" frame=\"void\" rules=\"rows\">\n";
      print FC "<td valign=\"top\"><table rules=\"rows\">\n";
      print FC "<tr><th colspan=\"2\" style=\"text-align:center; padding:10px 20px 10px 20px;\"><font color=\"#003399\"><b>$prim_wwn</b></font></th></tr>\n";
      my $last_found_fir = "";
      my @fabric_act = grep {/^$prim_wwn,/} @fabric_all_data;
      foreach my $line_f (@fabric_act) {
        chomp $line_f;
        my (undef, $sw_name, $port) = split(",",$line_f);

        print FC "<tr><td style=\"text-align:center; padding:7px 20px 7px 20px;\"><font color=\"black\"><a href=\"/stor2rrd-cgi/detail.sh?host=$sw_name&type=Frame&name=$sw_name&storage=SAN-BRCD&item=san_io_sum&gui=1&none=none\"><b>$sw_name</b></a></font></td><td style=\"text-align:center; padding:7px 20px 7px 20px;\"><font color=\"black\"><a href=\"/stor2rrd-cgi/detail.sh?host=$sw_name&type=SANPORT&name=$port&storage=SAN-BRCD&item=san&gui=1&none=none\"><b>$port</b></a></font></td></tr>\n";
      }
      print FC "</table></td>\n";
    }
    print FC "</table></tr></center>\n";
  }

  close (FC);



  # Totals (ISL)
  my @isl_all   = <$wrkdir/*\/ISL.txt>;
  my $isl_count = 0;
  my @isl_rrd_files;

  foreach my $line (@isl_all) {
    chomp $line;

    open(ISL, "< $line") || error ("file does not exists : $line ".__FILE__.":".__LINE__) && return 0;
    my @lines = <ISL>;
    close (ISL);

    foreach my $isl_line (@lines) {
      chomp $isl_line;
      $isl_count++;
      push @isl_rrd_files, "$isl_line\n";
    }
  }
  print "ISL found      : $isl_count\n";
  if ( $isl_count > 0 ) {
    draw_san_isl(\@isl_rrd_files);
  }


  # Configuration summary
  #if ( $count_brocade_switches > 1 ) {
  if ( $count_brocade_switches > 0 ) {
    my $san_conf = "$webdir/san_configuration.html";
    my @all_switches_cfg;
    open(SANC, "> $san_conf") || error( "Couldn't open file $san_conf $!" . __FILE__ . ":" . __LINE__ ) && next;
    print SANC "<br><br><br>\n";
    print SANC "<center>\n";
    print SANC "<b>Switches:</b>\n";
    print SANC "<table class =\"tabcfgsum tablesorter tablesortercfgsum\">\n";
    print SANC "<thead>\n";
    print SANC "<tr>\n";
    print SANC "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Fabric Name</th>\n";
    print SANC "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Switch Name</th>\n";
    print SANC "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">IP Address</th>\n";
    print SANC "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">World Wide Name</th>\n";
    print SANC "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Model</th>\n";
    print SANC "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Speed</th>\n";
    print SANC "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">OS Version</th>\n";
    print SANC "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Days Up</th>\n";
    print SANC "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Serial Number</th>\n";
    print SANC "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Total Ports</th>\n";
    print SANC "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">ISL Ports</th>\n";
    print SANC "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Unused Ports</th>\n";
    print SANC "</tr>\n";
    print SANC "</thead>\n";
    print SANC "<tbody>\n";

    foreach my $switch_name (@switches_all) {
      chomp $switch_name;
      $switch_name =~ s/^$wrkdir\///g;
      $switch_name =~ s/\/SAN-BRCD$//g;
      $switch_name =~ s/\/SAN-CISCO$//g;
      if ( -f "$wrkdir/$switch_name/config.cfg" ) {
        open(SCFG, "< $wrkdir/$switch_name/config.cfg") || error( "Couldn't open file $wrkdir/$switch_name/config.cfg $!" . __FILE__ . ":" . __LINE__ ) && next;
        my @sw_cfg = <SCFG>;
        close(SCFG);

        # all configuration variables per switch
        my $switch_ip              = "";
        my $switch_wwn             = "";
        my $switch_model           = "";
        my $switch_speed           = "";
        my $switch_os_version      = "";
        my $switch_fabric_name     = "";
        my $switch_days_up         = "";
        my $switch_serial_number   = "";
        my $switch_total_ports     = "";
        my $switch_unused_ports    = "";
        my $switch_total_isl_ports = "";

        foreach (@sw_cfg) {
          chomp $_;
          if ( $_ =~ "^switch_ip=" )              { $switch_ip = $_; $switch_ip =~ s/^switch_ip=//; }
          if ( $_ =~ "^switch_wwn=" )             { $switch_wwn = $_; $switch_wwn =~ s/^switch_wwn=//; }
          if ( $_ =~ "^switch_model=" )           { $switch_model = $_; $switch_model =~ s/^switch_model=//; }
          if ( $_ =~ "^switch_speed=" )           { $switch_speed = $_; $switch_speed =~ s/^switch_speed=//; }
          if ( $_ =~ "^switch_os_version=" )      { $switch_os_version = $_; $switch_os_version =~ s/^switch_os_version=//; }
          if ( $_ =~ "^switch_fabric_name=" )     { $switch_fabric_name = $_; $switch_fabric_name =~ s/^switch_fabric_name=//; }
          if ( $_ =~ "^switch_days_up=" )         { $switch_days_up = $_; $switch_days_up =~ s/^switch_days_up=//; }
          if ( $_ =~ "^switch_serial_number=" )   { $switch_serial_number = $_; $switch_serial_number =~ s/^switch_serial_number=//; }
          if ( $_ =~ "^switch_total_ports=" )     { $switch_total_ports = $_; $switch_total_ports =~ s/^switch_total_ports=//; }
          if ( $_ =~ "^switch_unused_ports=" )    { $switch_unused_ports = $_; $switch_unused_ports =~ s/^switch_unused_ports=//; }
          if ( $_ =~ "^switch_total_isl_ports=" ) { $switch_total_isl_ports = $_; $switch_total_isl_ports =~ s/^switch_total_isl_ports=//; }

          my $fab_line = "";
          ($fab_line) = grep {/,$switch_name,/} @fabric_legend;
          if ( defined $fab_line && $fab_line ne '' ) {
            my $fab_name = "";
            ($fab_name, undef) = split(",",$fab_line);
            if ( defined $fab_name && $fab_name ne '' ) {
              $switch_fabric_name = $fab_name;
            }
          }
        }

        print SANC "\n";
        print SANC "<tr>\n";
        print SANC "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_fabric_name</td>\n";
        print SANC "<td style=\"text-align:center; color:black;\" nowrap=\"\"><a href=\"$switch_name/config.html\"><b>$switch_name</b></td>\n";
        print SANC "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_ip</td>\n";
        print SANC "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_wwn</td>\n";
        print SANC "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_model</td>\n";
        print SANC "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_speed</td>\n";
        print SANC "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_os_version</td>\n";
        print SANC "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_days_up</td>\n";
        print SANC "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_serial_number</td>\n";
        print SANC "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_total_ports</td>\n";
        print SANC "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_total_isl_ports</td>\n";
        print SANC "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_unused_ports</td>\n";
        print SANC "</tr>\n";

        my $san_type = "";
        if ( -f "$wrkdir/$switch_name/SAN-BRCD")  { $san_type = "BRCD"; }
        if ( -f "$wrkdir/$switch_name/SAN-CISCO") { $san_type = "CISCO"; }
        if ( defined $switch_fabric_name && $switch_fabric_name ne '' ) {
          push(@all_switches_cfg, "$switch_fabric_name,$switch_name,$san_type,$switch_total_ports,$switch_total_isl_ports,$switch_unused_ports\n");
        }
      }
    }
    print SANC "</tbody>\n";
    print SANC "</table>\n";


    # per fabrics
    if (@all_switches_cfg) {
      print SANC "<br><br><br>\n";
      print SANC "<b>Fabrics:</b>\n";
      print SANC "<table class =\"tabcfgsum tablesorter tablesortercfgsum\">\n";
      print SANC "<thead>\n";
      print SANC "<tr>\n";
      print SANC "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Fabric Name</th>\n";
      print SANC "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Total Ports</th>\n";
      print SANC "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">ISL Ports</th>\n";
      print SANC "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Unused Ports</th>\n";
      print SANC "</tr>\n";
      print SANC "</thead>\n";
      print SANC "<tbody>\n";
      @all_switches_cfg = sort @all_switches_cfg;
      my $last_fab_name = "";

      foreach (@all_switches_cfg) {
        chomp $_;
        my ($fab_name, undef) = split(",", $_);

        if ( $fab_name eq $last_fab_name ) { next; }
        $last_fab_name = $fab_name;

        my @fab_arr = grep {/^$fab_name,/} @all_switches_cfg;
        my $fab_tot_ports = "0";
        my $fab_isl_ports = "0";
        my $fab_unu_ports = "0";
        foreach my $fab_line (@fab_arr) {
          chomp $fab_line;
          my ($fab, $sw_name, $sw_type, $sw_tot_ports, $sw_isl_ports, $sw_unu_ports) = split(",", $fab_line);
          if ( defined $sw_tot_ports && $sw_tot_ports ne '' && defined $sw_isl_ports && $sw_isl_ports ne '' && defined $sw_unu_ports && $sw_unu_ports ne '' ) {
            if ( isdigit($sw_tot_ports) && isdigit($sw_isl_ports) && isdigit($sw_unu_ports) ) {
              $fab_tot_ports = $fab_tot_ports + $sw_tot_ports;
              $fab_isl_ports = $fab_isl_ports + $sw_isl_ports;
              $fab_unu_ports = $fab_unu_ports + $sw_unu_ports;
            }
            else {
              error ("Some port value is not digit. SAN global configuration can have bad values! : $! ".__FILE__.":".__LINE__) && next;
            }
          }
        }
        print SANC "<tr>\n";
        print SANC "<td style=\"text-align:center; color:black;\" nowrap=\"\">$fab_name</td>\n";
        print SANC "<td style=\"text-align:center; color:black;\" nowrap=\"\">$fab_tot_ports</td>\n";
        print SANC "<td style=\"text-align:center; color:black;\" nowrap=\"\">$fab_isl_ports</td>\n";
        print SANC "<td style=\"text-align:center; color:black;\" nowrap=\"\">$fab_unu_ports</td>\n";
        print SANC "</tr>\n";
      }
      print SANC "</tbody>\n";
      print SANC "</table>\n";
    }

    # per vsan and virtual fabric
    if (@fabric_vsan_legend) {
      print SANC "<br><br><br>\n";
      print SANC "<b>VSANs, Virtual Fabrics:</b>\n";
      print SANC "<table class =\"tabcfgsum tablesorter tablesortercfgsum\">\n";
      print SANC "<thead>\n";
      print SANC "<tr>\n";
      print SANC "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Fabric Name</th>\n";
      print SANC "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Total Ports</th>\n";
      print SANC "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">ISL Ports</th>\n";
      print SANC "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Unused Ports</th>\n";
      print SANC "</tr>\n";
      print SANC "</thead>\n";
      print SANC "<tbody>\n";

      my $last_fab_name = "";

      foreach (@fabric_vsan_legend) {
        chomp $_;
        my ($fab_name, undef) = split(",", $_);

        if ( $fab_name eq $last_fab_name ) { next; }
        $last_fab_name = $fab_name;

        my @fab_arr = grep {/^$fab_name,/} @fabric_vsan_legend;
        my $fab_tot_ports = "0";
        my $fab_isl_ports = "0";
        foreach my $fab_line (@fab_arr) {
          chomp $fab_line;
          $fab_tot_ports++;
          my (undef, undef, undef, $rrd_file) = split(",", $fab_line);
          if (@isl_rrd_files) {
            my ($grep_port_in_isl_arr) = grep {/,$rrd_file,/} @isl_rrd_files;
            if (defined $grep_port_in_isl_arr && $grep_port_in_isl_arr ne '' ) { $fab_isl_ports++; }
          }
        }
        print SANC "<tr>\n";
        print SANC "<td style=\"text-align:center; color:black;\" nowrap=\"\">$fab_name</td>\n";
        print SANC "<td style=\"text-align:center; color:black;\" nowrap=\"\">$fab_tot_ports</td>\n";
        print SANC "<td style=\"text-align:center; color:black;\" nowrap=\"\">$fab_isl_ports</td>\n";
        print SANC "<td style=\"text-align:center; color:black;\" nowrap=\"\">UN</td>\n";
        print SANC "</tr>\n";
      }
      print SANC "</tbody>\n";
      print SANC "</table>\n";
    }

    print SANC "</center>\n";
    close(SANC);
  }

}

sub draw_san_isl
{
  my $fa     = shift;
  my @isl = @{$fa};
  my $item   = "";

  $item = "san_isl_data_in";
  draw_all_isl(\@isl,$item);
  $item = "san_isl_data_out";
  draw_all_isl(\@isl,$item);
  $item = "san_isl_frames_in";
  draw_all_isl(\@isl,$item);
  $item = "san_isl_frames_out";
  draw_all_isl(\@isl,$item);
  $item = "san_isl_frame_size_in";
  draw_all_isl(\@isl,$item);
  $item = "san_isl_frame_size_out";
  draw_all_isl(\@isl,$item);
  $item = "san_isl_credits";
  draw_all_isl(\@isl,$item);
  $item = "san_isl_crc_errors";
  draw_all_isl(\@isl,$item);
}

sub draw_all_isl
{
  my $fa     = shift;
  my $item   = shift;
  my @isl = @{$fa};

  print "creating graph : Totals:ISL:$item:d\n" if $DEBUG ;
  draw_graph_isl ("day","d","MINUTE:60:HOUR:2:HOUR:4:0:%H",\@isl,$item);

  print "creating graph : Totals:ISL:$item:w\n" if $DEBUG ;
  draw_graph_isl ("week","w","HOUR:8:DAY:1:DAY:1:0:%a",\@isl,$item);

  print "creating graph : Totals:ISL:$item:m\n" if $DEBUG ;
  draw_graph_isl ("4 weeks","m","DAY:1:DAY:2:DAY:2:0:%d",\@isl,$item);

  print "creating graph : Totals:ISL:$item:y\n" if $DEBUG ;
  draw_graph_isl ("year","y","MONTH:1:MONTH:1:MONTH:1:0:%b",\@isl,$item);

  return 0;
}

sub draw_graph_isl
{
  my $text           = shift;
  my $type_gr        = shift;
  my $xgrid          = shift;
  my $fa             = shift;
  my $item           = shift;
  my @isl            = @{$fa};
  my $t              = "COMMENT: ";
  my $t2             = "COMMENT:\\n";
  my $last           = "COMMENT: ";
  my $act_time       = localtime();
  my $act_time_u     = time();
  my $req_time       = 0;
  my $value_short    = "";
  my $value_long     = "";
  my $val            = 1;
  my $units_exponent = "--units-exponent=1.00";

  my $totals_tmp_dir = "$tmp_dir/SAN-totals";
  my $tmp_file       = "$totals_tmp_dir/$item-$type_gr.cmd";

  if ( ! -d $totals_tmp_dir ) {
    mkdir("$totals_tmp_dir", 0755) || die "$act_time: Cannot mkdir $totals_tmp_dir: $!";
  }

  if ( $item eq "san_isl_data_in" )         { $value_short= "MB/sec"; $value_long = "MBytes per second"; $val=(1024 * 1024) / 4;}
  if ( $item eq "san_isl_data_out" )        { $value_short= "MB/sec"; $value_long = "MBytes per second"; $val=(1024 * 1024) / 4;}
  if ( $item eq "san_isl_frames_in" )       { $value_short= "frames/sec"; $value_long = "Frames per second"; $val=1; $units_exponent = "--interlaced";}
  if ( $item eq "san_isl_frames_out" )      { $value_short= "frames/sec"; $value_long = "Frames per second"; $val=1; $units_exponent = "--interlaced";}
  if ( $item eq "san_isl_frame_size_in" )   { $value_short= "bytes"; $value_long = "Bytes per frame"; $val=4; $units_exponent = "--interlaced";}
  if ( $item eq "san_isl_frame_size_out" )  { $value_short= "bytes"; $value_long = "Bytes per frame"; $val=4; $units_exponent = "--interlaced";}
  if ( $item eq "san_isl_credits" )         { $value_short= "credits"; $value_long = "missing credits in % of time"; $val=1;}
  if ( $item eq "san_isl_crc_errors" )      { $value_short= "errors"; $value_long = "errors"; $val=1;}
  if ( $item eq "san_isl_encoding_errors" ) { $value_short= "errors"; $value_long = "errors"; $val=1;}

  my $comment        = sprintf ("%-16s","[$value_short]");
  my $i              = 0;
  my $j              = 0;
  my $cmd            = "";
  my $vertical_label = "--vertical-label=\\\"$value_long\\\"";
  my $header         = "SAN SWITCH : Totals : Transferred data last $text";

  $cmd .= "$graph_cmd \\\"$name_out\\\"";
  $cmd .= " --title \\\"$header\\\"";
  $cmd .= " --start now-1$type_gr";
  $cmd .= " --end now-1$type_gr+1$type_gr";
  $cmd .= " --imgformat PNG";
  $cmd .= " --slope-mode";
  $cmd .= " --width=400";
  $cmd .= " --height=150";
  $cmd .= " --step=$STEP";
  $cmd .= " --lower-limit=0.00";
  $cmd .= " --color=BACK#$pic_col";
  $cmd .= " --color=SHADEA#$pic_col";
  $cmd .= " --color=SHADEB#$pic_col";
  $cmd .= " --color=CANVAS#$pic_col";
  $cmd .= " --alt-autoscale-max";
  $cmd .= " --interlaced";
  $cmd .= " --upper-limit=0.1";
  $cmd .= " $vertical_label";
  $cmd .= " $units_exponent";
  $cmd .= " NO_LEGEND";
  $cmd .= " $disable_rrdtool_tag";
  $cmd .= " --x-grid=$xgrid";
  $cmd .= " --alt-y-grid";
  $cmd .= " $font_def_normal";
  $cmd .= " $font_tit_normal";
  $cmd .= " COMMENT:\\\"$comment                        Avg         Max\\l\\\"";

  my $host_space    = "";
  my $tot_val_index = 0;
  my $col_indx      = 0; # on purpose to start with the blue one
  my $line_indx     = 0; # place enter evry 3rd line
  my $last_fabric_n = "";

  foreach my $line_l (@isl) {
    chomp $line_l;
    $tot_val_index++;
    my ($port_name, $rrd, $sw_name, $to_port, $to_switch) = split(",",$line_l);
    $to_port   =~ s/to_port=//g;
    $to_switch =~ s/to_switch=//g;

    # add spaces to volume name to have 15 chars total (for formating graph legend)
    $host_space = "$sw_name,$port_name,$to_port,$to_switch";
    $host_space = sprintf ("%-10s","$host_space");

    my $isl_port_name = "$sw_name-$port_name -> $to_switch-$to_port";
    $isl_port_name = sprintf ("%-10s","$isl_port_name");

    my $legend_heading = "Ports $delimiter $comment $delimiter Avg $delimiter Max ";

    if ( $port_name eq '' || $rrd eq '' )          { next; }
    if ( ! -f "$rrd" )                             { error ("Could not find $port_name file: $rrd ".__FILE__.":".__LINE__); next; }

    # avoid old ports which do not exist in the period
    my $rrd_upd_time = (stat("$rrd"))[9];
    if ( $rrd_upd_time < $req_time ) { next; }
    my $time_first = find_real_data_start($rrd);

    my $item_rrd  = "";
    my $item_rrd2 = "";

    if ( $item eq "san_isl_data_in" )         { $item_rrd = "bytes_rec"; }
    if ( $item eq "san_isl_data_out" )        { $item_rrd = "bytes_tra"; }
    if ( $item eq "san_isl_frames_in" )       { $item_rrd = "frames_rec"; }
    if ( $item eq "san_isl_frames_out" )      { $item_rrd = "frames_tra"; }
    if ( $item eq "san_isl_frame_size_in" )   { $item_rrd = "frames_rec"; $item_rrd2 = "bytes_rec"; }
    if ( $item eq "san_isl_frame_size_out" )  { $item_rrd = "frames_tra"; $item_rrd2 = "bytes_tra"; }
    if ( $item eq "san_isl_credits" )         { $item_rrd = "swFCPortNoTxCredits"; }
    if ( $item eq "san_isl_crc_errors" )      { $item_rrd = "swFCPortRxCrcs"; }
    if ( $item eq "san_isl_encoding_errors" ) { $item_rrd = "swFCPortRxEncOutFrs"; }

    my $gtype="AREA";
    if ( $tot_val_index > 1 ) { $gtype="STACK"; }

    # build RRDTool cmd
    if ( $item eq "san_isl_credits" || $item eq "san_isl_frame_size_in" || $item eq "san_isl_frame_size_out" ) {
      if ( $item eq "san_isl_credits" ) {
        $val = 0.0000025;
        $cmd .= " DEF:value${i}=\\\"$rrd\\\":$item_rrd:AVERAGE";
        $cmd .= " CDEF:valmb1_${i}=value${i},$val,*";
        $cmd .= " CDEF:valmb2_${i}=valmb1_${i},60,/";
        $cmd .= " CDEF:valmb3_${i}=valmb2_${i},100,*";
        $cmd .= " CDEF:valmb${i}=valmb3_${i},1000,GT,UNKN,valmb3_${i},IF";
        $cmd .= " $gtype:valmb${i}$color[$col_indx]:\\\"$isl_port_name\\\"";
      }
      if ( $item eq "san_isl_frame_size_in" || $item eq "san_isl_frame_size_out" ) {
        $cmd .= " DEF:value1_${i}=\\\"$rrd\\\":$item_rrd:AVERAGE";
        $cmd .= " DEF:value2_${i}=\\\"$rrd\\\":$item_rrd2:AVERAGE";
        $cmd .= " CDEF:valmb1_${i}=value2_${i},$val,*";
        $cmd .= " CDEF:valmb${i}=valmb1_${i},value1_${i},/";
        $cmd .= " LINE1:valmb${i}$color[$col_indx]:\\\"$isl_port_name\\\"";

      }
    }
    else {
      $cmd .= " DEF:value${i}=\\\"$rrd\\\":$item_rrd:AVERAGE";
      $cmd .= " CDEF:valmb${i}=value${i},$val,/";
      $cmd .= " $gtype:valmb${i}$color[$col_indx]:\"$isl_port_name\"";
    }

    if ( $item eq "san_isl_frames_in" || $item eq "san_isl_frames_out" || $item eq "san_isl_frame_size_in" || $item eq "san_isl_frame_size_out" ) {
      $cmd .= " PRINT:valmb${i}:AVERAGE:\\\"%8.0lf $delimiter $host_space $delimiter $legend_heading $delimiter $color[$col_indx]\\\"";
      $cmd .= " PRINT:valmb${i}:MAX:\\\" %8.0lf $delimiter test $delimiter SAN-BRCD\\\"";
      $cmd .= " GPRINT:valmb${i}:AVERAGE:\\\"%8.0lf \\\"";
      $cmd .= " GPRINT:valmb${i}:MAX:\\\" %8.0lf \\\"";
    }
    if ( $item eq "san_isl_data_in" || $item eq "san_isl_data_out" ) {
      $cmd .= " PRINT:valmb${i}:AVERAGE:\\\"%8.1lf $delimiter $host_space $delimiter $legend_heading $delimiter $color[$col_indx]\\\"";
      $cmd .= " PRINT:valmb${i}:MAX:\\\" %8.1lf $delimiter test $delimiter SAN-BRCD\\\"";
      $cmd .= " GPRINT:valmb${i}:AVERAGE:\\\"%8.1lf \\\"";
      $cmd .= " GPRINT:valmb${i}:MAX:\\\" %8.1lf \\\"";
    }
    if ( $item eq "san_isl_credits" || $item eq "san_isl_crc_errors" ) {
      $cmd .= " PRINT:valmb${i}:AVERAGE:\\\"%8.1lf $delimiter $host_space $delimiter $legend_heading $delimiter $color[$col_indx]\\\"";
      $cmd .= " PRINT:valmb${i}:MAX:\\\" %8.1lf $delimiter test $delimiter SAN-BRCD\\\"";
      $cmd .= " GPRINT:valmb${i}:AVERAGE:\\\"%8.1lf \\\"";
      $cmd .= " GPRINT:valmb${i}:MAX:\\\" %8.1lf \\\"";
    }

    # --> it does not work ideally with newer RRDTOOL (1.2.30 --> it needs to be separated by cariage return here)
    $cmd .= " COMMENT:\\\"\\l\\\"";

    $i++;
    $col_indx++;
    if ( $col_indx > $color_max ) {
      $col_indx = 0;
    }
  }

  $cmd .= " HRULE:0#000000";
  # $cmd .= " VRULE:0#000000";  --> it is causing sigsegv on linuxeS
  $cmd =~ s/\\"/"/g;

  open(FH, "> $tmp_file") || error ("Can't open $tmp_file : $! ".__FILE__.":".__LINE__) && return 0;
  print FH "$cmd\n";
  close (FH);
}

sub draw_san_fabric
{
  my $fa     = shift;
  my @fabric = @{$fa};
  my $item   = "";

  $item = "san_fabric_data_in";
  draw_all_fabric(\@fabric,$item);
  $item = "san_fabric_frames_in";
  draw_all_fabric(\@fabric,$item);
  $item = "san_fabric_credits";
  draw_all_fabric(\@fabric,$item);
  $item = "san_fabric_crc_errors";
  draw_all_fabric(\@fabric,$item);
  $item = "san_fabric_encoding_errors";
  draw_all_fabric(\@fabric,$item);
}

sub draw_all_fabric
{
  my $fa     = shift;
  my $item   = shift;
  my @fabric = @{$fa};

  print "creating graph : Totals:Fabric:$item:d\n" if $DEBUG ;
  draw_graph_fabric ("day","d","MINUTE:60:HOUR:2:HOUR:4:0:%H",\@fabric,$item);

  print "creating graph : Totals:Fabric:$item:w\n" if $DEBUG ;
  draw_graph_fabric ("week","w","HOUR:8:DAY:1:DAY:1:0:%a",\@fabric,$item);

  print "creating graph : Totals:Fabric:$item:m\n" if $DEBUG ;
  draw_graph_fabric ("4 weeks","m","DAY:1:DAY:2:DAY:2:0:%d",\@fabric,$item);

  print "creating graph : Totals:Fabric:$item:y\n" if $DEBUG ;
  draw_graph_fabric ("year","y","MONTH:1:MONTH:1:MONTH:1:0:%b",\@fabric,$item);

  return 0;
}

sub draw_graph_fabric
{
  my $text           = shift;
  my $type_gr        = shift;
  my $xgrid          = shift;
  my $fa             = shift;
  my $item           = shift;
  my @fabric         = @{$fa};
  my $t              = "COMMENT: ";
  my $t2             = "COMMENT:\\n";
  my $last           = "COMMENT: ";
  my $act_time       = localtime();
  my $act_time_u     = time();
  my $req_time       = 0;
  my $value_short    = "";
  my $value_long     = "";
  my $val            = 1;
  my $units_exponent = "--units-exponent=1.00";

  my $totals_tmp_dir = "$tmp_dir/SAN-totals";
  my $tmp_file       = "$totals_tmp_dir/$item-$type_gr.cmd";

  if ( ! -d $totals_tmp_dir ) {
    mkdir("$totals_tmp_dir", 0755) || die "$act_time: Cannot mkdir $totals_tmp_dir: $!";
  }

  if ( $item eq "san_fabric_data_in" )         { $value_short= "MB/sec"; $value_long = "MBytes per second"; $val=(1024 * 1024) / 4;}
  if ( $item eq "san_fabric_frames_in" )       { $value_short= "frames/sec"; $value_long = "Frames per second"; $val=1; $units_exponent = "--interlaced";}
  if ( $item eq "san_fabric_credits" )         { $value_short= "credits"; $value_long = "missing credits in % of time"; $val=1;}
  if ( $item eq "san_fabric_crc_errors" )      { $value_short= "errors"; $value_long = "errors"; $val=1;}
  if ( $item eq "san_fabric_encoding_errors" ) { $value_short= "errors"; $value_long = "errors"; $val=1;}

  my $comment        = sprintf ("%-16s","[$value_short]");
  my $i              = 0;
  my $j              = 0;
  my $cmd            = "";
  my $vertical_label = "--vertical-label=\\\"$value_long\\\"";
  my $header         = "SAN SWITCH : Totals : Transferred data last $text";

  $cmd .= "$graph_cmd \\\"$name_out\\\"";
  $cmd .= " --title \\\"$header\\\"";
  $cmd .= " --start now-1$type_gr";
  $cmd .= " --end now-1$type_gr+1$type_gr";
  $cmd .= " --imgformat PNG";
  $cmd .= " --slope-mode";
  $cmd .= " --width=400";
  $cmd .= " --height=150";
  $cmd .= " --step=$STEP";
  $cmd .= " --lower-limit=0.00";
  $cmd .= " --color=BACK#$pic_col";
  $cmd .= " --color=SHADEA#$pic_col";
  $cmd .= " --color=SHADEB#$pic_col";
  $cmd .= " --color=CANVAS#$pic_col";
  $cmd .= " --alt-autoscale-max";
  $cmd .= " --interlaced";
  $cmd .= " --upper-limit=0.1";
  $cmd .= " $vertical_label";
  $cmd .= " $units_exponent";
  $cmd .= " NO_LEGEND";
  $cmd .= " $disable_rrdtool_tag";
  $cmd .= " --x-grid=$xgrid";
  $cmd .= " --alt-y-grid";
  $cmd .= " $font_def_normal";
  $cmd .= " $font_tit_normal";
  $cmd .= " COMMENT:\\\"$comment   Avg         Max\\l\\\"";

  my $host_space    = "";
  my $tot_val_index = 0;
  my $col_indx      = 0; # on purpose to start with the blue one
  my $line_indx     = 0; # place enter evry 3rd line
  my $last_fabric_n = "";

  foreach my $line_l (@fabric) {
    chomp $line_l;
    $tot_val_index++;
    my ($fabric_name, undef) = split(",",$line_l);

    if ( $fabric_name eq $last_fabric_n ) { next; }
    $last_fabric_n = $fabric_name;

    my @ports_for_fabric = grep {/^$fabric_name,/} @fabric;

    # add spaces to volume name to have 15 chars total (for formating graph legend)
    $host_space = $fabric_name;
    $host_space = sprintf ("%-10s","$host_space");

    my $legend_heading = "Ports $delimiter $comment $delimiter Avg $delimiter Max ";

    my $cmd_tot_per_switch = " CDEF:tot_val${tot_val_index}=";
    my $ports_found = 0;
    foreach my $line (@ports_for_fabric) {
      chomp($line);
      my ( undef, $sw_name, $port_name, $rrd ) = split(",",$line);

      # Show BBCredits only for fc ports
      if ( $item eq "san_fabric_credits" && -f "$wrkdir/$sw_name/SAN-CISCO" ) {
        my $go_bbc = 0;
        if ( $port_name =~ "^portfc" || $port_name =~ "portChannel" ) { $go_bbc = 1; }
        if ( $go_bbc == 0 ) { next; }
      }

      $ports_found++;

      if ( $port_name eq '' || $rrd eq '' )          { next; }
      if ( ! -f "$rrd" )                             { error ("Could not find $port_name file: $rrd ".__FILE__.":".__LINE__); next; }

      # avoid old ports which do not exist in the period
      my $rrd_upd_time = (stat("$rrd"))[9];
      if ( $rrd_upd_time < $req_time ) { next; }
      my $time_first = find_real_data_start($rrd);

      my $item_rrd = "";

      if ( $item eq "san_fabric_data_in" )         { $item_rrd = "bytes_rec"; }
      if ( $item eq "san_fabric_frames_in" )       { $item_rrd = "frames_rec"; }
      if ( $item eq "san_fabric_credits" )         { $item_rrd = "swFCPortNoTxCredits"; }
      if ( $item eq "san_fabric_crc_errors" )      { $item_rrd = "swFCPortRxCrcs"; }
      if ( $item eq "san_fabric_encoding_errors" ) { $item_rrd = "swFCPortRxEncOutFrs"; }

      # build RRDTool cmd
      if ( $item eq "san_fabric_credits" ) {
        $val = 0.0000025;
        $cmd .= " DEF:value${i}=\\\"$rrd\\\":$item_rrd:AVERAGE";
        $cmd .= " CDEF:valb${i}=TIME,$time_first,LT,value${i},value${i},UN,0,value${i},IF,IF";
        $cmd .= " CDEF:valmb1_${i}=valb${i},$val,*";
        $cmd .= " CDEF:valmb2_${i}=valmb1_${i},60,/";
        $cmd .= " CDEF:valmb3_${i}=valmb2_${i},100,*";
        $cmd .= " CDEF:valmb${i}=valmb3_${i},1000,GT,UNKN,valmb3_${i},IF";
      }
      else {
        $cmd .= " DEF:value${i}=\\\"$rrd\\\":$item_rrd:AVERAGE";
        $cmd .= " CDEF:valb${i}=TIME,$time_first,LT,value${i},value${i},UN,0,value${i},IF,IF";
        $cmd .= " CDEF:valmb${i}=valb${i},$val,/";
      }

      if ( $ports_found == 1) {
        $cmd_tot_per_switch .= "valmb${i},0,+";
      }
      else {
        $cmd_tot_per_switch .= ",valmb${i},+";
      }

      $i++;
    }

    my $gtype="AREA";

    if ( $tot_val_index > 1 )                    { $gtype="STACK"; }
    #if ( $item eq "san_fabric_credits" )         { $gtype="LINE1"; }
    #if ( $item eq "san_fabric_crc_errors" )      { $gtype="LINE1"; }
    #if ( $item eq "san_fabric_encoding_errors" ) { $gtype="LINE1"; }

    $cmd .= "$cmd_tot_per_switch";
    $cmd .= " $gtype:tot_val${tot_val_index}$color[$col_indx]:\"$host_space\"";

    if ( $item eq "san_fabric_frames_in" ) {
      $cmd .= " PRINT:tot_val${tot_val_index}:AVERAGE:\\\"%8.0lf $delimiter $host_space $delimiter $legend_heading $delimiter $color[$col_indx]\\\"";
      $cmd .= " PRINT:tot_val${tot_val_index}:MAX:\\\" %8.0lf $delimiter\\\"";
      $cmd .= " GPRINT:tot_val${tot_val_index}:AVERAGE:\\\"%8.0lf \\\"";
      $cmd .= " GPRINT:tot_val${tot_val_index}:MAX:\\\" %8.0lf \\\"";
    }
    if ( $item eq "san_fabric_data_in" ) {
      $cmd .= " PRINT:tot_val${tot_val_index}:AVERAGE:\\\"%8.1lf $delimiter $host_space $delimiter $legend_heading $delimiter $color[$col_indx]\\\"";
      $cmd .= " PRINT:tot_val${tot_val_index}:MAX:\\\" %8.1lf $delimiter\\\"";
      $cmd .= " GPRINT:tot_val${tot_val_index}:AVERAGE:\\\"%8.1lf \\\"";
      $cmd .= " GPRINT:tot_val${tot_val_index}:MAX:\\\" %8.1lf \\\"";
    }
    if ( $item eq "san_fabric_credits" || $item eq "san_fabric_crc_errors" || $item eq "san_fabric_encoding_errors" ) {
      $cmd .= " PRINT:tot_val${tot_val_index}:AVERAGE:\\\"%8.1lf $delimiter $host_space $delimiter $legend_heading $delimiter $color[$col_indx]\\\"";
      $cmd .= " PRINT:tot_val${tot_val_index}:MAX:\\\" %8.1lf $delimiter\\\"";
      $cmd .= " GPRINT:tot_val${tot_val_index}:AVERAGE:\\\"%8.1lf \\\"";
      $cmd .= " GPRINT:tot_val${tot_val_index}:MAX:\\\" %8.1lf \\\"";
    }

    # --> it does not work ideally with newer RRDTOOL (1.2.30 --> it needs to be separated by cariage return here)
    $cmd .= " COMMENT:\\\"\\l\\\"";

    $col_indx++;
    if ( $col_indx > $color_max ) {
      $col_indx = 0;
    }
  }

  $cmd .= " HRULE:0#000000";
  # $cmd .= " VRULE:0#000000";  --> it is causing sigsegv on linuxeS
  $cmd =~ s/\\"/"/g;

  open(FH, "> $tmp_file") || error ("Can't open $tmp_file : $! ".__FILE__.":".__LINE__) && return 0;
  print FH "$cmd\n";
  close (FH);
}

sub draw_san_total
{
  my $sw             = shift;
  my @switches       = @{$sw};
  my $item           = "";

  $item = "san_data_sum_tot_in";
  draw_all_totals(\@switches,$item);
  $item = "san_data_sum_tot_out";
  draw_all_totals(\@switches,$item);
  $item = "san_io_sum_tot_credits";
  draw_all_totals(\@switches,$item);
  $item = "san_io_sum_tot_crc_errors";
  draw_all_totals(\@switches,$item);
  $item = "san_io_sum_tot_encoding_errors";
  draw_all_totals(\@switches,$item);
  $item = "san_io_sum_tot_in";
  draw_all_totals(\@switches,$item);
  $item = "san_io_sum_tot_out";
  draw_all_totals(\@switches,$item);
}

sub draw_all_totals
{
  my $sw       = shift;
  my $item     = shift;
  my @switches = @{$sw};
  my $type     = "";

  if ( $item =~ "^san_data" ) { $type = "Data"; }
  if ( $item =~ "^san_io" )   { $type = "Frames"; }

  print "creating graph : Totals:$type:$item:d\n" if $DEBUG ;
  draw_graph_total ("day","d","MINUTE:60:HOUR:2:HOUR:4:0:%H",\@switches,$item);

  print "creating graph : Totals:$type:$item:w\n" if $DEBUG ;
  draw_graph_total ("week","w","HOUR:8:DAY:1:DAY:1:0:%a",\@switches,$item);

  print "creating graph : Totals:$type:$item:m\n" if $DEBUG ;
  draw_graph_total ("4 weeks","m","DAY:1:DAY:2:DAY:2:0:%d",\@switches,$item);

  print "creating graph : Totals:$type:$item:y\n" if $DEBUG ;
  draw_graph_total ("year","y","MONTH:1:MONTH:1:MONTH:1:0:%b",\@switches,$item);

  return 0;
}

sub draw_graph_total
{
  my $text           = shift;
  my $type_gr        = shift;
  my $xgrid          = shift;
  my $sw             = shift;
  my $item           = shift;
  my @switches       = @{$sw};
  my $t              = "COMMENT: ";
  my $t2             = "COMMENT:\\n";
  my $last           = "COMMENT: ";
  my $act_time       = localtime();
  my $act_time_u     = time();
  my $req_time       = 0;
  my $value_short    = "";
  my $value_long     = "";
  my $val            = 1;
  my $units_exponent = "--units-exponent=1.00";

  my $totals_tmp_dir = "$tmp_dir/SAN-totals";
  my $tmp_file       = "$totals_tmp_dir/$item-$type_gr.cmd";

  if ( ! -d $totals_tmp_dir ) {
    mkdir("$totals_tmp_dir", 0755) || die "$act_time: Cannot mkdir $totals_tmp_dir: $!";
  }


  if ( $item eq "san_data_sum_tot_in" || $item eq "san_data_sum_tot_out" ) { $value_short= "MB/sec"; $value_long = "MBytes per second"; $val=(1024 * 1024) / 4;}
  if ( $item eq "san_io_sum_tot_in" || $item eq "san_io_sum_tot_out" )     { $value_short= "frames/sec"; $value_long = "Frames per second"; $val=1; $units_exponent = "--interlaced";}
  if ( $item eq "san_io_sum_tot_credits" )                                 { $value_short= "credits"; $value_long = "missing credits in % of time"; $val=1;}
  if ( $item eq "san_io_sum_tot_crc_errors" )                              { $value_short= "errors"; $value_long = "errors"; $val=1;}
  if ( $item eq "san_io_sum_tot_encoding_errors" )                         { $value_short= "errors"; $value_long = "errors"; $val=1;}

  my $comment        = sprintf ("%-16s","[$value_short]");
  my $i              = 0;
  my $j              = 0;
  my $cmd            = "";
  my $vertical_label = "--vertical-label=\\\"$value_long\\\"";
  my $header         = "SAN SWITCH : Totals : Transferred data last $text";

  $cmd .= "$graph_cmd \\\"$name_out\\\"";
  $cmd .= " --title \\\"$header\\\"";
  $cmd .= " --start now-1$type_gr";
  $cmd .= " --end now-1$type_gr+1$type_gr";
  $cmd .= " --imgformat PNG";
  $cmd .= " --slope-mode";
  $cmd .= " --width=400";
  $cmd .= " --height=150";
  $cmd .= " --step=$STEP";
  $cmd .= " --lower-limit=0.00";
  $cmd .= " --color=BACK#$pic_col";
  $cmd .= " --color=SHADEA#$pic_col";
  $cmd .= " --color=SHADEB#$pic_col";
  $cmd .= " --color=CANVAS#$pic_col";
  $cmd .= " --alt-autoscale-max";
  $cmd .= " --interlaced";
  $cmd .= " --upper-limit=0.1";
  $cmd .= " $vertical_label";
  $cmd .= " $units_exponent";
  $cmd .= " NO_LEGEND";
  $cmd .= " $disable_rrdtool_tag";
  $cmd .= " --x-grid=$xgrid";
  $cmd .= " --alt-y-grid";
  $cmd .= " $font_def_normal";
  $cmd .= " $font_tit_normal";
  $cmd .= " COMMENT:\\\"$comment   Avg         Max\\l\\\"";

  my $host_space    = "";
  my $tot_val_index = 0;
  my $col_indx      = 0;
  my $line_indx     = 0; # place enter evry 3rd line

  foreach my $host (@switches) {
    chomp $host;
    $tot_val_index++;
    $host =~ s/^$wrkdir\///;
    $host =~ s/\/SAN-BRCD$//;
    $host =~ s/\/SAN-CISCO$//;
    $host_space = $host;

    # add spaces to volume name to have 15 chars total (for formating graph legend)
    $host_space =~ s/\&\&1/\//g;
    $host_space = sprintf ("%-10s","$host_space");

    my $legend_heading = "Ports $delimiter $comment $delimiter Avg $delimiter Max ";

    # read PORTS.cfg
    open(FHR, "< $wrkdir/$host/PORTS.cfg") || error ("file does not exists : $wrkdir/$host/PORTS.cfg ".__FILE__.":".__LINE__) && return 0;
    my @files = <FHR>;
    my @files_org = @files;
    close (FHR);

    my $cmd_tot_per_switch = " CDEF:tot_val${tot_val_index}=";
    my $ports_found = 0;
    foreach my $line (@files) {
      chomp($line);
      my ( $port_name, $rrd ) = split(" : ",$line);

      # Show BBCredits only for fc ports
      if ( $item eq "san_io_sum_tot_credits" && -f "$wrkdir/$host/SAN-CISCO" ) {
        my $go_bbc = 0;
        if ( $port_name =~ "^portfc" || $port_name =~ "portChannel" ) { $go_bbc = 1; }
        if ( $go_bbc == 0 ) { next; }
      }

      $ports_found++;

      if ( $port_name eq '' || $rrd eq '' )          { next; }
      if ( ! -f "$rrd" )                             { error ("Could not find $port_name file: $rrd ".__FILE__.":".__LINE__); next; }

      # avoid old ports which do not exist in the period
      my $rrd_upd_time = (stat("$rrd"))[9];
      if ( $rrd_upd_time < $req_time ) { next; }
      my $time_first = find_real_data_start($rrd);

      my $item_rrd = "";
      if ( $item eq "san_data_sum_tot_in" )              { $item_rrd = "bytes_rec"; }
      if ( $item eq "san_data_sum_tot_out" )             { $item_rrd = "bytes_tra"; }
      if ( $item eq "san_io_sum_tot_in" )                { $item_rrd = "frames_rec"; }
      if ( $item eq "san_io_sum_tot_out" )               { $item_rrd = "frames_tra"; }
      if ( $item eq "san_io_sum_tot_credits" )           { $item_rrd = "swFCPortNoTxCredits"; }
      if ( $item eq "san_io_sum_tot_crc_errors" )        { $item_rrd = "swFCPortRxCrcs"; }
      if ( $item eq "san_io_sum_tot_encoding_errors" )   { $item_rrd = "swFCPortRxEncOutFrs"; }

      # build RRDTool cmd
      if ( $item eq "san_io_sum_tot_credits" ) {
        $val = 0.0000025;
        $cmd .= " DEF:value${i}=\\\"$rrd\\\":$item_rrd:AVERAGE";
        $cmd .= " CDEF:valb${i}=TIME,$time_first,LT,value${i},value${i},UN,0,value${i},IF,IF";
        $cmd .= " CDEF:valmb1_${i}=valb${i},$val,*";
        $cmd .= " CDEF:valmb2_${i}=valmb1_${i},60,/";
        $cmd .= " CDEF:valmb3_${i}=valmb2_${i},100,*";
        $cmd .= " CDEF:valmb${i}=valmb3_${i},1000,GT,UNKN,valmb3_${i},IF";
      }
      else {
        $cmd .= " DEF:value${i}=\\\"$rrd\\\":$item_rrd:AVERAGE";
        $cmd .= " CDEF:valb${i}=TIME,$time_first,LT,value${i},value${i},UN,0,value${i},IF,IF";
        $cmd .= " CDEF:valmb${i}=valb${i},$val,/";
      }

      if ( $ports_found == 1) {
        $cmd_tot_per_switch .= "valmb${i},0,+";
      }
      else {
        $cmd_tot_per_switch .= ",valmb${i},+";
      }

      $i++;
    }
    if ( $ports_found == 0 ) {
      error ("Could not find ports for $host in $wrkdir/$host/PORTS.cfg ".__FILE__.":".__LINE__);
      return 0;
    }

    my $gtype="AREA";

    if ( $tot_val_index > 1 )                          { $gtype="STACK"; }
    #if ( $item eq "san_data_sum_tot_credits" )         { $gtype="LINE1"; }
    #if ( $item eq "san_data_sum_tot_crc_errors" )      { $gtype="LINE1"; }
    #if ( $item eq "san_data_sum_tot_encoding_errors" ) { $gtype="LINE1"; }

    $cmd .= "$cmd_tot_per_switch";
    $cmd .= " $gtype:tot_val${tot_val_index}$color[$col_indx]:\"$host_space\"";

    if ( $item eq "san_io_sum_tot_in" || $item eq "san_io_sum_tot_out" ) {
      $cmd .= " PRINT:tot_val${tot_val_index}:AVERAGE:\\\"%8.0lf $delimiter $host_space $delimiter $legend_heading $delimiter $color[$col_indx]\\\"";
      $cmd .= " PRINT:tot_val${tot_val_index}:MAX:\\\" %8.0lf $delimiter test $delimiter SAN-BRCD\\\"";
      $cmd .= " GPRINT:tot_val${tot_val_index}:AVERAGE:\\\"%8.0lf \\\"";
      $cmd .= " GPRINT:tot_val${tot_val_index}:MAX:\\\" %8.0lf \\\"";
    }
    if ( $item eq "san_data_sum_tot_in" || $item eq "san_data_sum_tot_out" ) {
      $cmd .= " PRINT:tot_val${tot_val_index}:AVERAGE:\\\"%8.1lf $delimiter $host_space $delimiter $legend_heading $delimiter $color[$col_indx]\\\"";
      $cmd .= " PRINT:tot_val${tot_val_index}:MAX:\\\" %8.1lf $delimiter test $delimiter SAN-BRCD\\\"";
      $cmd .= " GPRINT:tot_val${tot_val_index}:AVERAGE:\\\"%8.1lf \\\"";
      $cmd .= " GPRINT:tot_val${tot_val_index}:MAX:\\\" %8.1lf \\\"";
    }
    if ( $item eq "san_io_sum_tot_credits" || $item eq "san_io_sum_tot_crc_errors" || $item eq "san_io_sum_tot_encoding_errors" ) {
      $cmd .= " PRINT:tot_val${tot_val_index}:AVERAGE:\\\"%8.1lf $delimiter $host_space $delimiter $legend_heading $delimiter $color[$col_indx]\\\"";
      $cmd .= " PRINT:tot_val${tot_val_index}:MAX:\\\" %8.1lf $delimiter test $delimiter SAN-BRCD\\\"";
      $cmd .= " GPRINT:tot_val${tot_val_index}:AVERAGE:\\\"%8.1lf \\\"";
      $cmd .= " GPRINT:tot_val${tot_val_index}:MAX:\\\" %8.1lf \\\"";
    }

    # --> it does not work ideally with newer RRDTOOL (1.2.30 --> it needs to be separated by cariage return here)
    $cmd .= " COMMENT:\\\"\\l\\\"";

    $col_indx++;
    if ( $col_indx > $color_max ) {
      $col_indx = 0;
    }
  }

  $cmd .= " HRULE:0#000000";
  # $cmd .= " VRULE:0#000000";  --> it is causing sigsegv on linuxeS
  $cmd =~ s/\\"/"/g;

  open(FH, "> $tmp_file") || error ("Can't open $tmp_file : $! ".__FILE__.":".__LINE__) && return 0;
  print FH "$cmd\n";
  close (FH);

}

# it is iportant to have real data start, as before that are take NaN to keep good average and since then when NaN exist then == 0
# to make summary graphs working
# it is about total graphs, all POOL graphs, CPU, Drives total ...
sub find_real_data_start
{
  my $rrd_file     = shift;
  my $time_first   = 1;
  my $refresh_time = 86400; # 1 day
  my $data_line    = "";


  my $rrd_file_first = $rrd_file;
  $rrd_file_first =~ s/rr.$/first/g;

  # find out time stamp of first data update
  # note first data point with data, not first with NaN which returns rrdtool first
  RRDp::cmd qq(first "$rrd_file");
  my $first_tt = RRDp::read;
  chomp($$first_tt); # start of predefined data points in rrdtool  , tehre could be NaN

  # find real start of data
  $time_first  = $$first_tt;
  my $unix_act = time();
  if ( -f $rrd_file_first && ((stat("$rrd_file_first"))[9] + $refresh_time) > $unix_act ) {
    # read real last time of the record in rrdtool from the file (refresh every day)
    open(FHF, "< $rrd_file_first") || error ("Can't open $rrd_file_first : $! ".__FILE__.":".__LINE__);
    foreach my $line_frst (<FHF>)  {
      chomp($line_frst);
      if ( isdigit($line_frst) ) {
        $time_first = $line_frst;
        last;
      }
    }
    #print "002 $rrd_file_first $time_first \n";
    close (FHF);
  }
  else {
    my $time_year_before = time() - 31622400; # unix time - 1 year
    #RRDp::cmd qq(fetch "$rrd_file" AVERAGE --end $time_year_before );
    # rrdtool fetch and found the first record is a bit tricky, must be used --end stuff!!!
    RRDp::cmd qq(fetch "$rrd_file" AVERAGE --start $time_year_before );
    # strange, --start must be used!! at least on 1.4.8 RRDTool
    my $data = RRDp::read;
    my $time_first_act = 2000000000; # just place here something hig engouh, higherb than actual unix time in seconds
    foreach $data_line (split(/\n/,$$data)) {
      chomp($data_line);
      (my $time_first_act_tmp, my $item1, my $item2) = split (/ /,$data_line);
      if ( isdigit($item1) || isdigit($item2) ) {
        $time_first_act = $time_first_act_tmp;
        $time_first_act =~ s/://g;
        $time_first_act =~ s/ //g;
        if ( isdigit($time_first_act) ) {
          last;
        }
      }
    }
    if ( isdigit($time_first_act) && $time_first_act > $time_first ) {
      # when is rrdtool DB file older than retention of 300s data then rrdtool first has the right value of the first record
      $time_first = $time_first_act;
    }
    if (  $time_first_act == 2000000000 ) {
      # looks like the RRDfile is empty, no records --> place there 1 year old date
      $time_first =  $time_year_before;
    }
    open(FHF, "> $rrd_file_first") || error ("Can't open $rrd_file_first : $! ".__FILE__.":".__LINE__);
    print FHF "$time_first";
    close (FHF);
  }

  $time_first =~ s/://g;
  if ( isdigit($time_first) == 0 ) {
    #error ("Pool first time has not been found in : $rrd_file_first : $time_first : $data_line ".__FILE__.":".__LINE__);
    return 1; # something is wrong, "1" causes ignoring followed rrdtool construction
  }
  return $time_first;
}

# it check if rrdtool supports graphv --> then zoom is supported
sub  rrdtool_graphv
{
  my $graph_cmd   = "graph";
  my $graphv_file = "$tmp_dir/graphv";

  my $ansx = `$rrdtool`;

  if (index($ansx, 'graphv') != -1) {
    # graphv exists, create a file to pass it to cgi-bin commands
    if ( ! -f $graphv_file ) {
      `touch $graphv_file`;
    }
  }
  else {
    if ( -f $graphv_file ) {
      unlink ($graphv_file);
    }
  }

  return 0;
}

sub isdigit
{
  my $digit = shift;
  my $text  = shift;

  if ( ! defined($digit) ) {
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

# error handling
sub error
{
  my $text     = shift;
  my $act_time = localtime();

  print "ERROR          : $text \n";
  print STDERR "$act_time: $text \n";

  return 1;
}

sub once_a_day {
  my $version_file = shift;
  my $version_file_run = "$version_file-run";

  # at first check whether it is a first run after the midnight
  if ( ! -f $version_file ) {
    #error("version file er: $version_file does not exist, it should not happen, creating it");
    `touch $version_file`;
    `touch $version_file_run`;
  }
  else {
    my $run_time = (stat("$version_file"))[9];
    (my $sec,my $min,my $h,my $aday,my $m,my $y,my $wday,my $yday,my $isdst) = localtime(time());
    ($sec,$min,$h,my $png_day,$m,$y,$wday,$yday,$isdst) = localtime($run_time);
    if ( $aday != $png_day ) {
       print "first run      : first run after the midnight: $aday != $png_day\n";
       `touch $version_file`;
       `touch $version_file_run`;
    }
  }
  return 1;
}

