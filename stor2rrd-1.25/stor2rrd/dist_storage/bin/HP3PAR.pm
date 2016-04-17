#
# 3PAR.pm
#
# v1.2.0

# Changes:
# New release
# Add showsys space

package HP3PAR;  #

use Carp;
require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT    = qw();
our @EXPORT_OK = qw();
our $VERSION   = 1.2;


# Modules
use strict;
use Storable qw(retrieve store);
use Data::Dumper;

# 
my %storids;
my %stordata;
my $debug;
my %storstate;

$storstate{'node'}  = { "OK"=>"Normal","Degraded"=>"Warning","Failed"=>"Critical" };
$storstate{'ld'}    = { "normal"=>"Normal","degraded"=>"Warning","failed"=>"Critical" };
$storstate{'vvol'}  = { "normal"=>"Normal","degraded"=>"Warning","failed"=>"Critical" };
$storstate{'port'}  = { "ready"=>"Normal","loss_sync"=>"Warning","config_wait"=>"Warning","login_wait"=>"Warning",
                         "alpa_wait"=>"Warning","non_participate"=>"Warning","taking_coredump"=>"Warning",
                         "offline"=>"Warning","link_idle_for_reset"=>"Warning","dhcp_in_progress"=>"Warning","pending_reset"=>"Warning",
                         "unknown"=>"Critical","fw_dead"=>"Critical","error"=>"Critical" };
$storstate{'power'}  = { "OK"=>"Normal","Degraded"=>"Warning","NotPresent"=>"Warning","Failed"=>"Critical" };
$storstate{'pd'}  = { "normal"=>"Normal","degraded"=>"Warning","new"=>"Normal","failed"=>"Critical" };


sub process_files {
	my ($servers,$dir,$storname,$time_str,$interval,$debug) = @_;
	$stordata{'server_time'} = $time_str;
	$stordata{'interval'} = $interval;
	$stordata{'out_conf_file'} = $dir."/".$storname."_hp3parconf_".$time_str.".out";
	$stordata{'out_perf_file'} = $dir."/".$storname."_hp3parperf_".$time_str.".out";
	$stordata{'out_state_file'} = $dir."/".$storname."_hp3parstate_".$time_str.".out";
	#
	my $tmpdir = "$dir/tmp/";       # Directory for temporary files
	#
	foreach my $name ( @{$servers} ) {
		my $filename = $tmpdir.$storname.".".$name.".".$time_str.".txt";
		#&message("Process file: ".$filename);
		if (-r $filename ) {
			&message("Process file: ".$filename);
			&parse_showspace($filename) if( $name eq "showspace" );
			&parse_shownode($filename) if( $name eq "shownode" );
			&parse_showcpg($filename) if( $name eq "showcpg" );
			&parse_showport($filename) if( $name eq "showport" );
			&parse_showld($filename) if( $name eq "showld" );
			&parse_showvvcpg($filename) if( $name eq "showvvcpg" );
			&parse_showvv($filename) if( $name eq "showvv" );
			&parse_showvlun($filename) if( $name eq "showvlun" );
			&parse_showhost($filename) if( $name eq "showhost" );
			&parse_showpd($filename) if( $name eq "showpd" );
			&parse_statld($filename) if( $name eq "statld" );
			&parse_statvv($filename) if( $name eq "statvv" );
			&parse_statcpu($filename) if( $name eq "statcpu" );
			&parse_statport($filename) if( $name eq "statport" );
		}
	}
	# Print output perf file
	foreach my $key ( sort( keys(%stordata) ) ) {
		#print("__DBG__: Data - $key\n",Dumper($stordata{$key}));
		&print_perf_cpu if( $key eq "cpu" );
		&print_conf_vvol if( $key eq "vvol" );
		&print_perf_vvol if( $key eq "vvol" );
		&print_state_vvol if( $key eq "vvol" );
		&print_conf_cpg if( $key eq "cpg" );
		&print_conf_ld if( $key eq "ld" );
		&print_perf_ld if( $key eq "ld" );
		&print_state_ld if( $key eq "ld" );
		&print_conf_port if( $key eq "port" );
		&print_perf_port if( $key eq "port" );
		&print_state_port if( $key eq "port" );
		&print_conf_host if( $key eq "host" );
		&print_conf_sys if( $key eq "sys" );
		&print_state_node if( $key eq "node" );
		&print_conf_pd if( $key eq "pd" );
		&print_state_pd if( $key eq "pd" );
		
	}
	#print("__DBG__: IDs\n",Dumper(\%storids),"\n");
	#print("__DBG__: IDs\n",Dumper(\%storids{'cpg'}),"\n");
	#print("__DBG__: DATA CPG\n",Dumper($stordata{'cpg'}->{0}),"\n");
	#print("__DBG__: IDs HOST\n",Dumper(\%storids{'host'}),"\n");
	#print("__DBG__: DATA HOST\n",Dumper($stordata{'host'}->{'2'}),"\n");
	#print("__DBG__: IDs LD\n",Dumper(\%storids{'ld'}),"\n");
	#print("__DBG__: DATA LD\n",Dumper($stordata{'ld'}->{30}),"\n");
	#print("__DBG__: IDs PORT\n",Dumper(\$storids{'port'}),"\n");
	#print("__DBG__: DATA PORT\n",Dumper($stordata{'port'}->{'0:3:1'}),"\n");
	#print("__DBG__: DATA VVOL\n",Dumper($stordata{'vvol'}),"\n");
	#print("__DBG__: DATA CPU\n",Dumper($stordata{'cpu'}),"\n");
	#print("__DBG__: DATA CPU\n",Dumper($stordata{'cpu'}->{'0,total'}),"\n");
	#print("__DBG__: DATA NODE\n",Dumper($stordata{'node'}),"\n");
	#print("__DBG__: DATA NODE\n",Dumper($stordata{'power'}),"\n");
	#print("__DBG__: DATA VVOL 988:\n",Dumper($stordata{'vvol'}->{'124'}),"\n");
	#print("__DBG__: DATA SYS\n",Dumper($stordata{'sys'}),"\n");
	#print("__DBG__: DATA PD 0:\n",Dumper($stordata{'pd'}->{'0'}),"\n");
}

sub parse_showspace {
	my $filename = shift;
	if ( not defined $stordata{'sys'} ) {
		my %d; $stordata{'sys'} = \%d;
	}
	&message("parse_showspace: Process file: ".$filename);
	open(my $data,'<',$filename) || die("Cannot open file: ".$filename."\n");
	my $flag = 0;
	while ( my $ln = <$data> ) {
		chomp $ln;
		#print("__DBG__: [$flag]".$ln."\n");
		if ( $ln =~ /^\s*[-]+\s+System\s+Capacity/ ) { $flag = 1; next; }
		if ( $flag && $ln =~ /^\s*([\w]+)\s+:\s+([-\d\.]*)\s*/ ) {
			#print("__DBG_2: Space: ".$1." : ".$2."\n");
			$stordata{'sys'}->{$1} = $2;
		} elsif ( $flag && $ln =~ /^\s*(Total Capacity)\s+:\s+([-\d\.]*)\s*/ ) {
			#print("__DBG_3: Space: ".$1." : ".$2."\n");
			$stordata{'sys'}->{$1} = $2;
		}
	}
	close $data;
	
}

sub print_conf_sys {
	open(my $fh,'>>',$stordata{'out_conf_file'});
	#
    print $fh "\nSystem Level Configuration\n";
	print $fh "\tInterval Start:   ",$stordata{'server_time'},"\t(STOR2RRD Server time)\n";
	print $fh "\tInterval Length:  ",$stordata{'interval'}," seconds\n";
	print $fh "---------------------\n";
	# host_id,id,name,
	# port_count,iogrp_count,status,
	# IQN WWPN,Volume IDs,Volume Names
	#  
	print $fh "Total Capacity,".$stordata{'sys'}->{"Total Capacity"}."\n";
	print $fh "Allocated,".$stordata{'sys'}->{"Allocated"}."\n";
	print $fh "Allocated_Volumes,".$stordata{'sys'}->{"Volumes"}."\n";
	print $fh "Allocated_System,".$stordata{'sys'}->{"System"}."\n";
	print $fh "Free,".$stordata{'sys'}->{"Free"}."\n";
	print $fh "Failed,".$stordata{'sys'}->{"Failed"}."\n";
	
	close($fh);
}    

sub parse_shownode {
	my $filename = shift;
	my %ids; $storids{'node'} = \%ids;
	if ( not defined $stordata{'node'} ) {
		my %d; $stordata{'node'} = \%d;
	}
	&message("parse_shownode: Process file: ".$filename);
	open(my $data,'<',$filename) || die("Cannot open file: ".$filename."\n");
	my $flags = 0; my $flagp = 0;
	while ( my $ln = <$data> ) {
		chomp $ln;
		#print("__DBG__: [$flags,$flagp]".$ln."\n");
		if ( $ln =~ /^\s*Node\s+-State-\s+/ ) { $flags = 1; $flagp = 0; next; }
		if ( $ln =~ /^\s*Node\s+PS\s+/ ) { $flags = 0; $flagp = 1; next; }
		if ( $flags && $ln =~ /^\s*(\d+)\s+([-\w\.]+)\s+([-\w\.]*)/ ) {
			#print("__DBG_2: Node ID: ".$1." - State: ".$2."\n");
			$stordata{'node'}->{$1}->{'state'} = $2;
			$stordata{'node'}->{$1}->{'detailed_state'} = $3;
		}
		if ( $flagp && $ln =~ /^\s*(\d+,\d+)\s+(.*)/ ) {
			#Node PS -Assy_Part- -Assy_Serial-- ACState DCState PSState
			#
			my @a = split(/,/,$1);
			my @b = split(/\s+/,$2);
			#print("__DBG_3: Node ID: ".$1." = ".$a[0]." - State: ".Dumper(\@b)."\n");
			$stordata{'power'}->{$b[0]}->{'ACState'} = $b[3];
			$stordata{'power'}->{$b[0]}->{'DCState'} = $b[4];
			$stordata{'power'}->{$b[0]}->{'PSState'} = $b[5];
		}
	}
	close $data;
	
}

sub print_state_node {
	open(my $fh,'>>',$stordata{'out_state_file'});
	#
    print $fh "\nNode Level State\n";
	print $fh "\tInterval Start:   ",$stordata{'server_time'},"\t(STOR2RRD Server time)\n";
	print $fh "\tInterval Length:  ",$stordata{'interval'}," seconds\n";
	print $fh "---------------------\n";
	#  
	print $fh "Node,State,Level,Detailed_State\n";
	foreach my $id ( sort{$a <=> $b}(keys(%{$stordata{node}})) ) {
		my $state = $stordata{'node'}->{$id}->{"state"};
		printf $fh ("%d,%s,%s,%s,\n",$id,$state,$storstate{'node'}->{$state},$stordata{'node'}->{$id}->{"detailed_state"});
	}
    print $fh "\nPower Level State\n";
	print $fh "\tInterval Start:   ",$stordata{'server_time'},"\t(STOR2RRD Server time)\n";
	print $fh "\tInterval Length:  ",$stordata{'interval'}," seconds\n";
	print $fh "---------------------\n";
	#  
	print $fh "PowerID,State,Level\n";
	foreach my $id ( sort{$a <=> $b}(keys(%{$stordata{power}})) ) {
		my $state = $stordata{'power'}->{$id}->{'PSState'};
		printf $fh ("%d,%s,%s,\n",$id,$state,$storstate{'power'}->{$state});
	}
	
	close($fh);
}    

