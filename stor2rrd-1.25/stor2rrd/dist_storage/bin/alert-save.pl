#!/usr/bin/perl

use strict;
use warnings;
use lib "../bin";
#use Data::Dumper;
# use Custom;


print "Content-type: text/html\n\n";

my $buffer;
read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
$buffer = (split(/=/, $buffer))[1];
$buffer = &urldecode($buffer);

my $basedir = $ENV{INPUTDIR};
$basedir ||= "..";

my $cfgdir = "$basedir/etc/web_config";

my $tmpdir = "$basedir/tmp";
if (defined $ENV{TMPDIR_STOR}) {
  $tmpdir = $ENV{TMPDIR_STOR};
}

if ($buffer) {
  my $retstr = "";
  if ($ENV{'SERVER_NAME'} eq "demo.stor2rrd.com") {
    $buffer =~ s/\n/\\n/g;
    $buffer =~ s/\\:/\\\\:/g;
    $retstr = "\"msg\" : \"<div>This demo site does not allow saving any changes you do in the admin GUI panel.<br />";
    $retstr .= "You can only see the preview of alerting.cfg to be written.</div>\", \"cfg\" : \"";
    print "{ \"status\" : \"success\", $retstr" . "$buffer\" }";
  }
  elsif (open(CFG, ">$cfgdir/alerting.cfg")) {
    print CFG "$buffer\n";
    close CFG;
    $buffer =~ s/\n/\\n/g;
    $buffer =~ s/\\:/\\\\:/g;
    $retstr = "\"msg\" : \"<div>Alerting configuration file has been succesfuly saved!<br /><br /></div>\", \"cfg\" : \"";
    print "{ \"status\" : \"success\", $retstr" . "$buffer\" }";
  } else {
    print "{ \"status\" : \"fail\", \"msg\" : \"<div>File $cfgdir/alerting.cfg cannot be written by webserver, check apache user permissions: <span style='color: red'>$!</span></div>\" }";
  }
} else {
  print "{ \"status\" : \"fail\", \"msg\" : \"<div>No data was written to alerting.cfg</div>\" }";
}

sub urldecode {
  my $s = shift;
  $s =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
  $s =~ s/\+/ /g;
  return $s;
}
