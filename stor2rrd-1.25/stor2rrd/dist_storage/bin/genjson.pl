#!/usr/bin/perl
# generates JSON data structures
use strict;

# use warnings;
# use CGI::Carp qw(fatalsToBrowser);
# use Data::Dumper;

my $DEBUG           = $ENV{DEBUG};
my $GUIDEBUG        = $ENV{GUIDEBUG};
my $DEMO            = $ENV{DEMO};
my $BETA            = $ENV{BETA};
my $WLABEL          = $ENV{WLABEL};
my $version         = $ENV{version};
my $errlog          = $ENV{ERRLOG};
my $basedir         = $ENV{INPUTDIR};
my $webdir          = $ENV{WEBDIR};
my $inputdir        = $ENV{INPUTDIR};
my $dashb_rrdheight = $ENV{DASHB_RRDHEIGHT};
my $dashb_rrdwidth  = $ENV{DASHB_RRDWIDTH};
my $legend_height   = $ENV{LEGEND_HEIGHT};
my $jump_to_rank    = $ENV{JUMP_TO_RANK};

my $prodname        = "STOR2RRD";

if ($WLABEL) {
  $prodname = $WLABEL;
}
if ($jump_to_rank) {
  $jump_to_rank = "true";
}
else {
  $jump_to_rank = "false";
}

my $md5module = 1;
eval "use Digest::MD5 qw(md5_hex); 1" or $md5module = 0;

my $jsonmodule = 1;
eval "use JSON qw(encode_json decode_json); 1" or $jsonmodule = 0;

use lib "../bin";
if ( !$md5module ) {
  use MD5 qw(md5_hex);
}
if ( !$jsonmodule ) {
#    use JSON::PP qw(encode_json decode_json);
}

use CustomGroups;
use Alerting;

my @gtree;     # Globals
my @ctree;     # Customs
my %ctreeh;    # Customs
my @ftree;     # Favourites
my %htree;     # HMCs
my @ttree;     # Tail
my %stree;     # Servers
my %sstree;    # SAN switch tree
my %types;     # storage types
my %rtree;     # Removed LPARs
my %lstree;    # LPARs by Server
my %lhtree;    # LPARs by HMC
my @caps;      # Capacity
my @lnames;    # LPAR name (for autocomplete)
my %fleet;     # server / type / name
my %times;     # server timestamps
my $free;      # 1 -> free / 0 -> full
my $entitle;

# set unbuffered stdout
#$| = 1;

open( OUT, ">> $errlog" ) if $DEBUG == 2;

# get QUERY_STRING
use Env qw(QUERY_STRING);
print OUT "-- $QUERY_STRING\n" if $DEBUG == 2;

#`echo "QS $QUERY_STRING " >> /tmp/xx32`;
my ( $jsontype, $par1, $par2 ) = split( /&/, $QUERY_STRING );

if ( $jsontype eq "" ) {
  if (@ARGV) {
    $jsontype = "jsontype=" . $ARGV[0];
    $basedir  = "..";
  }
  else {
    $jsontype = "jsontype=dump";
  }
}

$jsontype =~ s/jsontype=//;

if ( $jsontype eq "test" ) {
  $basedir = "..";
  &test();
  exit;
}

if ( $jsontype eq "dump" ) {
  &dumpHTML();
  exit;
}

# CGI-BIN HTML header
if ( !@ARGV ) {
  print "Content-type: application/json\n\n";
}

if ( $jsontype eq "menu" ) {
  &mainMenu();
  exit;
}

if ( $jsontype eq "menuh" ) {
  &mainMenuHmc();
  exit;
}
elsif ( $jsontype eq "lparsel" ) {
  &lparSelect();
  exit;
}
elsif ( $jsontype eq "hmcsel" ) {
  &hmcSelect();
  exit;
}
elsif ( $jsontype eq "times" ) {
  &times();
  exit;
}
elsif ( $jsontype eq "powersel" ) {
  &print_all_models();
  exit;
}
elsif ( $jsontype eq "pools" ) {
  &poolsSelect();
  exit;
}

elsif ( $jsontype eq "lparnames" ) {
  &readMenu();
  $par1 =~ s/term=//;
  &lparNames($par1);
  exit;
}
elsif ( $jsontype eq "histrep" ) {
  &readMenu();
  $par1 =~ s/hmc=//;
  $par2 =~ s/managedname=//;
  &histReport( $par1, $par2 );
  exit;
}
elsif ( $jsontype eq "env" ) {
  &readMenu();
  &sysInfo();
  exit;
}
elsif ( $jsontype eq "pre" ) {
  &readMenu();
  &genPredefined();
  exit;
}
elsif ( $jsontype eq "cust" ) {
  &readMenu();
  &custGroupsSelect();
  exit;
}
elsif ( $jsontype eq "aclgrp" ) {
  &readMenu();
  &aclGroups();
  exit;
}
elsif ( $jsontype eq "fleet" ) {
  &readMenu();
  &genFleet();
  exit;
}
elsif ( $jsontype eq "fleetree" ) {
    &readMenu();
    &genFleetTree();
    exit;
}
elsif ( $jsontype eq "custgrps" ) {
    &genCustGrps();
    exit;
}
elsif ( $jsontype eq "alrttree" ) {
    &genAlertTree();
    exit;
}
elsif ( $jsontype eq "alrtgrptree" ) {
    &genAlertGroupTree();
    exit;
}
elsif ( $jsontype eq "alrttimetree" ) {
    &genAlertTimeTree();
    exit;
}
elsif ( $jsontype eq "isok" ) {
    &checkHealth();
    exit;
}
elsif ( $jsontype eq "caps" ) {
    &genCaps();
    exit;
}
elsif ( $jsontype eq "alrtcfg" ) {
    &getAlertConfig();
    exit;
}

