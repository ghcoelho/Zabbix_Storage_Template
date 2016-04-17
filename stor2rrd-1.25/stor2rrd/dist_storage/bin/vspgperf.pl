#!/usr/bin/perl
use warnings;
use strict;
use Data::Dumper;
use Date::Parse;
no warnings 'portable';

my %performance_data;

#my $STORAGE_NAME = "G200";
#my $BASEDIR = "/home/luzajic/STOR/VSP";
#my $bindir = $ENV{BINDIR};
#my $webdir =;
#my $health_status_html =  "$webdir/$STORAGE_NAME/health_status.html";
#my $inputdir = $ENV{INPUTDIR};
#my $wrkdir = "$BASEDIR/data/$STORAGE_NAME";
#my $configuration = "$wrkdir/IOSTATS";
#my $config_directory = "";
#my $command_file = "$wrkdir/$STORAGE_NAME-commnad.txt";
#my $ip_adress = "128.69.77.22";
#my $serial_number = "523589";
#my $login = "lukas";
#my $paswd = "zajda007";
#my $cli_dir = "";



my $STORAGE_NAME = $ENV{STORAGE_NAME};
my $BASEDIR = $ENV{INPUTDIR};
my $bindir = $ENV{BINDIR};
my $webdir = $ENV{WEBDIR};
my $health_status_html =  "$webdir/$STORAGE_NAME/health_status.html";
my $inputdir = $ENV{INPUTDIR};
my $wrkdir = "$BASEDIR/data/$STORAGE_NAME";
my $configuration = "$wrkdir/IOSTATS";
my $config_directory = "";
my $command_file = "$wrkdir/$STORAGE_NAME-commnad.txt";
my $serial_number = $ENV{VSPG_DEVID};
my $ip_adress = $ENV{VSPG_IP};
my $login = $ENV{VSPG_USER};
my $paswd = $ENV{VSPG_PW};
my $cli_dir= $ENV{VSP_CLIDIR};



my $data = "DATA";
my $time = "TIME";
my $from = "FROM";
my $to = "TO";
my $len = "LENGTH";
my %section_header;
my @values = "";
my $act_directory = localtime();
my $output = get_name_perf_file();
my $sample = 300;
my $timeout = $sample * 3;



sub create_command_file{
  my $file = shift;
  open (DATA, "> $file") || error_die( "Cannot read $file: $!" . __FILE__ . ":" . __LINE__ );
  print DATA "ip $ip_adress        ; Specifies IP adress of SVP\n";
  print DATA "dkcsn $serial_number           ; Specifies Serial Number of SVP\n";
  print DATA "login $login $paswd   ; Logs user into DKC\n";
  print DATA "show                  ; output storing period\n";
  print DATA "; +------------------------------------------------------------\n";
  print DATA "group PhyPG ; Parity Groups\n";
  print DATA "group PhyLDEV ; Logical Volumes\n";
  print DATA "group PhyProc ; Micro-Processor usage\n";
  print DATA "group PhyMPU ; Access Paths and Write Pending\n";
  print DATA "; -------------------------------------------------------------------------------------------------\n";
  print DATA "group PG ; Parity Group Statistics\n";
  print DATA "group LDEV ; LDEV usage in PGs, External Volume Groups or V-VOL Groups\n";
  print DATA "group Port ; Port usage\n";
  print DATA "group PortWWN ; Stats for HBAs connected to ports\n";
  print DATA "group LU ; LDEV usage Summarised by LU Path\n";
  print DATA "; +------------------------------------------------------------\n";
  print DATA "range -0005\n";
  print DATA "outpath \"$config_directory\"  ; specifies the sub-directory in which files will be saved\n";
  print DATA "option nocompress\n";
  print DATA "apply\n";
  close(DATA);

}

sub collect_metrics{

  `/usr/java8_64/jre/bin/java -classpath "$cli_dir/JSanExport.jar:$cli_dir/JSanRmiApiSx.jar:$cli_dir/JSanRmiServerUx.jar:$cli_dir/SanRmiApi.jar" -Xmx536870912 -Dmd.command=$wrkdir/"$STORAGE_NAME"-command.txt -Dmd.logpath=$wrkdir/log -Dmi.rmitimeout=20 sanproject.getmondat.RJMdMain`;


}

sub delete_file{
  my $file = shift;
  if ( -e $file ){
    #unlink "$file" or  error_die ("Unable to unlink $file: $!");
  }

}

sub create_parity_gr_file{
  my $file = "$config_directory/config-RG.txt";
  #`raidcom -login $login $paswd -I1`;
  `raidcom get parity_grp -I1 > "$file"`;
  #`raidcom -logout -I1`;
  return $file;
}

sub create_parity_gr_file2{
  my $file = "$config_directory/config-RG2.txt";
  delete_file($file);
  my $file_in = "$config_directory/config-RG.txt";
  my @array = get_array_data($file_in);
  #`raidcom -login $login $paswd -I1`;
  foreach my $line (@array){
    chomp $line;
    if ($line eq ""){next;}
    $line = remove_whitespace($line);
    if (! (index($line,"GROUP") > -1)){
      my @element = split(" ",$line);
      $element[1] = remove_whitespace($element[1]);
       `raidcom get parity_grp -parity_grp_id $element[1] -I1 >> "$file"`;
    }
  }
  #`raidcom -logout -I1`;
  return $file;
}


sub get_array_data {
  my $file = shift;
  my $test = test_file_exist($file);
  if ($test){
    open( FH, "< $file" ) || error_die( "Cannot read $file: $!" . __FILE__ . ":" . __LINE__ );
    my @file_all = <FH>;
    close(FH);
    return @file_all;
  }
  else{
    error( "File not exist $file: $!" . __FILE__ . ":" . __LINE__ );
    my @file_empty = "";
    return @file_empty;
  }
}

sub set_data_port{

  ### FILES ###
  my $file_port_iops = "$config_directory/Port_dat/Port_IOPS.csv";
  my $file_port_kbps = "$config_directory/Port_dat/Port_KBPS.csv";
  my $file_port_response = "$config_directory/Port_dat/Port_Response.csv";
  #my $file_port_ini_iops = "$config_directory/Port_dat/Port_Initiator_IOPS.csv";
  #my $file_port_ini_kbps = "$config_directory/Port_dat/Port_Initiator_KBPS.csv";
  #my $file_port_ini_response = "$config_directory/Port_dat/Port_Initiator_Response.csv";

  my $section = "Port Level Statistics";
  my $sub_section = "PORT";
  my $metric = "IO Rate(IOPS)";

  #my $header = "ID,IO Rate(IOPS),Read Rate(IOPS),Write Rate(IOPS),Read Hit(%),Write Hit(%),Read Trans. Size(kB/s),Write Trans. Size(kB/s)";
  my $header = "ID,IO Rate(IOPS),Trans. Size(kB/s),Response time";
  $section_header{$section} = $header;

  ### PORT IOPS AND TIME ###

  set_data_first($metric, $section, $sub_section, $file_port_iops);

  ### PORT KBPS ###
  $metric = "Trans. Size(kB/s)";
  set_data($metric, $section, $sub_section, $file_port_kbps);

  ### PORT RESPONSE ###
  $metric = "Response time";
  set_data($metric, $section, $sub_section, $file_port_response);

  ### PORT INITIATOR IOPS ###
  #$metric = "INI_IOPS";
  #set_data($metric, $section, $sub_section, $file_port_ini_iops);

  ### PORT INITIATOR KBPS ###
  #$metric = "INI_KBPS";
  #set_data($metric, $section, $sub_section, $file_port_ini_kbps);

  ### PORT INITIATOR RESPONSE ###
  #$metric = "INI_RESPONSE";
  #set_data($metric, $section, $sub_section, $file_port_ini_response);

}

