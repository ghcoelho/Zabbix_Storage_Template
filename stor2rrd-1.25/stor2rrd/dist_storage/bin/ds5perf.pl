#!/usr/bin/perl

### Modules
use strict;
use warnings;
use Time::Local;

### Options
my $storage_name;
my $storage_type;
my $sample_rate;
my $out_perf_file;
my $DS5_CLIDIR;
my $SMcli;
my $inputdir;
my @storage_items;
my @logicalDrives;
my $cmd_performanceStats;
my $cmd_logicalDrives;
my $user_name;
my $user_pw;
my $version;
my $tmp_file;
my $webdir = $ENV{WEBDIR};

if ( defined $ENV{STORAGE_NAME} ) {
  $storage_name = $ENV{STORAGE_NAME};
}
else {
  error( "ds5perf.pl: DS5k storage name alias is required! $!" . __FILE__ . ":" . __LINE__ ) && exit;
}
my $tmp_dir    = "/home/lpar2rrd/stor2rrd/tmp/";
my $output_dir = "/home/lpar2rrd/stor2rrd/data/$storage_name/";
if   ( defined $ENV{SAMPLE_RATE} ) { $sample_rate = $ENV{SAMPLE_RATE} }
if   ( defined $ENV{DS5_CLIDIR} )  { $DS5_CLIDIR  = $ENV{DS5_CLIDIR}, $SMcli = "$DS5_CLIDIR/SMcli"; }
else                               { $SMcli       = "SMcli"; }
if ( defined $ENV{DS5K_USER} ) { $user_name = $ENV{DS5K_USER} }
if ( defined $ENV{DS5K_PW} )   { $user_pw   = $ENV{DS5K_PW} }
if ( defined $ENV{INPUTDIR} )  { $inputdir  = $ENV{INPUTDIR}; $output_dir = "$inputdir/data/$storage_name/"; $tmp_dir = "$inputdir/tmp/"; }
if ( defined $ENV{TMPDIR} )    { $tmp_dir   = $ENV{TMPDIR} }
my $timeout = $sample_rate * 3;    #alarm timeout

### SMcli commands
my $cmd_performanceStats_to_errorlog;
my $cmd_logicalDrives_to_errorlog;
eval {
  # Set alarm
  my $act_time = localtime();
  local $SIG{ALRM} = sub { die "$act_time: died in SIG ALRM"; };
  alarm($timeout);

  # CMDs
  if ( $user_name && $user_pw ) {
    $cmd_performanceStats             = `$SMcli -n $storage_name -e -R $user_name -p $user_pw -c "set session performanceMonitorInterval=$sample_rate performanceMonitorIterations=1 ; show allLogicalDrives performanceStats;" 2>/dev/null`;
    $cmd_logicalDrives                = `$SMcli -n $storage_name -e -R $user_name -p $user_pw -c "show logicalDrives;" 2>/dev/null`;
    $cmd_performanceStats_to_errorlog = "$SMcli -n $storage_name -e -R $user_name -p <XXXXX> -c \"set session performanceMonitorInterval=$sample_rate performanceMonitorIterations=1 ; show allLogicalDrives performanceStats;\" 2>/dev/null";
    $cmd_logicalDrives_to_errorlog    = "$SMcli -n $storage_name -e -R $user_name -p <XXXXX> -c \"show logicalDrives;\" 2>/dev/null";
  }
  else {
    $cmd_performanceStats             = `$SMcli -n $storage_name -e -c "set session performanceMonitorInterval=$sample_rate performanceMonitorIterations=1 ; show allLogicalDrives performanceStats;" 2>/dev/null`;
    $cmd_logicalDrives                = `$SMcli -n $storage_name -e -c "show logicalDrives;" 2>/dev/null`;
    $cmd_performanceStats_to_errorlog = "$SMcli -n $storage_name -e -c \"set session performanceMonitorInterval=$sample_rate performanceMonitorIterations=1 ; show allLogicalDrives performanceStats;\" 2>/dev/null";
    $cmd_logicalDrives_to_errorlog    = "$SMcli -n $storage_name -e -c \"show logicalDrives;\" 2>/dev/null";
  }

  @storage_items = split( "\n", $cmd_performanceStats );
  @logicalDrives = split( "\n", $cmd_logicalDrives );

  # end of alarm
  alarm(0);
};

if ($@) {
  if ( $@ =~ /died in SIG ALRM/ ) {
    my $act_time = localtime();
    error("command timed out after : $timeout seconds");
    exit(0);
  }
}

if ( "@storage_items" !~ /SMcli completed successfully/ ) {
  $cmd_performanceStats =~ s/\n//g;
  $cmd_performanceStats = substr $cmd_performanceStats, -512;
  if ( "@storage_items" =~ /error code 12/ ) {
    error("SMcli command failed: $cmd_performanceStats_to_errorlog");
    error( "$cmd_performanceStats : $!" . __FILE__ . ":" . __LINE__ );
    error("Most probably permission issue, STOR2RRD cannot run SMcli command. Problem description and fix: http://www.stor2rrd.com/install.htm#SMclierror");
    exit;
  }
  else {
    error("SMcli command failed: $cmd_performanceStats_to_errorlog");
    error( "$cmd_performanceStats : $!" . __FILE__ . ":" . __LINE__ );
    exit;
  }
}
if ( "@logicalDrives" !~ /SMcli completed successfully/ ) {
  $cmd_logicalDrives =~ s/\n//g;
  $cmd_logicalDrives = substr $cmd_logicalDrives, -512;
  if ( "@logicalDrives" =~ /error code 12/ ) {
    error("SMcli command failed: $cmd_logicalDrives_to_errorlog");
    error( "$cmd_logicalDrives : $!" . __FILE__ . ":" . __LINE__ );
    error("Most probably permission issue, STOR2RRD cannot run SMcli command. Problem description and fix: http://www.stor2rrd.com/install.htm#SMclierror");
    exit;
  }
  else {
    error("SMcli command failed: $cmd_logicalDrives_to_errorlog");
    error( "$cmd_logicalDrives : $!" . __FILE__ . ":" . __LINE__ );
    exit;
  }
}
if ( "@storage_items" =~ /\"Objects\"/ ) {
  $storage_type = "new";
  $version      = "v2";
}
if ( "@storage_items" =~ /\"Storage Subsystems/ ) {
  $storage_type = "old";
  $version      = "v1";
}

### Search ID, POOL name, Controller, Capacity
my @logicalDrives_lines = grep {/Logical Drive name:|Logical Drive ID:|Associated disk pool:|Associated array:|Current owner:|Capacity:/} @logicalDrives;
my @volume_id;
my @pools;
my $volume_name = "";
my $volume_id   = "";
my $volume_pool = "";
my $controller  = "";
my $capacity    = "";
foreach my $line (@logicalDrives_lines) {
  chomp $line;
  if ( $line =~ "Logical Drive name:" ) {
    $line =~ s/Logical Drive name://g;
    $line =~ s/^\s+//g;
    $line =~ s/\s+$//g;
    $volume_name = $line;
  }
  if ( $line =~ "Logical Drive ID:" ) {
    $line =~ s/Logical Drive ID://g;
    $line =~ s/^\s+//g;
    $line =~ s/\s+$//g;
    $line =~ s/://g;
    $volume_id = $line;
  }
  if ( $line =~ "Capacity:" ) {
    $line =~ s/Capacity://g;
    $line =~ s/^\s+//g;
    $line =~ s/\s+$//g;
    $line =~ s/,//g;
    $capacity = $line;
  }
  if ( $line =~ "Associated disk pool:" || $line =~ "Associated array:" ) {
    my $type = "";
    if ( $line =~ "Associated disk pool:" ) { $type = "diskPool"; }
    if ( $line =~ "Associated array:" )     { $type = "array"; }
    $line =~ s/Associated disk pool://g;
    $line =~ s/Associated array://g;
    $line =~ s/^\s+//g;
    $line =~ s/\s+$//g;
    $volume_pool = $line;
    push( @pools, "$volume_pool,$type\n" );
  }
  if ( $line =~ "Current owner:" ) {
    $line =~ s/Current owner://g;
    $line =~ s/^\s+//g;
    $line =~ s/\s+$//g;
    $controller = $line;
    push( @volume_id, "$volume_name,$volume_id,$volume_pool,$controller,$capacity\n" );
  }
}

### search start date/time and interval
my ($time_line) = grep {/Performance Monitor Statistics/} @storage_items;
$time_line =~ s/\"//g;
my ( undef, $time, $interval ) = split( " - ", $time_line );
if ( ! defined $time || ! defined $interval ) { # maybe diff output, try another way
  ($time) = grep {/Date\/Time:/} @storage_items;
  ($interval) = grep {/Polling interval in seconds:/} @storage_items;
}

$time =~ s/Date\/Time://g;
$time =~ s/^\s+//g;
$time =~ s/\s+$//g;
$interval =~ s/Polling interval in seconds://g;
$interval =~ s/^\s+//g;
$interval =~ s/\s+$//g;
my ( $date,  $time_s, $part_of_the_day ) = split( " ", $time );
my ( $month, $day,    $year )            = split( "/", $date );
my ( $hour,  $min,    $sec )             = split( ":", $time_s );
my $year_s = $year + 2000;
my $hour_s = $hour;

if ( $part_of_the_day =~ /PM/ && $hour !~ /12/ ) {
  $hour_s = $hour + 12;
}
if ( $part_of_the_day =~ /AM/ && $hour =~ /12/ ) {
  $hour_s = $hour - 12;
}
my $s_timestamp = timelocal( $sec, $min, $hour_s, $day, $month - 1, $year_s );
my $s_date = sprintf( "%4d:%02d:%02d",  $year_s, $month, $day );
my $s_time = sprintf( "%02d:%02d:%02d", $hour_s, $min,   $sec );
my $e_timestamp = $s_timestamp + $interval;
my ( $sec_e, $min_e, $hour_e, $day_e, $month_e, $year_e, $wday_e, $yday_e, $isdst_e ) = localtime($e_timestamp);
my $e_date = sprintf( "%4d:%02d:%02d",  $year_e + 1900, $month_e + 1, $day_e );
my $e_time = sprintf( "%02d:%02d:%02d", $hour_e,        $min_e,       $sec_e );
my $start_time          = "$s_date" . "T" . "$s_time";
my $end_time            = $e_date . "T" . $e_time;
my $time_to_output_name = sprintf( "%4d%02d%02d_%02d%02d", $year_s, $month, $day, $hour_s, $min );

### output file
$out_perf_file = $output_dir . $storage_name . "_ds5perf_" . $time_to_output_name . ".out.tmp";
open( PERFOUT, ">$out_perf_file" ) || die "Couldn't open file $out_perf_file";

