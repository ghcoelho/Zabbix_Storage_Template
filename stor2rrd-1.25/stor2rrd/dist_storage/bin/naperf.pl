#!/usr/bin/perl
# vim: set filetype=perl :

# Modules
use strict;
use warnings;
use Storable;
use Data::Dumper;
use Date::Parse;
use POSIX qw(strftime);
use XML::Simple;
use LWP::UserAgent;
use HTTP::Request;
use Sys::Hostname;

my $md5module = 1;
eval "use Digest::MD5 qw(md5_hex); 1" or $md5module = 0;

use lib "../bin";

if ( !$md5module ) {
  use MD5 qw(md5_hex);
}
my $hostname = hostname;
my $cntr_prefix = substr(md5_hex($hostname), 0, 4) . "_";


$XML::Simple::PREFERRED_PARSER = 'XML::Parser';

# Options and their default value
my $mininterval    = 300;       # minimal interval time for data collection (sec)
my $dir            = "..";      # Data directory
my $now;
my $ssh = "ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=no -o PreferredAuthentications=publickey ";

my $debug          = 0;         # Debug mode 0:off, 1:on
my $debug_full     = 0;         # Debug mode 0:off, 1:on
my $storname       = "";
my $storip         = "";
my $stormode       = "";
my $userrname      = "";
my $statsFile;
# chomp(my $HOSTNAME = `hostname -s`);

my %netapp;
my $filer;

# required counters for 7-mode
my @volcounters = qw(read_ops read_data read_latency write_ops write_data write_latency total_ops avg_latency node_uuid node_name);  # volume
my @aggcounters = qw(user_reads user_writes user_read_blocks user_write_blocks total_transfers total_transfers_hdd total_transfers_ssd user_reads_hdd user_writes_hdd user_read_blocks_hdd user_write_blocks_hdd user_reads_ssd user_writes_ssd user_read_blocks_ssd user_write_blocks_ssd node_uuid node_name); # aggregate
my @dskcounters = qw(user_reads user_writes user_read_blocks user_read_latency user_write_blocks user_write_latency total_transfers disk_speed disk_capacity disk_busy display_name raid_name); # disk
my @syscounters = qw(system_id system_model serial_no ontap_version);               # system
my @hacounters  = qw(total_reads total_writes bytes_read bytes_written); # hostadapter
my @ifcounters  = qw(recv_packets recv_errors send_packets send_errors collisions recv_data send_data recv_drop_packets); # ifnet
my @luncounters = qw(read_ops write_ops other_ops read_data write_data queue_full avg_latency total_ops avg_read_latency avg_write_latency avg_other_latency queue_depth_lun display_name); # LUN

my $bindir = $ENV{BINDIR};
if (defined $ENV{DEBUG}) { $debug = $ENV{DEBUG} }
if (defined $ENV{DEBUG_FULL}) { $debug_full = $ENV{DEBUG_FULL} }
if (defined $ENV{NA_DIR}) { $dir = $ENV{NA_DIR} }

if (defined $ENV{STORAGE_NAME}) {
  $storname = $ENV{STORAGE_NAME};
} else {
  error("naperf.pl: NetApp storage name alias is required.\n");
  exit(1);
}

if (defined $ENV{STORAGE_MODE}) {
  $stormode = $ENV{STORAGE_MODE};
} else {
  error("naperf.pl: NetApp storage mode is required.\n");
  exit(1);
}

my $tmpdir = "$dir/";       # Directory for temporary files

my $out_perf_file;          #
my $out_conf_file;          #
my $cacheFile = $tmpdir."$storname.cache.file";

sub file_write {
  my $file = shift;
  open IO, ">$file" or die "Cannot open $file for output: $!\n";
  print IO @_;
  close IO;
}

sub file_read {
  my $file = shift;
  open IO, $file or die "Cannot open $file for input: $!\n";
  my @data = <IO>;
  close IO;
  wantarray ? @data : join( '' => @data );
}

sub trim {
  my $s = shift;
  $s =~ s/^\s+|\s+$//g;
  return $s;
}

my $storage;
my $cache;
my $data;
my $config;
my $tzoffset;

sub message {
  my $msg = shift;
  my $tm = localtime();
  print("INFO ".$tm." naperf.pl: ".$msg."\n");
}

sub warning {
  my ($msg,$rc) = @_;
  my $tm = localtime();
  print STDERR ("WARNING ".$tm." naperf.pl: ".$msg."\n");
}

sub error {
  my ($msg,$rc) = @_;
  my $tm = localtime();
  print STDERR ("ERROR ".$tm." naperf.pl: ".$msg."\n");
}

sub writeStats {
  if(! defined $cache->{'timestamp'} ) {
    store(\%netapp, $cacheFile);
    return;
  }
  $data->{'IntervalStartTime'} = $cache->{'timestamp'};
  # Open output file
  $out_perf_file = $tmpdir . $storname . "_netappperf_" . &fileextTime($now) . ".out";
  open (PERFOUT,">>${out_perf_file}.tmp") || die "Couldn't open file ${out_perf_file}.tmp.";
  #
  my $elementType = shift;
  if ( $elementType eq "volume" ) {
    &writeVolumeStats;
  } elsif ( $elementType eq "pool" ) {
    &writePoolStats;
  } elsif ( $elementType eq "disk" ) {
    &writeDiskStats;
  } elsif ( $elementType eq "lun" ) {
    &writeLUNStats;
  } elsif ( $elementType eq "ha" ) {
    &writeHAStats;
  } elsif ( $elementType eq "if" ) {
    &writeIFStats;
  }
  close(PERFOUT);
}

