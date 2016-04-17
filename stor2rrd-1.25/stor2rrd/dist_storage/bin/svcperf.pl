#!/usr/bin/perl
#
# svcperf.pl
#
# v1.0.3  2015-09-10

# Changes:
# New release


# Modules
use strict;
use Storable qw(retrieve store);
use Data::Dumper;
use Date::Parse;
use SVC;

#use XML::Simple;
my $bindir = $ENV{BINDIR};
require "$bindir/xml.pl"; # it replaces above line and fixes an issue on Perl 5.10.1 on AIX 7100-00-06-1216

# Constant
use constant SVCPRF101W => 101;
use constant SVCPRF102W => 102;
use constant SVCPRF103W => 103;
use constant SVCPRF104W => 104;
use constant SVCPRF105W => 105;
use constant SVCPRF106W => 106;
use constant SVCPRF107W => 107;
use constant SVCPRF108W => 108;
use constant SVCPRF109W => 109;
use constant SVCPRF110E => 110;
use constant SVCPRF111E => 111;
use constant SVCPRF112E => 112;
use constant SVCPRF113E => 113;
use constant SVCPRF114E => 114;
use constant SVCPRF115E => 115;
use constant SVCPRF116E => 116;
use constant SVCPRF117E => 117;
use constant SVCPRF118E => 118;
use constant SVCPRF119E => 119;


# Options and their default value
my $storage;                    # SVC/Storwize V7000 alias
my $svc;                        # SVC/Storwize V7000 cluster host name (IP address)
my $user        = "admin";      # SVC/Storwize V7000 user name
my $key         = "";           # SSH key filename
my $interval    = 1;            # interval time for data collection
my $dir         = "..";         # Data directory

my $debug       = 0;            # Debug mode 0:off, 1:on
my $debug_full  = 0;            # Debug mode 0:off, 1:on

if (defined $ENV{STORAGE_NAME}) {
	$storage= $ENV{STORAGE_NAME};
} else {
	message("SVC/Storwize V7000 storage name alias is required.");
	exit(1);
}
if (defined $ENV{SVC_IP}) {
	$svc= $ENV{SVC_IP};
} else {
	message("SVC/Storwize V7000 host name or IP address is required.");
	exit(1);
}
if (defined $ENV{SVC_USER}) { $user	= $ENV{SVC_USER} }
if (defined $ENV{SVC_KEY}) { $key = $ENV{SVC_KEY} }
if (defined $ENV{SVC_INTERVAL}) { $interval = $ENV{SVC_INTERVAL} }
if (defined $ENV{SVC_DIR}) { $dir = $ENV{SVC_DIR} }
if (defined $ENV{SVC_DEBUG_FULL}) { $debug_full = $ENV{SVC_DEBUG_FULL} }
if (defined $ENV{DEBUG}) { $debug = $ENV{DEBUG} }

# Global variables with their value
my $ssh;
my $scp;
my $cmd_ls = "/bin/ls";
my $cmd_mv = "/bin/mv";
my $cmd_rm = "/bin/rm";
my $cmd_grep = "/bin/grep";
my $putty = 0;
if ($putty) {
	$cmd_ls = "c:\\unix\\ls";
	$cmd_mv = "c:\\unix\\mv";
	$cmd_rm = "c:\\unix\\rm";
	$cmd_grep = "c:\\unix\\grep";
	#my $plink = "c:/Program Files (x86)/PuTTY/plink.exe";
	my $plink = "c:/Progra~2/PuTTY/plink.exe";
	my $pscp = "c:/Progra~2/PuTTY/pscp.exe";
	$ssh = $plink." -i $key $user\@$svc";
	$scp = $pscp." -i $key $user\@$svc:/dumps/iostats/";
} elsif("x$key" eq "x") {            # with default keyfile (.ssh/id_rsa)
	$ssh = "ssh  -q -o ConnectTimeout=80 -o StrictHostKeyChecking=no -o PreferredAuthentications=publickey $user\@$svc";
	$scp = "scp  -q -o ConnectTimeout=80 -o StrictHostKeyChecking=no -o PreferredAuthentications=publickey $user\@$svc:/dumps/iostats/";
} else {                        # with keyfile
	$ssh = "ssh  -q -o ConnectTimeout=80 -o StrictHostKeyChecking=no -o PreferredAuthentications=publickey -i $key $user\@$svc";
	$scp = "scp  -q -o ConnectTimeout=80 -o StrictHostKeyChecking=no -o PreferredAuthentications=publickey -i $key  $user\@$svc:/dumps/iostats/";
}

