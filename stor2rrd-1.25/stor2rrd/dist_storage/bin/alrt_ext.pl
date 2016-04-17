
use strict;
use Date::Parse;
use RRDp;
use AlertStor2rrd;

my $bindir = $ENV{BINDIR};
my $basedir = $ENV{INPUTDIR};
my $rrdtool = $ENV{RRDTOOL};
my $DEBUG = $ENV{DEBUG};
$DEBUG=22; # alerting verbose debug level

my $storage = $ENV{STORAGE_NAME};
my $st_type = $ENV{STORAGE_TYPE};
my $time_last = $ENV{STOR2RRD_TIME_ACT};

RRDp::start "$rrdtool";

AlertStor2rrd::alert($storage,$st_type,$time_last,$basedir,$DEBUG);

RRDp::end;

exit (0);

