#!/usr/bin/perl

use strict;
use warnings;
use RRDp;
use Xorux_lib;

my $rrdtool        = $ENV{RRDTOOL};
my $basedir        = $ENV{INPUTDIR};
my $wrkdir         = "$basedir/data";
my $tmpdir         = "$basedir/tmp";
my $KEEP_OUT_FILES = $ENV{KEEP_OUT_FILES};
my $demo           = 0;

if ( defined $ENV{DEMO} ) { $demo = $ENV{DEMO}; }

if ( ! defined($KEEP_OUT_FILES) || $KEEP_OUT_FILES eq '' ) {
    $KEEP_OUT_FILES = 0; # delete data out files as default
}

RRDp::start "$rrdtool";

my $last_update_file =  "$tmpdir/san_last_upd";
my $act_time         = localtime();
my $act_timestamp    = time();
my $last_timestamp   = $act_timestamp;
my $last_update_time = localtime($act_timestamp);
my $timestamp_diff   = 0;

if ( -f $last_update_file ) {
  $last_timestamp = (stat($last_update_file))[9];
  $timestamp_diff = $act_timestamp - $last_timestamp;
}

# test if is time for update
if ( ! -f $last_update_file || $timestamp_diff > 590 ) {
  open( LUF, ">$last_update_file" ) || error( "Couldn't open file $last_update_file $!" . __FILE__ . ":" . __LINE__ ) && exit;
  print LUF "$act_timestamp\n$act_time\n";
  close(LUF);

  load_output_data($wrkdir);
}

# close RRD pipe
RRDp::end;

exit;

sub load_output_data {

  my $wrkdir       = shift;
  my @switches_a = <$wrkdir/*\/SAN-*>;
  my @switches_all;
  foreach my $sw_n (@switches_a) {
    chomp $sw_n;
    if ( $sw_n =~ "SAN-BRCD" || $sw_n =~ "SAN-CISCO" ) {
      push(@switches_all, "$sw_n\n");
    }
  }

  foreach my $switch_name (@switches_all) {
    chomp $switch_name;
    $switch_name =~ s/^$wrkdir\///g;
    $switch_name =~ s/\/SAN-BRCD$//g;
    $switch_name =~ s/\/SAN-CISCO$//g;

    my $perf_string = "sanperf";
    opendir(DIR, "$wrkdir/$switch_name") || main::error ("directory does not exists : $wrkdir/$switch_name ".__FILE__.":".__LINE__) && return 0;

    my @files_unsorted = grep(/$switch_name\_$perf_string\_20.*/,readdir(DIR));
    my @files = sort { lc $a cmp lc $b } @files_unsorted;
    closedir(DIR);

    foreach my $file (@files) {
      chomp $file;
      my $input_file = "$wrkdir/$switch_name/$file";
      #print "$input_file\n";
      open( IN, "<$input_file" ) || error( "Couldn't open file $input_file $!" . __FILE__ . ":" . __LINE__ ) && exit;
      my @data = <IN>;
      close(IN);

      foreach my $port_data (@data) {
        chomp $port_data;
        if ( $port_data =~ "^act_time,bytes_tra,bytes_rec," ) { next; }

        my ( $act_time, $bytes_tra, $bytes_rec, $frames_tra, $frames_rec, $swFCPortNoTxCredits, $swFCPortRxCrcs, $port_speed, $reserve1, $reserve2, $reserve3, $reserve4, $reserve5, $reserve6, $switch_name, $db_name, undef ) = split(",",$port_data);

        my $rrd_file = "$wrkdir/$switch_name/$db_name";

        if ( -f $rrd_file ) {
          #print "$act_time : update rrd : $rrd_file\n";
          rrd_update($act_time, $bytes_tra, $bytes_rec, $frames_tra, $frames_rec, $swFCPortNoTxCredits, $swFCPortRxCrcs, $port_speed, $reserve1, $reserve2, $reserve3, $reserve4, $reserve5, $reserve6, $switch_name, $db_name, $rrd_file);
        }
        else {
          #print "$act_time : create rrd : $rrd_file\n";
          rrd_create($act_time, $switch_name, $db_name, $rrd_file);
        }
      }
      if ( $KEEP_OUT_FILES == 0 ) {
        unlink ("$input_file"); # delete already processed file
      }
    }
  }

}

sub rrd_create {

  my $act_time    = shift;
  my $switch_name = shift;
  my $db_name     = shift;
  my $rrd         = shift;
  my $STEP        = 60 ;
  my $data_type   = "COUNTER";

  # only for demo site!
  if ( $demo == 1 ) { $data_type = "GAUGE"; }

  my $time = $act_time - $STEP; # start time lower than actual one being updated
  my $no_time = $STEP * 7; # says the time interval when RRDTOOL considers a gap in input data

  # standard data retentions
  my $one_minute_sample = 86400;
  my $five_mins_sample  = 25920;
  my $one_hour_sample   = 4320;
  my $five_hours_sample = 1734;
  my $one_day_sample    = 1080;

  RRDp::cmd qq(create "$rrd"  --start "$time"  --step "$STEP"
  "DS:bytes_tra:$data_type:$no_time:0:102400000000"
  "DS:bytes_rec:$data_type:$no_time:0:102400000000"
  "DS:frames_tra:$data_type:$no_time:0:102400000000"
  "DS:frames_rec:$data_type:$no_time:0:102400000000"
  "DS:swFCPortNoTxCredits:$data_type:$no_time:0:102400000000"
  "DS:swFCPortRxCrcs:$data_type:$no_time:0:102400000000"
  "DS:port_speed:GAUGE:$no_time:0:102400000000"
  "DS:reserve1:$data_type:$no_time:0:102400000000"
  "DS:reserve2:$data_type:$no_time:0:102400000000"
  "DS:reserve3:$data_type:$no_time:0:102400000000"
  "DS:reserve4:$data_type:$no_time:0:102400000000"
  "DS:reserve5:$data_type:$no_time:0:102400000000"
  "DS:reserve6:$data_type:$no_time:0:102400000000"
  "RRA:AVERAGE:0.5:1:$one_minute_sample"
  "RRA:AVERAGE:0.5:5:$five_mins_sample"
  "RRA:AVERAGE:0.5:60:$one_hour_sample"
  "RRA:AVERAGE:0.5:300:$five_hours_sample"
  "RRA:AVERAGE:0.5:1440:$one_day_sample"
  );
  if (! Xorux_lib::create_check ("file: $rrd, $one_minute_sample, $five_mins_sample, $one_hour_sample, $five_hours_sample, $one_day_sample") ) {
    error ("unable to create $rrd : at ".__FILE__.": line ".__LINE__);
    RRDp::end;
    RRDp::start "$rrdtool";
    return 0;
  }
  return 1;

}

