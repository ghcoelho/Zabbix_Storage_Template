package CustomStor2rrd;
use Date::Parse;
use RRDp;
use strict;
use File::Copy;


my @config_custom_data = "";

my $bindir = $ENV{BINDIR};
if ( -f "$bindir/premium.pl" ) {
  require "$bindir/premium.pl";
}
else {
  require "$bindir/standard.pl";
}


sub custom {
  my ($basedir,$DEBUG) = @_;

  #$DEBUG=32; # 32 is custom group debug level 

  # get cmd line params
  my $wrkdir = "$basedir/data";
  my $custom_log="$basedir/custom.log";
  my $cfg = "$basedir/etc/web_config/custom_groups.cfg";
  if ( ! -f "$cfg" ) {
    if ( defined$ENV{CUSTOMCFG} ) {
      $cfg = $ENV{CUSTOMCFG};
      if ( ! -f "$cfg" ) {
        print "CustomG not cnf: custom groups are not configured: $cfg\n";
        return 1;
      }
    }
    else {
      print "CustomG not conf: custom groups are not configured: $cfg\n";
      return 1;
    }
  }

  # if cfg change then force to run install-html.sh (GUI refresh)
  check_cfg_change ($cfg,$basedir,$DEBUG);


  my $lpar_v = premium ();
  print "Custom start    : $lpar_v : $DEBUG\n";
  
  # use custom here to be sure it does not hang due to any problem
  my $timeout = 600; # it must be enough
  eval {
    my $act_time = localtime();
    local $SIG{ALRM} = sub {die "died in SIG ALRM: ";};
    alarm($timeout);

    my $ret = read_cfg ($cfg,$DEBUG);
    if ( $ret == 0 ) {
      return 0;
    }

    if ( $DEBUG == 32 ) {
      foreach my $l (@config_custom_data) {
        print "Config custom   : $l\n";
      }
    }

    check_data_volume($basedir,$wrkdir,$DEBUG,$lpar_v,\@config_custom_data);
    check_data_sanport($basedir,$wrkdir,$DEBUG,$lpar_v,\@config_custom_data);

    alarm (0);

    my $unixt = str2time($act_time);
    $act_time = localtime();
    my $unixt_end = str2time($act_time);
    my $run_time = $unixt_end - $unixt;
    print "Finished       : $act_time, run time: $run_time secs\n";
  };

  if ($@) {
    if ($@ =~ /died in SIG ALRM/) {
      error ("$0 timed out after : $timeout seconds");
    }
    else {
      error ("$0 failed: $@");
    }
    return (1);
  }
}

sub read_cfg {
  my ($cfg,$DEBUG) = @_;

  print "Custom cfg read: $cfg\n" if $DEBUG == 22;
  open(FH, "< $cfg") || error("could not open $cfg : $!".__FILE__.":".__LINE__) && return (0) ;
  my @lines = <FH>;
  close (FH);

  # allow usage of additional custom.cfg files like : etc/custom*.cfg
  (my $cfg_pref, my $cfg_suff) = split (/\./,$cfg);
  foreach my $cfg_cust (<$cfg_pref*\.$cfg_suff>) {
    chomp ($cfg_cust);
    if ( $cfg =~ m/^$cfg_cust$/ ) {
      next;
    }
    open(FH, "< $cfg_cust") || error("could not open $cfg_cust : $!".__FILE__.":".__LINE__) && return (0) ;
    my @lines_cust = <FH>;
    close (FH);
    my @merged = (@lines, @lines_cust);
    @lines = @merged;
    #print "001 $cfg_cust\n"; 
  }

  my @lines_sort = sort(@lines);

  my $data_line = 0;
  foreach my $line (@lines) {
    if ( $line =~ m/^#/ ) {
      next;
    }
    chomp ($line);
    # $line =~ s/#.*$//; --> must be allowed to allow "#" in volume name 
    $line =~ s/ *$//;

    # check if all parameters are specified
    my ( $tr1, $tr2, $tr3, $tr4) = split (/:/,$line);
    if ( ! defined ($tr4) || $tr4 eq '' ) {
      error ("Wrong custom group configuration record (not defined custom group name): $line ".__FILE__.":".__LINE__);
      next;
    }

    # continue with data lines
    if ( $line =~ m/^VOLUME/ || $line =~ m/^SANPORT/ ) {
      (my $trash, my $custom_act) = split (/:/,$line); 
      if ( defined ($custom_act) && ! $custom_act eq '' ) {
        $config_custom_data[$data_line] = $line;
        $data_line++;
        print "Data identified: $line\n" if $DEBUG == 32;
      }
    }
  }
  return (1);
}

# error handling
sub error
{
  my $text = shift;
  my $act_time = localtime();
  chomp ($text);

  print "ERROR          : $text : $!\n";
  print STDERR "$act_time: $text\n";

  return 1;
}


