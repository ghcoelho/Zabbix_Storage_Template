#!/usr/bin/perl -w
#
# $Revision: 1.3.1 $

my ($revision) = ('$Revision: 1.3.1 $' =~ /([\d\.]+)/);

# Modules
use strict;
use Storable;
use Data::Dumper;
use Date::Parse;
use HP3PAR;


# Options and their default value
my $storname;                   # HP3PAR storage alias
my $storip;                     # HP3PAR host name (IP address)
my $storuser       = "info";    # HP3PAR user name
my $storkey        = "";        # HP3PAR ssh key file name
my $interval       = 1;         # interval time for data collection
my $mininterval    = 300;       # minimal interval time for data collection (sec)
my $dir            = "..";      # Data directory
my $putty          = 0;         # 1 ... run on Windows

my $debug          = 0;         # Debug mode 0:off, 1:on
my $debug_full     = 0;         # Debug mode 0:off, 1:on
my $timeout;

my $webdir = $ENV{WEBDIR};
my $inputdir = $ENV{INPUTDIR};

my $bindir = $ENV{BINDIR};
if (defined $ENV{STORAGE_NAME}) {
	$storname = $ENV{STORAGE_NAME};
} else {
	print("hp3parperf.pl: HP3PAR storage name alias is required.\n");
	exit(1);
}
if (defined $ENV{'HP3PAR_IP'}) {
	$storip = $ENV{'HP3PAR_IP'};
} else {
	print("hp3parperf.pl: HP3PAR host name or IP address is required.\n");
	exit(1);
}
my $health_status_html =  "$webdir/$storname/health_status.html";
if (defined $ENV{'HP3PAR_USER'}) { $storuser = $ENV{'HP3PAR_USER'}; }
if (defined $ENV{'HP3PAR_KEYFILE'}) { $storkey = $ENV{'HP3PAR_KEYFILE'}; }
if (defined $ENV{'HP3PAR_DIR'}) { $dir = $ENV{'HP3PAR_DIR'}; }
if (defined $ENV{'SAMPLE_RATE'}) { $interval = $ENV{'SAMPLE_RATE'} }
if (defined $ENV{'SAMPLE_RATE'}) { $timeout = $ENV{'SAMPLE_RATE'} }
if (defined $ENV{'PUTTY'}) { $putty = $ENV{'PUTTY'} }
if (defined $ENV{DEBUG}) { $debug = $ENV{DEBUG} }
if (defined $ENV{DEBUG_FULL}) { $debug_full = $ENV{DEBUG_FULL} }

# Main process