sub writeVolumeStats {
  # print Dumper $volperf;
  #my %data;

  print PERFOUT "\nVolume Level Statistics\n";
  print PERFOUT "\tInterval Start:   ",&epoch2isotime($data->{'IntervalStartTime'},$tzoffset),"\n" if ( defined $data->{'IntervalStartTime'} );
  print PERFOUT "\tInterval End:     ",&epoch2isotime($data->{'IntervalEndTime'},$tzoffset),"\n" if ( defined $data->{'IntervalEndTime'});
  print PERFOUT "\tInterval Length:  ",$data->{'Interval'}," seconds\n" if ( defined $data->{'Interval'} );
  print PERFOUT "---------------------\n";
  print PERFOUT "volume_id,name,total_ops,avg_latency,read_ops,read_data,read_latency,write_ops,write_data,write_latency\n";
  foreach my $node (sort keys %{$netapp{volume}}) {
    my %t = %{$netapp{volume}{$node}};
    #print Dumper %t;
    # if (! $t{node_name}) {
    #   next;
    # }
    if (! $t{uuid} ) {
      $t{uuid} = $node;
    }
    #print Dumper @volcounters;
    my %r;
    @r{@volcounters} = @t{@volcounters};
    &reCalc(\%r);

    # print "$node: " . Dumper \%r;

    {
      no warnings 'uninitialized';
      print PERFOUT "$t{uuid},$node,$r{total_ops},$r{avg_latency},$r{read_ops},$r{read_data},$r{read_latency},$r{write_ops},$r{write_data},$r{write_latency}\n";
    }
  }
}

sub writePoolStats {
  # print Dumper $volperf;
  #my %data;

  print PERFOUT "\nRaid Level Statistics\n";
  print PERFOUT "\tInterval Start:   ",&epoch2isotime($data->{'IntervalStartTime'},$tzoffset),"\n" if ( defined $data->{'IntervalStartTime'} );
  print PERFOUT "\tInterval End:     ",&epoch2isotime($data->{'IntervalEndTime'},$tzoffset),"\n" if ( defined $data->{'IntervalEndTime'});
  print PERFOUT "\tInterval Length:  ",$data->{'Interval'}," seconds\n" if ( defined $data->{'Interval'} );
  print PERFOUT "---------------------\n";
  print PERFOUT "instance_uuid,instance_name,total_transfers,user_reads,user_writes,user_read_blocks,user_write_blocks,cap,used_cap,,,,,user_reads_hdd,user_reads_ssd,user_writes_hdd,user_writes_ssd\n";
  foreach my $node (sort keys %{$netapp{aggregate}}) {
    my %t = %{$netapp{aggregate}{$node}};
    $t{uuid} ||= $node;
    my %r;
    @r{@aggcounters} = @t{@aggcounters};
    &reCalc(\%r);
    {
      no warnings 'uninitialized';
      print PERFOUT "$t{uuid},$node,$r{total_transfers},$r{user_reads},$r{user_writes},$r{user_read_blocks},$r{user_write_blocks}," . &ConvSizeUnits('GB',$t{'size-total'}) . "," . &ConvSizeUnits('GB',$t{'size-used'}). ",,,,,$r{user_reads_hdd},$r{user_reads_ssd},$r{user_writes_hdd},$r{user_writes_ssd}\n";
    }
  }
}

sub writeDiskStats {
  # print Dumper $volperf;
  #my %data;

  print PERFOUT "\nDrive Level Statistics\n";
  print PERFOUT "\tInterval Start:   ",&epoch2isotime($data->{'IntervalStartTime'},$tzoffset),"\n" if ( defined $data->{'IntervalStartTime'} );
  print PERFOUT "\tInterval End:     ",&epoch2isotime($data->{'IntervalEndTime'},$tzoffset),"\n" if ( defined $data->{'IntervalEndTime'});
  print PERFOUT "\tInterval Length:  ",$data->{'Interval'}," seconds\n" if ( defined $data->{'Interval'} );
  print PERFOUT "---------------------\n";
  my @metrics = qw(disk-uid name read_ops write_ops read_data write_data user_reads user_writes user_read_latency user_write_latency user_read_blocks user_write_blocks total_transfers);
  print PERFOUT join (",", @metrics) . "\n";
  foreach my $node (sort keys %{$netapp{disk}}) {
    my %t = %{$netapp{disk}{$node}};
    #print Dumper %t;
    my %r;
    @r{@dskcounters} = @t{@dskcounters};
    &reCalc(\%r);

    # print "$node: " . Dumper \%r;

    {
      no warnings 'uninitialized';
      if ($stormode eq "7MODE") {
        print PERFOUT "$node,$t{'display_name'},$r{read_ops},$r{write_ops},$r{read_data},$r{write_data},$r{user_reads},$r{user_writes},$r{user_read_latency},$r{user_write_latency},$r{user_read_blocks},$r{user_write_blocks},$r{total_transfers}\n";
      } else {
        print PERFOUT "$t{'disk-uid'},$node,$r{read_ops},$r{write_ops},$r{read_data},$r{write_data},$r{user_reads},$r{user_writes},$r{user_read_latency},$r{user_write_latency},$r{user_read_blocks},$r{user_write_blocks},$r{total_transfers}\n";
      }
    }
  }
}

sub writeLUNStats {
  # print Dumper $volperf;
  #my %data;

  print PERFOUT "\nLUN Level Statistics\n";
  print PERFOUT "\tInterval Start:   ",&epoch2isotime($data->{'IntervalStartTime'},$tzoffset),"\n" if ( defined $data->{'IntervalStartTime'} );
  print PERFOUT "\tInterval End:     ",&epoch2isotime($data->{'IntervalEndTime'},$tzoffset),"\n" if ( defined $data->{'IntervalEndTime'});
  print PERFOUT "\tInterval Length:  ",$data->{'Interval'}," seconds\n" if ( defined $data->{'Interval'} );
  print PERFOUT "---------------------\n";
  my @metrics = qw(uuid name read_ops write_ops read_data write_data avg_read_latency avg_write_latency avg_latency total_ops other_ops);
  print PERFOUT join (",", @metrics) . "\n";
  foreach my $node (sort keys %{$netapp{lun}}) {
    my %t = %{$netapp{lun}{$node}};
    #print Dumper %t;
    my %r;
    @r{@luncounters} = @t{@luncounters};
    &reCalc(\%r);

    # print "$node: " . Dumper \%r;

    {
      no warnings 'uninitialized';
      print PERFOUT "$r{uuid},$node,$r{read_ops},$r{write_ops},$r{read_data},$r{write_data},$r{avg_read_latency},$r{avg_write_latency},$r{avg_latency},$r{total_ops},$r{other_ops}\n";
    }
  }
}

