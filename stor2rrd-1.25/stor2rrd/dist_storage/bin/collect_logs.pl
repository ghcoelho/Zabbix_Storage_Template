#!/usr/bin/perl

use strict;
use warnings;
# use Data::Dumper;

my $inputdir = $ENV{INPUTDIR} ||= "";
my $cfgdir   = "$inputdir/etc/web_config";
my $perl = $ENV{PERL};
my %cfg;

# get URL parameters (could be GET or POST) and put them into hash %PAR
my ($buffer, @pairs, $pair, $name, $value, %PAR);

if (! defined $ENV{'REQUEST_METHOD'}) {
  print "Content-type: text/plain\n\n";
  print "No command specified, exiting...";
  exit;
}

if (lc $ENV{'REQUEST_METHOD'} eq "post") {
  read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
} else {
  $buffer = $ENV{'QUERY_STRING'};
}

# Split information into name/value pairs
@pairs = split(/&/, $buffer);
foreach $pair (@pairs) {
  ($name, $value) = split(/=/, $pair);
  $value =~ tr/+/ /;
  $value =~ s/%(..)/pack("C", hex($1))/eg;
  $PAR{$name} = $value;
}

# print Dumper \%PAR;

if ($PAR{cmd} eq "page") {  ### Get list of credentials
	print "Content-type: text/html\n\n";

print <<_MARKER_;
<p>In case of problems, <button id="collect-logs">collect logs</button> and send us that file via our <a href="https://upload.stor2rrd.com">secured upload service</a>.</p>
<p>Customers under support can freely use that services in case of any problems with the tool.</p>
_MARKER_
if ($ENV{VM_IMAGE}) {
  print '<li><b><a href="?menu=96e9a0f&tab=3">Apache error</a></b>: web server error log</li>';
}
print "</ul></p>";

} elsif ($PAR{cmd} eq "logs") {   ### collect logs and send them to browser for saving
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  my $now = sprintf("%04d%02d%02d-%02d%02d%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
  my $call = `cd $inputdir; tar chf - logs etc tmp/*txt | gzip > /tmp/logs-$now.tar.gz `;
  if ( $? == -1 ) {
    print "Content-type: application/json\n\n";
    &result(0, "command failed: $!");
  } else {
    my $filename = "/tmp/logs-$now.tar.gz";
    my $length=length($filename);
    my $buffsize = 64 * (2 ** 10);
    print "Content-type: application/x-gzip\n";
    print "Cache-Control: no-cache \n";
    print "Content-Length: $length \n";
    print "Content-Disposition:attachment;filename=logs-$now.tar.gz\n\n";
    open(LOGS, "<", $filename) || die "$0: cannot open $filename for reading: $!";
    binmode(LOGS);
    binmode STDOUT;
    while (read( LOGS, $buffer, $buffsize )) {
      print $buffer;
    }
    unlink $filename;
  }
}

sub result {
  my ($status, $msg, $log) = @_;
  $log ||= "";
  $msg =~ s/\n/\\n/g;
  $msg =~ s/\\:/\\\\:/g;
  $log =~ s/\n/\\n/g;
  $log =~ s/\\:/\\\\:/g;
  $status = ($status) ? "true" : "false";
  print "{ \"success\": $status, \"message\" : \"$msg\", \"log\": \"$log\"}";
}