my $iosdir = "$dir/iostats/";   # Directory for iostats files
my $tmpdir = "$dir/";       # Directory for temporary files

# Global variables
my $terminate_pgm;
my $iostatsdumps_name;                                  # SVC, Storwize V7000 dependent
my ($node, $front_panel_id, @stats_files, $stats_file); # Current scan data
my (@Nn_last, @Nm_last, @Nv_last, @Nd_last);            # Last scan data
my $time_last;
my $iostat_file_missing_max = 3;

my ($command, $ret);
my $cfg_ref;
my $fullcfg_ref;
my %last_data; my $last_data_ref = \%last_data;
my %prev_data; my $prev_data_ref = \%prev_data;
my %mdiskgrp_cap; my $mdiskgrp_cap = \%mdiskgrp_cap;
my $iostat_file_missing_count;

# SVC Hardware Types
my %svc_g1 =("CG8"=>1,"CF8"=>1,"8A4"=>1,"8G4"=>1,"8F4"=>1,"8F2"=>1,"4F2"=>1);
my %svc_g2 =("DH8"=>1);

# Main process

# Display options
print("
svcperf.pl: Starts with the following options ...
\tSVC/Storwize V7000 cluster name alias:   $storage
\tSVC/Storwize V7000 cluster host name:    $svc
\tInterval:                                $interval
\tDirectory for iostats files:             $iosdir
\tDirectory for temporary files:           $tmpdir
\tDebug:                                   $debug
");

# Examine system name
my $svc_name;
my $lssystem = &LsSystem();

if ( not defined $lssystem->{'name'} ) {
    message("Cannot connect storage.");
    exit 1;
}
$svc_name = $lssystem->{'name'};
if("x$svc_name" eq "x") {
    message("Cannot get system name.");
    exit 1;
}
if($debug) {message("System name    : $svc_name");}
# Set filenames
my $logfile = $tmpdir . "../../logs/" . $storage . ".svcperf.log";	# log file
my $tmp_perf_file = $tmpdir . $storage . "_svcperf.data";	#
my $out_perf_file;
my $tmp_conf_file;
my $tmp_conf_full_file = ${storage}."_svcconf.datafull";
my $magic_file = $bindir."/../etc/.magic";
# Create log file
my $time = localtime();
$time = localtime();
message("Started at ".$time);
# Handling signals
$SIG{'INT'} = 'CtrlC';

# Change STOUT buffer attribute
$| = 1;	# disable STDOUT buffer

# Examine H/W type and Set iostats dumps file name (NOTE: change to script - same command to clear)
my $line_LSNODE = `$ssh svcinfo lsnode -nohdr -delim :`;
# if($debug_full) {print("The svcinfo lsnode command output: $line_LSNODE");}
my @field_LSNODE = split(':', $line_LSNODE);
if(length($field_LSNODE[2]) == 0 && length($field_LSNODE[15]) != 0) {
	# Storwize V7000 = UPS_serial_number is blank AND enclosure_serial_number is not blank
	$iostatsdumps_name = "dump_name";	# Storwize V7000 iostats dumps file name
	if($debug_full) {message("H/W type, iostats dumps file name (Storwize V7000): $iostatsdumps_name.");}
} elsif($svc_g1{$field_LSNODE[9]}) {	
	$iostatsdumps_name = "front_panel_id";	# SVC - Gen1 - with UPS - iostats dumps file name
	if($debug_full) {message("H/W type, iostats dumps file name (SVC): $iostatsdumps_name.");}
} elsif($svc_g2{$field_LSNODE[9]}) {	
	$iostatsdumps_name = "front_panel_id";	# SVC - Gen2 - with battery - iostats dumps file name
	if($debug_full) {message("H/W type, iostats dumps file name (SVC): $iostatsdumps_name.");}
}

# Clear SVC/Storwize V7000 iostats files  (NOTE: channge to script)
foreach my $line_LSNODE (`$ssh svcinfo lsnode -nohdr -delim :`) {
	# if($debug_full) {message("The svcinfo lsnode command output: $line_LSNODE");}
	my @field_LSNODE = split(':', $line_LSNODE);
	system("$ssh svctask cleardumps -prefix /dumps/iostats $field_LSNODE[0]");
	if($debug_full) {message("Clear iostas files: node $field_LSNODE[1]");}
}

# Start SVC/Storwize V7000 iostats collection
if($debug) {message("Statistics collection: ".$lssystem->{'statistics_status'}." - Interval: ".$lssystem->{'statistics_frequency'});}
if ( $lssystem->{'statistics_frequency'} != $interval ) {
	system ("$ssh svctask startstats -interval $interval") ;
	if($debug) {message("Start statistics collection: interval $interval");}
}

# Initialize Last uploaded data to curent time
$time_last = &Localtime_str;
#$time_last = "150629_134600";  # (\d{6}_\d{6}) # SVC svqueryclock
$terminate_pgm = 0;
$iostat_file_missing_count = 0;

# main loop
while(1){
	if($debug_full) { $time = localtime(); message("Get data at ".$time); }
	my @active_nodes;
	# Scan all nodes and get performance data
	foreach my $line_LSNODE (`$ssh svcinfo lsnode -nohdr -delim :`) {
		#if($debug_full) {message("The svcinfo lsnode command output: $line_LSNODE");}
		my @field_LSNODE = split(':', $line_LSNODE);
		# Check none configuration nodes
		if($field_LSNODE[4] eq "online") {
			if($field_LSNODE[7] =~ "no") {
				$node = $field_LSNODE[0];
				if($debug_full) {message("Non-configuration node: $node");}
				&ID_front_panel(); push(@active_nodes,$front_panel_id);
				&List_iostats_create();
				&List_iostats_copy();
			# Check configuration node
			} else {
				$node = $field_LSNODE[0];
				if($debug_full) {message("Configuration node: $node");}
				&ID_front_panel(); push(@active_nodes,$front_panel_id);
				&List_iostats_create();
				&List_iostats_get();
			}
		}
	}
	# Scan uploaded data and compute
	while (1) {
		if($debug_full){message("Start IOSTAT files loop - Last time: ".$time_last."  Nodes: ".scalar(@active_nodes));}
		my $time_last_save = $time_last;
		my @stats_list = (`$cmd_ls $iosdir | $cmd_grep _stats_`);
		my $stats_onetime = &OneTimeStatsList(\@stats_list);
		if (scalar(@{$stats_onetime}) == 0) {
			last;
		}
		if( &Check_iostats_files(\@active_nodes,$stats_onetime) ) {
			# All expected IO stats files
			message("Process IOSTAT files - Time: ".$time_last."  Nodes: ".scalar(@active_nodes));
			$iostat_file_missing_count = 0;
			&Process_iostats_files($stats_onetime);
			if( &Validate_iostat_data($last_data_ref) == 1 ) { next; }
			if( &Retrieve_previous_data == 1 ) { next; }
			if( &Validate_iostat_data($prev_data_ref) == 1 ) { next; }
			if( &Process_iostat_data == 1 ) { next; }
		} else {
			# Some IO stats file missing, waiting ...
			$iostat_file_missing_count++;
			if ( $iostat_file_missing_count <= $iostat_file_missing_max ) {
				&message("Some IOSTAT file missing in ".$time_last." interval. Waiting (".$iostat_file_missing_count.").");
				$time_last = $time_last_save;
				last;
			}
		}
 	} continue {
		# Clear Data
		&ClearData();
		# Clear Accumulated Data
		&SVC::ClearAccumData();
	}
} continue {
	# Read etc/.magic file
	&Read_magic();
	# Wait about 60 seconds
	for(my $i = 0; $i < 20; $i++) {
		# Terminate program?
		if($terminate_pgm){
			if($debug) {message("svcperf.pl: Exitting");}
			exit(0);
		}
		sleep (3);
	}
}

sub message {
	my $msg = shift;
	my $tm = localtime();
	print($tm." - INFO    - svcperf.pl: ".$msg."\n");
}

sub warning {
	my ($msg,$rc) = @_;
	my $tm = localtime();
	print STDERR ($tm." - WARNING - svcperf.pl: ".$msg."\n");
}

sub error {
	my ($msg,$rc) = @_;
	my $tm = localtime();
	print STDERR ($tm." - ERROR   - svcperf.pl: ".$msg."\n");
}


sub LsSystem {
	my $line;
	my $delim = ":";
	my %cfg;
	my $cmd = $ssh . " svcinfo lssystem -delim " . $delim;
	if ($debug_full) {message("Command: $cmd.")};
	open (CMDOUT,"$cmd |") || die "svcperf.pl: Command $cmd failed. Exiting.";

	while ($line = <CMDOUT>) {
		chomp ($line);
		if ($line  =~ /^(\w+)$delim(.*)$/) {   # system
			$cfg{$1} = $2;
		}
	}
	close(CMDOUT);
	return(\%cfg);
}


sub ID_front_panel {

	# Create $front_panel_id
	foreach my $line_LSNODEVPD (`$ssh svcinfo lsnodevpd -delim : $node`) {
		#if($debug_full) {print("The svcinfo lsnodevpd command output: $line_LSNODEVPD");}
		my @field_LSNODEVPD = split (':', $line_LSNODEVPD);
		if($field_LSNODEVPD[0] =~ $iostatsdumps_name) {
			#if($debug_full) {message("Check: $field_LSNODEVPD[1]");}
			$front_panel_id = $field_LSNODEVPD[1];
			chomp($front_panel_id);
			if($debug_full) {message("Front panel ID/Dump name: $front_panel_id");}
		}
	}
}


sub List_iostats_create {

	# create local node's I/O stats file list array (@stats_files)
	foreach my $line_LSIOSTATSDUMPS (`$ssh svcinfo lsiostatsdumps -nohdr -delim : $node`) {
		#if($debug_full) {print("The svcinfo lsiostatsdumps command output: $line_LSIOSTATSDUMPS");}
		my @field_LSIOSTATSDUMPS = split(':', $line_LSIOSTATSDUMPS);
		chomp($field_LSIOSTATSDUMPS[1]);
		if(index($field_LSIOSTATSDUMPS[1], $front_panel_id) > 0) {
			unshift(@stats_files, $field_LSIOSTATSDUMPS[1]);
		}
	}
	@stats_files = sort(@stats_files);
	if($debug_full) {message("I/O statistics log files: @stats_files");}
}

sub List_iostats_copy {

	# Scan all (Node, VDisk, MDisk, Drive) stats files
	while(defined($stats_file = shift(@stats_files))) {

		# Handle Node stats file
		if(not defined $Nn_last[$node]) { $Nn_last[$node] = "" }
		if($stats_file =~ m/Nn/ && $stats_file gt $Nn_last[$node]) {
			if($debug_full) {message("Copy iostat file: ".$stats_file);}
			$command = $ssh . " svctask cpdumps -prefix /dumps/iostats/" . $stats_file .  " " . $node;
			cmd_exec($command);
			$command = "$scp$stats_file $iosdir";
			if (! defined cmd_exec($command) ) {
				error("Upload IOSTAT file $stats_file failed.");
				system("$cmd_rm -f " . $tmp_perf_file );
				exit SVCPRF118E;
			}
			$Nn_last[$node] = $stats_file;
		}

		# Handle VDisk stats file
		if(not defined $Nv_last[$node]) { $Nv_last[$node] = "" }
		if($stats_file =~ m/Nv/ && $stats_file gt $Nv_last[$node]) {
			if($debug_full) {message("Copy iostat file: ".$stats_file);}
			$command = $ssh . " svctask cpdumps -prefix /dumps/iostats/" . $stats_file .  " " . $node;
			cmd_exec($command);
			$command = "$scp$stats_file $iosdir";
			if (! defined cmd_exec($command) ) {
				error("Upload IOSTAT file $stats_file failed.");
				system("$cmd_rm -f " . $tmp_perf_file );
				exit SVCPRF118E;
			}
			$Nv_last[$node] = $stats_file;
		}

		# Handle MDisk stats file
		if(not defined $Nm_last[$node]) { $Nm_last[$node] = "" }
		if($stats_file =~ m/Nm/ && $stats_file gt $Nm_last[$node]) {
			if($debug_full) {message("Copy iostat file: ".$stats_file);}
			$command = $ssh . " svctask cpdumps -prefix /dumps/iostats/" . $stats_file .  " " . $node;
			cmd_exec($command);
			$command = "$scp$stats_file $iosdir";
			if (! defined cmd_exec($command) ) {
				error("Upload IOSTAT file $stats_file failed.");
				system("$cmd_rm -f " . $tmp_perf_file );
				exit SVCPRF118E;
			}
			$Nm_last[$node] = $stats_file;
		}

		# Handle Drive stats file
		if(not defined $Nd_last[$node]) { $Nd_last[$node] = "" }
		if($stats_file =~ m/Nd/ && $stats_file gt $Nd_last[$node]) {
			if($debug_full) {message("Copy iostat file: ".$stats_file);}
			$command = $ssh . " svctask cpdumps -prefix /dumps/iostats/" . $stats_file .  " " . $node;
			cmd_exec($command);
			$command = "$scp$stats_file $iosdir";
			if (! defined cmd_exec($command) ) {
				error("svcperf.pl: Upload IOSTAT file $stats_file failed.");
				system("$cmd_rm -f " . $tmp_perf_file );
				exit SVCPRF118E;
			}
			$Nd_last[$node] = $stats_file;
		}
	}
}

sub List_iostats_get {

	# Scan all (Node, VDisk, MDisk, Drive) stats files
	while(defined($stats_file = shift(@stats_files))) {

		# Handle Node stats file
		if(not defined $Nn_last[$node]) { $Nn_last[$node] = "" }
		if($stats_file =~ m/Nn/ && $stats_file gt $Nn_last[$node]) {
			if($debug_full) {message("Copy iostat file: ".$stats_file);}
			$command = "$scp$stats_file $iosdir";
			if (! defined cmd_exec($command) ) {
				error("Upload IOSTAT file $stats_file failed.");
				system("$cmd_rm -f " . $tmp_perf_file );
				exit SVCPRF118E;
			}
			$Nn_last[$node] = $stats_file;
		}

		# Handle VDisk stats file
		if(not defined $Nv_last[$node]) { $Nv_last[$node] = "" }
		if($stats_file =~ m/Nv/ && $stats_file gt $Nv_last[$node]) {
			if($debug_full) {message("Copy iostat file: ".$stats_file);}
			$command = "$scp$stats_file $iosdir";
			if (! defined cmd_exec($command) ) {
				error("Upload IOSTAT file $stats_file failed.");
				system("$cmd_rm -f " . $tmp_perf_file );
				exit SVCPRF118E;
			}
			$Nv_last[$node] = $stats_file;
		}

		# Handle MDisk stats file
		if(not defined $Nm_last[$node]) { $Nm_last[$node] = "" }
		if($stats_file =~ m/Nm/ && $stats_file gt $Nm_last[$node]) {
			if($debug_full) {message("Copy iostat file: ".$stats_file);}
			$command = "$scp$stats_file $iosdir";
			if (! defined cmd_exec($command) ) {
				error("Upload IOSTAT file $stats_file failed.");
				system("$cmd_rm -f " . $tmp_perf_file );
				exit SVCPRF118E;
			}
			$Nm_last[$node] = $stats_file;
		}

		# Handle Drive stats file
		if(not defined $Nd_last[$node]) { $Nd_last[$node] = "" }
		if($stats_file =~ m/Nd/ && $stats_file gt $Nd_last[$node]) {
			if($debug_full) {message("Copy iostat file: ".$stats_file);}
			$command = "$scp$stats_file $iosdir";
			if (! defined cmd_exec($command) ) {
				error("Upload IOSTAT file $stats_file failed.");
				system("$cmd_rm -f " . $tmp_perf_file );
				exit SVCPRF118E;
			}
			$Nd_last[$node] = $stats_file;
		}
	}
}


sub OneTimeStatsList {
	my $stats_list = shift;
	my (@tlist,@a);
	# Get timestamp form filenames
	foreach my $line (@{$stats_list}) {
		chomp($line);
		if ($line =~ /^[-\w]+_(\d{6}_\d{6})$/) {
			my $tm = $1;
			push(@tlist,$tm);
		}
	}
	@tlist = sort(@tlist);
	#print STDERR Dumper(\@tlist);
	# Search next time after last time
	my $tm = shift(@tlist);
	while (@tlist) {

		if ( $tm le $time_last) {
			$tm = shift(@tlist);
		} else {
			last;
		}
	}
	if ( $tm lt $time_last) {
		return \@a;
	}
	if ( $tm eq $time_last) {
		return \@a;
	}
	# Search file with last time
	foreach my $line (@{$stats_list}) {
		chomp($line);
		if ($line =~ /^[-\w]+_$tm$/) {
			push(@a,$line);
		}
	}
	# Set new last time
	$time_last = $tm;
	return \@a;
}

sub Check_iostats_files {
	my ($nodes,$stats) = @_;
	my $nd;
	foreach $nd (@{$nodes}) {
		my $num_files = 0;
		foreach my $stats_name (@{$stats}) {
			chomp($stats_name);
			if($stats_name =~ /^N[dmnv]_stats_${nd}_.*$/) {
				$num_files++;
			}
		}
		if ($num_files != 4) { return 0; }
	}
	return 1;
}


sub Process_iostats_files {
	my $stats = shift;
	if($debug_full){&message("Process IOSTAT files:");}
	foreach my $line_DIR (@{$stats}) {
		$stats_file = $line_DIR;
		chomp($stats_file);
		if($debug_full){&message("        ".$stats_file);}
		&SVC::Data_insert($iosdir,$stats_file,$last_data_ref,$debug_full);
	}
}

sub Retrieve_previous_data {
	# Chech if exist previous data
	if ( not -r $tmp_perf_file ) {
		if($debug) {&message("No previous data. Store data to file: $tmp_perf_file.\n Continue.")};
		if ( ! defined store($last_data_ref, $tmp_perf_file) ) {
			message("svcperf.pl: ERROR: Store data to file $tmp_perf_file failed.");
			system("$cmd_rm -f " . $tmp_perf_file );
			exit SVCPRF110E;
		}
		return 1;
	}

	# Retrieve previous data from temporary file
	$prev_data_ref = retrieve($tmp_perf_file);
	if ( ! defined $prev_data_ref ) {
		&message("Retrieve data from file $tmp_perf_file failed.");
		system("$cmd_rm -f " . $tmp_perf_file );
		exit SVCPRF112E;
	}
	return 0;
}

sub Validate_iostat_data {
	my $data_ref = shift;
    # Check previous data validity
    my @nodes = keys(%{$data_ref->{svc_node}});
    if ( scalar(@nodes) == 0 ) {
        if($debug) { message("Data is not valid. Continue.")};
        return 1;
    }
    if ( not defined $data_ref->{svc_node}->{$nodes[0]}->{timestamp} || "x$data_ref->{svc_drive}->{$nodes[0]}->{timestamp}" eq "x" ) {
        return 1;
    }
}

sub Process_iostat_data {
	my @prev_nodes = keys(%{$prev_data_ref->{svc_node}});
    my $prev_time = str2time($prev_data_ref->{svc_node}->{$prev_nodes[0]}->{timestamp});
    my @last_nodes = keys(%{$last_data_ref->{svc_node}});
    my $last_time = str2time($last_data_ref->{svc_node}->{$last_nodes[0]}->{timestamp});

    if ( $last_time < $prev_time ) {
        if($debug) { message("svcperf.pl: Previous data is not valid. Exiting.")};
		system("$cmd_rm -f " . $tmp_perf_file );
		exit SVCPRF117E;
    }
    if ( $last_time == $prev_time ) {
        if($debug_full) {&message("No new data. Continue.")};
        return 1;
    }
    # Store latest data
	if($debug_full) {&message("svcperf.pl: Store actual data to file: ".$tmp_perf_file.".")};
	if ( ! defined store($last_data_ref, $tmp_perf_file) ) {
		message("ERROR: Store data to file $tmp_perf_file failed.");
		system("$cmd_rm -f " . $tmp_perf_file );
		exit SVCPRF111E;
	}
	# Set output filename
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($last_time);
    $year += 1900;
    $mon++;
    my $date = sprintf("%4d%2.2d%2.2d",$year,$mon,$mday);
    my $time = sprintf("%2.2d%2.2d%2.2d",$hour,$min,$sec);
    $out_perf_file = $tmpdir . $storage . "_svcperf_" . $date . "_" . $time . ".out";
	if($debug_full) {&message("Performance Output Filename: ".$out_perf_file.".")};

	# Get Latest Config Data
	$tmp_conf_file = &GetConfigFilename();
	if($debug) {message("Config Filename: " . $tmpdir . $tmp_conf_file)};
	if (! defined $tmp_conf_file || ! -r $tmpdir . $tmp_conf_file ) {
		message("Config File not found");
		exit SVCPRF114E;
	}
	$cfg_ref = retrieve($tmpdir . $tmp_conf_file);
	# Check configuration data validity
    if (! scalar(%{$cfg_ref}) ) {
        if($debug) { message("Configuration data is not valid. Exiting.")};
		system("$cmd_rm -f " . $tmp_conf_file );
		exit SVCPRF119E;
    }
	# Read Full Config Data
	if ( -r $tmpdir . $tmp_conf_full_file ) {
		$fullcfg_ref = retrieve($tmpdir . $tmp_conf_full_file);
	}

	if($debug_full) {&message("Configuration and Previous performance data is valid. Continue.")};

	# Get Capacity data
	&GetCapacityData();
	# Count performance data
	$ret = &SVC::CountPerfData($out_perf_file,$prev_data_ref,$last_data_ref,$mdiskgrp_cap,$cfg_ref,$fullcfg_ref,$debug_full);
	if($ret) {
		&warning("Latest data is not valid. Continue.");
		return 1;
	}

}

sub	GetCapacityData {
	#
	&MDiskGroupCapacityData();
}

sub MDiskGroupCapacityData {
	undef %mdiskgrp_cap;
	my $tier_level = 1;
	my $record_ref;
	my $list = &ListMdiskGrp;
	if($debug_full) {message("List MDisk Group IDs: ".$list);}
	my $cmd = $ssh." \"for i in ".$list."; do svcinfo lsmdiskgrp -bytes -delim : \\\$i;echo '*****';done\"";
	#if($debug_full) {message("Run: ".$cmd);}
	foreach my $line (`$cmd`) {
		chomp($line);
		if ( $line eq "*****" ) {
			# Record last line
			$mdiskgrp_cap->{$record_ref->{name}} = $record_ref;
			next;
		}
		my @a = split(':',$line);
		if ( $a[0] eq "id" ) {
			# New record first line
			my %rec; $record_ref = \%rec;
			&InitMdiskGrpRecord($record_ref);
			$record_ref->{$a[0]} = $a[1];
		} elsif ( $a[0] eq "site_id" && ! defined $a[1] ) {
			$record_ref->{$a[0]} = "";
		} elsif ( $a[0] eq "site_name" && ! defined $a[1] ) {
			$record_ref->{$a[0]} = "";
		} elsif ( defined $a[0] && ! defined $a[1] ) {
			# Value is not set - suppress
			next;
		} elsif ( $a[0] eq "tier" && $a[1] eq "generic_ssd" || $a[1] eq "ssd" ) { # set TIER Level 0
			$tier_level = 0;
			$record_ref->{tier_0} = $a[1];
		} elsif ( $a[0] eq "tier" && $a[1] eq "generic_hdd" || $a[1] eq "enterprise" ) { # set TIER Level 1
			$tier_level = 1;
			$record_ref->{tier_1} = $a[1];
		} elsif ( $a[0] eq "tier" ) { # set TIER Level 2
			$tier_level = 2;
			$record_ref->{tier_2} = $a[1];
		} elsif ( $a[0] eq "tier_mdisk_count" ) {
			$record_ref->{"tier_" . $tier_level . "_mdisk_count"} = $a[1];
		} elsif ( $a[0] eq "tier_capacity" ) {
			$record_ref->{"tier_" . $tier_level . "_capacity"} = $a[1];
		} elsif ( $a[0] eq "tier_free_capacity" ) {
			$record_ref->{"tier_" . $tier_level . "_free_capacity"} = $a[1];
		} else {
			$record_ref->{$a[0]} = $a[1];
		}
	}
}

sub ListMdiskGrp {
	#
	my @list;
	foreach my $line_LSMDISKGRP (`$ssh svcinfo lsmdiskgrp -nohdr -delim :`) {
		my @field_LSMDISKGRP = split(':', $line_LSMDISKGRP);
		#
		push(@list,$field_LSMDISKGRP[0]);
	}
	return(join(" ",@list));
}

sub InitMdiskGrpRecord {
        my $c = shift;
        $c->{tier_0} = "ssd";
	$c->{tier_0_mdisk_count} = 0;
        $c->{tier_0_capacity} = 0;
        $c->{tier_0_free_capacity} = 0;
        $c->{tier_1} = "enterprise";
	$c->{tier_1_mdisk_count} = 0;
        $c->{tier_1_capacity} = 0;
        $c->{tier_1_free_capacity} = 0;
        $c->{tier_2} = "nearline";
	$c->{tier_2_mdisk_count} = 0;
        $c->{tier_2_capacity} = 0;
        $c->{tier_2_free_capacity} = 0;
}

sub GetConfigFilename {
    my @a;
    foreach my $line_LS (`$cmd_ls $tmpdir`) {
        chomp($line_LS);
        # Select Config Data file
        if( $line_LS =~ /^${storage}_svcconf_\d+_\d+.data$/ ) {
            push(@a,$line_LS);
        }
    }
    my @b = sort @a;
    return(pop @b);
}

sub ClearData {
	undef %last_data;
	undef %prev_data;
	undef %mdiskgrp_cap;
}

sub Localtime_str {
    # OUT: 150425_095000
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
    my $y = $year - 100;
    my $m = $mon + 1;
    my $str = sprintf("%02d%02d%02d_%02d%02d%02d",$y,$m,$mday,$hour,$min,$sec);
    return($str);
}

sub Read_magic {
	if ( -r $magic_file ) {
		my $ret = open(MAGIC,$magic_file);
		if ( $ret != 1 ) { warning("Cannot open magic file: ".$magic_file); return; }
		while( my $line = <MAGIC> ) {
			chomp($line);
			if ( $line =~ /^.*SVC_DEBUG_FULL\s*=\s*(\d{1})\s*$/ ) {
				$debug = $1;
				$debug_full = $1;
			}
	        }
		close(MAGIC);
	}
}

sub cmd_exec {
	my $cmd = shift;
	$ret = 1;
	my $count = 0; # let it run only 5 times ( 10 x 80 sec timeout in ssh = 800secs)
	while($ret && !$terminate_pgm) {
		$count++;
		#if($debug_full) {message("Run: $cmd");}
		$ret = system("$cmd >> $logfile 2>&1");
		if($ret && $count < 10) {
			warning("Wait 5s and Retry $cmd");
			sleep 5;
			next;
                }
		if($ret && $count == 10) {
                   error("Failed: $cmd : too many attempts : $count");
                   return undef;
                   last;
                }
	}
	return $ret;
}


###############################################################################
#
# CtrlC
#
# 1. Catch SIGINT
# 2. Ternimate process
#
###############################################################################

sub CtrlC {
	$terminate_pgm = 1;
	print("svcperf.pl: Terminating ...\n");
}