sub writeHAStats {
  # print Dumper $volperf;
  #my %data;

  print PERFOUT "\nPort Level Statistics\n";
  print PERFOUT "\tInterval Start:   ",&epoch2isotime($data->{'IntervalStartTime'},$tzoffset),"\n" if ( defined $data->{'IntervalStartTime'} );
  print PERFOUT "\tInterval End:     ",&epoch2isotime($data->{'IntervalEndTime'},$tzoffset),"\n" if ( defined $data->{'IntervalEndTime'});
  print PERFOUT "\tInterval Length:  ",$data->{'Interval'}," seconds\n" if ( defined $data->{'Interval'} );
  print PERFOUT "---------------------\n";
  my @metrics = qw(name total_reads total_writes kbytes_read kbytes_written);
  print PERFOUT join (",", @metrics) . "\n";
  foreach my $node (sort keys %{$netapp{hostadapter}}) {
    my %t = %{$netapp{hostadapter}{$node}};
    #print Dumper %t;
    my %r;
    @r{@hacounters} = @t{@hacounters};
    &reCalc(\%r);

    # print "$node: " . Dumper \%r;

    {
      $r{bytes_read} ||= 0;
      $r{bytes_written} ||= 0;
      $r{bytes_read} = sprintf( "%.3f", $r{bytes_read} / 1024 );
      $r{bytes_written} = sprintf( "%.3f", $r{bytes_written} / 1024 );
      no warnings 'uninitialized';
      print PERFOUT "$node,$r{total_reads},$r{total_writes},$r{bytes_read},$r{bytes_written}\n";
    }
  }
}

sub writeIFStats {
  # print Dumper $volperf;
  #my %data;

  print PERFOUT "\nIFNET Level Statistics\n";
  print PERFOUT "\tInterval Start:   ",&epoch2isotime($data->{'IntervalStartTime'},$tzoffset),"\n" if ( defined $data->{'IntervalStartTime'} );
  print PERFOUT "\tInterval End:     ",&epoch2isotime($data->{'IntervalEndTime'},$tzoffset),"\n" if ( defined $data->{'IntervalEndTime'});
  print PERFOUT "\tInterval Length:  ",$data->{'Interval'}," seconds\n" if ( defined $data->{'Interval'} );
  print PERFOUT "---------------------\n";
  my @metrics = qw(name recv_packets recv_errors send_packets send_errors collisions recv_data send_data recv_drop_packets);
  print PERFOUT join (",", @metrics) . "\n";
  foreach my $node (sort keys %{$netapp{ifnet}}) {
    my %t = %{$netapp{ifnet}{$node}};
    #print Dumper %t;
    my %r;
    @r{@ifcounters} = @t{@ifcounters};
    &reCalc(\%r);

    # print "$node: " . Dumper \%r;

    {
      no warnings 'uninitialized';
      print PERFOUT "$node,$r{recv_packets},$r{recv_errors},$r{send_packets},$r{send_errors},$r{collisions},$r{recv_data},$r{send_data},$r{recv_drop_packets}\n";
    }
  }
}

sub reCalc {
  my $vals = shift;
  while (my ($key, $value) = each (%{$vals})) {
    if (! $value) {
      next;
    }
    if ($value eq "-") {
      $vals->{$key} = 0;
    } elsif ($value =~ /KB/) {
      $vals->{$key} =~ s/KB//;
    } elsif ($value =~ /.*\/s/) {
      $vals->{$key} =~ s/\/s//;
    } elsif ($value =~ /us/) {
      $vals->{$key} =~ s/us//;
      $vals->{$key} = sprintf( "%.3f", $vals->{$key} / 1000 );
    } elsif ($value =~ /ms/) {
      $vals->{$key} =~ s/ms//;
    }
    if ($value =~ /[0-9]+b/) {
      $vals->{$key} =~ s/b//;
      $vals->{$key} = sprintf( "%.3f", $vals->{$key} / 1024 );
    }
  }
  # print Dumper \$vals;
}

sub writeConf {
  # Open output file
  if(! defined $data->{'IntervalEndTime'} ) {
    return;
  }
  $out_conf_file = $tmpdir . $storname . "_netappconf_" . &fileextTime($data->{'IntervalEndTime'}) . ".out";
  open (PERFOUT,">>${out_conf_file}.tmp") || die "Couldn't open file ${out_perf_file}.tmp.";
  #
  my $elementType = shift;
  &writeSystemConf if ( $elementType eq "system" );
  &writePoolConf if ( $elementType eq "pool" );
  &writeVolumeConf if ( $elementType eq "volume" );
  &writeDiskConf if ( $elementType eq "disk" );
  &writeLUNConf if ( $elementType eq "lun" );
  &writeHAConf if ( $elementType eq "ha" );
  &writeIFConf if ( $elementType eq "if" );
  close(PERFOUT);
}

sub writeSystemConf {
  print PERFOUT "\nConfiguration Data\n------------------\n";
  #print PERFOUT "\tMachine Name:".$config->{'system'}->{'Name'}."\t\n";
  print PERFOUT "\tMachine Type: NetApp\t\n";
  my $mode = "cluster";
  if ($stormode eq "7MODE") {
    $mode = "system";
  }
  if (exists $netapp{system}{$mode}{ontap_version}) {
    $netapp{system}{$mode}{ontap_version} =~ s/\"//g;
  }
  {
    no warnings 'uninitialized';
    print PERFOUT "\tSystem ID: $netapp{system}{$mode}{system_id}\t\n";
    print PERFOUT "\tMachine Serial: $netapp{system}{$mode}{serial_no}\t\n";
    print PERFOUT "\tSystem Model: $netapp{system}{$mode}{system_model}\t\n";
    print PERFOUT "\tSystem Mode: $stormode\t\n";
    print PERFOUT "\tONTAP Version: $netapp{system}{$mode}{ontap_version}\t\n";
    print PERFOUT "\n";
  }
}

sub writePoolConf {
  print PERFOUT "\nRaid Level Configuration\n------------------------\n";
  print PERFOUT "name,id,node_name,node_uuid,status,capacity,used_capacity\n";
  foreach my $node (sort keys %{$netapp{aggregate}}) {
    my $t = \%{$netapp{aggregate}{$node}};
    $t->{uuid} ||= $node;
    $t->{node_name} ||= "";
    $t->{node_uuid} ||= "";
    $t->{'size-total'} ||= 0;
    # print Dumper $t;
    printf PERFOUT ("%s,%s,%s,%s,%s,%.3f,%.3f\n",$node,$t->{uuid},$t->{node_name},$t->{node_uuid},"",&ConvSizeUnits("GB",$t->{'size-total'}),&ConvSizeUnits("GB",$t->{'size-used'}));
  }
}