sub parse_showcpg {
	my $filename = shift;
	my %ids; $storids{'cpg'} = \%ids;
	if ( not defined $stordata{'cpg'} ) {
		my %d; $stordata{'cpg'} = \%d;
	}
	&message("parse_showcpg: Process file: ".$filename);
	open(my $data,'<',$filename) || die("Cannot open file: ".$filename."\n");
	my $flag = 0;
	while ( my $ln = <$data> ) {
		chomp $ln;
		#print("__DBG__: [$flag]".$ln."\n");
		if ( $ln =~ /^\s*Id\s+Name\s+Warn%\s+/ ) { $flag = 1; next; }
		if ( $ln =~ /^[-]+\s*/ ) { $flag = 0; last; }
		if ( $flag && $ln =~ /^\s*(\d+)\s+([-\w\.]+)\s+([-\d\.\s]*)/ ) {
			#print("__DBG_2: CPG ID: ".$1." - Name: ".$2."\n");
			$ids{$2} = $1;
			my %d;
			$d{name} = $2;
			$d{id} = $1;
			my @a = split(/\s+/,$3);
			&cpg_conf($1,$2,\@a);
		}
	}
	close $data;
	
}

sub cpg_conf {
	my ($id,$name,$a) = @_;
	#print("__DBG_2: VVol ID: ".$id." - Name: ".$name." - ".$a->[6]."\n");
	#                                   ------------------(MB)------------------
	#           ----Volumes---- -Usage- ----- Usr ----- ---- Snp ---- -- Adm ---
	#     Warn% VVs TPVVs TDVVs Usr Snp   Total    Used   Total  Used Total Used
	#         -   1     1     0   1   1     512     512   34304   512  8192  128
	#         0   1     2     3   4   5       6       7       8     9    10   11
	my $stat;
	if ( not defined $stordata{'cpg'}->{$id} ) {
		my %d; $stat = \%d; $stordata{'cpg'}->{$id} = $stat;
		$stordata{'cpg'}->{$id}->{'name'} = $name;
		$stordata{'cpg'}->{$id}->{'id'} = $id;
	}
	$stordata{'cpg'}->{$id}->{'usr_tot_cap'} = $a->[6];
	$stordata{'cpg'}->{$id}->{'usr_use_cap'} = $a->[7];
	$stordata{'cpg'}->{$id}->{'snp_tot_cap'} = $a->[8];
	$stordata{'cpg'}->{$id}->{'snp_use_cap'} = $a->[9];
	$stordata{'cpg'}->{$id}->{'adm_tot_cap'} = $a->[10];
	$stordata{'cpg'}->{$id}->{'adm_use_cap'} = $a->[11];
}

sub parse_showvvcpg {
	my $filename = shift;
	if ( not defined $stordata{'cpg'} ) {
		&error("parse_showvvcpg: CPG data not exist");
	}
	if ( not defined $stordata{'vvol'} ) {
		&error("parse_showvvcpg: VVOL data not exist");
	}
	&message("parse_showvvcpg: Process file: ".$filename);
	open(my $data,'<',$filename) || die("Cannot open file: ".$filename."\n");
	my $flag = 0;
	while ( my $ln = <$data> ) {
		chomp $ln;
		#print("__DBG__: [$flag]".$ln."\n");
		if ( $ln =~ /^\s*Name\s+CPG\s+Adm\s+/ ) { $flag = 1; next; }
		if ( $ln =~ /^[-]+\s*/ ) { $flag = 0; last; }
		if ( $flag && $ln =~ /^\s*([-\w\.]+)\s+([-\w\.]+)\s+([-\d\.\s]*)/ ) {
			my $vvid = $storids{'vvol'}->{$1};
			my $cpgname = $2;
			if ( $cpgname ne "---" ) {
				my $cpgid = $storids{'cpg'}->{$cpgname};
				#print("__DBG_3: VV ID: $vvid == CPG ID: $cpgid - Name: $cpgname\n");
				#print("__DBG_4: DATA VVOL $vvid Name: ",$stordata{'vvol'}->{$vvid}->{'name'});
				$stordata{'vvol'}->{$vvid}->{'cpgid'} = $cpgid;
				$stordata{'vvol'}->{$vvid}->{'cpgname'} = $cpgname;
			} else {
				$stordata{'vvol'}->{$vvid}->{'cpgid'} = "-";
				$stordata{'vvol'}->{$vvid}->{'cpgname'} = $cpgname;
			}
		}
	}
	close $data;
}

sub parse_showvv {
	my $filename = shift;
	my %ids;
	if ( not defined $stordata{'vvol'} ) {
		my %d; $stordata{'vvol'} = \%d;
	}
	&message("parse_showvv: Process file: ".$filename);
	open(my $data,'<',$filename) || die("Cannot open file: ".$filename."\n");
	my $flag = 0;
	while ( my $ln = <$data> ) {
		chomp $ln;
		#print("__DBG__: [$flag]".$ln."\n");
		if ( $ln =~ /^\s*Id\s+Name\s+Prov\s+/ ) { $flag = 1; next; }
		if ( $ln =~ /^[-]+\s*/ ) { $flag = 0; last; }
		if ( $flag && $ln =~ /^\s*(\d+)\s+([-\w\.]+)\s+(.*)\s*/ ) {
			#print("__DBG_2: VVol ID: ".$1." - Name: ".$2."\n");
			$ids{$2} = $1;
			$stordata{'vvol'}->{$1}->{'id'} = $1;
			$stordata{'vvol'}->{$1}->{'name'} = $2;
			my @a = split(/\s+/,$3);
			&vvol_conf($1,$2,\@a);
		}
	}
	close $data;
	$storids{'vvol'} = \%ids;
}

sub vvol_conf {
	my ($id,$name,$a) = @_;
	#print("__DBG_2: VVol ID: ".$id." - Name: ".$name." - ".$a->[6]."\n");
	# Prov Type  CopyOf         BsId Rd State  Adm_Rsvd_MB Snp_Rsvd_MB Usr_Rsvd_MB VSize_MB Detailed_State
	# 0    1     2              3    4  5      6           7           8           9        10
	#
	my $stat;
	if ( defined $stordata{'vvol'}->{$id} ) {
		$stat = $stordata{'vvol'}->{$id};
	} else {
		my %d; $stat = \%d; $stordata{'vvol'}->{$id} = $stat;
		$stordata{'vvol'}->{$id}->{'name'} = $name;
		$stordata{'vvol'}->{$id}->{'id'} = $id;
	}
	$stordata{'vvol'}->{$id}->{'prov'} = $a->[0];
	$stordata{'vvol'}->{$id}->{'type'} = $a->[1];
	$stordata{'vvol'}->{$id}->{'copyof'} = $a->[2];
	$stordata{'vvol'}->{$id}->{'bsid'} = $a->[3];
	$stordata{'vvol'}->{$id}->{'rd'} = $a->[4];
	$stordata{'vvol'}->{$id}->{'state'} = $a->[5];
	$stordata{'vvol'}->{$id}->{'adm_size'} = $a->[6];
	$stordata{'vvol'}->{$id}->{'snp_size'} = $a->[7];
	$stordata{'vvol'}->{$id}->{'usr_size'} = $a->[8];
	$stordata{'vvol'}->{$id}->{'virt_size'} = $a->[9];
	$stordata{'vvol'}->{$id}->{'detailed_state'} = $a->[10];
	if ( $a->[8] ne "--") {
		$stordata{'vvol'}->{$id}->{'real_size'} = $a->[6] + $a->[7] + $a->[8];
	} else {
		$stordata{'vvol'}->{$id}->{'real_size'} = 0;
	}
}

sub parse_statvv {
	my $filename = shift;
	if ( not defined $stordata{'vvol'} ) {
		my %d; $stordata{'vvol'} = \%d;
	}
	my $ids = $storids{'vvol'};
	&message("parse_statvv: Process file: ".$filename);
	open(my $data,'<',$filename) || die("Cannot open file: ".$filename."\n");
	my $flag = 0; my $time; my $date;
	while ( my $ln = <$data> ) {
		chomp $ln;
		#print("__DBG__: [$flag]".$ln."\n");
		# 00:26:09 01/09/2016 -> 2015-07-13 16:09:33
		if ( $ln =~ /^\s*(\d{2}:\d{2}:\d{2})\s+(\d{2})\/(\d{2})\/(\d{4}).*/ ) {
			 $flag = 1; $time = $4."-".$2."-".$3." ".$1;
			 next;
		}
		if ( $ln =~ /^[-]+\s*/ ) { $flag = 0; last; }
		if ( $flag && $ln =~ /^\s*([-\w\.]+)\s+([rwt]{1})\s+([-\d\.\s]*)/ ) {
			my $name = $1;
			my $rwflag = $2;
			my $id = $ids->{$name};
                        if( not defined $id ) {
                                &message("parse_statvv: Volume: ".$name." has not ID");
                                next;
                        }
			my %d;
			$d{name} = $name;
			$d{id} = $id;
			my @a = split(/\s+/,$3);
			&vvol_data($id,$name,$rwflag,$time,\@a);
		}
	}
	close $data;
}

