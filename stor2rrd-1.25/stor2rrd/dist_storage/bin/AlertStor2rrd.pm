package AlertStor2rrd;
use Date::Parse;
use RRDp;
use strict;
use POSIX qw(strftime);

my @config_alert_data = "";
my @config_alert = ("logs/alert_history.log","0","25","60","15",""); # predefined defaults
my @config_alert_key = ("ALERT_HISTORY","NAGIOS","EMAIL_GRAPH","REPEAT_DEFAULT","PEAK_TIME_DEFAULT","EXTERN_ALERT");
my $ALERT_HISTORY = 0;
my $NAGIOS = 1;
my $EMAIL_GRAPH = 2;
my $REPEAT_DEFAULT = 3;
my $PEAK_TIME_DEFAULT = 4;
my $EXTERN_ALERT = 5;


sub alert {
  my ($storage,$st_type,$time_act,$basedir,$DEBUG) = @_;

  my $debug = $ENV{DEBUG_ALERT};
  if ( defined ($debug) &&  isdigit($debug) && $debug == 1 ) {
    $DEBUG=22; # 22 that is alerting verbose level
  }

  if ( ! defined($storage) || $storage eq '' || ! defined($st_type) || $st_type eq '' || ! defined($time_act) || $time_act eq '' ) {
    error("Alerting cannot run, is not set one of following storage/st_type/time_act ($storage/$st_type/$time_act) ".__FILE__.":".__LINE__);
    return (1);
  }

  # check if is passed time is in text or unix form, convert necessary
  my $time_act_u = $time_act;
  if ( isdigit($time_act) ) {
    $time_act = strftime ("%H:%M:%S %d/%m/%Y", localtime($time_act_u));
  }
  else {
    $time_act_u = str2time($time_act);
    $time_act = strftime ("%H:%M:%S %d/%m/%Y", localtime($time_act_u));
  }
   
  print "\n" if $DEBUG == 22;
  print "Alerting starts: storage=$storage, st_type=$st_type, time=$time_act, debug=$DEBUG\n" if $DEBUG == 22;


  # get cmd line params
  my $wrkdir = "$basedir/data";
  my $alert_log="$basedir/alert.log";
  my $nagios_dir="$basedir/nagios";
  my $cfg = "$basedir/web_config/alerting.cfg"; 
  if ( ! -f "$cfg" ) {
    $cfg = "$basedir/etc/alert.cfg"; 
  }
  if ( defined$ENV{ALERCFG} && -f $ENV{ALERCFG} ) {
    $cfg = $ENV{ALERCFG};
  }
  if ( -f "$basedir/etc/web_config/alerting.cfg" ) {
    $cfg = "$basedir/etc/web_config/alerting.cfg" # one created by the GUI is prefered
  }


  
  # use alert here to be sure it does not hang due to any problem
  my $timeout = 600; # it must be enough otherwise oit does not make sense to alert
  eval {
    my $act_time = localtime();
    local $SIG{ALRM} = sub {die "died in SIG ALRM: ";};
    alarm($timeout);

    my $ret = read_cfg ($cfg,$DEBUG,$storage,\@config_alert_key);
    if ( $ret == 0 ) {
      return 0;
    }

    if ( $DEBUG == 22 ) {
      my $line_no = 0;
      foreach my $l (@config_alert) {
        print "Config global  : $config_alert_key[$line_no] : $l\n";
        $line_no++;
      }
      foreach my $l (@config_alert_data) {
        print "Config alert   : $l\n";
      }
    }

    check_data($basedir,$storage,$st_type,$time_act,$time_act_u,$wrkdir,$DEBUG,$nagios_dir,\@config_alert_data);

    alarm (0);

    # close RRD pipe
    my $unixt = str2time($act_time);
    $act_time = localtime();
    my $unixt_end = str2time($act_time);
    my $run_time = $unixt_end - $unixt;
    print "Finished       : $act_time, run time: $run_time secs\n" if $DEBUG == 22;
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
  my ($cfg,$DEBUG,$storage,$config_alert_key_tmp) = @_;
  my @config_alert_key = @{$config_alert_key_tmp};


  print "Alrt cfg read  : $cfg\n" if $DEBUG == 22;
  if ( ! -f "$cfg" ) {
    return 0; # alerting is not in place
  }

  open(FH, "< $cfg") || error("could not open $cfg : $!".__FILE__.":".__LINE__) && return (0) ;
  my @lines = <FH>;
  close (FH);

  # allow usage of additional alert.cfg files like : etc/alert*.cfg
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
  my $key_no = 0;
  my $key = "";
  foreach my $line (@lines) {
    if ( $line =~ m/^#/ ) {
      next;
    }
    chomp ($line);
    $line =~ s/#.*$//;

    $key_no = 0;
    foreach $key (@config_alert_key) {
      # search for default variables and replace defaults
      if ( $line =~ m/^$key=/ ) {
        (my $trash, my $value) = split(/=/,$line);
        if ( defined ($value) && ! $value eq '' ) {
          $value =~ s/ //g;
          $value =~ s/	//g;
          if ( defined ($value) && ! $value eq '' ) {
            $config_alert[$key_no] =  $value;
          }
        }
      }
      $key_no++;
    }
    if ( $key_no < $#config_alert_key ) {
      next; # the key has been found
    }

    # continue with data lines
    if ( $line =~ m/^VOLUME:/ ) {
      (my $trash, my $storage_act) = split (/:/,$line); 
      if ( defined ($storage_act) && ! $storage_act eq '' && $storage =~ m/^$storage_act$/ ) {
        # save only data for actual storage
        $config_alert_data[$data_line] = $line;
        $data_line++;
        print "Data identified: $line\n" if $DEBUG == 22;
      }
    }
    if ( $line =~ m/^EMAIL:/ ) {
      # save email groups
      $config_alert_data[$data_line] = $line;
      $data_line++;
      print "Data identified: $line\n" if $DEBUG == 22;
    }
  }

  $key_no = 0;
  foreach $key (@config_alert_key) {
    if ( $key_no != $EXTERN_ALERT && $config_alert[$key_no] eq '' ) {
      error ("$key is not set, exiting ...");
      return (0);
    }
    $key_no++;
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

#VOLUME:storage:name:[io|io_read|io_write|data|data_read|data_write]:limit:peek time in min:alert repeat time in min:exclude time:email group
#========================================================================================================================
#VOLUME:storwize01:BBzOd02:ior:1:::test@stor2rrd.com


sub check_data {
  my ($basedir,$storage,$st_type,$time_act,$time_act_u,$wrkdir,$DEBUG,$nagios_dir,$config_alert_data_tmp) = @_;
  my @config_alert_data = @{$config_alert_data_tmp};
  my $vol_cfg_file = "$wrkdir/$storage/VOLUME/volumes.cfg";
  my $alert_repeat_file="$basedir/tmp/alert_repeat-stor2rrd-$storage.tmp";
  my ($sec,$min,$hour_act) = localtime();
  my $email_graph = $config_alert[$EMAIL_GRAPH];


  # Volume translation
  if ( ! -f "$vol_cfg_file" ) {
    error ("Does not exist volume cfg file: $vol_cfg_file ".__FILE__.":".__LINE__);
    return 1;
  }

  open(FV, "< $vol_cfg_file") || error("Can't open $vol_cfg_file $! ".__FILE__.":".__LINE__) && return 1;
  my @vol_cfg = <FV>;
  close (FV);

  my @repeat_list = "";
  if ( -f $alert_repeat_file ) {
    open(FHR, "< $alert_repeat_file");
    @repeat_list = sort(<FHR>);
    close (FHR);
  }


  my $volume_prev = "NA";
  my $volume_id = "NA";
  my @vol_file = "";
  $vol_file[0] = "NA";

  my @config_email = "";
  my $line_email_no = 0;
  # separate EMAIL
  foreach my $line (@config_alert_data) {
    chomp ($line);
    if ( $line =~ m/^EMAIL/ ) {
      $config_email[$line_email_no] = $line;
      $line_email_no++;
    }
  }
    

  # go through line by line with alerts
  foreach my $line (@config_alert_data) {
    chomp ($line);
    if ( $line =~ m/^EMAIL/ ) {
      next;
    }
    
    (my $trash, my $storage_act, my $volume, my $item, my $limit, my $peak_time, my $repeat_time, my $exclude_time, my $email) = split (/:/,$line);
    if ( ! defined ($storage_act) || $storage_act eq '' || $storage !~ m/^$storage_act$/ ) {
      # email can be empty, then is used only for externa purposes like external scrip[t or nagios
      next; # ignoring, it is not specified the storage
    }
    if ($storage_act eq '' || $volume eq '' || $item eq '' || $limit eq '' ) {
      error("$storage: alerting rule does not contain all required fields: $line ".__FILE__.":".__LINE__);
      next;
    }
    if ( ! defined($repeat_time) || $repeat_time eq '' || ! isdigit($repeat_time) ) {
      #use the global one
      $repeat_time = $config_alert[$REPEAT_DEFAULT];
    }
    if ( ! defined($peak_time) || $peak_time eq '' || ! isdigit($peak_time) ) {
      #use the global one
      $peak_time = $config_alert[$PEAK_TIME_DEFAULT];
    }

    print "Working for    : $storage:$volume:$item : $line\n" if $DEBUG == 22;

    # check if the time is not excluded.
    if ( defined ($exclude_time) && ! $exclude_time eq '' ) {
      my ($hour_start, $hour_end) = split (/\-/,$exclude_time);
      $hour_start =~ s/ //g;
      if ( ! defined ($hour_end) || $hour_start eq '' ) {
        error ("$storage:$volume:$item : wrong format of exclude time ($exclude_time), it should be like 1-5 to exclude time pro 1am to 5am, ignoring it ".__FILE__.":".__LINE__);
      }
      else {
        $hour_end =~ s/ //g;
        if ( isdigit($hour_start) && isdigit($hour_end) ) {
          if ( $hour_act >= $hour_start && $hour_act < $hour_end ) {
            print "Excluded time  : $storage:$volume:$item : excluded due to time exclusion: $exclude_time\n" if $DEBUG == 22;
            next;
          }
          else {
            print "Excl time ok   : $storage:$volume:$item : $hour_start - $hour_end\n" if $DEBUG == 22;
          }
        }
        else {
          error ("$storage:$volume:$item : wrong format of exclude time ($exclude_time), it should be like 1-5 to exclude time pro 1am to 5am, ignoring it ".__FILE__.":".__LINE__);
        }
      }
    }
   
    if ( $volume !~ m/^$volume_prev$/ ) { 
      # skip that if the same volume next alert line
      $volume_id = "NA";
      foreach my $vol_act (@vol_cfg) {
        chomp($vol_act);
        if ( $vol_act =~ m/^$volume : / ) {
          (my $name, $volume_id) = split (/:/,$vol_act); 
          $volume_id =~ s/ //g;
          last;
        }
      }

      if ( $volume_id =~ m/^NA$/ ) {
        error ("$storage:$volume:$item  Volume \"$volume\" has not been found in $vol_cfg_file ".__FILE__.":".__LINE__);
        next;
      }
      $volume_id =~ s/ //g;
      $volume_id =~ s/;$//;
      #print "03 $volume : $volume_id\n";

      $vol_file[0] = "NA";
      my $file_time_stamp = 0;

      if ( $volume_id =~ m/;/ ) {
        # Multilevel volumes (DS8k), 1 volume name might contain several physical volumes
        my $vol_file_indx = 0;
        foreach my $volume_act (split(/;/,$volume_id)) {
          $file_time_stamp = 0;
          $volume_act =~ s/^0x//;
          foreach my $vol_file_tmp (<$wrkdir/$storage/VOLUME/$volume_act*.rrd>) {
            # there can be volumes with pool identification in the name (DS5k and XIV at least)  vol_name-Pxy.rrd
            # select the most actual one as per the file timestamp
            my $file_time_stamp_act = (stat("$vol_file_tmp"))[9];
            if ( $file_time_stamp_act > $file_time_stamp ) {
              $vol_file[$vol_file_indx] = $vol_file_tmp;
              $vol_file_indx++;
            }
          }
        }

      }
      else {
        # Normal volumes just mapping ID to 1 file name
        foreach my $vol_file_tmp (<$wrkdir/$storage/VOLUME/$volume_id*.rrd>) {
          # there can be volumes with pool identification in the name (DS5k and XIV at least)  vol_name-Pxy.rrd
          # select the most actual one as per the file timestamp
          my $file_time_stamp_act = (stat("$vol_file_tmp"))[9];
          if ( $file_time_stamp_act > $file_time_stamp ) {
            $vol_file[0] = $vol_file_tmp;
          }
        }
      }

      if ( $vol_file[0] =~ m/^NA$/ ) {
        error ("$storage:$volume:$item ($volume_id) volume file has not been found  ".__FILE__.":".__LINE__);
        next;
      }
    }
    if ( $DEBUG == 22 ) {   
      foreach my $vol_file_act (@vol_file) {
        print "Volume file    : $storage:$volume:$item : $vol_file_act \n";
      }
    }
    $volume_prev = $volume;

    # Volume file has been identified!


    # get utilization
    my $graph_path = "$basedir/tmp/alert-graph-$storage-$item.png";

    # do not create graph unnecessary --> 0 instead of $email_graph
    my $limit_act = get_util(0,$graph_path,$storage,$st_type,$item,$time_act,$peak_time,$time_act_u,$volume,$DEBUG,$basedir,\@vol_file); 
    print "Volume ulit    : $storage:$volume:$item : $limit_act (limit is $limit)\n" if $DEBUG == 22;
    if ( $limit_act == -1 ) {
       next; # something was wrong
    }

    # check if it is over the limit
    if ( $limit_act < $limit ) {
      next;
    }

    # check retention time
    my ($last_alert_time_u, $last_alert_time, @repeat_list_passed) = get_last_alert_time("$storage:$volume:$item",$time_act,$time_act_u,$DEBUG,\@repeat_list);
    if ( $time_act_u < $last_alert_time_u + $repeat_time * 60) {
      # retention time does not allow alarming
      print "Retention      : $storage:$volume:$item : utilization is over the limit ($limit_act > $limit) however repeat time supress alarming now, last: $last_alert_time, retention: $repeat_time\n" if $DEBUG == 22;
      next;
    }
    @repeat_list = @repeat_list_passed; # must be here to do not overwrite the record when no alarm is issued

    # issue the alert
    print "Alerting       : $storage:$volume:$item : utilization is over the limit ($limit_act > $limit) alerting\n" if $DEBUG == 22;
    log_to_alert_log($time_act,$storage,$volume,$item,$limit_act,$limit,$email);

    if ( $email_graph > 0 ) {
      # create graph now when there is sure that it will send out
      get_util($email_graph,$graph_path,$storage,$st_type,$item,$time_act,$peak_time,$time_act_u,$volume,$DEBUG,$basedir,\@vol_file); 
    }

    if ( defined($email) && ! $email eq '' ) {
      sendmail ($config_alert[$EMAIL_GRAPH],$graph_path,$email,$time_act,$peak_time,$storage,$volume,$item,$limit_act,$limit,$line_email_no,$DEBUG,\@config_email);
    }

    if ( $config_alert[$NAGIOS] == 1 ) {
      # nagios alarm
      nagios_alarm($storage,$volume,$item,$limit_act,$limit,$time_act,$nagios_dir,$DEBUG);
    }

    # extern alert
    if ( defined ($config_alert[$EXTERN_ALERT]) && ! $config_alert[$EXTERN_ALERT] eq '' ) {
      extern_alarm($storage,$volume,$item,$limit_act,$limit,$time_act,$config_alert[$EXTERN_ALERT],$DEBUG,$basedir);
    }
  }

  update_repeat_table ($alert_repeat_file,\@repeat_list);
  return 1;
}

sub log_to_alert_log {
  my ($time_act,$storage,$volume,$item,$limit_act,$limit,$email) = @_; 

  open(FHW, ">> $config_alert[$ALERT_HISTORY]") || error("could not open $config_alert[$ALERT_HISTORY] : $!".__FILE__.":".__LINE__) && return 1;
  if ( defined($email) && ! $email eq '' ) {
    print FHW "$time_act: $storage:$volume:$item over the limit: $limit_act (limit $limit), email: $email\n";
  }
  else {
    print FHW "$time_act: $storage:$volume:$item over the limit: $limit_act (limit $limit), no email\n";
  }
  close (FHW);
  return 1;
}


# get time of the last alarm
sub get_last_alert_time {
  my ($identification,$time_act,$time_act_u,$DEBUG,$repeat_list_tmp) = @_;
  my @repeat_list = @{$repeat_list_tmp};

  my $line_no = -1;
  foreach my $line (@repeat_list) {
    chomp ($line);
    $line_no++;
    (my $ident, my $time_alrt_u, my $time_alrt) = split (/\|/,$line);

    if ( ! defined ($ident) || $ident eq '' || ! defined ($time_alrt_u) || $time_alrt_u eq '' ) {
      # something wrong
      next;
    }

    if ( $ident =~ m/^$identification$/ ) {
      # found a record
      $repeat_list[$line_no] = "$identification|$time_act_u|$time_act";
      return ($time_alrt_u, $time_alrt, @repeat_list);
    }
  }
  $line_no++;
  $repeat_list[$line_no] = "$identification|$time_act_u|$time_act";

  return (-1, -1, @repeat_list);
}


sub update_repeat_table {
  my ($alert_repeat_file,$repeat_list_tmp) = @_;
  my @repeat_list = @{$repeat_list_tmp};

  # update retention alerts
  open(FHW, "> $alert_repeat_file") || error("could not open $alert_repeat_file : $!".__FILE__.":".__LINE__) && return 1;
  foreach my $line (@repeat_list) {
    chomp ($line);
    print FHW "$line\n";
  }
  close (FHW);

  return 1;
}
  
sub get_util {
  my ($email_graph,$graph_path,$storage,$st_type,$item,$time_act,$peak_time,$time_act_u,$volume,$DEBUG,$basedir,$vol_file_tmp) = @_;
  my @vol_file = @{$vol_file_tmp};
  my $peak_time_sec = $peak_time * 60;
  my $width = 300;
  my $ret = -1;

  # translate [io|read_io|write_io|data|read|write] into real names used by storages
  my $item_translated = $item;

  if ( $st_type =~ m/^SWIZ$/ ||  $st_type =~ m/^XIV$/ ) {
    if ( $item =~ m/^data$/ ) {
      # it does not have totals --> summ it up
      $item_translated = "read";
      my $ret1 = get_util_exec ($email_graph,$graph_path,$time_act,$basedir,$time_act_u,$peak_time_sec,$width,$item_translated,$storage,$volume,$item,$DEBUG,\@vol_file);
      $item_translated = "write";
      my $ret2 = get_util_exec ($email_graph,$graph_path,$time_act,$basedir,$time_act_u,$peak_time_sec,$width,$item_translated,$storage,$volume,$item,$DEBUG,\@vol_file);
      $ret = $ret1 + $ret2;
    }
    if ( $item =~ m/^io$/ ) {
      # it does not have totals --> summ it up
      $item_translated = "read_io";
      my $ret1 = get_util_exec ($email_graph,$graph_path,$time_act,$basedir,$time_act_u,$peak_time_sec,$width,$item_translated,$storage,$volume,$item,$DEBUG,\@vol_file);
      $item_translated = "write_io";
      my $ret2 = get_util_exec ($email_graph,$graph_path,$time_act,$basedir,$time_act_u,$peak_time_sec,$width,$item_translated,$storage,$volume,$item,$DEBUG,\@vol_file);
      $ret = $ret1 + $ret2;
    }
    if ( $item !~ m/^data$/ || $item !~ m/^io$/ ) { 
      $ret = get_util_exec ($email_graph,$graph_path,$time_act,$basedir,$time_act_u,$peak_time_sec,$width,$item_translated,$storage,$volume,$item,$DEBUG,\@vol_file);
    }
  }

  if ( $st_type =~ m/^DS5K$/ ) {
    if ( $item =~ m/^io$/ )   { 
      $item_translated = "io_rate"; 
      $ret = get_util_exec ($email_graph,$graph_path,$time_act,$basedir,$time_act_u,$peak_time_sec,$width,$item_translated,$storage,$volume,$item,$DEBUG,\@vol_file);
    }
    if ( $item =~ m/^data$/ ) { 
      $item_translated = "data_rate"; 
      $ret = get_util_exec ($email_graph,$graph_path,$time_act,$basedir,$time_act_u,$peak_time_sec,$width,$item_translated,$storage,$volume,$item,$DEBUG,\@vol_file);
    }
    if ( $item =~ m/^data_/ || $item =~ m/^io_/ ) { 
      error ("$storage:$volume:$item : wrong $item, it is not supported for this ($$st_type) kind of storage ".__FILE__.":".__LINE__) && return -1;
    }
  }

  if ( $st_type =~ m/^DS8K$/ ) {
    if ( $item =~ m/^io$/ )   { 
       $item_translated = "io_rate"; 
      $ret = get_util_exec ($email_graph,$graph_path,$time_act,$basedir,$time_act_u,$peak_time_sec,$width,$item_translated,$storage,$volume,$item,$DEBUG,\@vol_file);
    }
    if ( $item =~ m/^data$/ ) { 
      $item_translated = "data_rate"; 
      $ret = get_util_exec ($email_graph,$graph_path,$time_act,$basedir,$time_act_u,$peak_time_sec,$width,$item_translated,$storage,$volume,$item,$DEBUG,\@vol_file);
    }
    if ( $item =~ m/^read$/ || $item =~ m/^write$/ ) { 
      $ret = get_util_exec ($email_graph,$graph_path,$time_act,$basedir,$time_act_u,$peak_time_sec,$width,$item_translated,$storage,$volume,$item,$DEBUG,\@vol_file);
    }
    if ( $item =~ m/^read_io$/ || $item =~ m/^write_io$/ ) { 
      foreach my $vol_file_act (@vol_file) {
        $vol_file_act =~ s/\.rrd/\.rrc/; # this is stored in .rrc file
      }
      $ret = get_util_exec ($email_graph,$graph_path,$time_act,$basedir,$time_act_u,$peak_time_sec,$width,$item_translated,$storage,$volume,$item,$DEBUG,\@vol_file);
    }
  }

  return $ret;
}

sub get_util_exec {
  my ($email_graph,$graph_path,$time_act,$basedir,$time_act_u,$peak_time_sec,$width,$item_translated,$storage,$volume,$item,$DEBUG,$vol_file_tmp) = @_;
  my @vol_file = @{$vol_file_tmp};
  my $answer = "";
  my $start_time = $time_act_u-$peak_time_sec;
    
  if ( $email_graph > 0 ) {
    print "Creating graph : $storage:$volume:$item : $graph_path\n" if $DEBUG == 22;
    $start_time = $time_act_u-$email_graph*3600;
  }

  $graph_path =~ s/://g;
  my $cmd .= "graph \"$graph_path\"";
  $cmd .= " --start \"$start_time\"";
  $cmd .= " --end \"$time_act_u\"";
  if ( $email_graph > 0 ) {
    $cmd .= " --title \\\"$storage:$volume:$item: last $email_graph"."h\\\"";
    my $pic_col = $ENV{PICTURE_COLOR};
    $cmd .= " --imgformat PNG";
    $cmd .= " --slope-mode";
    $cmd .= " --no-minor";
    $cmd .= " --height=150";
    $cmd .= " --lower-limit=0.00";
    $cmd .= " --color=BACK#$pic_col";
    $cmd .= " --color=SHADEA#$pic_col";
    $cmd .= " --color=SHADEB#$pic_col";
    $cmd .= " --color=CANVAS#$pic_col";
    $cmd .= " --alt-autoscale-max";
    $cmd .= " --units-exponent=1.00";
    $cmd .= " --alt-y-grid";
    my $vertical_label="--vertical-label=\"MB per seconds\"";
    if ( $item_translated =~ m/io/ ) {
      $vertical_label="--vertical-label=\"IO per seconds\"";
    }
    $cmd .= " $vertical_label";
  }
  $cmd .= " --width=$width";
  if ( $email_graph == 25 ) {
      $cmd .= " --x-grid=MINUTE:60:HOUR:2:HOUR:4:0:%H";
  }

  # Disable Tobi's promo
  my $rrd_ver = $RRDp::VERSION;
  if ( isdigit($rrd_ver) && $rrd_ver > 1.34 ) {
    # graphv is supported since rrdtool-1.3rc5
    $cmd .= " --disable-rrdtool-tag";
  }

  my $indx = 0;
  foreach my $vol_file_act (@vol_file) {
    # more input files here can be --> ie DS8k multilevel volumes
    $cmd .= " DEF:item_part${indx}=\"$vol_file_act\":$item_translated:AVERAGE";
    $indx++;
  }

  # get summary
  my $index_actual = 0;
  $cmd .= " CDEF:item=item_part${index_actual}";
  $index_actual++;
  for (; $index_actual < $indx; $index_actual++) {
    $cmd .= ",item_part${index_actual},+";
  }

  my $item_space = sprintf ("%-10s",$item);
  if ( $item_translated =~ m/io/ ) {
    if ( $email_graph > 0 ) {
      $cmd .= " COMMENT:\\\"                 average   maximu\\n\\\"";
      $cmd .= " LINE1:item#00FF00:\" $item_space \"";
      $cmd .= " GPRINT:item:AVERAGE:\\\"%6.0lf \\\"";
      $cmd .= " GPRINT:item:MAX:\\\"%6.0lf \\\"";
    }
    else {
      $cmd .= " PRINT:item:AVERAGE:\\\"%6.0lf \\\"";
    }

  }
  else {
    $cmd .= " CDEF:itemmb=item,1024,/";
    if ( $email_graph > 0 ) {
      $cmd .= " COMMENT:\\\"                average    maximu\\n\\\"";
      $cmd .= " LINE1:itemmb#00FF00:\" $item_space \"";
      $cmd .= " GPRINT:itemmb:AVERAGE:\\\"%6.1lf \\\"";
      $cmd .= " GPRINT:itemmb:MAX:\\\"%6.1lf \\\"";
    }
    else {
      $cmd .= " PRINT:itemmb:AVERAGE:\\\"%6.3lf \\\"";
    }
  }
  if ( $email_graph > 0 ) {
    $cmd .= " COMMENT:\\n";
    $cmd .= " HRULE:0#000000";
  }
  $cmd =~ s/\\"/"/g;
  #print "$cmd\n";

  eval {
    RRDp::cmd qq($cmd);
    $answer = RRDp::read;
  };

  if ($@) {
    chomp($@);
    error("$storage:$volume:$item: RRD file read problem: $vol_file[0] $@ "); # file&line is apended there in that variable already
    return -1;
  }

  if ( $email_graph > 0 ) {
    return 1; # only creating of graph, do not utilization value
  }


  chomp ($$answer);
  if ( $$answer =~ m/NaN/ || $$answer =~ m/nan/ ) {
    error ("$storage:$volume:$item : no data at: $time_act - $peak_time_sec seconds ".__FILE__.":".__LINE__);
    return -1;
  }
  chomp($$answer);
  my $page= -1;
  foreach my $line (split (/\n/,$$answer)) {
    $page=$line;
    chomp ($page);
    $page =~ s/ //g;
  }
  if ( $$answer  =~ "ERROR" ) {
    error ("$storage:$volume:$item : $vol_file[0]: Graph rrdtool error : $$answer ".__FILE__.":".__LINE__);
    return -1;
  }
  
  if ( isdigit($page) == 1 ) {
    return $page;
  }
  else {
    error ("$storage:$volume:$item : $vol_file[0]: Graph rrdtool error : $$answer ; page: $page ".__FILE__.":".__LINE__);
    return -1;
  }
}

sub sendmail
{
  my ($email_graph,$graph_path,$email,$time_act,$peak_time,$storage,$volume,$item,$limit_act,$limit,$line_email_no,$DEBUG,$config_email_tmp) = @_;
  my @config_email = @{$config_email_tmp};
  my $mailfrom = "stor2rrd";
  my $mailprog = "/usr/sbin/sendmail";
  my $value = "";
  if ( $item =~ /io/ ) {
    $value = sprintf ("%.0f IO/sec",$limit_act);
  }
  else {
    $value = sprintf ("%.1f MB/sec",$limit_act);
  }
  my $subject = "STOR2RRD: Alert for $storage:$volume:$item, actual traffic: $value (limit $limit)";

  if ( $line_email_no == 0 ) {
    error("No any alerting targed has been specified, define email rules via the GUI ".__FILE__.":".__LINE__);
    return 1;
  }

  foreach my $email_act (@config_email) {
    chomp($email_act);
    (my $trash, my $email_name, my $email_list_line) = split(/:/,$email_act);
    if ( ! defined($email_name) || $email_name eq '' || ! defined($email_list_line) || $email_list_line eq '' ) {
      next;
    }
    if ( $email_name =~ m/^$email$/ ) {
      # email group has been found
      (my @email_list) = split (/,/,$email_list_line);
      foreach my $email (@email_list) {
        $email =~ s/ //g;
        print "Emailing       : $storage:$volume:$item : $value : sending email to $email\n" if $DEBUG == 22;
        if (open MAIL, "|$mailprog -t") {
          print MAIL "To: $email\n" ;
          print MAIL "From: $mailfrom\n" ;
          print MAIL "Reply-To: $mailfrom\n" ;
          print MAIL "X-Mailer: stor2rrd 1.0\n" ;
          print MAIL "Subject: $subject\n\n" ;
          print MAIL "STOR2RRD alert\n Time: $time_act\n Storage: $storage:\n Volume: $volume\n Metric: $item\n Average throughput during last $peak_time"."mins: $value\n \(MAX limit: $limit\)\n";
          print MAIL "\n\n";
          if ( $email_graph > 0 && -f $graph_path ) {
            print "Attachment     : $storage:$volume:$item : attaching : $graph_path\n" if $DEBUG == 22;
            open(PNG, "uuencode $graph_path $storage:$volume:$item.png |");
            binmode(PNG);
            while (read(PNG,$b,4096)) {
              print MAIL "$b";
            }
            close(PNG);
          }
          close(MAIL);
        }
      }
      if ( -f $graph_path ) {
        # remove here, to allow to be send to more addresses
        unlink ($graph_path);
      }
    }
  }
  return 0;
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


sub nagios_alarm
{
  my ($storage,$volume,$item,$limit_act,$limit,$time_act,$nagios_dir,$DEBUG) = @_;
  my $value = "";
  if ( $item =~ /io/ ) {
    $value = sprintf ("%.0f IO/sec",$limit_act);
  }
  else {
    $value = sprintf ("%.1f MB/sec",$limit_act);
  }

  print "Alert nagios   : $storage:$volume:$item : utilization=$value\n" if $DEBUG == 22;

  if (! -d "$nagios_dir" ) {
    print "mkdir          : $nagios_dir\n" if $DEBUG ;
    mkdir("$nagios_dir", 0755) || error("Cannot mkdir $nagios_dir: $!".__FILE__.":".__LINE__) && return 1;
    chmod 0777, "$nagios_dir"  || error("Can't chmod 666 $nagios_dir: $!".__FILE__.":".__LINE__) && return 1;
  }

  if (! -d "$nagios_dir/$storage" ) {
    print "mkdir          : $nagios_dir/$storage\n" if $DEBUG ;
    mkdir("$nagios_dir/$storage", 0755) || error("Cannot mkdir $nagios_dir/$storage: $!".__FILE__.":".__LINE__) && return 1;
    chmod 0777, "$nagios_dir/$storage"  || error("Can't chmod 666 $nagios_dir/$storage: $!".__FILE__.":".__LINE__) && return 1;
  }

  open(FH, "> $nagios_dir/$storage/$volume-$item") || error("Can't create $nagios_dir/$storage/$volume-$item : $!".__FILE__.":".__LINE__) && return 1;


  print FH "Critical alert for: $storage:$volume:$item utilization=$value,MAX limit=$limit,time=$time_act\n";
  close (FH);

  chmod 0666, "$nagios_dir/$storage/$volume-$item" || error("Can't chmod 666 $nagios_dir/$storage/$volume-$item : $!".__FILE__.":".__LINE__) && return 1;

  return 1;
}

sub extern_alarm
{
  my ($storage,$volume,$item,$limit_act,$limit,$time_act,$extern_alert,$DEBUG,$basedir) = @_;

  if ( ! -f "$basedir/$extern_alert" ) {
    if ( ! -x "$basedir/$extern_alert" ) {
      error ("EXTERN_ALERT is set but the file is not executable : $basedir/$extern_alert ".__FILE__.":".__LINE__) && return 1;
    }
  }
  else {
    if ( ! -f "$extern_alert" ) {
      error ("EXTERN_ALERT is set but the file does not exist: $extern_alert : $basedir/$extern_alert ".__FILE__.":".__LINE__) && return 1;
    }
    else {
      if ( ! -x "$extern_alert" ) {
        error ("EXTERN_ALERT is set but the file is not executable : $extern_alert ".__FILE__.":".__LINE__) && return 1;
      }
    }
  }

  my $value = "";
  if ( $item =~ /io/ ) {
    $value = sprintf ("%.0f IO/sec",$limit_act);
  }
  else {
    $value = sprintf ("%.1f MB/sec",$limit_act);
  }

  print "Alert external : $storage:$volume:$item : utilization=$value\n" if $DEBUG == 22;

  system("$extern_alert", "$storage", "$volume", "$item", "$limit_act", "$limit", "$time_act", "$value");

  return 1;
}