sub set_data_proc_usage{
  ### FILES ###
  my $file_proc_usage = "$config_directory/PhyProc_dat/PHY_MP.csv";
  my $section = "CPU-CORE Level Statistics";
  my $sub_section = "PROC";
  my $metric = "Usage(%)";

  my $header = "ID,$metric";
  $section_header{$section} = $header;

  ### PROC USAGE ###
  set_data_first($metric, $section, $sub_section, $file_proc_usage);

}

#sub set_data_raid_group{
#  ### FILES ###
#  my $file_raid_group = "$config_directory/PhyPG_dat/PHY_PG.csv";
#  my $section = "RAID GROUP Level Statistics";
#  my $sub_section = "RAID GROUP";
#  my $metric = "Usage(%)";
#
#  my $header = "ID,$metric";
#  $section_header{$section} = $header;
#
#  ### PROC USAGE ###
#  set_data_first($metric, $section, $sub_section, $file_raid_group);
#
#}

sub remove_whitespace{
  my $value = shift;
  $value =~ s/^\s+|\s+$//g;
  return $value;

}

sub get_total_cap_rg{
  my ($data_tmp) = @_;
  my @data = @{$data_tmp};
  my $active = 0;
  my $index_group = "";
  my $index_lba = "";
  my %rg_cap;

  foreach my $line (@data){
    chomp $line;
    if ($line eq ""){
      $active = 0;
      next;
    }
    $line = remove_whitespace($line);
    if ( $line =~ /GROUP/ && $line =~ /SIZE_LBA/ ){
      $index_group = "";
      $index_lba = "";
      my @header = split(" ",$line);
      my $index = -1;
      foreach my $element (@header){
        chomp $element;
        $index++;
        if ($element eq ""){next;}
        $element = remove_whitespace($element);
        if ($element eq "GROUP"){
          $index_group = $index;
        }
        if ($element eq "SIZE_LBA"){
          $index_lba = $index;
        }
      }
      if ($index_group ne "" && $index_lba ne ""){
        $active = 1;
        next;
      }
    }
    if ($active == 1){
      my @header = split(" ",$line);
      chomp $header[$index_group];
      chomp $header[$index_lba];
      my $name = remove_whitespace($header[$index_group]);
      my $lba = remove_whitespace($header[$index_lba]);
      my $total_cap = round((hex($lba) * 512) / (1024*1024*1024));
      if (defined $rg_cap{"$name"}){
        my $cap = $rg_cap{"$name"};
        $rg_cap{"$name"} = $cap + $total_cap;
      }
      else{
        $rg_cap{"$name"} = $total_cap;
      }
    }
  }

  return %rg_cap;
}

sub set_capacity_rg{
  my $section = shift;
  my $sub_section = shift;
  my $metric = shift;
  my $file = shift;
  my $file2 = shift;
  my @metrics = split(",",$metric);

  my @data = get_array_data($file);
  my @data_cap = get_array_data($file2);
  my %header;
  my $key_header = "GROUP";
  my @array_rg;
  my %total_capacity = get_total_cap_rg(\@data_cap);

  foreach my $line (@data){
    chomp $line;
    if ($line eq ""){next;}
    if ($line =~ /$key_header/){
      my $prev;
      foreach my $element(@metrics){
        my $start_element = index ($line, $element);
        if ($start_element  == -1) {next;}
        else{
          if (defined $prev){
            $header{$section}{$prev}{END} = $start_element - 1;
          }
          $header{$section}{$start_element}{NAME} = $element;
          $header{$section}{$start_element}{START} = $start_element;
          if (!defined $prev){
            $prev = $start_element;
            next;
          }
          if (defined $header{$section}{$prev}{END}){
            $header{$section}{$prev}{LENGTH} = $header{$section}{$prev}{END} - $header{$section}{$prev}{START};
          }
          $prev = $start_element;

        }
      }
      foreach my $id (sort { $a <=> $b} keys %{$header{$section}}){
        if (!defined $header{$section}{$id}{LENGTH} && defined $header{$section}{$id}{START}){
          $header{$section}{$id}{LENGTH} = "LAST";
          last;
        }
      }
    }
    else{
      my $group = "";
      my $size_usage = "";
      my $size_free = "";
      my $percent_free = "";
      if (defined $header{$section}){
        foreach my $id (sort { $a <=> $b} keys %{$header{$section}}){
          if (defined $header{$section}{$id}{LENGTH}){
            my $name = $header{$section}{$id}{NAME};
            if ($name ne "GROUP" && $name ne "U(%)"  && $name ne "AV_CAP(GB)"){next;}
            my $start = $header{$section}{$id}{START};
            my $length = $header{$section}{$id}{LENGTH};
            if ($start == 0){$length--;}
            my $value = substr($line,$start,$length);
            $value = remove_whitespace($value);

            if ($name eq "GROUP"){
              $group = $value;
            }
            if ($name eq "AV_CAP(GB)"){
              $size_free = $value;
            }

            if ($name eq "U(%)"){
              my $percent = $value;
              $percent_free = 100 - $percent;
            }
          }
        }
        if (($size_free  == 0 && defined $total_capacity{$group} && $percent_free == 0) || (defined $total_capacity{$group} && $size_free  == 0 && $percent_free != 0) ){
          #my $total_cap = (100/$percent_free) * $size_free;
          #$total_cap = round($total_cap);
          my $total_cap = $total_capacity{$group};
          $size_free = 0;
          $size_usage = $total_cap;
          $performance_data{$section}{$sub_section}{$group}{"Total size(TB)"} = round($total_cap / 1024);
          $performance_data{$section}{$sub_section}{$group}{"Used size(TB)"} = round($size_usage / 1024);
        }
        else{
          if (defined $total_capacity{$group}){
            my $total_cap = $total_capacity{$group};
            #$size_free = ($percent_free/100) * $total_cap;
            $size_usage = $total_cap -  $size_free;
            $performance_data{$section}{$sub_section}{$group}{"Total size(TB)"} = round($total_cap / 1024);
            $performance_data{$section}{$sub_section}{$group}{"Used size(TB)"} = round($size_usage / 1024);
          }
          else{
            push(@array_rg,",$group,,,,,,,,,,,,,,,,\n");
          }
        }
      }
    }
  }
}