sub sysInfo() {
  my $sideMenuWidth;
  my $vmImage;
  if ( $ENV{'SIDE_MENU_WIDTH'} ) {
    $sideMenuWidth = $ENV{'SIDE_MENU_WIDTH'};
  }
  if ( $ENV{'VM_IMAGE'} ) {
    $vmImage = 1;
  }
  print "{\n";    # envelope begin
  print "\"version\":\"$version\",\n";
  print "\"free\":\"$free\",\n";
  print "\"entitle\":\"$entitle\",\n";
  print "\"dashb_rrdheight\":\"$dashb_rrdheight\",\n";
  print "\"dashb_rrdwidth\":\"$dashb_rrdwidth\",\n";
  print "\"legend_height\":\"$legend_height\",\n";
  print "\"jump_to_rank\":$jump_to_rank,\n";
  print "\"guidebug\":\"$GUIDEBUG\",\n";
  print "\"wlabel\":\"$WLABEL\",\n";
  print "\"vmImage\":" . &boolean($vmImage) . ",\n";
  print "\"sideMenuWidth\":\"$sideMenuWidth\",\n";
  print "\"beta\":\"$BETA\",\n";
  print "\"demo\":\"$DEMO\"\n";
  print "}\n";    # envelope end
}

sub dumpHTML() {
  print "Content-type: application/octet-stream\n";
  print("Content-Disposition:attachment;filename=debug.txt\n\n");
  my $buffer;
  read( STDIN, $buffer, $ENV{'CONTENT_LENGTH'} );
  my @pairs = split( /&/, $buffer );

  my @q = split( /=/, $pairs[1] );
  my $html = urldecode( $q[1] );
  print $html;

  #use CGI;
  #use CGI('header');
  #print header(-type=>'application/octet-stream',
  #       -attachment=>'debug.txt');
  #my $q = new CGI;
  #print $q->param('tosave');

}

sub test () {
  print "Content-type: text/plain\n\n";
#  require Data::Dumper;
  #&readMenu();
  #print Dumper \%types;
  # my %alerts = Alerting::getAlerts();
  # print Dumper \%alerts;
  #print Dumper \@caps;
  # &genHMCs;
  #print Dumper \%stree;
  #print Dumper \%lstree;
  #print Dumper \%lhtree;
  print "\n";
}

sub genCaps () {
  # use Data::Dumper;
  &readMenu();
  print "[\n";             # envelope begin
  if (@caps) {
    my $delim = "";
    foreach my $toAsk (sort { lc( $a->[0] ) cmp lc( $b->[0] ) } @caps) {
      print $delim . "{\"storage\": \"@$toAsk[0]\", \"subsys\": \"@$toAsk[1]\", \"url\": \"@$toAsk[2]\"}";
      $delim = "\n,";
    }
  }
  # $Data::Dumper::Terse = 1;
  # $Data::Dumper::Useqq = 1;
  print "\n]\n";           # envelope end
}

sub mainMenu () {
  &readMenu();
  my $hash = substr( md5_hex("DASHBOARD"), 0, 7 );
  ### Generate JSON
  print "[\n";    # envelope begin
  print
      "{\"title\":\"DASHBOARD\",\"extraClasses\":\"boldmenu\",\"href\":\"dashboard.html\",\"hash\":\"$hash\"}\n";
  &globalWoTitle();

  &genServersReduced();    # List by Servers

  #	&genHMCs ();  # List by HMCs

  &tail();
  print "\n]\n";           # envelope end
  ### End of JSON
}

sub mainMenuHmc () {
  &readMenu();
  my $hash = substr( md5_hex("DASHBOARD"), 0, 7 );
  ### Generate JSON
  print "[\n";             # envelope begin
  print
      "{\"title\":\"DASHBOARD\",\"extraClasses\":\"boldmenu\",\"href\":\"dashboard.html\",\"hash\":\"$hash\"},\n";
  &globalWoTitle();

  &genHMCs();              # List by HMCs

  &tail();
  print "\n]\n";           # envelope end
  ### End of JSON
}

sub lparSelect() {
  &readMenu();
  ### Generate JSON
  print "[\n";             # envelope begin
  &genLpars();             # List by Servers
  print "\n]\n";           # envelope end
  ### End of JSON
}

sub hmcSelect() {
  &readMenu();
  ### Generate JSON
  print "[\n";             # envelope begin
  &genHmcSelect();         # List by HMCs
  print "\n]\n";           # envelope end
  ### End of JSON
}