sub writeVolumeConf {
  print PERFOUT "\nVolume Level Configuration\n--------------------------\n";
  my @metrics = qw(uuid name containing-aggregate-uuid containing-aggregate-name owning-vserver-uuid owning-vserver-name type instance-uuid state size-total size-available filesystem-size size-used percentage-used files-used files-total snapshot-percent-reserved);
  print PERFOUT join (",", @metrics) . "\n";
  foreach my $node (sort keys %{$netapp{volume}}) {
    my $t = \%{$netapp{volume}{$node}};
    $t->{uuid} ||= $node;
    $t->{'size-total'} ||= 0;
    {
      no warnings 'uninitialized';
      printf PERFOUT ("%s,%s,%s,%s,%s,%s,%s,%s,%s,%.3f,%.3f,%.3f,%.3f,%s,%s,%s,%s\n", $t->{uuid},$node,$t->{'containing-aggregate-uuid'},$t->{'containing-aggregate'},$t->{'owning-vserver-uuid'},$t->{'owning-vserver-name'},$t->{'type'},$t->{'instance-uuid'},$t->{'state'},&ConvSizeUnits("GB",$t->{'size-total'}),&ConvSizeUnits("GB",$t->{'size-available'}),&ConvSizeUnits("GB",$t->{'filesystem-size'}),&ConvSizeUnits("GB",$t->{'size-used'}),$t->{'percentage-used'},$t->{'files-used'},$t->{'files-total'},$t->{'snapshot-percent-reserved'});
    }
  }
}

sub writeLUNConf {
  print PERFOUT "\nLUN Level Configuration\n--------------------------\n";
  my @metrics = qw(uuid name serial-number block-size staging is-space-reservation-enabled alignment size size-used suffix-size multiprotocol-type share-state online prefix-size read-only mapped);
  print PERFOUT join (",", @metrics) . "\n";
  foreach my $node (sort keys %{$netapp{lun}}) {
    my $t = \%{$netapp{lun}{$node}};
    $t->{uuid} ||= $node;
    {
      no warnings 'uninitialized';
      printf PERFOUT ("%s,%s,%s,%s,%s,%s,%s,%.3f,%.3f,%s,%s,%s,%s,%s,%s,%s\n", $t->{uuid},$node,$t->{'serial-number'},$t->{'block-size'},$t->{'staging'},$t->{'is-space-reservation-enabled'},$t->{'alignment'},&ConvSizeUnits("GB",$t->{'size'}),&ConvSizeUnits("GB",$t->{'size-used'}),$t->{'suffix-size'},$t->{'multiprotocol-type'},$t->{'share-state'},$t->{'online'},$t->{'prefix-size'},$t->{'read-only'},$t->{'mapped'});
    }
  }
}

sub writeDiskConf {
  print PERFOUT "\nDrive Level Configuration\n";
  print PERFOUT   "-------------------------\n";
  print PERFOUT "disk-uid,name,id,port-name,raid-group,used-space,disk_capacity,port,raid-type,vendor-id,disk-type,node,plex,used-blocks,pool,aggregate,serial-number,disk-model,effective-disk-type,host-adapter,physical-space\n";
  foreach my $node (sort keys %{$netapp{disk}}) {
    my $t = \%{$netapp{disk}{$node}};
    #$t->{'disk-uid'} ||= $node;
    {
      no warnings 'uninitialized';
      if ($stormode eq "7MODE") {
        printf PERFOUT ("%s,%s,%s,%s,%.3f,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%.3f\n", $node, $t->{'display_name'},$t->{'port-name'},$t->{'raid-group'},&ConvSizeUnits("GB",$t->{'used-space'}),$t->{'disk_capacity'},$t->{'port'},$t->{'raid-type'},$t->{'vendor-id'},$t->{'disk-type'},$t->{'node'},$t->{'plex'},$t->{'used-blocks'},$t->{'pool'},$t->{'aggregate'},$t->{'serial-number'},$t->{'disk-model'},$t->{'effective-disk-type'},$t->{'host-adapter'},&ConvSizeUnits("GB",$t->{'physical-space'}));
      } else {
        printf PERFOUT ("%s,%s,%s,%s,%.3f,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%.3f\n", $t->{'disk-uid'},$node,$t->{'port-name'},$t->{'raid-group'},&ConvSizeUnits("GB",$t->{'used-space'}),$t->{'disk_capacity'},$t->{'port'},$t->{'raid-type'},$t->{'vendor-id'},$t->{'disk-type'},$t->{'node'},$t->{'plex'},$t->{'used-blocks'},$t->{'pool'},$t->{'aggregate'},$t->{'serial-number'},$t->{'disk-model'},$t->{'effective-disk-type'},$t->{'host-adapter'},&ConvSizeUnits("GB",$t->{'physical-space'}));
      }
    }
  }
}

sub writeHAConf {
  print PERFOUT "\nPort Level Configuration\n------------------------\n";
  print PERFOUT "name,node_name,node_uuid\n";
  foreach my $node (sort keys %{$netapp{hostadapter}}) {
    my $t = \%{$netapp{hostadapter}{$node}};
    {
      no warnings 'uninitialized';
      printf PERFOUT ("%s,%s,%s\n",$node,$t->{node_name},$t->{node_uuid});
    }
  }
}

sub writeIFConf {
  print PERFOUT "\nIFNET Level Configuration\n------------------------\n";
  print PERFOUT "name,node_name,node_uuid\n";
  foreach my $node (sort keys %{$netapp{ifnet}}) {
    my $t = \%{$netapp{ifnet}{$node}};
    {
      no warnings 'uninitialized';
      printf PERFOUT ("%s,%s,%s\n",$node,$t->{node_name},$t->{node_uuid});
    }
  }
}

sub fileextTime {
  my $t = shift;
  if (! defined $t ) { return "NA"; }
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($t);
    my $y = $year + 1900;
    my $m = $mon + 1;
  return sprintf("%d%02d%02d_%02d%02d",$y,$m,$mday,$hour,$min,$sec);
}

