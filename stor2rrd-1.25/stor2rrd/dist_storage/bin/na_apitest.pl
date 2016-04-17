#!/usr/bin/perl
# vim: set filetype=perl :

# Modules
use strict;
use warnings;
use Data::Dumper;
use POSIX qw(strftime);
use LWP::UserAgent;
use HTTP::Request;
use Sys::Hostname;

my $hostname = hostname;


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
my $storage;
my $cache;
my $data;
my $config;
my $tzoffset;

sub message {
  my $msg = shift;
  my $tm = localtime();
  print("  INFO ".$tm." naperf.pl: ".$msg."\n");
}

sub warning {
  my ($msg,$rc) = @_;
  my $tm = localtime();
  print STDERR ("  WARNING ".$tm." naperf.pl: ".$msg."\n");
}

sub error {
  my ($msg,$rc) = @_;
  my $tm = localtime();
  print STDERR ("  ERROR ".$tm." naperf.pl: ".$msg."\n");
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

if ($stormode eq "7MODE") {
  # 7-mode
  message("HOSTNAME: $hostname, NETAPP MODE: 7-mode");

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
    error ("API Test failed: $results->{_msg}");
  } else {
    message("API Connection result: $results->{_msg}");
  }
} elsif ($stormode eq "CMODE") {
  # C-mode
  message("HOSTNAME: $hostname, NETAPP MODE: C-mode");

  ############## API part <<<<<<<<<<<<<<<<
  my $API = 'servlets/netapp.servlets.admin.XMLrequest_filer';
  my $url = "$apiproto://$filer/$API";
  &message ("URL: $url");

  my $xml_request = "<?xml version='1.0' encoding='utf-8'?>
  <!DOCTYPE netapp SYSTEM 'file:/etc/netapp_filer.dtd'>
  <netapp xmlns='http://www.netapp.com/filer/admin' version='1.10'>

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
    error("API test failed: $results->{_msg}");
  } else {
    message("API Connection result: $results->{_msg}");
  }
}
# print Dumper \%netapp;

exit 0;