sub set_data_raid_group{

  ### FILES ###
  #my $file_pool_iops = "$config_directory/PG_dat/PG_IOPS.csv";
  #my $file_pool_iops_read = "$config_directory/PG_dat/PG_Read_IOPS.csv";
  #my $file_pool_iops_write = "$config_directory/PG_dat/PG_Write_IOPS.csv";



  my $file_pool_iops_read_seq = "$config_directory/PG_dat/PG_Seq_Read_IOPS.csv";
  my $file_pool_iops_read_rnd = "$config_directory/PG_dat/PG_Rnd_Read_IOPS.csv";
  my $file_pool_iops_write_seq = "$config_directory/PG_dat/PG_Seq_Write_IOPS.csv";
  my $file_pool_iops_write_rnd = "$config_directory/PG_dat/PG_Rnd_Write_IOPS.csv";

  #my $file_pool_trans_rate ="$config_directory/PG_dat/PG_TransRate.csv";
  my $file_pool_trans_rate_read = "$config_directory/PG_dat/PG_Read_TransRate.csv";
  my $file_pool_trans_rate_write = "$config_directory/PG_dat/PG_Write_TransRate.csv";

  my $file_pool_response = "$config_directory/PG_dat/PG_Response.csv";
  my $file_pool_response_read = "$config_directory/PG_dat/PG_Read_Response.csv";
  my $file_pool_response_write = "$config_directory/PG_dat/PG_Write_Response.csv";

  my $file_pool_back_trans = "$config_directory/PG_dat/PG_BackTrans.csv";
  my $file_pool_d2cs = "$config_directory/PG_dat/PG_D2CS_Trans.csv";
  my $file_pool_d2cr = "$config_directory/PG_dat/PG_D2CR_Trans.csv";

  my $section = "Raid Group Level Statistics";
  my $sub_section = "RG";
  my $metric = "seq_read_io";

  my $header = "ID,IO Rate(IOPS),Read Rate(IOPS),Write Rate(IOPS),Read Trans. Size(kB/s),Write Trans. Size(kB/s),Total size(TB),Used size(TB),Read response time,Write response time,Data rate back,IO rate back,seq_read_io,rnd_read_io,seq_write_io,rnd_write_io";
  $section_header{$section} = $header;

  ### POOL IOPS READ SEQUENTIAL AND TIME ###

  set_data_first($metric, $section, $sub_section, $file_pool_iops_read_seq);

  ### POOL READ IOPS ###
  #$metric = "Read Rate(IOPS)";
  #set_data($metric, $section, $sub_section, $file_pool_iops_read);

   ### POOL WRITE IOPS ###
  #$metric = "Write Rate(IOPS)";
  #set_data($metric, $section, $sub_section, $file_pool_iops_write);

  ### POOL READ SEQUENTIAL IOPS ###
  #$metric = "IOPS_READ_SEQUENTIAL";
  #set_data($metric, $section, $sub_section, $file_pool_iops_read_seq);

  ### POOL READ RANDOM IOPS ###
  $metric = "rnd_read_io";
  set_data($metric, $section, $sub_section, $file_pool_iops_read_rnd);

  ### POOL WRITE SEQUENTIAL IOPS ###
  $metric = "seq_write_io";
  set_data($metric, $section, $sub_section, $file_pool_iops_write_seq);

  ### POOL WRITE RANDOM IOPS ###
  $metric = "rnd_write_io";
  set_data($metric, $section, $sub_section, $file_pool_iops_write_rnd);


  ### IOPS READ ###
  set_total_metric("seq_read_io","rnd_read_io","Read Rate(IOPS)",$section,$sub_section);

  ### IOPS WRITE ###
  set_total_metric("seq_write_io","rnd_write_io","Write Rate(IOPS)",$section,$sub_section);

  ### TOTAL IOPS ###
  set_total_metric("Read Rate(IOPS)","Write Rate(IOPS)","IO Rate(IOPS)",$section,$sub_section);


  ### TRANS RATE READ ###
  $metric = "Read Trans. Size(kB/s)";
  set_data($metric, $section, $sub_section, $file_pool_trans_rate_read);

  ### TRANS_RATE ###
  #$metric = "TRANS_RATE";
  #set_data($metric, $section, $sub_section, $file_pool_trans_rate);


  ### TRANS RATE WRITE ###
  $metric = "Write Trans. Size(kB/s)";
  set_data($metric, $section, $sub_section, $file_pool_trans_rate_write);

  ### Response TIME ###
  #$metric = "Response time";
  #set_data($metric, $section, $sub_section, $file_pool_response);

  ### Response READ ###
  $metric = "Read response time";
  set_data($metric, $section, $sub_section, $file_pool_response_read);

  ### Response WRITE ###
  $metric = "Write response time";
  set_data($metric, $section, $sub_section, $file_pool_response_write);

  ### C2D OR BACK_TRANS ###
  $metric = "Data rate back";
  set_data($metric, $section, $sub_section, $file_pool_back_trans);

   ### D2CS ###
  $metric = "D2CS";
  set_data($metric, $section, $sub_section, $file_pool_d2cs);

   ### D2CR ###
  $metric = "D2CR";
  set_data($metric, $section, $sub_section, $file_pool_d2cr);

  ### D2CS + D2CR je io_rate_back
  $metric = "IO rate back";
  set_total_metric("D2CR","D2CS",$metric,$section,$sub_section);

  ### set capacity
  my $config_file = create_parity_gr_file();
  my $config_file2 = create_parity_gr_file2();
  $metric = "T,GROUP,Num_LDEV,U(%),AV_CAP(GB),R_LVL,R_TYPE,SL,CL,DRIVE_TYPE";
  set_capacity_rg($section,$sub_section,$metric,$config_file,$config_file2);




}