# Display parameters
if ($debug) {
	print("
hp3parperf.pl starts with the following parameters ...
\tRevision:                             $revision
\tHP3PAR alias:                         $storname
\tHP3PAR host name or IP:               $storip
\tHP3PAR admin user name:               $storuser
\tHP3PAR admin user SSH key filename:   $storkey
\tInterval time for data collection:    $interval
\tBase Directory for output files:      $dir
\tDebug:                                $debug
\n");
}

my $tmpdir = "$dir/tmp/";       # Directory for temporary files
if ( not -d $tmpdir ) {
	mkdir($tmpdir) or die("ERROR: Cannot create directory $tmpdir. Exitting.")
}

my $out_perf_file;          #
my $out_conf_file;          #

my $ssh;
my $scp;
my $cmd_ls = "/bin/ls";
my $cmd_mv = "/bin/mv";
my $cmd_rm = "/bin/rm";
my $cmd_grep = "/bin/grep";
my $cmd_zip = "/bin/pkzip";
if ($putty) {
	$tmpdir = "$dir\\tmp\\";       # Directory for temporary files
	$cmd_ls = "c:\\unix\\ls";
	$cmd_mv = "c:\\unix\\mv";
	$cmd_rm = "del";
	$cmd_grep = "c:\\unix\\grep";
	$cmd_zip = "c:\\Progra~1\\7-Zip\\7z";
	#my $plink = "c:/Program Files (x86)/PuTTY/plink.exe";
	my $plink = "c:\\Progra~2\\PuTTY\\plink.exe";
	my $pscp = "c:\\Progra~2\\PuTTY\\pscp.exe";
	$ssh = $plink." -i $storkey $storuser\@$storip";
	$scp = $pscp." -i $storkey $storuser\@$storip:";
} elsif(not defined $storkey or "x$storkey" eq "x") {	# with default keyfile (.ssh/id_rsa)
	$ssh = "ssh $storuser\@$storip";
	$scp = "scp $storuser\@$storip:";
} else {		        #
	$ssh = "ssh -i $storkey $storuser\@$storip";
	$scp = "scp -i $storkey  $storuser\@$storip:";
}


sub message {
	my $msg = shift;
	my $tm = localtime();
	print($tm." INFO    :"." hp3parperf.pl: ".$msg."\n") if ( $debug );
}

sub warning {
	my ($msg,$rc) = @_;
	my $tm = localtime();
	print STDERR ($tm." WARNING :"." hp3parperf.pl: ".$msg."\n");
}

sub error {
	my ($msg,$rc) = @_;
	my $tm = localtime();
	if( defined $rc ) {
		print STDERR ($tm." ERROR   :"." hp3parperf.pl: ".$msg." - return code: ".$rc."\n");
	} else {
		print STDERR ($tm." ERROR   :"." hp3parperf.pl: ".$msg."\n");
	}
		
}

my @servers = qw(showspace shownode showhost showcpg showld showvv showvvcpg showvlun showport showpd statcpu statld statvv statport);  # statpd statcmp
my $time_str = &localtime_str;
##### Off-line #######
# my $time_str = "160325_180501";
# &message("Process off-line files.");
# &HP3PAR::process_files(\@servers,$dir,$storname,$time_str,$interval);
# exit;
######################

if ( $debug == 1 ) { my $tm = localtime(); printf("%s INFO    : hp3parperf.pl : Revision: %s\n\tServers: ",$tm,$revision); }
my @children = {};
foreach my $server (@servers) {
    my $pid;
    next if $pid = fork;    # Parent goes to next server.
    unless( defined $pid ) { error("Fork failed: $!",101); exit 101; }
    # From here on, we're in the child. The server we want to deal
    # with is in $server.
    if ( $debug == 0 ) { printf("%s ",$server); }
    &childsrv($server);
}

# parent waits until all child processes have finished
&message("Parent ($$)");
if ( not defined($timeout) or $timeout eq '' ) {
   	$timeout = 1800;
} else {
   	$timeout = $timeout * 6;
}
# set alarm on first SSH command to make sure it does not hang
eval {
   	local $SIG{ALRM} = sub {&error("Parent died in SIG ALRM",102); exit 102; };
   	alarm($timeout);
	# Waiting for childs ends.
	while ( 1 ) {
		my $pid_found = wait();
		my $rc = $?;
		if ( $pid_found == -1 ) { last; }
		my $msg = sprintf("Child (%s) exited with code %s (%x) = %d", $pid_found, $rc, $rc, $rc >> 8);
		if ( $rc == 0 ) {
			&message($msg);
		} else {
			&error($msg);
		}
		push(@children,$pid_found);
	}
    # end of alarm
    alarm (0);
};

&message("All childern done! Process files.");
if ( $debug == 0 ) { my $tm = localtime(); printf("\n%s INFO    : hp3parperf.pl : Process files [%s].\n",$tm,$time_str); }
&HP3PAR::process_files(\@servers,$dir,$storname,$time_str,$interval,$debug);
&HP3PAR::set_global_health_status_summary($storname,$inputdir,$health_status_html,$time_str);
&message("Delete files.");
&deletefiles;
&message("Done.");

exit 0;

sub childsrv {
	my $name = shift;
	if( $name eq "showspace" )  { sleep 25; &server_showspace; };
	if( $name eq "showhost" )   { sleep 30; &server_showhost; };
	if( $name eq "showcpg" )    { sleep 35; &server_showcpg; };
	if( $name eq "showvvcpg" )  { sleep 40; &server_showvvcpg; };
	if( $name eq "showld" )     { sleep 45; &server_showld; };
	if( $name eq "showvv" )     { sleep 50; &server_showvv; };
	if( $name eq "showvlun" )   { sleep 55; &server_showvlun; };
	if( $name eq "showport" )   { sleep 60; &server_showport; };
	if( $name eq "shownode" )   { sleep 65; &server_shownode; };
	if( $name eq "showpd" )     { sleep 70; &server_showpd; };
	if( $name eq "statcpu" )    {           &server_statcpu; };
	if( $name eq "statld" )     { sleep  5; &server_statld; };
	if( $name eq "statvv" )     { sleep 10; &server_statvv; };
	if( $name eq "statport" )   { sleep 15; &server_statport; };
	if( $name eq "statpd" )     { sleep 20; &server_statpd; };
}

sub server_showspace {
	if ( not defined $timeout or $timeout eq '' ) {
    	$timeout = 30;
	} else {
    	$timeout = $timeout * 3;
	}
	# set alarm on first SSH command to make sure it does not hang
	eval {
    	local $SIG{ALRM} = sub {&error("Child server showspace died in SIG ALRM",103); exit 103; };
    	alarm($timeout);
		# cmd
		my $filename = $tmpdir.$storname.".showspace.".$time_str.".txt";
		my $command = $ssh." showsys -space";
		message("\tChild server showspace ($$) - output: ".$filename);
		my($exit,$stdout) = &execcmd($command);  
		if ($exit != 0) { error("Command showspace failed with code ".$exit); exit 150; }  
		open(my $tmpfile, '>', $filename);
		foreach my $ln ( @{$stdout} ) {
			print $tmpfile $ln;
		}
		close $tmpfile;
		#
    	# end of alarm
    	alarm (0);
	};
    exit 0;  # Ends the child process.
}

sub server_shownode {
	if ( not defined $timeout or $timeout eq '' ) {
    	$timeout = 30;
	} else {
    	$timeout = $timeout * 3;
	}
	# set alarm on first SSH command to make sure it does not hang
	my $filename = $tmpdir.$storname.".shownode.".$time_str.".txt";
	message("\tChild server shownode ($$) - output: ".$filename);
	eval {
    	local $SIG{ALRM} = sub {&error("Child server shownode died in SIG ALRM",103); exit 103; };
    	alarm($timeout);
		# cmd
		my $command = $ssh." shownode -state";
		message("\tChild server shownode-state ($$) - output: ".$filename);
		my($exit,$stdout) = &execcmd($command);  
		if ($exit != 0) { error("Command shownode-state failed with code ".$exit); exit 150; }  
		open(my $tmpfile, '>', $filename);
		foreach my $ln ( @{$stdout} ) {
			print $tmpfile $ln;
		}
		close $tmpfile;
		#
    	# end of alarm
    	alarm (0);
	};
	eval {
    	local $SIG{ALRM} = sub {&error("Child server shownode died in SIG ALRM",103); exit 103; };
    	alarm($timeout);
		# cmd
		my $command = $ssh." shownode -ps";
		message("\tChild server shownode-ps ($$) - output: ".$filename);
		my($exit,$stdout) = &execcmd($command);  
		if ($exit != 0) { error("Command shownode-ps failed with code ".$exit); exit 150; }  
		open(my $tmpfile, '>>', $filename);
		foreach my $ln ( @{$stdout} ) {
			print $tmpfile $ln;
		}
		close $tmpfile;
		#
    	# end of alarm
    	alarm (0);
	};
	
    exit 0;  # Ends the child process.
}

sub server_showhost {
	if ( not defined $timeout or $timeout eq '' ) {
    	$timeout = 30;
	} else {
    	$timeout = $timeout * 3;
	}
	# set alarm on first SSH command to make sure it does not hang
	eval {
    	local $SIG{ALRM} = sub {&error("Child server showhost died in SIG ALRM",103); exit 103; };
    	alarm($timeout);
		# cmd
		my $filename = $tmpdir.$storname.".showhost.".$time_str.".txt";
		my $command = $ssh." showhost -d";
		message("\tChild server showhost ($$) - output: ".$filename);
		my($exit,$stdout) = &execcmd($command);  
		if ($exit != 0) { error("Command showhost failed with code ".$exit); exit 150; }  
		open(my $tmpfile, '>', $filename);
		foreach my $ln ( @{$stdout} ) {
			print $tmpfile $ln;
		}
		close $tmpfile;
		#
    	# end of alarm
    	alarm (0);
	};
	
    exit 0;  # Ends the child process.
}

sub server_showcpg {
	if ( not defined $timeout or $timeout eq '' ) {
    	$timeout = 30;
	} else {
    	$timeout = $timeout * 3;
	}
	# set alarm on first SSH command to make sure it does not hang
	eval {
    	local $SIG{ALRM} = sub {&error("Child server showcpg died in SIG ALRM",103); exit 103; };
    	alarm($timeout);
		# cmd
		my $filename = $tmpdir.$storname.".showcpg.".$time_str.".txt";
		my $command = $ssh." showcpg";
		message("\tChild server showvv ($$) - output: ".$filename);
		my($exit,$stdout) = &execcmd($command);  
		if ($exit != 0) { error("Command showcpg failed with code ".$exit); exit 150; }  
		open(my $tmpfile, '>', $filename);
		foreach my $ln ( @{$stdout} ) {
			print $tmpfile $ln;
		}
		close $tmpfile;
		#
    	# end of alarm
    	alarm (0);
	};
	
    exit 0;  # Ends the child process.
}

sub server_showvvcpg {
	if ( not defined $timeout or $timeout eq '' ) {
    	$timeout = 30;
	} else {
    	$timeout = $timeout * 3;
	}
	# set alarm on first SSH command to make sure it does not hang
	eval {
    	local $SIG{ALRM} = sub {&error("Child server showcpg died in SIG ALRM",103); exit 103; };
    	alarm($timeout);
		# cmd
		my $filename = $tmpdir.$storname.".showvvcpg.".$time_str.".txt";
		my $command = $ssh." showvvcpg";
		message("\tChild server showvvcpg ($$) - output: ".$filename);
		my($exit,$stdout) = &execcmd($command);  
		if ($exit != 0) { error("Command showvvcpg failed with code ".$exit); exit 150; }  
		open(my $tmpfile, '>', $filename);
		foreach my $ln ( @{$stdout} ) {
			print $tmpfile $ln;
		}
		close $tmpfile;
		#
    	# end of alarm
    	alarm (0);
	};
	
    exit 0;  # Ends the child process.
}

sub server_showld {
	if ( not defined $timeout or $timeout eq '' ) {
    	$timeout = 30;
	} else {
    	$timeout = $timeout * 3;
	}
	# set alarm on first SSH command to make sure it does not hang
	my $filename = $tmpdir.$storname.".showld.".$time_str.".txt";
	message("\tChild server showld ($$) - output: ".$filename);
	eval {
    	local $SIG{ALRM} = sub {&error("Child server showld died in SIG ALRM",103); exit 103; };
    	alarm($timeout);
		# cmd
		my $command = $ssh." showld";
		my($exit,$stdout) = &execcmd($command);  
		if ($exit != 0) { error("Command showld failed with code ".$exit); exit 150; }  
		open(my $tmpfile, '>', $filename);
		foreach my $ln ( @{$stdout} ) {
			print $tmpfile $ln;
		}
		close $tmpfile;
		#
    	# end of alarm
    	alarm (0);
	};
	eval {
    	local $SIG{ALRM} = sub {&error("Child server showld died in SIG ALRM",103); exit 103; };
    	alarm($timeout);
		# cmd
		my $command = $ssh." showld -d";
		message("\tChild server showld-d ($$) - output: ".$filename);
		my($exit,$stdout) = &execcmd($command);  
		if ($exit != 0) { error("Command showld-d failed with code ".$exit); exit 150; }  
		open(my $tmpfile, '>>', $filename);
		foreach my $ln ( @{$stdout} ) {
			print $tmpfile $ln;
		}
		close $tmpfile;
		#
    	# end of alarm
    	alarm (0);
	};
	eval {
    	local $SIG{ALRM} = sub {&error("Child server showld died in SIG ALRM",103); exit 103; };
    	alarm($timeout);
		# cmd
		my $command = $ssh." showld -state";
		message("\tChild server showld-state ($$) - output: ".$filename);
		my($exit,$stdout) = &execcmd($command);  
		if ($exit != 0) { error("Command showld-state failed with code ".$exit); exit 150; }  
		open(my $tmpfile, '>>', $filename);
		foreach my $ln ( @{$stdout} ) {
			print $tmpfile $ln;
		}
		close $tmpfile;
		#
    	# end of alarm
    	alarm (0);
	};
	
    exit 0;  # Ends the child process.
}

sub server_showvv {
	if ( not defined $timeout or $timeout eq '' ) {
    	$timeout = 30;
	} else {
    	$timeout = $timeout * 3;
	}
	# set alarm on first SSH command to make sure it does not hang
	eval {
    	local $SIG{ALRM} = sub {&error("Child server showvv died in SIG ALRM",103); exit 103; };
    	alarm($timeout);
		# cmd
		my $filename = $tmpdir.$storname.".showvv.".$time_str.".txt";
		my $command = $ssh." showvv -showcols Id,Name,Prov,Type,CopyOf,BsId,Rd,State,Adm_Rsvd_MB,Snp_Rsvd_MB,Usr_Rsvd_MB,VSize_MB,Detailed_State";
		message("\tChild server showvv ($$) - output: ".$filename);
		my($exit,$stdout) = &execcmd($command);  
		if ($exit != 0) { error("Command showvv failed with code ".$exit); exit 150; }  
		open(my $tmpfile, '>', $filename);
		foreach my $ln ( @{$stdout} ) {
			print $tmpfile $ln;
		}
		close $tmpfile;
		#
    	# end of alarm
    	alarm (0);
	};
	
    exit 0;  # Ends the child process.
}

sub server_showport {
	if ( not defined $timeout or $timeout eq '' ) {
    	$timeout = 30;
	} else {
    	$timeout = $timeout * 3;
	}
	# set alarm on first SSH command to make sure it does not hang
	eval {
    	local $SIG{ALRM} = sub {&error("Child server showport died in SIG ALRM",103); exit 103; };
    	alarm($timeout);
		# cmd
		my $filename = $tmpdir.$storname.".showport.".$time_str.".txt";
		my $command = $ssh." showport";
		message("\tChild server showport ($$) - output: ".$filename);
		my($exit,$stdout) = &execcmd($command);  
		if ($exit != 0) { error("Command shoport failed with code ".$exit); exit 150; }  
		open(my $tmpfile, '>', $filename);
		foreach my $ln ( @{$stdout} ) {
			print $tmpfile $ln;
		}
		close $tmpfile;
		#
    	# end of alarm
    	alarm (0);
	};
    exit 0;  # Ends the child process.
}

sub server_showvlun {
	if ( not defined $timeout or $timeout eq '' ) {
    	$timeout = 30;
	} else {
    	$timeout = $timeout * 3;
	}
	# set alarm on first SSH command to make sure it does not hang
	eval {
    	local $SIG{ALRM} = sub {&error("Child server showvlun died in SIG ALRM",103); exit 103; };
    	alarm($timeout);
		# cmd
		my $filename = $tmpdir.$storname.".showvlun.".$time_str.".txt";
		my $command = $ssh." showvlun";
		message("\tChild server showvlun ($$) - output: ".$filename);
		my($exit,$stdout) = &execcmd($command);  
		if ($exit != 0) { error("Command showvlun failed with code ".$exit); exit 150; }  
		open(my $tmpfile, '>', $filename);
		foreach my $ln ( @{$stdout} ) {
			print $tmpfile $ln;
		}
		close $tmpfile;
		#
    	# end of alarm
    	alarm (0);
	};
	
    exit 0;  # Ends the child process.
}


sub server_showpd {
	if ( not defined $timeout or $timeout eq '' ) {
    	$timeout = 30;
	} else {
    	$timeout = $timeout * 3;
	}
	# set alarm on first SSH command to make sure it does not hang
	eval {
    	local $SIG{ALRM} = sub {&error("Child server showpd died in SIG ALRM",103); exit 103; };
    	alarm($timeout);
		# cmd
		my $filename = $tmpdir.$storname.".showpd.".$time_str.".txt";
		my $command = $ssh." showpd";
		message("\tChild server showpd ($$) - output: ".$filename);
		my($exit,$stdout) = &execcmd($command);  
		if ($exit != 0) { error("Command showpd failed with code ".$exit); exit 150; }  
		open(my $tmpfile, '>', $filename);
		foreach my $ln ( @{$stdout} ) {
			print $tmpfile $ln;
		}
		close $tmpfile;
		#
    	# end of alarm
    	alarm (0);
	};
	
    exit 0;  # Ends the child process.
}


sub server_statcpu {
	if ( not defined $timeout or $timeout eq '' ) {
    	$timeout = 30;
	} else {
    	$timeout = $timeout * 3;
	}
	# set alarm on first SSH command to make sure it does not hang
	eval {
    	local $SIG{ALRM} = sub {&error("Child server statcpu died in SIG ALRM",103); exit 103; };
    	alarm($timeout);
		# cmd
		my $filename = $tmpdir.$storname.".statcpu.".$time_str.".txt";
		my $command = $ssh." statcpu -d ".$interval." -iter 1";
		message("\tChild server statcpu ($$) - output: ".$filename);
		my ($exit,$stdout) = &execcmd($command);  
		if ($exit != 0) { error("Command statcpu failed with code ".$exit); exit 150; }  
		open(my $tmpfile, '>', $filename);
		foreach my $ln ( @{$stdout} ) {
			print $tmpfile $ln;
		}
		close $tmpfile;
		#
    	# end of alarm
    	alarm (0);
	};
	
    exit 0;  # Ends the child process.
}

sub server_statld {
	if ( not defined $timeout or $timeout eq '' ) {
    	$timeout = 30;
	} else {
    	$timeout = $timeout * 3;
	}
	# set alarm on first SSH command to make sure it does not hang
	eval {
    	local $SIG{ALRM} = sub {&error("\tChild server statld died in SIG ALRM",104); exit 104; };
    	alarm($timeout);
		# cmd
		my $filename = $tmpdir.$storname.".statld.".$time_str.".txt";
		my $command = $ssh." statld -rw -d ".$interval." -iter 1";
		message("\tChild server statld ($$) - output: ".$filename);
		my ($exit,$stdout) = &execcmd($command);  
		if ($exit != 0) { error("Command statld failed with code ".$exit); exit 150; }  
		open(my $tmpfile, '>', $filename);
		foreach my $ln ( @{$stdout} ) {
			print $tmpfile $ln;
		}
		close $tmpfile;
    	# end of alarm
    	alarm (0);
	};
	
    exit 0;  # Ends the child process.
}

sub server_statport {
	if ( not defined $timeout or $timeout eq '' ) {
    	$timeout = 30;
	} else {
    	$timeout = $timeout * 3;
	}
	# set alarm on first SSH command to make sure it does not hang
	eval {
    	local $SIG{ALRM} = sub {&error("\tChild server statport died in SIG ALRM",104); exit 104; };
    	alarm($timeout);
		# cmd
		my $filename = $tmpdir.$storname.".statport.".$time_str.".txt";
		my $command = $ssh." statport -rw -d ".$interval." -iter 1";
		message("\tChild server statport ($$) - output: ".$filename);
		my ($exit,$stdout) = &execcmd($command);  
		if ($exit != 0) { error("Command statport failed with code ".$exit); exit 150; }  
		open(my $tmpfile, '>', $filename);
		foreach my $ln ( @{$stdout} ) {
			print $tmpfile $ln;
		}
		close $tmpfile;
    	# end of alarm
    	alarm (0);
	};
	
    exit 0;  # Ends the child process.
}

sub server_statpd {
	if ( not defined $timeout or $timeout eq '' ) {
    	$timeout = 30;
	} else {
    	$timeout = $timeout * 3;
	}
	# set alarm on first SSH command to make sure it does not hang
	eval {
    	local $SIG{ALRM} = sub {&error("\tChild server statpd died in SIG ALRM",104); exit 104; };
    	alarm($timeout);
		# cmd
		my $filename = $tmpdir.$storname.".statpd.".$time_str.".txt";
		my $command = $ssh." statpd -rw -d ".$interval." -iter 1";
		message("\tChild server statpd ($$) - output: ".$filename);
		my ($exit,$stdout) = &execcmd($command);
		if ($exit != 0) { error("Command statpd failed with code ".$exit); exit 150; }  
		open(my $tmpfile, '>', $filename);
		foreach my $ln ( @{$stdout} ) {
			print $tmpfile $ln;
		}
		close $tmpfile;
    	# end of alarm
    	alarm (0);
	};
	
    exit 0;  # Ends the child process.
}

sub server_statvv {
	if ( not defined $timeout or $timeout eq '' ) {
    	$timeout = 30;
	} else {
    	$timeout = $timeout * 3;
	}
	# set alarm on first SSH command to make sure it does not hang
	eval {
    	local $SIG{ALRM} = sub {&error("\tChild server statvv died in SIG ALRM",104); exit 104; };
    	alarm($timeout);
		# cmd
		my $filename = $tmpdir.$storname.".statvv.".$time_str.".txt";
		my $command = $ssh." statvv -rw -d ".$interval." -iter 1";
		message("\tChild server statvv ($$) - output: ".$filename);
		my ($exit,$stdout) = &execcmd($command);  
		if ($exit != 0) { error("Command statvv failed with code ".$exit); exit 150; }  
		open(my $tmpfile, '>', $filename);
		foreach my $ln ( @{$stdout} ) {
			print $tmpfile $ln;
		}
		close $tmpfile;
    	# end of alarm
    	alarm (0);
	};
	
    exit 0;  # Ends the child process.
}

sub execcmd {
        my $cmd = "@_";
        my $ret_value; my $msg;
        my $rc = 0;
        my @out;
        #
        if ($debug) { message("Execute: @_"); }
        (@out = `@_`);
        $ret_value = $?;
        if ($ret_value == -1) {
                $msg = sprintf "Failed to execute: $!\n";
                if ($debug) { message($msg); }
                $rc = -1;
        } elsif ($ret_value & 127) {
                $msg = sprintf "Command \'%s\' died with signal %d\n",$cmd,($ret_value & 127);
                if ($debug) { message($msg); }
                $rc = ($ret_value & 127);
        } else {
                $msg = sprintf "Command \'%s\' exited with value %d\n",$cmd,$ret_value >> 8;
                if ($debug) { message($msg); }
                $rc = ($ret_value >> 8);
        }
        return ($rc,\@out);
}

sub localtime_str {
    # OUT: 150425_095000
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
    my $y = $year - 100;
    my $m = $mon + 1;
    my $str = sprintf("%02d%02d%02d_%02d%02d%02d",$y,$m,$mday,$hour,$min,$sec);
    return($str);
}

sub deletefiles {
	my $command = $cmd_rm." ".$tmpdir."*".$time_str.".txt";
	my ($exit,$stdout) = &execcmd($command);
}
