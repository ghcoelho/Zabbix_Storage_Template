#!/usr/bin/perl

use strict;
use warnings;
use SNMP;
use Socket;
use Data::Dumper;
use Time::Local;
use RRDp;
use Xorux_lib;
use Math::BigInt;

my $san_ip;
my $san_type;
my $rrdtool        = $ENV{RRDTOOL};
my $basedir        = $ENV{INPUTDIR};
my $webdir         = $ENV{WEBDIR};
my $wrkdir         = "$basedir/data";
my $tmpdir         = "$basedir/tmp";

# important variables
if ( defined $ENV{SAN_IP} && $ENV{SAN_IP} ne '' ) {
  $san_ip = $ENV{SAN_IP};
}
else {
  error( "SAN IP is required! $!" . __FILE__ . ":" . __LINE__ ) && exit;
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


# demo
my $demo = 0;
if ( defined $ENV{DEMO} ) { $demo = $ENV{DEMO}; }


# start RRD via a pipe
RRDp::start "$rrdtool";


# BROCADE
if ( $san_type eq "BRCD" ) {
# check demo state
  if ( $demo == 0 || $demo == 1 || $demo == 2 ) {
    if ( $demo == 0 || $demo == 2 ) {
      collect_data_brcd($san_ip);
    }
    if ( $demo == 1 ) {
      # san_ip in etc/san_list must be a name of switch
      import_data_for_demo($san_ip);
    }
  }
  else {
    error( "Wrong ENV{DEMO} value in etc/.magic! DEMO value is \"$demo\"! Must be \"DEMO=0\" or \"DEMO=1\" or \"DEMO=2\"  $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }
}


# CISCO
if ( $san_type eq "CISCO" ) {
  collect_data_cisco($san_ip);
}


###########
# BROCADE #
###########

sub collect_data_brcd {

  my $dest       = shift;
  my $comm       = 'public';
  my $mib        = 'sysDescr';
  my $sver       = '1';
  my $timeout    = '50000000';
  my $SecName    = "snmpuser1";
  my $RemotePort = "";

  # SNMP option
  if ( defined $ENV{SNMP_VERSION} && $ENV{SNMP_VERSION} ne '' ) {
    if ( $ENV{SNMP_VERSION} == 1 || $ENV{SNMP_VERSION} == 3 || $ENV{SNMP_VERSION} eq "2c" ) {
      $sver = $ENV{SNMP_VERSION};
    }
    else {
      error( "Unknown SNMP version in etc/san-list.cfg! Automatically used SNMP version \"$sver\"! $!" . __FILE__ . ":" . __LINE__ );
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
    if ( defined $comm_st && $comm_st ne "" && $sver == 3 ) {
      chomp $comm_st;
      $SecName = $comm_st;
    }
  }

  my $sess; # The SNMP::Session object that does the work.
  my $var;  # Used to hold the individual responses.
  my $vb;   # The Varbind object used for the 'real' query.

  my %data_collect;
  my %snmpparms;

  #my $start_time = localtime();

  # Initialize the MIB (else you can't do queries).
  &SNMP::addMibDirs("$basedir/MIBs/");
  &SNMP::loadModules('SW-MIB' , 'Brocade-REG-MIB' , 'Brocade-TC' , 'FCMGMT-MIB' , 'FA-EXT-MIB');
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
    # Done as a block since you may not always want to die
    # in here.  You could set up another query, just go on,
    # or whatever...
  }
  $var =~ s/"//g;
  $data_collect{'configuration'}{$vb->tag} = $var;
  #print $vb->tag, ".", $vb->iid, " : $var\n";

  # Now let's show a MIB that might return multiple instances.

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
    $data_collect{'configuration'}{$vb->tag} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # swFCPortPhyState
  #
  $mib = 'swFCPortPhyState'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {
    $var =~ s/"//g;
    $data_collect{'ports'}{$vb->iid}{$vb->tag} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var, "\n";
    #print "{$vb->iid}{$vb->tag}", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # swFCPortOpStatus
  #
  $mib = 'swFCPortOpStatus'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {
    $var =~ s/"//g;
    $data_collect{'ports'}{$vb->iid}{$vb->tag} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # fcFeFabricName
  #
  $mib = '1.3.6.1.2.1.75.1.1.1'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb) ) {
    $var =~ s/"//g;
    $data_collect{'configuration'}{fcFeFabricName} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var,"\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # fcFeElementName
  #
  $mib = '1.3.6.1.2.1.75.1.1.2'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb) ) {
    $var =~ s/"//g;
    $data_collect{'configuration'}{fcFeElementName} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var,"\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }


  ### FCMGMT-MIB START ###
  #
  # connUnitPortStatCountTxElements
  #
  $mib = 'connUnitPortStatCountTxElements'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id = $vb->iid;
    $port_id =~ s/^.+\.//g;
    $var     =~ s/"//g;

    my $dec_val = hex2dec($var);
    my $num = $dec_val / 4;
    #$data_collect{'ports'}{$port_id}{$vb->tag}{hex} = $var;
    #$data_collect{'ports'}{$port_id}{$vb->tag}{dec} = $dec_val;
    $data_collect{'ports'}{$port_id}{$vb->tag} = $num;
    #print "connUnitPortStatCountTxElements = $data_collect{'ports'}{$port_id}{$vb->tag} = $dec_val, $num\n";

    #print $vb->iid, " : ", $var, "\n";
    #print $port_id, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitPortStatCountRxElements
  #
  $mib = 'connUnitPortStatCountRxElements'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id = $vb->iid;
    $port_id =~ s/^.+\.//g;
    $var     =~ s/"//g;

    my $dec_val = hex2dec($var);
    my $num = $dec_val / 4;
    #$data_collect{'ports'}{$port_id}{$vb->tag}{hex} = $var;
    #$data_collect{'ports'}{$port_id}{$vb->tag}{dec} = $dec_val;
    $data_collect{'ports'}{$port_id}{$vb->tag} = $num;
    #print "connUnitPortStatCountRxElements = $data_collect{'ports'}{$port_id}{$vb->tag} = $dec_val, $num\n";

    #print $vb->iid, " : ", $var, "\n";
    #print $port_id, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitPortStatCountTxObjects
  #
  $mib = 'connUnitPortStatCountTxObjects'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id = $vb->iid;
    $port_id =~ s/^.+\.//g;
    $var     =~ s/"//g;

    my $dec_val = hex2dec($var);
    #$data_collect{'ports'}{$port_id}{$vb->tag}{hex} = $var;
    #$data_collect{'ports'}{$port_id}{$vb->tag}{dec} = $dec_val;
    $data_collect{'ports'}{$port_id}{$vb->tag} = $dec_val;
    #print "connUnitPortStatCountTxObjects = $data_collect{'ports'}{$port_id}{$vb->tag} = $dec_val\n";

    #print $vb->iid, " : ", $var, "\n";
    #print $port_id, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitPortStatCountRxObjects
  #
  $mib = 'connUnitPortStatCountRxObjects'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id = $vb->iid;
    $port_id =~ s/^.+\.//g;
    $var     =~ s/"//g;

    my $dec_val = hex2dec($var);
    #$data_collect{'ports'}{$port_id}{$vb->tag}{hex} = $var;
    #$data_collect{'ports'}{$port_id}{$vb->tag}{dec} = $dec_val;
    $data_collect{'ports'}{$port_id}{$vb->tag} = $dec_val;
    #print "connUnitPortStatCountRxObjects = $data_collect{'ports'}{$port_id}{$vb->tag} = $dec_val\n";

    #print $vb->iid, " : ", $var, "\n";
    #print $port_id, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitPortStatCountBBCreditZero
  #
  $mib = 'connUnitPortStatCountBBCreditZero'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id = $vb->iid;
    $port_id =~ s/^.+\.//g;
    $var     =~ s/"//g;

    my $dec_val = hex2dec($var);
    #$data_collect{'ports'}{$port_id}{$vb->tag}{hex} = $var;
    #$data_collect{'ports'}{$port_id}{$vb->tag}{dec} = $dec_val;
    $data_collect{'ports'}{$port_id}{$vb->tag} = $dec_val;

    #print $vb->iid, " : ", $var, "\n";
    #print $port_id, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitPortStatCountInvalidCRC
  #
  $mib = 'connUnitPortStatCountInvalidCRC'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id = $vb->iid;
    $port_id =~ s/^.+\.//g;
    $var     =~ s/"//g;

    my $dec_val = hex2dec($var);
    $data_collect{'ports'}{$port_id}{$vb->tag} = $dec_val;

    #print $vb->iid, " : ", $var, "\n";
    #print $port_id, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitPortName
  #
  $mib = 'connUnitPortName'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id = $vb->iid;
    $port_id =~ s/^.+\.//g;
    $var     =~ s/"//g;
    $var     =~ s/\r//g;

    $data_collect{'ports'}{$port_id}{$vb->tag} = $var;

    #print $vb->iid, " : ", $var, "\n";
    #print $port_id, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitPortSpeed
  #
  $mib = 'connUnitPortSpeed'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id = $vb->iid;
    $port_id =~ s/^.+\.//g;
    $var     =~ s/"//g;

    $data_collect{'ports'}{$port_id}{$vb->tag} = $var;
    #print "connUnitPortSpeed = $var\n";

    #print $vb->iid, " : ", $var, "\n";
    #print $port_id, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitPortWwn
  #
  $mib = 'connUnitPortWwn'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id    = $vb->iid;
    my $wwn_to_cfg = $var;

    $wwn_to_cfg =~ s/"//g;
    $wwn_to_cfg =~ s/\s+$//g;
    $wwn_to_cfg =~ s/^\s+//g;
    $wwn_to_cfg =~ s/\s+/:/g;
    $port_id    =~ s/^.+\.//g;
    $var        =~ s/"//g;
    $var        =~ s/\s+//g;

    $data_collect{'ports'}{$port_id}{$vb->tag}     = $var;
    $data_collect{'ports'}{$port_id}{'wwn_to_cfg'} = $wwn_to_cfg;

    #print $vb->iid, " : ", $var, "\n";
    #print $port_id, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitPortStatCountInvalidOrderedSets
  #
  $mib = 'connUnitPortStatCountInvalidOrderedSets'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id = $vb->iid;
    $port_id =~ s/^.+\.//g;
    $var     =~ s/"//g;

    my $dec_val = hex2dec($var);
    $data_collect{'ports'}{$port_id}{$vb->tag} = $dec_val;

    #print $vb->iid, " : ", $var, "\n";
    #print $port_id, " : ", $dec_val, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  ######################
  #
  # connUnitLinkPortNumberX
  #
  $mib = 'connUnitLinkPortNumberX'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $iid = $vb->iid;
    $iid =~ s/^.+\.//g;
    $var =~ s/"//g;

    $data_collect{'ISL'}{'ports'}{$iid} = $var;
    #$data_collect{'ISL'}{$iid}{'port'} = $var;
    #print $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitLinkPortWwnX
  #
  $mib = 'connUnitLinkPortWwnX'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $iid = $vb->iid;
    $iid =~ s/^.+\.//g;
    $var =~ s/"//g;
    $var =~ s/\s+//g;

    $data_collect{'ISL'}{'map'}{$iid}{'from_wwn'} = $var;
    #print $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitLinkPortWwnY
  #
  $mib = 'connUnitLinkPortWwnY'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $iid = $vb->iid;
    $iid =~ s/^.+\.//g;
    $var =~ s/"//g;
    $var =~ s/\s+//g;

    $data_collect{'ISL'}{'map'}{$iid}{'to_wwn'} = $var;
    #print $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitRevsRevId
  #
  $mib = 'connUnitRevsRevId'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $iid = $vb->iid;
    $iid =~ s/^.+\.//g;
    $var =~ s/"//g;
    $var =~ s/\s+//g;

    if ( $iid == 1 ) { $data_collect{'configuration'}{switchType} = $var; }
    if ( $iid == 2 ) { $data_collect{'configuration'}{Fabric_OS_version} = $var; }
    #$data_collect{'configuration'}{$vb->tag} = $var;
    #print "$data_collect{'configuration'}{$vb->tag}\n";
    #print $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitPortType
  #
  $mib = 'connUnitPortType'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $iid = $vb->iid;
    $iid =~ s/^.+\.//g;
    $var =~ s/"//g;
    $var =~ s/\s+//g;

    $data_collect{'configuration'}{port}{$iid}{PortType} = $var;
    #print "$data_collect{'configuration'}{$vb->tag}\n";
    #print $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # sysUpTime
  #
  $mib = 'sysUpTime'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb) ) {
    $var =~ s/"//g;
    $data_collect{'configuration'}{'sysUpTime'} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var,"xxx\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitSn
  #
  $mib = 'connUnitSn'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb) ) {
    $var =~ s/"//g;
    $data_collect{'configuration'}{'connUnitSn'} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var,"xxx\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitUrl
  #
  $mib = 'connUnitUrl'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb) ) {
    $var =~ s/"//g;
    $data_collect{'configuration'}{'connUnitUrl'} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var,"xxx\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # ifName
  #
  $mib = 'ifName'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {
    #$data_collect{'ports'}{$vb->iid}{$vb->tag} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # swPortEncrypt
  #
  $mib = 'swPortEncrypt'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id = $vb->iid;
    $port_id =~ s/^.+\.//g;
    $var     =~ s/"//g;

    #print $vb->tag, ".", $vb->iid, " : ", $var,"xxx\n";
    $data_collect{'ports'}{$port_id}{$vb->tag} = $var;
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # swPortCompression
  #
  $mib = 'swPortCompression'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id = $vb->iid;
    $port_id =~ s/^.+\.//g;
    $var     =~ s/"//g;

    #print $vb->tag, ".", $vb->iid, " : ", $var,"xxx\n";
    $data_collect{'ports'}{$port_id}{$vb->tag} = $var;
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }


  ###################
  ### FCMGMT-MIB END ###

  ### check vsans ###
  my $tmp_vsan_file = "$tmpdir/$san_ip-check-vsan";
  if (-f $tmp_vsan_file ) {
    open( VSAN, "<$tmp_vsan_file" ) || error( "Couldn't open file $tmp_vsan_file $!" . __FILE__ . ":" . __LINE__ ) && return 1;
    my @vsans = <VSAN>;
    close(VSAN);

    foreach my $vf_id (@vsans) {
      chomp $vf_id;
      if ( $vf_id =~ "^VF:" ) {
        my %vsan_data_collect = collect_vsan_data_brcd($san_ip,$vf_id);

        #merge hashes
        %{$data_collect{'ports'}}                 = (%{$vsan_data_collect{'ports'}}, %{$data_collect{'ports'}});
        %{$data_collect{'configuration'}{'port'}} = (%{$vsan_data_collect{'configuration'}{'port'}}, %{$data_collect{'configuration'}{'port'}});

        my $vsan_id = $vf_id;
        $vsan_id =~ s/^VF://;
        if ( defined $vsan_data_collect{'configuration'}{'vsan'}{'fcFeFabricName'} ) {
          $data_collect{'configuration'}{'vsan'}{$vsan_id}{'fcFeFabricName'} = $vsan_data_collect{'configuration'}{'vsan'}{'fcFeFabricName'};
        }
        if ( defined $vsan_data_collect{'configuration'}{'vsan'}{'fcFeElementName'} ) {
          $data_collect{'configuration'}{'vsan'}{$vsan_id}{'fcFeElementName'} = $vsan_data_collect{'configuration'}{'vsan'}{'fcFeElementName'};
        }
        $data_collect{'configuration'}{'vsan'}{$vsan_id}{'vsanName'} = "Virtual_Fabric_$vsan_id";

        my $vsan_port_idx = 0;
        foreach my $vsan_port (sort { $a <=> $b } keys (%{$vsan_data_collect{ports}})) {
          $vsan_port_idx++;
          $data_collect{'configuration'}{'vsan'}{$vsan_id}{'ports'}{$vsan_port_idx} = $vsan_port;
        }
      }
      else { next; }
    }
  }


  #my $end_time = localtime();
  #print "start collect data: $start_time - end collect data: $end_time\n";

  #print Dumper(\%data_collect);
  save_data_brcd(%data_collect);

  if ( $demo == 2 ) {
    export_data_for_demo(%data_collect);
  }

  exit;
}