sub check_data_volume {
  my ($basedir,$wrkdir,$DEBUG,$lpar_v,$config_custom_data_tmp) = @_;
  my @config_custom_data = @{$config_custom_data_tmp};
  my $time_act = localtime();
  my $time_act_u = str2time($time_act);
  my ($sec,$min,$hour_act) = localtime();
  my @storage_translation = "";
  my @volume_translation = "";

  my $rrd_ver = $RRDp::VERSION;
  my $disable_rrdtool_tag = "--interlaced";  # just nope string, it is deprecated anyway
  if ( isdigit($rrd_ver) && $rrd_ver > 1.35 ) {
    $disable_rrdtool_tag = "--disable-rrdtool-tag";
  }


  # Volume translation --> read all volumes.cfg used in data lines and kept them in @volume_translation
  my $storage_no = 0;
  foreach my $line (@config_custom_data) {
    chomp ($line);
    ( my $type, my $storage ) = split (/:/,$line);
    if ( ! defined ($storage) || $storage eq '' ) {
      next; # some trash
    }
    if ( $type !~ m/^VOLUME$/ ) {
      next; # some trash
    }

    my $stor_found = 0;
    my $vol_indx = 0;
    foreach my $storage_act (@storage_translation) {
      if ( $storage =~ m/^$storage_act$/ ) {
        $stor_found = 1;
        last;
      }
    }
    if ($stor_found == 0 ) {
      # load volume cfg file
      my $vol_cfg_file = "$wrkdir/$storage/VOLUME/volumes.cfg";   
      if ( ! -f "$vol_cfg_file" ) {
        error ("Does not exist volume cfg file: $vol_cfg_file ".__FILE__.":".__LINE__);
        next;    
      }

      print "Storage process : $storage $storage_no\n" if $DEBUG > 0;
      open(FV, "< $vol_cfg_file") || error("Can't open $vol_cfg_file $! ".__FILE__.":".__LINE__) && next;
      $storage_translation[$storage_no] = $storage;
      my @array = <FV>;
      $volume_translation[$storage_no] = \@array;
      $storage_no++;
      close (FV);
    }
  }

  # sort it our per the group name
  @config_custom_data = sort { (split ':', $a)[3] cmp (split ':', $b)[3] } @config_custom_data;

  # read data
  my @group = "";
  my $group_no = 0;
  my $group_name_prev = "";
  my $vol_total_rate = 0;
  my $vol_total_rate_no = 0;
  my $vol_all = 0;
  foreach my $line (@config_custom_data) {
    chomp ($line);
    ( my $type, my $storage, my $volume, my $group_name ) = split (/:/,$line);
    if ( ! defined ($storage) || $storage eq '' || ! defined ($volume) || $volume eq '' || ! defined ($group_name) || $group_name eq '' ) {
      next; # some trash
    }
    if ( $type !~ m/^VOLUME$/ ) {
      next; # some trash
    }

    # get volume ID
    my $volume_id = get_volume_id ($storage,$volume,\@storage_translation,\@volume_translation);
    if ( ! defined($volume_id) || $volume_id eq '' ) {
      error("$storage:$volume:$group_name : volume_id has not been identified");
      next;    
    }

    print "Volume ID found : $storage:$volume:$group_name : $volume_id\n" if $DEBUG == 32;
    
    if ( -f "$basedir/data/$storage/DS5K" ) {
      # DS5K storage identified
      $vol_total_rate = 1;
    }
    else {
      if ( -f "$basedir/data/$storage/SWIZ" ) {
        $vol_total_rate_no = 1; # SVC/Storwize identified
      }
      else {
        $vol_all = 1;
      }
    }
    if ( $group_name_prev eq '' || $group_name_prev =~ m/^$group_name$/ ) {
      # stil same group, save data records
      $group[$group_no] = "$storage:$volume:$volume_id";
      $group_name_prev = $group_name;
      $group_no++;
      next;
    }
   
    # the other group, execute the old group
    group_exec ($group_name_prev,$disable_rrdtool_tag,$time_act,$time_act_u,$basedir,$DEBUG,$lpar_v,$vol_total_rate,$vol_total_rate_no,$vol_all,\@group);

    # initialize structures for next group
    @group = "";
    $group_no = 0;
    $group[$group_no] = "$storage:$volume:$volume_id";
    $group_name_prev = $group_name;
    $group_no++;
    $vol_total_rate = 0;
    $vol_total_rate_no = 0;
    $vol_all = 0;
  }
  if ( $group_no > 0 ) {
    group_exec ($group_name_prev,$disable_rrdtool_tag,$time_act,$time_act_u,$basedir,$DEBUG,$lpar_v,$vol_total_rate,$vol_total_rate_no,$vol_all,\@group);
  }

  return 1;

}

# work with the group, generate command files
sub group_exec {
  my ($group_name,$disable_rrdtool_tag,$time_act,$time_act_u,$basedir,$DEBUG,$lpar_v,$vol_total_rate,$vol_total_rate_no,$vol_all,$group_tmp) = @_;
  my @group = @{$group_tmp};
  my @metric_list = ("data_rate","io_rate","read_io","write_io","read","write"); # mixed env
  if ( $vol_total_rate == 1 ) {
    @metric_list = ("data_rate","io_rate"); # DS5K has only data_rate, io_rate
  }
  if ( $vol_total_rate_no == 1 ) { # SVC has no total
    @metric_list = ("read_io","write_io","read","write");
  }
  if ( $vol_all == 1 || ($vol_total_rate_no == 1 && $vol_total_rate == 1) ) {
    @metric_list = ("data_rate","io_rate","read_io","write_io","read","write"); # mixed env
  }

  foreach my $item (@metric_list) {
    create_graph($group_name,$item,$disable_rrdtool_tag,$time_act,$time_act_u,$basedir,$DEBUG,$lpar_v,\@group);
  }

  return 1;
}


# find out volume ID
sub get_volume_id {
  my ($storage,$volume,$storage_translation_tmp,$volume_translation) = @_;
  my @storage_translation = @{$storage_translation_tmp};

  # find out possition of given storage
  my $storage_no = 0;
  foreach my $line (@storage_translation) {
    if ( $line =~ m/^$storage$/ ) {
      last;
    }
    $storage_no++;
  }

  my $storage_found = 0;
  foreach my $row (@$volume_translation) { # it is already reference
    if ( $storage_found != $storage_no ) {
      $storage_found++;
      next;
    }
    foreach my $line_vol (@$row) {
      chomp ($line_vol);
      (my $volume_act, my $volume_id) = split (/ : /,$line_vol);
      if ( ! defined ($volume_id) || $volume_id eq '' ) {
        next;
      }
      if ( $volume_act =~ m/^$volume/ ) {
        $volume_id =~ s/ //g;
        $volume_id =~ s/;$//g;
        return $volume_id;
      }
      #print "$line_vol\n";
    }
    #print "============\n";
  }

  return "";
}



