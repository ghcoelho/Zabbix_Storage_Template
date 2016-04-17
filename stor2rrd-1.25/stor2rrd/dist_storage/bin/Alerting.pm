package Alerting;
# LPAR2RRD alerting module
# vim: autoindent tabstop=2 shiftwidth=2 expandtab softtabstop=2 filetype=perl
use strict;
use warnings;

# use Data::Dumper;

my $basedir = $ENV{INPUTDIR};
$basedir ||= "..";

my $cfgdir     = "$basedir/etc/web_config";
my $realcfgdir = "$basedir/etc";

#if ( defined $ENV{TMPDIR_LPAR} ) {
#  my $tmpdir = $ENV{TMPDIR_LPAR};
#}

# first try to use system JSON module, if not present use bundled one
#my $jsonmodule = 1;
#eval "use JSON qw(encode_json decode_json); 1" or $jsonmodule = 0;
#
#if ( !$jsonmodule ) {
#  use JSON::PP qw(encode_json decode_json);
#}

my %alerts;    # hash holding alerting configuration
my %emailgrps; # hash holding e-mail groups
my %config;    # hash holding configuration
my @rawcfg;

sub readCfg {
  if ( !open( CFG, "$cfgdir/alerting.cfg" ) ) {
    if ( !open( CFG, "$realcfgdir/alert.cfg" ) ) {
      if ( !open( CFG, ">$cfgdir/alerting.cfg" ) ) {
        die "Cannot open file: $!\n";
      }
      else {       # create empty cfg file
        print CFG <<_MARKER_;
#VOLUME:storage:name:[io|read_io|write_io|data|read|write]:limit:peek time in min:alert repeat time in min:exclude time:email group
#==================================================================================================================================
# Nagios alerting
# Call this script from nrpe.cfg: bin/check_lpar2rrd
# More details on http://www.stor2rrd.com/nagios.html
NAGIOS=1        # [0/1] on/off Nagios support for alerting

# use external script for alerting
# it will be called once an alarm appears with these 7 parameters
# script.sh  <storage> <volume> <metric> <actual value> <limit>
# you can use bin/external_alert_example.sh as an example
# use the full path or relative path to the script
EXTERN_ALERT=bin/external_alert_example.sh

# include graphs into the email notification 0 - false, last 1 - X hours included in the graphs
EMAIL_GRAPH=25

# default time in minutes which says how often you should be alerted
# you can specify per volume different value in "alert repeat time" column of each ALERT
REPEAT_DEFAULT=60

# default time in minutes for length of traffic peak
# (the time when avg traffic utilization must be above of specified limit to generate an alert)
# you can change it per volume level in "time in min" column of each ALERT
# note it should not be shorter than sample rate for particular storage (usually 5 minutes)
PEAK_TIME_DEFAULT=15
_MARKER_

        close CFG;
        open( CFG, "$cfgdir/alerting.cfg" );
      }
    }
  }

  while ( my $line = <CFG> ) {
    chomp($line);
    $line =~ s/\\:/===========doublecoma=========/g
        ;    # workround for lpars/pool/groups with double coma inside the name
    $line =~ s/ *$//g;    # delete spaces at the end
    if ( $line =~ m/^$/
      || $line =~ m/^#/ )
    {
      next;
    }
    if ($line =~ m/:/) {
      my @val = split( /:/, $line );

      for (@val) {
        &doublecoma($_);
      }

      push @rawcfg, $line;

      my ( $type, $storage, $name, $item, $limit, $peak, $repeat, $exclude, $mailgrp ) = @val;

      if ($type eq "VOLUME" ) {
        # print STDERR $line . "\n";
        # push @cfggrp, $group_name;
        # my $idx = keys %{$alerts{$storage}{$type}{$name}{$item}};
        my $rule = { limit => $limit, peak => $peak, repeat => $repeat, exclude => $exclude, mailgrp => $mailgrp};
        push @{ $alerts{$storage}{$type}{$name}{$item} }, $rule;
        #$alerts{$storage}{$type}{$name}{$item}{$idx}{limit} = $limit;
        #$alerts{$storage}{$type}{$name}{$item}{$idx}{peek} = $peek;
        #$alerts{$storage}{$type}{$name}{$item}{$idx}{repeat} = $repeat;
        #$alerts{$storage}{$type}{$name}{$item}{$idx}{exclude} = $exclude;
        #$alerts{$storage}{$type}{$name}{$item}{$idx}{mailgrp} = $mailgrp;

        # print Dumper \%alerts;

      } elsif ($type eq "EMAIL" ) {
        my @mails;
        if ($name) {
          @mails = ( split /,/, $name );
          chomp (@mails);
          s{^\s+|\s+$}{}g foreach @mails;
          push @{ $emailgrps{$storage} }, @mails;
        }
      }
    } elsif ($line =~ m/=/) {
      my @val = split( /=/, $line, 2 );
      $config{$val[0]} = (split /\s+/, $val[1])[0];
    }
  }
  # print Dumper \%emailgrps;
}

sub getDefinedGroups {
# return sorted array of defined groups
  &readCfg;
  return sort keys %emailgrps;
}

sub getDefinedAlerts {
# return sorted array of defined alerts
  &readCfg;
  return sort keys %alerts;
}

sub getAlerts {
# return sorted array of defined alerts
  &readCfg;
  return %alerts;
}
sub getConfig {
# return configuration hash
  &readCfg;
  return %config;
}

sub getAlertDetails {
# params: alert_name
# return hash of alert details
  my ($storage, $type, $name, $metric) = shift;
  return $alerts{$storage}{$type}{$name}{$metric};
}

sub getGroupMembers {
# param: group_name
# return sorted array of defined alerts
  my $groupName = shift;
  return $emailgrps{$groupName};
}

sub getFullName {
# params: group_name, group_member
# return full name of a member
  my ($groupName, $groupMem) = @_;
  return $alerts{groups}{$groupName}{$groupMem}{fullname};
}

sub getEmail {
# params: group_name, group_member
# return full name of a member
  my ($groupName, $groupMem) = @_;
  return $alerts{groups}{$groupName}{$groupMem}{email};
}

sub getUserDetails {
# params: group_name, group_member
# return hash of member details
  my ($groupName, $groupMem) = @_;
  return $alerts{groups}{$groupName}{$groupMem};
}

sub doublecoma {
  return s/===========doublecoma=========/:/g;
}

sub pipes {
  return s/===pipe===/\|/g;
}

1;