### header
print PERFOUT "\nVolume Level Statistics\n";
print PERFOUT "  Interval Start:   $start_time\n";
print PERFOUT "  Interval End:     $end_time\n";
print PERFOUT "  Interval Length:  $interval seconds\n";
print PERFOUT "---------------------\n";
print PERFOUT "Volume ID,Time,Interval (s),Volume Name,Pool Name,Controler,Total IOs,Total IO Rate (IO/s),Total Data Rate (KB/s),Read Hits,Write Hits,Cache read %,SSD Read Cache Hit %,IO Latency,Cache hits,Capacity (MB)\n";

my $header_line = "";
my @header;
($header_line) = grep {/^"Storage Subsystems|^"Objects/} @storage_items;
$header_line =~ s/\s"//g;
$header_line =~ s/"//g;
@header = split(",",$header_line);
chomp @header;

#Objects,Total IOs,Read %,Primary Read Cache Hit %,Primary Write Cache Hit %,SSD Read Cache Hit %,Current MBs/sec,Maximum MBs/sec,Current IOs/sec,Maximum IOs/sec,Minimum IOs/sec,Average IOs/sec,Minimum MBs/sec,Average MBs/sec,Current IO Latency,Maximum IO Latency,Minimum IO Latency,Average IO Latency

#Storage Subsystems,Total IOs,Read Percentage,Cache Hit Percentage,Current KB/second,Maximum KB/second,Current IO/second,Maximum IO/second

my $search_for_total_IOs                   = "Total IOs";
my $search_for_Read_Percentage             = "Read Percentage";
my $search_for_Cache_Hit_Percentage        = "Cache Hit Percentage";
my $search_for_Current_KBsec               = "Current KB/second";
my $search_for_Current_MBsec               = "Current MB/second";
my $search_for_Maximum_KBsec               = "Maximum KB/second";
my $search_for_Maximum_MBsec               = "Maximum MB/second";
my $search_for_Current_IOsec               = "Current IO/second";
my $search_for_Maximum_IOsec               = "Maximum IO/second";
my $search_for_Read_pct                    = "Read %";
my $search_for_Primary_Read_Cache_Hit_pct  = "Primary Read Cache Hit %";
my $search_for_Primary_Write_Cache_Hit_pct = "Primary Write Cache Hit %";
my $search_for_SSD_Read_Cache_Hit_pct      = "SSD Read Cache Hit %";
my $search_for_Current_MBs_sec             = "Current MBs/sec";
my $search_for_Maximum_MBs_sec             = "Maximum MBs/sec";
my $search_for_Current_IOs_sec             = "Current IOs/sec";
my $search_for_Maximum_IOs_sec             = "Maximum IOs/sec";
my $search_for_Minimum_IOs_sec             = "Minimum IOs/sec";
my $search_for_Average_IOs_sec             = "Average IOs/sec";
my $search_for_Minimum_MBs_sec             = "Minimum MBs/sec";
my $search_for_Average_MBs_sec             = "Average MBs/sec";
my $search_for_Current_IO_Latency          = "Current IO Latency";
my $search_for_Maximum_IO_Latency          = "Maximum IO Latency";
my $search_for_Minimum_IO_Latency          = "Minimum IO Latency";
my $search_for_Average_IO_Latency          = "Average IO Latency";

my $total_IOs_index;
my $Read_Percentage_index;
my $Cache_Hit_Percentage_index;
my $Current_KBsec_index;
my $Current_MBsec_index;
my $Maximum_KBsec_index;
my $Maximum_MBsec_index;
my $Current_IOsec_index;
my $Maximum_IOsec_index;
my $Read_pct_index;
my $Primary_Read_Cache_Hit_pct_index;
my $Primary_Write_Cache_Hit_pct_index;
my $SSD_Read_Cache_Hit_pct_index;
my $Current_MBs_sec_index;
my $Maximum_MBs_sec_index;
my $Current_IOs_sec_index;
my $Maximum_IOs_sec_index;
my $Minimum_IOs_sec_index;
my $Average_IOs_sec_index;
my $Minimum_MBs_sec_index;
my $Average_MBs_sec_index;
my $Current_IO_Latency_index;
my $Maximum_IO_Latency_index;
my $Minimum_IO_Latency_index;
my $Average_IO_Latency_index;

($total_IOs_index)                   = grep { $header[$_] eq $search_for_total_IOs } 0..$#header;
($Read_Percentage_index)             = grep { $header[$_] eq $search_for_Read_Percentage } 0..$#header;
($Cache_Hit_Percentage_index)        = grep { $header[$_] eq $search_for_Cache_Hit_Percentage } 0..$#header;
($Current_KBsec_index)               = grep { $header[$_] eq $search_for_Current_KBsec } 0..$#header;
($Current_MBsec_index)               = grep { $header[$_] eq $search_for_Current_MBsec } 0..$#header;
($Maximum_KBsec_index)               = grep { $header[$_] eq $search_for_Maximum_KBsec } 0..$#header;
($Maximum_MBsec_index)               = grep { $header[$_] eq $search_for_Maximum_MBsec } 0..$#header;
($Current_IOsec_index)               = grep { $header[$_] eq $search_for_Current_IOsec } 0..$#header;
($Maximum_IOsec_index)               = grep { $header[$_] eq $search_for_Maximum_IOsec } 0..$#header;
($Read_pct_index)                    = grep { $header[$_] eq $search_for_Read_pct } 0..$#header;
($Primary_Read_Cache_Hit_pct_index)  = grep { $header[$_] eq $search_for_Primary_Read_Cache_Hit_pct } 0..$#header;
($Primary_Write_Cache_Hit_pct_index) = grep { $header[$_] eq $search_for_Primary_Write_Cache_Hit_pct } 0..$#header;
($SSD_Read_Cache_Hit_pct_index)      = grep { $header[$_] eq $search_for_SSD_Read_Cache_Hit_pct } 0..$#header;
($Current_MBs_sec_index)             = grep { $header[$_] eq $search_for_Current_MBs_sec } 0..$#header;
($Maximum_MBs_sec_index)             = grep { $header[$_] eq $search_for_Maximum_MBs_sec } 0..$#header;
($Current_IOs_sec_index)             = grep { $header[$_] eq $search_for_Current_IOs_sec } 0..$#header;
($Maximum_IOs_sec_index)             = grep { $header[$_] eq $search_for_Maximum_IOs_sec } 0..$#header;
($Minimum_IOs_sec_index)             = grep { $header[$_] eq $search_for_Minimum_IOs_sec } 0..$#header;
($Average_IOs_sec_index)             = grep { $header[$_] eq $search_for_Average_IOs_sec } 0..$#header;
($Minimum_MBs_sec_index)             = grep { $header[$_] eq $search_for_Minimum_MBs_sec } 0..$#header;
($Average_MBs_sec_index)             = grep { $header[$_] eq $search_for_Average_MBs_sec } 0..$#header;
($Current_IO_Latency_index)          = grep { $header[$_] eq $search_for_Current_IO_Latency } 0..$#header;
($Maximum_IO_Latency_index)          = grep { $header[$_] eq $search_for_Maximum_IO_Latency } 0..$#header;
($Minimum_IO_Latency_index)          = grep { $header[$_] eq $search_for_Minimum_IO_Latency } 0..$#header;
($Average_IO_Latency_index)          = grep { $header[$_] eq $search_for_Average_IO_Latency } 0..$#header;

if ( not defined $total_IOs_index )                   { $total_IOs_index = "not_found"; }
if ( not defined $Read_Percentage_index )             { $Read_Percentage_index = "not_found"; }
if ( not defined $Cache_Hit_Percentage_index )        { $Cache_Hit_Percentage_index = "not_found"; }
if ( not defined $Current_KBsec_index )               { $Current_KBsec_index = "not_found"; }
if ( not defined $Current_MBsec_index )               { $Current_MBsec_index = "not_found"; }
if ( not defined $Maximum_KBsec_index )               { $Maximum_KBsec_index = "not_found"; }
if ( not defined $Maximum_MBsec_index )               { $Maximum_MBsec_index = "not_found"; }
if ( not defined $Current_IOsec_index )               { $Current_IOsec_index = "not_found"; }
if ( not defined $Maximum_IOsec_index )               { $Maximum_IOsec_index = "not_found"; }
if ( not defined $Read_pct_index )                    { $Read_pct_index = "not_found"; }
if ( not defined $Primary_Read_Cache_Hit_pct_index )  { $Primary_Read_Cache_Hit_pct_index = "not_found"; }
if ( not defined $Primary_Write_Cache_Hit_pct_index ) { $Primary_Write_Cache_Hit_pct_index = "not_found"; }
if ( not defined $SSD_Read_Cache_Hit_pct_index )      { $SSD_Read_Cache_Hit_pct_index = "not_found"; }
if ( not defined $Current_MBs_sec_index )             { $Current_MBs_sec_index = "not_found"; }
if ( not defined $Maximum_MBs_sec_index )             { $Maximum_MBs_sec_index = "not_found"; }
if ( not defined $Current_IOs_sec_index )             { $Current_IOs_sec_index = "not_found"; }
if ( not defined $Maximum_IOs_sec_index )             { $Maximum_IOs_sec_index = "not_found"; }
if ( not defined $Minimum_IOs_sec_index )             { $Minimum_IOs_sec_index = "not_found"; }
if ( not defined $Average_IOs_sec_index )             { $Average_IOs_sec_index = "not_found"; }
if ( not defined $Minimum_MBs_sec_index )             { $Minimum_MBs_sec_index = "not_found"; }
if ( not defined $Average_MBs_sec_index )             { $Average_MBs_sec_index = "not_found"; }
if ( not defined $Current_IO_Latency_index )          { $Current_IO_Latency_index = "not_found"; }
if ( not defined $Maximum_IO_Latency_index )          { $Maximum_IO_Latency_index = "not_found"; }
if ( not defined $Minimum_IO_Latency_index )          { $Minimum_IO_Latency_index = "not_found"; }
if ( not defined $Average_IO_Latency_index )          { $Average_IO_Latency_index = "not_found"; }

chomp $total_IOs_index;                  chomp $Read_Percentage_index;             chomp $Cache_Hit_Percentage_index;    chomp $Current_KBsec_index;
chomp $Maximum_KBsec_index;              chomp $Current_IOsec_index;               chomp $Maximum_IOsec_index;           chomp $Read_pct_index;
chomp $Primary_Read_Cache_Hit_pct_index; chomp $Primary_Write_Cache_Hit_pct_index; chomp $SSD_Read_Cache_Hit_pct_index;  chomp $Current_MBs_sec_index;
chomp $Maximum_MBs_sec_index;            chomp $Current_IOs_sec_index;             chomp $Maximum_IOs_sec_index;         chomp $Minimum_IOs_sec_index;
chomp $Average_IOs_sec_index;            chomp $Minimum_MBs_sec_index;             chomp $Average_MBs_sec_index;         chomp $Current_IO_Latency_index;
chomp $Maximum_IO_Latency_index;         chomp $Minimum_IO_Latency_index;          chomp $Average_IO_Latency_index;      chomp $Current_MBsec_index;
chomp $Maximum_MBsec_index;