sub vvol_data {
	my ($id,$name,$rwflag,$time,$a) = @_;
	#print("__DBG_2: VVol ID: ".$id." - Name: ".$name." - ".$rwflag." - ".$a->[6]."\n");
	#     I/O per second    KBytes per sec    Svt ms      IOSz KB     
	#     Cur  Avg  Max     Cur  Avg  Max     Cur  Avg    Cur  Avg    Qlen
	#     0    1    2       3    4    5       6    7      8    9      10
	#
	my $stat;
	if ( defined $stordata{'vvol'}->{$id} ) {
		$stat = $stordata{'vvol'}->{$id};
		$stordata{'vvol'}->{$id}->{'time'} = $time;
	} else {
		my %d; $stat = \%d; $stordata{'vvol'}->{$id} = $stat;
		$stordata{'vvol'}->{$id}->{'name'} = $name;
		$stordata{'vvol'}->{$id}->{'id'} = $id;
		$stordata{'vvol'}->{$id}->{'time'} = $time;
	}

	if ( $rwflag eq "r") {
		$stordata{'vvol'}->{$id}->{'rops'} = $a->[0];
		$stordata{'vvol'}->{$id}->{'rops-avg'} = $a->[1];
		$stordata{'vvol'}->{$id}->{'rops-max'} = $a->[2];
		$stordata{'vvol'}->{$id}->{'rdps'} = $a->[3];
		$stordata{'vvol'}->{$id}->{'rdps-avg'} = $a->[4];
		$stordata{'vvol'}->{$id}->{'rdps-max'} = $a->[5];
		$stordata{'vvol'}->{$id}->{'rlpo'} = $a->[6];
		$stordata{'vvol'}->{$id}->{'rlpo-avg'} = $a->[7];
		$stordata{'vvol'}->{$id}->{'rtpo'} = $a->[8];
		$stordata{'vvol'}->{$id}->{'rtpo-avg'} = $a->[9];
	} elsif ( $rwflag eq "w") {
		$stordata{'vvol'}->{$id}->{'wops'} = $a->[0];
		$stordata{'vvol'}->{$id}->{'wops-avg'} = $a->[1];
		$stordata{'vvol'}->{$id}->{'wops-max'} = $a->[2];
		$stordata{'vvol'}->{$id}->{'wdps'} = $a->[3];
		$stordata{'vvol'}->{$id}->{'wdps-avg'} = $a->[4];
		$stordata{'vvol'}->{$id}->{'wdps-max'} = $a->[5];
		$stordata{'vvol'}->{$id}->{'wlpo'} = $a->[6];
		$stordata{'vvol'}->{$id}->{'wlpo-avg'} = $a->[7];
		$stordata{'vvol'}->{$id}->{'wtpo'} = $a->[8];
		$stordata{'vvol'}->{$id}->{'wtpo-avg'} = $a->[9];
	} elsif ( $rwflag eq "t") {
		$stordata{'vvol'}->{$id}->{'tops'} = $a->[0];
		$stordata{'vvol'}->{$id}->{'tops-avg'} = $a->[1];
		$stordata{'vvol'}->{$id}->{'tops-max'} = $a->[2];
		$stordata{'vvol'}->{$id}->{'tdps'} = $a->[3];
		$stordata{'vvol'}->{$id}->{'tdps-avg'} = $a->[4];
		$stordata{'vvol'}->{$id}->{'tdps-max'} = $a->[5];
		$stordata{'vvol'}->{$id}->{'tlpo'} = $a->[6];
		$stordata{'vvol'}->{$id}->{'tlpo-avg'} = $a->[7];
		$stordata{'vvol'}->{$id}->{'ttpo'} = $a->[8];
		$stordata{'vvol'}->{$id}->{'ttpo-avg'} = $a->[9];
		$stordata{'vvol'}->{$id}->{'tq'} = $a->[10];
	}
	
}

sub print_conf_vvol {
	open(my $fh,'>>',$stordata{'out_conf_file'});
	#
    print $fh "\nVolume Level Configuration\n";
	print $fh "\tInterval Start:   ",$stordata{'server_time'},"\t(STOR2RRD Server time)\n";
	print $fh "\tInterval Length:  ",$stordata{'interval'}," seconds\n";
	print $fh "---------------------\n";
	#volume id:volume name:pool id/name:size:used/free
	print $fh "Volume ID,Volume name,CPG ID,CPG name,State,";
	print $fh "Provisioning,Type,Copy Of,Admin size [MB],Snap size [MB],User size [MB],Real size [MB],Virtual size [MB],\n";
	
	foreach my $id ( sort{$a <=> $b}(values(%{$storids{vvol}})) ) {
		#
		my $cpid;
		my $v = $stordata{'vvol'}->{$id};
		if ( $v->{'copyof'} ne "---" ) {
			$v->{'cpgid'} = "-";
			$v->{'cpgname'} = "---";
		}
		# Volume ID,Volume name,CPG ID,CPG name,Status,
		printf $fh ("%d,%s,%s,%s,%s,",$v->{'id'},$v->{'name'},$v->{'cpgid'},$v->{'cpgname'},$v->{'state'});
		# Provisioning,Type,Copy Of,Admin size,Snap size,User size,Real size,Virtual size
		printf $fh ("%s,%s,%s,%s,%s,%s,%d,%d,\n",$v->{'prov'},$v->{'type'},$v->{'copyof'},$v->{'adm_size'},$v->{'snp_size'},$v->{'usr_size'},$v->{'real_size'},$v->{'virt_size'});
	}
	close($fh);
}    

sub print_state_vvol {
	open(my $fh,'>>',$stordata{'out_state_file'});
	#
    print $fh "\nVolume Level State\n";
	print $fh "\tInterval Start:   ",$stordata{'server_time'},"\t(STOR2RRD Server time)\n";
	print $fh "\tInterval Length:  ",$stordata{'interval'}," seconds\n";
	print $fh "---------------------\n";
	#  
	print $fh "Volume ID,Volume name,State,Level,Detailed_State\n";
	foreach my $id ( sort{$a <=> $b}(values(%{$storids{'vvol'}})) ) {
		#
		my $v = $stordata{'vvol'}->{$id};
                if( not defined $v->{'id'} ) {
                        &message("print_conf_vvol: Volume ID: ".$id." has not state data");
                        next;
                }
		printf $fh ("%d,%s,%s,%s,%s,\n",$v->{'id'},$v->{'name'},$v->{'state'},$storstate{'vvol'}->{$v->{'state'}},$v->{'detailed_state'});
	}
	
	close($fh);
}    

sub print_perf_vvol {
	open(my $fh,'>>',$stordata{'out_perf_file'});
	#Volume Level Statistics
	#Interval Start:   2015-07-13 16:08:33
	#Interval End:     2015-07-13 16:09:33
	#Interval Length:  60 seconds
    #---------------------
    print $fh "\nVolume Level Statistics\n";
	print $fh "\tInterval Start:   ",$stordata{'server_time'},"\t(STOR2RRD Server time)\n";
	print $fh "\tInterval Length:  ",$stordata{'interval'}," seconds\n";
	print $fh "---------------------\n";
    
    #Volume ID,Time,Interval (s),Read IO Rate (IO/s),Write IO Rate (IO/s),Total IO Rate (IO/s),Read Data Rate (KB/s),Write Data Rate (KB/s),Total Data Rate (KB/s),Read Transfer Size (kB),Write Transfer Size (kB),Overall Transfer Size (kB),Read Response Time (ms),Write Response Time (ms),Overall Response Time (ms),Peak Read Response Time (ms),Peak Write Response Time (ms),Host Delay (assuming that all host delay is writes) (ms),Host Delay (assuming that host delay is evenly spread between read and writes) (ms),Read Hits,Write Hits,Data Read (KB),Data Written (KB),Volume (Vdisk) Name,Managed Disk Group ID,Managed Disk Group Name,IO Group ID,IO Group Name,Remote Copy relationship ID,Remote Copy relationship name,Remote Copy Change Volume relationship,FlashCopy map ID,FlashCopy map name,FlashCopy map count,Copy Count,Space Efficient Copy Count,Cache state,Easy Tier On/Off,Easy Tier Status,Preferred Node ID,Capacity (TB),Real Capacity (TB),Used Capacity (TB),Auto Expand,Grain Size,Throttle Unit,Throttle Rate,UDID (for HPUX),
    #0000,2015-07-13 16:09:33,60,0.000,0.000,0.000,0.000,0.000,0.000,0.000,0.000,0.000,0.000,0.000,0.000,0.000,0.000,0.000,0.000,0.000,0.000,0.000,0.000,tsmplinux_rvg,0,SAS450,0,io_grp0,,,no,,,0,1,0,empty,,,,53687091200.000,0,0,0,0,,0,,
		# Volume ID,Time,Interval (s),
	# Read IO Rate (IO/s),Write IO Rate (IO/s),Total IO Rate (IO/s),
	# Read Data Rate (KB/s),Write Data Rate (KB/s),Total Data Rate (KB/s),
	# Read Transfer Size (kB),Write Transfer Size (kB),Overall Transfer Size (kB),
	# Read Response Time (ms),Write Response Time (ms),Overall Response Time (ms),
	# Peak Read Response Time (ms),Peak Write Response Time (ms),
	# Host Delay (assuming that all host delay is writes) (ms),Host Delay (assuming that host delay is evenly spread between read and writes) (ms),
	# Read Hits,Write Hits,Data Read (KB),Data Written (KB),
	# Volume (Vdisk) Name,Managed Disk Group ID,Managed Disk Group Name,IO Group ID,IO Group Name,
	# Remote Copy relationship ID,Remote Copy relationship name,Remote Copy Change Volume relationship,
	# FlashCopy map ID,FlashCopy map name,FlashCopy map count,
	# Copy Count,Space Efficient Copy Count,Cache state,Easy Tier On/Off,Easy Tier Status,
	# Preferred Node ID,Capacity (TB),Real Capacity (TB),Used Capacity (TB),
	# Auto Expand,Grain Size,Throttle Unit,Throttle Rate,UDID (for HPUX),
	#
	printf $fh "Volume ID,Time,Interval (s),";
	printf $fh "Read IO Rate (IO/s),Write IO Rate (IO/s),Total IO Rate (IO/s),Read Data Rate (KB/s),Write Data Rate (KB/s),Total Data Rate (KB/s),";
	printf $fh "Read Transfer Size (kB),Write Transfer Size (kB),Overall Transfer Size (kB),Read Response Time (ms),Write Response Time (ms),Overall Response Time (ms),";
	printf $fh ",,,,";
	printf $fh ",,,,";
	printf $fh "Volume (Vdisk) Name,CPG ID,CPG Name,,,";
	printf $fh ",,,\n";
	#printf $fh ",,,,";
	#printf $fh ",,,,";
	#printf $fh "Capacity (TB),Real Capacity (TB),Used Capacity (TB),,,,,,\n";
	
	foreach my $id ( sort{$a <=> $b}(values(%{$storids{vvol}})) ) {
		#
		my $v = $stordata{'vvol'}->{$id};
                if( not defined $v->{'rops'} ) {
                        &message("print_perf_vvol: Volume ID: ".$id." has not perf data");
                        next;
                }
		if ( not defined $v->{time} ) { next; }
		#"Volume ID,Time,Interval (s),
		printf $fh ("%d,%s,%s,",$v->{'id'},$v->{time},$stordata{'interval'},);   
		#"Read IO Rate (IO/s),Write IO Rate (IO/s),Total IO Rate (IO/s),Read Data Rate (KB/s),Write Data Rate (KB/s),Total Data Rate (KB/s)"
		printf $fh ("%d,%d,%d,%d,%d,%d,",$v->{'rops'},$v->{'wops'},$v->{'tops'},$v->{'rdps'},$v->{'wdps'},$v->{'tdps'});
		#"Read Transfer Size (kB),Write Transfer Size (kB),Overall Transfer Size (kB),Read Response Time (ms),Write Response Time (ms),Overall Response Time (ms)"
		printf $fh ("%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,",$v->{'rtpo'},$v->{'wtpo'},$v->{'ttpo'},$v->{'rlpo'},$v->{'wlpo'},$v->{'tlpo'});
		#"Peak Read Response Time (ms),Peak Write Response Time (ms),Host Delay (assuming that all host delay is writes) (ms),Host Delay (assuming that host delay is evenly spread between read and writes) (ms)"
		printf $fh (",,,,");
		#"Read Hits,Write Hits,Data Read (KB),Data Written (KB)";
		printf $fh  (",,,,");
		#"Volume (Vdisk) Name,Managed Disk Group ID,Managed Disk Group Name,IO Group ID,IO Group Name";
		if ( defined $v->{'cpgid'} ) {
			printf $fh  ("%s,%s,%s,,,",$v->{'name'},$v->{'cpgid'},$v->{'cpgname'});
		} else {
			printf $fh  ("%s,,,,,",$v->{'name'});
		}
		#"Remote Copy relationship ID,Remote Copy relationship name,Remote Copy Change Volume relationship";
		printf $fh  (",,,\n");
		#"FlashCopy map ID,FlashCopy map name,FlashCopy map count,Copy Count";
		#printf $fh  (",,,,");
		#"Space Efficient Copy Count,Cache state,Easy Tier On/Off,Easy Tier Status,Preferred Node ID";
		#printf $fh  (",,,,,");
		#"Capacity (TB),Real Capacity (TB),Used Capacity (TB),Auto Expand,Grain Size,Throttle Unit,Throttle Rate,UDID (for HPUX),\n";
		#printf $fh  (",,,,,,,0,\n");
	}
	
	close($fh);
}