sub save_data_brcd {
  my (%data) = @_;
  my $switch_name;
  my $act_time = time();

  if ( defined $data{configuration}{sysName} ) {
    $switch_name = $data{configuration}{sysName};
  }
  else {
    error( "Switch name not found! IP: $san_ip $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  if (! -d "$wrkdir/$switch_name" ) {
    mkdir("$wrkdir/$switch_name", 0755) || error( "$act_time: Cannot mkdir $wrkdir/$switch_name: $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  # output file
  my ( $sec, $min, $hour, $day, $month, $year, $wday, $yday, $isdst ) = localtime();
  my $date = sprintf( "%4d%02d%02d",  $year + 1900, $month + 1, $day );
  my $time = sprintf( "%02d%02d", $hour, $min);
  my $output_file = "$wrkdir/$switch_name/$switch_name\_sanperf_$date\_$time.out.tmp\n";
  open( OUT, ">$output_file" ) || error( "Couldn't open file $output_file $!" . __FILE__ . ":" . __LINE__ ) && exit;

  # output file header
  print OUT "act_time,bytes_tra,bytes_rec,frames_tra,frames_rec,swFCPortNoTxCredits,swFCPortRxCrcs,port_speed,reserve1,reserve2,reserve3,reserve4,reserve5,reserve6,switch_name,db_name,rrd_file\n";

  my @health_status_data;

  my $ports_cfg        = "$wrkdir/$switch_name/PORTS.cfg";
  my $ports_cfg_suffix = "$ports_cfg-tmp";
  open( PCFG, ">$ports_cfg_suffix" ) || error( "Couldn't open file $ports_cfg_suffix $!" . __FILE__ . ":" . __LINE__ ) && exit;

  foreach my $name (sort { $a <=> $b } keys (%{$data{ports}})) {
    my $bytes_tra           = ""; # transmitted
    my $bytes_rec           = ""; # received
    my $frames_tra          = ""; # transmitted
    my $frames_rec          = ""; # received
    my $swFCPortNoTxCredits = ""; # Counts the number of times that the transmit credit has reached 0.
    my $swFCPortRxCrcs      = ""; # Counts the number of CRC errors detected for frames received.
    my $port_speed          = "";
    my $port_id             = "";
    my $port_name           = "";
    my $port_wwn            = "";
    my $db_name;
    my $rrd_file;
    my $swFCPortPhyState    = "";
    my $swFCPortOpStatus    = "";
    my $reserve1            = ""; #connUnitPortStatCountInvalidOrderedSets
    my $reserve2            = "";
    my $reserve3            = "";
    my $reserve4            = "";
    my $reserve5            = "";
    my $reserve6            = "";

    $port_id = $name;
    if ( defined $data{ports}{$name}{connUnitPortName} ) {
      $port_name = $data{ports}{$name}{connUnitPortName};
    }
    if ( defined $data{ports}{$name}{connUnitPortStatCountTxElements} && isdigit($data{ports}{$name}{connUnitPortStatCountTxElements}) ) {
      $bytes_tra = $data{ports}{$name}{connUnitPortStatCountTxElements};
    }
    if ( defined $data{ports}{$name}{connUnitPortStatCountRxElements} && isdigit($data{ports}{$name}{connUnitPortStatCountRxElements}) ) {
      $bytes_rec = $data{ports}{$name}{connUnitPortStatCountRxElements};
    }
    if ( defined $data{ports}{$name}{connUnitPortStatCountTxObjects} && isdigit($data{ports}{$name}{connUnitPortStatCountTxObjects}) ) {
      $frames_tra = $data{ports}{$name}{connUnitPortStatCountTxObjects};
    }
    if ( defined $data{ports}{$name}{connUnitPortStatCountRxObjects} && isdigit($data{ports}{$name}{connUnitPortStatCountRxObjects}) ) {
      $frames_rec = $data{ports}{$name}{connUnitPortStatCountRxObjects};
    }
    if ( defined $data{ports}{$name}{connUnitPortStatCountBBCreditZero} && isdigit($data{ports}{$name}{connUnitPortStatCountBBCreditZero}) ) {
      $swFCPortNoTxCredits = $data{ports}{$name}{connUnitPortStatCountBBCreditZero};
    }
    if ( defined $data{ports}{$name}{connUnitPortStatCountInvalidCRC} && isdigit($data{ports}{$name}{connUnitPortStatCountInvalidCRC}) ) {
      $swFCPortRxCrcs = $data{ports}{$name}{connUnitPortStatCountInvalidCRC};
    }
    if ( defined $data{ports}{$name}{connUnitPortStatCountInvalidOrderedSets} && isdigit($data{ports}{$name}{connUnitPortStatCountInvalidOrderedSets}) ) {
      $reserve1 = $data{ports}{$name}{connUnitPortStatCountInvalidOrderedSets};
    }
    if ( defined $data{ports}{$name}{connUnitPortSpeed} && isdigit($data{ports}{$name}{connUnitPortSpeed}) ) {
      $port_speed = $data{ports}{$name}{connUnitPortSpeed};
    }
    if ( defined $data{ports}{$name}{swFCPortPhyState} ) {
      $swFCPortPhyState = $data{ports}{$name}{swFCPortPhyState};
    }
    if ( defined $data{ports}{$name}{swFCPortOpStatus} ) {
      $swFCPortOpStatus = $data{ports}{$name}{swFCPortOpStatus};
    }
    if ( defined $data{ports}{$name}{connUnitPortWwn} ) {
      $port_wwn = $data{ports}{$name}{connUnitPortWwn};
    }
    push(@health_status_data, "$port_id,$swFCPortPhyState,$swFCPortOpStatus\n");

    # if port is disabled, then CRC errors must be NaN.
    if ( $swFCPortPhyState eq "inSync" && $swFCPortOpStatus eq "offline" ) {
      $swFCPortRxCrcs      = "U";
      #print "$act_time : Port $port_id is disabled!!!\n";
    }

    # if operational status is offline, then frames in/out must be NaN.
    if ( $swFCPortOpStatus eq "offline" ) {
      $frames_tra = "U";
      $frames_rec = "U";
    }


    if ( ! -d "$wrkdir/$switch_name" ) {
      mkdir("$wrkdir/$switch_name");
    }
    if ( ! -f "$wrkdir/$switch_name/SAN-BRCD" ) {
      open( BRCD, ">$wrkdir/$switch_name/SAN-BRCD" ) || error( "Couldn't open file $wrkdir/$switch_name/SAN-BRCD $!" . __FILE__ . ":" . __LINE__ ) && exit;
      close(BRCD);
    }

    $db_name = "port" . $port_id . "\.rrd";
    $rrd_file = "$wrkdir/$switch_name/$db_name";

    print PCFG "port$port_id : $rrd_file : $port_name : $port_wwn\n";
    print OUT "$act_time,$bytes_tra,$bytes_rec,$frames_tra,$frames_rec,$swFCPortNoTxCredits,$swFCPortRxCrcs,$port_speed,$reserve1,$reserve2,$reserve3,$reserve4,$reserve5,$reserve6,$switch_name,$db_name,$rrd_file\n";
  }
  close(OUT);
  close(PCFG);
  rename "$ports_cfg_suffix", "$ports_cfg";

  # health status
  if (! -d "$webdir/$switch_name" ) {
    mkdir("$webdir/$switch_name", 0755) || error( "$act_time: Cannot mkdir $webdir/$switch_name: $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  my $health_status_html =  "$webdir/$switch_name/health_status.html";
  my $act_timestamp      = time();
  my $hs_timestamp       = $act_timestamp;
  my $last_update        = localtime($act_timestamp);
  my $timestamp_diff     = 0;

  if ( -f $health_status_html ) {
    $hs_timestamp   = (stat($health_status_html))[9];
    $timestamp_diff = $act_timestamp - $hs_timestamp;
  }

  if ( ! -f $health_status_html || $timestamp_diff > 299 ) {
    health_status_brcd(\@health_status_data,$health_status_html,$last_update,$switch_name);
  }

  # vsan part
  if ( defined $data{configuration}{vsan} ) {

    open( VSAN, ">$wrkdir/$switch_name/vsan.txt" ) || error( "Couldn't open file $wrkdir/$switch_name/vsan.txt $!" . __FILE__ . ":" . __LINE__ ) && exit;

    foreach my $vsan_id (sort { $a <=> $b } keys (%{$data{configuration}{vsan}})) {
      chomp $vsan_id;
      my $vsan_name             = "";
      my $principal_vsan_sw_wwn = "";
      my $vsan_sw_wwn           = "";

      if ( defined $data{configuration}{vsan}{$vsan_id}{vsanName} && $data{configuration}{vsan}{$vsan_id}{vsanName} ne '' ) {
        $vsan_name = $data{configuration}{vsan}{$vsan_id}{vsanName};
      }
      else {
        $vsan_name = "vsan_$vsan_id";
      }
      if ( defined $data{configuration}{vsan}{$vsan_id}{fcFeFabricName} && $data{configuration}{vsan}{$vsan_id}{fcFeFabricName} ne '' ) {
        $principal_vsan_sw_wwn = $data{configuration}{vsan}{$vsan_id}{fcFeFabricName};
        $principal_vsan_sw_wwn =~ s/"//g;
        $principal_vsan_sw_wwn =~ s/\s+//g;
      }
      if ( defined $data{configuration}{vsan}{$vsan_id}{fcFeElementName} && $data{configuration}{vsan}{$vsan_id}{fcFeElementName} ne '' ) {
        $vsan_sw_wwn = $data{configuration}{vsan}{$vsan_id}{fcFeElementName};
        $vsan_sw_wwn =~ s/"//g;
        $vsan_sw_wwn =~ s/\s+//g;
      }
      # vsan ports
      if ( defined $data{configuration}{vsan}{$vsan_id}{ports} && $data{configuration}{vsan}{$vsan_id}{ports} ne '' ) {
        my $port_name = "";
        foreach my $port_id (sort { $a <=> $b } keys (%{$data{configuration}{vsan}{$vsan_id}{ports}})) {
          chomp $port_id;
          if ( defined $data{configuration}{vsan}{$vsan_id}{ports}{$port_id} && $data{configuration}{vsan}{$vsan_id}{ports}{$port_id} ne '' ) {
            $port_name = $data{configuration}{vsan}{$vsan_id}{ports}{$port_id};

            print VSAN "$vsan_id : $vsan_sw_wwn : $switch_name : $vsan_id : $vsan_name : port$port_name : $wrkdir/$switch_name/port$port_name.rrd\n";
          }
        }
      }
      else { next; } # if vsan hasnt ports, then go to next vsan
    }
    close(VSAN);
  }


  # Fabric part
  if ( defined $data{configuration}{fcFeFabricName} && defined $data{configuration}{fcFeElementName}  ) {
    my $fcFeFabricName  = $data{configuration}{fcFeFabricName};
    my $fcFeElementName = $data{configuration}{fcFeElementName};
    $fcFeFabricName =~ s/"//g;
    $fcFeFabricName =~ s/\s+//g;
    $fcFeElementName =~ s/"//g;
    $fcFeElementName =~ s/\s+//g;

    my $fabric_name = "";
    if ( -f "$basedir/etc/san-list.cfg") {
      open( SL, "<$basedir/etc/san-list.cfg" ) || error( "Couldn't open file $basedir/etc/san-list.cfg $!" . __FILE__ . ":" . __LINE__ );
      my @san_cfg = <SL>;
      close(SL);
      my ($line) = grep {/^$san_ip:/} @san_cfg;
      chomp $line;
      my (undef, undef, undef, $fab_name) = split(":",$line);
      if ( defined $fab_name && $fab_name ne "" ) {
        chomp $fab_name;
        $fabric_name = $fab_name;
      }
    }

    open( FC, ">$wrkdir/$switch_name/fabric.txt" ) || error( "Couldn't open file $wrkdir/$switch_name/fabric.txt $!" . __FILE__ . ":" . __LINE__ ) && exit;
    print FC "$fcFeFabricName,$fcFeElementName,$switch_name,$fabric_name\n";
    close(FC);
  }
  else {
    error( "fcFeFabricName or fcFeElementName not found! IP: $san_ip $!" . __FILE__ . ":" . __LINE__ );
  }

  # ISL part
  open( ISL, ">$wrkdir/$switch_name/ISL.txt" ) || error( "Couldn't open file $wrkdir/$switch_name/ISL.txt $!" . __FILE__ . ":" . __LINE__ ) && exit

  my @all_ports;
  my @switches_all = <$wrkdir/*\/SAN-BRCD>;
  foreach my $sw_name (@switches_all) {
    chomp $sw_name;
    $sw_name =~ s/^$wrkdir\///g;
    $sw_name =~ s/\/SAN-BRCD$//g;

    open( ALP, "<$wrkdir/$sw_name/PORTS.cfg" ) || error( "Couldn't open file $wrkdir/$sw_name/PORTS.cfg $!" . __FILE__ . ":" . __LINE__ ) && exit;
    my @ports = <ALP>;
    close(ALP);

    foreach my $line (@ports) {
      chomp $line;
      push(@all_ports, "$sw_name : $line\n");
    }
  }

  my $isl_count = 0;
  my $id_index = 0;
  foreach my $id_line (sort { $a <=> $b } keys (%{$data{ISL}{map}})) {
    $id_index++;
    if ( $id_index ne $id_line ) { next; }
    $isl_count++;
    my $from_wwn  = "";
    my $from_sw   = "";
    my $from_port = "";
    my $from_line = "";
    my $to_wwn    = "";
    my $to_sw     = "";
    my $to_port   = "";
    my $to_line   = "";
    if ( defined $data{ISL}{map}{$id_line}{from_wwn} && $data{ISL}{map}{$id_line}{from_wwn} ne '' ) {
      $from_wwn = $data{ISL}{map}{$id_line}{from_wwn};
    }
    if ( defined $data{ISL}{map}{$id_line}{to_wwn} && $data{ISL}{map}{$id_line}{to_wwn} ne '' ) {
      $to_wwn = $data{ISL}{map}{$id_line}{to_wwn};
    }
    if ( grep {/$from_wwn$/} @all_ports ) {
      ($from_line) = grep {/$from_wwn$/} @all_ports;
      chomp $from_line;
      ($from_sw, $from_port, undef) = split(" : ",$from_line);
    }
    if ( grep {/$to_wwn$/} @all_ports ) {
      ($to_line) = grep {/$to_wwn$/} @all_ports;
      chomp $to_line;
      ($to_sw, $to_port, undef) = split(" : ",$to_line);
    }
    #print "FROM : $from_sw : $from_port   --->   TO : $to_sw : $to_port\n";
    if ( -f "$wrkdir/$from_sw/$from_port.rrd" ) {
      print ISL "$from_port,$wrkdir/$from_sw/$from_port.rrd,$from_sw,to_port=$to_port,to_switch=$to_sw\n";
    }
    else {
      error( "$from_sw : RRDfile for inter switch link not found! ISL=$from_port, RRD=$wrkdir/$from_sw/$from_port.rrd $!" . __FILE__ . ":" . __LINE__ );
    }
  }
  close(ISL);
  if ( $isl_count == 0 ) {
    unlink ("$wrkdir/$switch_name/ISL.txt");
  }

  # Configuration
  my $config_html        =  "$webdir/$switch_name/config.html";
  my $act_timestamp_cfg  = time();
  my $cfg_timestamp      = $act_timestamp_cfg;
  my $last_update_cfg    = localtime($act_timestamp_cfg);
  my $timestamp_diff_cfg = 0;

  if ( -f $config_html ) {
    $cfg_timestamp      = (stat($config_html))[9];
    $timestamp_diff_cfg = $act_timestamp_cfg - $cfg_timestamp;
  }

  if ( ! -f $config_html || $timestamp_diff_cfg > 3599 ) {
    config_cfg_brcd(%data);
  }

}

sub config_cfg_brcd {
  my (%data) = @_;

  # all configuration variables per switch
  my $switch_name            = "";
  my $switch_ip              = "";
  my $switch_wwn             = "";
  my $switch_model           = "";
  my $switch_speed           = "";
  my $switch_os_version      = "";
  my $switch_fabric_name     = "";
  my $switch_days_up         = "";
  my $switch_serial_number   = "";
  my $switch_total_ports     = "";
  my $switch_unused_ports    = "";
  my $switch_total_isl_ports = "";

  if ( defined $data{configuration}{sysName} ) {
    $switch_name = $data{configuration}{sysName};
  }
  if ( defined $data{configuration}{fcFeElementName} ) {
    $switch_wwn = $data{configuration}{fcFeElementName};
    $switch_wwn =~ s/^\s+//g;
    $switch_wwn =~ s/\s+$//g;
    $switch_wwn =~ s/\s+/:/g;
  }
  if ( defined $data{configuration}{Fabric_OS_version} ) {
    $switch_os_version = $data{configuration}{Fabric_OS_version};
  }
  if ( defined $data{configuration}{sysUpTime} ) {
    ($switch_days_up, undef) = split(":", $data{configuration}{sysUpTime});
  }
  if ( defined $data{configuration}{connUnitSn} ) {
    $switch_serial_number = $data{configuration}{connUnitSn};
  }
  if ( defined $data{configuration}{connUnitUrl} ) {
    $switch_ip = $data{configuration}{connUnitUrl};
    $switch_ip =~ s/http://;
    $switch_ip =~ s/\///g;
  }
  if ( -f "$wrkdir/$switch_name/ISL.txt" ) {
    open( ISL, "<$wrkdir/$switch_name/ISL.txt" ) || error( "Couldn't open file $wrkdir/$switch_name/ISL.txt $!" . __FILE__ . ":" . __LINE__ ) && next;
    my @isl = <ISL>;
    close(ISL);
    $switch_total_isl_ports = @isl;
  }
  else {
    $switch_total_isl_ports = "0";
  }
  if ( -f "$wrkdir/$switch_name/PORTS.cfg" ) {
    open( PORTS, "<$wrkdir/$switch_name/PORTS.cfg" ) || error( "Couldn't open file $wrkdir/$switch_name/PORTS.cfg $!" . __FILE__ . ":" . __LINE__ ) && next;
    my @ports = <PORTS>;
    close(PORTS);
    $switch_total_ports = @ports;
  }

  my $unused_ports_count = 0;
  foreach my $name (sort { $a <=> $b } keys (%{$data{ports}})) {
    if ( defined $data{ports}{$name}{swFCPortPhyState} && $data{ports}{$name}{swFCPortPhyState} =~ "noTransceiver" ) {
      $unused_ports_count++;
    }
  }
  $switch_unused_ports = $unused_ports_count;

  if ( defined $data{configuration}{switchType} ) {
    my $type_line = translate_brcd_type($data{configuration}{switchType});
    if ( defined $type_line && $type_line ne '' ) {
      my (undef, $speed, $model) = split(",",$type_line);
      $switch_model = $model;
      $switch_speed = $speed;
    }
  }


  # config.cfg
  my $config_cfg = "$wrkdir/$switch_name/config.cfg";
  open( SCFG, ">$config_cfg" ) || error( "Couldn't open file $config_cfg $!" . __FILE__ . ":" . __LINE__ ) && next;

  print SCFG "switch_name=$switch_name\n";
  print SCFG "switch_ip=$switch_ip\n";
  print SCFG "switch_wwn=$switch_wwn\n";
  print SCFG "switch_model=$switch_model\n";
  print SCFG "switch_speed=$switch_speed\n";
  print SCFG "switch_os_version=$switch_os_version\n";
  print SCFG "switch_fabric_name=$switch_fabric_name\n";
  print SCFG "switch_days_up=$switch_days_up\n";
  print SCFG "switch_serial_number=$switch_serial_number\n";
  print SCFG "switch_total_ports=$switch_total_ports\n";
  print SCFG "switch_unused_ports=$switch_unused_ports\n";
  print SCFG "switch_total_isl_ports=$switch_total_isl_ports\n";

  close(SCFG);

  # config.html
  my $config_html =  "$webdir/$switch_name/config.html";
  open(CFGH, "> $config_html") || error( "Couldn't open file $config_html $!" . __FILE__ . ":" . __LINE__ ) && next;
  print CFGH "<br><br><br>\n";
  print CFGH "<center>\n";
  print CFGH "<table class =\"tabcfgsum tablesortercfgsum\">\n";
  print CFGH "<thead>\n";
  print CFGH "<tr>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Switch Name</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">IP Address</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">World Wide Name</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Model</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Speed</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">OS Version</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Days Up</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Serial Number</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Total Ports</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">ISL Ports</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Unused Ports</th>\n";
  print CFGH "</tr>\n";
  print CFGH "</thead>\n";
  print CFGH "<tbody>\n";

  print CFGH "<tr>\n";
  print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_name</td>\n";
  print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_ip</td>\n";
  print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_wwn</td>\n";
  print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_model</td>\n";
  print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_speed</td>\n";
  print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_os_version</td>\n";
  print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_days_up</td>\n";
  print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_serial_number</td>\n";
  print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_total_ports</td>\n";
  print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_total_isl_ports</td>\n";
  print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_unused_ports</td>\n";
  print CFGH "</tr>\n";
  print CFGH "</tbody>\n";
  print CFGH "</table>\n";

  print CFGH "<br><br><br>\n";
  print CFGH "<table class =\"tabcfgsum tablesorter tablesortercfgsum\">\n";
  print CFGH "<thead>\n";
  print CFGH "<tr>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Port</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Alias (from switch)</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Alias (from alias.cfg)</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">World Wide Name</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Speed</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">ISL</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">State</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Encrypt</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Compress</th>\n";
  print CFGH "</tr>\n";
  print CFGH "</thead>\n";
  print CFGH "<tbody>\n";


  # read etc/alias.cfg
  my $afile="$basedir/etc/alias.cfg";
  my @alines;
  if ( -f $afile ) {
    open(FHA, "< $afile") || error ("File cannot be opened for read, wrong user rights?? : $afile ".__FILE__.":".__LINE__) && next;
    @alines = <FHA>;
    close (FHA);
  }
  # isl
  my $isl_cfg = "$wrkdir/$switch_name/ISL.txt";
  my @isl;
  if ( -f $isl_cfg ) {
    open( ISL, "<$isl_cfg" ) || error( "Couldn't open file $isl_cfg $!" . __FILE__ . ":" . __LINE__ ) && next;
    @isl = <ISL>;
    close(ISL);
  }

  foreach my $name (sort { $a <=> $b } keys (%{$data{ports}})) {
    my $port_name      = "-";
    my $alias_from_sw  = "-";
    my $alias_from_cfg = "-";
    my $port_speed     = "-";
    my $port_isl       = "-";
    my $port_state     = "-";
    my $port_encrypt   = "-";
    my $port_compress  = "-";
    my $port_wwn       = "-";

    $port_name = $name;
    if ( defined $data{ports}{$name}{connUnitPortName} && $data{ports}{$name}{connUnitPortName} ne '' ) {
      $alias_from_sw = $data{ports}{$name}{connUnitPortName};
    }
    if ( defined $data{ports}{$name}{connUnitPortSpeed} && $data{ports}{$name}{connUnitPortSpeed} ne '' ) {
      $port_speed = $data{ports}{$name}{connUnitPortSpeed};
      if ( isdigit($port_speed) ) {
        $port_speed = ($port_speed * 8) / 1000000;
        $port_speed = "$port_speed Gbps";
      }
    }
    if ( defined $data{ports}{$name}{swFCPortPhyState} && $data{ports}{$name}{swFCPortPhyState} =~ "noTransceiver" ) {
      $port_state = "unused";
    }
    if ( defined $data{ports}{$name}{wwn_to_cfg} && $data{ports}{$name}{wwn_to_cfg} ne '' ) {
      $port_wwn = $data{ports}{$name}{wwn_to_cfg};
    }

    if ( defined $data{ports}{$name}{swPortCompression} && $data{ports}{$name}{swPortCompression} ne '' ) {
      $port_compress = $data{ports}{$name}{swPortCompression};
    }
    if ( defined $data{ports}{$name}{swPortEncrypt} && $data{ports}{$name}{swPortEncrypt} ne '' ) {
      $port_encrypt = $data{ports}{$name}{swPortEncrypt};
    }

    # use alias from alias.cfg
    my $alias_from_admin_line  = "";
    my $alias_from_admin_line2 = "";
    ($alias_from_admin_line)  = grep {/^SANPORT:$switch_name:port$port_name:/} @alines;
    ($alias_from_admin_line2) = grep {/^SANPORT:$switch_name:$port_name:/} @alines;
    if ( defined $alias_from_admin_line && $alias_from_admin_line ne '' ) {
      my (undef, undef, undef, $alias_from_admin) = split(":",$alias_from_admin_line);
      if ( defined $alias_from_admin && $alias_from_admin ne '' ) {
        $alias_from_cfg  = "$alias_from_admin";
      }
    }
    if ( defined $alias_from_admin_line2 && $alias_from_admin_line2 ne '' ) {
      my (undef, undef, undef, $alias_from_admin) = split(":",$alias_from_admin_line2);
      if ( defined $alias_from_admin && $alias_from_admin ne '' ) {
        $alias_from_cfg  = "$alias_from_admin";
      }
    }

    # isl
    my $isl_line = "";
    ($isl_line) = grep {/^port$port_name,/} @isl;
    if ( defined $isl_line && $isl_line ne '' ) {
      chomp $isl_line;
      my (undef, undef, undef, $to_port, $to_sw) = split(",", $isl_line);
      if ( defined $to_port && $to_port ne '' && defined $to_sw && $to_sw ne '' ) {
        $to_port =~ s/to_port=//;
        $to_sw =~ s/to_switch=//;
        $port_isl = "to $to_sw, $to_port";
      }
    }


    print CFGH "<tr>\n";
    print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$port_name</td>\n";
    print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$alias_from_sw</td>\n";
    print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$alias_from_cfg</td>\n";
    print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$port_wwn</td>\n";
    print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$port_speed</td>\n";
    print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$port_isl</td>\n";
    print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$port_state</td>\n";
    print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$port_encrypt</td>\n";
    print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$port_compress</td>\n";
    print CFGH "</tr>\n";
  }

  print CFGH "</tbody>\n";
  print CFGH "</table>\n";

  close(CFGH);


}

sub translate_brcd_type {

  my $type = shift;
  my @all_types = ("2,1 Gbps,Brocade 2010",
                   "3,1 Gbps,Brocade 2400",
                   "6,1 Gbps,Brocade 2800",
                   "9,2 Gbps,Brocade 3800",
                   "10,2 Gbps,Brocade 12000",
                   "12,2 Gbps,Brocade 3900",
                   "16,2 Gbps,Brocade 3200",
                   "21,2 Gbps,Brocade 24000",
                   "22,2 Gbps,Brocade 3016",
                   "26,2 Gbps,Brocade 3850",
                   "27,2 Gbps,Brocade 3250",
                   "32,4 Gbps,Brocade 4100",
                   "34,4 Gbps,Brocade 200E",
                   "37,4 Gbps,Brocade 4020",
                   "38,2 Gbps,Brocade AP7420",
                   "42,4 Gbps,Brocade 48000",
                   "43,4 Gbps,Brocade 4024",
                   "44,4 Gbps,Brocade 4900",
                   "46,4 Gbps,Brocade 7500",
                   "58,4 Gbps,Brocade 5000",
                   "62,8 Gbps,Brocade DCX",
                   "64,8 Gbps,Brocade 5300",
                   "66,8 Gbps,Brocade 5100",
                   "67,8 Gbps,Brocade Encryption Switch",
                   "71,8 Gbps,Brocade 300",
                   "73,8 Gbps,Brocade 5470",
                   "76,UN,Brocade 8000",
                   "77,8 Gbps,Brocade DCX-4S",
                   "83,8 Gbps,Brocade 7800",
                   "121,16 Gbps,Brocade DCX8510-4",
                   "120,16 Gbps,Brocade DCX8510-8",
                   "109,16 Gbps,Brocade 6510",
                  );

  $type =~ s/\.[0-9]*$//;
  my $type_line = "";
  ($type_line) = grep {/^$type,/} @all_types;

  return($type_line);
}

sub health_status_brcd {

  my $health_status_d    = shift;
  my $health_status_html = shift;
  my $last_update        = shift;
  my $switch_name        = shift;
  my @data               = @{$health_status_d};
  my $main_state         = "OK";
  my $state_suffix       = "ok";
  my $act_timestamp      = time();

  # physical
  # gray   = noCard,1,noTransceiver,2,
  # red    = laserFault,3,portFault,7,diagFault,8,
  # orange = noLight,4,noSync,5,lockRef,9,
  # green  = inSync,6,

  # operational
  # gray   = unknown,0
  # red    = faulty,4,
  # orange = offline,2,testing,3,
  # green  = online,1

  my $gray_st   = "<img src=\"css/images/status_gray.png\">";
  my $red_st    = "<img src=\"css/images/status_red.png\">";
  my $orange_st = "<img src=\"css/images/status_orange.png\">";
  my $green_st  = "<img src=\"css/images/status_green.png\">";

  my $port_table_start = "<table class=\"san_stat_legend\" frame=\"box\" style=\"padding:0px 5px 0px 5px;\"><tr><td height=\"20px\"><b>Port</b></td>";
  my $phys_table_start = "<tr><td height=\"20px\" nowrap=\"\"><b>Physical status</b></td>";
  my $oper_table_start = "<tr><td height=\"20px\" nowrap=\"\"><b>Operational status<b></td>";
  my $port_table_line  = "";
  my $phys_table_line  = "";
  my $oper_table_line  = "";
  my $port_table_end   = "</tr>\n";
  my $phys_table_end   = "</tr>\n";
  my $oper_table_end   = "</tr></table>\n";
  my @HS_table;
  my $port_idx         = 0;

  open( HS, ">$health_status_html" ) || error( "Couldn't open file $health_status_html $!" . __FILE__ . ":" . __LINE__ ) && exit;

  foreach my $line (@data) {
    chomp $line;
    $port_idx++;
    my ($port_id, $phys_st, $oper_st) = split(",",$line);

    $port_table_line .= "<td align=\"center\"><b>$port_id</b></td>";

    if ( $phys_st =~ "noCard" || $phys_st =~ "noTransceiver" ) {
      $phys_table_line .= "<td width=\"20px\" height=\"20px\" nowrap=\"\" title=\"$phys_st\"><a href=\"/stor2rrd-cgi/detail.sh?host=$switch_name&type=SANPORT&name=port$port_id&storage=SAN-BRCD&item=san&gui=1&none=none\">$gray_st</a></td>";
    }
    if ( $phys_st =~ "laserFault" || $phys_st =~ "portFault" || $phys_st =~ "diagFault" ) {
      $phys_table_line .= "<td width=\"20px\" height=\"20px\" nowrap=\"\" title=\"$phys_st\"><a href=\"/stor2rrd-cgi/detail.sh?host=$switch_name&type=SANPORT&name=port$port_id&storage=SAN-BRCD&item=san&gui=1&none=none\">$red_st</a></td>";
    }
    if ( $phys_st =~ "noLight" || $phys_st =~ "noSync" || $phys_st =~ "lockRef" ) {
      $phys_table_line .= "<td width=\"20px\" height=\"20px\" nowrap=\"\" title=\"$phys_st\"><a href=\"/stor2rrd-cgi/detail.sh?host=$switch_name&type=SANPORT&name=port$port_id&storage=SAN-BRCD&item=san&gui=1&none=none\">$orange_st</a></td>";
    }
    if ( $phys_st =~ "inSync" ) {
      $phys_table_line .= "<td width=\"20px\" height=\"20px\" nowrap=\"\" title=\"$phys_st\"><a href=\"/stor2rrd-cgi/detail.sh?host=$switch_name&type=SANPORT&name=port$port_id&storage=SAN-BRCD&item=san&gui=1&none=none\">$green_st</a></td>";
    }
    if ( $oper_st =~ "unknown" ) {
      $oper_table_line .= "<td width=\"20px\" height=\"20px\" nowrap=\"\" title=\"$oper_st\"><a href=\"/stor2rrd-cgi/detail.sh?host=$switch_name&type=SANPORT&name=port$port_id&storage=SAN-BRCD&item=san&gui=1&none=none\">$gray_st</a></td>";
    }
    if ( $oper_st =~ "faulty" ) {
      $oper_table_line .= "<td width=\"20px\" height=\"20px\" nowrap=\"\" title=\"$oper_st\"><a href=\"/stor2rrd-cgi/detail.sh?host=$switch_name&type=SANPORT&name=port$port_id&storage=SAN-BRCD&item=san&gui=1&none=none\">$red_st</a></td>";
    }
    if ( $oper_st =~ "offline" || $oper_st =~ "testing" ) {
      $oper_table_line .= "<td width=\"20px\" height=\"20px\" nowrap=\"\" title=\"$oper_st\"><a href=\"/stor2rrd-cgi/detail.sh?host=$switch_name&type=SANPORT&name=port$port_id&storage=SAN-BRCD&item=san&gui=1&none=none\">$orange_st</a></td>";
    }
    if ( $oper_st =~ "online" ) {
      $oper_table_line .= "<td width=\"20px\" height=\"20px\" nowrap=\"\" title=\"$oper_st\"><a href=\"/stor2rrd-cgi/detail.sh?host=$switch_name&type=SANPORT&name=port$port_id&storage=SAN-BRCD&item=san&gui=1&none=none\">$green_st</a></td>";
    }

    if ( $phys_st =~ "laserFault" || $phys_st =~ "portFault" || $phys_st =~ "diagFault" || $oper_st =~ "faulty" ) {
      $main_state = "NOT_OK";
      $state_suffix = "nok";
    }

    if ( $port_idx % 48 == 0 ) {
      push(@HS_table, "$port_table_start $port_table_line $port_table_end");
      push(@HS_table, "$phys_table_start $phys_table_line $phys_table_end");
      push(@HS_table, "$oper_table_start $oper_table_line $oper_table_end");

      $port_table_line  = "";
      $phys_table_line  = "";
      $oper_table_line  = "";
    }
  }

  if ( $port_table_line ne '' && $phys_table_line ne '' && $oper_table_line ne '' ) {
    push(@HS_table, "$port_table_start $port_table_line $port_table_end");
    push(@HS_table, "$phys_table_start $phys_table_line $phys_table_end");
    push(@HS_table, "$oper_table_start $oper_table_line $oper_table_end");
  }

  # Global health check
  my $component_name = $switch_name;
  $component_name =~ s/\s+//g;

  if (! -d "$basedir/tmp/health_status_summary" ) {
    mkdir("$basedir/tmp/health_status_summary", 0755) || error( "$act_timestamp: Cannot mkdir $basedir/tmp/health_status_summary: $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }
  if ( -f "$basedir/tmp/health_status_summary/$component_name.ok" )  { unlink ("$basedir/tmp/health_status_summary/$component_name.ok"); }
  if ( -f "$basedir/tmp/health_status_summary/$component_name.nok" ) { unlink ("$basedir/tmp/health_status_summary/$component_name.nok"); }

  open( MAST, ">$basedir/tmp/health_status_summary/$component_name.$state_suffix" ) || error( "Couldn't open file $basedir/tmp/health_status_summary/$component_name.$state_suffix $!" . __FILE__ . ":" . __LINE__ ) && exit;
  print MAST "SAN-SWITCH : $switch_name : $main_state : $act_timestamp\n";
  close(MAST);


# html table
print HS <<_MARKER_;
<html>
<head>
  <title>STOR2RRD</title>
</head>
  <br><br><br>
  <center>

  @HS_table

  <br><br><br>
  <center>
    <table>
      <td>
        <table class=\"san_stat_legend\">
          <tr>
            <td colspan="2" width="20px" height="20px"><b>Physical status</b></td>
          </tr>
          <tr>
            <td width="20px" height="20px" nowrap="">$green_st</td>
            <td nowrap=""><b>inSync:</b> The module is receiving light and is in sync.</td>
          </tr>
          <tr>
            <td width="20px" height="20px" nowrap="">$gray_st</td>
            <td nowrap=""><b>noCard:</b> No card is present in this switch slot.</td>
          </tr>
          <tr>
            <td width="20px" height="20px">&nbsp;</td>
            <td nowrap=""><b>noTransceiver:</b> No Transceiver module in this port.</td>
          </tr>
          <tr>
            <td width="20px" height="20px">&nbsp;</td>
            <td nowrap="">(Transceiver is the generic name for GBIC, SFP, and so on)</td>
          </tr>
          <tr>
            <td width="20px" height="20px" nowrap="">$orange_st</td>
            <td nowrap=""><b>noLight:</b> The module is not receiving light.</td>
          </tr>
          <tr>
            <td width="20px" height="20px">&nbsp;</td>
            <td nowrap=""><b>noSync:</b> The module is receiving light but is out of sync.</td>
          </tr>
          <tr>
            <td width="20px" height="20px">&nbsp;</td>
            <td nowrap=""><b>lockRef:</b> Port is locking to the reference signal.</td>
          </tr>
            <td width="20px" height="20px" nowrap="">$red_st</td>
            <td nowrap=""><b>laserFault:</b> The module is signaling a laser fault.</td>
          </tr>
          <tr>
            <td width="20px" height="20px">&nbsp;</td>
            <td nowrap="">(defective GBIC)</td>
          </tr>
          <tr>
            <td width="20px" height="20px">&nbsp;</td>
            <td nowrap=""><b>portFault:</b> The port is marked faulty.</td>
          </tr>
          <tr>
            <td width="20px" height="20px">&nbsp;</td>
            <td nowrap="">(defective GBIC, cable, or device)</td>
          </tr>
          <tr>
            <td width="20px" height="20px">&nbsp;</td>
            <td nowrap=""><b>diagFault:</b> The port failed diagnostics.</td>
          </tr>
          <tr>
            <td width="20px" height="20px">&nbsp;</td>
            <td nowrap="">(defective G_Port or FL_Port card or motherboard)</td>
          </tr>
        </table>
      </td>
      <td>
        <table>
          <tr>
            <td width="40px" height="20px">&nbsp;</td>
            </tr>
          </table>
        </td>
        </td>
        <td>
          <table class=\"san_stat_legend\">
            <tr>
              <td colspan="2" width="20px" height="20px"><b>Operational status</b></td>
            </tr>
            <tr>
              <td width="20px" height="20px" nowrap="">$green_st</td>
              <td nowrap=""><b>online:</b> User frames can be passed.</td>
            </tr>
            <tr>
              <td width="20px" height="20px" nowrap="">$gray_st</td>
              <td nowrap=""><b>unknown:</b> The port module is physically absent.</td>
            </tr>
            <tr>
              <td width="20px" height="20px" nowrap="">$orange_st</td>
              <td nowrap=""><b>offline:</b> No user frames can be passed.</td>
            </tr>
            <tr>
              <td width="20px" height="20px" nowrap="">$red_st</td>
              <td nowrap=""><b>faulty:</b> The port module is physically faulty.</td>
            </tr>
            <tr>
              <td width="20px" height="20px">&nbsp;</td>
              <td></td>
            </tr>
            <tr>
              <td width="20px" height="20px">&nbsp;</td>
              <td></td>
            </tr>
            <tr>
              <td width="20px" height="20px">&nbsp;</td>
              <td></td>
            </tr>
            <tr>
              <td width="20px" height="20px">&nbsp;</td>
              <td></td>
            </tr>
            <tr>
              <td width="20px" height="20px">&nbsp;</td>
              <td></td>
            </tr>
            <tr>
              <td width="20px" height="20px">&nbsp;</td>
              <td></td>
            </tr>
            <tr>
              <td width="20px" height="20px">&nbsp;</td>
              <td></td>
            </tr>
            <tr>
              <td width="20px" height="20px">&nbsp;</td>
              <td></td>
            </tr>
            <tr>
              <td width="20px" height="20px">&nbsp;</td>
              <td></td>
            </tr>
          </table>
        </td>
      </table>
    </center>
  </body>
</html>

_MARKER_

  close(HS);
}

sub collect_vsan_data_brcd {

  my $dest       = shift;
  my $vf_id      = shift;
  my $mib        = 'sysDescr';
  my $sver       = '3';
  my $timeout    = '50000000';
  my $SecName    = "snmpuser1";
  my $RemotePort = "";

  if ( -f "$basedir/etc/san-list.cfg") {
    open( SL, "<$basedir/etc/san-list.cfg" ) || error( "Couldn't open file $basedir/etc/san-list.cfg $!" . __FILE__ . ":" . __LINE__ );
    my @san_cfg = <SL>;
    close(SL);
    my ($line) = grep {/^$san_ip:/} @san_cfg;
    chomp $line;
    my (undef, $comm_st, undef, undef) = split(":",$line);
    if ( defined $comm_st && $comm_st ne "" && $sver == 3 ) {
      chomp $comm_st;
      $SecName = $comm_st;
    }
  }

  # SNMP option
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

  my $sess; # The SNMP::Session object that does the work.
  my $var;  # Used to hold the individual responses.
  my $vb;   # The Varbind object used for the 'real' query.

  my %data_collect;
  my %snmpparms;

  #my $start_time = localtime();

  # Initialize the MIB (else you can't do queries).
  &SNMP::addMibDirs("$basedir/MIBs/");
  &SNMP::loadModules('SW-MIB' , 'Brocade-REG-MIB' , 'Brocade-TC' , 'FCMGMT-MIB' , 'FA-EXT-MIB');
  &SNMP::initMib();

  $snmpparms{DestHost}       = inet_ntoa(inet_aton($dest));
  $snmpparms{Version}        = $sver;
  $snmpparms{Timeout}        = $timeout;
  $snmpparms{UseSprintValue} = '1';
  $snmpparms{SecName}        = $SecName;
  $snmpparms{Context}        = $vf_id;

  if ( defined $RemotePort && $RemotePort ne '' ) {
    $snmpparms{RemotePort} = $RemotePort;
  }

  $sess = new SNMP::Session(%snmpparms);

  # Turn the MIB object into something we can actually use.
  $vb = new SNMP::Varbind([$mib,'0']); # '0' is the instance.

  $var = $sess->get($vb); # Get exactly what we asked for.
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
    # Done as a block since you may not always want to die
    # in here.  You could set up another query, just go on,
    # or whatever...
  }
  $var =~ s/"//g;
  $data_collect{'configuration'}{$vb->tag} = $var;
  #print $vb->tag, ".", $vb->iid, " : $var\n";

  # Now let's show a MIB that might return multiple instances.

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
    #$data_collect{'configuration'}{$vb->tag} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # swFCPortPhyState
  #
  $mib = 'swFCPortPhyState'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {
    $var =~ s/"//g;
    $data_collect{'ports'}{$vb->iid}{$vb->tag} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var, "\n";
    #print "{$vb->iid}{$vb->tag}", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # swFCPortOpStatus
  #
  $mib = 'swFCPortOpStatus'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {
    $var =~ s/"//g;
    $data_collect{'ports'}{$vb->iid}{$vb->tag} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # fcFeFabricName
  #
  $mib = '1.3.6.1.2.1.75.1.1.1'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb) ) {
    $var =~ s/"//g;
    $data_collect{'configuration'}{'vsan'}{'fcFeFabricName'} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var,"\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # fcFeElementName
  #
  $mib = '1.3.6.1.2.1.75.1.1.2'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb) ) {
    $var =~ s/"//g;
    $data_collect{'configuration'}{'vsan'}{'fcFeElementName'} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var,"\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }


  ### FCMGMT-MIB START ###
  #
  # connUnitPortStatCountTxElements
  #
  $mib = 'connUnitPortStatCountTxElements'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id = $vb->iid;
    $port_id =~ s/^.+\.//g;
    $var     =~ s/"//g;

    my $dec_val = hex2dec($var);
    my $num = $dec_val / 4;
    #$data_collect{'ports'}{$port_id}{$vb->tag}{hex} = $var;
    #$data_collect{'ports'}{$port_id}{$vb->tag}{dec} = $dec_val;
    $data_collect{'ports'}{$port_id}{$vb->tag} = $num;
    #print "connUnitPortStatCountTxElements = $data_collect{'ports'}{$port_id}{$vb->tag} = $dec_val, $num\n";

    #print $vb->iid, " : ", $var, "\n";
    #print $port_id, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitPortStatCountRxElements
  #
  $mib = 'connUnitPortStatCountRxElements'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id = $vb->iid;
    $port_id =~ s/^.+\.//g;
    $var     =~ s/"//g;

    my $dec_val = hex2dec($var);
    my $num = $dec_val / 4;
    #$data_collect{'ports'}{$port_id}{$vb->tag}{hex} = $var;
    #$data_collect{'ports'}{$port_id}{$vb->tag}{dec} = $dec_val;
    $data_collect{'ports'}{$port_id}{$vb->tag} = $num;
    #print "connUnitPortStatCountRxElements = $data_collect{'ports'}{$port_id}{$vb->tag} = $dec_val, $num\n";

    #print $vb->iid, " : ", $var, "\n";
    #print $port_id, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitPortStatCountTxObjects
  #
  $mib = 'connUnitPortStatCountTxObjects'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id = $vb->iid;
    $port_id =~ s/^.+\.//g;
    $var     =~ s/"//g;

    my $dec_val = hex2dec($var);
    #$data_collect{'ports'}{$port_id}{$vb->tag}{hex} = $var;
    #$data_collect{'ports'}{$port_id}{$vb->tag}{dec} = $dec_val;
    $data_collect{'ports'}{$port_id}{$vb->tag} = $dec_val;
    #print "connUnitPortStatCountTxObjects = $data_collect{'ports'}{$port_id}{$vb->tag} = $dec_val\n";

    #print $vb->iid, " : ", $var, "\n";
    #print $port_id, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitPortStatCountRxObjects
  #
  $mib = 'connUnitPortStatCountRxObjects'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id = $vb->iid;
    $port_id =~ s/^.+\.//g;
    $var     =~ s/"//g;

    my $dec_val = hex2dec($var);
    #$data_collect{'ports'}{$port_id}{$vb->tag}{hex} = $var;
    #$data_collect{'ports'}{$port_id}{$vb->tag}{dec} = $dec_val;
    $data_collect{'ports'}{$port_id}{$vb->tag} = $dec_val;
    #print "connUnitPortStatCountRxObjects = $data_collect{'ports'}{$port_id}{$vb->tag} = $dec_val\n";

    #print $vb->iid, " : ", $var, "\n";
    #print $port_id, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitPortStatCountBBCreditZero
  #
  $mib = 'connUnitPortStatCountBBCreditZero'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id = $vb->iid;
    $port_id =~ s/^.+\.//g;
    $var     =~ s/"//g;

    my $dec_val = hex2dec($var);
    #$data_collect{'ports'}{$port_id}{$vb->tag}{hex} = $var;
    #$data_collect{'ports'}{$port_id}{$vb->tag}{dec} = $dec_val;
    $data_collect{'ports'}{$port_id}{$vb->tag} = $dec_val;

    #print $vb->iid, " : ", $var, "\n";
    #print $port_id, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitPortStatCountInvalidCRC
  #
  $mib = 'connUnitPortStatCountInvalidCRC'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id = $vb->iid;
    $port_id =~ s/^.+\.//g;
    $var     =~ s/"//g;

    my $dec_val = hex2dec($var);
    $data_collect{'ports'}{$port_id}{$vb->tag} = $dec_val;

    #print $vb->iid, " : ", $var, "\n";
    #print $port_id, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitPortName
  #
  $mib = 'connUnitPortName'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id = $vb->iid;
    $port_id =~ s/^.+\.//g;
    $var     =~ s/"//g;
    $var     =~ s/\r//g;

    $data_collect{'ports'}{$port_id}{$vb->tag} = $var;

    #print $vb->iid, " : ", $var, "\n";
    #print $port_id, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitPortSpeed
  #
  $mib = 'connUnitPortSpeed'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id = $vb->iid;
    $port_id =~ s/^.+\.//g;
    $var     =~ s/"//g;

    $data_collect{'ports'}{$port_id}{$vb->tag} = $var;
    #print "connUnitPortSpeed = $var\n";

    #print $vb->iid, " : ", $var, "\n";
    #print $port_id, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitPortWwn
  #
  $mib = 'connUnitPortWwn'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {
    my $port_id    = $vb->iid;
    my $wwn_to_cfg = $var;

    $wwn_to_cfg =~ s/"//g;
    $wwn_to_cfg =~ s/\s+$//g;
    $wwn_to_cfg =~ s/^\s+//g;
    $wwn_to_cfg =~ s/\s+/:/g;
    $port_id    =~ s/^.+\.//g;
    $var        =~ s/"//g;
    $var        =~ s/\s+//g;

    $data_collect{'ports'}{$port_id}{$vb->tag}     = $var;
    $data_collect{'ports'}{$port_id}{'wwn_to_cfg'} = $wwn_to_cfg;

    #print $vb->iid, " : ", $var, "\n";
    #print $port_id, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitPortStatCountInvalidOrderedSets
  #
  $mib = 'connUnitPortStatCountInvalidOrderedSets'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id = $vb->iid;
    $port_id =~ s/^.+\.//g;
    $var     =~ s/"//g;

    my $dec_val = hex2dec($var);
    $data_collect{'ports'}{$port_id}{$vb->tag} = $dec_val;

    #print $vb->iid, " : ", $var, "\n";
    #print $port_id, " : ", $dec_val, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  ######################
  #
  # connUnitLinkPortNumberX
  #
  $mib = 'connUnitLinkPortNumberX'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $iid = $vb->iid;
    $iid =~ s/^.+\.//g;
    $var =~ s/"//g;

    $data_collect{'ISL'}{'ports'}{$iid} = $var;
    #$data_collect{'ISL'}{$iid}{'port'} = $var;
    #print $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitLinkPortWwnX
  #
  $mib = 'connUnitLinkPortWwnX'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $iid = $vb->iid;
    $iid =~ s/^.+\.//g;
    $var =~ s/"//g;
    $var =~ s/\s+//g;

    $data_collect{'ISL'}{'map'}{$iid}{'from_wwn'} = $var;
    #print $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitLinkPortWwnY
  #
  $mib = 'connUnitLinkPortWwnY'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $iid = $vb->iid;
    $iid =~ s/^.+\.//g;
    $var =~ s/"//g;
    $var =~ s/\s+//g;

    $data_collect{'ISL'}{'map'}{$iid}{'to_wwn'} = $var;
    #print $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitRevsRevId
  #
  $mib = 'connUnitRevsRevId'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $iid = $vb->iid;
    $iid =~ s/^.+\.//g;
    $var =~ s/"//g;
    $var =~ s/\s+//g;

    if ( $iid == 1 ) { $data_collect{'configuration'}{switchType} = $var; }
    if ( $iid == 2 ) { $data_collect{'configuration'}{Fabric_OS_version} = $var; }
    #$data_collect{'configuration'}{$vb->tag} = $var;
    #print "$data_collect{'configuration'}{$vb->tag}\n";
    #print $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitPortType
  #
  $mib = 'connUnitPortType'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $iid = $vb->iid;
    $iid =~ s/^.+\.//g;
    $var =~ s/"//g;
    $var =~ s/\s+//g;

    $data_collect{'configuration'}{port}{$iid}{PortType} = $var;
    #print "$data_collect{'configuration'}{$vb->tag}\n";
    #print $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # ifName
  #
  $mib = 'ifName'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {
    #$data_collect{'ports'}{$vb->iid}{$vb->tag} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # swPortEncrypt
  #
  $mib = 'swPortEncrypt'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id = $vb->iid;
    $port_id =~ s/^.+\.//g;
    $var     =~ s/"//g;

    #print $vb->tag, ".", $vb->iid, " : ", $var,"xxx\n";
    $data_collect{'ports'}{$port_id}{$vb->tag} = $var;
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # swPortCompression
  #
  $mib = 'swPortCompression'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id = $vb->iid;
    $port_id =~ s/^.+\.//g;
    $var     =~ s/"//g;

    #print $vb->tag, ".", $vb->iid, " : ", $var,"xxx\n";
    $data_collect{'ports'}{$port_id}{$vb->tag} = $var;
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }
  ###################
  ### FCMGMT-MIB END ###

  #print Dumper(\%data_collect);
  return %data_collect;
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

#
# subs for demo only!
#
sub export_data_for_demo {
  use Storable 'nstore';
  my (%data)      = @_;
  my $act_time    = time();
  my $output_file;
  my $switch_name;

  if ( defined $data{configuration}{sysName} ) {
    $switch_name = $data{configuration}{sysName};
  }
  else {
    error( "Switch name not found! IP: $san_ip $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  foreach my $name (sort { $a <=> $b } keys (%{$data{ports}})) {
    my $port_id  = $name;
    my $db_name  = "port" . $port_id . "\.rrd";
    my $rrd_file = "$wrkdir/$switch_name/$db_name";
    my $new_data = get_last_val($rrd_file);
    # $act_time:$bytes_tra:$bytes_rec:$frames_tra:$frames_rec:$swFCPortNoTxCredits:$swFCPortRxCrcs:$port_speed
    #my ( undef, $bytes_tra_new, $bytes_rec_new, $frames_tra_new, $frames_rec_new, $swFCPortNoTxCredits_new, $swFCPortRxCrcs_new, $port_speed_new ) = split(" ",$new_data);
    # $act_time:$bytes_tra:$bytes_rec:$frames_tra:$frames_rec:$swFCPortNoTxCredits:$swFCPortRxCrcs:$port_speed:$reserve1:$reserve2:$reserve3:$reserve4:$reserve5:$reserve6
    my ( undef, $bytes_tra_new, $bytes_rec_new, $frames_tra_new, $frames_rec_new, $swFCPortNoTxCredits_new, $swFCPortRxCrcs_new, $port_speed_new, $reserve1_new, $reserve2_new, $reserve3_new, $reserve4_new, $reserve5_new, $reserve6_new ) = split(" ",$new_data);

    if ( $bytes_tra_new           ne "NaNQ" ) { $data{ports}{$name}{connUnitPortStatCountTxElements}         = sprintf '%g', $bytes_tra_new; }
    if ( $bytes_rec_new           ne "NaNQ" ) { $data{ports}{$name}{connUnitPortStatCountRxElements}         = sprintf '%g', $bytes_rec_new; }
    if ( $frames_tra_new          ne "NaNQ" ) { $data{ports}{$name}{connUnitPortStatCountTxObjects}          = sprintf '%g', $frames_tra_new; }
    if ( $frames_rec_new          ne "NaNQ" ) { $data{ports}{$name}{connUnitPortStatCountRxObjects}          = sprintf '%g', $frames_rec_new; }
    if ( $swFCPortNoTxCredits_new ne "NaNQ" ) { $data{ports}{$name}{connUnitPortStatCountBBCreditZero}       = sprintf '%g', $swFCPortNoTxCredits_new; }
    if ( $swFCPortRxCrcs_new      ne "NaNQ" ) { $data{ports}{$name}{connUnitPortStatCountInvalidCRC}         = sprintf '%g', $swFCPortRxCrcs_new; }
    if ( $port_speed_new          ne "NaNQ" ) { $data{ports}{$name}{connUnitPortSpeed}                       = sprintf '%g', $port_speed_new; }
    if ( $reserve1_new            ne "NaNQ" ) { $data{ports}{$name}{connUnitPortStatCountInvalidOrderedSets} = sprintf '%g', $reserve1_new; }

    #print "$bytes_tra_new, $bytes_rec_new, $frames_tra_new, $frames_rec_new, $swFCPortNoTxCredits_new, $swFCPortRxCrcs_new, $port_speed_new, $reserve1_new, $reserve2_new, $reserve3_new, $reserve4_new, $reserve5_new, $reserve6_new\n";
  }

  if (! -d "$wrkdir/$switch_name/demo" ) {
    mkdir("$wrkdir/$switch_name/demo", 0755) || error( "$act_time: Cannot mkdir $wrkdir/$switch_name/demo: $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  my $actual_date = sprintf("%4d-%02d-%02d", $year+1900, $mon+1, $mday);
  my $actual_time = sprintf("%2d:%02d", $hour, $min);

  # save all data in hash to file
  #$output_file = "$wrkdir/$switch_name/demo/$actual_date-$actual_time";
  $output_file = "$wrkdir/$switch_name/demo/$actual_time";
  nstore \%data, "$output_file";
}

sub import_data_for_demo {
  use Storable;
  my $switch_name = shift;

  if (! -d "$wrkdir/$switch_name/demo" ) {
    error( "Dir with fake data is not exist here! ($wrkdir/$switch_name/demo) : $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  my $actual_date = sprintf("%4d-%02d-%02d", $year+1900, $mon+1, $mday);
  my $actual_time = sprintf("%2d:%02d", $hour, $min);

  if ( -f "$wrkdir/$switch_name/demo/$actual_time" ) {
    my $input_file = "$wrkdir/$switch_name/demo/$actual_time";
    my %data       = %{retrieve("$input_file")};

    # Anonymize switch name
    # Use switch name from etc/san-list.cfg
    $data{configuration}{sysName} = $switch_name;

    # Anonymize port name
    # Use port name from $wrkdir/$switch_name/demo/fake-port.cfg
    if ( -f "$wrkdir/$switch_name/demo/fake-port.cfg" ) {
      open( FAPO, "<$wrkdir/$switch_name/demo/fake-port.cfg" ) || error( "Couldn't open file $wrkdir/$switch_name/demo/fake-port.cfg $!" . __FILE__ . ":" . __LINE__ ) && exit;
      my @fake_port_cfg = <FAPO>;
      close(FAPO);

      foreach my $name (sort { $a <=> $b } keys (%{$data{ports}})) {
        my $port_id = $name;
        if ( defined $data{ports}{$name}{connUnitPortName} && $data{ports}{$name}{connUnitPortName} ne '' ) {
          my $port_name = $data{ports}{$name}{connUnitPortName};

          my ($fake_port_line) = grep {/^$port_id :/} @fake_port_cfg;
          my ( undef, $fake_port_name ) = split(" : ",$fake_port_line);
          chomp $fake_port_name;

          $data{ports}{$name}{connUnitPortName} = $fake_port_name;
        }
      }
    }

    #print Dumper \%data;
    save_data_brcd(%data);
  }
  else {
    error( "Fake data for this time is not exist here! ($wrkdir/$switch_name/demo/*) : $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }
}

sub get_last_val {
  my $rrd_file   = shift;
  my $act_time   = time();
  #my $start_time = $act_time - 60;
  #my $end_time   = $act_time - 10;
  # last value before one hour
  my $start_time = $act_time - 3600;
  my $end_time   = $act_time - 3550;
  my $return     = "";

  RRDp::cmd qq(fetch "$rrd_file" AVERAGE --start $start_time --end $end_time);
  my $data     = RRDp::read;
  my @data_all = split("\n",$$data);

  my $founded_lines = 0;
  foreach my $line (@data_all) {
    chomp $line;
    $line =~ s/^\s+//g;
    if ( $line =~ m/^[0-9]/ && $founded_lines == 0 ) {
      $return = $line;
      $founded_lines++;
    }
  }

  return $return;
}

sub hex2dec {
  my $num = shift;

  $num =~ s/\s+//g;
  my $hex = "0x$num";

  use Math::BigInt;
  my $dec = Math::BigInt->new($hex);

  return($dec);
}

sub bignum {
  my $bnum = shift;

  use Math::BigInt;
  my $num = Math::BigInt->new($bnum);

  return($num);
}


###########
#  CISCO  #
###########

sub collect_data_cisco {

  my $dest       = shift;
  my $comm       = 'public';
  my $mib        = 'sysDescr';
  my $sver       = '2c';
  my $timeout    = '50000000';
  my $SecName    = "snmpuser1";
  my $RemotePort = "";

  # SNMP option
  if ( defined $ENV{SNMP_VERSION} && $ENV{SNMP_VERSION} ne '' ) {
    if ( $ENV{SNMP_VERSION} == 3 || $ENV{SNMP_VERSION} eq "2c" ) {
      $sver = $ENV{SNMP_VERSION};
    }
    else {
      error( "Unknown SNMP version in etc/san-list.cfg! Automatically used SNMP version \"$sver\"! $!" . __FILE__ . ":" . __LINE__ );
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

  my $sess; # The SNMP::Session object that does the work.
  my $var;  # Used to hold the individual responses.
  my $vb;   # The Varbind object used for the 'real' query.

  my %data_collect;
  my %snmpparms;

  #my $start_time = localtime();

  # Initialize the MIB (else you can't do queries).
  &SNMP::addMibDirs("$basedir/MIBs/");
  #&SNMP::loadModules('SW-MIB' , 'Brocade-REG-MIB' , 'Brocade-TC' , 'FCMGMT-MIB');
  &SNMP::loadModules('SW-MIB' , 'Brocade-REG-MIB' , 'Brocade-TC' , 'FCMGMT-MIB' , 'CISCO-FC-FE-MIB', 'CISCO-DM-MIB');
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
    # Done as a block since you may not always want to die
    # in here.  You could set up another query, just go on,
    # or whatever...
  }
  $data_collect{'configuration'}{$vb->tag} = $var;
  #print $vb->tag, ".", $vb->iid, " : $var\n";

  # Now let's show a MIB that might return multiple instances.

  #
  # sysName
  #
  $mib = 'sysName'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {
    $data_collect{'configuration'}{$vb->tag} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # swFCPortPhyState
  #
  $mib = 'swFCPortPhyState'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {
    $data_collect{'ports'}{$vb->iid}{$vb->tag} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # swFCPortOpStatus
  #
  $mib = 'swFCPortOpStatus'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {
    $data_collect{'ports'}{$vb->iid}{$vb->tag} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # fcFeFabricName
  #
  #$mib = '1.3.6.1.2.1.75.1.1.1'; # The ARP table!
  $mib = '1.3.6.1.4.1.9.9.302.1.1.1.1.9'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb) ) {
    $var =~ s/"//g;
    $data_collect{'configuration'}{fcFeFabricName} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var,"\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # fcFeElementName
  #
  #$mib = '1.3.6.1.2.1.75.1.1.2'; # The ARP table!
  $mib = '1.3.6.1.4.1.9.9.302.1.1.1.1.10'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb) ) {
    $var =~ s/"//g;
    $data_collect{'configuration'}{fcFeElementName} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var,"\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # ifName
  #
  $mib = 'ifName'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {
    $data_collect{'ports'}{$vb->iid}{$vb->tag} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # ifAlias
  #
  $mib = 'ifAlias'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {
    $data_collect{'ports'}{$vb->iid}{$vb->tag} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # ifHCOutOctets
  #
  $mib = 'ifHCOutOctets'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {
    my $num = int($var / 4);
    $data_collect{'ports'}{$vb->iid}{$vb->tag} = $num;
    #print $vb->tag, ".", $vb->iid, " : ", $var, "\n";
    #my $int = int($var/4);
    #if ($vb->iid == '16777216' ) { print $vb->tag, ".", $vb->iid, " : ", $var, "num=$num,int=$int\n"; }
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # ifHCInOctets
  #
  $mib = 'ifHCInOctets'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {
    my $num = int($var / 4);
    $data_collect{'ports'}{$vb->iid}{$vb->tag} = $num;
    #print $vb->tag, ".", $vb->iid, " : ", $var, "\n";
    #my $int = int($var/4);
    #if ($vb->iid == '16777216' ) { print $vb->tag, ".", $vb->iid, " : ", $var, "num=$num,int=$int\n"; }
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # ifHCOutUcastPkts
  #
  $mib = 'ifHCOutUcastPkts'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {
    $data_collect{'ports'}{$vb->iid}{$vb->tag} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # ifHCInUcastPkts
  #
  $mib = 'ifHCInUcastPkts'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {
    $data_collect{'ports'}{$vb->iid}{$vb->tag} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # ifType
  #
  $mib = 'ifType'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {
    $data_collect{'ports'}{$vb->iid}{$vb->tag} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # ifOperStatus
  #
  $mib = 'ifOperStatus'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {
    $data_collect{'ports'}{$vb->iid}{$vb->tag} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # ifAdminStatus
  #
  $mib = 'ifAdminStatus'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {
    $data_collect{'ports'}{$vb->iid}{$vb->tag} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # ifHighSpeed
  #
  $mib = 'ifHighSpeed'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {
    if ( defined $var && isdigit($var) ) {
      $var = ($var / 8) * 1000;
      $var = int($var);
      $data_collect{'ports'}{$vb->iid}{$vb->tag} = $var;
      #print $vb->tag, ".", $vb->iid, " : ", $var, "\n";
    }
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitPortWwn
  #
  $mib = 'connUnitPortWwn'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $port_id    = $vb->iid;
    my $wwn_to_cfg = $var;

    $wwn_to_cfg =~ s/"//g;
    $wwn_to_cfg =~ s/\s+$//g;
    $wwn_to_cfg =~ s/^\s+//g;
    $wwn_to_cfg =~ s/\s+/:/g;
    $port_id    =~ s/^.+\.//g;
    $var        =~ s/"//g;
    $var        =~ s/\s+//g;

    $data_collect{'ports'}{$port_id}{$vb->tag}     = $var;
    $data_collect{'ports'}{$port_id}{'wwn_to_cfg'} = $wwn_to_cfg;

    #print $vb->iid, " : ", $var, "\n";
    #print $port_id, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitLinkPortWwnY
  #
  $mib = 'connUnitLinkPortWwnY'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $iid = $vb->iid;
    $iid =~ s/^.+\.//g;
    $var =~ s/"//g;
    $var =~ s/\s+//g;

    $data_collect{'ISL'}{'map'}{$iid}{'to_wwn'} = $var;
    #print $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # fcIfInvalidCrcs
  #
  $mib = 'fcIfInvalidCrcs'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $iid = $vb->iid;
    $iid =~ s/^.+\.//g;
    $var =~ s/"//g;
    $var =~ s/\s+//g;

    $data_collect{'ports'}{$vb->iid}{$vb->tag} = $var;
    #print $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # fcIfBBCreditTransistionFromZero
  #
  $mib = 'fcIfBBCreditTransistionFromZero'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $iid = $vb->iid;
    $iid =~ s/^.+\.//g;
    $var =~ s/"//g;
    $var =~ s/\s+//g;

    $data_collect{'ports'}{$vb->iid}{$vb->tag} = $var;
    #print $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # fcIfOperStatusCause
  #
  $mib = 'fcIfOperStatusCause'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $iid = $vb->iid;
    $iid =~ s/^.+\.//g;
    $var =~ s/"//g;
    $var =~ s/\s+//g;

    $data_collect{'ports'}{$vb->iid}{$vb->tag} = $var;
    #print $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  ### VSAN
  #
  # vsanIfVsan
  #
  $mib = 'vsanIfVsan'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $iid = $vb->iid;
    $iid =~ s/^.+\.//g;
    $var =~ s/"//g;
    $var =~ s/\s+//g;

    my $port_name = "";
    if (defined $data_collect{'ports'}{$iid}{'ifName'} && $data_collect{'ports'}{$iid}{'ifName'} ne '' ) {
      $port_name = $data_collect{'ports'}{$iid}{'ifName'};
    }
    $data_collect{'configuration'}{vsan}{$var}{ports}{$iid} = $port_name;
    #print $vb->iid, " : ", $var, "   $data_collect{'ports'}{$iid}{'ifName'}\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # vsanName
  #
  $mib = 'vsanName'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $vsan_id = $vb->iid;
    $vsan_id =~ s/^.+\.//g;
    $var =~ s/"//g;
    $var =~ s/\s+//g;

    $data_collect{'configuration'}{vsan}{$vsan_id}{vsanName} = $var;
    #print $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # dmPrincipalSwitchWwn
  #
  $mib = 'dmPrincipalSwitchWwn'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $vsan_id = $vb->iid;
    $vsan_id =~ s/^.+\.//g;
    $var =~ s/"//g;
    $var =~ s/\s+//g;

    $data_collect{'configuration'}{vsan}{$vsan_id}{dmPrincipalSwitchWwn} = $var;
    #print $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # dmLocalSwitchWwn
  #
  $mib = 'dmLocalSwitchWwn'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $vsan_id = $vb->iid;
    $vsan_id =~ s/^.+\.//g;
    $var =~ s/"//g;
    $var =~ s/\s+//g;

    $data_collect{'configuration'}{vsan}{$vsan_id}{dmLocalSwitchWwn} = $var;
    #print $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # zoneSetName
  #
  $mib = 'zoneSetName'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $vsan_id = $vb->iid;
    $vsan_id =~ s/\.[0-9]+$//g;
    $vsan_id =~ s/^.+\.//g;
    $var =~ s/"//g;
    $var =~ s/\s+//g;

    $data_collect{'configuration'}{zones}{$vsan_id}{zoneSetName} = $var;
    #print $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # zoneName
  #
  $mib = 'zoneName'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $vsan_id = $vb->iid;
    my $zone_id = $vb->iid;
    $vsan_id =~ s/\.[0-9]+$//g;
    $vsan_id =~ s/^.+\.//g;
    $zone_id =~ s/^.+\.//g;
    $var =~ s/"//g;
    $var =~ s/\s+//g;

    $data_collect{'configuration'}{zones}{$vsan_id}{zoneID}{$zone_id}{zoneName} = $var;
    #print $vb->iid, " : ", $var, "\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # zoneMemberID
  #
  $mib = 'zoneMemberID'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb);
        ($vb->tag eq $mib) and not ($sess->{ErrorNum});
        $var = $sess->getnext($vb)
      ) {

    my $id_line = $vb->iid;
    $id_line =~ s/^.+\.\([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\)/$1/g;
    $id_line =~ s/\./,/g;
    my ($vsan_id, undef, $zone_id, $alias_id) = split(",",$id_line);

    $var =~ s/"//g;
    $var =~ s/\s+//g;

    $data_collect{'configuration'}{zones}{$vsan_id}{zoneID}{$zone_id}{zoneMemberID}{$alias_id} = $var;
    #print $vb->iid, " : ", $var, "\n";
    #print "$id_line=$var\n";
    #print "$vsan_id, undef, $zone_id, $alias_id\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # sysUpTime
  #
  $mib = 'sysUpTime'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb) ) {
    $var =~ s/"//g;
    $data_collect{'configuration'}{'sysUpTime'} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var,"xxx\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitSn
  #
  $mib = 'connUnitSn'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb) ) {
    $var =~ s/"//g;
    $data_collect{'configuration'}{'connUnitSn'} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var,"xxx\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  #
  # connUnitUrl
  #
  $mib = 'connUnitUrl'; # The ARP table!
  $vb = new SNMP::Varbind([$mib]);  # No instance this time.
  for ( $var = $sess->getnext($vb) ) {
    $var =~ s/"//g;
    $data_collect{'configuration'}{'connUnitUrl'} = $var;
    #print $vb->tag, ".", $vb->iid, " : ", $var,"xxx\n";
  }
  if ($sess->{ErrorNum}) {
    error( "Got $sess->{ErrorStr} querying $dest for $mib. $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }



  #my $end_time = localtime();
  #print "start collect data: $start_time - end collect data: $end_time\n";
  #print Dumper(\%data_collect);

  save_data_cisco(%data_collect);

  exit;
}

sub save_data_cisco {
  my (%data) = @_;
  my $switch_name;
  my $act_time = time();

  if ( defined $data{configuration}{sysName} ) {
    $switch_name = $data{configuration}{sysName};
  }
  else {
    error( "Switch name not found! IP: $san_ip $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  if (! -d "$wrkdir/$switch_name" ) {
    mkdir("$wrkdir/$switch_name", 0755) || error( "$act_time: Cannot mkdir $wrkdir/$switch_name: $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  # output file
  my ( $sec, $min, $hour, $day, $month, $year, $wday, $yday, $isdst ) = localtime();
  my $date = sprintf( "%4d%02d%02d",  $year + 1900, $month + 1, $day );
  my $time = sprintf( "%02d%02d", $hour, $min);
  my $output_file = "$wrkdir/$switch_name/$switch_name\_sanperf_$date\_$time.out.tmp\n";
  open( OUT, ">$output_file" ) || error( "Couldn't open file $output_file $!" . __FILE__ . ":" . __LINE__ ) && exit;

  # output file header
  print OUT "act_time,bytes_tra,bytes_rec,frames_tra,frames_rec,swFCPortNoTxCredits,swFCPortRxCrcs,port_speed,reserve1,reserve2,reserve3,reserve4,reserve5,reserve6,switch_name,db_name,rrd_file\n";

  my @health_status_data;

  my $ports_cfg        = "$wrkdir/$switch_name/PORTS.cfg";
  my $ports_cfg_suffix = "$ports_cfg-tmp";
  open( PCFG, ">$ports_cfg_suffix" ) || error( "Couldn't open file $ports_cfg_suffix $!" . __FILE__ . ":" . __LINE__ ) && exit;

  foreach my $name (sort { $a <=> $b } keys (%{$data{ports}})) {
    my $bytes_tra           = ""; # transmitted
    my $bytes_rec           = ""; # received
    my $frames_tra          = ""; # transmitted
    my $frames_rec          = ""; # received
    my $swFCPortNoTxCredits = ""; # Counts the number of times that the transmit credit has reached 0.
    my $swFCPortRxCrcs      = ""; # Counts the number of CRC errors detected for frames received.
    my $port_speed          = "";
    my $port_id             = "";
    my $port_name           = "";
    my $port_wwn            = "";
    my $db_name;
    my $rrd_file;
    my $swFCPortPhyState    = "";
    my $swFCPortOpStatus    = "";
    my $fcIfOperStatusCause = "";
    my $reserve1            = ""; #connUnitPortStatCountInvalidOrderedSets
    my $reserve2            = "";
    my $reserve3            = "";
    my $reserve4            = "";
    my $reserve5            = "";
    my $reserve6            = "";

    $port_id = $name;
    #if ( ! defined $data{ports}{$name}{ifType} || $data{ports}{$name}{ifType} ne 'fibreChannel' ) { next; } # test port type
    if ( defined $data{ports}{$name}{ifName} && $data{ports}{$name}{ifName} ne '' ) {
      $port_id = $data{ports}{$name}{ifName};
      $port_id =~ s/\//-/;
      $port_id =~ s/^port-channel/portChannel/;
      $port_id =~ s/\s+/_/;
    }
    else {
      error( "Not defined port id for port $name! $!" . __FILE__ . ":" . __LINE__ ) && next;
    }
    if ( $data{ports}{$name}{ifName} !~ "^fc|^port-channel|^Ethernet|^GigabitEthernet" ) { next; }

    if ( defined $data{ports}{$name}{ifAlias} ) {
      $port_name = $data{ports}{$name}{ifAlias};
    }
    if ( defined $data{ports}{$name}{ifHCOutOctets} && isdigit($data{ports}{$name}{ifHCOutOctets}) ) {
      $bytes_tra = $data{ports}{$name}{ifHCOutOctets};
    }
    if ( defined $data{ports}{$name}{ifHCInOctets} && isdigit($data{ports}{$name}{ifHCInOctets}) ) {
      $bytes_rec = $data{ports}{$name}{ifHCInOctets};
    }
    if ( defined $data{ports}{$name}{ifHCOutUcastPkts} && isdigit($data{ports}{$name}{ifHCOutUcastPkts}) ) {
      $frames_tra = $data{ports}{$name}{ifHCOutUcastPkts};
    }
    if ( defined $data{ports}{$name}{ifHCInUcastPkts} && isdigit($data{ports}{$name}{ifHCInUcastPkts}) ) {
      $frames_rec = $data{ports}{$name}{ifHCInUcastPkts};
    }
    if ( defined $data{ports}{$name}{fcIfBBCreditTransistionFromZero} && isdigit($data{ports}{$name}{fcIfBBCreditTransistionFromZero}) ) {
      if ( $port_id =~ "^fc" || $port_id =~ "^portChannel" ) {
        $swFCPortNoTxCredits = $data{ports}{$name}{fcIfBBCreditTransistionFromZero};
      }
    }
    if ( defined $data{ports}{$name}{fcIfInvalidCrcs} && isdigit($data{ports}{$name}{fcIfInvalidCrcs}) ) {
      $swFCPortRxCrcs = $data{ports}{$name}{fcIfInvalidCrcs};
    }

    ## port status
    #if ( defined $data{ports}{$name}{ifAdminStatus} && defined $data{ports}{$name}{ifOperStatus} ) {
    #  print "$port_id : admin_st=$data{ports}{$name}{ifAdminStatus},oper_st=$data{ports}{$name}{ifOperStatus},\n";
    #}

    #if ( defined $data{ports}{$name}{connUnitPortStatCountInvalidOrderedSets} && isdigit($data{ports}{$name}{connUnitPortStatCountInvalidOrderedSets}) ) {
    #  $reserve1 = $data{ports}{$name}{connUnitPortStatCountInvalidOrderedSets};
    #}
    if ( defined $data{ports}{$name}{ifHighSpeed} && isdigit($data{ports}{$name}{ifHighSpeed}) ) {
      $port_speed = $data{ports}{$name}{ifHighSpeed};
    }
    if ( defined $data{ports}{$name}{ifAdminStatus} ) {
      $swFCPortPhyState = $data{ports}{$name}{ifAdminStatus};
    }
    if ( defined $data{ports}{$name}{ifOperStatus} ) {
      $swFCPortOpStatus = $data{ports}{$name}{ifOperStatus};
    }
    if ( defined $data{ports}{$name}{fcIfOperStatusCause} ) {
      $fcIfOperStatusCause = $data{ports}{$name}{fcIfOperStatusCause};
    }
    if ( defined $data{ports}{$name}{connUnitPortWwn} ) {
      $port_wwn = $data{ports}{$name}{connUnitPortWwn};
    }
    push(@health_status_data, "$port_id,$swFCPortPhyState,$swFCPortOpStatus,$fcIfOperStatusCause\n");
    #print "$port_id,$swFCPortPhyState,$swFCPortOpStatus,$fcIfOperStatusCause\n";

    ## if port is disabled, then CRC errors must be NaN.
    #if ( $swFCPortPhyState eq "inSync" && $swFCPortOpStatus eq "offline" ) {
    #  $swFCPortRxCrcs      = "U";
    #  #print "$act_time : Port $port_id is disabled!!!\n";
    #}

    ## if operational status is offline, then frames in/out must be NaN.
    #if ( $swFCPortOpStatus eq "offline" ) {
    #  $frames_tra = "U";
    #  $frames_rec = "U";
    #}


    if ( ! -d "$wrkdir/$switch_name" ) {
      mkdir("$wrkdir/$switch_name");
    }
    if ( ! -f "$wrkdir/$switch_name/SAN-CISCO" ) {
      open( CISC, ">$wrkdir/$switch_name/SAN-CISCO" ) || error( "Couldn't open file $wrkdir/$switch_name/SAN-CISCO $!" . __FILE__ . ":" . __LINE__ ) && exit;
      close(CISC);
    }

    $db_name = "port" . $port_id . "\.rrd";
    $rrd_file = "$wrkdir/$switch_name/$db_name";

    print PCFG "port$port_id : $rrd_file : $port_name : $port_wwn\n";
    print OUT "$act_time,$bytes_tra,$bytes_rec,$frames_tra,$frames_rec,$swFCPortNoTxCredits,$swFCPortRxCrcs,$port_speed,$reserve1,$reserve2,$reserve3,$reserve4,$reserve5,$reserve6,$switch_name,$db_name,$rrd_file\n";
  }
  close(OUT);
  close(PCFG);
  rename "$ports_cfg_suffix", "$ports_cfg";

  # health status
  if (! -d "$webdir/$switch_name" ) {
    mkdir("$webdir/$switch_name", 0755) || error( "$act_time: Cannot mkdir $webdir/$switch_name: $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }

  my $health_status_html =  "$webdir/$switch_name/health_status.html";
  my $act_timestamp      = time();
  my $hs_timestamp       = $act_timestamp;
  my $last_update        = localtime($act_timestamp);
  my $timestamp_diff     = 0;

  if ( -f $health_status_html ) {
    $hs_timestamp   = (stat($health_status_html))[9];
    $timestamp_diff = $act_timestamp - $hs_timestamp;
  }

  if ( ! -f $health_status_html || $timestamp_diff > 299 ) {
    health_status_cisco(\@health_status_data,$health_status_html,$last_update,$switch_name);
  }

  # Fabric part
  if ( defined $data{configuration}{fcFeFabricName} && defined $data{configuration}{fcFeElementName}  ) {
    my $fcFeFabricName  = $data{configuration}{fcFeFabricName};
    my $fcFeElementName = $data{configuration}{fcFeElementName};
    $fcFeFabricName =~ s/"//g;
    $fcFeFabricName =~ s/\s+//g;
    $fcFeElementName =~ s/"//g;
    $fcFeElementName =~ s/\s+//g;

    my $fabric_name = "";
    if ( -f "$basedir/etc/san-list.cfg") {
      open( SL, "<$basedir/etc/san-list.cfg" ) || error( "Couldn't open file $basedir/etc/san-list.cfg $!" . __FILE__ . ":" . __LINE__ );
      my @san_cfg = <SL>;
      close(SL);
      my ($line) = grep {/^$san_ip:/} @san_cfg;
      chomp $line;
      my (undef, undef, undef, $fab_name) = split(":",$line);
      if ( defined $fab_name && $fab_name ne "" ) {
        chomp $fab_name;
        $fabric_name = $fab_name;
      }
    }

    open( FC, ">$wrkdir/$switch_name/fabric.txt" ) || error( "Couldn't open file $wrkdir/$switch_name/fabric.txt $!" . __FILE__ . ":" . __LINE__ ) && exit;
    print FC "$fcFeFabricName,$fcFeElementName,$switch_name,$fabric_name\n";
    close(FC);
  }
  else {
    error( "fcFeFabricName or fcFeElementName not found! IP: $san_ip $!" . __FILE__ . ":" . __LINE__ );
  }

  # vsan part
  if ( defined $data{configuration}{vsan} ) {

    open( VSAN, ">$wrkdir/$switch_name/vsan.txt" ) || error( "Couldn't open file $wrkdir/$switch_name/vsan.txt $!" . __FILE__ . ":" . __LINE__ ) && exit;

    foreach my $vsan_id (sort { $a <=> $b } keys (%{$data{configuration}{vsan}})) {
      chomp $vsan_id;
      my $vsan_name             = "";
      my $principal_vsan_sw_wwn = "";
      my $vsan_sw_wwn           = "";

      if ( defined $data{configuration}{vsan}{$vsan_id}{vsanName} && $data{configuration}{vsan}{$vsan_id}{vsanName} ne '' ) {
        $vsan_name = $data{configuration}{vsan}{$vsan_id}{vsanName};
      }
      else {
        $vsan_name = "vsan_$vsan_id";
      }
      if ( defined $data{configuration}{vsan}{$vsan_id}{dmPrincipalSwitchWwn} && $data{configuration}{vsan}{$vsan_id}{dmPrincipalSwitchWwn} ne '' ) {
        $principal_vsan_sw_wwn = $data{configuration}{vsan}{$vsan_id}{dmPrincipalSwitchWwn};
        $principal_vsan_sw_wwn =~ s/"//g;
        $principal_vsan_sw_wwn =~ s/\s+//g;
      }
      if ( defined $data{configuration}{vsan}{$vsan_id}{dmLocalSwitchWwn} && $data{configuration}{vsan}{$vsan_id}{dmLocalSwitchWwn} ne '' ) {
        $vsan_sw_wwn = $data{configuration}{vsan}{$vsan_id}{dmLocalSwitchWwn};
        $vsan_sw_wwn =~ s/"//g;
        $vsan_sw_wwn =~ s/\s+//g;
      }
      # vsan ports
      if ( defined $data{configuration}{vsan}{$vsan_id}{ports} && $data{configuration}{vsan}{$vsan_id}{ports} ne '' ) {
        my $port_name = "";
        foreach my $port_id (sort { $a <=> $b } keys (%{$data{configuration}{vsan}{$vsan_id}{ports}})) {
          chomp $port_id;
          if ( defined $data{configuration}{vsan}{$vsan_id}{ports}{$port_id} && $data{configuration}{vsan}{$vsan_id}{ports}{$port_id} ne '' ) {
            if ( $data{configuration}{vsan}{$vsan_id}{ports}{$port_id} !~ "^fc|^port-channel|^Ethernet" ) { next; }
            $port_name = $data{configuration}{vsan}{$vsan_id}{ports}{$port_id};
            $port_name =~ s/^port-channel/portChannel/;
            $port_name =~ s/\//-/;
            $port_name =~ s/\s+/_/;

            print VSAN "$principal_vsan_sw_wwn : $vsan_sw_wwn : $switch_name : $vsan_id : $vsan_name : port$port_name : $wrkdir/$switch_name/port$port_name.rrd\n";
          }
        }
      }
      else { next; } # if vsan hasnt ports, then go to next vsan
    }
    close(VSAN);
  }
  #else {
  #  error( "vSan not found! IP: $san_ip $!" . __FILE__ . ":" . __LINE__ );
  #}

  # ISL part
  open( ISL, ">$wrkdir/$switch_name/ISL.txt" ) || error( "Couldn't open file $wrkdir/$switch_name/ISL.txt $!" . __FILE__ . ":" . __LINE__ ) && exit

  my @all_ports;
  my @switches_all = <$wrkdir/*\/SAN-*>;
  foreach my $sw_name (@switches_all) {
    chomp $sw_name;
    $sw_name =~ s/^$wrkdir\///g;
    $sw_name =~ s/\/SAN-BRCD$//g;
    $sw_name =~ s/\/SAN-CISCO$//g;

    open( ALP, "<$wrkdir/$sw_name/PORTS.cfg" ) || error( "Couldn't open file $wrkdir/$sw_name/PORTS.cfg $!" . __FILE__ . ":" . __LINE__ ) && exit;
    my @ports = <ALP>;
    close(ALP);

    foreach my $line (@ports) {
      chomp $line;
      push(@all_ports, "$sw_name : $line\n");
    }
  }

  my $isl_count = 0;
  my $id_index = 0;
  foreach my $id_line (sort { $a <=> $b } keys (%{$data{ISL}{map}})) {
    $id_index++;
    #if ( $id_index ne $id_line ) { next; }
    my $from_wwn  = "";
    my $from_sw   = "";
    my $from_port = "";
    my $from_line = "";
    my $to_wwn    = "";
    my $to_sw     = "";
    my $to_port   = "";
    my $to_line   = "";
    #if ( defined $data{ISL}{map}{$id_line}{from_wwn} && $data{ISL}{map}{$id_line}{from_wwn} ne '' ) {
    #  $from_wwn = $data{ISL}{map}{$id_line}{from_wwn};
    #}
    if ( defined $data{ports}{$id_line}{connUnitPortWwn} && $data{ports}{$id_line}{connUnitPortWwn} ne '' ) {
      $from_wwn = $data{ports}{$id_line}{connUnitPortWwn};
      $isl_count++;
    }
    else { next; }
    if ( defined $data{ISL}{map}{$id_line}{to_wwn} && $data{ISL}{map}{$id_line}{to_wwn} ne '' ) {
      $to_wwn = $data{ISL}{map}{$id_line}{to_wwn};
      $to_wwn =~ s/0000000000000000$//;
    }
    if ( grep {/$from_wwn$/} @all_ports ) {
      ($from_line) = grep {/$from_wwn$/} @all_ports;
      chomp $from_line;
      #print "from $from_line\n";
      ($from_sw, $from_port, undef) = split(" : ",$from_line);
    }
    if ( grep {/$to_wwn$/} @all_ports ) {
      ($to_line) = grep {/$to_wwn$/} @all_ports;
      chomp $to_line;
      #print "to $to_line\n";
      ($to_sw, $to_port, undef) = split(" : ",$to_line);
    }
    #print "FROM : $from_sw : $from_port   --->   TO : $to_sw : $to_port\n";
    if ( -f "$wrkdir/$from_sw/$from_port.rrd" ) {
      print ISL "$from_port,$wrkdir/$from_sw/$from_port.rrd,$from_sw,to_port=$to_port,to_switch=$to_sw\n";
    }
    else {
      error( "$from_sw : RRDfile for inter switch link not found! ISL=$from_port, RRD=$wrkdir/$from_sw/$from_port.rrd $!" . __FILE__ . ":" . __LINE__ );
    }
  }
  close(ISL);
  if ( $isl_count == 0 ) {
    unlink ("$wrkdir/$switch_name/ISL.txt");
  }

  # Configuration
  my $glob_config_html   =  "$webdir/$switch_name/glob_config.html";
  my $config_html        =  "$webdir/$switch_name/config.html";
  my $zones_html         =  "$webdir/$switch_name/zones.html";
  my $act_timestamp_cfg  = time();
  my $cfg_timestamp      = $act_timestamp_cfg;
  my $last_update_cfg    = localtime($act_timestamp_cfg);
  my $timestamp_diff_cfg = 0;

  if ( -f $config_html ) {
    $cfg_timestamp      = (stat($config_html))[9];
    $timestamp_diff_cfg = $act_timestamp_cfg - $cfg_timestamp;
  }

  if ( ! -f $config_html || $timestamp_diff_cfg > 3599 ) {

    open( GCFG, ">$glob_config_html" ) || error( "Couldn't open file $glob_config_html $!" . __FILE__ . ":" . __LINE__ ) && exit;
    print GCFG "<div  id=\"tabs\"> <ul>\n";
    print GCFG "<li><a href=\"$switch_name/config.html\">Switch</a></li>\n";
    print GCFG "<li><a href=\"$switch_name/zones.html\">Zones</a></li>\n";
    print GCFG "</ul> </div>\n";
    close(GCFG);

    # zones
    open( ZCFG, ">$zones_html" ) || error( "Couldn't open file $zones_html $!" . __FILE__ . ":" . __LINE__ ) && exit;

    print ZCFG "<br>\n";
    print ZCFG "<center><table class =\"tabcfgsumext\"><tr>\n";

    foreach my $zoneset_id (sort { $a <=> $b } keys (%{$data{configuration}{zones}})) {
      my $zoneSetName = "";
      if ( defined $data{configuration}{zones}{$zoneset_id}{zoneSetName} && $data{configuration}{zones}{$zoneset_id}{zoneSetName} ne '' ) {
        $zoneSetName = $data{configuration}{zones}{$zoneset_id}{zoneSetName};
      }
      else {
        error( "Not defined zoneSetName for zoneSet id $zoneset_id! $!" . __FILE__ . ":" . __LINE__ ) && next;
      }
      print ZCFG "<td><center><table class =\"tabcfgsum tablesorter tablesortercfgsum\"><thead><tr><th colspan=\"2\" style=\"text-align:center;\">$zoneSetName</th></tr>\n";
      print ZCFG "<tr><th class = \"sortable\" style=\"text-align:center; color:black;\">Name</th><th style=\"text-align:center; color:black;\">Aliases</th></tr></thead><tbody>\n";

      my $zoneName    = "";
      foreach my $zone_id (sort { $a <=> $b } keys (%{$data{configuration}{zones}{$zoneset_id}{zoneID}})) {
        if ( defined $data{configuration}{zones}{$zoneset_id}{zoneID}{$zone_id}{zoneName} && $data{configuration}{zones}{$zoneset_id}{zoneID}{$zone_id}{zoneName} ne '' ) {
          $zoneName = $data{configuration}{zones}{$zoneset_id}{zoneID}{$zone_id}{zoneName};
        }
        print ZCFG "<tr><td style=\"text-align:left;\"><b>$zoneName</b></td><td>\n";

        my $zoneAlias = "";
        my $alias_idx = 0;
        foreach my $zone_al_id (sort { $a <=> $b } keys (%{$data{configuration}{zones}{$zoneset_id}{zoneID}{$zone_id}{zoneMemberID}})) {
          if ( defined $data{configuration}{zones}{$zoneset_id}{zoneID}{$zone_id}{zoneMemberID}{$zone_al_id} && $data{configuration}{zones}{$zoneset_id}{zoneID}{$zone_id}{zoneMemberID}{$zone_al_id} ne '' ) {
            $zoneAlias = $data{configuration}{zones}{$zoneset_id}{zoneID}{$zone_id}{zoneMemberID}{$zone_al_id};
            $alias_idx++;
          }
          if ( $alias_idx % 2 == 0 ) {
            print ZCFG "$zoneAlias<br>\n";
          }
          else {
            print ZCFG "$zoneAlias \n";
          }
        }
        $zoneAlias = "";
        print ZCFG "</td></tr>\n";
      }

      print ZCFG "</tbody></table></center></td>\n";
    }
    print ZCFG "</tr></table></center>\n";
    close(ZCFG);

    # config.cfg for global configuration
    config_cfg_cisco(%data);
  }

}

sub config_cfg_cisco {
  my (%data) = @_;

  # all configuration variables per switch
  my $switch_name            = "";
  my $switch_ip              = "";
  my $switch_wwn             = "";
  my $switch_model           = "";
  my $switch_speed           = "";
  my $switch_os_version      = "";
  my $switch_fabric_name     = "";
  my $switch_days_up         = "";
  my $switch_serial_number   = "";
  my $switch_total_ports     = "";
  my $switch_unused_ports    = "";
  my $switch_total_isl_ports = "";

  if ( defined $data{configuration}{sysName} ) {
    $switch_name = $data{configuration}{sysName};
  }
  if ( defined $data{configuration}{fcFeElementName} ) {
    $switch_wwn = $data{configuration}{fcFeElementName};
    $switch_wwn =~ s/^\s+//g;
    $switch_wwn =~ s/\s+$//g;
    $switch_wwn =~ s/\s+/:/g;
  }
  if ( defined $data{configuration}{sysUpTime} ) {
    ($switch_days_up, undef) = split(":", $data{configuration}{sysUpTime});
  }
  if ( defined $data{configuration}{connUnitSn} ) {
    $switch_serial_number = $data{configuration}{connUnitSn};
  }
  if ( defined $data{configuration}{connUnitUrl} ) {
    $switch_ip = $data{configuration}{connUnitUrl};
    $switch_ip =~ s/http://;
    $switch_ip =~ s/\///g;
  }
  if ( -f "$wrkdir/$switch_name/ISL.txt" ) {
    open( ISL, "<$wrkdir/$switch_name/ISL.txt" ) || error( "Couldn't open file $wrkdir/$switch_name/ISL.txt $!" . __FILE__ . ":" . __LINE__ ) && next;
    my @isl = <ISL>;
    close(ISL);
    $switch_total_isl_ports = @isl;
  }
  else {
    $switch_total_isl_ports = "0";
  }
  if ( -f "$wrkdir/$switch_name/PORTS.cfg" ) {
    open( PORTS, "<$wrkdir/$switch_name/PORTS.cfg" ) || error( "Couldn't open file $wrkdir/$switch_name/PORTS.cfg $!" . __FILE__ . ":" . __LINE__ ) && next;
    my @ports = <PORTS>;
    close(PORTS);
    $switch_total_ports = @ports;
  }
  if ( defined $data{configuration}{sysDescr} ) {
    my ($switchType, $sysDescr, $Fabric_OS_version, undef) = split(", ",$data{configuration}{sysDescr});
    $switch_model      = "$switchType";
    $switch_os_version = "$sysDescr, $Fabric_OS_version";
  }

  my $unused_ports_count = 0;
  foreach my $name (sort { $a <=> $b } keys (%{$data{ports}})) {
    if ( defined $data{ports}{$name}{fcIfOperStatusCause} && $data{ports}{$name}{fcIfOperStatusCause} =~ "fcotNotPresent" ) {
      $unused_ports_count++;
    }
  }
  $switch_unused_ports = $unused_ports_count;




  my $config_cfg = "$wrkdir/$switch_name/config.cfg";
  open( SCFG, ">$config_cfg" ) || error( "Couldn't open file $config_cfg $!" . __FILE__ . ":" . __LINE__ ) && next;

  print SCFG "switch_name=$switch_name\n";
  print SCFG "switch_ip=$switch_ip\n";
  print SCFG "switch_wwn=$switch_wwn\n";
  print SCFG "switch_model=$switch_model\n";
  print SCFG "switch_speed=$switch_speed\n";
  print SCFG "switch_os_version=$switch_os_version\n";
  print SCFG "switch_fabric_name=$switch_fabric_name\n";
  print SCFG "switch_days_up=$switch_days_up\n";
  print SCFG "switch_serial_number=$switch_serial_number\n";
  print SCFG "switch_total_ports=$switch_total_ports\n";
  print SCFG "switch_unused_ports=$switch_unused_ports\n";
  print SCFG "switch_total_isl_ports=$switch_total_isl_ports\n";

  close(SCFG);

  # config.html
  my $config_html =  "$webdir/$switch_name/config.html";
  open(CFGH, "> $config_html") || error( "Couldn't open file $config_html $!" . __FILE__ . ":" . __LINE__ ) && next;
  print CFGH "<br><br><br>\n";
  print CFGH "<center>\n";
  print CFGH "<table class =\"tabcfgsum tablesortercfgsum\">\n";
  print CFGH "<thead>\n";
  print CFGH "<tr>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Switch Name</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">IP Address</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">World Wide Name</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Model</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Speed</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">OS Version</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Days Up</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Serial Number</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Total Ports</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">ISL Ports</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Unused Ports</th>\n";
  print CFGH "</tr>\n";
  print CFGH "</thead>\n";
  print CFGH "<tbody>\n";

  print CFGH "<tr>\n";
  print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_name</td>\n";
  print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_ip</td>\n";
  print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_wwn</td>\n";
  print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_model</td>\n";
  print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_speed</td>\n";
  print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_os_version</td>\n";
  print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_days_up</td>\n";
  print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_serial_number</td>\n";
  print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_total_ports</td>\n";
  print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_total_isl_ports</td>\n";
  print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$switch_unused_ports</td>\n";
  print CFGH "</tr>\n";
  print CFGH "</tbody>\n";
  print CFGH "</table>\n";

  print CFGH "<br><br><br>\n";
  print CFGH "<table class =\"tabcfgsum tablesorter tablesortercfgsum\">\n";
  print CFGH "<thead>\n";
  print CFGH "<tr>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Port</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Alias (from switch)</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Alias (from alias.cfg)</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">World Wide Name</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Speed</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">ISL</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">State</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Encrypt</th>\n";
  print CFGH "<th class = \"sortable\" style=\"text-align:center; color:black;\" nowrap=\"\">Compress</th>\n";
  print CFGH "</tr>\n";
  print CFGH "</thead>\n";
  print CFGH "<tbody>\n";


  # read etc/alias.cfg
  my $afile="$basedir/etc/alias.cfg";
  my @alines;
  if ( -f $afile ) {
    open(FHA, "< $afile") || error ("File cannot be opened for read, wrong user rights?? : $afile ".__FILE__.":".__LINE__) && next;
    @alines = <FHA>;
    close (FHA);
  }
  # isl
  my $isl_cfg = "$wrkdir/$switch_name/ISL.txt";
  my @isl;
  if ( -f $isl_cfg ) {
    open( ISL, "<$isl_cfg" ) || error( "Couldn't open file $isl_cfg $!" . __FILE__ . ":" . __LINE__ ) && next;
    @isl = <ISL>;
    close(ISL);
  }

  foreach my $name (sort { $a <=> $b } keys (%{$data{ports}})) {
    my $port_name      = "-";
    my $alias_from_sw  = "-";
    my $alias_from_cfg = "-";
    my $port_speed     = "-";
    my $port_isl       = "-";
    my $port_state     = "-";
    my $port_encrypt   = "-";
    my $port_compress  = "-";
    my $port_wwn       = "-";

    if ( defined $data{ports}{$name}{ifName} && $data{ports}{$name}{ifName} ne '' ) {
      $port_name = $data{ports}{$name}{ifName};
      $port_name =~ s/\//-/;
      $port_name =~ s/^port-channel/portChannel/;
      $port_name =~ s/\s+/_/;
    }
    else {
      error( "Not defined port id for port $name! $!" . __FILE__ . ":" . __LINE__ ) && next;
    }
    if ( $data{ports}{$name}{ifName} !~ "^fc|^port-channel|^Ethernet|^GigabitEthernet" ) { next; }

    if ( defined $data{ports}{$name}{ifAlias} && $data{ports}{$name}{ifAlias} ne '' ) {
      $alias_from_sw = $data{ports}{$name}{ifAlias};
    }
    if ( defined $data{ports}{$name}{wwn_to_cfg} && $data{ports}{$name}{wwn_to_cfg} ne '' ) {
      $port_wwn = $data{ports}{$name}{wwn_to_cfg};
    }

    #if ( defined $data{ports}{$name}{connUnitPortSpeed} && $data{ports}{$name}{connUnitPortSpeed} ne '' ) {
    #  $port_speed = $data{ports}{$name}{connUnitPortSpeed};
    #  if ( isdigit($port_speed) ) {
    #    $port_speed = ($port_speed * 8) / 1000000;
    #    $port_speed = "$port_speed Gbps";
    #  }
    #}
    if ( defined $data{ports}{$name}{fcIfOperStatusCause} && $data{ports}{$name}{fcIfOperStatusCause} =~ "fcotNotPresent" ) {
      $port_state = "unused";
    }

    # use alias from alias.cfg
    my $alias_from_admin_line  = "";
    my $alias_from_admin_line2 = "";
    ($alias_from_admin_line)  = grep {/^SANPORT:$switch_name:port$port_name:/} @alines;
    ($alias_from_admin_line2) = grep {/^SANPORT:$switch_name:$port_name:/} @alines;
    if ( defined $alias_from_admin_line && $alias_from_admin_line ne '' ) {
      my (undef, undef, undef, $alias_from_admin) = split(":",$alias_from_admin_line);
      if ( defined $alias_from_admin && $alias_from_admin ne '' ) {
        $alias_from_cfg  = "$alias_from_admin";
      }
    }
    if ( defined $alias_from_admin_line2 && $alias_from_admin_line2 ne '' ) {
      my (undef, undef, undef, $alias_from_admin) = split(":",$alias_from_admin_line2);
      if ( defined $alias_from_admin && $alias_from_admin ne '' ) {
        $alias_from_cfg  = "$alias_from_admin";
      }
    }

    # isl
    my $isl_line = "";
    ($isl_line) = grep {/^port$port_name,/} @isl;
    if ( defined $isl_line && $isl_line ne '' ) {
      chomp $isl_line;
      my (undef, undef, undef, $to_port, $to_sw) = split(",", $isl_line);
      if ( defined $to_port && $to_port ne '' && defined $to_sw && $to_sw ne '' ) {
        $to_port =~ s/to_port=//;
        $to_sw =~ s/to_switch=//;
        $port_isl = "to $to_sw, $to_port";
      }
    }


    print CFGH "<tr>\n";
    print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$port_name</td>\n";
    print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$alias_from_sw</td>\n";
    print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$alias_from_cfg</td>\n";
    print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$port_wwn</td>\n";
    print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$port_speed</td>\n";
    print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$port_isl</td>\n";
    print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$port_state</td>\n";
    print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$port_encrypt</td>\n";
    print CFGH "<td style=\"text-align:center; color:black;\" nowrap=\"\">$port_compress</td>\n";
    print CFGH "</tr>\n";
  }

  print CFGH "</tbody>\n";
  print CFGH "</table>\n";

  close(CFGH);
}

sub health_status_cisco {

  my $health_status_d    = shift;
  my $health_status_html = shift;
  my $last_update        = shift;
  my $switch_name        = shift;
  my @data               = @{$health_status_d};
  my $main_state         = "OK";
  my $state_suffix       = "ok";
  my $act_timestamp      = time();
  my @states;

  #(1-up, 2-down, 3-testing, 4-unknown, 5-dormant, 6-notPresent, 7-lowerLayerDown) : 1.3.6.1.2.1.2.2.1.8

  #Physical status
  #Green B1
  #Yellow : B3,
  #Grey: B2, B4, B6
  #Red : B5, B7

  if ( -f "$basedir/bin/cisco-status-custom.txt" ) {
    open( CST, "<$basedir/bin/cisco-status-custom.txt" ) || error( "Couldn't open file $basedir/bin/cisco-status-custom.txt $!" . __FILE__ . ":" . __LINE__ ) && exit;
    @states = <CST>;
    close(CST);
  }
  else {
    open( CST, "<$basedir/etc/cisco-status.txt" ) || error( "Couldn't open file $basedir/etc/cisco-status.txt $!" . __FILE__ . ":" . __LINE__ ) && exit;
    @states = <CST>;
    close(CST);
  }

  my $gray_st   = "<center><img src=\"css/images/status_gray.png\"></center>";
  my $red_st    = "<center><img src=\"css/images/status_red.png\"></center>";
  my $orange_st = "<center><img src=\"css/images/status_orange.png\"></center>";
  my $green_st  = "<center><img src=\"css/images/status_green.png\"></center>";

  my $port_table_start  = "<table class=\"san_stat_legend\" frame=\"box\" style=\"padding:0px 5px 0px 5px;\"><tr><td height=\"20px\"><b>Port</b></td>";
  my $admin_table_start = "<tr><td height=\"20px\" nowrap=\"\"><b>Admin status</b></td>";
  my $phys_table_start  = "<tr><td height=\"20px\" nowrap=\"\"><b>Operational status</b></td>";
  my $oper_table_start  = "<tr><td height=\"20px\" nowrap=\"\"><b>Operational status reason<b></td>";
  my $port_table_line   = "";
  my $admin_table_line  = "";
  my $phys_table_line   = "";
  my $oper_table_line   = "";
  my $port_table_end    = "</tr>\n";
  my $admin_table_end   = "</tr>\n";
  my $phys_table_end    = "</tr>\n";
  my $oper_table_end    = "</tr></table>\n";
  my @HS_table;
  my $port_idx          = 0;
  my $oper_color        = "";
  my @oper_legend;

  open( HS, ">$health_status_html" ) || error( "Couldn't open file $health_status_html $!" . __FILE__ . ":" . __LINE__ ) && exit;

  foreach my $line (@data) {
    chomp $line;
    $port_idx++;
    my ($port_id, $phys_st, $oper_st, $fcIfOperStatusCause) = split(",",$line);
    #print "$port_id, $phys_st, $oper_st, $fcIfOperStatusCause\n";

    $port_table_line .= "<td align=\"center\" nowrap=\"\"><b>$port_id</b></td>";

    # admin status
    if ( $phys_st =~ "testing" || $phys_st =~ "down" ) {
      $admin_table_line .= "<td width=\"20px\" height=\"20px\" nowrap=\"\" title=\"$phys_st\"><a href=\"/stor2rrd-cgi/detail.sh?host=$switch_name&type=SANPORT&name=port$port_id&storage=SAN-BRCD&item=san&gui=1&none=none\">$orange_st</a></td>";
    }
    if ( $phys_st =~ "up" ) {
      $admin_table_line .= "<td width=\"20px\" height=\"20px\" nowrap=\"\" title=\"$phys_st\"><a href=\"/stor2rrd-cgi/detail.sh?host=$switch_name&type=SANPORT&name=port$port_id&storage=SAN-BRCD&item=san&gui=1&none=none\">$green_st</a></td>";
    }

    # physical status
    if ( $oper_st =~ "unknown" || $oper_st =~ "notPresent" ) {
      $phys_table_line .= "<td width=\"20px\" height=\"20px\" nowrap=\"\" title=\"$oper_st\"><a href=\"/stor2rrd-cgi/detail.sh?host=$switch_name&type=SANPORT&name=port$port_id&storage=SAN-BRCD&item=san&gui=1&none=none\">$gray_st</a></td>";
    }
    if ( $oper_st =~ "dormant" || $oper_st =~ "lowerLayerDown" ) {
      $phys_table_line .= "<td width=\"20px\" height=\"20px\" nowrap=\"\" title=\"$oper_st\"><a href=\"/stor2rrd-cgi/detail.sh?host=$switch_name&type=SANPORT&name=port$port_id&storage=SAN-BRCD&item=san&gui=1&none=none\">$red_st</a></td>";
    }
    if ( $oper_st =~ "testing" || $oper_st =~ "down" ) {
      $phys_table_line .= "<td width=\"20px\" height=\"20px\" nowrap=\"\" title=\"$oper_st\"><a href=\"/stor2rrd-cgi/detail.sh?host=$switch_name&type=SANPORT&name=port$port_id&storage=SAN-BRCD&item=san&gui=1&none=none\">$orange_st</a></td>";
    }
    if ( $oper_st =~ "up" ) {
      $phys_table_line .= "<td width=\"20px\" height=\"20px\" nowrap=\"\" title=\"$oper_st\"><a href=\"/stor2rrd-cgi/detail.sh?host=$switch_name&type=SANPORT&name=port$port_id&storage=SAN-BRCD&item=san&gui=1&none=none\">$green_st</a></td>";
    }

    # operational status
    if ( defined $fcIfOperStatusCause && $fcIfOperStatusCause ne '' ) {
      my ($act_state_line) = grep (/: $fcIfOperStatusCause/, @states);
      chomp $act_state_line;
      my ( $def_color, undef, $act_state ) = split(" : ", $act_state_line);
      my $sort_ind = "";

      if ( $def_color eq "red" )    { $oper_color = $red_st; $sort_ind = 4; }
      if ( $def_color eq "green" )  { $oper_color = $green_st; $sort_ind = 1; }
      if ( $def_color eq "yellow" ) { $oper_color = $orange_st; $sort_ind = 3; }
      if ( $def_color eq "grey" )   { $oper_color = $gray_st; $sort_ind = 2; }

      $oper_table_line .= "<td width=\"20px\" height=\"20px\" nowrap=\"\" title=\"$fcIfOperStatusCause\"><a href=\"/stor2rrd-cgi/detail.sh?host=$switch_name&type=SANPORT&name=port$port_id&storage=SAN-BRCD&item=san&gui=1&none=none\">$oper_color</a></td>";

      push(@oper_legend, "$sort_ind,$def_color,$act_state\n");
    }


    if ( $oper_st =~ "dormant" || $oper_st =~ "lowerLayerDown" || $oper_color =~ "red_status" ) {
      $main_state = "NOT_OK";
      $state_suffix = "nok";
    }

    if ( $port_idx % 48 == 0 ) {
      push(@HS_table, "$port_table_start $port_table_line $port_table_end");
      push(@HS_table, "$admin_table_start $admin_table_line $admin_table_end");
      push(@HS_table, "$phys_table_start $phys_table_line $phys_table_end");
      push(@HS_table, "$oper_table_start $oper_table_line $oper_table_end");

      $port_table_line   = "";
      $admin_table_line  = "";
      $phys_table_line   = "";
      $oper_table_line   = "";
    }
  }

  if ( $port_table_line ne '' && $phys_table_line ne '' && $oper_table_line ne '' ) {
    push(@HS_table, "$port_table_start $port_table_line $port_table_end");
    push(@HS_table, "$admin_table_start $admin_table_line $admin_table_end");
    push(@HS_table, "$phys_table_start $phys_table_line $phys_table_end");
    push(@HS_table, "$oper_table_start $oper_table_line $oper_table_end");
  }

  # Global health check
  my $component_name = $switch_name;
  $component_name =~ s/\s+//g;

  if (! -d "$basedir/tmp/health_status_summary" ) {
    mkdir("$basedir/tmp/health_status_summary", 0755) || error( "$act_timestamp: Cannot mkdir $basedir/tmp/health_status_summary: $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }
  if ( -f "$basedir/tmp/health_status_summary/$component_name.ok" )  { unlink ("$basedir/tmp/health_status_summary/$component_name.ok"); }
  if ( -f "$basedir/tmp/health_status_summary/$component_name.nok" ) { unlink ("$basedir/tmp/health_status_summary/$component_name.nok"); }

  open( MAST, ">$basedir/tmp/health_status_summary/$component_name.$state_suffix" ) || error( "Couldn't open file $basedir/tmp/health_status_summary/$component_name.$state_suffix $!" . __FILE__ . ":" . __LINE__ ) && exit;
  print MAST "SAN-SWITCH : $switch_name : $main_state : $act_timestamp\n";
  close(MAST);


  #oper legend
  @oper_legend = sort @oper_legend;
  my @cisco_legend_table;
  my $op_color    = "";
  my $last_found  = "";
  my $legend_line = "<tr><td width=\"20px\" height=\"20px\" nowrap=\"\">XORUX-COLOR-XORUX</td><td nowrap=\"\"><b>XORUX-STATE-XORUX</b></td></tr>";

  foreach (@oper_legend) {
    chomp $_;

    my $found = $_;
    if ($found eq $last_found) {next};
    $last_found = $found;

    my ( undef, $def_color, $stat ) = split(",", $_);
    if ( $def_color eq "red" )    { $op_color = $red_st; }
    if ( $def_color eq "green" )  { $op_color = $green_st; }
    if ( $def_color eq "yellow" ) { $op_color = $orange_st; }
    if ( $def_color eq "grey" )   { $op_color = $gray_st; }

    my $line = $legend_line;
    $line =~ s/XORUX-STATE-XORUX/$stat/g;
    $line =~ s/XORUX-COLOR-XORUX/$op_color/g;
    push(@cisco_legend_table, $line);
  }

# html table
print HS <<_MARKER_;
<html>
<head>
  <title>STOR2RRD</title>
</head>
  <div id='hiw'><a href='http://www.stor2rrd.com/operStatusReason.html' target='_blank'><img src='css/images/help-browser.gif' alt='Operational status reason legend' title='Operational status reason legend'></a></div>
  <br><br><br>
  <center>

  @HS_table

  <br><br><br>
  <center>
    <table>
      <td valign=\"top\">
        <table class=\"san_stat_legend\">
          <tr>
            <td colspan="2" height="20px" nowrap=""><b>Admin status</b></td>
          </tr>
          <tr>
            <td colspan="2" height="20px" nowrap="">The desired state of the interface.</td>
          </tr>
          <tr>
            <td width="20px" height="20px" nowrap="">$green_st</td>
            <td nowrap=""><b>up</b></td>
          </tr>
          <tr>
            <td width="20px" height="20px" nowrap="">$orange_st</td>
            <td nowrap=""><b>down</b></td>
          </tr>
          <tr>
            <td width="20px" height="20px" nowrap="">$orange_st</td>
            <td nowrap=""><b>testing</b></td>
          </tr>
        </table>
      </td>
      <td>
        <table>
          <tr>
            <td width="40px" height="20px">&nbsp;</td>
          </tr>
        </table>
        </td>
      </td>
      <td valign=\"top\">
        <table class=\"san_stat_legend\">
          <tr>
            <td colspan="2" height="20px" nowrap=""><b>Operational status</b></td>
          </tr>
          <tr>
            <td colspan="2" height="20px" nowrap="">The current operational state of the interface.</td>
          </tr>
          <tr>
            <td width="20px" height="20px" nowrap="">$green_st</td>
            <td nowrap=""><b>up</b></td>
          </tr>
          <tr>
            <td width="20px" height="20px" nowrap="">$gray_st</td>
            <td nowrap=""><b>notPresent</b></td>
          </tr>
          <tr>
            <td width="20px" height="20px" nowrap="">$gray_st</td>
            <td nowrap=""><b>unknown</b></td>
          </tr>
          <tr>
            <td width="20px" height="20px" nowrap="">$orange_st</td>
            <td nowrap=""><b>down</b></td>
          </tr>
          <tr>
            <td width="20px" height="20px" nowrap="">$orange_st</td>
            <td nowrap=""><b>testing</b></td>
          </tr>
          <tr>
            <td width="20px" height="20px" nowrap="">$red_st</td>
            <td nowrap=""><b>lowerLayerDown</b></td>
          </tr>
        </table>
      </td>
      <td>
        <table>
          <tr>
            <td width="40px" height="20px">&nbsp;</td>
          </tr>
        </table>
        </td>
      </td>
        <td valign=\"top\">
          <table class=\"san_stat_legend\">
            <tr>
              <td colspan="2" height="20px" nowrap=""><b>Operational status reason</b></td>
            </tr>
            <tr>
              <td colspan="2" height="20px" nowrap="">The cause of current operational state of the port.</b></td>
            </tr>
            @cisco_legend_table
          </table>
        </td>
      </table>
    </center>
  </body>
</html>

_MARKER_

  close(HS);
}

