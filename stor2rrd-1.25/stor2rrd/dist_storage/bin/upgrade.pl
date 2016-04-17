#!/usr/bin/perl

use strict;
use warnings;
use CGI::Carp qw(fatalsToBrowser);
# use Data::Dumper;

my $inputdir = $ENV{INPUTDIR} ||= "";
my $cfgdir   = "$inputdir/etc/web_config";
my $perl = $ENV{PERL};
my %cfg;

# get URL parameters (could be GET or POST) and put them into hash %PAR
my ($buffer, @pairs, $pair, $name, $value, %PAR);

if (defined $ENV{'CONTENT_TYPE'} && $ENV{'CONTENT_TYPE'} =~ "multipart/form-data") {
  print "Content-type: application/json\n\n";
  require CGI;
  my $cgi = new CGI;
  # print Dumper $cgi;
  my $file = $cgi->param('upgfile');

  if ($file) {
    # if (length($file) <= 50000000) {
    if (0) {
      &result(0, "File is too small, it cannot be VMware SDK for Perl.");
    } else {
      my $tmpfilename = $cgi->tmpFileName($file);
      rename $tmpfilename, "/tmp/$file";
      chmod 0664, "/tmp/$file";
      my $udir = (split /\.tar/, $file)[0];
      my $txt = `cd /tmp; tar xf /tmp/$file`;
      if (! -f "/tmp/$udir/scripts/update.sh") {
        &result(0, "This file doesn't look like the upgrade package");
      } else {
        $txt = `cd /tmp/$udir; scripts/update.sh`;
        if ($? == 0) {
          &result(1, "Upgrade succesfully installed, now <button id='run-data-load'>run data load</button>.<br>Don't forget to refresh your browser (Ctrl-F5)", "<pre>$txt</pre>");
        } else {
          &result(0, "Upgrade install failed", "<pre>$txt</pre>");
      }
    }
    }
  } else {
    &result(0, "No file uploaded", $file);
  }
  exit;
}

if (! defined $ENV{'REQUEST_METHOD'}) {
  print "Content-type: text/plain\n\n";
  print "No command specified, exiting...\n";
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

# print $call , "\n";


# print Dumper \%PAR;

if ($PAR{cmd} eq "form") {  ### Generate upload form
  print "Content-type: text/html\n\n";
  print "<p>You can use this form to upgrade or patch running installation.<p>";
  if ($ENV{VM_IMAGE}) {
    print <<_MARKER_;
    <p>Please download upgrade / patch from <a href='http://www.stor2rrd.com' target="blank"><b>STOR2RRD</b></a> website to your computer and then upload it to the running appliance via following form:<br>
    <form id="upgrade-form" action="/stor2rrd-cgi/upgrade.sh" method="post" enctype="multipart/form-data">
    <p>File to Upload: <input type="file" accept=".tar" name="upgfile"></p>
    <p><input type="submit" id="sdk-upload" name="Submit" value="Upload file" /></p>
    <div class="progress">
      <div class="bar"></div >
      <div class="percent">0%</div >
    </div>
    </form>
  <div id="status"></div>
_MARKER_
  } else {
    print "<p>This feature is only active when running as VMware appliance. <a href='http://www.stor2rrd.com/LPAR2RRD_and_STOR2RRD_Virtual_Appliance.htm'>More info...</a></p>";
  }
} elsif ($PAR{cmd} eq "load") {   ### run load.sh and show what to do next
  print "Content-type: application/json\n\n";
  if (system("nohup $inputdir/load.sh > $inputdir/logs/load.out 2>&1 &") == -1) {
    &result(0, "Couldn't exec load.sh ($!).");
  } else {
    my $txt = "Data load has been launched!\n It could take very long (up to 30 minutes) depending on your infrastructure size.\n";
    &result(1, $txt);
  }
}


sub result {
  my ($status, $msg, $log) = @_;
  $log ||= "";
  $msg =~ s/\n/\\n/g;
  $msg =~ s/\\:/\\\\:/g;
  $log =~ s/\n/\\n/g;
  $log =~ s/\\:/\\\\:/g;
  $log =~ s/\"/\\\"/g;
  $status = ($status) ? "true" : "false";
  print "{ \"success\": $status, \"message\" : \"$msg\", \"log\": \"$log\"}";
}