sub parse_statcpu {
	my $filename = shift;
	if ( not defined $stordata{'cpu'} ) {
		my %d; $stordata{'cpu'} = \%d;
	}
	my $ids = $storids{'cpu'};
	&message("parse_statcpu: Process file: ".$filename);
	open(my $data,'<',$filename) || die("Cannot open file: ".$filename."\n");
	my $time;
	while ( my $ln = <$data> ) {
		chomp $ln;
		#print("__DBG_1: ".$ln."\n");
		# 00:26:09 01/09/2016 -> 2015-07-13 16:09:33
		if ( $ln =~ /^\s*(\d{2}:\d{2}:\d{2})\s+(\d{2})\/(\d{2})\/(\d{4}).*/ ) {
			 $time = $4."-".$2."-".$3." ".$1;
			 next;
		}
		#   node,cpu user sys idle intr/s ctxt/s
		if ( $ln =~ /^\s*node,cpu\s+user\s+sys\s+.*/ ) { next; }
		#        0,7    0   0  100              
		#    0,total    0   1   99   1957   3685
		if ( $ln =~ /^\s*(\d+,\d+)\s+(\d+)\s+(\d+)\s+(\d+)/ ) {
			my $id = $1;
			my %d;
			$d{'id'} = $id;
			$d{'time'} = $time;
			$d{'user'} = $2;
			$d{'sys'} = $3;
			$d{'idle'} = $4;
			$stordata{'cpu'}->{$id} = \%d;
		}
		if ( $ln =~ /^\s*(\d+,total)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/ ) {
			my $id = $1;
			my %d;
			$d{'id'} = $id;
			$d{'time'} = $time;
			$d{'user'} = $2;
			$d{'sys'} = $3;
			$d{'idle'} = $4;
			$d{'intrps'} = $5;
			$d{'ctxtps'} = $6;
			$stordata{'cpu'}->{$id} = \%d;
		}
	}
	close $data;
}

sub print_perf_cpu {
	open(my $fh,'>>',$stordata{'out_perf_file'});

    print $fh "\nCPU-Node Level Statistics\n";
	print $fh "\tInterval Start:   ",$stordata{'server_time'},"\t(STOR2RRD Server time)\n";
	print $fh "\tInterval Length:  ",$stordata{'interval'}," seconds\n";
	print $fh "---------------------\n";
	# Node,Time,Interval,CPU Utilization - User,CPU Utilization - System,CPU Utilization - Idle,intr/s,ctxt/s,
	# node1_core00,2015-07-13 16:03:33,60,node1,0,1.597,0.000,
	print $fh "Node,Time,Interval (s),";
	print $fh "CPU Utilization - User,CPU Utilization - System,CPU Utilization - Idle,";
	print $fh "intr/s,ctxt/s,\n";
	#
	foreach my $id ( sort(keys(%{$stordata{'cpu'}})) ) {
		#
		my $v = $stordata{'cpu'}->{$id};
		my ($node,$cpu) = split(/,/,$v->{'id'});
		if ( $cpu ne "total" ) { next; }
		#"Node-CPU,Time,Interval (s),Node,CPU Core ID,
		printf $fh ("%d,%s,%s,",$node,$v->{time},$stordata{'interval'});
		# CPU Utilization - User,CPU Utilization - System,CPU Utilization - Idle,
		printf $fh ("%d,%d,%d,",$v->{'user'},$v->{'sys'},$v->{'idle'});
		# intr/s,ctxt/s,
		printf $fh ("%d,%d,\n",$v->{'intrps'},$v->{'ctxtps'});
	}


    print $fh "\nCPU-Core Level Statistics\n";
	print $fh "\tInterval Start:   ",$stordata{'server_time'},"\t(STOR2RRD Server time)\n";
	print $fh "\tInterval Length:  ",$stordata{'interval'}," seconds\n";
	print $fh "---------------------\n";
    
	# Node,CPU Core,Time,Interval,Node,CPU Core,CPU Utilization - User,CPU Utilization - System,CPU Utilization - Idle,
	# node1_core00,2015-07-13 16:03:33,60,node1,0,1.597,0.000,
	#
	print $fh "Node-CPU Core,Time,Interval (s),Node,CPU Core,";
	print $fh "CPU Utilization - User,CPU Utilization - System,CPU Utilization - Idle,\n";
	
	foreach my $id ( sort(keys(%{$stordata{'cpu'}})) ) {
		#
		my $v = $stordata{'cpu'}->{$id};
		my ($node,$cpu) = split(/,/,$v->{'id'});
		if ( $cpu eq "total" ) { next; }
		#"Node-CPU,Time,Interval (s),Node,CPU Core ID,
		printf $fh ("%d-%d,%s,%s,%d,%d,",$node,$cpu,$v->{time},$stordata{'interval'},$node,$cpu);
		# CPU Utilization - User,CPU Utilization - System,CPU Utilization - Idle,
		printf $fh ("%d,%d,%d,\n",$v->{'user'},$v->{'sys'},$v->{'idle'});
	}
	
	close($fh);
}

sub print_conf_cpg {
	open(my $fh,'>>',$stordata{'out_conf_file'});
	#
    print $fh "\nPool Level Configuration\n";
	print $fh "\tInterval Start:   ",$stordata{'server_time'},"\t(STOR2RRD Server time)\n";
	print $fh "\tInterval Length:  ",$stordata{'interval'}," seconds\n";
	print $fh "---------------------\n";
	#volume id:volume name:pool id/name:size:used/free
	print $fh "CPG ID,CPG name,";
	print $fh "User Total Capacity [MB],User Used Capacity [MB],";
	print $fh "Snapshot Total Capacity [MB],Snapshot Used Capacity [MB],";
	print $fh "Admin Total Capacity [MB],Admin Used Capacity [MB],\n";
	
	foreach my $id ( sort{$a <=> $b}(values(%{$storids{'cpg'}})) ) {
		#
		my $cpid;
		my $v = $stordata{'cpg'}->{$id};
		# CPG ID,CPG name,
		printf $fh ("%d,%s,",$v->{'id'},$v->{'name'});
		# User Total Capacity [MB],User Used Capacity [MB],
		printf $fh ("%d,%d,",$v->{'usr_tot_cap'},$v->{'usr_use_cap'});
		# Snapshot Total Capacity [MB],Snapshot Used Capacity [MB],
		printf $fh ("%d,%d,",$v->{'snp_tot_cap'},$v->{'snp_use_cap'});
		# Admin Total Capacity [MB],Admin Used Capacity [MB]
		printf $fh ("%d,%d,\n",$v->{'adm_tot_cap'},$v->{'adm_use_cap'});
	}
	close($fh);
}    

sub parse_showld {
	my $filename = shift;
	my %ids; $storids{'ld'} = \%ids;
	if ( not defined $stordata{'ld'} ) {
		my %d; $stordata{'ld'} = \%d;
	}
	&message("parse_showld: Process file: ".$filename);
	open(my $data,'<',$filename) || die("Cannot open file: ".$filename."\n");
	my $flagn = 0; my $flagd = 0; my $flags = 0;
	# Id Name                       RAID -Detailed_State- Own  SizeMB  UsedMB Use  Lgct LgId WThru MapV
	# 0 admin.usr.0                   1 normal           0/1    3072    3072 V       0  ---     N    Y
	#
	# Id Name                       CPG   RAID Own  SizeMB RSizeMB RowSz StepKB SetSz Refcnt Avail CAvail ------CreationTime------ ---CreationPattern----
	#  0 admin.usr.0                ---      1 0/1    3072    6144     3    256     2      0 mag   mag    2014-10-06 09:35:23 CEST --                    
	
	while ( my $ln = <$data> ) {
		chomp $ln;
		#print("__DBG__: [$flags]".$ln."\n");
		if ( $ln =~ /^\s*Id\s+Name\s+RAID\s+/ ) { $flagn = 1; next; }
		if ( $ln =~ /^\s*Id\s+Name\s+CPG\s+/ ) { $flagd = 1; next; }
		if ( $ln =~ /^\s*Id\s+Name\s+-State-\s+/ ) { $flags = 1; next; }
		if ( $ln =~ /^[-]+\s*/ ) { $flagn = 0; $flagd = 0; $flags = 0; next; }
		if ( $flagn && $ln =~ /^\s*(\d+)\s+([-\w\.]+)\s+(.*)\s*/ ) {
			$ids{$2} = $1;
			$stordata{'ld'}->{$1}->{'id'} = $1;
			$stordata{'ld'}->{$1}->{'name'} = $2;
			my @a = split(/\s+/,$3);
			&ld_conf($1,$2,\@a);
		}
		if ( $flagd && $ln =~ /^\s*(\d+)\s+([-\w\.]+)\s+(.*)\s*/ ) {
			$ids{$2} = $1;
			$stordata{'ld'}->{$1}->{'id'} = $1;
			$stordata{'ld'}->{$1}->{'name'} = $2;
			my @a = split(/\s+/,$3);
			&ld_conf_detail($1,$2,\@a);
		}
		if ( $flags && $ln =~ /^\s*(\d+)\s+([-\w\.]+)\s+([-\w\.]+)\s+([-\w\.]+)\s*/ ) {
			#print("__DBG_2: LD ID: ".$1." - Name: ".$2."\n");
			$ids{$2} = $1;
			$stordata{'ld'}->{$1}->{'id'} = $1;
			$stordata{'ld'}->{$1}->{'name'} = $2;
			$stordata{'ld'}->{$1}->{'state'} = $3;
			$stordata{'ld'}->{$1}->{'detailed_state'} = $4;
		}
	}
	close $data;
}