sub set_data_lun{

  ### FILES ###
  #my $file_lun_iops = "$config_directory/LU_dat/LU_IOPS.csv";
  my $file_lun_iops_read_seq ="$config_directory/LU_dat/LU_Seq_Read_IOPS.csv";
  my $file_lun_iops_write_seq ="$config_directory/LU_dat/LU_Seq_Write_IOPS.csv";
  my $file_lun_iops_read_rnd ="$config_directory/LU_dat/LU_Rnd_Read_IOPS.csv";
  my $file_lun_iops_write_rnd ="$config_directory/LU_dat/LU_Rnd_Write_IOPS.csv";


  #my $file_lun_trans_rate ="$config_directory/LU_dat/LU_TransRate.csv";
  my $file_lun_trans_rate_read = "$config_directory/LU_dat/LU_Read_TransRate.csv";
  my $file_lun_trans_rate_write = "$config_directory/LU_dat/LU_Write_TransRate.csv";

  my $file_lun_hit_read_seq = "$config_directory/LU_dat/LU_Seq_Read_Hit.csv";
  my $file_lun_hit_write_seq = "$config_directory/LU_dat/LU_Seq_Write_Hit.csv";
  my $file_lun_hit_read_rnd = "$config_directory/LU_dat/LU_Rnd_Read_Hit.csv";
  my $file_lun_hit_write_rnd = "$config_directory/LU_dat/LU_Rnd_Write_Hit.csv";

  #my $file_lun_response = "$config_directory/LU_dat/LU_Response.csv";
  my $file_lun_response_read = "$config_directory/LU_dat/LU_Read_Response.csv";
  my $file_lun_response_write = "$config_directory/LU_dat/LU_Write_Response.csv";

  my $file_lun_c2d = "$config_directory/LU_dat/LU_C2D_Trans.csv";
  my $file_lun_d2cs = "$config_directory/LU_dat/LU_D2CS_Trans.csv";
  my $file_lun_d2cr = "$config_directory/LU_dat/LU_D2CR_Trans.csv";

  my $section = "Volume Level Statistics";
  my $sub_section = "LUN";
  my $metric = "seq_read_io";

  my $header = "ID,IO Rate(IOPS),Read Rate(IOPS),Write Rate(IOPS),Read Hit(%),Write Hit(%),Read Trans. Size(kB/s),Write Trans. Size(kB/s),Read response time,Write response time,Capacity(MB),Used(MB),Data rate back,IO rate back,seq_read_io,rnd_read_io,seq_write_io,rnd_write_io,seq_read_hit,rnd_read_hit,seq_write_hit,rnd_write_hit";
  $section_header{$section} = $header;

  ### LUN IOPS READ SEQUENTIAL AND TIME ###
  set_data_first($metric, $section, $sub_section, $file_lun_iops_read_seq);

  ### SET ID LUN/VOLUME
  #set_id_volume($section,$sub_section,$metric);

  ### IOPS READ SEQUENTIAL ###
  #$metric = "IOPS_READ_SEQUENTIAL";
  #set_data($metric, $section, $sub_section, $file_lun_iops_read_seq);

  ### IOPS WRITE SEQUENTIAL ###
  $metric = "seq_write_io";
  set_data($metric, $section, $sub_section, $file_lun_iops_write_seq);

  ### IOPS READ RANDOM ###
  $metric = "rnd_read_io";
  set_data($metric, $section, $sub_section, $file_lun_iops_read_rnd);

  ### IOPS WRITE RANDOM ###
  $metric = "rnd_write_io";
  set_data($metric, $section, $sub_section, $file_lun_iops_write_rnd);

  ### IOPS READ ###
  #set_total_metric("seq_read_io","rnd_read_io","Read Rate(IOPS)",$section,$sub_section);

  ### IOPS WRITE ###
  #set_total_metric("seq_write_io","rnd_write_io","Write Rate(IOPS)",$section,$sub_section);


  ### total IOPS ###
  #set_total_metric("Read Rate(IOPS)","Write Rate(IOPS)","IO Rate(IOPS)",$section,$sub_section);


  ### HIT READ SEQUENTIAL ###
  $metric = "seq_read_hit";
  set_data($metric, $section, $sub_section, $file_lun_hit_read_seq);

  ### HIT READ RANDOM ###
  $metric = "rnd_read_hit";
  set_data($metric, $section, $sub_section, $file_lun_hit_read_rnd);

  ### HIT WRITE RANDOM ###
  $metric = "rnd_write_hit";
  set_data($metric, $section, $sub_section, $file_lun_hit_write_rnd);

  ### HIT WRITE SEQUENTIAL ###
  $metric = "seq_write_hit";
  set_data($metric, $section, $sub_section, $file_lun_hit_write_seq);

  ### HIT READ ###
  #$metric = "Read Hit(%)";
  #set_total_metric("seq_read_hit","rnd_read_hit",$metric,$section,$sub_section, "seq_read_io","rnd_read_io");

  ### HIT WRITE ###
  #$metric = "Write Hit(%)";
  #set_total_metric("seq_write_hit","rnd_write_hit",$metric,$section,$sub_section, "seq_write_io", "rnd_write_io");

  ### TRANS RATE READ ###
  $metric = "Read Trans. Size(kB/s)";
  set_data($metric, $section, $sub_section, $file_lun_trans_rate_read);

  ### TRANS_RATE ###
  #$metric = "TRANS_RATE";
  #set_data($metric, $section, $sub_section, $file_lun_trans_rate);


  ### TRANS RATE WRITE ###
  $metric = "Write Trans. Size(kB/s)";
  set_data($metric, $section, $sub_section, $file_lun_trans_rate_write);

  ### Response TIME ###
  #$metric = "RESPONSE";
  #set_data($metric, $section, $sub_section, $file_lun_response);

  ### Response READ ###
  $metric = "Read response time";
  set_data($metric, $section, $sub_section, $file_lun_response_read);

  ### Response WRITE ###
  $metric = "Write response time";
  set_data($metric, $section, $sub_section, $file_lun_response_write);
  #print Dumper \%performance_data;

  ### C2D ###
  $metric = "Data rate back";
  set_data($metric, $section, $sub_section, $file_lun_c2d);

   ### D2CS ###
  $metric = "D2CS";
  set_data($metric, $section, $sub_section, $file_lun_d2cs);

   ### D2CR ###
  $metric = "D2CR";
  set_data($metric, $section, $sub_section, $file_lun_d2cr);

  ### D2CS + D2CR je io_rate_back
  #$metric = "IO rate back";
  #set_total_metric("D2CR","D2CS",$metric,$section,$sub_section);


  ### set metric per id volume ###
  $metric = "seq_read_io,seq_write_io,rnd_read_io,rnd_write_io,Read Trans. Size(kB/s),Write Trans. Size(kB/s),D2CS,Data rate back,D2CR";
  set_id_volume($section,$sub_section,$metric);

  ### IOPS READ ###
  set_total_metric("seq_read_io","rnd_read_io","Read Rate(IOPS)",$section,$sub_section);

  ### IOPS WRITE ###
  set_total_metric("seq_write_io","rnd_write_io","Write Rate(IOPS)",$section,$sub_section);

  ### total IOPS ###
  set_total_metric("Read Rate(IOPS)","Write Rate(IOPS)","IO Rate(IOPS)",$section,$sub_section);

  ### D2CS + D2CR je io_rate_back
  $metric = "IO rate back";
  set_total_metric("D2CR","D2CS",$metric,$section,$sub_section);

  ### HIT READ ###
  $metric = "Read Hit(%)";
  set_total_metric("seq_read_hit","rnd_read_hit",$metric,$section,$sub_section, "seq_read_io","rnd_read_io");

  ### HIT WRITE ###
  $metric = "Write Hit(%)";
  set_total_metric("seq_write_hit","rnd_write_hit",$metric,$section,$sub_section, "seq_write_io", "rnd_write_io");

  my $file_cap = create_volume_file();
  $metric = "PORT#,/ALPA/C,TID#,LU#,Seq#,Num,LDEV#,Used(MB),LU_CAP(MB),U(%),T(%),PID";
  set_cap_volume($file_cap,$metric,$section,$sub_section);

  #print Dumper \%performance_data;
}

sub create_volume_file{
  my $file = "$config_directory/config-VOLUME.txt";
  delete_file($file);
  my $file_in = "$config_directory/config-PORT.txt";
  my @array = get_array_data($file_in);
  #`raidcom -login $login $paswd -I1`;
  foreach my $line (@array){
    chomp $line;
    if ($line eq ""){
      $line = remove_whitespace($line);
      if ($line =~ /TAR/){
        my @elements = split(" ",$line);
        $elements[0] = remove_whitespace($elements[0]);
        `raidvchkscan -v aou -p $elements[0] -I1 >> "$file"`;
      }
    }
  }
  #`raidcom -logout -I1`;
  return $file;
}