sub isotime {
  my $t = shift;
  if ( $t =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2}).(\d{6})([\+-])(\d+)$/ ) {
    my $tmod = $9 % 60;
    use integer;
    my $tdiv = $9 / 60;
    no integer;
    my $tz = sprintf("%04d",($tdiv * 100) + $tmod );
    return sprintf("%d:%02d:%02dT%02d:%02d:%02d.%06d%s%s",$1,$2,$3,$4,$5,$6,$7,$8,$tz);
  }
}

sub ConvSizeUnits {
  my ($unit,$size) = @_;
  if (! $size ) {
    return 0;
  }
  if ( $unit eq "KB" ) { return($size / 1024) }
  if ( $unit eq "MB" ) { return($size / 1048576) }
  if ( $unit eq "GB" ) { return($size / 1073741824) }
  if ( $unit eq "TB" ) { return($size / 1099511627776) }
}

sub tzoffset {
  return strftime("%z", localtime);
}

sub epoch2isotime {
  # Output: 2015:02:05T19:54:07.000000+0100
  my ($tm,$tz) = @_;	# epoch, TZ offset (+0100)
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($tm);
  my $y = $year + 1900;
  my $m = $mon + 1;
  my $mcs = 0;
  my $str = sprintf("%4d:%02d:%02dT%02d:%02d:%02d.%06d%s",$y,$m,$mday,$hour,$min,$sec,$mcs,$tz);
  return($str);
}

sub obscure_password {
  my $string = shift;
  my $obscure = encode_base64(pack("u",$string), "");
  return $obscure;
}

sub unobscure_password {
  my $string = shift;
  my $unobscure = decode_base64($string);
  $unobscure = unpack(chr(ord("a") + 19 + print ""),$unobscure);
  return $unobscure;
}