foreach my $line (@storage_items) {
  chomp $line;
  $line =~ s/\"//g;
  if ( $line =~ /^Logical Drive/ ) {
    $line =~ s/^Logical Drive //g;
    my ($volume_name, undef) = split(",",$line);
    my @items = split(",",$line);

    my $total_IOs                   = "";
    my $Read_Percentage             = "";
    my $Cache_Hit_Percentage        = "";
    my $Current_KBsec               = "";
    my $Current_MBsec               = "";
    my $Maximum_KBsec               = "";
    my $Maximum_MBsec               = "";
    my $Current_IOsec               = "";
    my $Maximum_IOsec               = "";
    my $Read_pct                    = "";
    my $Primary_Read_Cache_Hit_pct  = "";
    my $Primary_Write_Cache_Hit_pct = "";
    my $SSD_Read_Cache_Hit_pct      = "";
    my $Current_MBs_sec             = "";
    my $Maximum_MBs_sec             = "";
    my $Current_IOs_sec             = "";
    my $Maximum_IOs_sec             = "";
    my $Minimum_IOs_sec             = "";
    my $Average_IOs_sec             = "";
    my $Minimum_MBs_sec             = "";
    my $Average_MBs_sec             = "";
    my $Current_IO_Latency          = "";
    my $Maximum_IO_Latency          = "";
    my $Minimum_IO_Latency          = "";
    my $Average_IO_Latency          = "";

    if ( $total_IOs_index !~ m/^not_found$/ )                   { $total_IOs = $items[$total_IOs_index] }
    if ( $Read_Percentage_index !~ m/^not_found$/ )             { $Read_Percentage = $items[$Read_Percentage_index] }
    if ( $Cache_Hit_Percentage_index !~ m/^not_found$/ )        { $Cache_Hit_Percentage = $items[$Cache_Hit_Percentage_index] }
    if ( $Current_KBsec_index !~ m/^not_found$/ )               { $Current_KBsec = $items[$Current_KBsec_index] }
    if ( $Current_MBsec_index !~ m/^not_found$/ )               { $Current_MBsec = $items[$Current_MBsec_index] }
    if ( $Maximum_KBsec_index !~ m/^not_found$/ )               { $Maximum_KBsec = $items[$Maximum_KBsec_index] }
    if ( $Maximum_MBsec_index !~ m/^not_found$/ )               { $Maximum_MBsec = $items[$Maximum_MBsec_index] }
    if ( $Current_IOsec_index !~ m/^not_found$/ )               { $Current_IOsec = $items[$Current_IOsec_index] }
    if ( $Maximum_IOsec_index !~ m/^not_found$/ )               { $Maximum_IOsec = $items[$Maximum_IOsec_index] }
    if ( $Read_pct_index !~ m/^not_found$/ )                    { $Read_pct = $items[$Read_pct_index] }
    if ( $Primary_Read_Cache_Hit_pct_index !~ m/^not_found$/ )  { $Primary_Read_Cache_Hit_pct = $items[$Primary_Read_Cache_Hit_pct_index] }
    if ( $Primary_Write_Cache_Hit_pct_index !~ m/^not_found$/ ) { $Primary_Write_Cache_Hit_pct = $items[$Primary_Write_Cache_Hit_pct_index] }
    if ( $SSD_Read_Cache_Hit_pct_index !~ m/^not_found$/ )      { $SSD_Read_Cache_Hit_pct = $items[$SSD_Read_Cache_Hit_pct_index] }
    if ( $Current_MBs_sec_index !~ m/^not_found$/ )             { $Current_MBs_sec = $items[$Current_MBs_sec_index] }
    if ( $Maximum_MBs_sec_index !~ m/^not_found$/ )             { $Maximum_MBs_sec = $items[$Maximum_MBs_sec_index] }
    if ( $Current_IOs_sec_index !~ m/^not_found$/ )             { $Current_IOs_sec = $items[$Current_IOs_sec_index] }
    if ( $Maximum_IOs_sec_index !~ m/^not_found$/ )             { $Maximum_IOs_sec = $items[$Maximum_IOs_sec_index] }
    if ( $Minimum_IOs_sec_index !~ m/^not_found$/ )             { $Minimum_IOs_sec = $items[$Minimum_IOs_sec_index] }
    if ( $Average_IOs_sec_index !~ m/^not_found$/ )             { $Average_IOs_sec = $items[$Average_IOs_sec_index] }
    if ( $Minimum_MBs_sec_index !~ m/^not_found$/ )             { $Minimum_MBs_sec = $items[$Minimum_MBs_sec_index] }
    if ( $Average_MBs_sec_index !~ m/^not_found$/ )             { $Average_MBs_sec = $items[$Average_MBs_sec_index] }
    if ( $Current_IO_Latency_index !~ m/^not_found$/ )          { $Current_IO_Latency = $items[$Current_IO_Latency_index] }
    if ( $Maximum_IO_Latency_index !~ m/^not_found$/ )          { $Maximum_IO_Latency = $items[$Maximum_IO_Latency_index] }
    if ( $Minimum_IO_Latency_index !~ m/^not_found$/ )          { $Minimum_IO_Latency = $items[$Minimum_IO_Latency_index] }
    if ( $Average_IO_Latency_index !~ m/^not_found$/ )          { $Average_IO_Latency = $items[$Average_IO_Latency_index] }

    ###
    my ($id_line) = grep {/^$volume_name,/} @volume_id;
    chomp $id_line;
    my ( undef, $id, $pool, $vol_controller, $cap ) = split( ",", $id_line );
    my $capacity;
    my ( $cap_num, $cap_size ) = split( " ", $cap );
    if ( $cap_size =~ /MB/ ) { $capacity = $cap_num; }
    if ( $cap_size =~ /GB/ ) { $capacity = $cap_num * 1024; }
    if ( $cap_size =~ /TB/ ) { $capacity = $cap_num * 1024 * 1024; }
    if ( $cap_size =~ /PB/ ) { $capacity = $cap_num * 1024 * 1024 * 1024; }
    $vol_controller =~ s/Controller in slot//g;
    $vol_controller =~ s/^\s+//g;
    $vol_controller =~ s/\s+$//g;

    # Total Data Rate (KB/s)
    my $total_data_rate_KBs = "";
    if ( $Average_MBs_sec_index !~ m/^not_found$/ ) { $total_data_rate_KBs = $Average_MBs_sec * 1024; }
    if ( $Current_KBsec_index !~ m/^not_found$/ )   { $total_data_rate_KBs = $Current_KBsec; }
    if ( $Current_MBsec_index !~ m/^not_found$/ )   { $total_data_rate_KBs = $Current_MBsec * 1024; }

    # Total IO Rate (IO/s)
    my $total_IO_rate_IOs = "";
    if ( $Average_IOs_sec_index !~ m/^not_found$/ ) { $total_IO_rate_IOs = $Average_IOs_sec; }
    else { $total_IO_rate_IOs = $Current_IOsec; }

    # Cache read %
    my $cache_read_pct = "";
    if ( $Read_pct_index !~ m/^not_found$/ ) { $cache_read_pct = $Read_pct; }
    else { $cache_read_pct = $Cache_Hit_Percentage; }

    print PERFOUT "$id,$start_time,$interval,$volume_name,$pool,$vol_controller,$total_IOs,$total_IO_rate_IOs,$total_data_rate_KBs,$Primary_Read_Cache_Hit_pct,$Primary_Write_Cache_Hit_pct,$cache_read_pct,$SSD_Read_Cache_Hit_pct,$Average_IO_Latency,$Read_Percentage,$capacity\n";
  }
}

# Pool conf part
print PERFOUT "\nPool Capacity Statistics\n";
print PERFOUT "  Interval Start:   $start_time\n";
print PERFOUT "  Interval End:     $end_time\n";
print PERFOUT "  Interval Length:  $interval seconds\n";
print PERFOUT "---------------------\n";
print PERFOUT "name,id,status,mdisk count,volume count,capacity (TB),extent size,free capacity (TB),virtual capacity (TB),used capacity (TB),real capacity (TB),overallocation,warning (%),easy tier,easy tier status,TIER-0 type,TIER-0 mdisk count,TIER-0 capacity (TB),TIER-0 free capacity (TB),TIER-1 type,TIER-1 mdisk count,TIER-1 capacity (TB),TIER-1 free capacity (TB),TIER-2 type,TIER-2 mdisk count,TIER-2 capacity (TB),TIER-2 free capacity (TB),compression active,compression virtual capacity (TB),compression compressed capacity (TB),compression uncompressed capacity (TB)\n";


