#!/usr/bin/perl

use strict;
use warnings;
use SNMP;
use Socket;

my $san_ip;
my $san_type;
my $basedir = $ENV{INPUTDIR};

# important variables
if ( defined $ENV{SAN_IP} && $ENV{SAN_IP} ne '' ) {
  $san_ip = $ENV{SAN_IP};
}
else {
  error( "SAN IP is required! $!" . __FILE__ . ":" . __LINE__ ) && exit 0;
}
if ( defined $ENV{SAN_TYPE} && $ENV{SAN_TYPE} ne '' ) {
  if ( $ENV{SAN_TYPE} eq "BRCD" || $ENV{SAN_TYPE} eq "CISCO" ) {
    $san_type = $ENV{SAN_TYPE};
  }
  else {
    error( "Unknown SAN type! Must be \"BRCD\" or \"CISCO\"!  $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }
}
else {
  error( "SAN TYPE is required! <BRCD|CISCO> $!" . __FILE__ . ":" . __LINE__ ) && exit;
}


my $dest       = $san_ip;
my $comm       = 'public';
my $mib        = 'sysDescr';
my $sver       = '';
my $timeout    = '5000000';
my $SecName    = "snmpuser1";
my $RemotePort = "";

# SNMP option
if ( $san_type eq "BRCD" ) {
  $sver = '1';
  if ( defined $ENV{SNMP_VERSION} && $ENV{SNMP_VERSION} ne '' ) {
    if ( $ENV{SNMP_VERSION} == 1 || $ENV{SNMP_VERSION} == 3 || $ENV{SNMP_VERSION} eq "2c" ) {
      $sver = $ENV{SNMP_VERSION};
    }
    else {
      error( "Unknown SNMP version in etc/san-list.cfg! Automatically used SNMP version \"$sver\"! $!" . __FILE__ . ":" . __LINE__ );
    }
  }
}
if ( $san_type eq "CISCO" ) {
  $sver = '2c';
  if ( defined $ENV{SNMP_VERSION} && $ENV{SNMP_VERSION} ne '' ) {
    if ( $ENV{SNMP_VERSION} == 3 || $ENV{SNMP_VERSION} eq "2c" ) {
      $sver = $ENV{SNMP_VERSION};
    }
    else {
      error( "Unknown SNMP version in etc/san-list.cfg! Automatically used SNMP version \"$sver\"! $!" . __FILE__ . ":" . __LINE__ );
    }
  }
}
if ( defined $ENV{SNMP_PORT} && $ENV{SNMP_PORT} ne '' ) {
  $RemotePort = $ENV{SNMP_PORT};
  if ( ! isdigit($RemotePort) ) {
    error( "SNMP port \"$RemotePort\" is not digit! Automatically used SNMP default port \"161\"! $!" . __FILE__ . ":" . __LINE__ );
    $RemotePort = "";
  }
  my $snmp_port_length = length $RemotePort;
  if ( isdigit($snmp_port_length) && $snmp_port_length > 5 ) {
    error( "SNMP port \"$RemotePort\" length is greater then 5! Automatically used SNMP default port \"161\"! $!" . __FILE__ . ":" . __LINE__ );
    $RemotePort = "";
  }
}


if ( -f "$basedir/etc/san-list.cfg") {
  open( SL, "<$basedir/etc/san-list.cfg" ) || error( "Couldn't open file $basedir/etc/san-list.cfg $!" . __FILE__ . ":" . __LINE__ );
  my @san_cfg = <SL>;
  close(SL);
  my ($line) = grep {/^$san_ip:/} @san_cfg;
  chomp $line;
  my (undef, $comm_st, undef, undef) = split(":",$line);
  if ( defined $comm_st && $comm_st ne "" ) {
    chomp $comm_st;
    $comm = $comm_st;
  }
  if ( defined $comm_st && $comm_st ne "" && $sver eq 3 ) {
    chomp $comm_st;
    $SecName = $comm_st;
  }
}

print "Type         : $san_type\n";
print "DestHost     : $dest\n";
print "Version SNMP : $sver\n";
if ( $sver eq 3 ) {
  print "SecName      : $SecName\n";
}
else {
  print "Community    : $comm\n";
}

if ( defined $RemotePort && $RemotePort ne '' ) {
  print "Community    : $comm\n";
  print "SNMP port    : $RemotePort\n";
}
else {
  print "SNMP port    : not defined! Used SNMP default port \"161\"!\n";

}


my $state = try_connect();
if ( $state == 1) {
  print "STATE        : CONNECTED!\n";
}
else {
  print "STATE        : NOT CONNECTED!\n";
}

sub try_connect {
  my $sess; # The SNMP::Session object that does the work.
  my $var;  # Used to hold the individual responses.
  my $vb;   # The Varbind object used for the 'real' query.

  my %snmpparms;

  # Initialize the MIB (else you can't do queries).
  &SNMP::addMibDirs("$basedir/MIBs/");
  &SNMP::loadModules('SW-MIB' , 'Brocade-REG-MIB' , 'Brocade-TC' , 'FCMGMT-MIB' , 'FCMGMT-MIB' , 'CISCO-FC-FE-MIB', 'CISCO-DM-MIB' , 'FA-EXT-MIB');
  &SNMP::initMib();

  $snmpparms{Community}      = $comm;
  $snmpparms{DestHost}       = inet_ntoa(inet_aton($dest));
  $snmpparms{Version}        = $sver;
  $snmpparms{Timeout}        = $timeout;
  $snmpparms{UseSprintValue} = '1';
  $snmpparms{SecName}        = $SecName;

  if ( defined $RemotePort && $RemotePort ne '' ) {
    $snmpparms{RemotePort} = $RemotePort;
  }


  $sess = new SNMP::Session(%snmpparms);

  # Turn the MIB object into something we can actually use.
  $vb = new SNMP::Varbind([$mib,'0']); # '0' is the instance.

  $var = $sess->get($vb); # Get exactly what we asked for.
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # sysName
  #
  $mib = 'sysName'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {
    $var =~ s/"//g;
    print "Switch name  : $var\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  return 1;
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