sub ld_conf {
	my ($id,$name,$a) = @_;
	#print("__DBG_2: VVol ID: ".$id." - Name: ".$name." - ".$a->[6]."\n");
	# RAID -Detailed_State- Own  SizeMB  UsedMB Use  Lgct LgId WThru MapV
	#    1 normal           0/1    3072    3072 V       0  ---     N    Y
	#    0                1   2       3       4   5     6    7     8    9
	#
	my $stat;
	if ( defined $stordata{'ld'}->{$id} ) {
		$stat = $stordata{'ld'}->{$id};
	} else {
		my %d; $stat = \%d; $stordata{'ld'}->{$id} = $stat;
		$stordata{'ld'}->{$id}->{'name'} = $name;
		$stordata{'ld'}->{$id}->{'id'} = $id;
	}
	$stordata{'ld'}->{$id}->{'raid'} = $a->[0];
	$stordata{'ld'}->{$id}->{'status'} = $a->[1];
	$stordata{'ld'}->{$id}->{'own'} = $a->[2];
	$stordata{'ld'}->{$id}->{'total_size'} = $a->[3];
	$stordata{'ld'}->{$id}->{'used_size'} = $a->[4];
	$stordata{'ld'}->{$id}->{'use'} = $a->[5];
	$stordata{'ld'}->{$id}->{'lgct'} = $a->[6];
	$stordata{'ld'}->{$id}->{'lgid'} = $a->[7];
	$stordata{'ld'}->{$id}->{'wthru'} = $a->[8];
	$stordata{'ld'}->{$id}->{'mapv'} = $a->[9];
}

sub ld_conf_detail {
	my ($id,$name,$a) = @_;
	#print("__DBG_2: VVol ID: ".$id." - Name: ".$name." - ".$a->[6]."\n");
	# CPG   RAID Own  SizeMB RSizeMB RowSz StepKB SetSz Refcnt Avail CAvail ------CreationTime------ ---CreationPattern----
	# ---      1 0/1    3072    6144     3    256     2      0 mag   mag    2014-10-06 09:35:23 CEST --                    
	#   0      1   2       3       4     5      6     7      8   9       10                       11                 12
	#
	my $stat;
	if ( defined $stordata{'ld'}->{$id} ) {
		$stat = $stordata{'ld'}->{$id};
	} else {
		my %d; $stat = \%d; $stordata{'ld'}->{$id} = $stat;
		$stordata{'ld'}->{$id}->{'name'} = $name;
		$stordata{'ld'}->{$id}->{'id'} = $id;
	}
	$stordata{'ld'}->{$id}->{'cpgname'} = $a->[0];
	$stordata{'ld'}->{$id}->{'raid'} = $a->[1];
	$stordata{'ld'}->{$id}->{'own'} = $a->[2];
	$stordata{'ld'}->{$id}->{'size'} = $a->[3];
	$stordata{'ld'}->{$id}->{'rsize'} = $a->[4];
	$stordata{'ld'}->{$id}->{'row_size'} = $a->[5];
	$stordata{'ld'}->{$id}->{'step'} = $a->[6];
	$stordata{'ld'}->{$id}->{'set_size'} = $a->[7];
	$stordata{'ld'}->{$id}->{'ref_cnt'} = $a->[8];
	$stordata{'ld'}->{$id}->{'avail'} = $a->[9];
	$stordata{'ld'}->{$id}->{'c_avail'} = $a->[10];
	$stordata{'ld'}->{$id}->{'cre_time'} = $a->[11];
	$stordata{'ld'}->{$id}->{'cre_patt'} = $a->[12];
}

sub print_conf_ld {
	open(my $fh,'>>',$stordata{'out_conf_file'});
	#
    print $fh "\nLogical Drive Level Configuration\n";
	print $fh "\tInterval Start:   ",$stordata{'server_time'},"\t(STOR2RRD Server time)\n";
	print $fh "\tInterval Length:  ",$stordata{'interval'}," seconds\n";
	print $fh "---------------------\n";
	#volume id:volume name:pool id/name:size:used/free
	print $fh "LD ID,LD name,CPG ID,CPG name,RAID,Status,";
	print $fh "Owner,Use,Total size [MB],Used size [MB],\n";
	
	foreach my $id ( sort{$a <=> $b}(values(%{$storids{'ld'}})) ) {
		#
		my $v = $stordata{'ld'}->{$id};
		my $cpgid;
		if ( $v->{'cpgname'} eq "---") {
			$cpgid = "-";
		} else {
			$cpgid = $storids{'cpg'}->{$v->{'cpgname'}};
		}
		my $use = $v->{'use'};
		$use =~ s/,/-/;
		# LD ID,LD name,CPG ID,CPG name,RAID,Status
		printf $fh ("%d,%s,%s,%s,",$v->{'id'},$v->{'name'},$cpgid,$v->{'cpgname'});
		# RAID,Status
		printf $fh ("%d,%s,",$v->{'raid'},$v->{'status'});
		# Owner,Use,Total size [MB],Used size [MB]
		printf $fh ("%s,%s,%d,%d,\n",$v->{'own'},$use,$v->{'total_size'},$v->{'used_size'});
	}
	close($fh);
}    

sub print_state_ld {
	open(my $fh,'>>',$stordata{'out_state_file'});
	#
    print $fh "\nLogical Drive Level State\n";
	print $fh "\tInterval Start:   ",$stordata{'server_time'},"\t(STOR2RRD Server time)\n";
	print $fh "\tInterval Length:  ",$stordata{'interval'}," seconds\n";
	print $fh "---------------------\n";
	# host_id,id,name,
	# port_count,iogrp_count,status,
	# IQN WWPN,Volume IDs,Volume Names
	#  
	print $fh "LD ID,LD name,State,Level,Detailed_State\n";
	foreach my $id ( sort{$a <=> $b}(values(%{$storids{'ld'}})) ) {
		#
		my $v = $stordata{'ld'}->{$id};
		printf $fh ("%d,%s,%s,%s,%s,\n",$v->{'id'},$v->{'name'},$v->{'state'},$storstate{'ld'}->{$v->{'state'}},$v->{'detailed_state'});
	}
	
	close($fh);
}    

sub parse_statld {
	my $filename = shift;
	if ( not defined $stordata{'ld'} ) {
		my %d; $stordata{'ld'} = \%d;
	}
	my $ids = $storids{'ld'};
	&message("parse_statld: Process file: ".$filename);
	open(my $data,'<',$filename) || die("Cannot open file: ".$filename."\n");
	#        00:12:13 01/19/2016 r/w I/O per second KBytes per sec      Svt ms   IOSz KB     
	#                    Ldname      Cur  Avg  Max  Cur  Avg  Max   Cur   Avg  Cur  Avg Qlen
	#               admin.usr.0   r    0    0    0    0    0    0  0.00  0.00  0.0  0.0    -
	#               admin.usr.0   w    1    1    1    3    3    3 14.33 14.33  5.2  5.2    -
	my $flag = 0; my $time; my $date;
	while ( my $ln = <$data> ) {
		chomp $ln;
		# 00:26:09 01/09/2016 -> 2015-07-13 16:09:33
		if ( $ln =~ /^\s*(\d{2}:\d{2}:\d{2})\s+(\d{2})\/(\d{2})\/(\d{4}).*/ ) {
			 $time = $4."-".$2."-".$3." ".$1;
			 next;
		}
		if ( $ln =~ /^\s*Ldname\s+Cur\s+Avg\s+Max/ ) { $flag = 1; next; }
		if ( $ln =~ /^[-]+\s*/ ) { $flag = 0; last; }
		if ( $flag && $ln =~ /^\s*([-\w\.]+)\s+([rwt]{1})\s+([-\d\.\s]*)/ ) {
			my $name = $1;
			my $rwflag = $2;
			my $id = $ids->{$name};
                        if( not defined $id ) {
                                &message("parse_statld: Volume: ".$name." has not ID");
                                next;
                        }
			my %d;
			$d{name} = $name;
			$d{id} = $id;
			my @a = split(/\s+/,$3);
			&ld_data($id,$name,$rwflag,$time,\@a);
		}
	}
	close $data;
}

sub ld_data {
	my ($id,$name,$rwflag,$time,$a) = @_;
	#print("__DBG_2: VVol ID: ".$id." - Name: ".$name." - ".$rwflag." - ".$a->[6]."\n");
	#     I/O per second    KBytes per sec    Svt ms      IOSz KB     
	#     Cur  Avg  Max     Cur  Avg  Max     Cur  Avg    Cur  Avg    Qlen
	#     0    1    2       3    4    5       6    7      8    9      10
	#
	my $stat;
	if ( defined $stordata{'ld'}->{$id} ) {
		$stat = $stordata{'ld'}->{$id};
		$stordata{'ld'}->{$id}->{'time'} = $time;
	} else {
		my %d; $stat = \%d; $stordata{'vvol'}->{$id} = $stat;
		$stordata{'ld'}->{$id}->{'name'} = $name;
		$stordata{'ld'}->{$id}->{'id'} = $id;
		$stordata{'ld'}->{$id}->{'time'} = $time;
	}

	if ( $rwflag eq "r") {
		$stordata{'ld'}->{$id}->{'rops'} = $a->[0];
		$stordata{'ld'}->{$id}->{'rops-avg'} = $a->[1];
		$stordata{'ld'}->{$id}->{'rops-max'} = $a->[2];
		$stordata{'ld'}->{$id}->{'rdps'} = $a->[3];
		$stordata{'ld'}->{$id}->{'rdps-avg'} = $a->[4];
		$stordata{'ld'}->{$id}->{'rdps-max'} = $a->[5];
		$stordata{'ld'}->{$id}->{'rlpo'} = $a->[6];
		$stordata{'ld'}->{$id}->{'rlpo-avg'} = $a->[7];
		$stordata{'ld'}->{$id}->{'rtpo'} = $a->[8];
		$stordata{'ld'}->{$id}->{'rtpo-avg'} = $a->[9];
	} elsif ( $rwflag eq "w") {
		$stordata{'ld'}->{$id}->{'wops'} = $a->[0];
		$stordata{'ld'}->{$id}->{'wops-avg'} = $a->[1];
		$stordata{'ld'}->{$id}->{'wops-max'} = $a->[2];
		$stordata{'ld'}->{$id}->{'wdps'} = $a->[3];
		$stordata{'ld'}->{$id}->{'wdps-avg'} = $a->[4];
		$stordata{'ld'}->{$id}->{'wdps-max'} = $a->[5];
		$stordata{'ld'}->{$id}->{'wlpo'} = $a->[6];
		$stordata{'ld'}->{$id}->{'wlpo-avg'} = $a->[7];
		$stordata{'ld'}->{$id}->{'wtpo'} = $a->[8];
		$stordata{'ld'}->{$id}->{'wtpo-avg'} = $a->[9];
	} elsif ( $rwflag eq "t") {
		$stordata{'ld'}->{$id}->{'tops'} = $a->[0];
		$stordata{'ld'}->{$id}->{'tops-avg'} = $a->[1];
		$stordata{'ld'}->{$id}->{'tops-max'} = $a->[2];
		$stordata{'ld'}->{$id}->{'tdps'} = $a->[3];
		$stordata{'ld'}->{$id}->{'tdps-avg'} = $a->[4];
		$stordata{'ld'}->{$id}->{'tdps-max'} = $a->[5];
		$stordata{'ld'}->{$id}->{'tlpo'} = $a->[6];
		$stordata{'ld'}->{$id}->{'tlpo-avg'} = $a->[7];
		$stordata{'ld'}->{$id}->{'ttpo'} = $a->[8];
		$stordata{'ld'}->{$id}->{'ttpo-avg'} = $a->[9];
		$stordata{'ld'}->{$id}->{'tq'} = $a->[10];
	}
}