my $last_pool = "";
@pools = sort @pools;
foreach (@pools) {
  chomp $_;
  my $pool_line = $_;
  if ( $pool_line eq $last_pool ) {next}
  $last_pool = $pool_line;

  my ($pool, $pool_type) = split(",",$pool_line);

  # SMcli command
  my $cmd_show_array;
  my $cmd_show_array_to_errorlog;
  my @show_array;
  my $capacity      = "";
  my $used_capacity = "";
  my $free_capacity = "";

  #if ( $storage_type =~ /new/ ) {
  if ( $pool_type =~ /diskPool/ ) {
    eval {
      # Set alarm
      my $act_time = localtime();
      local $SIG{ALRM} = sub { die "$act_time: died in SIG ALRM"; };
      alarm($timeout);

      # CMDs
      if ( $user_name && $user_pw ) {
        $cmd_show_array             = `$SMcli -n $storage_name -e -R $user_name -p $user_pw -c "show diskPool [\\\"$pool\\\"] ;" 2>/dev/null`;
        $cmd_show_array_to_errorlog = "$SMcli -n $storage_name -e -R $user_name -p <XXXXX> -c \"show diskPool [\\\"$pool\\\"] ;\" 2>/dev/null";
      }
      else {
        $cmd_show_array             = `$SMcli -n $storage_name -e -c "show diskPool [\\\"$pool\\\"] ;" 2>/dev/null`;
        $cmd_show_array_to_errorlog = "$SMcli -n $storage_name -e -c \"show diskPool [\\\"$pool\\\"] ;\" 2>/dev/null";
      }
      @show_array = split( "\n", $cmd_show_array );

      # end of alarm
      alarm(0);
    };
    if ($@) {
      if ( $@ =~ /died in SIG ALRM/ ) {
        my $act_time = localtime();
        error("command timed out after : $timeout seconds");
        exit(0);
      }
    }
    if ( "@show_array" !~ /SMcli completed successfully/ ) {
      $cmd_show_array =~ s/\n//g;
      $cmd_show_array = substr $cmd_show_array, -512;
      if ( "@show_array" =~ /error code 12/ ) {
        error("SMcli command failed: $cmd_show_array_to_errorlog");
        error( "$cmd_show_array : $!" . __FILE__ . ":" . __LINE__ );
        error("Most probably permission issue, STOR2RRD cannot run SMcli command. Problem description and fix: http://www.stor2rrd.com/install.htm#SMclierror");
        exit;
      }
      else {
        error("SMcli command failed: $cmd_show_array_to_errorlog");
        error( "$cmd_show_array : $!" . __FILE__ . ":" . __LINE__ );
        exit;
      }
    }
    foreach my $line_k (@show_array) {
      chomp $line_k;
      if ( $line_k =~ "Usable capacity:" ) {
        $line_k =~ s/Usable capacity://g;
        $line_k =~ s/,//g;
        $line_k =~ s/^\s+//g;
        $line_k =~ s/\s+$//g;
        my ( $cap_num, $cap_size ) = split( " ", $line_k );
        if ( $cap_size =~ /^B/ ) { $capacity = $cap_num / 1024 / 1024 / 1024 / 1024; }
        if ( $cap_size =~ /kB/ ) { $capacity = $cap_num / 1024 / 1024 / 1024; }
        if ( $cap_size =~ /MB/ ) { $capacity = $cap_num / 1024 / 1024; }
        if ( $cap_size =~ /GB/ ) { $capacity = $cap_num / 1024; }
        if ( $cap_size =~ /TB/ ) { $capacity = $cap_num; }
        if ( $cap_size =~ /PB/ ) { $capacity = $cap_num * 1024; }
      }
      if ( $line_k =~ "Used capacity:" ) {
        $line_k =~ s/Used capacity://g;
        $line_k =~ s/,//g;
        $line_k =~ s/^\s+//g;
        $line_k =~ s/\s+$//g;
        my ( $cap_num, $cap_size ) = split( " ", $line_k );
        if ( $cap_size =~ /^B/ ) { $used_capacity = $cap_num / 1024 / 1024 / 1024 / 1024; }
        if ( $cap_size =~ /kB/ ) { $used_capacity = $cap_num / 1024 / 1024 / 1024; }
        if ( $cap_size =~ /MB/ ) { $used_capacity = $cap_num / 1024 / 1024; }
        if ( $cap_size =~ /GB/ ) { $used_capacity = $cap_num / 1024; }
        if ( $cap_size =~ /TB/ ) { $used_capacity = $cap_num; }
        if ( $cap_size =~ /PB/ ) { $used_capacity = $cap_num * 1024; }
      }
      if ( $line_k =~ "Free Capacity:" ) {
        $line_k =~ s/Free Capacity://g;
        $line_k =~ s/,//g;
        $line_k =~ s/^\s+//g;
        $line_k =~ s/\s+$//g;
        my ( undef, $cap_num, $cap_size ) = split( " ", $line_k );
        if ( $cap_size =~ /^B/ ) { $free_capacity = $cap_num / 1024 / 1024 / 1024 / 1024; }
        if ( $cap_size =~ /kB/ ) { $free_capacity = $cap_num / 1024 / 1024 / 1024; }
        if ( $cap_size =~ /MB/ ) { $free_capacity = $cap_num / 1024 / 1024; }
        if ( $cap_size =~ /GB/ ) { $free_capacity = $cap_num / 1024; }
        if ( $cap_size =~ /TB/ ) { $free_capacity = $cap_num; }
        if ( $cap_size =~ /PB/ ) { $free_capacity = $cap_num * 1024; }
      }
    }
    print PERFOUT "$pool,,,,,$capacity,,$free_capacity,,$used_capacity,,,,,,,,,,,,,,,,,,,,,\n";
  }
  #if ( $storage_type =~ /old/ ) {
  if ( $pool_type =~ /array/ ) {
    eval {
      # Set alarm
      my $act_time = localtime();
      local $SIG{ALRM} = sub { die "$act_time: died in SIG ALRM"; };
      alarm($timeout);

      # CMDs
      if ( $user_name && $user_pw ) {
        $cmd_show_array             = `$SMcli -n $storage_name -e -R $user_name -p $user_pw -c "show array [\\\"$pool\\\"] ;" 2>/dev/null`;
        $cmd_show_array_to_errorlog = "$SMcli -n $storage_name -e -R $user_name -p <XXXXX> -c \"show array [\\\"$pool\\\"] ;\" 2>/dev/null";
      }
      else {
        $cmd_show_array             = `$SMcli -n $storage_name -e -c "show array [\\\"$pool\\\"] ;" 2>/dev/null`;
        $cmd_show_array_to_errorlog = "$SMcli -n $storage_name -e -c \"show array [\\\"$pool\\\"] ;\" 2>/dev/null";
      }
      @show_array = split( "\n", $cmd_show_array );

      # end of alarm
      alarm(0);
    };
    if ($@) {
      if ( $@ =~ /died in SIG ALRM/ ) {
        my $act_time = localtime();
        error("command timed out after : $timeout seconds");
        exit(0);
      }
    }
    if ( "@show_array" !~ /SMcli completed successfully/ ) {
      $cmd_show_array =~ s/\n//g;
      $cmd_show_array = substr $cmd_show_array, -512;
      if ( "@show_array" =~ /error code 12/ ) {
        error("SMcli command failed: $cmd_show_array_to_errorlog");
        error( "$cmd_show_array : $!" . __FILE__ . ":" . __LINE__ );
        error("Most probably permission issue, STOR2RRD cannot run SMcli command. Problem description and fix: http://www.stor2rrd.com/install.htm#SMclierror");
        exit;
      }
      else {
        error("SMcli command failed: $cmd_show_array_to_errorlog");
        error( "$cmd_show_array : $!" . __FILE__ . ":" . __LINE__ );
        exit;
      }
    }
    foreach my $line_k (@show_array) {
      chomp $line_k;
      $line_k =~ s/^\s+//g;
      if ( $line_k =~ "^Capacity:" ) {
        $line_k =~ s/Capacity://g;
        $line_k =~ s/,//g;
        $line_k =~ s/^\s+//g;
        $line_k =~ s/\s+$//g;
        my ( $cap_num, $cap_size ) = split( " ", $line_k );
        if ( $cap_size =~ /^B/ ) { $capacity = $cap_num / 1024 / 1024 / 1024 / 1024; }
        if ( $cap_size =~ /kB/ ) { $capacity = $cap_num / 1024 / 1024 / 1024; }
        if ( $cap_size =~ /MB/ ) { $capacity = $cap_num / 1024 / 1024; }
        if ( $cap_size =~ /GB/ ) { $capacity = $cap_num / 1024; }
        if ( $cap_size =~ /TB/ ) { $capacity = $cap_num; }
        if ( $cap_size =~ /PB/ ) { $capacity = $cap_num * 1024; }
      }
      if ( $line_k =~ "^Free Capacity:" ) {
        $line_k =~ s/Free Capacity://g;
        $line_k =~ s/,//g;
        $line_k =~ s/^\s+//g;
        $line_k =~ s/\s+$//g;
        my ( $cap_num, $cap_size ) = split( " ", $line_k );
        if ( $cap_size =~ /^B/ ) { $free_capacity = $cap_num / 1024 / 1024 / 1024 / 1024; }
        if ( $cap_size =~ /kB/ ) { $free_capacity = $cap_num / 1024 / 1024 / 1024; }
        if ( $cap_size =~ /MB/ ) { $free_capacity = $cap_num / 1024 / 1024; }
        if ( $cap_size =~ /GB/ ) { $free_capacity = $cap_num / 1024; }
        if ( $cap_size =~ /TB/ ) { $free_capacity = $cap_num; }
        if ( $cap_size =~ /PB/ ) { $free_capacity = $cap_num * 1024; }
      }
    }
    print PERFOUT "$pool,,,,,$capacity,,$free_capacity,,$used_capacity,,,,,,,,,,,,,,,,,,,,,\n";
  }
}
close(PERFOUT);

### CONFIGURATION

# conditions for creating a configuration file
my $config_html            = $output_dir . "config.html";
my $time_for_configuration = "";
my $act_time               = time();
my $time_diff              = 0;
$tmp_file = $tmp_dir . $storage_name . "conf_time";
if ( !-e $tmp_file ) {
  open( CONFTIME, ">$tmp_file" ) || die "Couldn't open file $tmp_file";
  print CONFTIME "$act_time";
  close(CONFTIME);
  $time_for_configuration = "OK";
}
else {
  open( CONFTIME, "<$tmp_file" ) || die "Couldn't open file $tmp_file";
  my @conf_array = <CONFTIME>;
  close(CONFTIME);
  $time_diff = $act_time - $conf_array[0];
}

if ( $time_diff > 3600 ) { $time_for_configuration = "OK"; }
if ( !-e $config_html )  { $time_for_configuration = "OK"; }