sub times () {
  &readMenu();
  my @sorted = sort { $times{$b} <=> $times{$a} } keys %times;

  print Dumper \%times;

  #	print Dumper \@sorted;
  for my $srv ( sort keys %times ) {
    for my $hmc (
      sort { $times{$srv}{$b} <=> $times{$srv}{$a} }
      keys %{ $times{$srv} }
        )
    {
      print Dumper $hmc;
    }
  }
}

sub poolsSelect() {
  &readMenu();
  ### Generate JSON
  print "[\n";      # envelope begin
  &genPools();      # generate list of Pools
  print "\n]\n";    # envelope end
  ### End of JSON
}

sub custGroupsSelect() {
  ### Generate JSON
  print "[\n";      # envelope begin
  &genCusts();      #
  print "\n]\n";    # envelope end
  ### End of JSON
}

sub checkHealth () {
  # print "[\n";      # envelope begin
  my @files = glob "${basedir}/tmp/health_status_summary/*.nok";
  if (@files) {
    print "{\"status\": \"NOK\"}";
  } else {
    print "{\"status\": \"OK\"}";
  }
  # print "\n]\n";    # envelope end
}

sub readMenu () {
  my $skel = "$basedir/tmp/menu.txt";

  open( SKEL, $skel ) or die "Cannot open file: $!\n";

  while ( my $line = <SKEL> ) {
    my ( $hmc, $srv, $txt, $url );
    chomp $line;
    my @val = split( ':', $line );
    for (@val) {
      &collons($_);
    }
    {
      "O" eq $val[0] && do {
        $free = ( $val[1] == 1 ) ? 1 : 0;
        last;
      };
      "G" eq $val[0] && do {
        my ( $txt, $url ) = ( $val[2], $val[3] );
        if ( $txt eq "HMC totals" ) { last; }
        push @gtree, [ $txt, $url ];
        last;
      };
      "F" eq $val[0] && do {
        my ( $txt, $url ) = ( $val[2], $val[3] );
        push @ftree, [ $txt, $url ];
        last;
      };
      "C" eq $val[0] && do {
        my ( $txt, $url ) = ( $val[2], $val[3] );
        if ( $txt ne "<b>Configuration</b>" ) {
          push @ctree, [ $txt, $url ];
          $ctreeh{$txt} = $url;
        }
        last;
      };
      "H" eq $val[0] && do {
        ( $hmc, $txt, $url ) = ( $val[1], $val[2], $val[3] );
        if ( $txt . $url ) {
          $htree{$hmc}{$txt} = $url;
        }
        last;
      };
      "W" eq $val[0] && do {
        ( $hmc, $txt, $url ) = ( $val[1], $val[2], $val[3] );
        if ( $txt . $url ) {
          $sstree{$hmc}{$txt} = $url;
        }
        if ( !exists $types{$hmc} ) {
          $url =~ /.*&storage=([^&]*)/;
          if ($1) {
            $types{$hmc} = $1;
          }
        }
        last;
      };

# aggregates
#A:DS05:POOL:read_io:Read IO:/stor2rrd-cgi/detail.sh?host=DS05&type=POOL&name=read_io&storage=DS8K&item=sum&gui=1&none=none::
      "A" eq $val[0] && do {
        my ( $storage, $subsys, $agg, $txt, $url, $timestamp )
            = ( $val[1], $val[2], $val[3], $val[4], $val[5], $val[7] );
        if ($timestamp) {
          $times{$subsys}{$storage} = $timestamp;
        }
        $subsys =~ s/&nbsp;/ /g;
        push @{ $stree{$subsys}{$storage} }, [ $txt, $url, $agg ];
        if ( !exists $types{$storage} ) {
          $url =~ /.*&storage=([^&]*)/;
          $types{$storage} = $1;
        }
        #if ($agg eq "cap") {
          #push @caps, [$storage, $subsys, $url];
        #}
        last;
      };
      "L" eq $val[0] && do {
        my ( $storage, $subsys, $atxt, $txt, $url ) = ( $val[1], $val[2], $val[3], $val[4], $val[5] );
        $subsys =~ s/&nbsp;/ /g;
        $txt =~ s/\r//g;
        push @{ $lhtree{$storage}{$subsys} }, [ $txt => $url, $atxt ];
        if ( $subsys eq "Managed disk" || $subsys eq "RAID GROUP" ) {
          $subsys = 'RANK';
        }
        elsif ( $subsys eq "CPU-CORE" ) {
          $subsys = 'CPU-NODE';
        }
        elsif ( $subsys eq "CPU util" ) {
          $subsys = 'CPU-NODE';
        }
        push @lnames, $txt;
        push @{ $fleet{$storage}{$subsys} }, $txt;
        last;
      };

#R:ahmc11:BSRV21:BSRV21LPAR5:BSRV21LPAR5:/lpar2rrd-cgi/detail.sh?host=ahmc11&server=BSRV21&lpar=BSRV21LPAR5&item=lpar&entitle=0&gui=1&none=none::
      "R" eq $val[0] && do {
        my ( $hmc, $srv, $txt, $url ) = ( $val[1], $val[2], $val[4], $val[5] );
        push @{ $rtree{$hmc}{$srv} }, [ $txt => $url ];

        # push @lnames, $txt;
        last;
      };
      "T" eq $val[0] && do {
        my ( $txt, $url ) = ( $val[2], $val[3] );
        push @ttree, [ $txt, $url ];
        last;
      };
      "X" eq $val[0] && do {
        my ( $storage, $subsys, $url ) = ( $val[1], $val[2], $val[6] );
        push @caps, [$storage, $subsys, $url];
        last;
      };
      "Q" eq $val[0] && do {    # product version
        $version = $val[1];
        last;
      };
    };
  }

  close(SKEL);
}