sub print_perf_ld {
	open(my $fh,'>>',$stordata{'out_perf_file'});
	#Volume Level Statistics
	#Interval Start:   2015-07-13 16:08:33
	#Interval End:     2015-07-13 16:09:33
	#Interval Length:  60 seconds
    #---------------------
    print $fh "\nLogical Drive Level Statistics\n";
	print $fh "\tInterval Start:   ",$stordata{'server_time'},"\t(STOR2RRD Server time)\n";
	print $fh "\tInterval Length:  ",$stordata{'interval'}," seconds\n";
	print $fh "---------------------\n";
	#
	printf $fh "Logical Drive ID,Time,Interval (s),";
	printf $fh "Read IO Rate (IO/s),Write IO Rate (IO/s),Total IO Rate (IO/s),Read Data Rate (KB/s),Write Data Rate (KB/s),Total Data Rate (KB/s),";
	printf $fh "Read Transfer Size (kB),Write Transfer Size (kB),Overall Transfer Size (kB),Read Response Time (ms),Write Response Time (ms),Overall Response Time (ms),";
	printf $fh ",,,,";
	printf $fh ",,,,";
	printf $fh "Logical Drive Name,CPG ID,CPG Name,RAID,,";
	printf $fh ",,,\n";
	
	foreach my $id ( sort{$a <=> $b}(values(%{$storids{ld}})) ) {
		#
		my $v = $stordata{'ld'}->{$id};
                if( not defined $v->{'rops'} ) {
                        &message("print_perf_ld: Logical Drive ID: ".$id." has not perf data");
                        next;
                }
		my $cpgid;
		if ( $v->{'cpgname'} eq "---") {
			$cpgid = "-";
		} else {
			$cpgid = $storids{'cpg'}->{$v->{'cpgname'}};
		}
		#"Volume ID,Time,Interval (s),
		printf $fh ("%d,%s,%s,",$v->{'id'},$v->{time},$stordata{'interval'},);   
		#"Read IO Rate (IO/s),Write IO Rate (IO/s),Total IO Rate (IO/s),Read Data Rate (KB/s),Write Data Rate (KB/s),Total Data Rate (KB/s)"
		printf $fh ("%d,%d,%d,%d,%d,%d,",$v->{'rops'},$v->{'wops'},$v->{'tops'},$v->{'rdps'},$v->{'wdps'},$v->{'tdps'});
		#"Read Transfer Size (kB),Write Transfer Size (kB),Overall Transfer Size (kB),Read Response Time (ms),Write Response Time (ms),Overall Response Time (ms)"
		printf $fh ("%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,",$v->{'rtpo'},$v->{'wtpo'},$v->{'ttpo'},$v->{'rlpo'},$v->{'wlpo'},$v->{'tlpo'});
		#
		printf $fh (",,,,");
		#;
		printf $fh  (",,,,");
		# Logical Drive Name,CPG ID,CPG Name,RAID,,;
		printf $fh  ("%s,%s,%s,%d,,",$v->{'name'},$cpgid,$v->{'cpgname'},$v->{'raid'});
		#
		printf $fh  (",,,\n");
	}
	
	close($fh);
}

sub parse_showport {
	my $filename = shift;
	my %ids;
	if ( not defined $stordata{'port'} ) {
		my %d; $stordata{'port'} = \%d;
	}
	&message("parse_showport: Process file: ".$filename);
	open(my $data,'<',$filename) || die("Cannot open file: ".$filename."\n");
	# N:S:P      Mode     State ----Node_WWN---- -Port_WWN/HW_Addr-  Type Protocol Label Partner FailoverState
	# 0:0:1 initiator     ready 50002ACFF70046A8   50002AC0010046A8  disk      SAS  DP-1       -             -
	my $flag = 0;
	while ( my $ln = <$data> ) {
		chomp $ln;
		#print("__DBG__: [$flag]".$ln."\n");
		if ( $ln =~ /^\s*N:S:P\s+Mode\s+State\s+/ ) { $flag = 1; next; }
		if ( $ln =~ /^[-]+\s*/ ) { $flag = 0; last; }
		if ( $flag && $ln =~ /^\s*([:\d]+)\s+(.*)\s*/ ) {
			$ids{'P'.$1} = $1;
			$stordata{'port'}->{$1}->{'id'} = $1;
			my @a = split(/\s+/,$2);
			&port_conf($1,\@a);
		}
	}
	close $data;
	$storids{'port'} = \%ids;
}

sub port_conf {
	my ($id,$a) = @_;
	#print("__DBG_2: VVol ID: ".$id." - Name: ".$name." - ".$a->[6]."\n");
	#      Mode     State ----Node_WWN---- -Port_WWN/HW_Addr-  Type Protocol Label Partner FailoverState
	# initiator     ready 50002ACFF70046A8   50002AC0010046A8  disk      SAS  DP-1       -             -
	#         0         1                2                  3     4        5     6       7             8
	#
	my $stat;
	if ( defined $stordata{'port'}->{$id} ) {
		$stat = $stordata{'port'}->{$id};
	} else {
		my %d; $stat = \%d; $stordata{'port'}->{$id} = $stat;
		$stordata{'port'}->{$id}->{'id'} = $id;
	}
	$stordata{'port'}->{$id}->{'mode'} = $a->[0];
	$stordata{'port'}->{$id}->{'state'} = $a->[1];
	$stordata{'port'}->{$id}->{'wwnn'} = $a->[2];
	$stordata{'port'}->{$id}->{'wwpn'} = $a->[3];
	$stordata{'port'}->{$id}->{'type'} = $a->[4];
	$stordata{'port'}->{$id}->{'protocol'} = $a->[5];
	$stordata{'port'}->{$id}->{'label'} = $a->[6];
	$stordata{'port'}->{$id}->{'partner'} = $a->[7];
	$stordata{'port'}->{$id}->{'failoverstate'} = $a->[8];
}

sub print_conf_port {
	open(my $fh,'>>',$stordata{'out_conf_file'});
	#
    print $fh "\nPort Level Configuration\n";
	print $fh "\tInterval Start:   ",$stordata{'server_time'},"\t(STOR2RRD Server time)\n";
	print $fh "\tInterval Length:  ",$stordata{'interval'}," seconds\n";
	print $fh "---------------------\n";
	# N:S:P      Mode     State ----Node_WWN---- -Port_WWN/HW_Addr-  Type Protocol Label Partner FailoverState
	# 0:1:1    target     ready 2FFFFFFFFFFFFFFF   2FFFFFFFFFFFFFF8  host       FC     -   1:1:1          none
	print $fh "N:S:P,Mode,State,Node WWN,Port WWN,";
	print $fh "Type,Protocol,Label,Partner,Failover State,\n";
	
	foreach my $id ( sort(values(%{$storids{'port'}})) ) {
		#
		my $v = $stordata{'port'}->{$id};
		# N:S:P,Mode,State,Node WWN,PortWWN,
		printf $fh ("%s,%s,%s,%s,%s,",$v->{'id'},$v->{'mode'},$v->{'state'},$v->{'wwnn'},$v->{'wwpn'});
		# Type,Protocol,Label,Partner,Failover State
		printf $fh ("%s,%s,%s,%s,%s,\n",$v->{'type'},$v->{'protocol'},$v->{'label'},$v->{'partner'},$v->{'failoverstate'});
	}
	close($fh);
}    

sub print_state_port {
	open(my $fh,'>>',$stordata{'out_state_file'});
	#
    print $fh "\nPort Level State\n";
	print $fh "\tInterval Start:   ",$stordata{'server_time'},"\t(STOR2RRD Server time)\n";
	print $fh "\tInterval Length:  ",$stordata{'interval'}," seconds\n";
	print $fh "---------------------\n";
	#  
	print $fh "N:S:P,Type,State,Level,\n";
	foreach my $id ( sort(values(%{$storids{'port'}})) ) {
		#
		my $v = $stordata{'port'}->{$id};
		printf $fh ("%s,%s,%s,%s,\n",$v->{'id'},$v->{'type'},$v->{'state'},$storstate{'port'}->{$v->{'state'}});
	}
	
	close($fh);
}    

sub port_data {
	my ($id,$rwflag,$time,$a) = @_;
	#print("__DBG_2: VVol ID: ".$id." - Name: ".$name." - ".$rwflag." - ".$a->[6]."\n");
	#  I/O per second KBytes per sec      Svt ms   IOSz KB     
	#  Cur  Avg  Max  Cur  Avg  Max   Cur   Avg  Cur  Avg Qlen
	#    7    7    7  153  153  153  4.21  4.21 20.7 20.7    -
	#    0    1    2    3    4    5     6     7    8    9    10
	#
	my $stat;
	if ( defined $stordata{'port'}->{$id} ) {
		$stat = $stordata{'port'}->{$id};
		$stordata{'port'}->{$id}->{'time'} = $time;
	} else {
		my %d; $stat = \%d; $stordata{'vvol'}->{$id} = $stat;
		$stordata{'port'}->{$id}->{'id'} = $id;
		$stordata{'port'}->{$id}->{'time'} = $time;
	}
	if ( $rwflag eq "r") {
		$stordata{'port'}->{$id}->{'rops'} = $a->[0];
		$stordata{'port'}->{$id}->{'rops-avg'} = $a->[1];
		$stordata{'port'}->{$id}->{'rops-max'} = $a->[2];
		$stordata{'port'}->{$id}->{'rdps'} = $a->[3];
		$stordata{'port'}->{$id}->{'rdps-avg'} = $a->[4];
		$stordata{'port'}->{$id}->{'rdps-max'} = $a->[5];
		$stordata{'port'}->{$id}->{'rlpo'} = $a->[6];
		$stordata{'port'}->{$id}->{'rlpo-avg'} = $a->[7];
		$stordata{'port'}->{$id}->{'rtpo'} = $a->[8];
		$stordata{'port'}->{$id}->{'rtpo-avg'} = $a->[9];
	} elsif ( $rwflag eq "w") {
		$stordata{'port'}->{$id}->{'wops'} = $a->[0];
		$stordata{'port'}->{$id}->{'wops-avg'} = $a->[1];
		$stordata{'port'}->{$id}->{'wops-max'} = $a->[2];
		$stordata{'port'}->{$id}->{'wdps'} = $a->[3];
		$stordata{'port'}->{$id}->{'wdps-avg'} = $a->[4];
		$stordata{'port'}->{$id}->{'wdps-max'} = $a->[5];
		$stordata{'port'}->{$id}->{'wlpo'} = $a->[6];
		$stordata{'port'}->{$id}->{'wlpo-avg'} = $a->[7];
		$stordata{'port'}->{$id}->{'wtpo'} = $a->[8];
		$stordata{'port'}->{$id}->{'wtpo-avg'} = $a->[9];
	} elsif ( $rwflag eq "t") {
		$stordata{'port'}->{$id}->{'tops'} = $a->[0];
		$stordata{'port'}->{$id}->{'tops-avg'} = $a->[1];
		$stordata{'port'}->{$id}->{'tops-max'} = $a->[2];
		$stordata{'port'}->{$id}->{'tdps'} = $a->[3];
		$stordata{'port'}->{$id}->{'tdps-avg'} = $a->[4];
		$stordata{'port'}->{$id}->{'tdps-max'} = $a->[5];
		$stordata{'port'}->{$id}->{'tlpo'} = $a->[6];
		$stordata{'port'}->{$id}->{'tlpo-avg'} = $a->[7];
		$stordata{'port'}->{$id}->{'ttpo'} = $a->[8];
		$stordata{'port'}->{$id}->{'ttpo-avg'} = $a->[9];
		$stordata{'port'}->{$id}->{'tq'} = $a->[10];
	}
	
}

