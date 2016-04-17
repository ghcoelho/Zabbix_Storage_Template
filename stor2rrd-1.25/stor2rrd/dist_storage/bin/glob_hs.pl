#!/usr/bin/perl

use strict;
use warnings;

my $tmpdir   = $ENV{TMPDIR_STOR};
my $act_time = time();

if ( ! -d "$tmpdir/health_status_summary" ) {
  error( "$tmpdir/health_status_summary not exist! $!" . __FILE__ . ":" . __LINE__ ) && exit;
}

my @items = <$tmpdir/health_status_summary/*>;

my @storages;
my @switches;

foreach my $file (@items) {
  chomp $file;

  open( FILE, "<$file" ) || error( "Couldn't open file $file $!" . __FILE__ . ":" . __LINE__ ) && exit;
  my $component_line = <FILE>;
  close(FILE);

  my ( $type, $name, $status, $log_time, $reason ) = split(" : ",$component_line);

  # test disabled HW
  my $time_diff = $act_time - $log_time;
  if ( $time_diff > 604800 ) { next; }

  my $st;
  my $red_st   = "background=\"css/images/status_red.png\"";
  my $green_st = "background=\"css/images/status_green.png\"";

  if ( $status eq "OK" )     { $st = $green_st; }
  if ( $status eq "NOT_OK" ) { $st = $red_st; }

  my $line = "<tr><td $st width=\"20px\" height=\"20px\" nowrap=\"\">&nbsp;</td><td height=\"20px\"><a href=\"$name/health_status.html\"><b>$name</b></a></td><td><td></tr>";
  if ( defined $reason && $reason ne '' ) {
    $line = "<tr><td $st width=\"20px\" height=\"20px\" nowrap=\"\">&nbsp;</td><td height=\"20px\"><a href=\"$name/health_status.html\"><b>$name</b></a></td><td>$reason</td></tr>";
  }

  if ( $type eq "STORAGE" )    { push(@storages, "$line\n"); }
  if ( $type eq "SAN-SWITCH" ) { push(@switches, "$line\n"); }
}

print "Content-type: text/html\n\n";

print <<_MARKER_;
<br><br><br>
<center>
<table class="glob_health_state">
  <tr>
    <td colspan="2"><font color="#003399"><b>STORAGES:</b></td>
  </tr>
  @storages
  <tr></tr>
  <tr>
    <td colspan="2"><font color="#003399"><b>SWITCHES:</b></td>
  </tr>
  @switches
</table>
</center>
_MARKER_

### ERROR HANDLING
sub error {
  my $text     = shift;
  my $act_time = localtime();
  chomp($text);
  print STDERR "$act_time: $text : $!\n";
  return 1;
}