sub set_cap_volume{
  my ($file,$metric,$section,$sub_section) = @_;
  my @data = get_array_data($file);
  my %header;
  my $key_header = "LU#";
  my @metrics = split (",",$metric);

  foreach my $line (@data){
     chomp $line;
    if ($line eq ""){next;}
    if ($line =~ /$key_header/){
      my $prev;
      foreach my $element(@metrics){
        my $start_element = index ($line, $element);
        if ($start_element  == -1) {next;}
        else{
          if (defined $prev){
            $header{$section}{$prev}{END} = $start_element - 1;
          }
          $header{$section}{$start_element}{NAME} = $element;
          $header{$section}{$start_element}{START} = $start_element;
          if (!defined $prev){
            $prev = $start_element;
            next;
          }
          if (defined $header{$section}{$prev}{END}){
            $header{$section}{$prev}{LENGTH} = $header{$section}{$prev}{END} - $header{$section}{$prev}{START};
          }
          $prev = $start_element;

        }
      }
    }
    else{
      my $lun = "";
      my $cap_total = "";
      my $cap_used = "";
      my $cap_free = "";
      if (defined $header{$section}){
        foreach my $id (sort { $a <=> $b} keys %{$header{$section}}){
          if (defined $header{$section}{$id}{LENGTH}){
            my $name = $header{$section}{$id}{NAME};
            if ($name ne "LU#" && $name ne "Used(MB)"  && $name ne "LU_CAP(MB)"){next;}
            my $start = $header{$section}{$id}{START};
            my $length = $header{$section}{$id}{LENGTH};
            if ($start == 0){$length--;}
            my $value = substr($line,$start,$length);
            $value = remove_whitespace($value);

            if ($name eq "LU#"){
              $lun = $value;
            }
            if ($name eq "Used(MB)"){
              $cap_used = $value;
            }
            if ($name eq "LU_CAP(MB)"){
              $cap_total = $value;
            }

            if ($lun ne "" && $cap_total ne "" && $cap_used ne ""){
              $cap_free = $cap_total - $cap_used;
              $performance_data{$section}{$sub_section}{$lun}{"Capacity(MB)"} = $cap_total;
              $performance_data{$section}{$sub_section}{$lun}{"Used(MB)"} = $cap_used;
            }
          }
        }
      }
    }
  }
}


sub set_data{
  my $metric = shift;
  my $section = shift;
  my $sub_section = shift;
  my $file = shift;
  my $i = 1;
  my @array = get_array_data($file);
  foreach my $line (@array){
    if ($line =~ /No/){
      $i = 2;
      next;
    }
    if ($i == 2){
      my @array_line = split(",",$line);
      foreach my $id (keys %{$performance_data{$section}{$sub_section}}){
        my $position = $performance_data{$section}{$sub_section}{$id}{POSITION};
        if (!defined $position){next;}
        if (!defined $performance_data{$section}{$sub_section}{$id}{$metric}){
          $array_line[$position] =~ s/^\s+|\s+$//g;
          if ($array_line[$position] =~ /-/){
            $performance_data{$section}{$sub_section}{$id}{$metric} = "NAN";
            next;
          }
          else{
            if ($metric eq "Response time" || $metric eq "Read response time" || $metric eq "Write response time" ){
              $array_line[$position] = $array_line[$position] / 1000; ### microseconds to miliseconds
              $array_line[$position] = round($array_line[$position]);
            }
          }
          $performance_data{$section}{$sub_section}{$id}{$metric} = $array_line[$position];
        }
      }
      $i = 3;
    }
  }
}

sub get_hit_numerator_volume{
  my $section = shift;
  my $sub_section = shift;
  my $metric = shift;
  my $metric_io = shift;
  my $id = shift;
  my $numerator = shift;

  if (defined $performance_data{$section}{$sub_section}{$id}{$metric} && $performance_data{$section}{$sub_section}{$id}{$metric} ne "NAN"){
    $numerator = $numerator + ($performance_data{$section}{$sub_section}{$id}{$metric} * $performance_data{$section}{$sub_section}{$id}{$metric_io});
  return $numerator;
  }

  else{
    return $numerator;
  }

}

sub get_response_numerator_volume{
  my $section = shift;
  my $sub_section = shift;
  my $metric = shift;
  my $metric_io = shift;
  my $id = shift;
  my $numerator = shift;

  if (defined $performance_data{$section}{$sub_section}{$id}{$metric} && $performance_data{$section}{$sub_section}{$id}{$metric} ne "NAN"){
    $numerator = $numerator + ($performance_data{$section}{$sub_section}{$id}{$metric} * $metric_io);
  return $numerator;
  }

  else{
    return $numerator;
  }

}

sub get_hit_denominator_volume{
  my $section = shift;
  my $sub_section = shift;
  my $metric_io = shift;
  my $id = shift;
  my $denominator = shift;

  if (defined $performance_data{$section}{$sub_section}{$id}{$metric_io} && $performance_data{$section}{$sub_section}{$id}{$metric_io} ne "NAN"){
    $denominator = $denominator + $performance_data{$section}{$sub_section}{$id}{$metric_io};
  return $denominator;
  }

  else{
    return $denominator;
  }

}

sub get_response_denominator_volume{
  my $section = shift;
  my $sub_section = shift;
  my $metric_io = shift;
  my $id = shift;
  my $denominator = shift;

  $denominator = $denominator + $metric_io;
  return $denominator;

}