sub isdigit
{
  my $digit = shift;
  my $text = shift;

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


sub create_graph {
  my ($group_name,$item,$disable_rrdtool_tag,$time_act,$time_act_u,$basedir,$DEBUG,$lpar_v,$group_tmp) = @_;
  my @group = @{$group_tmp};

  if ( ! -d "$basedir/tmp/custom-group" ) {
      print "mkdir          : $basedir/tmp/custom-group\n" if $DEBUG ;
      mkdir("$basedir/tmp/custom-group", 0755) || die   "$time_act: Cannot mkdir $basedir/tmp/custom-group: $!";
  }

  @group = sort { (split ':', $a)[0] cmp (split ':', $b)[0] } @group; # sort it out per storage name

  draw_graph_volume ("day","d","MINUTE:60:HOUR:2:HOUR:4:0:%H",$item,$group_name,$disable_rrdtool_tag,$time_act,$time_act_u,$basedir,$DEBUG,$lpar_v,\@group);
  draw_graph_volume ("week","w","HOUR:8:DAY:1:DAY:1:86400:%a",$item,$group_name,$disable_rrdtool_tag,$time_act,$time_act_u,$basedir,$DEBUG,$lpar_v,\@group);
  draw_graph_volume ("4 weeks","m","DAY:1:DAY:2:DAY:2:0:%d",$item,$group_name,$disable_rrdtool_tag,$time_act,$time_act_u,$basedir,$DEBUG,$lpar_v,\@group);
  draw_graph_volume ("year","y","MONTH:1:MONTH:1:MONTH:1:0:%b",$item,$group_name,$disable_rrdtool_tag,$time_act,$time_act_u,$basedir,$DEBUG,$lpar_v,\@group);
  return 0;
}


sub draw_graph_volume {
  my ($text,$type_gr,$xgrid,$item,$group_name,$disable_rrdtool_tag,$time_act,$time_act_u,$basedir,$DEBUG,$lpar_v,$group_tmp) = @_;
  my @group = @{$group_tmp};
  my $name = "$basedir/tmp/custom-group/$group_name-$item-$type_gr";
  my $file_color_save = "$basedir/tmp/custom-group/$group_name-$item.col";
  my $lim = "li";
  my $type = "VOLUME";
  my $t="COMMENT: ";
  my $t2="COMMENT:\\n";
  my $last ="COMMENT: ";
  my $rrd_time = "";
  my $indx_low = 0;
  my $prev = -1;
  my $once = 0;
  my $last_time = "na";
  my @color=("#FF0000", "#0000FF", "#FFFF00", "#00FFFF", "#FFA500", "#00FF00", "#808080", "#FF00FF", "#800080",
             "#FDD017", "#0000A0", "#3BB9FF", "#008000", "#800000", "#ADD8E6", "#F778A1", "#800517", "#736F6E", "#F52887",
             "#C11B17", "#5CB3FF", "#A52A2A", "#FF8040", "#2B60DE", "#736AFF", "#1589FF", "#98AFC7", "#8D38C9", "#307D7E",
             "#F6358A", "#151B54", "#6D7B8D", "#FDEEF4", "#FF0080", "#F88017", "#2554C7", "#FFF8C6", "#D4A017", "#306EFF",
             "#151B8D", "#9E7BFF", "#EAC117", "#E0FFFF", "#15317E", "#6C2DC7", "#FBB917", "#FCDFFF", "#15317E", "#254117",
             "#FAAFBE", "#357EC7", "#4AA02C", "#38ACEC", "#C0C0C0");
  my $color_max = 53;
  my $pic_col = $ENV{PICTURE_COLOR};
  my $STEP = $ENV{SAMPLE_RATE};
  my $step_new = $STEP;
  my $font_def_normal =  "--font=DEFAULT:7:";
  my $font_tit_normal =  "--font=TITLE:9:";
  my $delimiter = "XORUX"; # this is for rrdtool print lines for clickable legend
  my $delim_com = "XOR_COM"; #delimiter when comments from rrd are needed
  my $wrkdir = "$basedir/data";
  my $lparn = "";
  $lim =~ s/i/l/;
  my $lv = length($lpar_v) + 3;

  my $tmp_file="$name.cmd";

  print "creating custom: $group_name:$item:$type_gr\n" if $DEBUG > 0 ;

  # open a file with stored colours
  my @color_save = "";
  if ( -f "$file_color_save" ) {
    open(FHC, "< $file_color_save") || error ("file cannot be opened : $file_color_save ".__FILE__.":".__LINE__) && return 0;
    @color_save = <FHC>;
    close (FHC);
  }

  my $req_time = "";
  my $header = "$type aggregated $item: last $text";
  my $i = 0;
  my $volume = "";
  my $cmd = "";
  my $j = 0;

  my $color_indx = 0; # reset colour index

  if ( "$type_gr" =~ "d" ) {
    $req_time = $time_act_u - 86400;
  }
  if ( "$type_gr" =~ "w" ) {
    $req_time = $time_act_u - 604800;
  }
  if ( "$type_gr" =~ "m" ) {
    $req_time = $time_act_u - 2764800;
  }
  if ( "$type_gr" =~ "y" ) {
    $req_time = $time_act_u - 31536000;
  }

  $cmd .= "graph \\\"$name.png\\\"";
  $cmd .= " --title \\\"$header\\\"";
  $cmd .= " --start now-1$type_gr";
  $cmd .= " --end now-1$type_gr+1$type_gr";
  $cmd .= " --imgformat PNG";
  $cmd .= " $disable_rrdtool_tag";
  $cmd .= " --slope-mode";
  $cmd .= " --width=400";
  $cmd .= " --height=150";
  $cmd .= " --step=$step_new";
  $cmd .= " --lower-limit=0.00";
  $cmd .= " --color=BACK#$pic_col";
  $cmd .= " --color=SHADEA#$pic_col";
  $cmd .= " --color=SHADEB#$pic_col";
  $cmd .= " --color=CANVAS#$pic_col";
  $cmd .= " --alt-autoscale-max";
  $cmd .= " --interlaced";
  $cmd .= " --upper-limit=0.1";
  $cmd .= " $font_def_normal";
  $cmd .= " $font_tit_normal";

  my $value_short = "";
  my $value_long = "";
  my $val = 1;
  my $suffix = "rrd";

  # do not use switch statement
  if ( $item =~ m/^data_rate$/ )     { $value_short= "MB"; $value_long = "MBytes"; $val = 1024;}
  if ( $item =~ m/^read$/ )          { $value_short= "MB"; $value_long = "MBytes"; $val = 1024;}
  if ( $item =~ m/^write$/ )         { $value_short= "MB"; $value_long = "MBytes"; $val = 1024;}
  if ( $item =~ m/^io_rate$/ )       { $value_short= "IOPS"; $value_long = "IO per second"; }
  if ( $item =~ m/^read_io$/ )       { $value_short= "IOPS"; $value_long = "IO per second"; }
  if ( $item =~ m/^write_io$/ )      { $value_short= "IOPS"; $value_long = "IO per second"; }
  if ( $item =~ m/^resp_t$/ )        { $value_short= "ms"; $value_long = "mili seconds"; }
  if ( $item =~ m/^resp_t_r$/ )      { $value_short= "ms"; $value_long = "mili seconds"; }
  if ( $item =~ m/^resp_t_w$/ )      { $value_short= "ms"; $value_long = "mili seconds"; }
  if ( $item =~ m/^cache_hit$/ )     { $value_short= "%"; $value_long = "percent"; }
  if ( $item =~ m/^ssd_r_cache_hit$/ ){ $value_short= "%"; $value_long = "percent"; }
  if ( $item =~ m/^r_cache_hit$/ )   { $value_short= "%"; $value_long = "percent"; }
  if ( $item =~ m/^w_cache_hit$/ )   { $value_short= "%"; $value_long = "percent"; }
  if ( $item =~ m/^read_pct$/ )      { $value_short= "%"; $value_long = "percent"; }
  if ( $item =~ m/^r_cache_usage$/ ) { $value_short= "MB"; $value_long = "MBytes"; $val=1024; }
  if ( $item =~ m/^w_cache_usage$/ ) { $value_short= "MB"; $value_long = "MBytes"; $val=1024; }
  if ( $item =~ m/^read_b$/ )        { $value_short= "MB"; $value_long = "MBytes"; $val = 1024;}
  if ( $item =~ m/^write_b$/ )       { $value_short= "MB"; $value_long = "MBytes"; $val = 1024;}
  if ( $item =~ m/^read_io_b$/ )     { $value_short= "IOPS"; $value_long = "IO per second"; }
  if ( $item =~ m/^write_io_b$/ )    { $value_short= "IOPS"; $value_long = "IO per second"; }
  if ( $item =~ m/^resp_t_r_b$/ )    { $value_short= "ms"; $value_long = "mili seconds"; }
  if ( $item =~ m/^resp_t_w_b$/ )    { $value_short= "ms"; $value_long = "mili seconds"; }


  #if ( -f "$wrkdir/$storage/DS8K" ) {
  #  if ( $item =~ m/^read$/ || $item =~ m/^write$/ ) {
  #    # data is stored in wrong RRDTool type (GAUGE instead of ABSOLUTE)
  #    # this do data conversion
  #    $val = $step_new; # do not use $val=1024
  #  }
  #}
    
  #print "001 $st_type $type $item $suffix\n";

  $cmd .= " --vertical-label=\\\"$item in $value_long\\\"";
  $cmd .= " --units-exponent=1.00";
  $cmd .= " --x-grid=$xgrid";
  $cmd .= " --alt-y-grid";

  # add spaces to volume name (for formating graph legend)
  my $item_short = $item;
  $item_short =~ s/r_cache_//;
  $item_short =~ s/w_cache_//;
  my $legend = sprintf ("%-38s","$item_short [$value_short]");
  my $legend_heading = "$item_short $delimiter [$value_short] $delimiter Avg $delimiter Max ";
  $legend_heading =~ s/%/%%/g;
  $cmd .= " COMMENT:\\\"$legend       Avg       Max                                                Avg       Max\\l\\\"";

  my $gtype="AREA";
  if ( $item =~ m/resp_t/ || $item =~ m/cache_hit/ || $item =~ m/read_pct/ ) {
    $gtype="LINE1";
  }

  my $volume_list = "";
  my $volume_list_tmp = "";


  my $vols = "";
  my $itemm_sum = "";
  my $volume_space = "";
  my $last_vol = -1;
  my $color_file_change = 0;
  my $item_name_for_print_comment = "";
  my $cmd_print = ""; # print commands for clickable legend
  my $once_report = 0;
  my $indx = 0;
  my $file = "";
  my $once_report_ds5k_no = 0;
  my $once_report_ds5k_yes =0;

  foreach my $group_line (@group) {
    if ( $group_line eq '' || $group_line =~ m/^#/ ) {
      next;
    }
    (my $storage, my $volume_name, my $vol_ids) = split (/:/,$group_line);
    if ( ! defined ($vol_ids) || $vol_ids eq '' ) {
      next;
    }
    $vol_ids =~ s/0x//g;
    my @vol_array = split(/;/,$vol_ids);

    my $itemm = $item."m".$volume_name.$storage;
    $itemm =~ s/\./Z/g;	# dots in rrdtool variable names causing problems for rrdtool parser
    $itemm =~ s/ /X/g; 	# space in rrdtool variable names causing problems for rrdtool parser
    $itemm =~ s/\#/Y/g; # hash in rrdtool variable names causing problems for rrdtool parser
    $itemm =~ s/:/R/g;  # hash in rrdtool variable names causing problems for rrdtool parser
    $itemm =~ s/-/S/g;  # dash in rrdtool variable names causing problems for rrdtool parser (some old versions)
    $itemm_sum = $itemm."sum";

    #
    # follow each volume (there migh be more volumes under 1 volume nick!!!
    # first run just select files ... must be for mutilevel resp_t a cache_hit to count how many items are summed
    my @vol_array_work = "";
    my $vol_array_work_indx = 0;
    my $suffix = "rrd";

    my $st_type = "DS5K";
    if ( -f "$wrkdir/$storage/DS8K" ) {
      $st_type = "DS8K";
    }
    if ( -f "$wrkdir/$storage/XIV" ) {
      $st_type = "XIV";
    }
    if ( -f "$wrkdir/$storage/SWIZ" ) {
      $st_type = "SWIZ";
    }
    if ( -f "$wrkdir/$storage/HUS" ) {
      $st_type = "HUS";
    }
    if ( -f "$wrkdir/$storage/3PAR" ) {
      $st_type = "3PAR";
    }
    if ( -f "$wrkdir/$storage/VSPG" ) {
      $st_type = "VSPG";
    }
    if ( -f "$wrkdir/$storage/NETAPP" ) {
      $st_type = "NETAPP";
    }

    if ( $st_type =~ m/DS5K/ && $item !~ m/^data_rate$/ && $item !~ m/^io_rate$/ ) {
      # DS5K has only "data_rate","io_rate"
      next; # skip it 
    }

    if ( ($item =~ m/^data_rate$/ || $item =~ m/^io_rate$/) && ( $st_type =~ m/SWIZ/ || $st_type =~ m/XIV/ )) {
      # SWIZ and XIV do not have data_rate and io_rate in Volume rrdtool files
      next; # skip it 
    }

    $prev = -1;

    foreach my $volume (@vol_array) {
      if ( $st_type =~ m/^DS8K$/  ) {
        if ( $item =~ m/^resp_t_r$/ || $item =~ m/^resp_t_w$/ || $item =~ m/^read_io$/ || $item =~ m/^write_io$/ ) {
          $suffix = "rrc";
        }
      }
      $file = "$wrkdir/$storage/$type/$volume.$suffix";

      if ( $st_type =~ m/XIV/ || $st_type =~ m/DS5K/ || $st_type =~ m/3PAR/ ) {
        # XIV & DS5K volumes contain pool_id in their names: 00273763-P102932.rrd
        # there might be more files if volumes are moved between pool, select the most fresh one
        my $vol_update_last = 0;
        foreach my $file_xiv (<$wrkdir/$storage/$type/$volume-P*\.$suffix>) {
          my $vol_upd_time = (stat("$file_xiv"))[9];
          if ( $vol_upd_time > $vol_update_last ) {
            $file = $file_xiv;
            $vol_update_last = $vol_upd_time
          }
        }
        if ($vol_update_last == 0 ) {
          #volume has not been found,m skipping it
          next;
        }
      }

      if ( $volume eq '' ) {
        next;
      }

      if ( ! -f $file ) {
        if ( $once_report == 0 ) {
          # It might appear after the upgrade to 1.00 as *rrc files are not in place yet
          error("volumes stats: $file does not exist, continuing ".__FILE__.":".__LINE__);
          $once_report++;
        }
        next;
      }

      # go every each volume for particular group

      # avoid old volumes which do not exist in the period
      my $rrd_upd_time = (stat("$file"))[9];
      if ( $rrd_upd_time < $req_time ) {
        next;
      }
      $vol_array_work[$vol_array_work_indx] = $file;
      #print "001  $vol_array_work[$vol_array_work_indx] : $file : $vol_array_work_indx\n";
      $vol_array_work_indx++;
    }

    # lets make $cmd for multilevels ones
    my $file_for_print = "";
    foreach my $file (@vol_array_work) {
      if ( $file eq '' ) {
        next;
      }
      $file_for_print = $file; 

      if ( $type_gr =~ m/d/ && $once == 0 ) {
        # find out time stamp of last data update
        # take just one volume to keep it simple
        $once++; 
        RRDp::cmd qq(last "$file");
        my $last_tt = RRDp::read;
        $last_time=localtime($$last_tt);
        $last_time =~ s/:/\\:/g;
      }


      # bulid RRDTool cmd
  
      $cmd .= " DEF:$item${i}=\\\"$file\\\":$item:AVERAGE";
      if ( $vol_array_work_indx > 1 ) {
        my $val_tot = $val;
        if ( $item =~ m/resp_t/ || $item =~ m/cache_hit/ || $item =~ m/read_pct/ ) {
          # resp_t and cache_hit must be averaged not summed for multivolumes ...
          $val_tot = $val * $vol_array_work_indx;
        }
        $cmd .= " CDEF:$itemm${i}=$item${i},$val_tot,/"; # convert into MB if necessary, normaly is there 1
      }
      else {
        $cmd .= " CDEF:$itemm${i}=$item${i},$val,/"; # convert into MB if necessary, normaly is there 1
      }

      if ( $prev == -1 ) {
          $cmd .= " CDEF:$itemm_sum${i}=$itemm${i}"; 
      }
      else {
          $cmd .= " CDEF:$itemm_sum${i}=$itemm_sum${last_vol},$itemm${i},+"; 
      }
      $i++;
      $prev++;
      $last_vol++;
    }

    if ( $prev == -1 ) {
      next; # have not found any volume
    }

    # add spaces to volume name to have 18 chars total (for formating graph legend)
    $volume_space = $volume_name;
    $volume_space = sprintf ("%-38s","$volume_space");

    # Found out stored color index to keep same color for the volume across all graphs
    my $color_indx_found = -1;
    my $col_index = 0;
    foreach my $line_col (@color_save) {
      chomp ($line_col);
      if ( $line_col eq '' ) {
        next;
      }
      (my $color_indx_found_act, my $volume_name_save) = split (/:/,$line_col);
      if ( $volume_name_save =~ m/^$volume_name$storage$/ ) {
        $color_indx_found = $color_indx_found_act;
        $color_indx = $color_indx_found;
        last;
      }
      $col_index++;
    }
    if ( $color_indx_found == -1 ) {
      $color_file_change = 1;
      $color_save[$col_index] = $color_indx.":".$volume_name.$storage;
    }
    while ($color_indx > $color_max ) { # this should not normally happen, just to be sure
      $color_indx = $color_indx - $color_max;
    }
    # end color
    $lparn .= " ";

    $cmd .= " $gtype:$itemm_sum${last_vol}$color[$color_indx]:\\\"$volume_space\\\"";
    $item_name_for_print_comment = "$itemm_sum${last_vol}";

    if ( $item !~ m/resp_t/ && $item !~ m/cache_hit/ && $item !~ m/read_pct/ ) {
      $gtype="STACK";
    }

    if ( $lv != length($t) && length($lparn) > length($t) + 1 ) {
      if ( ! -f "$basedir/tmp/custom-group/.$group_name-$lim.cmd" ) {
        copy("$basedir/html/.$lim", "$basedir/tmp/custom-group/.$group_name-$lim.cmd");
      }
      $indx++;
      $color_indx++;
      next;
    }
  
    # put carriage return after each second volume in the legend
    if ($j == 1) {
      if ( $item =~ m/io_rate/ || $item =~ m/read_io/ || $item =~ m/write_io/ ) {
        $cmd .= " GPRINT:$itemm_sum${last_vol}:AVERAGE:\\\"%6.0lf \\\"";
        $cmd .= " GPRINT:$itemm_sum${last_vol}:MAX:\\\"%6.0lf \\l\\\"";

        $cmd .= " PRINT:$itemm_sum${last_vol}:AVERAGE:\\\"%6.0lf $delimiter customg-storage $delimiter $volume_space $delimiter $legend_heading $delimiter $color[$color_indx]\\\"";
        $cmd .= " PRINT:$itemm_sum${last_vol}:MAX:\\\" %6.0lf $delimiter $file_for_print $delimiter $st_type\\\"";
      }
      else {
        if ( $item !~ m/cache_hit/ && $item !~ m/read_pct/ ) {
          $cmd .= " GPRINT:$itemm_sum${last_vol}:AVERAGE:\\\"%6.1lf \\\"";
          $cmd .= " GPRINT:$itemm_sum${last_vol}:MAX:\\\"%6.1lf \\l\\\"";

          $cmd .= " PRINT:$itemm_sum${last_vol}:AVERAGE:\\\"%6.1lf $delimiter customg-storage $delimiter $volume_space $delimiter $legend_heading $delimiter $color[$color_indx]\\\"";
          $cmd .= " PRINT:$itemm_sum${last_vol}:MAX:\\\" %6.1lf $delimiter $file_for_print $delimiter $st_type\\\"";
        }
        else {
          # cache_hit
          my $volume_print = $volume_name;
          $volume_print =~ s/ /=====space=====/g;
          $cmd .= " PRINT:$itemm_sum${last_vol}:AVERAGE:\\\"$volume_print %6.1lf \\\"";
          $cmd .= " GPRINT:$itemm_sum${last_vol}:AVERAGE:\\\"%6.1lf \\\"";
          $cmd .= " GPRINT:$itemm_sum${last_vol}:MAX:\\\"%6.1lf \\l\\\"";

          $cmd .= " PRINT:$itemm_sum${last_vol}:AVERAGE:\\\"%6.1lf $delimiter customg-storage $delimiter $volume_print $delimiter $legend_heading $delimiter $color[$color_indx]\\\"";
	  $cmd .= " PRINT:$itemm_sum${last_vol}:MAX:\\\" %6.1lf $delimiter $file_for_print $delimiter $st_type\\\"";
        }
      }
      $j = 0;
    }
    else {
      if ( $item =~ m/io_rate/ || $item =~ m/read_io/ || $item =~ m/write_io/ ) {
        $cmd .= " GPRINT:$itemm_sum${last_vol}:AVERAGE:\\\"%6.0lf \\\"";
        $cmd .= " GPRINT:$itemm_sum${last_vol}:MAX:\\\"%6.0lf \\\"";

        $cmd .= " PRINT:$itemm_sum${last_vol}:AVERAGE:\\\"%6.0lf $delimiter customg-storage $delimiter $volume_space $delimiter $legend_heading $delimiter $color[$color_indx]\\\"";
	$cmd .= " PRINT:$itemm_sum${last_vol}:MAX:\\\" %6.0lf $delimiter $file_for_print $delimiter $st_type\\\"";
      }
      else {
        if ( $item !~ m/cache_hit/ && $item !~ m/read_pct/ ) {
          $cmd .= " GPRINT:$itemm_sum${last_vol}:AVERAGE:\\\"%6.1lf \\\"";
          $cmd .= " GPRINT:$itemm_sum${last_vol}:MAX:\\\"%6.1lf \\\"";

          $cmd .= " PRINT:$itemm_sum${last_vol}:AVERAGE:\\\"%6.1lf $delimiter customg-storage $delimiter $volume_space $delimiter $legend_heading $delimiter $color[$color_indx]\\\"";
          $cmd .= " PRINT:$itemm_sum${last_vol}:MAX:\\\" %6.1lf $delimiter $file_for_print $delimiter $st_type\\\"";
        }
        else {
          # cache_hit
          my $volume_print = $volume_name;
          $volume_print =~ s/ /=====space=====/g;
          $cmd .= " PRINT:$itemm_sum${last_vol}:AVERAGE:\\\"$volume_print %6.1lf \\\"";
          $cmd .= " GPRINT:$itemm_sum${last_vol}:AVERAGE:\\\"%6.1lf \\\"";
          $cmd .= " GPRINT:$itemm_sum${last_vol}:MAX:\\\"%6.1lf \\\"";

          $cmd .= " PRINT:$itemm_sum${last_vol}:AVERAGE:\\\"%6.1lf $delimiter customg-storage $delimiter $volume_print $delimiter $legend_heading $delimiter $color[$color_indx]\\\"";
          $cmd .= " PRINT:$itemm_sum${last_vol}:MAX:\\\" %6.1lf $delimiter $file_for_print $delimiter $st_type\\\"";
        }
      }
      $j++
    }
    $color_indx++;
    if ($color_indx > $color_max ) {
      $color_indx = 0;
    }
    $indx++;
    if ( $lpar_v =~ m/free/ && $last_vol > 10 ) {
      last;
    }
  }

  if ( $indx == 0 ) {
    # nothing has been selected, there is no new data in RRD files --> created at least empty graph
    $cmd .= " DEF:dummy=\\\"$file\\\":$item:AVERAGE";
    $cmd .= " LINE1:dummy#ffffff:\\\"\\\" ";
  }

  if ($j == 1) {
    $cmd .= " COMMENT:\\\"\\l\\\"";
  }

  if ( $indx > 0 && $item =~ m/resp_t/ ) {
    $cmd .= " PRINT:$item_name_for_print_comment:MAX:\\\" %8.1lf $delim_com \\\"";
    $cmd .= " PRINT:$item_name_for_print_comment:MAX:\\\" %8.1lf $delim_com \\\"";
  }

  if ( $type_gr =~ m/d/ ) {
    # last update timestamp
    $cmd .= " COMMENT:\\\"Updated\\\: $last_time\\\"";
  }

  $cmd .= " HRULE:0#000000";
  # $cmd .= " VRULE:0#000000";  --> it is causing sigsegv on linuxeS
  $cmd =~ s/\\"/"/g;

  # write colors into a file
  if ( $color_file_change == 1 ) {
    open(FHC, "> $file_color_save") || error ("file does cannot be created :  $file_color_save ".__FILE__.":".__LINE__) && return 0;
    foreach my $line_cs (@color_save) {
      chomp ($line_cs);# it must be there, somehow appear there \n ...
      if ( $line_cs eq '' ) {
        next;
      }
      if ( $line_cs =~ m/:/ ) {
        print FHC "$line_cs\n";
      }
    }
    close (FHC);
  }
  # colours

  my $FH;
  open(FH, "> $tmp_file") || error ("Can't open $tmp_file : $! ".__FILE__.":".__LINE__) && return 0;
  print FH "$cmd\n";
  close (FH);

  return 0;
}

sub  check_cfg_change {
  my ($cfg,$basedir,$DEBUG) = @_;
  my $last_change_file = "$basedir/tmp/custom-group-cfg-last.txt";

  if ( ! -f $last_change_file ) {
    # first run
    touch ($basedir,$DEBUG);
   `touch $last_change_file`;
    return 1;
  }

  my $cfg_upd_time = (stat("$cfg"))[9];
  my $last_upd_time = (stat("$last_change_file"))[9];
  if ( $cfg_upd_time > $last_upd_time ) {
    touch ($basedir,$DEBUG);
   `touch $last_change_file`;
  }

  return 1;
}

sub touch
{
  my ($basedir,$DEBUG) = @_;
  my $version="$ENV{version}";
  my $new_change="$basedir/tmp/$version-run";


  if ( ! -f $new_change ) {
   `touch $new_change`; # say install_html.sh that there was any change
   print "touch          : custom group config change :  $new_change\n" if $DEBUG ;
  }

  return 0
}

sub check_data_sanport {
  my ($basedir,$wrkdir,$DEBUG,$lpar_v,$config_custom_data_tmp) = @_;
  my @config_custom_data = @{$config_custom_data_tmp};
  my $time_act = localtime();
  my $time_act_u = str2time($time_act);
  my ($sec,$min,$hour_act) = localtime();
  my @storage_translation = "";
  my @volume_translation = "";

  my $rrd_ver = $RRDp::VERSION;
  my $disable_rrdtool_tag = "--interlaced";  # just nope string, it is deprecated anyway
  if ( isdigit($rrd_ver) && $rrd_ver > 1.35 ) {
    $disable_rrdtool_tag = "--disable-rrdtool-tag";
  }

  # sort it our per the group name
  @config_custom_data = sort { (split ':', $a)[3] cmp (split ':', $b)[3] } @config_custom_data;

  # read data
  my @group = "";
  my $group_no = 0;
  my $group_name_prev = "";
  foreach my $line (@config_custom_data) {
    chomp ($line);
    ( my $type, my $storage, my $volume, my $group_name ) = split (/:/,$line);
    if ( ! defined ($storage) || $storage eq '' || ! defined ($volume) || $volume eq '' || ! defined ($group_name) || $group_name eq '' ) {
      next; # some trash
    }
    if ( $type !~ m/^SANPORT$/ ) {
      next; # filter just SAN
    }

    $volume =~ s/ .*$//; # filter up aliases like this:7 [ASAN11p06_ASRV11VIOS2fcs2]
    #if ( ! isdigit($volume) ) {
    # no no, Cisco SAN port names contain text
    #  error ("SANPORT: volume name is not a digit: $volume : $line : $! ".__FILE__.":".__LINE__);
    #  next;
    #}

    if ( $group_name_prev eq '' || $group_name_prev =~ m/^$group_name$/ ) {
      # stil same group, save data records
      $group[$group_no] = "$storage:$volume";
      $group_name_prev = $group_name;
      $group_no++;
      next;
    }
   
    # the other group, execute the old group
    group_exec_sanport ($group_name_prev,$disable_rrdtool_tag,$time_act,$time_act_u,$basedir,$DEBUG,$lpar_v,\@group);

    # initialize structures for next group
    @group = "";
    $group_no = 0;
    $group[$group_no] = "$storage:$volume";
    $group_name_prev = $group_name;
    $group_no++;
  }
  if ( $group_no > 0 ) {
    group_exec_sanport ($group_name_prev,$disable_rrdtool_tag,$time_act,$time_act_u,$basedir,$DEBUG,$lpar_v,\@group);
  }

  return 1;

}

# work with the group, generate command files
sub group_exec_sanport {
  my ($group_name,$disable_rrdtool_tag,$time_act,$time_act_u,$basedir,$DEBUG,$lpar_v,$group_tmp) = @_;
  my @group = @{$group_tmp};
  #my @metric_list = ("data_in","data_out","frames_in","frames_out","credits","encoding_errors","crc_errors");
  my @metric_list = ("data_in","data_out","frames_in","frames_out","credits","errors");

  foreach my $item (@metric_list) {
    create_graph_sanport($group_name,$item,$disable_rrdtool_tag,$time_act,$time_act_u,$basedir,$DEBUG,$lpar_v,\@group);
  }

  return 1;
}


sub create_graph_sanport {
  my ($group_name,$item,$disable_rrdtool_tag,$time_act,$time_act_u,$basedir,$DEBUG,$lpar_v,$group_tmp) = @_;
  my @group = @{$group_tmp};

  if ( ! -d "$basedir/tmp/custom-group" ) {
      print "mkdir          : $basedir/tmp/custom-group\n" if $DEBUG ;
      mkdir("$basedir/tmp/custom-group", 0755) || die   "$time_act: Cannot mkdir $basedir/tmp/custom-group: $!";
  }

  @group = sort { (split ':', $a)[0] cmp (split ':', $b)[0] } @group; # sort it out per storage name

  draw_graph_sanport("day","d","MINUTE:60:HOUR:2:HOUR:4:0:%H",$item,$group_name,$disable_rrdtool_tag,$time_act,$time_act_u,$basedir,$DEBUG,$lpar_v,\@group);
  draw_graph_sanport("week","w","HOUR:8:DAY:1:DAY:1:86400:%a",$item,$group_name,$disable_rrdtool_tag,$time_act,$time_act_u,$basedir,$DEBUG,$lpar_v,\@group);
  draw_graph_sanport("4 weeks","m","DAY:1:DAY:2:DAY:2:0:%d",$item,$group_name,$disable_rrdtool_tag,$time_act,$time_act_u,$basedir,$DEBUG,$lpar_v,\@group);
  draw_graph_sanport("year","y","MONTH:1:MONTH:1:MONTH:1:0:%b",$item,$group_name,$disable_rrdtool_tag,$time_act,$time_act_u,$basedir,$DEBUG,$lpar_v,\@group);
  return 0;
}


sub draw_graph_sanport {
  my ($text,$type_gr,$xgrid,$item,$group_name,$disable_rrdtool_tag,$time_act,$time_act_u,$basedir,$DEBUG,$lpar_v,$group_tmp) = @_;
  my @group = @{$group_tmp};
  my $name = "$basedir/tmp/custom-group/$group_name-$item-$type_gr";
  my $file_color_save = "$basedir/tmp/custom-group/$group_name-$item.col";
  my $lim = "li";
  my $type = "SANPORT";
  my $t="COMMENT: ";
  my $t2="COMMENT:\\n";
  my $last ="COMMENT: ";
  my $rrd_time = "";
  my $indx_low = 0;
  my $prev = -1;
  my $once = 0;
  my $last_time = "na";
  my @color=("#FF0000", "#0000FF", "#FFFF00", "#00FFFF", "#FFA500", "#00FF00", "#808080", "#FF00FF", "#800080",
             "#FDD017", "#0000A0", "#3BB9FF", "#008000", "#800000", "#ADD8E6", "#F778A1", "#800517", "#736F6E", "#F52887",
             "#C11B17", "#5CB3FF", "#A52A2A", "#FF8040", "#2B60DE", "#736AFF", "#1589FF", "#98AFC7", "#8D38C9", "#307D7E",
             "#F6358A", "#151B54", "#6D7B8D", "#FDEEF4", "#FF0080", "#F88017", "#2554C7", "#FFF8C6", "#D4A017", "#306EFF",
             "#151B8D", "#9E7BFF", "#EAC117", "#E0FFFF", "#15317E", "#6C2DC7", "#FBB917", "#FCDFFF", "#15317E", "#254117",
             "#FAAFBE", "#357EC7", "#4AA02C", "#38ACEC", "#C0C0C0");
  my $color_max = 53;
  my $pic_col = $ENV{PICTURE_COLOR};
  my $STEP = $ENV{SAMPLE_RATE};
  my $step_new = $STEP;
  my $font_def_normal =  "--font=DEFAULT:7:";
  my $font_tit_normal =  "--font=TITLE:9:";
  my $delimiter = "XORUX"; # this is for rrdtool print lines for clickable legend
  my $delim_com = "XOR_COM"; #delimiter when comments from rrd are needed
  my $wrkdir = "$basedir/data";
  my $lparn = "";
  $lim =~ s/i/l/;
  my $lv = length($lpar_v) + 3;

  my $tmp_file="$name.cmd";

  print "creating custom: $group_name:$item:$type_gr\n" if $DEBUG > 0 ;

  # open a file with stored colours
  my @color_save = "";
  if ( -f "$file_color_save" ) {
    open(FHC, "< $file_color_save") || error ("file cannot be opened : $file_color_save ".__FILE__.":".__LINE__) && return 0;
    @color_save = <FHC>;
    close (FHC);
  }

  my $req_time = "";
  my $header = "$type aggregated $item: last $text";
  my $i = 0;
  my $cmd = "";
  my $j = 0;

  my $color_indx = 0; # reset colour index

  if ( "$type_gr" =~ "d" ) {
    $req_time = $time_act_u - 86400;
  }
  if ( "$type_gr" =~ "w" ) {
    $req_time = $time_act_u - 604800;
  }
  if ( "$type_gr" =~ "m" ) {
    $req_time = $time_act_u - 2764800;
  }
  if ( "$type_gr" =~ "y" ) {
    $req_time = $time_act_u - 31536000;
  }

  $cmd .= "graph \\\"$name.png\\\"";
  $cmd .= " --title \\\"$header\\\"";
  $cmd .= " --start now-1$type_gr";
  $cmd .= " --end now-1$type_gr+1$type_gr";
  $cmd .= " --imgformat PNG";
  $cmd .= " $disable_rrdtool_tag";
  $cmd .= " --slope-mode";
  $cmd .= " --width=400";
  $cmd .= " --height=150";
  $cmd .= " --step=$step_new";
  $cmd .= " --lower-limit=0.00";
  $cmd .= " --color=BACK#$pic_col";
  $cmd .= " --color=SHADEA#$pic_col";
  $cmd .= " --color=SHADEB#$pic_col";
  $cmd .= " --color=CANVAS#$pic_col";
  $cmd .= " --alt-autoscale-max";
  $cmd .= " --interlaced";
  $cmd .= " --upper-limit=0.1";
  $cmd .= " $font_def_normal";
  $cmd .= " $font_tit_normal";

  my $value_short = "";
  my $value_long = "";
  my $val = 1;
  my $suffix = "rrd";

  # do not use switch statement
  if ( $item =~ m/^data/  )   { $value_short= "MB/sec"; $value_long = "MBytes per second"; $val=(1024 * 1024) / 4;}
  if ( $item =~ m/^frames/ )  { $value_short= "frames/sec"; $value_long = "Frames per second"; $val=1;}
  if ( $item =~ m/^credits/ ) { $value_short= "credits"; $value_long = "credits"; $val=1;}
  if ( $item =~ m/^errors/ )  { $value_short= "errors"; $value_long = "errors"; $val=1;}

  my $item_rrd = $item;
  if ( $item eq "data_in" )         { $item_rrd = "bytes_rec"; }
  if ( $item eq "data_out" )        { $item_rrd = "bytes_tra"; }
  if ( $item eq "frames_in" )       { $item_rrd = "frames_rec"; }
  if ( $item eq "frames_out" )      { $item_rrd = "frames_tra"; }
  if ( $item eq "credits" )         { $item_rrd = "swFCPortNoTxCredits"; }
  if ( $item eq "errors" )          { $item_rrd = "swFCPortRxCrcs"; }
  #if ( $item eq "crc_errors" )      { $item_rrd = "swFCPortRxCrcs"; }
  #if ( $item eq "encoding_errors" ) { $item_rrd = "swFCPortRxEncOutFrs"; }

  #print "001 $st_type $type $item $suffix\n";

  $cmd .= " --vertical-label=\\\"$item in $value_long\\\"";
  $cmd .= " --units-exponent=1.00";
  $cmd .= " --x-grid=$xgrid";
  $cmd .= " --alt-y-grid";

  # add spaces to volume name (for formating graph legend)
  my $item_short = $item;
  my $legend = sprintf ("%-38s","$item_short [$value_short]");
  my $legend_heading = "$item_short $delimiter [$value_short] $delimiter Avg $delimiter Max ";
  $legend_heading =~ s/%/%%/g;
  $cmd .= " COMMENT:\\\"$legend       Avg       Max                                                Avg       Max\\l\\\"";

  my $gtype="AREA";
  my $itemm_sum = "";
  my $volume_space = "";
  my $indx = 0;
  my $color_file_change = 0;
  my $cmd_print = ""; # print commands for clickable legend
  my $once_report = 0;
  my $rrd = "";

  foreach my $group_line (@group) {
    if ( $group_line eq '' || $group_line =~ m/^#/ ) {
      next;
    }
    (my $storage, my $volume_name) = split (/:/,$group_line);
    if ( ! defined ($volume_name) || $volume_name eq '' ) {
      next;
    }

    $prev = -1;
    my $itemm = $item."m".$volume_name.$storage;
    $itemm =~ s/\./Z/g;	# dots in rrdtool variable names causing problems for rrdtool parser
    $itemm =~ s/ /X/g; 	# space in rrdtool variable names causing problems for rrdtool parser
    $itemm =~ s/\#/Y/g; # hash in rrdtool variable names causing problems for rrdtool parser
    $itemm =~ s/:/R/g;  # hash in rrdtool variable names causing problems for rrdtool parser
    $itemm =~ s/-/S/g;  # dash in rrdtool variable names causing problems for rrdtool parser (some old versions)
    $itemm_sum = $itemm."sum";

    $rrd = "$wrkdir/$storage/port$volume_name.rrd";
    if ( ! -f $rrd ) {
      error ("SANPORT: does not exist $rrd ".__FILE__.":".__LINE__);
      next;
    }

    # avoid old volumes which do not exist in the period
    my $rrd_upd_time = (stat("$rrd"))[9];
    if ( $rrd_upd_time < $req_time ) {
      next;
    }

    # add spaces to volume name to have 18 chars total (for formating graph legend)
    $volume_space = $volume_name;
    $volume_space = sprintf ("%-15s","$volume_space");

    # Found out stored color index to keep same color for the volume across all graphs
    my $color_indx_found = -1;
    my $col_index = 0;
    foreach my $line_col (@color_save) {
      chomp ($line_col);
      if ( $line_col eq '' ) {
        next;
      }
      (my $color_indx_found_act, my $volume_name_save) = split (/:/,$line_col);
      if ( $volume_name_save =~ m/^$volume_name$storage$/ ) {
        $color_indx_found = $color_indx_found_act;
        $color_indx = $color_indx_found;
        last;
      }
      $col_index++;
    }
    if ( $color_indx_found == -1 ) {
      $color_file_change = 1;
      $color_save[$col_index] = $color_indx.":".$volume_name.$storage;
    }
    while ($color_indx > $color_max ) { # this should not normally happen, just to be sure
      $color_indx = $color_indx - $color_max;
    }
    # end color
    $lparn .= " ";

    if ( $lv != length($t) && length($lparn) > length($t) - 5) {
      if ( ! -f "$basedir/tmp/custom-group/.$group_name-$lim.cmd" ) {
        copy("$basedir/html/.$lim", "$basedir/tmp/custom-group/.$group_name-$lim.cmd");
      }
      $color_indx++;
      $indx++;
      next;
    }
  
    # my $time_first = find_real_data_start($rrd); --> no, no, only for summary (total graphs)
    #$cmd .= " CDEF:$itemm${indx}=TIME,$time_first,LT,$item${indx},$item${indx},UN,0,$item${indx},IF,IF";
    $cmd .= " DEF:$itemm${indx}=\\\"$rrd\\\":$item_rrd:AVERAGE";
    $cmd .= " CDEF:$itemm_sum${indx}=$itemm${indx},$val,/";

    $cmd .= " $gtype:$itemm_sum${indx}$color[$color_indx]:\\\"$volume_space\\\"";

    # build RRDTool cmd
    $cmd .= " GPRINT:$itemm_sum${indx}:AVERAGE:\\\"%8.0lf \\\"";
    $cmd .= " GPRINT:$itemm_sum${indx}:MAX:\\\"%8.0lf \\l\\\"";

    $cmd .= " PRINT:$itemm_sum${indx}:AVERAGE:\\\"%8.0lf $delimiter customg-san $delimiter $volume_name $delimiter $legend_heading $delimiter $color[$color_indx]\\\"";
    $cmd .= " PRINT:$itemm_sum${indx}:MAX:\\\" %8.0lf $delimiter $rrd $delimiter SAN-BRCD\\\"";

    $color_indx++;
    if ($color_indx > $color_max ) {
      $color_indx = 0;
    }
    $gtype="STACK";
    $indx++;
    if ( $lpar_v =~ m/free/ && $indx > 4 ) {
      last;
    }
  }

  if ( $indx == 0  && -f $rrd && ! $item_rrd eq '' ) {
    # nothing has been selected, there is no new data in RRD files --> creat at least empty graph
    $cmd .= " DEF:dummy=\\\"$rrd\\\":$item_rrd:AVERAGE";
    $cmd .= " LINE1:dummy#ffffff:\\\"\\\" ";
  }

  if ( $type_gr =~ m/d/ ) {
    # last update timestamp
    $cmd .= " COMMENT:\\\"Updated\\\: $last_time\\\"";
  }

  $cmd .= " HRULE:0#000000";
  # $cmd .= " VRULE:0#000000";  --> it is causing sigsegv on linuxeS
  $cmd =~ s/\\"/"/g;

  # write colors into a file
  if ( $color_file_change == 1 ) {
    open(FHC, "> $file_color_save") || error ("file does cannot be created :  $file_color_save ".__FILE__.":".__LINE__) && return 0;
    foreach my $line_cs (@color_save) {
      chomp ($line_cs);# it must be there, somehow appear there \n ...
      if ( $line_cs eq '' ) {
        next;
      }
      if ( $line_cs =~ m/:/ ) {
        print FHC "$line_cs\n";
      }
    }
    close (FHC);
  }
  # colours

  my $FH;
  open(FH, "> $tmp_file") || error ("Can't open $tmp_file : $! ".__FILE__.":".__LINE__) && return 0;
  print FH "$cmd\n";
  close (FH);

  return 0;
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