### Generate STORAGE submenu
sub genHMCs {
  print "{\"title\":\"STORAGE\",\"folder\":\"true\",\"expanded\":true,\"children\":[\n";
  my $n1 = "";
  for my $hmc ( sort keys %lhtree ) {
    if ( !exists $sstree{$hmc} ) {
      print $n1 . "{\"title\":\"$hmc\",\"folder\":\"true\",\"children\":[\n";
      hmcTotals($hmc);
      $n1 = ",";
      my $n2 = "";
      foreach my $srv ( 'CPU-NODE', 'CPU util', 'POOL', 'RANK', 'Managed disk', "RAID GROUP", 'VOLUME', 'DRIVE', 'PORT', 'HOST', "CACHE" )
      {
        if ( exists $stree{$srv}->{$hmc} || exists $lhtree{$hmc}{$srv} ) {

          # if (exists $lhtree{$hmc}{$srv} ) {
          print $n2 . "{\"title\":\"$srv\",\"folder\":\"true\",\"children\":[\n";
          $n2 = ",";
          if ( exists $stree{$srv}->{$hmc} ) {
            server( $hmc, $srv );
            if ( exists $lhtree{$hmc}{$srv} ) {
              print ",\n";
            }
          }
          if ( exists $lhtree{$hmc}{$srv} ) {
            print "{\"title\":\"Items\",\"folder\":\"true\",\"children\":[\n";
            my $n3 = "";
            for my $lpar ( @{ $lhtree{$hmc}->{$srv} } ) {

              #print Dumper $lpar;
              my $alt = @$lpar[2];

              # my $alt = "";
              # if ($srv eq 'POOL' || $srv eq 'RANK' || $srv eq 'Managed disk') {
              #  $alt = @$lpar[2];
              #}
              print $n3 . &fullNode( @$lpar[0], @$lpar[1], $hmc, $srv, 1, $alt );
              $n3 = ",";
            }    # L3 END
            if ( exists $rtree{$hmc}->{$srv} ) {
              print $n3 . "\n{\"title\":\"Removed\",\"folder\":\"true\",\"children\":[\n";
              my $n4 = "";
              for my $removed ( @{ $rtree{$hmc}->{$srv} } ) {
                print $n4 . &fullNode( @$removed[0], @$removed[1], $hmc, $srv, 1 );
                $n4 = ",\n";
              }
              print "]}";
            }
            print "]}";
          }
          print "]}\n";
        }    # L2 END
      }
      print "]}\n";
    }
  }
  print "]},\n";
  if (%sstree) {  ###  SAN SWITCH
    print "{\"title\":\"SAN SWITCH\",\"folder\":\"true\",\"expanded\":true,\"children\":[\n";
    my $n1 = "";
    if ( exists $sstree{"Totals"} ) {
      print $n1 . "{\"title\":\"Totals\",\"folder\":\"true\",\"children\":[\n";
      hmcTotals("Totals");
      $n1 = ",";
      print "]}\n";
    }
    for my $hmc ( sort keys %sstree ) {
      if ($hmc ne "Totals") {
        print $n1 . "{\"title\":\"$hmc\",\"type\":\"SAN\",\"folder\":\"true\",\"children\":[\n";
        hmcTotals($hmc);
        if ( exists $lhtree{$hmc} ) {
          print ",";
        }
        $n1 = ",";
        my $n2 = "";
        foreach my $srv ( 'SANPORT' ) {
          if ( exists $lhtree{$hmc}{$srv} ) {
            print $n2 . "{\"title\":\"PORT\",\"folder\":\"true\",\"type\":\"SAN\",\"children\":[\n";
            $n2 = ",";
            my $delim = '';
            for ( @{ $lhtree{$hmc}{$srv} } ) {
              print $delim . &fullNode( @$_[0], @$_[1], $hmc, $srv, 1, @$_[2] );
              $delim = ",\n";
            }
            print "]}\n";
          }
        }
        print "]}\n";
      }
    }
    print "]},\n";
  }
}