sub set_id_volume {

###
# CL1-A.01(B1-LPAR1-Prod).0
# CL1-A -         PORT
# 01 -            HOST GROUP
# B1-LPAR1-Prod - GROUP NAME
# 0               ID LUN/VOLUME

  #print Dumper \%performance_data;
  my $sum_1 = 0;
  my $sum_2 = 0;
  my $sum_3 = 0;
  my $sum_4 = 0;
  my $sum_5 = 0;
  my $sum_6 = 0;
  my $sum_7 = 0;
  my $sum_8 = 0;
  my $sum_9 = 0;
  my $last_id = "";

  my $seq_read_hit = "seq_read_hit";
  my $seq_read_hit_numerator = 0;
  my $seq_read_hit_denominator = 0;

  my $rnd_read_hit = "rnd_read_hit";
  my $rnd_read_hit_numerator = 0;
  my $rnd_read_hit_denominator = 0;


  my $seq_write_hit = "seq_write_hit";
  my $seq_write_hit_numerator = 0;
  my $seq_write_hit_denominator = 0;

  my $rnd_write_hit = "rnd_write_hit";
  my $rnd_write_hit_numerator = 0;
  my $rnd_write_hit_denominator = 0;

  my $response_read = "Read response time";
  my $response_read_numerator = 0;
  my $response_read_denominator = 0;
  my $response_write = "Write response time";
  my $response_write_numerator = 0;
  my $response_write_denominator = 0;


  my $section = shift;
  my $sub_section = shift;
  my $metric = shift;
  my @metrics = split(",",$metric);
  my @inventory_id;

  my $size = keys $performance_data{$section}{$sub_section};
  for (my $i = 1; $i <= $size; $i++ ){
    foreach my $id (keys %{$performance_data{$section}{$sub_section}}){
      my $id_new = $id;
      $id_new =~ s/.*\)\.//g;
      my $check = 0;
      foreach my $line (@inventory_id){
        if ($line eq $id_new){
          $check = 1;
          last;
        }
      }
      if ($check == 1){next;}
      #print $id . "\n";
      if ($last_id eq ""){
        $last_id = $id_new;
          if (defined $performance_data{$section}{$sub_section}{$id}{$metrics[0]} && $performance_data{$section}{$sub_section}{$id}{$metrics[0]} ne "NAN"){
            $sum_1 = $sum_1 + $performance_data{$section}{$sub_section}{$id}{$metrics[0]};
          }
          if (defined $performance_data{$section}{$sub_section}{$id}{$metrics[1]} && $performance_data{$section}{$sub_section}{$id}{$metrics[1]} ne "NAN"){
            $sum_2 = $sum_2 + $performance_data{$section}{$sub_section}{$id}{$metrics[1]};
          }
          if (defined $performance_data{$section}{$sub_section}{$id}{$metrics[2]} && $performance_data{$section}{$sub_section}{$id}{$metrics[2]} ne "NAN"){
            $sum_3 = $sum_3 + $performance_data{$section}{$sub_section}{$id}{$metrics[2]};
          }
          if (defined $performance_data{$section}{$sub_section}{$id}{$metrics[3]} && $performance_data{$section}{$sub_section}{$id}{$metrics[3]} ne "NAN"){
            $sum_4 = $sum_4 + $performance_data{$section}{$sub_section}{$id}{$metrics[3]};
          }
          if (defined $performance_data{$section}{$sub_section}{$id}{$metrics[4]} && $performance_data{$section}{$sub_section}{$id}{$metrics[4]} ne "NAN"){
            $sum_5 = $sum_5 + $performance_data{$section}{$sub_section}{$id}{$metrics[4]};
          }
          if (defined $performance_data{$section}{$sub_section}{$id}{$metrics[5]} && $performance_data{$section}{$sub_section}{$id}{$metrics[5]} ne "NAN"){
            $sum_6 = $sum_6 + $performance_data{$section}{$sub_section}{$id}{$metrics[5]};
          }
          if (defined $performance_data{$section}{$sub_section}{$id}{$metrics[6]} && $performance_data{$section}{$sub_section}{$id}{$metrics[6]} ne "NAN"){
            $sum_7 = $sum_7 + $performance_data{$section}{$sub_section}{$id}{$metrics[6]};
          }
          if (defined $performance_data{$section}{$sub_section}{$id}{$metrics[7]} && $performance_data{$section}{$sub_section}{$id}{$metrics[7]} ne "NAN"){
            $sum_8 = $sum_8 + $performance_data{$section}{$sub_section}{$id}{$metrics[7]};
          }
          $seq_read_hit_numerator = get_hit_numerator_volume($section,$sub_section,$seq_read_hit,$metrics[0],$id,$seq_read_hit_numerator);
          $seq_read_hit_denominator = get_hit_denominator_volume($section,$sub_section,$metrics[0],$id,$seq_read_hit_denominator);

          $rnd_read_hit_numerator = get_hit_numerator_volume($section,$sub_section,$rnd_read_hit,$metrics[2],$id,$rnd_read_hit_numerator);
          $rnd_read_hit_denominator = get_hit_denominator_volume($section,$sub_section,$metrics[2],$id,$rnd_read_hit_denominator);

          $seq_write_hit_numerator = get_hit_numerator_volume($section,$sub_section,$seq_write_hit,$metrics[1],$id,$seq_write_hit_numerator);
          $seq_write_hit_denominator = get_hit_denominator_volume($section,$sub_section,$metrics[1],$id,$seq_write_hit_denominator);

          $rnd_write_hit_numerator = get_hit_numerator_volume($section,$sub_section,$rnd_write_hit,$metrics[3],$id,$rnd_write_hit_numerator);
          $rnd_write_hit_denominator = get_hit_denominator_volume($section,$sub_section,$metrics[3],$id,$rnd_write_hit_denominator);

          ### response time ###
          my $iops = $performance_data{$section}{$sub_section}{$id}{$metrics[0]} + $performance_data{$section}{$sub_section}{$id}{$metrics[1]} + $performance_data{$section}{$sub_section}{$id}{$metrics[2]} + $performance_data{$section}{$sub_section}{$id}{$metrics[3]};
          $response_read_numerator = get_response_numerator_volume($section,$sub_section,$response_read,$iops,$id,$response_read_numerator);
          $response_write_numerator = get_response_numerator_volume($section,$sub_section,$response_write,$iops,$id,$response_write_numerator);

          $response_read_denominator = get_response_denominator_volume($section,$sub_section,$iops,$id,$response_read_denominator);
          $response_write_denominator = get_response_denominator_volume($section,$sub_section,$iops,$id,$response_write_denominator);
          delete($performance_data{$section}{$sub_section}{$id});



          next;
      }

      if ($id_new eq $last_id){
        if (defined $performance_data{$section}{$sub_section}{$id}{$metrics[0]} && $performance_data{$section}{$sub_section}{$id}{$metrics[0]} ne "NAN"){
          $sum_1 = $sum_1 + $performance_data{$section}{$sub_section}{$id}{$metrics[0]};
        }
        if (defined $performance_data{$section}{$sub_section}{$id}{$metrics[1]} && $performance_data{$section}{$sub_section}{$id}{$metrics[1]} ne "NAN"){
          $sum_2 = $sum_2 + $performance_data{$section}{$sub_section}{$id}{$metrics[1]};
        }
        if (defined $performance_data{$section}{$sub_section}{$id}{$metrics[2]} && $performance_data{$section}{$sub_section}{$id}{$metrics[2]} ne "NAN"){
          $sum_3 = $sum_3 + $performance_data{$section}{$sub_section}{$id}{$metrics[2]};
        }
        if (defined $performance_data{$section}{$sub_section}{$id}{$metrics[3]} && $performance_data{$section}{$sub_section}{$id}{$metrics[3]} ne "NAN"){
          $sum_4 = $sum_4 + $performance_data{$section}{$sub_section}{$id}{$metrics[3]};
        }
        if (defined $performance_data{$section}{$sub_section}{$id}{$metrics[4]} && $performance_data{$section}{$sub_section}{$id}{$metrics[4]} ne "NAN"){
          $sum_5 = $sum_5 + $performance_data{$section}{$sub_section}{$id}{$metrics[4]};
        }
        if (defined $performance_data{$section}{$sub_section}{$id}{$metrics[5]} && $performance_data{$section}{$sub_section}{$id}{$metrics[5]} ne "NAN"){
          $sum_6 = $sum_6 + $performance_data{$section}{$sub_section}{$id}{$metrics[5]};
        }
        if (defined $performance_data{$section}{$sub_section}{$id}{$metrics[6]} && $performance_data{$section}{$sub_section}{$id}{$metrics[6]} ne "NAN"){
          $sum_7 = $sum_7 + $performance_data{$section}{$sub_section}{$id}{$metrics[6]};
        }
        if (defined $performance_data{$section}{$sub_section}{$id}{$metrics[7]} && $performance_data{$section}{$sub_section}{$id}{$metrics[7]} ne "NAN"){
          $sum_8 = $sum_8 + $performance_data{$section}{$sub_section}{$id}{$metrics[7]};
        }

        $seq_read_hit_numerator = get_hit_numerator_volume($section,$sub_section,$seq_read_hit,$metrics[0],$id,$seq_read_hit_numerator);
        $seq_read_hit_denominator = get_hit_denominator_volume($section,$sub_section,$metrics[0],$id,$seq_read_hit_denominator);
        $rnd_read_hit_numerator = get_hit_numerator_volume($section,$sub_section,$rnd_read_hit,$metrics[2],$id,$rnd_read_hit_numerator);
        $rnd_read_hit_denominator = get_hit_denominator_volume($section,$sub_section,$metrics[2],$id,$rnd_read_hit_denominator);

        $seq_write_hit_numerator = get_hit_numerator_volume($section,$sub_section,$seq_write_hit,$metrics[1],$id,$seq_write_hit_numerator);
        $seq_write_hit_denominator = get_hit_denominator_volume($section,$sub_section,$metrics[1],$id,$seq_write_hit_denominator);

        $rnd_write_hit_numerator = get_hit_numerator_volume($section,$sub_section,$rnd_write_hit,$metrics[3],$id,$rnd_write_hit_numerator);
        $rnd_write_hit_denominator = get_hit_denominator_volume($section,$sub_section,$metrics[3],$id,$rnd_write_hit_denominator);

        ### response time ###
        my $iops = $performance_data{$section}{$sub_section}{$id}{$metrics[0]} + $performance_data{$section}{$sub_section}{$id}{$metrics[1]} + $performance_data{$section}{$sub_section}{$id}{$metrics[2]} + $performance_data{$section}{$sub_section}{$id}{$metrics[3]};
        $response_read_numerator = get_response_numerator_volume($section,$sub_section,$response_read,$iops,$id,$response_read_numerator);
        $response_write_numerator = get_response_numerator_volume($section,$sub_section,$response_write,$iops,$id,$response_write_numerator);

        $response_read_denominator = get_response_denominator_volume($section,$sub_section,$iops,$id,$response_read_denominator);
        $response_write_denominator = get_response_denominator_volume($section,$sub_section,$iops,$id,$response_write_denominator);
        delete($performance_data{$section}{$sub_section}{$id});

      }
      #print $performance_data{$section}{$sub_section}{$id} . "\n";

    }
    if ($last_id eq ""){next;}
    #print "$last_id $metric $sum\n";
    $performance_data{$section}{$sub_section}{$last_id}{$metrics[0]} = $sum_1;
    $performance_data{$section}{$sub_section}{$last_id}{$metrics[1]} = $sum_2;
    $performance_data{$section}{$sub_section}{$last_id}{$metrics[2]} = $sum_3;
    $performance_data{$section}{$sub_section}{$last_id}{$metrics[3]} = $sum_4;
    $performance_data{$section}{$sub_section}{$last_id}{$metrics[4]} = $sum_5;
    $performance_data{$section}{$sub_section}{$last_id}{$metrics[5]} = $sum_6;
    $performance_data{$section}{$sub_section}{$last_id}{$metrics[6]} = $sum_7;
    $performance_data{$section}{$sub_section}{$last_id}{$metrics[7]} = $sum_8;
    $performance_data{$section}{$sub_section}{$last_id}{$metrics[8]} = $sum_9;
    $performance_data{$section}{$sub_section}{$last_id}{ID} = $last_id;

    if ($seq_read_hit_denominator == 0){
      $performance_data{$section}{$sub_section}{$last_id}{$seq_read_hit} = 0;
    }
    else{
      $performance_data{$section}{$sub_section}{$last_id}{$seq_read_hit} = round($seq_read_hit_numerator / $seq_read_hit_denominator);
    }

    if ($rnd_read_hit_denominator == 0){
      $performance_data{$section}{$sub_section}{$last_id}{$rnd_read_hit} = 0;
    }
    else{
      $performance_data{$section}{$sub_section}{$last_id}{$rnd_read_hit} = round($rnd_read_hit_numerator / $rnd_read_hit_denominator);
    }

    if ($seq_write_hit_denominator == 0){
      $performance_data{$section}{$sub_section}{$last_id}{$seq_write_hit} = 0;
    }
    else{
      $performance_data{$section}{$sub_section}{$last_id}{$seq_write_hit} = round($seq_write_hit_numerator / $seq_write_hit_denominator);
    }

    if ($rnd_write_hit_denominator == 0){
      $performance_data{$section}{$sub_section}{$last_id}{$rnd_write_hit} = 0;
    }
    else{
      $performance_data{$section}{$sub_section}{$last_id}{$rnd_write_hit} = round($rnd_write_hit_numerator / $rnd_write_hit_denominator);
    }
    if ($response_read_denominator == 0){
      $performance_data{$section}{$sub_section}{$last_id}{$response_read} = 0;
    }
    else{
      $performance_data{$section}{$sub_section}{$last_id}{$response_read} = round($response_read_numerator / $response_read_denominator);
    }
    if ($response_write_denominator == 0){
      $performance_data{$section}{$sub_section}{$last_id}{$response_write} = 0;
    }
    else{
      $performance_data{$section}{$sub_section}{$last_id}{$response_write} = round($response_write_numerator / $response_write_denominator);
    }

    push (@inventory_id,$last_id);
    $last_id = "";
    $sum_1 = 0;
    $sum_2 = 0;
    $sum_3 = 0;
    $sum_4 = 0;
    $sum_5 = 0;
    $sum_6 = 0;
    $sum_7 = 0;
    $sum_8 = 0;
    $sum_9 = 0;
    $seq_read_hit_numerator = 0;
    $seq_read_hit_denominator = 0;
    $rnd_read_hit_numerator = 0;
    $rnd_read_hit_denominator = 0;

    $seq_write_hit_numerator = 0;
    $seq_write_hit_denominator = 0;
    $rnd_write_hit_numerator = 0;
    $rnd_write_hit_denominator = 0;

    $response_write_numerator = 0;
    $response_write_denominator = 0;
    $response_read_numerator = 0;
    $response_read_denominator = 0;

  }
  #print Dumper \@inventory_id;



  #print Dumper \%performance_data;


}