# creating configuration file
if ( $time_for_configuration =~ /OK/ ) {
  open( CONFTIME, ">$tmp_file" ) || die "Couldn't open file $tmp_file";
  print CONFTIME "$act_time";
  close(CONFTIME);

  my $out_conf_file;
  $out_conf_file = $output_dir . $storage_name . "_ds5conf_" . $time_to_output_name . ".out.tmp";
  open( CONFOUT, ">$out_conf_file" ) || die "Couldn't open file $out_conf_file";

  # Configuration data main header
  print CONFOUT "Configuration Data\n";
  print CONFOUT "------------------\n";
  print CONFOUT "DS5K type : $version\n";

  # SMcli command
  my $cmd_summary;
  my $cmd_summary_to_errorlog;
  my @show_summary;

  if ( $storage_type =~ /new/ ) {
    eval {
      # Set alarm
      my $act_time = localtime();
      local $SIG{ALRM} = sub { die "$act_time: died in SIG ALRM"; };
      alarm($timeout);

      # CMDs
      if ( $user_name && $user_pw ) {
        $cmd_summary             = `$SMcli -n $storage_name -e -R $user_name -p $user_pw -c "show storagesubsystem summary;" 2>/dev/null`;
        $cmd_summary_to_errorlog = "$SMcli -n $storage_name -e -R $user_name -p <XXXXX> -c \"show storagesubsystem summary;\" 2>/dev/null";
      }
      else {
        $cmd_summary             = `$SMcli -n $storage_name -e -c "show storagesubsystem summary;" 2>/dev/null`;
        $cmd_summary_to_errorlog = "$SMcli -n $storage_name -e -c \"show storagesubsystem summary;\" 2>/dev/null";
      }
      @show_summary = split( "\n", $cmd_summary );

      # end of alarm
      alarm(0);
    };
    if ($@) {
      if ( $@ =~ /died in SIG ALRM/ ) {
        my $act_time = localtime();
        error("command timed out after : $timeout seconds");
        exit(0);
      }
    }
    if ( "@show_summary" !~ /SMcli completed successfully/ ) {
      $cmd_summary =~ s/\n//g;
      $cmd_summary = substr $cmd_summary, -512;
      if ( "@show_summary" =~ /error code 12/ ) {
        error("SMcli command failed: $cmd_summary_to_errorlog");
        error( "$cmd_summary : $!" . __FILE__ . ":" . __LINE__ );
        error("Most probably permission issue, STOR2RRD cannot run SMcli command. Problem description and fix: http://www.stor2rrd.com/install.htm#SMclierror");
        exit;
      }
      else {
        error("SMcli command failed: $cmd_summary_to_errorlog");
        error( "$cmd_summary : $!" . __FILE__ . ":" . __LINE__ );
        exit;
      }
    }
    my $package_version = "";
    foreach my $line (@show_summary) {
      chomp $line;
      $line =~ s/^\s+//g;
      if ( $line =~ "^Chassis Serial Number:" ) {
        $line =~ s/^\s+//g;
        $line =~ s/\s+$//g;
        my ( $title, $variable ) = split( ":", $line );
        $title =~ s/^\s+//g;
        $title =~ s/\s+$//g;
        $variable =~ s/^\s+//g;
        $variable =~ s/\s+$//g;
        print CONFOUT "$title: $variable\n";
      }
      if ( $line =~ "^Current Package Version:" ) {
        if   ( $package_version =~ "Current Package Version:" ) { next; }
        else                                                    { $package_version = $line; }
        $line =~ s/^\s+//g;
        $line =~ s/\s+$//g;
        my ( $title, $variable ) = split( ":", $line );
        $title =~ s/^\s+//g;
        $title =~ s/\s+$//g;
        $variable =~ s/^\s+//g;
        $variable =~ s/\s+$//g;
        print CONFOUT "$title: $variable\n";
      }
      if ( $line =~ "^SMW Version:" ) {
        $line =~ s/^\s+//g;
        $line =~ s/\s+$//g;
        my ( $title, $variable ) = split( ":", $line );
        $title =~ s/^\s+//g;
        $title =~ s/\s+$//g;
        $variable =~ s/^\s+//g;
        $variable =~ s/\s+$//g;
        print CONFOUT "$title: $variable\n";
      }
    }
  }
  if ( $storage_type =~ /old/ ) {
    eval {
      # Set alarm
      my $act_time = localtime();
      local $SIG{ALRM} = sub { die "$act_time: died in SIG ALRM"; };
      alarm($timeout);

      # CMDs
      if ( $user_name && $user_pw ) {
        $cmd_summary             = `$SMcli -n $storage_name -e -R $user_name -p $user_pw -c "show storagesubsystem summary;" 2>/dev/null`;
        $cmd_summary_to_errorlog = "$SMcli -n $storage_name -e -R $user_name -p <XXXXX> -c \"show storagesubsystem summary;\" 2>/dev/null";
      }
      else {
        $cmd_summary             = `$SMcli -n $storage_name -e -c "show storagesubsystem summary;" 2>/dev/null`;
        $cmd_summary_to_errorlog = "$SMcli -n $storage_name -e -c \"show storagesubsystem summary;\" 2>/dev/null";
      }
      @show_summary = split( "\n", $cmd_summary );

      # end of alarm
      alarm(0);
    };
    if ($@) {
      if ( $@ =~ /died in SIG ALRM/ ) {
        my $act_time = localtime();
        error("command timed out after : $timeout seconds");
        exit(0);
      }
    }
    if ( "@show_summary" !~ /SMcli completed successfully/ ) {
      $cmd_summary =~ s/\n//g;
      $cmd_summary = substr $cmd_summary, -512;
      if ( "@show_summary" =~ /error code 12/ ) {
        error("SMcli command failed: $cmd_summary_to_errorlog");
        error( "$cmd_summary : $!" . __FILE__ . ":" . __LINE__ );
        error("Most probably permission issue, STOR2RRD cannot run SMcli command. Problem description and fix: http://www.stor2rrd.com/install.htm#SMclierror");
        exit;
      }
      else {
        error("SMcli command failed: $cmd_summary_to_errorlog");
        error( "$cmd_summary : $!" . __FILE__ . ":" . __LINE__ );
        exit;
      }
    }
    my $firmware_vers = "";
    foreach my $line (@show_summary) {
      chomp $line;
      $line =~ s/^\s+//g;
      if ( $line =~ "^Firmware version:" ) {
        if   ( $firmware_vers =~ "Firmware version:" ) { next; }
        else                                           { $firmware_vers = $line; }
        $line =~ s/^\s+//g;
        $line =~ s/\s+$//g;
        my ( $title, $variable ) = split( ":", $line );
        $title =~ s/^\s+//g;
        $title =~ s/\s+$//g;
        $variable =~ s/^\s+//g;
        $variable =~ s/\s+$//g;
        print CONFOUT "$title: $variable\n";
      }
      if ( $line =~ "^SMW version:" ) {
        $line =~ s/^\s+//g;
        $line =~ s/\s+$//g;
        my ( $title, $variable ) = split( ":", $line );
        $title =~ s/^\s+//g;
        $title =~ s/\s+$//g;
        $variable =~ s/^\s+//g;
        $variable =~ s/\s+$//g;
        print CONFOUT "$title: $variable\n";
      }
      if ( $line =~ "^Feature pack:" ) {
        $line =~ s/^\s+//g;
        $line =~ s/\s+$//g;
        my ( $title, $variable ) = split( ":", $line );
        $title =~ s/^\s+//g;
        $title =~ s/\s+$//g;
        $variable =~ s/^\s+//g;
        $variable =~ s/\s+$//g;
        print CONFOUT "$title: $variable\n";
      }
      if ( $line =~ "^Feature pack submodel ID:" ) {
        $line =~ s/^\s+//g;
        $line =~ s/\s+$//g;
        my ( $title, $variable ) = split( ":", $line );
        $title =~ s/^\s+//g;
        $title =~ s/\s+$//g;
        $variable =~ s/^\s+//g;
        $variable =~ s/\s+$//g;
        print CONFOUT "$title: $variable\n";
      }
    }
  }

  # Volume part
  my @volume_cfg_lines   = grep {/Logical Drive name:|Capacity:|Logical Drive ID:|Associated disk pool:|Associated array:|Accessible By:|Interface type:|Drive interface type:|Drive type:/} @logicalDrives;
  my $volume_name_cfg    = "";
  my $volume_id_cfg      = "";
  my $volume_pool_cfg    = "";
  my $volume_capacity    = "";
  my $vol_interface_type = "";
  my @vol_hosts;
  my $hosts_in_logicalDrives = 0;
  my @vol_name_id;

  print CONFOUT "\nVolume Level Configuration\n";
  print CONFOUT "--------------------------\n";
  print CONFOUT "volume_id,id,name,,,,pool_id,pool_name,capacity (MB),,,,,,vdisk_UID,,,,,,interface_type\n";

  #print @config_lines;
  foreach my $line (@volume_cfg_lines) {
    chomp $line;
    if ( $line =~ "Logical Drive name:" ) {
      $line =~ s/Logical Drive name://g;
      $line =~ s/^\s+//g;
      $line =~ s/\s+$//g;
      $volume_name = $line;
    }
    if ( $line =~ "Logical Drive ID:" ) {
      $line =~ s/Logical Drive ID://g;
      $line =~ s/^\s+//g;
      $line =~ s/\s+$//g;
      $line =~ s/://g;
      $volume_id = $line;
      push( @vol_name_id, "$volume_name,$volume_id\n" );
    }
    if ( $line =~ "Associated disk pool:" || $line =~ "Associated array:" ) {
      $line =~ s/Associated disk pool://g;
      $line =~ s/Associated array://g;
      $line =~ s/^\s+//g;
      $line =~ s/\s+$//g;
      $volume_pool = $line;
    }
    if ( $line =~ "Capacity:" ) {
      $line =~ s/Capacity://g;
      $line =~ s/,//g;
      $line =~ s/^\s+//g;
      $line =~ s/\s+$//g;
      $volume_capacity = $line;
    }
    if ( $line =~ "Interface type:" || $line =~ "Drive interface type:" || $line =~ "Drive type:" ) {
      $line =~ s/Interface type://g;
      $line =~ s/Drive interface type://g;
      $line =~ s/Drive type://g;
      $line =~ s/^\s+//g;
      $line =~ s/\s+$//g;
      $vol_interface_type = $line;
      my $capacity;
      my ( $cap_num, $cap_size ) = split( " ", $volume_capacity );
      if ( $cap_size =~ /MB/ ) { $capacity = $cap_num; }
      if ( $cap_size =~ /GB/ ) { $capacity = $cap_num * 1024; }
      if ( $cap_size =~ /TB/ ) { $capacity = $cap_num * 1024 * 1024; }
      if ( $cap_size =~ /PB/ ) { $capacity = $cap_num * 1024 * 1024 * 1024; }

      my $test_perf_data = "";
      $test_perf_data    = grep {/^$volume_name,/} @storage_items;
      if ( ! defined $test_perf_data || $test_perf_data eq '' || $test_perf_data == 0 ) {
        print CONFOUT "$volume_id,,$volume_name,,,,,$volume_pool,$capacity,,,,,,,,,,,,$vol_interface_type,no_perf_data\n";
      }
      else {
        print CONFOUT "$volume_id,,$volume_name,,,,,$volume_pool,$capacity,,,,,,,,,,,,$vol_interface_type\n";
      }
    }
    if ( $line =~ "Accessible By:" ) {
      $hosts_in_logicalDrives = 1;
      $line =~ s/Accessible By://g;
      $line =~ s/^\s+//g;
      $line =~ s/\s+$//g;
      if ( $line =~ /^Host/ ) {
        push( @vol_hosts, "$volume_name,$line,$volume_id\n" );
      }
    }
  }

  # Host part
  # SMcli command
  my $cmd_hostTopology;
  my $cmd_hostTopology_to_errorlog;
  my @hostTopology;
  my $cmd_lunMappings;
  my $cmd_lunMappings_to_errorlog;
  my @lunMappings;

  eval {
    # Set alarm
    my $act_time = localtime();
    local $SIG{ALRM} = sub { die "$act_time: died in SIG ALRM"; };
    alarm($timeout);

    # CMDs
    if ( $user_name && $user_pw ) {
      $cmd_hostTopology             = `$SMcli -n $storage_name -e -R $user_name -p $user_pw -c "show hostTopology;" 2>/dev/null`;
      $cmd_hostTopology_to_errorlog = "$SMcli -n $storage_name -e -R $user_name -p <XXXXX> -c \"show hostTopology;\" 2>/dev/null";
    }
    else {
      $cmd_hostTopology             = `$SMcli -n $storage_name -e -c "show hostTopology;" 2>/dev/null`;
      $cmd_hostTopology_to_errorlog = "$SMcli -n $storage_name -e -c \"show hostTopology;\" 2>/dev/null";
    }
    @hostTopology = split( "\n", $cmd_hostTopology );

    if ( $hosts_in_logicalDrives == 0 ) {
      if ( $user_name && $user_pw ) {
        $cmd_lunMappings             = `$SMcli -n $storage_name -e -R $user_name -p $user_pw -c "show storageSubsystem lunMappings;" 2>/dev/null`;
        $cmd_lunMappings_to_errorlog = "$SMcli -n $storage_name -e -R $user_name -p <XXXXX> -c \"show storageSubsystem lunMappings;\" 2>/dev/null";
      }
      else {
        $cmd_lunMappings             = `$SMcli -n $storage_name -e -c "show storageSubsystem lunMappings;" 2>/dev/null`;
        $cmd_lunMappings_to_errorlog = "$SMcli -n $storage_name -e -c \"show storageSubsystem lunMappings;\" 2>/dev/null";
      }
      @lunMappings = split( "\n", $cmd_lunMappings );
    }

    # end of alarm
    alarm(0);
  };
  if ($@) {
    if ( $@ =~ /died in SIG ALRM/ ) {
      my $act_time = localtime();
      error("command timed out after : $timeout seconds");
      exit(0);
    }
  }
  if ( "@hostTopology" !~ /SMcli completed successfully/ ) {
    $cmd_hostTopology =~ s/\n//g;
    $cmd_hostTopology = substr $cmd_hostTopology, -512;
    if ( "@hostTopology" =~ /error code 12/ ) {
      error("SMcli command failed: $cmd_hostTopology_to_errorlog");
      error( "$cmd_hostTopology : $!" . __FILE__ . ":" . __LINE__ );
      error("Most probably permission issue, STOR2RRD cannot run SMcli command. Problem description and fix: http://www.stor2rrd.com/install.htm#SMclierror");
      exit;
    }
    else {
      error("SMcli command failed: $cmd_hostTopology_to_errorlog");
      error( "$cmd_hostTopology : $!" . __FILE__ . ":" . __LINE__ );
      exit;
    }
  }
  if ( $hosts_in_logicalDrives == 0 ) {
    if ( "@lunMappings" !~ /SMcli completed successfully/ ) {
      $cmd_lunMappings =~ s/\n//g;
      $cmd_lunMappings = substr $cmd_lunMappings, -512;
      if ( "@lunMappings" =~ /error code 12/ ) {
        error("SMcli command failed: $cmd_lunMappings_to_errorlog");
        error( "$cmd_lunMappings : $!" . __FILE__ . ":" . __LINE__ );
        error("Most probably permission issue, STOR2RRD cannot run SMcli command. Problem description and fix: http://www.stor2rrd.com/install.htm#SMclierror");
        exit;
      }
      else {
        error("SMcli command failed: $cmd_lunMappings_to_errorlog");
        error( "$cmd_lunMappings : $!" . __FILE__ . ":" . __LINE__ );
        exit;
      }
    }
  }

  print CONFOUT "\nHost Level Configuration\n";
  print CONFOUT "--------------------------\n";
  print CONFOUT "host_id,id,name,port_count,Type,volume_count,WWPN,Volume IDs,Volume Names\n";

  if ( $hosts_in_logicalDrives == 0 ) {
    my @hosts_from_lunMappings;
    foreach my $line (@vol_name_id) {
      chomp $line;
      my ($vol_name, $vol_id) = split(",",$line);
      my $host_line = "";
      ($host_line) = grep {/$vol_name /} @lunMappings;
      if ( defined $host_line ) {
        $host_line =~ s/^.+  Host /Host /g;
        $host_line =~ s/  .+//g;
        push( @hosts_from_lunMappings, "$vol_name,$host_line,$vol_id\n" );
      }
    }
    @vol_hosts = @hosts_from_lunMappings;
  }

  my $host_group = "";
  my $host_name  = "";
  foreach my $line (@hostTopology) {
    chomp $line;
    if ( $line =~ /Host Group:/ ) {
      $line =~ s/Host Group://g;
      $line =~ s/^\s+//g;
      $line =~ s/\s+$//g;
      $host_group = "$line";
    }
    if ( $line =~ /^         Host:/ ) {
      $host_group = "===UNKNOWN===XORUX===";
    }
    if ( $line =~ /Host:/ ) {
      $line =~ s/Host://g;
      $line =~ s/^\s+//g;
      $line =~ s/\s+$//g;
      $host_name = "$line";

      #print "HOST: $host_name GROUP: $host_group\n";
      my @vol_lines = grep {/$host_name,|$host_group,/} @vol_hosts;
      print CONFOUT ",,$host_name,,,,,";
      foreach my $line_i (@vol_lines) {
        chomp $line_i;
        my ( undef, undef, $vol_id ) = split( ",", $line_i );
        print CONFOUT "$vol_id ";
      }
      print CONFOUT ",";
      foreach my $line_l (@vol_lines) {
        chomp $line_l;
        my ( $vol_name, undef ) = split( ",", $line_l );
        print CONFOUT "$vol_name ";
      }
      print CONFOUT "\n";
    }
  }

  # Pool conf part
  print CONFOUT "\nPool Level Configuration\n";
  print CONFOUT "------------------------\n";
  print CONFOUT "name,id,status,mdisk_count,vdisk_count,capacity (GB),extent_size,free_capacity (GB),virtual_capacity,used_capacity (GB),real_capacity,overallocation,warning,easy_tier,easy_tier_status,compression_active,compression_virtual_capacity,compression_compressed_capacity,compression_uncompressed_capacity\n";

  my $last_pool = "";
  @pools = sort @pools;
  foreach (@pools) {
    chomp $_;
    #my $pool = $_;
    #if ( $pool eq $last_pool ) {next}
    #$last_pool = $pool;
    my $pool_line = $_;
    if ( $pool_line eq $last_pool ) {next}
    $last_pool = $pool_line;

    my ($pool, $pool_type) = split(",",$pool_line);

    # SMcli command
    my $cmd_show_array;
    my $cmd_show_array_to_errorlog;
    my @show_array;
    my $capacity      = "";
    my $used_capacity = "";
    my $free_capacity = "";

    #if ( $storage_type =~ /new/ ) {
    if ( $pool_type =~ /diskPool/ ) {
      eval {
        # Set alarm
        my $act_time = localtime();
        local $SIG{ALRM} = sub { die "$act_time: died in SIG ALRM"; };
        alarm($timeout);

        # CMDs
        if ( $user_name && $user_pw ) {
          $cmd_show_array             = `$SMcli -n $storage_name -e -R $user_name -p $user_pw -c "show diskPool [\\\"$pool\\\"] ;" 2>/dev/null`;
          $cmd_show_array_to_errorlog = "$SMcli -n $storage_name -e -R $user_name -p <XXXXX> -c \"show diskPool [\\\"$pool\\\"] ;\" 2>/dev/null";
        }
        else {
          $cmd_show_array             = `$SMcli -n $storage_name -e -c "show diskPool [\\\"$pool\\\"] ;" 2>/dev/null`;
          $cmd_show_array_to_errorlog = "$SMcli -n $storage_name -e -c \"show diskPool [\\\"$pool\\\"] ;\" 2>/dev/null";
        }
        @show_array = split( "\n", $cmd_show_array );

        # end of alarm
        alarm(0);
      };
      if ($@) {
        if ( $@ =~ /died in SIG ALRM/ ) {
          my $act_time = localtime();
          error("command timed out after : $timeout seconds");
          exit(0);
        }
      }
      if ( "@show_array" !~ /SMcli completed successfully/ ) {
        $cmd_show_array =~ s/\n//g;
        $cmd_show_array = substr $cmd_show_array, -512;
        if ( "@show_array" =~ /error code 12/ ) {
          error("SMcli command failed: $cmd_show_array_to_errorlog");
          error( "$cmd_show_array : $!" . __FILE__ . ":" . __LINE__ );
          error("Most probably permission issue, STOR2RRD cannot run SMcli command. Problem description and fix: http://www.stor2rrd.com/install.htm#SMclierror");
          exit;
        }
        else {
          error("SMcli command failed: $cmd_show_array_to_errorlog");
          error( "$cmd_show_array : $!" . __FILE__ . ":" . __LINE__ );
          exit;
        }
      }
      foreach my $line_k (@show_array) {
        chomp $line_k;
        if ( $line_k =~ "Usable capacity:" ) {
          $line_k =~ s/Usable capacity://g;
          $line_k =~ s/,//g;
          $line_k =~ s/^\s+//g;
          $line_k =~ s/\s+$//g;
          my ( $cap_num, $cap_size ) = split( " ", $line_k );
          if ( $cap_size =~ /^B/ ) { $capacity = $cap_num / 1024 / 1024 / 1024; }
          if ( $cap_size =~ /kB/ ) { $capacity = $cap_num / 1024 / 1024; }
          if ( $cap_size =~ /MB/ ) { $capacity = $cap_num / 1024; }
          if ( $cap_size =~ /GB/ ) { $capacity = $cap_num; }
          if ( $cap_size =~ /TB/ ) { $capacity = $cap_num * 1024; }
          if ( $cap_size =~ /PB/ ) { $capacity = $cap_num * 1024 * 1024; }
        }
        if ( $line_k =~ "Used capacity:" ) {
          $line_k =~ s/Used capacity://g;
          $line_k =~ s/,//g;
          $line_k =~ s/^\s+//g;
          $line_k =~ s/\s+$//g;
          my ( $cap_num, $cap_size ) = split( " ", $line_k );
          if ( $cap_size =~ /^B/ ) { $used_capacity = $cap_num / 1024 / 1024 / 1024; }
          if ( $cap_size =~ /kB/ ) { $used_capacity = $cap_num / 1024 / 1024; }
          if ( $cap_size =~ /MB/ ) { $used_capacity = $cap_num / 1024; }
          if ( $cap_size =~ /GB/ ) { $used_capacity = $cap_num; }
          if ( $cap_size =~ /TB/ ) { $used_capacity = $cap_num * 1024; }
          if ( $cap_size =~ /PB/ ) { $used_capacity = $cap_num * 1024 * 1024; }
        }
        if ( $line_k =~ "Free Capacity:" ) {
          $line_k =~ s/Free Capacity://g;
          $line_k =~ s/,//g;
          $line_k =~ s/^\s+//g;
          $line_k =~ s/\s+$//g;
          my ( undef, $cap_num, $cap_size ) = split( " ", $line_k );
          if ( $cap_size =~ /^B/ ) { $free_capacity = $cap_num / 1024 / 1024 / 1024; }
          if ( $cap_size =~ /kB/ ) { $free_capacity = $cap_num / 1024 / 1024; }
          if ( $cap_size =~ /MB/ ) { $free_capacity = $cap_num / 1024; }
          if ( $cap_size =~ /GB/ ) { $free_capacity = $cap_num; }
          if ( $cap_size =~ /TB/ ) { $free_capacity = $cap_num * 1024; }
          if ( $cap_size =~ /PB/ ) { $free_capacity = $cap_num * 1024 * 1024; }
        }
      }
      print CONFOUT "$pool,,,,,$capacity,,$free_capacity,,$used_capacity,,,,,,,,,\n";
    }
    #if ( $storage_type =~ /old/ ) {
    if ( $pool_type =~ /array/ ) {
      eval {
        # Set alarm
        my $act_time = localtime();
        local $SIG{ALRM} = sub { die "$act_time: died in SIG ALRM"; };
        alarm($timeout);

        # CMDs
        if ( $user_name && $user_pw ) {
          $cmd_show_array             = `$SMcli -n $storage_name -e -R $user_name -p $user_pw -c "show array [\\\"$pool\\\"] ;" 2>/dev/null`;
          $cmd_show_array_to_errorlog = "$SMcli -n $storage_name -e -R $user_name -p <XXXXX> -c \"show array [\\\"$pool\\\"] ;\" 2>/dev/null";
        }
        else {
          $cmd_show_array             = `$SMcli -n $storage_name -e -c "show array [\\\"$pool\\\"] ;" 2>/dev/null`;
          $cmd_show_array_to_errorlog = "$SMcli -n $storage_name -e -c \"show array [\\\"$pool\\\"] ;\" 2>/dev/null";
        }
        @show_array = split( "\n", $cmd_show_array );

        # end of alarm
        alarm(0);
      };
      if ($@) {
        if ( $@ =~ /died in SIG ALRM/ ) {
          my $act_time = localtime();
          error("command timed out after : $timeout seconds");
          exit(0);
        }
      }
      if ( "@show_array" !~ /SMcli completed successfully/ ) {
        $cmd_show_array =~ s/\n//g;
        $cmd_show_array = substr $cmd_show_array, -512;
        if ( "@show_array" =~ /error code 12/ ) {
          error("SMcli command failed: $cmd_show_array_to_errorlog");
          error( "$cmd_show_array : $!" . __FILE__ . ":" . __LINE__ );
          error("Most probably permission issue, STOR2RRD cannot run SMcli command. Problem description and fix: http://www.stor2rrd.com/install.htm#SMclierror");
          exit;
        }
        else {
          error("SMcli command failed: $cmd_show_array_to_errorlog");
          error( "$cmd_show_array : $!" . __FILE__ . ":" . __LINE__ );
          exit;
        }
      }
      foreach my $line_k (@show_array) {
        chomp $line_k;
        $line_k =~ s/^\s+//g;
        if ( $line_k =~ "^Capacity:" ) {
          $line_k =~ s/Capacity://g;
          $line_k =~ s/,//g;
          $line_k =~ s/^\s+//g;
          $line_k =~ s/\s+$//g;
          my ( $cap_num, $cap_size ) = split( " ", $line_k );
          if ( $cap_size =~ /^B/ ) { $capacity = $cap_num / 1024 / 1024 / 1024; }
          if ( $cap_size =~ /kB/ ) { $capacity = $cap_num / 1024 / 1024; }
          if ( $cap_size =~ /MB/ ) { $capacity = $cap_num / 1024; }
          if ( $cap_size =~ /GB/ ) { $capacity = $cap_num; }
          if ( $cap_size =~ /TB/ ) { $capacity = $cap_num * 1024; }
          if ( $cap_size =~ /PB/ ) { $capacity = $cap_num * 1024 * 1024; }
        }
        if ( $line_k =~ "^Free Capacity:" ) {
          $line_k =~ s/Free Capacity://g;
          $line_k =~ s/,//g;
          $line_k =~ s/^\s+//g;
          $line_k =~ s/\s+$//g;
          my ( $cap_num, $cap_size ) = split( " ", $line_k );
          if ( $cap_size =~ /^B/ ) { $free_capacity = $cap_num / 1024 / 1024 / 1024; }
          if ( $cap_size =~ /kB/ ) { $free_capacity = $cap_num / 1024 / 1024; }
          if ( $cap_size =~ /MB/ ) { $free_capacity = $cap_num / 1024; }
          if ( $cap_size =~ /GB/ ) { $free_capacity = $cap_num; }
          if ( $cap_size =~ /TB/ ) { $free_capacity = $cap_num * 1024; }
          if ( $cap_size =~ /PB/ ) { $free_capacity = $cap_num * 1024 * 1024; }
        }
      }
      print CONFOUT "$pool,,,,,$capacity,,$free_capacity,,$used_capacity,,,,,,,,,\n";
    }
  }
  close(CONFOUT);
}