### Generate HMC select tree
sub genHmcSelect {
  my $n1 = "";
  for my $hmc ( sort keys %lhtree ) {
    print $n1 . "{\"title\":\"$hmc\",\"folder\":\"true\",\"children\":[\n";
    $n1 = ",";
    my $n2 = "";
    for my $srv ( sort keys %{ $lhtree{$hmc} } ) {
      print $n2 . "{\"title\":\"$srv\",\"folder\":\"true\",\"children\":[\n";
      $n2 = ",";
      print "{\"title\":\"LPAR\",\"folder\":\"true\",\"children\":[\n";
      my $n3 = "";
      for my $lpar ( @{ $lhtree{$hmc}->{$srv} } ) {
        my $value = "$hmc|$srv|@$lpar[0]";
        print $n3 . "{\"title\":\"@$lpar[0]\",\"icon\":false,\"key\":\"$value\"}";
        $n3 = ",";
      }    # L3 END
      if ( exists $rtree{$hmc}->{$srv} ) {
        for my $removed ( @{ $rtree{$hmc}->{$srv} } ) {
          my $value = "$hmc|$srv|@$removed[0]";
          print $n3 . "\n"
              . "{\"title\":\"@$removed[0]\",\"icon\":false,\"extraClasses\":\"removed\",\"key\":\"$value\"}";
        }
      }
      print "]}]}";
    }    # L2 END
    print "]}\n";
  }
}

### Generate Custom groups list for select inputs
sub genCusts {
    my $delim = '';
    for (@ctree) {
        if ( @$_[0] ne "Custom groups" && @$_[0] ne "<b>Configuration</b>") {
            my $egrp = urlencode( @$_[0] );
            print $delim . "{\"title\":\"@$_[0]\",\"key\":\"$egrp\"}";
            $delim = ",\n";
        }
    }
}

sub histReport {
  my ( $hmc, $server ) = @_;
  print "[\n";

  # print "{\"title\":\"SELECT ALL\",\"folder\":\"true\",\"expanded\":true,\"children\":[\n";
  my $n3 = "";
  if ($server eq "RANK") {
	if (exists $lhtree{$hmc}{"Managed disk"}) {
		$server = "Managed disk";
	} elsif (exists $lhtree{$hmc}{"RAID GROUP"}) {
		$server = "RAID GROUP";
	}
  }
  for my $lpar ( @{ $lhtree{$hmc}->{$server} } ) {

    #print Dumper $lpar;
    my $value = "@$lpar[2]";

    #if ($server eq 'POOL' || $server eq 'RANK') {
    # 	$value = "@$lpar[2]";
    #}
    print $n3 . "{\"title\":\"@$lpar[0]\",\"icon\":false,\"key\":\"$value\"}";
    $n3 = ",\n";
  }
  if ( exists $rtree{$hmc}->{$server} ) {
    for my $removed ( @{ $rtree{$hmc}->{$server} } ) {
      print $n3 . "\n"
          . "{\"title\":\"@$removed[0]\",\"icon\":false,\"extraClasses\":\"removed\",\"key\":\"@$removed[0]\"}";
    }
  }

  #print "]}";

  print "]";

}

sub genPredefined() {
  print "[\n";    # envelope begin
  my $delim = "";
  my $hash  = "";
  for my $srv ( sort keys %types ) {
    if ( $types{$srv} && $types{$srv} ne 'SAN-BRCD') {
      $hash = substr( md5_hex( $srv . "POOL" . "SubSys_SUM" ), 0, 7 );
      if ( $types{$srv} eq "DS5K" || $types{$srv} eq "HUS" ) {
        print $delim . "\"" . $hash . "xOd\"";    # agg IO total
        $delim = ",\n";
      }
      else {
        print $delim . "\"" . $hash . "xgd\"";    # POOL IO sum
        $delim = ",\n";
      }
    }
  }
  for (@ctree) {
      if ( lc @$_[0] ne "custom groups" && @$_[0] ne "<b>Configuration</b>") {
          my $grp = @$_[0];
          my $hash = substr( md5_hex( "nana" . $grp ), 0, 7 );
          @$_[1] =~ /type=([^&]*)/i;
          my $type = $1;
          if ($type eq "VOLUME") {
            # my @files = glob "'${basedir}/tmp/custom-group/${grp}-io_rate-d.cmd'";
            my $filetochk = "${basedir}/tmp/custom-group/${grp}-io_rate-d.cmd";
            # print STDERR "\nGLOB RES: " . Dumper $filetochk;
            # $egrp = @$_[1];
            if ( -f $filetochk) {
              print $delim . "\"" . $hash . "x1d\"";  # custom-group-io_rate
              $delim = ",\n";
            } else {
              print $delim . "\"" . $hash . "x3d\"";  # custom-group-read_io
              $delim = ",\n";
              print $delim . "\"" . $hash . "x4d\"";  # custom-group-write_io
            }
          } else {
            print $delim . "\"" . $hash . "aqd\"";
            $delim = ",\n";
            print $delim . "\"" . $hash . "ard\"";
          }
      }
  }
  print "\n]\n";                               # envelope end
}

sub urlencode {
  my $s = shift;
  $s =~ s/ /+/g;
  $s =~ s/([^A-Za-z0-9\+-_])/sprintf("%%%02X", ord($1))/seg;
  return $s;
}

sub urldecode {
  my $s = shift;
  $s =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
  $s =~ s/\+/ /g;
  return $s;
}