sub print_perf_port {
	open(my $fh,'>>',$stordata{'out_perf_file'});
	#Volume Level Statistics
	#Interval Start:   2015-07-13 16:08:33
	#Interval End:     2015-07-13 16:09:33
	#Interval Length:  60 seconds
    #---------------------
    print $fh "\nPort Level Statistics\n";
	print $fh "\tInterval Start:   ",$stordata{'server_time'},"\t(STOR2RRD Server time)\n";
	print $fh "\tInterval Length:  ",$stordata{'interval'}," seconds\n";
	print $fh "---------------------\n";
	#
	printf $fh "N:S:P,Time,Interval (s),";
	printf $fh "Read IO Rate (IO/s),Write IO Rate (IO/s),Total IO Rate (IO/s),Read Data Rate (KB/s),Write Data Rate (KB/s),Total Data Rate (KB/s),";
	printf $fh "Read Transfer Size (kB),Write Transfer Size (kB),Overall Transfer Size (kB),Read Response Time (ms),Write Response Time (ms),Overall Response Time (ms),";
	printf $fh ",,,,";
	printf $fh ",,,,";
	printf $fh "Type,Protocol,Label,,";
	printf $fh ",,,\n";
	
	foreach my $id ( sort(values(%{$storids{'port'}})) ) {
		#
		my $v = $stordata{'port'}->{$id};
                if( not defined $v->{'rops'} ) {
                        &message("print_perf_port: Port ID: ".$id." has not perf data");
                        next;
                }
		if ( not defined $v->{time} ) { next; }
		#"Volume ID,Time,Interval (s),
		printf $fh ("%s,%s,%s,",$v->{'id'},$v->{time},$stordata{'interval'},);   
		#"Read IO Rate (IO/s),Write IO Rate (IO/s),Total IO Rate (IO/s),Read Data Rate (KB/s),Write Data Rate (KB/s),Total Data Rate (KB/s)"
		printf $fh ("%d,%d,%d,%d,%d,%d,",$v->{'rops'},$v->{'wops'},$v->{'tops'},$v->{'rdps'},$v->{'wdps'},$v->{'tdps'});
		#"Read Transfer Size (kB),Write Transfer Size (kB),Overall Transfer Size (kB),Read Response Time (ms),Write Response Time (ms),Overall Response Time (ms)"
		printf $fh ("%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,",$v->{'rtpo'},$v->{'wtpo'},$v->{'ttpo'},$v->{'rlpo'},$v->{'wlpo'},$v->{'tlpo'});
		#
		printf $fh (",,,,");
		#;
		printf $fh  (",,,,");
		# Logical Drive Name,CPG ID,CPG Name,RAID,,;
		printf $fh  ("%s,%s,%s,,,",$v->{'type'},$v->{'protocol'},$v->{'label'});
		#
		printf $fh  (",,,\n");
	}
	
	close($fh);
}

sub parse_statport {
	my $filename = shift;
	if ( not defined $stordata{'port'} ) {
		my %d; $stordata{'port'} = \%d;
	}
	my $ids = $storids{'port'};
	&message("parse_statport: Process file: ".$filename);
	open(my $data,'<',$filename) || die("Cannot open file: ".$filename."\n");
	# 23:36:14 01/18/2016 r/w I/O per second KBytes per sec      Svt ms   IOSz KB     
	#      Port       D/C      Cur  Avg  Max  Cur  Avg  Max   Cur   Avg  Cur  Avg Qlen
    #     0:0:1      Data   r    7    7    7  153  153  153  4.21  4.21 20.7 20.7    -
	my $flag = 0; my $time;
	while ( my $ln = <$data> ) {
		chomp $ln;
		#print("__DBG__: [$flag]".$ln."\n");
		# 00:26:09 01/09/2016 -> 2015-07-13 16:09:33
		if ( $ln =~ /^\s*(\d{2}:\d{2}:\d{2})\s+(\d{2})\/(\d{2})\/(\d{4}).*/ ) {
			 $time = $4."-".$2."-".$3." ".$1;
			 next;
		}
		if ( $ln =~ /^\s*Port\s+D\/C\s+Cur/ ) { $flag = 1; next; }
		if ( $ln =~ /^[-]+\s*/ ) { $flag = 0; last; }
		if ( $flag && $ln =~ /^\s*([:\d]+)\s+\w+\s+([rwt]{1})\s+(.*)/ ) {
			my $id = $1;
			my $rwflag = $2;
			my %d;
			$d{id} = $id;
			my @a = split(/\s+/,$3);
			&port_data($id,$rwflag,$time,\@a);
		}
	}
	close $data;
}

sub parse_showvlun {
	my $filename = shift;
	if ( not defined $stordata{'vvol'} ) {
		my %d; $stordata{'vvol'} = \%d;
	}
	&message("parse_showvlun: Process file: ".$filename);
	open(my $data,'<',$filename) || die("Cannot open file: ".$filename."\n");
	# Active VLUNs
	# Lun VVName         HostName -Host_WWN/iSCSI_Name-  Port Type Status  ID
	#   1 HPUX-VM1       BL860i2  5001438018737A34      0:1:1 host active   1
	my $flag = 0;
	while ( my $ln = <$data> ) {
		chomp $ln;
		#print("__DBG__: [$flag]".$ln."\n");
		if ( $ln =~ /^\s*Lun\s+VVName\s+HostName\s+/ ) { $flag = 1; next; }
		if ( $ln =~ /^[-]+\s*/ ) { $flag = 0; last; }
		if ( $flag && $ln =~ /^\s*(\d+)\s+([-\w\.]+)\s+([-\w\.]+)\s+(.*)\s*/ ) {
			#print("__DBG_7: VVname: ".$2." - HostName: ".$3."\n");
			my $hostid;
			if ( defined $storids{'host'}->{$3} ) {
				$hostid = $storids{'host'}->{$3};
			} else {
				warning("vlun: Host ID is not defined for Host name ".$3);
				next;
			}
			&vlun_conf($hostid,$3,$2);
		}
	}
	close $data;
}

sub vlun_conf {
	my ($id,$host,$vvol) = @_;
	#print("__DBG_8:  Host ID: ".$id." - Host Name: ".$host." - VVol Name: ".$vvol."\n");
	#
	my $stat;
	if ( defined $stordata{'host'}->{$id} ) {
		$stat = $stordata{'host'}->{$id};
	} else {
		my %d; $stat = \%d; $stordata{'host'}->{$id} = $stat;
		$stordata{'host'}->{$id}->{'name'} = $host;
		$stordata{'host'}->{$id}->{'id'} = $id;
	}
	# VVol IDs
	my $vvid = $storids{'vvol'}->{$vvol};
	if ( defined $stordata{'host'}->{$id}->{'vvol_ids'} ) {
		my @d = split(/ /,$stordata{'host'}->{$id}->{'vvol_ids'});
		my $flag = 1;
		for my $ent ( @d ) {
			if ( $ent eq $vvid ) { $flag = 0; last; }
		}
		if ( $flag ) {
			push(@d,$vvid);
			$stordata{'host'}->{$id}->{'vvol_ids'} = join(" ",@d);
		}
	} else {
		$stordata{'host'}->{$id}->{'vvol_ids'} = $vvid;
	}
	# VVol Names
	if ( defined $stordata{'host'}->{$id}->{'vvol_names'} ) {
		my @d = split(/ /,$stordata{'host'}->{$id}->{'vvol_names'});
		my $flag = 1;
		for my $ent ( @d ) {
			if ( $ent eq $vvol ) { $flag = 0; last; }
		}
		if ( $flag ) {
			push(@d,$vvol);
			$stordata{'host'}->{$id}->{'vvol_names'} = join(" ",@d);
		}
	} else {
		$stordata{'host'}->{$id}->{'vvol_names'} = $vvol;
	}
}

sub parse_showhost {
	my $filename = shift;
	my %ids; $storids{'host'} = \%ids;
	if ( not defined $stordata{'host'} ) {
		my %d; $stordata{'host'} = \%d;
	}
	&message("parse_showhost: Process file: ".$filename);
	open(my $data,'<',$filename) || die("Cannot open file: ".$filename."\n");
	my $flag = 0;
	while ( my $ln = <$data> ) {
		chomp $ln;
		if ( $ln =~ /^\s*Id\s+Name\s+Persona\s+/ ) { $flag = 1; next; }
		if ( $flag && $ln =~ /^\s*(\d+)\s+([-\w\.]+)\s+(.*)\s*/ ) {
			$ids{$2} = $1;
			$stordata{'host'}->{$1}->{'id'} = $1;
			$stordata{'host'}->{$1}->{'name'} = $2;
			my @a = split(/\s+/,$3);
			&host_conf($1,$2,\@a);
		}
	}
	close $data;
}

sub host_conf {
	my ($id,$name,$a) = @_;
   	# Persona       ---------WWN/iSCSI_Name--------- Port  IP_addr
	# 0             1                                2     3    
	#
	my $stat;
	if ( defined $stordata{'host'}->{$id} ) {
		$stat = $stordata{'host'}->{$id};
	} else {
		my %d; $stat = \%d; $stordata{'host'}->{$id} = $stat;
		$stordata{'host'}->{$id}->{'name'} = $name;
		$stordata{'host'}->{$id}->{'id'} = $id;
	}
	$stordata{'host'}->{$id}->{'persona'} = $a->[0];
	# WWN/iSCSI
	if ( defined $stordata{'host'}->{$id}->{'wwn_iscsi'} ) {
		my @d = split(/ /,$stordata{'host'}->{$id}->{'wwn_iscsi'});
		my $flag = 1;
		for my $ent ( @d ) {
			if ( $ent eq $a->[1]) { $flag = 0; last; }
		}
		if ( $flag ) {
			push(@d,$a->[1]);
			$stordata{'host'}->{$id}->{'wwn_iscsi'} = join(" ",@d);
		}
	} else {
		$stordata{'host'}->{$id}->{'wwn_iscsi'} = $a->[1];
	}
	# Port
	if ( defined $stordata{'host'}->{$id}->{'port'} ) {
		my @d = split(/ /,$stordata{'host'}->{$id}->{'port'});
		my $flag = 1;
		for my $ent ( @d ) {
			if ( $ent eq $a->[2]) { $flag = 0; last; }
		}
		if ( $flag ) {
			push(@d,$a->[2]);
			$stordata{'host'}->{$id}->{'port'} = join(" ",@d);
		}
	} else {
		$stordata{'host'}->{$id}->{'port'} = $a->[2];
	}
	$stordata{'host'}->{$id}->{'ip_addr'} = $a->[3];
}