sub rrd_update {

  my $act_time            = shift;
  my $bytes_tra           = shift;
  my $bytes_rec           = shift;
  my $frames_tra          = shift;
  my $frames_rec          = shift;
  my $swFCPortNoTxCredits = shift;
  my $swFCPortRxCrcs      = shift;
  my $port_speed          = shift;
  my $reserve1            = shift;
  my $reserve2            = shift;
  my $reserve3            = shift;
  my $reserve4            = shift;
  my $reserve5            = shift;
  my $reserve6            = shift;
  my $switch_name         = shift;
  my $db_name             = shift;
  my $rrd                 = shift;
  my $last_rec            = "";

  if ( ! defined($bytes_tra)           || $bytes_tra eq '' )           { $bytes_tra = 'U'; }
  if ( ! defined($bytes_rec)           || $bytes_rec eq '' )           { $bytes_rec = 'U'; }
  if ( ! defined($frames_tra)          || $frames_tra eq '' )          { $frames_tra = 'U'; }
  if ( ! defined($frames_rec)          || $frames_rec eq '' )          { $frames_rec = 'U'; }
  if ( ! defined($swFCPortNoTxCredits) || $swFCPortNoTxCredits eq '' ) { $swFCPortNoTxCredits = 'U'; }
  if ( ! defined($swFCPortRxCrcs)      || $swFCPortRxCrcs eq '' )      { $swFCPortRxCrcs = 'U'; }
  if ( ! defined($port_speed)          || $port_speed eq '' )          { $port_speed = 'U'; }
  if ( ! defined($reserve1)            || $reserve1 eq '' )            { $reserve1 = 'U'; }
  if ( ! defined($reserve2)            || $reserve2 eq '' )            { $reserve2 = 'U'; }
  if ( ! defined($reserve3)            || $reserve3 eq '' )            { $reserve3 = 'U'; }
  if ( ! defined($reserve4)            || $reserve4 eq '' )            { $reserve4 = 'U'; }
  if ( ! defined($reserve5)            || $reserve5 eq '' )            { $reserve5 = 'U'; }
  if ( ! defined($reserve6)            || $reserve6 eq '' )            { $reserve6 = 'U'; }


  eval {
    RRDp::cmd qq(last "$rrd" );
    $last_rec = RRDp::read;
  };
  if ($@) {
    error ("failed during read last time $rrd");
    return 0;
  }
  chomp ($$last_rec);
  if ( isdigit($$last_rec) && $$last_rec >= $act_time ) {
    #error ("bad update time! $$last_rec >= $act_time");
    return 0;
  }


  RRDp::cmd qq(update "$rrd" $act_time:$bytes_tra:$bytes_rec:$frames_tra:$frames_rec:$swFCPortNoTxCredits:$swFCPortRxCrcs:$port_speed:$reserve1:$reserve2:$reserve3:$reserve4:$reserve5:$reserve6);

  my $answer = RRDp::read;
  if ( ! $$answer eq '' && $$answer =~ m/ERROR/ ) {
    error (" $switch_name: $rrd : $act_time:$bytes_tra:$bytes_rec:$frames_tra:$frames_rec:$swFCPortNoTxCredits:$swFCPortRxCrcs:$port_speed:$reserve1:$reserve2:$reserve3:$reserve4:$reserve5:$reserve6 ... : $$answer");
    if ( $$answer =~ m/is not an RRD file/ ) {
      (my $err,  my $file, my $txt) = split(/'/,$$answer);
      error ("Removing as it seems to be corrupted: $rrd");
      unlink("$rrd") || error ("Cannot rm $rrd : $!");
    }
    return 0;
  }
}

# error handling
sub error
{
  my $text = shift;
  my $act_time = localtime();
  chomp ($text);

  #print "ERROR          : $text : $!\n";
  print STDERR "$act_time: $text : $!\n";
  #print "$act_time: $text : $!\n" if $DEBUG > 2;;

  return 1;
}

sub isdigit
{
  my $digit = shift;

  if ( $digit eq '' ) {
    return 0;
  }

  my $digit_work = $digit;
  $digit_work =~ s/[0-9]//g;
  $digit_work =~ s/\.//;

  if (length($digit_work) == 0) {
    # is a number
    return 1;
  }

  # NOT a number
  #main::error ("there was expected a digit but a string is there, field: , value: $digit");
  return 0;
}