### Global section
sub global {
  my $fsub = 0;
  my $csub = 0;
  my $hsub = 0;

  print "{\"title\":\"GLOBAL\",\"folder\":\"true\",\"children\":[\n";
  if ( @ftree > 0 ) {
    $fsub = 1;
  }
  if ( @ctree > 0 ) {
    $csub = 1;
  }
  my $delim = '';
  for (@gtree) {
    my ( $t, $u ) = ( @$_[0], @$_[1] );
    {
      print $delim;
      ( ( lc $t eq "favourites" )    && $fsub ) && do { &favs();  last; };
      ( ( lc $t eq "custom groups" ) && $csub ) && do { &custs(); last; };
      if ( lc $t eq "health status" )
      {
        print &txthrefbold( $t, $u );
      }
      else {
        print &txthref( $t, $u );
      }
    }
    $delim = ",\n";
  }
  print "]},";
}

### Global section without Title
sub globalWoTitle {
  my $fsub = 0;
  my $csub = 0;
  my $hsub = 0;

  if ( @ftree > 0 ) {
    $fsub = 1;
  }
  if ( @ctree > 0 ) {
    $csub = 1;
  }
  my $delim = '';
  for (@gtree) {
    my ( $t, $u ) = ( @$_[0], @$_[1] );
    {
      print $delim;
            if ( ( lc $t eq "favourites" ) && $fsub ) {
                &favs();
            }
            elsif ( lc $t eq "custom groups" ) {
                &custs();
            }
            elsif (lc $t eq "cpu workload estimator"
                || lc $t eq "health status"
                || lc $t eq "alerting configuration"
                || lc $t eq "volumes top"
                || lc $t eq "capacity" )
            {
                print &txthrefbold( $t, $u );
      }
      else {
        print &txthref( $t, $u );
      }
    }
    $delim = ",\n";
  }
  print $delim;
}

### Favourites
sub favs {
  print "{\"title\":\"FAVOURITES\",\"folder\":\"true\",\"children\":[\n";
  my $delim = '';
  for (@ftree) {
    print $delim . &txthref( @$_[0], @$_[1] );
    $delim = ",\n";
  }
  print "]}";
}
### Custom Groups
sub custs {
    print "{\"title\":\"CUSTOM GROUPS\",\"folder\":\"true\",\"children\":[\n";
    print &fullNode( "<b>Configuration</b>", "/stor2rrd-cgi/cgrps.sh", "na", "na", 0 );
    my $delim = ",\n";
    my %coll = CustomGroups::getCollections();
    if ( $coll{collection} ) {
      for my $collname ( sort keys %{ $coll{collection} } ) {
        print $delim . "{\"title\":\"$collname\",\"folder\":\"true\",\"children\":[\n";
        my $n2 = "";
        for my $cgrp ( sort keys %{ $coll{collection}{$collname} } ) {
            print $n2 . &fullNode( $cgrp, $ctreeh{$cgrp}, "na", "na", 1, $cgrp );
            $n2 = ",\n";
          }

        print "]}";
      }
    }
    if ( $coll{nocollection} ) {
      # print Dumper \%ctreeh;
      for my $cgrp ( sort keys %{ $coll{nocollection} } ) {
        print $delim . &fullNode( $cgrp, $ctreeh{$cgrp}, "na", "na", 1, $cgrp);
      }
    }
    print "]}";
}

### HMC submenu
sub hmcs {

  #	print "{\"title\":\"HMC totals\",\"folder\":\"true\",\"children\":[\n";
  my $delim = '';
  for (%htree) {
    print $delim . &txthref( @$_[0], @$_[1] );
    $delim = ",\n";
  }

  #	print "]}";
}

### single HMC Totals
sub hmcTotals {
  my ($hmc) = @_;

  my $delim = '';
  #	print Dumper \%htree;
  if ( exists $htree{$hmc} ) {
    for ( sort keys %{ $htree{$hmc} } ) {
      print $delim . &txthref( $_, $htree{$hmc}{$_} );
      $delim = ",\n";
    }
    if ( exists $lhtree{$hmc} ) {
      print "$delim";
    }
  }
  if ( exists $sstree{$hmc} ) {
    foreach my $srv ( 'Data', 'IO', 'Frame', 'Fabric', "ISL", 'Heatmap', 'Health status', 'Configuration', 'Historical reports' )
    {
      if ( exists $sstree{$hmc}->{$srv} )
      {
        print $delim . &fullNode( $srv, $sstree{$hmc}{$srv}, $hmc, $srv, 0 );
        $delim = ",\n";
      }
    }
  }
  #print "$delim";
}

### Tail menu section
sub tail {
  my $freeOrFull = ( $free == 1 ? "free" : "full" );
  print
      "{\"title\":\"$prodname <span style='font-weight: normal'>($version $freeOrFull)</span>\",\"folder\":\"true\",\"children\":[\n";
  my $delim = '';
  for (@ttree) {
    print $delim . &txthref( @$_[0], @$_[1] );
    $delim = ",\n";
  }
  if ( $GUIDEBUG == 1 ) {
    print $delim . &txthref( "Load debug content", "debug.txt" );
  }
  print "]}";
}