health_status();

sub health_status {

  my $health_status_html =  "$webdir/$storage_name/health_status.html";
  my $act_timestamp      = time();
  my $hs_timestamp       = $act_timestamp;
  my $last_update        = localtime($act_timestamp);
  my $timestamp_diff     = 0;

  my @health_status_arr;
  my @HS_data_out;

  if ( -f $health_status_html ) {
    $hs_timestamp = (stat($health_status_html))[9];
    $timestamp_diff = $act_timestamp - $hs_timestamp;
  }

  if ( ! -f $health_status_html || $timestamp_diff > 180 ) {

    ### SMcli commands
    my $cmd_healthStatus;
    my $cmd_healthStatus_to_errorlog;
    eval {
      # Set alarm
      my $act_time = localtime();
      local $SIG{ALRM} = sub { die "$act_time: died in SIG ALRM"; };
      alarm($timeout);

      # CMDs
      if ( $user_name && $user_pw ) {
        $cmd_healthStatus             = `$SMcli -n $storage_name -e -R $user_name -p $user_pw -c "show storageSubsystem healthStatus;" 2>/dev/null`;
        $cmd_healthStatus_to_errorlog = "$SMcli -n $storage_name -e -R $user_name -p <XXXXX> -c \"show storageSubsystem healthStatus;\" 2>/dev/null";
      }
      else {
        $cmd_healthStatus             = `$SMcli -n $storage_name -e -c "show storageSubsystem healthStatus;" 2>/dev/null`;
        $cmd_healthStatus_to_errorlog = "$SMcli -n $storage_name -e -c \"show storageSubsystem healthStatus;\" 2>/dev/null";
      }
      @health_status_arr = split( "\n", $cmd_healthStatus );
      # end of alarm
      alarm(0);
    };

    if ($@) {
      if ( $@ =~ /died in SIG ALRM/ ) {
        my $act_time = localtime();
        error("command timed out after : $timeout seconds");
        exit(0);
      }
    }

    if ( "@health_status_arr" !~ /SMcli completed successfully/ ) {
      $cmd_healthStatus =~ s/\n//g;
      $cmd_healthStatus = substr $cmd_healthStatus, -512;
      if ( "@health_status_arr" =~ /error code 12/ ) {
        error("SMcli command failed: $cmd_healthStatus_to_errorlog");
        error( "$cmd_healthStatus : $!" . __FILE__ . ":" . __LINE__ );
        error("Most probably permission issue, STOR2RRD cannot run SMcli command. Problem description and fix: http://www.stor2rrd.com/install.htm#SMclierror");
        exit;
      }
      else {
        error("SMcli command failed: $cmd_healthStatus_to_errorlog");
        error( "$cmd_healthStatus : $!" . __FILE__ . ":" . __LINE__ );
        exit;
      }
    }

    my $storage_status = "";
    push(@HS_data_out, "<br>$last_update");

    foreach my $line (@health_status_arr) {
      chomp $line;
      if ( $line =~ "^Warning: The monitor" || $line =~ "^Executing script" || $line =~ "^The controller clocks" || $line =~ "^Controller in Slot" || $line =~ "^Storage Management Station:" || $line =~ "^Script execution complete" || $line =~ "^SMcli completed successfully" || $line eq '' || $line =~ "^Warning! No Monitor" ) {
        next;
      }
      else {
        push(@HS_data_out, "<br>$line");
      }
      if ( $line =~ "Storage Subsystem health status =" || $line =~ "Storage subsystem health status =" ) {
        $storage_status = $line;
        $storage_status =~ s/Storage Subsystem health status =//g;
        $storage_status =~ s/Storage subsystem health status =//g;
        $storage_status =~ s/^\s+//g;
        $storage_status =~ s/\s+$//g;
      }
    }
    push(@HS_data_out, "<br><br>");


    # Global health check
    my $act_timestamp  = time();
    my $main_state     = "OK";
    my $state_suffix   = "ok";
    my $component_name = $storage_name;

    $component_name =~ s/\s+//g;

    if ( $storage_status !~ "optimal" ) { $main_state = "NOT_OK"; $state_suffix = "nok"; }

    if (! -d "$inputdir/tmp/health_status_summary" ) {
      mkdir("$inputdir/tmp/health_status_summary", 0755) || error( "$act_time: Cannot mkdir $inputdir/tmp/health_status_summary: $!" . __FILE__ . ":" . __LINE__ ) && exit;
    }
    if ( -f "$inputdir/tmp/health_status_summary/$component_name.ok" )  { unlink ("$inputdir/tmp/health_status_summary/$component_name.ok"); }
    if ( -f "$inputdir/tmp/health_status_summary/$component_name.nok" ) { unlink ("$inputdir/tmp/health_status_summary/$component_name.nok"); }

    open( MAST, ">$inputdir/tmp/health_status_summary/$component_name.$state_suffix" ) || error( "Couldn't open file $inputdir/tmp/health_status_summary/$component_name.$state_suffix $!" . __FILE__ . ":" . __LINE__ ) && exit;
    print MAST "STORAGE : $storage_name : $main_state : $act_timestamp\n";
    close(MAST);

    #
    # get events logs
    #

    ### allevents

    my $cmd_allevent;
    my $cmd_allevent_to_errorlog;
    my @cmd_allevent_output;
    my $allevent_txt       = $output_dir . "allevent.txt";
    my @event_lines;
    my @allevent_data_out;

    my $seq_num         = "";
    my $seq_num_last    = "";
    my $take_new_events = 0;

    if ( -f $allevent_txt ) {
      open( AE, "<$allevent_txt" ) || die "Couldn't open file $allevent_txt";
      my @allevent_lines = <AE>;
      close(AE);

      my @sequence_number = grep {/^Sequence number:/} @allevent_lines;
      if ( defined $sequence_number[0] && $sequence_number[0] ne "" ) {
        $sequence_number[0] =~ s/^Sequence number://g;
        $sequence_number[0] =~ s/^\s+//g;
        $sequence_number[0] =~ s/\s+$//g;
        chomp $sequence_number[0];
        $seq_num = $sequence_number[0];
      }

      # last one eventlog
      my $cmd_last_event;
      my $cmd_last_event_to_errorlog;
      my @cmd_last_event_output;
      my $last_event_txt       = $output_dir . "last_event.txt";
      eval {
        # Set alarm
        my $act_time = localtime();
        local $SIG{ALRM} = sub { die "$act_time: died in SIG ALRM"; };
        alarm($timeout);
        # CMDs
        if ( $user_name && $user_pw ) {
          $cmd_last_event             = `$SMcli -n $storage_name -e -R $user_name -p $user_pw -c 'save storageSubsystem criticalEvents file="$last_event_txt" count=1 ;' 2>/dev/null`;
          $cmd_last_event_to_errorlog = "$SMcli -n $storage_name -e -R $user_name -p <XXXXX> -c \'save storageSubsystem criticalEvents file=\"$last_event_txt\" count=1 ;\' 2>/dev/null";
        }
        else {
          $cmd_last_event             = `$SMcli -n $storage_name -e -c 'save storageSubsystem criticalEvents file="$last_event_txt" count=1 ;' 2>/dev/null`;
          $cmd_last_event_to_errorlog = "$SMcli -n $storage_name -e -c \'save storageSubsystem criticalEvents file=\"$last_event_txt\" count=1 ;\' 2>/dev/null";
        }
        @cmd_last_event_output       = split( "\n", $cmd_last_event );
        # end of alarm
        alarm(0);
      };
      if ($@) {
        if ( $@ =~ /died in SIG ALRM/ ) {
          my $act_time = localtime();
          error("command timed out after : $timeout seconds");
          exit(0);
        }
      }
      if ( "@cmd_last_event_output" !~ /SMcli completed successfully/ ) {
        $cmd_last_event =~ s/\n//g;
        $cmd_last_event = substr $cmd_last_event, -512;
        if ( "@cmd_last_event_output" =~ /error code 12/ ) {
          error("SMcli command failed: $cmd_last_event_to_errorlog");
          error( "$cmd_last_event : $!" . __FILE__ . ":" . __LINE__ );
          error("Most probably permission issue, STOR2RRD cannot run SMcli command. Problem description and fix: http://www.stor2rrd.com/install.htm#SMclierror");
          exit;
        }
        else {
          error("SMcli command failed: $cmd_last_event_to_errorlog");
          error( "$cmd_last_event : $!" . __FILE__ . ":" . __LINE__ );
          next;
        }
      }

      open( LE, "<$last_event_txt" ) || die "Couldn't open file $last_event_txt";
      my @last_event_lines = <LE>;
      close(LE);

      my @last_sequence_number = grep {/^Sequence number:/} @last_event_lines;
      if ( defined $last_sequence_number[0] && $last_sequence_number[0] ne "" ) {
        $last_sequence_number[0] =~ s/^Sequence number://g;
        $last_sequence_number[0] =~ s/^\s+//g;
        $last_sequence_number[0] =~ s/\s+$//g;
        chomp $last_sequence_number[0];
        $seq_num_last = $last_sequence_number[0];
      }

      # diff lasr old and new sequence number
      if ( $seq_num eq $seq_num_last ) {
        @event_lines = @allevent_lines;
      }
      else {
        $take_new_events = 1;
      }
    }


    if ( ! -f $allevent_txt || $take_new_events == 1 ) {
      eval {
        # Set alarm
        my $act_time = localtime();
        local $SIG{ALRM} = sub { die "$act_time: died in SIG ALRM"; };
        alarm($timeout);
        # CMDs
        if ( $user_name && $user_pw ) {
          $cmd_allevent             = `$SMcli -n $storage_name -e -R $user_name -p $user_pw -c 'save storageSubsystem criticalEvents file="$allevent_txt";' 2>/dev/null`;
          $cmd_allevent_to_errorlog = "$SMcli -n $storage_name -e -R $user_name -p <XXXXX> -c \'save storageSubsystem criticalEvents file=\"$allevent_txt\";\' 2>/dev/null";
        }
        else {
          $cmd_allevent             = `$SMcli -n $storage_name -e -c 'save storageSubsystem criticalEvents file="$allevent_txt";' 2>/dev/null`;
          $cmd_allevent_to_errorlog = "$SMcli -n $storage_name -e -c \'save storageSubsystem criticalEvents file=\"$allevent_txt\";\' 2>/dev/null";
        }
        @cmd_allevent_output       = split( "\n", $cmd_allevent );
        # end of alarm
        alarm(0);
      };
      if ($@) {
        if ( $@ =~ /died in SIG ALRM/ ) {
          my $act_time = localtime();
          error("command timed out after : $timeout seconds");
          exit(0);
        }
      }
      if ( "@cmd_allevent_output" !~ /SMcli completed successfully/ ) {
        $cmd_allevent =~ s/\n//g;
        $cmd_allevent = substr $cmd_allevent, -512;
        if ( "@cmd_allevent_output" =~ /error code 12/ ) {
          error("SMcli command failed: $cmd_allevent_to_errorlog");
          error( "$cmd_allevent : $!" . __FILE__ . ":" . __LINE__ );
          error("Most probably permission issue, STOR2RRD cannot run SMcli command. Problem description and fix: http://www.stor2rrd.com/install.htm#SMclierror");
          exit;
        }
        else {
          error("SMcli command failed: $cmd_allevent_to_errorlog");
          error( "$cmd_allevent : $!" . __FILE__ . ":" . __LINE__ );
          exit;
        }
      }
      if ( -f $allevent_txt ) {
        open( AE, "<$allevent_txt" ) || die "Couldn't open file $allevent_txt";
        my @allevent_lines = <AE>;
        close(AE);
        @event_lines = @allevent_lines;
      }
      else {
        error( "$allevent_txt not found! : $!" . __FILE__ . ":" . __LINE__ );
      }
    }

    #my $events_header = "<table class =\"tabcfgsum\"><thead><tr><th>Date/Time</th><th>Sequence number</th><th>Event type</th><th>Event category</th><th>Priority</th><th>Event needs attention</th><th>Event send alert</th><th>Event visibility</th><th>Description</th><th>Event specific codes</th><th>Component type</th><th>Component location</th><th>Logged by</th></tr></thead><tbody>";

    my $events_header = "<table class =\"tabcfgsum tablesorter tablesortercfgsum\"><thead><tr>
<th class = \"sortable\" title=\"Date/Time\" nowrap=\"\">Date/Time&nbsp;&nbsp;&nbsp;&nbsp;</th>
<th class = \"sortable\" title=\"Sequence number\" nowrap=\"\">id&nbsp;&nbsp;&nbsp;&nbsp;</th>
<th class = \"sortable\" title=\"Event type\" nowrap=\"\">type&nbsp;&nbsp;&nbsp;&nbsp;</th>
<th class = \"sortable\" title=\"Event category\" nowrap=\"\">cat.&nbsp;&nbsp;&nbsp;&nbsp;</th>
<th class = \"sortable\" title=\"Priority\" nowrap=\"\">priority&nbsp;&nbsp;&nbsp;&nbsp;</th>
<th class = \"sortable\" title=\"Event needs attention\" nowrap=\"\">attn.&nbsp;&nbsp;&nbsp;&nbsp;</th>
<th class = \"sortable\" title=\"Event send alert\" nowrap=\"\">alert&nbsp;&nbsp;&nbsp;&nbsp;</th>
<th class = \"sortable\" title=\"Event visibility\" nowrap=\"\">visibility&nbsp;&nbsp;&nbsp;&nbsp;</th>
<th class = \"sortable\" title=\"Description\" nowrap=\"\">description&nbsp;&nbsp;&nbsp;&nbsp;</th>
<th class = \"sortable\" title=\"Event specific codes\" nowrap=\"\">code&nbsp;&nbsp;&nbsp;&nbsp;</th>
<th class = \"sortable\" title=\"Component type\" nowrap=\"\">com. type&nbsp;&nbsp;&nbsp;&nbsp;</th>
<th class = \"sortable\" title=\"Component location\" nowrap=\"\">com. location&nbsp;&nbsp;&nbsp;&nbsp;</th>
<th class = \"sortable\" title=\"Logged by\" nowrap=\"\">logged by&nbsp;&nbsp;&nbsp;&nbsp;</th></tr>
</thead><tbody>";

    push ( @allevent_data_out, "$events_header\n");

    my $Date_Time             = "";
    my $Sequence_number       = "";
    my $Event_type            = "";
    my $Event_category        = "";
    my $Priority              = "";
    my $Event_needs_attention = "";
    my $Event_send_alert      = "";
    my $Event_visibility      = "";
    my $Description           = "";
    my $Event_specific_codes  = "";
    my $Component_type        = "";
    my $Component_location    = "";
    my $Logged_by             = "";

    foreach my $line (@event_lines) {
      chomp $line;
      if ( $line =~ "^Date/Time:" )             { $line =~ s/^Date\/Time: //g;            $Date_Time = $line; }
      if ( $line =~ "^Sequence number:" )       { $line =~ s/^Sequence number: //g;       $Sequence_number = $line; }
      if ( $line =~ "^Event type:" )            { $line =~ s/^Event type: //g;            $Event_type = $line; }
      if ( $line =~ "^Event category:" )        { $line =~ s/^Event category: //g;        $Event_category = $line; }
      if ( $line =~ "^Priority:" )              { $line =~ s/^Priority: //g;              $Priority = $line; }
      if ( $line =~ "^Event needs attention:" ) { $line =~ s/^Event needs attention: //g; $Event_needs_attention = $line; }
      if ( $line =~ "^Event send alert:" )      { $line =~ s/^Event send alert: //g;      $Event_send_alert = $line; }
      if ( $line =~ "^Event visibility:" )      { $line =~ s/^Event visibility: //g;      $Event_visibility = $line; }
      if ( $line =~ "^Description:" )           { $line =~ s/^Description: //g;           $Description = $line; }
      if ( $line =~ "^Event specific codes:" )  { $line =~ s/^Event specific codes: //g;  $Event_specific_codes = $line; }
      if ( $line =~ "^Component type:" )        { $line =~ s/^Component type: //g;        $Component_type = $line; }
      if ( $line =~ "^Component location:" )    { $line =~ s/^Component location: //g;    $Component_location = $line; }
      if ( $line =~ "^Logged by:" )             { $line =~ s/^Logged by: //g;             $Logged_by = $line; }

      if ( $line =~ "^Raw data:") {
        push ( @allevent_data_out, "<tr><td nowrap=\"\">$Date_Time</td><td nowrap=\"\">$Sequence_number</td><td nowrap=\"\">$Event_type</td><td nowrap=\"\">$Event_category</td><td nowrap=\"\">$Priority</td><td nowrap=\"\">$Event_needs_attention</td><td nowrap=\"\">$Event_send_alert</td><td nowrap=\"\">$Event_visibility</td><td nowrap=\"\">$Description</td><td nowrap=\"\">$Event_specific_codes</td><td nowrap=\"\">$Component_type</td><td nowrap=\"\">$Component_location</td><td nowrap=\"\">$Logged_by</td></tr>\n");
      }
    }
    push ( @allevent_data_out, "</tbody></table>\n");

    open( HS, ">$health_status_html" ) || error( "Couldn't open file $health_status_html $!" . __FILE__ . ":" . __LINE__ ) && exit;

    print HS "<HTML> <HEAD> <TITLE>STOR2RRD</TITLE> </HEAD>\n";
    print HS "<BODY BGCOLOR=#D3D2D2 TEXT=#000000 LINK=#0000FF VLINK= #000080 ALINK=#FF0000 >\n";
    print HS "@HS_data_out";
    print HS "@allevent_data_out";
    print HS "</body></html>\n";
    print HS "</pre></body></html>\n";

    close(HS);
  }
}

### ERROR HANDLING
sub error {
  my $text     = shift;
  my $act_time = localtime();
  chomp($text);
  print STDERR "$act_time: $text : $!\n";
  return 1;
}
