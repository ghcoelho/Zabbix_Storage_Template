#!/usr/bin/perl
# generates JSON data structures
use strict;

#use warnings;
# use CGI::Carp qw(fatalsToBrowser);

my $DEBUG           = $ENV{DEBUG};
my $GUIDEBUG        = $ENV{GUIDEBUG};
my $DEMO            = $ENV{DEMO};
my $BETA            = $ENV{BETA};
my $version         = $ENV{version};
my $errlog          = $ENV{ERRLOG};
my $basedir         = $ENV{INPUTDIR};
my $webdir          = $ENV{WEBDIR};
my $inputdir        = $ENV{INPUTDIR};
my $action;
my $cookie;
my $filename;

$basedir ||= "..";

my $cfgdir     = "$basedir/etc/web_config";
my $realcfgdir = "$basedir/etc";

if ( defined $ENV{TMPDIR_STOR} ) {
  my $tmpdir = $ENV{TMPDIR_STOR};
}

# set unbuffered stdout
#$| = 1;

open( OUT, ">> $errlog" ) if $DEBUG == 2;

# get QUERY_STRING
use Env qw(QUERY_STRING);
print OUT "-- $QUERY_STRING\n" if $DEBUG == 2;

#`echo "QS $QUERY_STRING " >> /tmp/xx32`;
( $action, $cookie ) = split( /&/, urldecode($QUERY_STRING) );

if ( $action eq "" ) {
    if (@ARGV) {
        $basedir  = "..";
    }
    $action = "list";
}

if ( !@ARGV ) {
    print "Content-type: application/json\n\n";
}


if ( $action eq "list" ) {
    &list();
    exit;
} else {
  ($action, $filename) = split /=/, $action;
  # print "Action: $action   File: $filename\n";
  if ( $action eq "save" ) {
    (undef, $cookie) = split /=/, $cookie;
    # print "Cookie: $cookie";
    if (open(DBSTATUS, ">$cfgdir/$filename")) {
      print DBSTATUS $cookie;
      close DBSTATUS;
      print "{ \"status\" : \"success\", \"retstr\" :" . "\"buffer\" }";
    } else {
      print "{ \"status\" : \"fail\", \"msg\" : \"<div>File $cfgdir/$filename cannot be written by webserver, check apache user permissions: <span style='color: red'>$!</span></div>\" }";
    }
    exit;
  } elsif ( $action eq "load" ){
    if (open(DBSTATUS, "<$cfgdir/$filename")) {
      my $line = <DBSTATUS>;
      print "{ \"status\" : \"success\", \"cookie\" :" . "\"$line\", \"filename\" :" . "\"$filename\"}";
      close DBSTATUS;
    }
  }
}



sub uniq {
    my %seen;
    return grep { !$seen{$_}++ } @_;
}

sub list {
    print "[\n";             # envelope begin
    opendir(DIR, $cfgdir) or die $!;
    my $delim = "";
    while (my $file = readdir(DIR)) {
      # Use a regular expression to ignore files beginning with a period
      if ($file =~ /^db_.*/) {
        print $delim . "\"$file\"\n";
        $delim = ",";
      }
    }
    closedir(DIR);
    print "\n]\n";           # envelope end
}

sub urldecode {
    my $s = shift;
    $s =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
    $s =~ s/\+/ /g;
    return $s;
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
