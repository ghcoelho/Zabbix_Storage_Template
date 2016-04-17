package CustomGroups;

use strict;
use warnings;

#use Data::Dumper;

my %grp;
my @rawacl;
my @cfggrp;    # array of groups from acl.cfg

my $basedir = $ENV{INPUTDIR};
$basedir ||= "..";

my $cfgdir     = "$basedir/etc/web_config";
my $realcfgdir = "$basedir/etc";
if ( defined $ENV{TMPDIR_LPAR} ) {
  my $tmpdir = $ENV{TMPDIR_LPAR};
}

my $aclAdmins = $ENV{ACL_ADMIN_GROUP};

my $user = $ENV{REMOTE_USER};
$user ||= "tester";

sub readCfg {
  if ( !open( CFG, "$cfgdir/custom_groups.cfg" ) ) {
    if ( !open( CFG, "$realcfgdir/custom_groups.cfg" ) ) {
      if ( !open( CFG, ">$cfgdir/custom_groups.cfg" ) ) {
        die "Cannot open file: $!\n";
      }
    }
  }

  while ( my $line = <CFG> ) {
    chomp($line);
    $line =~ s/\\:/===========doublecoma=========/g
        ;    # workround for lpars/pool/groups with double coma inside the name
    $line =~ s/ *$//g;    # delete spaces at the end
    if ( $line =~ m/^$/
      || ( $line !~ m/^VOLUME/ && $line !~ m/^(SAN)?PORT/ )
      || $line =~ m/^#/
      || $line !~ m/:/
      || $line =~ m/:$/
      || $line =~ m/: *$/ )
    {
      next;
    }
    my @val = split( /:/, $line );

    for (@val) {
      &doublecoma($_);
    }

    # my ($group, $cgrp, $srv, $lpar) = @val;
    my ( $type, $server, $name, $group_name, $collection ) = @val;

    push @rawacl, $line;

    push @cfggrp, $group_name;

    push @{ $grp{"$group_name"}{"children"}{$server} }, $name;
    $grp{"$group_name"}{"type"} = $type;
    if ($collection) {
      $grp{"$group_name"}{"collection"} = $collection;
    }

    # print Dumper \%grp;
  }
}

sub getCfgGroups {
  &readCfg();
  return @cfggrp;
}

sub getGrp {
  &readCfg();
  return %grp;
}

sub getRawCfg {
  &readCfg();
  return @rawacl;
}

sub getCollections {
  &readCfg();
  my %coll;
  foreach my $cgrp (keys %grp) {
      my $colname = $grp{$cgrp}{"collection"};
      if ( $colname ) {
        $coll{collection}{$colname}{$cgrp} = 1;
      } else {
        $coll{nocollection}{$cgrp} = 1;
      }
  }
  return %coll;
}

sub doublecoma {
  return s/===========doublecoma=========/:/g;
}

sub pipes {
  return s/===pipe===/\|/g;
}
1;