sub set_data_first{
  my $metric = shift;
  my $section = shift;
  my $sub_section = shift;
  my $file = shift;
  my $i = 1;
  my @array = get_array_data($file);
  foreach my $line (@array){
    if ($line =~ /From/ ){
      my $start = get_start($line);
      #print $start;
      $performance_data{$section}{$time}{$from} = $start;
      #print Dumper \%performance_data;
    }
    if ($line =~ /To/ ){
      my $end = get_end($line);
      #print $start;
      $performance_data{$section}{$time}{$to} = $end;
      #print Dumper \%performance_data;
    }
    if (defined $performance_data{$section}{$time}{$to} && $performance_data{$section}{$time}{$from} && $i == 1){
      my $end_time = str2time($performance_data{$section}{$time}{$to});
      my $start_time = str2time($performance_data{$section}{$time}{$from});
      my $length = $end_time - $start_time;
      $performance_data{$section}{$len} = $length;
      $i++;
    }
    if ($line =~ /No/){
      $i = 2;
      my @array_line = split(",",$line);
      my $position = -1;
      foreach my $header (@array_line){
        $position++;
        if ($header =~ /No/ || $header =~ /time/){
          next;
        }
        else{
          $header =~ s/"//g;
          $header =~ s/^\s+|\s+$//g;
          $performance_data{$section}{$sub_section}{$header}{ID} = $header;
          $performance_data{$section}{$sub_section}{$header}{POSITION} = $position;
          next;
        }
      }
    next;
    }
    if ($i == 2){
      my @array_line = split(",",$line);
      foreach my $id (keys %{$performance_data{$section}{$sub_section}}){
        my $position = $performance_data{$section}{$sub_section}{$id}{POSITION};
        if (!defined $performance_data{$section}{$sub_section}{$id}{$metric}){
          $array_line[$position] =~ s/^\s+|\s+$//g;
          $performance_data{$section}{$sub_section}{$id}{$metric} = $array_line[$position];
        }
      }
      $i = 3;
    }
  }
}