sub encode_base64 {
  my $s = shift;
  my $r = '';
  while( $s =~ /(.{1,45})/gs ){
    chop( $r .= substr(pack("u",$1),1) );
  }
  my $pad=(3-length($s)%3)%3;
  $r =~ tr|` -_|AA-Za-z0-9+/|;
  $r=~s/.{$pad}$/"="x$pad/e if $pad;
  $r=~s/(.{1,72})/$1\n/g;
  $r;
}

sub decode_base64 {
  my $d = shift;
  $d =~ tr!A-Za-z0-9+/!!cd;
  $d =~ s/=+$//;
  $d =~ tr!A-Za-z0-9+/! -_!;
  my $r = '';
  while( $d =~ /(.{1,60})/gs ){
    my $len = chr(32 + length($1)*3/4);
    $r .= unpack("u", $len . $1 );
  }
  $r;
}

# MAIN

# Load cache from file
if ( -r $cacheFile ) {
  if($debug) { message("Read cache file $cacheFile."); };
  $cache = retrieve($cacheFile);
} else {
  my %cache_array; $cache = \%cache_array;
}

$tzoffset = &tzoffset();

$now = time;
$data->{'IntervalEndTime'} = $now;
$netapp{timestamp} = $now;
if (! $cache->{statscleaned}) {
  $netapp{'statscleaned'} = $now;
  $cache->{'statscleaned'} = $now;
} else {
  $netapp{'statscleaned'} = $cache->{'statscleaned'};
}
$data->{'Interval'} = 300;
if ($cache->{timestamp}) {
  $data->{'Interval'} = $now - $cache->{timestamp};
}

my $apiport = 80;
if (defined $ENV{NA_PORT_API}) {
  $apiport = $ENV{NA_PORT_API};
}

my $apiproto = "http";
if (defined $ENV{NA_PROTO_API} && $ENV{NA_PROTO_API}) {
  $apiproto .= "s";   # set HTTPS
}

if (defined $ENV{NA_IP}) {
  $storip = $ENV{NA_IP};
  $filer = "$storip:$apiport";
} else {
  error("naperf.pl: NetApp hostname/IP required.\n");
  exit(1);
}

my $user = '';
my $pass = '';

if (defined $ENV{NA_USER}) {
  $user = "$ENV{NA_USER}";
} else {
  error("naperf.pl: NetApp API username required.\n");
  exit(1);
}

if (defined $ENV{NA_PASSWD}) {
  $pass = unobscure_password("$ENV{NA_PASSWD}");
} else {
  error("naperf.pl: NetApp API password required.\n");
  exit(1);
}

my $cur_sampleid = $cntr_prefix . $netapp{timestamp};

if ($stormode eq "7MODE") {
  # 7-mode
  message("HOSTNAME: $hostname,  STATS PREFIX: $cntr_prefix,  NETAPP MODE: 7-mode");

  #my $objects = "system ifnet";   # take all counters from this objects
  #$objects .= " " . join " ", map {"volume:*:" . $_} @volcounters;
  #$objects .= " " . join " ", map {"aggregate:*:" . $_} @aggcounters;
  #$objects .= " " . join " ", map {"disk:*:" . $_} @dskcounters;
  #$objects .= " " . join " ", map {"hostadapter:*:" . $_} @hacounters;
  #$objects .= " " . join " ", map {"lun:*:" . $_} @luncounters;

  my $objects = "system ifnet volume aggregate disk hostadapter lun";   # take all counters from this objects

  if ( ($now - $cache->{statscleaned}) < 86400 ) {
    my $collectStart = `$ssh $user\@$storip "stats start -I $cur_sampleid $objects" 2>&1`;
    chomp $collectStart;
    if ($collectStart) {
      &error("Statistics collection failed to start: $collectStart");
      exit(1);
    } else {
      &message("Statistics collection is being started for sample-id: $cur_sampleid");
    }
  }
  # &message("Command: stats start -I $cur_sampleid $objects");

  if ($cache->{timestamp}) {
    my $old_sampleid = $cntr_prefix . $cache->{timestamp};
    my @collectedData = `$ssh $user\@$storip "stats stop -I $old_sampleid"`;
    my $collectedLines = scalar @collectedData;
    &message("Statistics collection is being stopped for sample-id: $old_sampleid ($collectedLines lines collected)");
    $statsFile = "stats-$storname-" . epoch2isotime($cache->{timestamp}, $tzoffset);
    # store(\@collectedData, $statsFile . ".txt");
    foreach my $line (@collectedData) {
      chomp $line;
      if (length($line) > 5) {
        my @spline;
        if ($line =~ "\.<[0-9]") {
          next;
        }
        if ($line =~ "^disk") {
          if ($line !~ "instance_name") {
            @spline = $line =~ /([^:]+):(.*):(.*):(.*)/;
          } else {
            next;
          }
        } else {
          #print $line . "\n";
          @spline = split(":", $line, 4);
        }
        if ($spline[0] ne "StatisticsID") {
          $netapp{$spline[0]}{$spline[1]}{$spline[2]} = $spline[3];
        } else {
          $netapp{$spline[0]} = $spline[1];
        }
      }
    }
    #foreach my $diskid (keys %{ $netapp{disk} }) {
      #my $diskname = $netapp{disk}{$diskid}{display_name};
      #$netapp{disk}{$diskname} = delete $netapp{disk}{$diskid};
    #}
    foreach my $lun (keys %{ $netapp{lun} }) {
      my $lunname = $netapp{lun}{$lun}{display_name};
      $netapp{lun}{$lunname} = delete $netapp{lun}{$lun};
    }
    if ( ($now - $cache->{statscleaned}) >= 86400 ) {
      my $collectWipe = `$ssh $user\@$storip "stats stop -a" 2>&1`;
      chomp $collectWipe;
      $netapp{statscleaned} = $now;
      if ($collectWipe =~ "No background stats") {
        &message("Samples cleanup not needed: $collectWipe");
        # exit(1);
      } else {
        &message("All background runs will be stopped.");
      }
      my $collectStart = `$ssh $user\@$storip "stats start -I $cur_sampleid $objects" 2>&1`;
      chomp $collectStart;
      if ($collectStart) {
        &error("Statistics collection failed to start: $collectStart");
        exit(1);
      } else {
        &message("Statistics collection is being started for sample-id: $cur_sampleid");
      }
    }

    # store(\%coll, $statsFile . ".hsh");
    # file_write($statsFile . ".dump", Dumper \%netapp);
    # my $collectWipe = `ssh $storname "set -privilege advanced -confirmations off; statistics samples delete -sample-id $cache->{timestamp}"`;
    # &message($collectWipe);
  }

  ############## API part <<<<<<<<<<<<<<<<
  my $API = 'servlets/netapp.servlets.admin.XMLrequest_filer';
  my $url = "$apiproto://$filer/$API";
  &message ("URL: $url");

  my $xml_request = "<?xml version='1.0' encoding='utf-8'?>
  <!DOCTYPE netapp SYSTEM 'file:/etc/netapp_filer.dtd'>

  <netapp xmlns='http://www.netapp.com/filer/admin'><volume-list-info/><aggr-list-info/><disk-list-info/><lun-list-info/>

  </netapp>";


  my $agent = LWP::UserAgent->new(
  ssl_opts => {
  verify_hostname => 0
  }
  );

  my $request = HTTP::Request->new( POST => $url );
  $request->content( $xml_request );
  $request->authorization_basic( $user, $pass );

  my $results = $agent->request($request);

  if ( ! $results->is_success ) {
    error ("Request error: $results->status_line");
    die;
  }

  my $xml = XMLin($results->content);
  my $vols = $xml->{results}[0]{'volumes'}{'volume-info'};
  my $aggs = $xml->{results}[1]{'aggregates'}{'aggr-info'};
  my $dsks = $xml->{results}[2]{'disk-details'}{'disk-detail-info'};
  my $luns = $xml->{results}[3]{'luns'}{'lun-info'};

  # print Dumper @luns;
  my %hluns;
  if (ref($luns) eq 'HASH') {
    my $lunname = $luns->{path};
    $hluns{$lunname} =  $luns;
  } else { 
    foreach my $lun (@{$luns}) {
      #print Dumper $lun;
      my $lunname = $lun->{path};
      $hluns{$lunname} =  $lun;
    }
  }
  # print "XXXX hluns  " .  Dumper \%hluns;
  
  my %na;
  $na{volume} = $vols;
  $na{aggregate} = $aggs;
  $na{disk} = $dsks;
  $na{lun} = \%hluns;

  #@{$netapp{volume}}{ keys %{$na{volume}} } = values %{$na{volume}};
  #@{$netapp{aggregate}}{ keys %{$na{aggregate}} } = values %{$na{aggregate}};
  #@{$netapp{disk}}{ keys %{$na{disk}} } = values %{$na{disk}};

  if (exists $na{volume}{uuid}) {
    my $key = $na{volume}{name};
    foreach my $key1 (keys %{ $na{volume} }) {
      $netapp{volume}{$key}{$key1} = trim($na{volume}{$key1});
    }
  } else {
    foreach my $key (keys %{ $na{volume} }) {
      foreach my $key1 (keys %{ $na{volume}{$key} }) {
        $netapp{volume}{$key}{$key1} = trim($na{volume}{$key}{$key1});
      }
    }
  }

  foreach my $key (keys %{ $netapp{aggregate} }) {
    foreach my $key1 (keys %{ $na{aggregate}{$key} }) {
      $netapp{aggregate}{$key}{$key1} = trim($na{aggregate}{$key}{$key1});
    }
  }
  foreach my $key (keys %{ $netapp{disk} }) {
    foreach my $key1 (keys %{ $na{disk}{$key} }) {
      $netapp{disk}{$key}{$key1} = trim($na{disk}{$key}{$key1});
    }
  }
  # print "XXXX netapp " .  Dumper $netapp{lun};
  # print "XXXX na     " .  Dumper $na{lun};
  foreach my $key (keys %{ $netapp{lun} }) {
    foreach my $key1 (keys %{ $na{lun}{$key} }) {
      $netapp{lun}{$key}{$key1} = trim($na{lun}{$key}{$key1});
    }
  }

  ############## API part >>>>>>>>>>>>>>>>
  file_write($statsFile . ".dump", Dumper \%netapp) if $debug_full;


} elsif ($stormode eq "CMODE") {
  # C-mode
  message("HOSTNAME: $hostname,  STATS PREFIX: $cntr_prefix,  NETAPP MODE: C-mode");

  ############## API part <<<<<<<<<<<<<<<<
  my $API = 'servlets/netapp.servlets.admin.XMLrequest_filer';
  my $url = "$apiproto://$filer/$API";
  my $volxml = "
  <volume-get-iter>
    <max-records>10000</max-records>
    <desired-attributes>
      <volume-attributes>
        <volume-id-attributes>
          <uuid />
          <name />
          <containing-aggregate-uuid />
          <containing-aggregate-name />
          <owning-vserver-uuid />
          <owning-vserver-name />
          <node />
          <reserve-used />
          <reserve />
          <disk-count />
          <instance-uuid />
          <style />
          <space-reserve-enabled />
          <raid-size />
        </volume-id-attributes>
        <volume-inode-attributes>
          <files-used />
          <files-total />
        </volume-inode-attributes>
        <volume-space-attributes>
          <filesystem-size />
          <size-total />
          <size-available />
          <size-used />
          <percentage-size-used />
          <percentage-snapshot-reserve />
        </volume-space-attributes>
        <volume-state-attributes>
          <state />
        </volume-state-attributes>
      </volume-attributes>
    </desired-attributes>
  </volume-get-iter>
  ";

  my $aggxml = "
  <aggr-get-iter max-records='1'>
    <desired-attributes>
      <aggr-attributes>
        <aggr-space-attributes>
          <size-total />
          <size-used />
        </aggr-space-attributes>
        <aggregate-uuid />
      </aggr-attributes>
    </desired-attributes>
  </aggr-get-iter>
  ";

  my $dskxml = "
  <storage-disk-get-iter>
    <max-records>10000</max-records>
    <desired-attributes>
      <storage-disk-info>
        <disk-inventory-info>
          <disk-type />
          <model />
          <capacity-sectors />
          <serial-number />
          <vendor />
          <disk-uid />
        </disk-inventory-info>
        <disk-ownership-info>
        </disk-ownership-info>
        <disk-paths>
          <disk-path-info>
            <disk-port-name />
            <node />
          </disk-path-info>
        </disk-paths>
        <disk-raid-info />
      </storage-disk-info>
    </desired-attributes>
  </storage-disk-get-iter>
  ";

  my $emsxml = "
  <ems-message-get-iter>
    <max-records>10</max-records>
    <desired-attributes>
      <ems-message-info>
        <source />
        <time />
        <node />
        <event />
        <seq-num />
        <severity />
      </ems-message-info>
    </desired-attributes>
    <query>
      <ems-message-info>
        <severity>emergency | alert | critical | error | warning</severity>
      </ems-message-info>
    </query>
  </ems-message-get-iter>
  ";

  my $xml_request = "<?xml version='1.0' encoding='utf-8'?>
  <!DOCTYPE netapp SYSTEM 'file:/etc/netapp_filer.dtd'>
  <netapp xmlns='http://www.netapp.com/filer/admin' version='1.10'>

  $volxml
  $aggxml
  $dskxml
  $emsxml

  </netapp>";


  my $agent = LWP::UserAgent->new(
      ssl_opts => {
          verify_hostname => 0
      }
  );

  my $request = HTTP::Request->new( POST => $url );
  $request->content( $xml_request );
  $request->authorization_basic( $user, $pass );

# print Dumper $request;

  my $results = $agent->request($request);

# print Dumper $results;

  if ( ! $results->is_success ) {
      error("Request error: $results->status_line");
      die;
  }

  my $xml = XMLin($results->content);
  # print Dumper $xml;
  #$xml = $xml->{results};
  my $vols = $xml->{results}[0]{'attributes-list'}{'volume-attributes'};
  my $aggs = $xml->{results}[1]{'attributes-list'}{'aggr-attributes'};
  my $dsks = $xml->{results}[2]{'attributes-list'}{'storage-disk-info'};

  if (ref($vols) eq 'ARRAY') {
    foreach my $item (@{$vols}) {
      # print Dumper $item;
      my $id = $item->{'volume-id-attributes'};
      my $sz = $item->{'volume-space-attributes'};
      my $st = $item->{'volume-state-attributes'};
      my $in = $item->{'volume-inode-attributes'};
      # print Dumper $id;
      if ($id->{'name'}) {
        my $key = $netapp{volume}{$id->{'name'}};
        $netapp{volume}{$id->{'name'}}{'uuid'} = $id->{'uuid'};
        $netapp{volume}{$id->{'name'}}{'containing-aggregate-uuid'} = $id->{'containing-aggregate-uuid'};
        $netapp{volume}{$id->{'name'}}{'containing-aggregate'} = $id->{'containing-aggregate-name'};
        $netapp{volume}{$id->{'name'}}{'owning-vserver-uuid'} = $id->{'owning-vserver-uuid'};
        $netapp{volume}{$id->{'name'}}{'owning-vserver-name'} = $id->{'owning-vserver-name'};
        $netapp{volume}{$id->{'name'}}{'type'} = $id->{'style'};
        $netapp{volume}{$id->{'name'}}{'instance-uuid'} = $id->{'instance-uuid'};
        $netapp{volume}{$id->{'name'}}{'state'} = $st->{'state'};
        $netapp{volume}{$id->{'name'}}{'size-total'} = $sz->{'size-total'};
        $netapp{volume}{$id->{'name'}}{'size-available'} = $sz->{'size-available'};
        $netapp{volume}{$id->{'name'}}{'filesystem-size'} = $sz->{'filesystem-size'};
        $netapp{volume}{$id->{'name'}}{'percentage-used'} = $sz->{'percentage-size-used'};
        $netapp{volume}{$id->{'name'}}{'size-used'} = $sz->{'size-used'};
        $netapp{volume}{$id->{'name'}}{'files-used'} = $in->{'files-used'};
        $netapp{volume}{$id->{'name'}}{'files-total'} = $in->{'files-total'};
        $netapp{volume}{$id->{'name'}}{'snapshot-percent-reserved'} = $sz->{'percentage-snapshot-reserve'};
      }
    }
  }

  if (ref($aggs) eq 'ARRAY') {
    foreach my $item (@{$aggs}) {
      # print Dumper $item;
      my $sz = $item->{'aggr-space-attributes'};
      # print Dumper $id;
      if ($item->{'aggregate-name'}) {
        $netapp{aggregate}{$item->{'aggregate-name'}}{size} = $sz->{'size-total'};
        $netapp{aggregate}{$item->{'aggregate-name'}}{used} = $sz->{'size-used'};
        $netapp{aggregate}{$item->{'aggregate-name'}}{uuid} = $item->{'aggregate-uuid'};
      }
    }
  }

  if (ref($dsks) eq 'ARRAY') {
    foreach my $item (@{$dsks}) {
      # print Dumper $item;
      my $inv = $item->{'disk-inventory-info'};
      my $raid = $item->{'disk-raid-info'};
      my $path = $item->{'disk-disk-paths'};
      my $name = $item->{'disk-name'};
      my $uid = $item->{'disk-uid'};
      my $sectsize = $inv->{'bytes-per-sector'};
      $sectsize ||= 512;

      if ($raid->{'container-type'} ne 'unassigned') {
        $netapp{disk}{$name}{'disk-model'} = $inv->{'model'};
        $netapp{disk}{$name}{'disk-type'} = $inv->{'disk-type'};
        $netapp{disk}{$name}{'vendor-id'} = $inv->{'vendor'};
        $netapp{disk}{$name}{'serial-number'} = $inv->{'serial-number'};
        $netapp{disk}{$name}{'disk-uid'} = $uid;
        $netapp{disk}{$name}{'physical-space'} = $raid->{'physical-blocks'} * $sectsize;
        $netapp{disk}{$name}{'used-space'} = $raid->{'used-blocks'} * $sectsize;
        $netapp{disk}{$name}{'used-blocks'} = $raid->{'used-blocks'};
        $netapp{disk}{$name}{'effective-disk-type'} = $raid->{'effective-disk-type'};
        $netapp{disk}{$name}{'aggregate'} = $raid->{'disk-aggregate-info'}{'aggregate-name'};
        $netapp{disk}{$name}{'raid-group'} = $raid->{'disk-aggregate-info'}{'raid-group-name'};
        $netapp{disk}{$name}{'plex'} = $raid->{'disk-aggregate-info'}{'plex-name'};
        $netapp{disk}{$name}{'node'} = $raid->{'active-node-name'};
        $netapp{disk}{$name}{'pool'} = $raid->{'spare-pool'};
      }
    }
  }


  # print Dumper $netapp{disk};
  # print Dumper $vols;
  # print Dumper $aggs;
  # print Dumper $dsks;
  ############## API part >>>>>>>>>>>>>>>>

  my $objects = "system|lun|disk|volume|aggregate|hostadapter|lif";
  my $counters = "read_ops|read_data|read_latency|write_ops|write_data|write_latency|other_ops|other_latency|total_ops|avg_latency|total_transfers|user_reads|user_writes|user_read_blocks|user_write_blocks|user_reads_hdd|user_reads_ssd|user_writes_hdd|user_writes_ssd|vserver_name|vserver_uuid|node_name|node_uuid";
  $counters .= "|system_id|system_model|serial_no|ontap_version";  # system counters
  $counters .= "|user_read_latency|user_write_latency";  # disk counters
  $counters .= "|total_reads|total_writes|bytes_read|bytes_written|rscn_count"; # hostadapter counters
  $counters .= "|recv_data|recv_errors|recv_packet|sent_data|sent_errors|sent_packet"; # lif counters

  if ( ($now - $cache->{statscleaned}) < 3600 ) {
    my $collectStart = `$ssh $user\@$storip "set -privilege advanced -confirmations off; statistics start -object $objects -counter $counters -sample-id $cur_sampleid"`;
    chomp $collectStart;
    $collectStart = trim($collectStart);
    &message($collectStart);
  }

  if ($cache->{timestamp}) {
    my $old_sampleid = $cntr_prefix . $cache->{timestamp};
    my $collectStop = `$ssh $user\@$storip "set -privilege advanced -confirmations off; statistics stop -sample-id $old_sampleid"`;
    chomp $collectStop;
    $collectStop = trim($collectStop);
    &message($collectStop);
    my @collectedData = `$ssh $user\@$storip "set -privilege advanced -confirmations off -showallfields true -showseparator :: -units KB -rows 0; statistics show -sample-id $old_sampleid"`;
    my $statsFile = "stats-$storname-" . epoch2isotime($cache->{timestamp}, $tzoffset);
    # store(\@collectedData, $statsFile . ".txt");
    foreach my $line (@collectedData) {
      chomp $line;
      if (length($line) > 6) {
        # print $line . "\n";
        my @spline = split("::", $line);
        if (lc $spline[0] ne "object") {
          $netapp{$spline[0]}{$spline[1]}{$spline[2]} = $spline[4];
        }
      }
    }
    file_write($statsFile . ".dump", Dumper \%netapp) if $debug_full;
    # print Dumper \%coll;
    sleep (2);
    if ( ($now - $cache->{statscleaned}) >= 3600 ) {
      my $collectWipe = `$ssh $user\@$storip "set -privilege advanced -confirmations off; statistics samples delete -sample-id $cntr_prefix*"`;
      chomp $collectWipe;
      $collectWipe = trim($collectWipe);
      &message($collectWipe);
      $netapp{statscleaned} = $now;
      my $collectStart = `$ssh $user\@$storip "set -privilege advanced -confirmations off; statistics start -object $objects -counter $counters -sample-id $cur_sampleid"`;
      chomp $collectStart;
      $collectStart = trim($collectStart);
      &message($collectStart);
    } else {
      my $collectWipe = `$ssh $user\@$storip "set -privilege advanced -confirmations off; statistics samples delete -sample-id $old_sampleid"`;
      chomp $collectWipe;
      $collectWipe = trim($collectWipe);
      &message($collectWipe);
    }
  }
}
# print Dumper \%netapp;

&message("Storing latest data to $cacheFile");
store(\%netapp, $cacheFile);

&message("Starting to create conf & perf files...");
&writeStats("volume");
&writeStats("pool");
&writeStats("disk");
&writeStats("lun");
&writeStats("ha");
&writeStats("if");
&writeConf("system");
&writeConf("volume");
&writeConf("pool");
&writeConf("disk");
&writeConf("lun");
&writeConf("ha");
&writeConf("if");


&message("Done.");
exit 0;