sub print_conf_host {
	open(my $fh,'>>',$stordata{'out_conf_file'});
	#
    print $fh "\nHost Level Configuration\n";
	print $fh "\tInterval Start:   ",$stordata{'server_time'},"\t(STOR2RRD Server time)\n";
	print $fh "\tInterval Length:  ",$stordata{'interval'}," seconds\n";
	print $fh "---------------------\n";
	# host_id,id,name,
	# port_count,iogrp_count,status,
	# IQN WWPN,Volume IDs,Volume Names
	#  
	print $fh "host_id,id,name,";
	print $fh "port_count,,status,";
	print $fh "IQN WWPN,Volume IDs,Volume Names,\n";
	
	foreach my $id ( sort{$a <=> $b}(values(%{$storids{'host'}})) ) {
		#
		my $cpid;
		my $v = $stordata{'host'}->{$id};
		my @port = split(/ /,$v->{'port'});
		# host_id,id,name,
		printf $fh ("%06d,%d,%s,",$v->{'id'},$v->{'id'},$v->{'name'});
		# port_count,,status,
		printf $fh ("%s,,,",scalar(@port));
		# IQN WWPN,Volume IDs,Volume Names,
		if ( defined $v->{'vvol_names'} ) {
			printf $fh ("%s,%s,%s,\n",$v->{'wwn_iscsi'},$v->{'vvol_ids'},$v->{'vvol_names'});
		} else {
			printf $fh ("%s,,,\n",$v->{'wwn_iscsi'});
		}
		
	}
	close($fh);
}    

sub parse_showpd {
	my $filename = shift;
	if ( not defined $stordata{'pd'} ) {
		my %d; $stordata{'pd'} = \%d;
	}
	&message("parse_showpd: Process file: ".$filename);
	open(my $data,'<',$filename) || die("Cannot open file: ".$filename."\n");
	my $flag = 0;
	while ( my $ln = <$data> ) {
		chomp $ln;
		#print("__DBG__: [$flag]".$ln."\n");
		if ( $ln =~ /^\s*Id\s+CagePos\s+Type\s+/ ) { $flag = 1; next; }
		if ( $ln =~ /^[-]+\s*/ ) { $flag = 0; last; }
		if ( $flag && $ln =~ /^\s*(\d+)\s+(.*)\s*/ ) {
			#print("__DBG_2: VVol ID: ".$1." - ".$2."\n");
			$stordata{'pd'}->{$1}->{'id'} = $1;
			my @a = split(/\s+/,$2);
			&pd_conf($1,\@a);
		}
	}
	close $data;
}

sub pd_conf {
	my ($id,$a) = @_;
	#print("__DBG_2: VVol ID: ".$id." - Name: ".$name." - ".$a->[6]."\n");
	#                         ----Size(MB)----- ----Ports----
	# CagePos Type RPM State     Total     Free A      B      Capacity(GB)
	# 0:0:0   FC    15 normal   278528   106496 1:0:1* 0:0:1           300
	#
	my $stat;
	if ( defined $stordata{'pd'}->{$id} ) {
		$stat = $stordata{'pd'}->{$id};
	} else {
		my %d; $stat = \%d; $stordata{'pd'}->{$id} = $stat;
		$stordata{'pd'}->{$id}->{'id'} = $id;
	}
	$stordata{'pd'}->{$id}->{'cage_pos'} = $a->[0];
	$stordata{'pd'}->{$id}->{'type'} = $a->[1];
	$stordata{'pd'}->{$id}->{'rpm'} = $a->[2];
	$stordata{'pd'}->{$id}->{'state'} = $a->[3];
	$stordata{'pd'}->{$id}->{'total_size_mb'} = $a->[4];
	$stordata{'pd'}->{$id}->{'free_size_mb'} = $a->[5];
	$stordata{'pd'}->{$id}->{'port_A'} = $a->[6];
	$stordata{'pd'}->{$id}->{'port_B'} = $a->[7];
	$stordata{'pd'}->{$id}->{'capacity_GB'} = $a->[8];
}

sub print_conf_pd {
	open(my $fh,'>>',$stordata{'out_conf_file'});
	#
    print $fh "\nPhysical Disk Configuration\n";
	print $fh "\tInterval Start:   ",$stordata{'server_time'},"\t(STOR2RRD Server time)\n";
	print $fh "\tInterval Length:  ",$stordata{'interval'}," seconds\n";
	print $fh "---------------------\n";
	#volume id:volume name:pool id/name:size:used/free
	print $fh "Physical Disk ID,Cage Position,Type,RPM,State,";
	print $fh "Total Size [MB],Free Size [MB],Port A,Port B,Capacity [GB],\n";
	
	foreach my $id ( sort{$a <=> $b}(keys(%{$stordata{'pd'}})) ) {
		#
		my $v = $stordata{'pd'}->{$id};
		# Physical Disk ID,Cage Position,Type,RPM,State,
		printf $fh ("%d,%s,%s,%s,%s,",$v->{'id'},$v->{'cage_pos'},$v->{'type'},$v->{'rpm'},$v->{'state'});
		# Total Size [MB],Free Size [MB],Port A,Port B,Capacity [GB],
		printf $fh ("%d,%d,%s,%s,%d,\n",$v->{'total_size_mb'},$v->{'free_size_mb'},$v->{'port_A'},$v->{'port_B'},$v->{'capacity_GB'});
	}
	close($fh);
}    

sub print_state_pd {
	open(my $fh,'>>',$stordata{'out_state_file'});
	#
    print $fh "\nPhysical Disk State\n";
	print $fh "\tInterval Start:   ",$stordata{'server_time'},"\t(STOR2RRD Server time)\n";
	print $fh "\tInterval Length:  ",$stordata{'interval'}," seconds\n";
	print $fh "---------------------\n";
	#  
	print $fh "Physical Disk ID,Cage Position,State,Level\n";
	foreach my $id ( sort{$a <=> $b}(keys(%{$stordata{'pd'}})) ) {
		#
		my $v = $stordata{'pd'}->{$id};
		printf $fh ("%d,%s,%s,%s,\n",$v->{'id'},$v->{'cage_pos'},$v->{'state'},$storstate{'pd'}->{$v->{'state'}});
	}
	
	close($fh);
}    

### health status ###

sub set_global_health_status_summary{
  my ($storname,$inputdir,$health_status_html,$time_str) = @_;
  my $file_state = $stordata{'out_state_file'};
  # Global health check
  my $act_timestamp  = time();
  #my $act_time = localtime();
  my $main_state     = "OK";
  my $state_suffix   = "ok";
  my $component_name = $storname;
  #$component_name =~ s/\s+//g;
  my $storage_status = set_health_status_html($storname,$health_status_html,$file_state);

  if ( $storage_status !~ "optimal" ) { $main_state = "NOT_OK"; $state_suffix = "nok"; }
  if (! -d "$inputdir/tmp/health_status_summary" ) {
    mkdir("$inputdir/tmp/health_status_summary", 0755) || error( "$time_str: Cannot mkdir $inputdir/tmp/health_status_summary: $!" . __FILE__ . ":" . __LINE__ ) && return 0;
  }
  if ( -f "$inputdir/tmp/health_status_summary/$component_name.ok" )  { unlink ("$inputdir/tmp/health_status_summary/$component_name.ok"); }
  if ( -f "$inputdir/tmp/health_status_summary/$component_name.nok" ) { unlink ("$inputdir/tmp/health_status_summary/$component_name.nok"); }

  open( MAST, ">$inputdir/tmp/health_status_summary/$component_name.$state_suffix" ) || error( "Couldn't open file $inputdir/tmp/health_status_summary/$component_name.$state_suffix $!" . __FILE__ . ":" . __LINE__ ) && return 0;
  print MAST "STORAGE : $component_name : $main_state : $act_timestamp\n";
  close(MAST);
  unlink ($file_state);
}

sub set_health_status_html{
  my $STORAGE_NAME = shift;
  my $health_status_html = shift;
  my $file_state = shift;
  my $time = localtime();
  my $status;
  my $report = "Storage $STORAGE_NAME health status = optimal\n";
  open( FH, "< $file_state" ) || error( "Cannot read $file_state: $!" . __FILE__ . ":" . __LINE__ ) && return 0;
  my @hw_all = <FH>;
  close(FH);
  if (check_health_status(\@hw_all) == 0){
    $status = "optimal";
    open(DATA, ">$health_status_html") or error ("Cannot open file: $health_status_html : $!") && return 0;
    print DATA "<!DOCTYPE html>\n";
    print DATA "<html>\n";
    print DATA "<body>\n";
    print DATA "<pre>$time\n";
    print DATA "$report\n";
    foreach my $line (@hw_all){
      chomp $line;
      print DATA "$line\n";
    }
    print DATA "</pre>\n";
    print DATA "</body>\n";
    print DATA "</html>\n";
    close DATA;
  }
  else{
    $status = "error";
    $report = "Storage $STORAGE_NAME health status = Error\n";
    open(DATA, ">$health_status_html") or error ("Cannot open file: $health_status_html : $!") && return 0;
    print DATA "<!DOCTYPE html>\n";
    print DATA "<html>\n";
    print DATA "<body>\n";
    print DATA "<pre>$time\n";
    print DATA "$report\n\n";
    foreach my $line (@hw_all){
      chomp $line;
      print DATA "$line\n";
    }
    #print DATA "@hw_all\n";
    print DATA "</pre>\n";
    print DATA "</body>\n";
    print DATA "</html>\n";
    close DATA;
  }
  return $status;
}


sub check_health_status{
  my ($hw_all) = @_;
  my @data = @{$hw_all};
  my $active = 0;
  my $index;

  foreach my $line (@data){
    chomp $line;
    if ($line eq ""){
      $index = "";
      $active = 0;
      next;
    }
    $line =~ s/^\s+|\s+$//g;
    if ($line =~ /----/){
      $index = "";
      $active = 1;
      next;
    }
    if ($active == 1){
      my @header = split(",",$line);
      my $i = -1;
      foreach my $element (@header){
        $i++;
        chomp $element;
        if ($element eq ""){next;}
        $element =~ s/^\s+|\s+$//g;
        if ($element eq "Level"){
          $index = $i;
          last;
        }
      }
      if ($index ne "" && defined $index){
        $active = 2;
        next;
      }
    }
    if ($active == 2){
      my @status = split(",",$line);
      chomp $status[$index];
      $status[$index] =~ s/^\s+|\s+$//g;
      my $upper_status = uc($status[$index]);
      if ($upper_status eq "CRITICAL"){
        return 1;
      }
    }
  }

  return 0;

}

sub error_die{
  my $message = shift;
  print STDERR "$message\n";
  exit (1);

}


sub message {
	my $msg = shift;
	my $tm = localtime();
	print($tm." INFO    :"." HP3PAR: ".$msg."\n") if ( $debug );
}

sub warning {
	my ($msg,$rc) = @_;
	my $tm = localtime();
	print STDERR ($tm." WARNING :"." HP3PAR: ".$msg."\n");
}

sub error {
	my ($msg,$rc) = @_;
	my $tm = localtime();
	if( defined $rc ) {
		print STDERR ($tm." ERROR   :"." HP3PAR: ".$msg." - return code: ".$rc."\n");
	} else {
		print STDERR ($tm." ERROR   :"." HP3PAR: ".$msg."\n");
	}
		
}


1;