### Single Server menu
# params: (hmc, srv)
sub server {
  my ( $h, $s ) = @_;
  my $delim = '';
  my $isLpar = ( $s eq "HOST" ) ? 1 : 0;
  for ( @{ $stree{$s}->{$h} } ) {
    print $delim . &fullNode( @$_[0], @$_[1], $h, $s, $isLpar, @$_[2] );
    $delim = ",\n";
  }
}

sub lparNames () {
  my @unique = sort ( do {
      my %seen;
      grep { !$seen{$_}++ } @lnames;
        }
  );
  print "[";
  if (@_) {
    @unique = grep( {/@_/i} @unique );
  }
  my $delim = '';
  for (@unique) {

    #		print Dumper $_;
    print $delim . "{\"value\":\"$_\"}";
    $delim = ",\n";
  }
  print "]";
}
sub genFleetTree {
    print "[";
    my $n1 = "";
    for my $srv ( sort keys %fleet ) {
        if ($times{$srv}{"removed"} == 1) {
          next;
        }
        print $n1 . "{\"title\":\"$srv\",\"folder\":\"true\",\"type\":\"$types{$srv}\",\"children\":[\n";
        $n1 = ",\n";
        my $n2 = "";
        for my $type ( sort keys %{ $fleet{$srv} } ) {
          print $n2 . "{\"title\":\"$type\",\"folder\":\"true\",\"children\":[";
          $n2 = ",\n";
          my $n3 = "";
          my @uni = uniq( @{ $fleet{$srv}{$type} } );
          foreach my $name ( @uni ) {
              print $n3 . "{\"title\":\"$name\"}";
              $n3 = ",";
          }    # L3 END
          print "]}";
        }    # L2 END
        print "]}";
    }
    print "]\n";
}

sub genFleet {
    print "{";
    my $n1 = "";
    for my $srv ( sort keys %fleet ) {
        if ($times{$srv}{"removed"} == 1) {
          next;
        }
        print $n1 . "\"$srv\":{";
        print "\"STORTYPE\":\"$types{$srv}\",";
        $n1 = ",\n";
        my $n2 = "";
        for my $type ( sort keys %{ $fleet{$srv} } ) {
        print $n2 . "\"$type\":[";
        $n2 = ",\n";
            my $n3 = "";
            my @uni = uniq( @{ $fleet{$srv}{$type} } );
            # print Dumper \@uni;
            foreach my $name ( @uni ) {
                print $n3
                    . "\"$name\"";
                $n3 = ",";
            }    # L3 END
            print "]";
        }    # L2 END
        print "}";
    }
    print "}\n";
}

sub genCustGrps {
    print "[";
    my $n1 = "";
    my %cgrps = CustomGroups::getGrp();
    for my $cgrp ( sort keys %cgrps ) {
      my $collection = "";
      if ( $cgrps{$cgrp}{'collection'} ) {
        $collection = ",\"collection\":\"" . $cgrps{$cgrp}{'collection'} . "\"";
      }
        print $n1 . "{\"title\":\"$cgrp\",\"folder\":\"true\",\"type\":\"" . $cgrps{$cgrp}{'type'} . "\"$collection,\"loaded\":\"true\",\"children\":[\n";
        $n1 = "\n,";
        my $n2 = "";
        for my $type ( sort keys %{ $cgrps{$cgrp}{'children'} } ) {
        print $n2 . "{\"title\":\"$type\",\"folder\":\"true\",\"children\":[\n";
        $n2 = "\n,";
            my $n3 = "";
            for my $name ( @{ $cgrps{$cgrp}{'children'}{$type} } ) {
                print $n3 . "{\"title\":\"$name\"}";
                $n3 = "\n,";
            }    # L3 END
            print "]}";
        }    # L2 END
        print "]}";
    }
    print "]\n";
}
sub genAlertTree {
    print "[";
    my $n1 = "";
    my %alerts = Alerting::getAlerts();
    # print Dumper \%alerts;
    foreach my $alert (sort keys %alerts) {
      print $n1 . "{\"title\":\"$alert\",\"folder\":\"true\",\"children\":[\n";
      $n1 = "\n,";
      my $n2 = "";
      foreach my $name (sort keys %{$alerts{$alert}{VOLUME}}) {
        print $n2 . "{\"title\":\"$name\",\"folder\":\"true\",\"children\":[\n";
        $n2 = "\n,";
        my $n3 = "";
        my $ruleidx = 1;
        foreach my $metric (%{$alerts{$alert}{VOLUME}{$name}}) {
          foreach my $vals (@{$alerts{$alert}{VOLUME}{$name}{$metric}}) {
            # print $vals->{limit};
            # $my ( $limit, $peak, $repeat, $exclude, $mailgrp ) = (%{\$val{limit}, \$val{limit}, \$val{limit}, \$val{limit}, \$val{limit});
            #print $n3 . "{\"title\":\"Rule #$ruleidx\",\"metrics\":\"$metric\",\"limit\":\"$vals->{limit}\",\"peak\":\"$vals->{peak}\",\"repeat\":\"$vals->{repeat}\",\"exclude\":\"$vals->{exclude}\",\"mailgrp\":\"$vals->{mailgrp}\"}";
            print $n3 . "{\"title\":\"\",\"metric\":\"$metric\",\"limit\":\"$vals->{limit}\",\"peak\":\"$vals->{peak}\",\"repeat\":\"$vals->{repeat}\",\"exclude\":\"$vals->{exclude}\",\"mailgrp\":\"$vals->{mailgrp}\"}";
            $n3 = "\n,";
            $ruleidx++;
          }
        }
        print "]}\n";
      }
      print "]}\n";
    }
    print "]\n";
}
sub genAlertGroupTree {
    print "[";
    my $n1 = "";

    foreach my $grp (Alerting::getDefinedGroups()) {
      print $n1 . "{\"title\":\"$grp\",\"folder\":\"true\",\"children\":[\n";
      $n1 = "\n,";
      my $n2 = "";
      # my @members = Alerting::getGroupMembers($grp);
      # print Dumper @members;
      foreach(@{ Alerting::getGroupMembers($grp) }) {
        # my $user = Alerting::getUserDetails($grp, $_);
        print $n2 . "{\"title\":\"$_\"}";
        $n2 = "\n,";
      }
      print "]}\n";
    }
    print "]\n";
}
sub getAlertConfig {
    print "[";
    my $n1 = "";
    my %cfg = Alerting::getConfig();
    # print Dumper %cfg;
    while ( my($key, $val) = each %cfg ) {
        print $n1 . "{\"$key\":\"$val\"}";
        $n1 = "\n,";
    }
    print "]\n";
}