sub set_total_metric{
### random + sequential ###
  my $metric_random = shift;
  my $metric_seq = shift;
  my $metric_total = shift;
  my $section = shift;
  my $sub_section = shift;
  my $seq_io = shift;
  my $rnd_io = shift;
  if ($metric_total eq "Data rate back" || $metric_total eq "IO rate back" || $metric_total eq "Read Rate(IOPS)" || $metric_total eq "Write Rate(IOPS)" || $metric_total eq "IO Rate(IOPS)"){
    foreach my $id (keys %{$performance_data{$section}{$sub_section}}){
      my $random = $performance_data{$section}{$sub_section}{$id}{$metric_random};
      my $seq = $performance_data{$section}{$sub_section}{$id}{$metric_seq};
      if (!defined $random || !defined $seq){next;}
      my $total = $seq + $random;
      $performance_data{$section}{$sub_section}{$id}{$metric_total} = $total;
    }
  }

  if ($metric_total eq "Read Hit(%)" || $metric_total eq "Write Hit(%)"){
    foreach my $id (keys %{$performance_data{$section}{$sub_section}}){
      my $random = $performance_data{$section}{$sub_section}{$id}{$metric_random};
      my $seq = $performance_data{$section}{$sub_section}{$id}{$metric_seq};
      if (!defined $random || !defined $seq){next;}
      my $seq_iops = $performance_data{$section}{$sub_section}{$id}{$seq_io};
      my $rnd_iops = $performance_data{$section}{$sub_section}{$id}{$rnd_io};
      if ($rnd_iops+$seq_iops == 0){
        my $total = 0;
        $performance_data{$section}{$sub_section}{$id}{$metric_total} = $total;
        next;
      }
      my $total = (($seq * $seq_iops) + ($random * $rnd_iops))/($rnd_iops+$seq_iops);
      $total = round($total);
      $performance_data{$section}{$sub_section}{$id}{$metric_total} = $total;
      next;
    }

  }
}

sub error_die
{
  my $message = shift;
  print STDERR "$message\n";
  `raidcom -logout -I1`;
  exit (1);
}

sub round{
  my $number = shift;
  my $num = $number;
  if ($number =~ /\./){
    $number =~ s/.*\.//g;
    my $length = length($number);
    if ($length > 3){
    my  $rounded = sprintf("%.3f", $num);
      return $rounded;
    }
    else{
      return $num;
    }
  }
  else{
    return $num;
  }
}


sub get_start{
  my $start = shift;
  $start =~ s/From//g;
  $start =~ s/://;
  $start =~ s/\//:/g;
  $start =~ s/^\s+|\s+$//g;
  $start =~ s/ /T/g;
  $start = $start . ":00";
  return $start;
}

sub get_end{
  my $end = shift;
  $end =~ s/To//g;
  $end =~ s/://;
  $end =~ s/\//:/g;
  $end =~ s/^\s+|\s+$//g;
  $end =~ s/ /T/g;
  $end = $end . ":00";
  return $end;
}

sub test_file_exist{
  my $file = shift;
  if (!-e $file || -z $file){
    return 0;
  }
  else{
    return 1;
  }
}

sub write_data{
  foreach my $title (keys %section_header){
    open(DATA, ">>$output") or error_die ("Cannot open file: $output : $!");
    #print "$title\n";
    get_data("$title","$section_header{$title}");
    if (!defined $performance_data{$title}{TIME}{FROM} || !defined $performance_data{$title}{TIME}{TO} || !defined $performance_data{$title}{LENGTH}){
      close DATA;
      next;
    }
    print DATA "$title\n";
    my $interval_start =   " Interval Start:  " .$performance_data{$title}{TIME}{FROM};
    my $interval_end =     " Interval End:    " .$performance_data{$title}{TIME}{TO};
    my $interval_length =  " Interval Length: " .$performance_data{$title}{LENGTH};
    print DATA" $interval_start";
    print DATA"\n";
    print DATA" $interval_end";
    print DATA"\n";
    print DATA" $interval_length";
    print DATA"\n";
    print DATA "-----------------------------------\n";
    #print DATA"\n";
    #$section{$sect} =~ s/\n//g;
    print DATA $section_header{$title};
    print DATA @values;
    print DATA "\n\n";
    close DATA;
  }

}

sub get_data{
  my $name_section = shift;
  my $section_contents = shift;
  @values = "";
  foreach my $id (keys %{$performance_data{$name_section}}){
    if ($id eq "LENGTH" || $id eq "TIME"){next;}
      foreach my $section (keys %{$performance_data{$name_section}{$id}}){
        if (!@values eq ""){
          my $last = pop(@values);
          $last =~ s/,//g;
          push(@values,$last);
        }
        push(@values,"\n");
        my @headers = split(",",$section_contents);
        foreach my $element(@headers){
        chomp $element;
        $element=~ s/^\s+|\s+$//g;
        if (defined $performance_data{$name_section}{$id}{$section}{$element} && $performance_data{$name_section}{$id}{$section}{$element} ne "NAN"){
          push(@values,"$performance_data{$name_section}{$id}{$section}{$element},");
        }
        else{
          push(@values,",");
        }
      }
    }
  }
  my $last = pop(@values);
  $last =~ s/,//g;
  push(@values,$last);
}

sub data_structure{
  my  $directory = $configuration;
  if (!-d $directory){
    mkdir $directory || error_die( "Cannot read $directory: $!" . __FILE__ . ":" . __LINE__ );
  }
  for (my $i=0;$i<60;$i=$i+5){
    if ($i<10){
      if (!-d "$directory/0$i"){
      mkdir "$directory/0$i" || error_die( "Cannot read $directory: $!" . __FILE__ . ":" . __LINE__ );
    }
    }
    else{
      if (!-d "$directory/$i"){
        mkdir "$directory/$i" || error_die( "Cannot read $directory: $!" . __FILE__ . ":" . __LINE__ );
      }
    }
  }
}


sub get_name_perf_file{
  #my $dir = "/sys2rrd/HUS_CLI/configuration";
  my @time = localtime();
  my $time_human = localtime();
  my $sec = $time[0];
  my $minute = $time[1];
  my $hour = $time[2];
  my $day = $time[3];
  my $month = $time[4] + 1;
  my (undef,undef,undef,undef,$year) = split(" ",$time_human);
  chomp $year;

  if ($minute < 10){$minute = "0$minute";}
  if ($hour < 10){$hour = "0$hour";}
  if ($day < 10){$day = "0$day";}
  if ($month < 10){$month = "0$month";}
  if ($sec < 10){$sec = "0$sec";}
  my $name_file = "$wrkdir/$STORAGE_NAME"."_vspgperf_"."$year$month$day"."_"."$hour$minute".".out";
  #print "$name_file\n";
  return $name_file;

}

### main function ####
eval{
  #Set alarm
  my $act_time = localtime();
  my $act_directory = $act_time;
  local $SIG{ALRM} = sub { die "$act_time: died in SIG ALRM"; };
  alarm($timeout);
  my @entry_time = split(" ",$act_directory);
  (undef, my $active_minute, undef) =  split(":",$entry_time[3]);
  $config_directory = "$configuration/$active_minute";
  data_structure();
  create_command_file($command_file);
  if ($active_minute eq "00"){
    system "perl $bindir/vspgconf.pl";

  }
  collect_metrics();
  `raidcom -login $login $paswd -I1`;
  set_data_lun();
  set_data_port();
  #set_data_pool();
  set_data_proc_usage();
  set_data_raid_group();
  `raidcom -logout -I1`;
  #print Dumper \%performance_data;
  #print Dumper \%section_header;
  write_data();

alarm(0);
};

if ($@){
  if ($@ =~ /died in SIG ALRM/){
    my $act_time = localtime();
    error_die(" script vspgperf.pl timed out after : $timeout seconds");
  }
}


### end main function ###
