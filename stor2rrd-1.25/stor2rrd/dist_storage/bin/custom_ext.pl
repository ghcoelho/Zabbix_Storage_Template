
use strict;
use Date::Parse;
use RRDp;
use CustomStor2rrd;

my $bindir = $ENV{BINDIR};
my $basedir = $ENV{INPUTDIR};
my $rrdtool = $ENV{RRDTOOL};
my $DEBUG = $ENV{DEBUG};
#$DEBUG=32; # alerting verbose debug level

RRDp::start "$rrdtool";

CustomStor2rrd::custom($basedir,$DEBUG);

RRDp::end;

exit (0);