sub txthref {
  my $hash = substr( md5_hex( $_[0] ), 0, 7 );
  return "{\"title\":\"$_[0]\",\"icon\":false,\"href\":\"$_[1]\",\"hash\":\"$hash\"}";
}

sub fullNode {
  my ( $title, $href, $hmc, $srv, $islpar, $altname ) = @_;
  my $key = ( $srv eq "na" ? "" : $srv ) . " " . $title;
  if ( $srv eq "Managed disk" || $srv eq "RAID GROUP" ) {
    $srv = "RANK";
  }
  if ( $srv eq "CPU util" ) {
    $srv = "CPU-NODE";
  }
  if ( $srv eq "CPU-CORE" ) {
    $srv = "CPU-NODE";
  }
  if ( !$islpar ) {
    my $hashstr = $hmc . $srv . "SubSys_SUM";
    my $hash = substr( md5_hex($hashstr), 0, 7 );

 return "{\"title\":\"$title\",\"href\":\"$href\",\"hash\":\"$hash\",\"hmc\":\"$hmc\",\"srv\":\"$srv\",\"altname\":\"$altname\",\"agg\":true,\"str\":\"$key\",\"hashstr\":\"$hashstr\"}";
#    return
 #       "{\"title\":\"$title\",\"href\":\"$href\",\"hash\":\"$hash\",\"hmc\":\"$hmc\",\"srv\":\"$srv\",\"altname\":\"$altname\",\"agg\":true,\"str\":\"$key\"}";
  }
  else {
    my $hashstr = $hmc . $srv . $altname;
    my $hash = substr( md5_hex($hashstr), 0, 7 );

 return "{\"title\":\"$title\",\"href\":\"$href\",\"hash\":\"$hash\",\"hmc\":\"$hmc\",\"srv\":\"$srv\",\"altname\":\"$altname\",\"str\":\"$key\",\"hashstr\":\"$hashstr\"}";
 #   return
  #      "{\"title\":\"$title\",\"href\":\"$href\",\"hash\":\"$hash\",\"hmc\":\"$hmc\",\"srv\":\"$srv\",\"altname\":\"$altname\",\"str\":\"$key\"}";
  }
}

sub txthrefbold {
  my $hash = substr( md5_hex( $_[0] ), 0, 7 );
  return "{\"title\":\"$_[0]\",\"extraClasses\":\"boldmenu\",\"href\":\"$_[1]\",\"hash\":\"$hash\"}";
}

sub txthref_wchld {
  return "{\"title\":\"$_[0]\",\"icon\":false,\"href\":\"$_[1]\",\"children\":[";
}

sub txtkey {
  return "{\"title\":\"$_[0]\",\"icon\":false,\"key\":\"$_[1]\"}";
}

sub txtkeysel {
  return "{\"title\":\"$_[0]\",\"icon\":false,\"selected\":true,\"key\":\"$_[1]\"}";
}

sub collons {
  return s/===double-col===/:/g;
}

sub uniq {
    my %seen;
    return grep { !$seen{$_}++ } @_;
}


# error handling
sub error {
  my $text     = shift;
  my $act_time = localtime();
  chomp($text);

  #print "ERROR          : $text : $!\n";
  print STDERR "$act_time: $text : $!\n";

  return 1;
}

sub boolean {
  my $val = shift;
  if ($val) {
    return "true";
  }
  else {
    return "false";
  }
}
