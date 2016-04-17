#!/usr/bin/perl
use strict;
use warnings;
use Time::Local;
use File::Basename;
use Data::Dumper;

my $STORAGE_NAME = $ENV{STORAGE_NAME};
my $BASEDIR = $ENV{INPUTDIR};
my $HUS_CLIDIR = $ENV{HUS_CLIDIR};
my $HUS_OUTFILE = $ENV{HUS_OUTFILE};
my $bindir = $ENV{BINDIR};
my $webdir = $ENV{WEBDIR};
my $health_status_html =  "$webdir/$STORAGE_NAME/health_status.html";
my $inputdir = $ENV{INPUTDIR};
my $wrkdir = "$BASEDIR/data/$STORAGE_NAME";
my $configuration = "$wrkdir/IOSTATS";

my $sample = 300;
my $timeout = $sample * 3;

#unlink "performance.txt" or die "Unable to unlink performance.txt: $!";
#my $STORAGE_NAME = "HUS110_TEST";
#my $HUS_OUTFILE = "/home/stor2rrd/stor2rrd/data/HUS110/hus_conf/performance.txt";
#my $bindir = "/home/stor2rrd/stor2rrd/data/HUS110/hus_conf";
#my $wrkdir = "/home/stor2rrd/stor2rrd/data/HUS110/hus_conf";
#my $webdir = "/home/stor2rrd/stor2rrd/www";
#my $health_status_html =  "$webdir/HUS110_TEST/health_status.html";
#my $inputdir = "/home/stor2rrd/stor2rrd/";
#my $configuration = "$wrkdir/IOSTATS";

my $interval_start;
my $interval_end;
my $interval_lenght;
my $header;
my $header_old;
my %performace_data;
my %pool_luns;
my %rg_luns;
my $unix_times = 1449615600; ### for testing ###
my @dp_pool_all;
my @lu_all;
my @rg_all;
### file to array ###
#my $file = "pfm00000.txt";

#my $wrkdir = $wrkdir;
#my $wrkdir = "$BASEDIR/data/$STORAGE_NAME";
#my $perform_path = "$wrkdir/perform";

eval{
  #Set alarm
  my $act_time = localtime();
  my $act_directory = $act_time;
  local $SIG{ALRM} = sub { die "$act_time: died in SIG ALRM"; };
  alarm($timeout);


#my $file = get_first_perf();
#open( FH, "< $file" ) || error_die( "Cannot read $file: $!" . __FILE__ . ":" . __LINE__ ) && exit 0;
#my @file_all = <FH>;
#close(FH);


#my $file_dp = create_config_dp();
#if ($file_dp eq 0){my @dp_pool_all = ""}
#else{
#  open( FH, "< $file_dp" ) || error_die( "Cannot read $file_dp: $!" . __FILE__ . ":" . __LINE__ ) && exit 0;
#  my @dp_pool_all = <FH>;
#  close(FH);
#}

#my $file_lu = create_config_lu();
#open( FH, "< $file_lu" ) || error_die( "Cannot read $file_lu: $!" . __FILE__ . ":" . __LINE__ ) && exit 0;
#my @lu_all = <FH>;
#close(FH);

#my $file_hw = create_config_hw();
#open( FH, "< $file_hw" ) || error_die( "Cannot read $file_hw: $!" . __FILE__ . ":" . __LINE__ ) && exit 0;
#my @hw_all = <FH>;
#close(FH);

#my $file_volume = create_config_volume();
#open( FH, "< $file_volume" ) || error_die( "Cannot read $file_volume: $!" . __FILE__ . ":" . __LINE__ ) && exit 0;
#my @volume_all = <FH>;
#close(FH);

#my $file_rg = create_config_rg();
#open( FH, "< $file_rg" ) || error_die( "Cannot read $file_rg: $!" . __FILE__ . ":" . __LINE__ ) && exit 0;
#my @rg_all = <FH>;
#close(FH);

my @entry_time = split(" ",$act_directory);
(undef, my $active_minute, undef) =  split(":",$entry_time[3]);
#print "$active_minute\n";
my $config_directory = "$configuration/$active_minute";

data_structure();


### run husconf.pl ###
#my $last_rec = "$wrkdir/config-HOST1.txt";
#if (-f $last_rec){
#  my $now_time = time();
#  my @stat = stat $last_rec;
#  my $time = $stat[9];
#  if ($now_time - $time >= 3600 ){
#    system "perl $bindir/husconf.pl";
#  }
#}
#else{
#  system "perl $bindir/husconf.pl";
#}

if ($active_minute eq "00"){
  system "perl $bindir/husconf.pl";

}

my $file = get_first_perf();
open( FH, "< $file" ) || error_die( "Cannot read $file: $!" . __FILE__ . ":" . __LINE__ ) && exit 0;
my @file_all = <FH>;
close(FH);


my $file_dp = create_config_dp();
if ($file_dp eq 0){ @dp_pool_all = "";}
else{
  open( FH, "< $file_dp" ) || error_die( "Cannot read $file_dp: $!" . __FILE__ . ":" . __LINE__ ) && exit 0;
  @dp_pool_all = <FH>;
  close(FH);
}

my $file_lu = create_config_lu();
if ($file_lu eq 0){@lu_all = "";}
else{
  open( FH, "< $file_lu" ) || error_die( "Cannot read $file_lu: $!" . __FILE__ . ":" . __LINE__ ) && exit 0;
  @lu_all = <FH>;
  close(FH);
}

my $file_hw = create_config_hw();
open( FH, "< $file_hw" ) || error_die( "Cannot read $file_hw: $!" . __FILE__ . ":" . __LINE__ ) && exit 0;
my @hw_all = <FH>;
close(FH);

my $file_volume = create_config_volume();
open( FH, "< $file_volume" ) || error_die( "Cannot read $file_volume: $!" . __FILE__ . ":" . __LINE__ ) && exit 0;
my @volume_all = <FH>;
close(FH);

my $file_rg = create_config_rg();
if ($file_rg eq 0){
}
else{
  open( FH, "< $file_rg" ) || error_die( "Cannot read $file_rg: $!" . __FILE__ . ":" . __LINE__ ) && exit 0;
  @rg_all = <FH>;
}

### interval start, end, lenght###
my ($line) = grep {/SN:/} @file_all;
if (defined $line){
  chomp $line;
  my @start = split(" ",$line);
  my $start_date = $start[0];
  my $start_time = $start[1];
  $start_date =~ s/\//:/g;
  my ($year,$mon,$mday) = split(/:/, $start_date);
  my ($hour,$min,$sec) = split(/:/,$start_time);
  my $timestamp_start = timelocal($sec,$min,$hour,$mday,$mon-1,$year);
  #print $time . "\n";

  my $end_date = $start[3];
  my $end_time = $start[4];
  $end_date =~ s/\//:/g;
  ($year,$mon,$mday) = split(/:/, $end_date);
  ($hour,$min,$sec) = split(/:/,$end_time);
  my $timestamp_end = timelocal($sec,$min,$hour,$mday,$mon-1,$year);
  my $lenght = $timestamp_end - $timestamp_start;

  $interval_start = "Interval Start:   $start_date" . "T". "$start_time\n";
  $interval_end =   "Interval End:     $end_date" . "T" . "$end_time\n";
  $interval_lenght = "Interval Length:  $lenght seconds\n";
  #print "$interval_start\n";
  #print "$interval_end\n";
  #print "$interval_lenght\n";
}
my @pool_id;
my @drive_id;
my @rg_id;
my $title;
my %section;
my %hw_section;
my @column;
my @id_row;
my $index = 0;
my $jump = 0;
my $once = 0;
my $first_delimiter = 1;
my $check = 0;
my $count_column = 0;
my $active = 0;
my $count_line = 0;
my $pom = 0;
my @values;
#my %performace_data;
my $header_select;
my $output = get_name_perf_file();
foreach my $line (@file_all){
  $count_line++;
  chomp $line;
  #print $line . "\n";


### PORT LEVELS STATISTICS ###
  if ($line =~ /Port Information/){
    $title = "Port Level Statistics\n";
    $active = 1;
    $once = 0;
    $index = 0;
    $jump = 0;
    $header = "CTL,ID,IO Rate(IOPS),Read Rate(IOPS),Write Rate(IOPS),Read Hit(%),Write Hit(%),Trans. Rate(MB/S),Read Trans. Rate(MB/S),Write Trans. Rate(MB/S),Read CMD Count,Write CMD Count,Read CMD Hit Count,Write CMD Hit Count,Read Trans. Size(kB/s),Write Trans. Size(kB/s),CTL CMD IO Rate(IOPS),CTL CMD Trans. Rate(KB/S),CTL CMD Count,CTL CMD Trans. Size(KB),CTL CMD Time(microsec.),CTL CMD Max Time(microsec.),Data CMD IO Rate(IOPS),Data CMD Trans. Rate(MB/S),Data CMD Count,Data CMD Trans. Size(MB),Data CMD Time(microsec.),Data CMD Max Time(microsec.),Timeout Error Count,Random IO Rate(IOPS),Random Read Rate(IOPS),Random Write Rate(IOPS),Random Trans. Rate(MB/S),Random Read Trans. Rate(MB/S),Random Write Trans. Rate(MB/S),Random Read CMD Count,Random Write CMD Count,Random Read Trans. Size(MB),Random Write Trans. Size(MB),Sequential IO Rate(IOPS),Sequential Read Rate(IOPS),Sequential Write Rate(IOPS),Sequential Trans. Rate(MB/S),Sequential Read Trans. Rate(MB/S),Sequential Write Trans. Rate(MB/S),Sequential Read CMD Count,Sequential Write CMD Count,Sequential Read Trans. Size(MB),Sequential Write Trans. Size(MB),XCOPY Rate(IOPS),XCOPY Read Rate(IOPS),XCOPY Write Rate(IOPS),XCOPY Read Trans. Rate(MB/S),XCOPY Write Trans. Rate(MB/S),XCOPY Time(microsec.),XCOPY Max Time(microsec.)\n";
    #$header = "ID,IO Rate(IOPS),Read Rate(IOPS),Write Rate(IOPS),Read Hit(%),Write Hit(%),Read Trans. Size(MB),Write Trans. Size(MB)\n";
    @column = split(",",$header);
    $count_column = scalar @column;
    $section{"$title"} = "ID,IO Rate(IOPS),Read Rate(IOPS),Write Rate(IOPS),Read Hit(%),Write Hit(%),Read Trans. Size(kB/s),Write Trans. Size(kB/s)\n";
    next;
  }


  if ($line =~ /RG Information/){
    $title = "Raid Group Level Statistics\n";
    $active = 2;
    $once = 0;
    $index = 0;
    $jump = 0;
    $header = "CTL,ID,IO Rate(IOPS),Read Rate(IOPS),Write Rate(IOPS),Read Hit(%),Write Hit(%),Trans. Rate(MB/S),Read Trans. Rate(MB/S),Write Trans. Rate(MB/S),Read CMD Count,Write CMD Count,Read CMD Hit Count,Write CMD Hit Count,Read Trans. Size(kB/s),Write Trans. Size(kB/s),Random IO Rate(IOPS),Random Read Rate(IOPS),Random Write Rate(IOPS),Random Trans. Rate(MB/S),Random Read Trans. Rate(MB/S),Random Write Trans. Rate(MB/S),Random Read CMD Count,Random Write CMD Count,Random Read Trans. Size(MB),Random Write Trans. Size(MB),Sequential IO Rate(IOPS),Sequential Read Rate(IOPS),Sequential Write Rate(IOPS),Sequential Trans. Rate(MB/S),Sequential Read Trans. Rate(MB/S),Sequential Write Trans. Rate(MB/S),Sequential Read CMD Count,Sequential Write CMD Count,Sequential Read Trans. Size(MB),Sequential Write Trans. Size(MB),XCOPY Rate(IOPS),XCOPY Read Rate(IOPS),XCOPY Write Rate(IOPS),XCOPY Read Trans. Rate(MB/S),XCOPY Write Trans. Rate(MB/S),XCOPY Time(microsec.),XCOPY Max Time(microsec.)\n";
    @column = split(",",$header);
    $count_column = scalar @column;
    $section{"$title"} = "ID,IO Rate(IOPS),Read Rate(IOPS),Write Rate(IOPS),Read Trans. Size(kB/s),Write Trans. Size(kB/s),Total size(TB),Used size(TB),Read response time,Write response time\n";
    #$section{"$title"} = "$header";
    next;
  }

  if ($line =~ /DP Pool Information/){
    $title = "Pool Level Statistics\n";
    $active = 3;
    $once = 0;
    $index = 0;
    $jump = 0;
    #$header = "ID,IO Rate(IOPS),Read Rate(IOPS),Write Rate(IOPS),Read Trans. Size(MB),Write Trans. Size(MB)\n";
    $header = "CTL,ID,IO Rate(IOPS),Read Rate(IOPS),Write Rate(IOPS),Read Hit(%),Write Hit(%),Trans. Rate(MB/S),Read Trans. Rate(MB/S),Write Trans. Rate(MB/S),Read CMD Count,Write CMD Count,Read CMD Hit Count,Write CMD Hit Count,Read Trans. Size(kB/s),Write Trans. Size(kB/s),XCOPY Rate(IOPS),XCOPY Read Rate(IOPS),XCOPY Write Rate(IOPS),XCOPY Read Trans. Rate(MB/S),XCOPY Write Trans. Rate(MB/S),XCOPY Time(microsec.),XCOPY Max Time(microsec.)\n";
    @column = split(",",$header);
    $count_column = scalar @column;
    $section{"$title"} = "ID,IO Rate(IOPS),Read Rate(IOPS),Write Rate(IOPS),Read Trans. Size(kB/s),Write Trans. Size(kB/s),Total size(TB),Used size(TB),Read response time,Write response time\n";
    next;
  }

  if ($line =~ /LU Information/){
    $title = "Volume Level Statistics\n";
    $active = 4;
    $once = 0;
    $index = 0;
    $jump = 0;
    $header = "Controller,ID,IO Rate(IOPS),Read Rate(IOPS),Write Rate(IOPS),Read Hit(%),Write Hit(%),Trans. Rate(MB/S),Read Trans. Rate(MB/S),Write Trans. Rate(MB/S),Read CMD Count,Write CMD Count,Read CMD Hit Count,Write CMD Hit Count,Read Trans. Size(kB/s),Write Trans. Size(kB/s),Read CMD Hit Count2,Read CMD Hit Time(microsec.),Read CMD Hit Max Time(microsec.),Write CMD Hit Count2,Write CMD Hit Time(microsec.),Write CMD Hit Max Time(microsec.),Read CMD Miss Count,Read CMD Miss Time(microsec.),Read CMD Miss Max Time(microsec.),Write CMD Miss Count,Write CMD Miss Time(microsec.),Write CMD Miss Max Time(microsec.),Read CMD Job Count,Read CMD Job Time(microsec.),Read CMD Job Max Time(microsec.),Write CMD Job Count,Write CMD Job Time(microsec.),Write CMD Job Max Time(microsec.),Read Hit Delay CMD Count(<300ms),Read Hit Delay CMD Count(300-499ms),Read Hit Delay CMD Count(500-999ms),Read Hit Delay CMD Count(1000ms-),Write Hit Delay CMD Count(<300ms),Write Hit Delay CMD Count(300-499ms),Write Hit Delay CMD Count(500-999ms),Write Hit Delay CMD Count(1000ms-),Read Miss Delay CMD Count(<300ms),Read Miss Delay CMD Count(300-499ms),Read Miss Delay CMD Count(500-999ms),Read Miss Delay CMD Count(1000ms-),Write Miss Delay CMD Count(<300ms),Write Miss Delay CMD Count(300-499ms),Write Miss Delay CMD Count(500-999ms),Write Miss Delay CMD Count(1000ms-),Read Job Delay CMD Count(<300ms),Read Job Delay CMD Count(300-499ms),Read Job Delay CMD Count(500-999ms),Read Job Delay CMD Count(1000ms-),Write Job Delay CMD Count(<300ms),Write Job Delay CMD Count(300-499ms),Write Job Delay CMD Count(500-999ms),Write Job Delay CMD Count(1000ms-),Tag Count,Average Tag Count,Data CMD IO Rate(IOPS),Data CMD Trans. Rate(MB/S),Data CMD Count,Data CMD Trans. Size(MB),Data CMD Time(microsec.),Data CMD Max Time(microsec.),Random IO Rate(IOPS),Random Read Rate(IOPS),Random Write Rate(IOPS),Random Trans. Rate(MB/S),Random Read Trans. Rate(MB/S),Random Write Trans. Rate(MB/S),Random Read CMD Count,Random Write CMD Count,Random Read Trans. Size(MB),Random Write Trans. Size(MB),Sequential IO Rate(IOPS),Sequential Read Rate(IOPS),Sequential Write Rate(IOPS),Sequential Trans. Rate(MB/S),Sequential Read Trans. Rate(MB/S),Sequential Write Trans. Rate(MB/S),Sequential Read CMD Count,Sequential Write CMD Count,Sequential Read Trans. Size(MB),Sequential Write Trans. Size(MB),XCOPY Rate(IOPS),XCOPY Read Rate(IOPS),XCOPY Write Rate(IOPS),XCOPY Read Trans. Rate(MB/S),XCOPY Write Trans. Rate(MB/S),XCOPY Time(microsec.),XCOPY Max Time(microsec.),Total Tag Count,Read Tag Count,Write Tag Count,Total Average Tag Count,Read Average Tag Count,Write Average Tag Count\n";
    @column = split(",",$header);
    $count_column = scalar @column;
    $section{"$title"} = "ID,Controller,IO Rate(IOPS),Read Rate(IOPS),Write Rate(IOPS),Read Hit(%),Write Hit(%),Read Trans. Size(kB/s),Write Trans. Size(kB/s),Read response time,Write response time,Capacity(MB),Used(MB)\n";
    next;
  }

  if ($line =~ /Cache Information/){    # cache zatím nedělám nekonzistetní řádky typu partion je jen někde....
    $title = "Node Cache Level Statistics\n";
    $active = 5;
    $once = 0;
    $index = 0;
    $jump = 0;
    $header = "Controller,Partition,Write Pending Rate(%),Clean Queue Usage Rate(%),Middle Queue Usage Rate(%),Physical Queue Usage Rate(%)";
    $section{"$title"} = "$header";
    @column = split(",",$header);
    $count_column = scalar @column;
    next;
  }

  if ($line =~ /Processor Information/){
    $title = "CPU-CORE Level Statistics\n";
    $active = 6;
    $once = 0;
    $index = 0;
    $jump = 0;
    $header = "Controller,Core,Usage(%),Host-Cache Bus Usage Rate(%),Drive-Cache Bus Usage Rate(%),Processor-Cache Bus Usage Rate(%),Cache(DRR) Bus Usage Rate(%),Dual Bus Usage Rate(%),Total Bus Usage Rate(%)";
    @column = split(",",$header);
    $count_column = scalar @column;
    $section{"$title"} = "Controller,Core,Usage(%)";
    next;
  }


  if ($line =~ /Drive Information/){
    $title = "Drive Level Statistics\n";
    $active = 7;
    $once = 0;
    $index = 0;
    $jump = 0;
    $header = "Controller,Unit,ID,IO Rate(IOPS),Read Rate(IOPS),Write Rate(IOPS),Trans. Rate(MB/S),Read Trans. Rate(MB/S),Write Trans. Rate(MB/S),Online Verify Rate(IOPS),Read CMD Count,Write CMD Count,Read Trans. Size(kB/s),Write Trans. Size(kB/s),Online Verify CMD Count";
    @column = split(",",$header);
    $count_column = scalar @column;
    $section{"$title"} = "ID,Controller,IO Rate(IOPS),Read Rate(IOPS),Write Rate(IOPS),Read Trans. Size(kB/s),Write Trans. Size(kB/s),Operating Rate(%)";
    next;
  }

  if ($line =~ /Drive Operate Information/){
    $title = "Drive Operate Level Statistics\n";
    $once = 0;
    $index = 0;
    $jump = 0;
    $header = "Controller,Unit,ID,Operating Rate(%),Tag Count,Unload Time(min.),Average Tag Count";
    @column = split(",",$header);
    $count_column = scalar @column;
    $active = 8;
    $section{"$title"} = "Controller,Unit,ID,Operating Rate(%)";
    next;
  }

  if ($line =~ /Backend Information/){
    $title = "Backend Level Statistics\n";
    $once = 0;
    $index = 0;
    $jump = 0;
    $header = "Controller,Path,IO Rate(IOPS),Read Rate(IOPS),Write Rate(IOPS),Trans. Rate(MB/S),Read Trans. Rate(MB/S),Write Trans. Rate(MB/S),Online Verify Rate(IOPS),Read CMD Count,Write CMD Count,Read Trans. Size(kB/s),Write Trans. Size(kB/s),Online Verify CMD Count";
    @column = split(",",$header);
    $count_column = scalar @column;
    $active = 9;
    $section{"$title"} = "Controller,Read Rate(IOPS),Write Rate(IOPS),Read Trans. Size(kB/s),Write Trans. Size(kB/s),Online Verify Rate(IOPS)\n";
    $header_select = $section{"$title"};
    #$section{"$title"} = "$header";
    next;
  }

  if ($line =~ /Management Area Information : DP Pool/){
    $title = "Management Area : DP Pool Level Statistics\n";
    $once = 0;
    $index = 0;
    $jump = 0;
    $header = "CTL,Core,DP Pool,Cache Hit Rate(%),Access Count";
    @column = split(",",$header);
    $count_column = scalar @column;
    $active = 10;
    #$section{"$title"} = "$header";
    next;
  }
  if ($line =~ /Management Area Information : RAID Group/){
    $active = 11;
    next;
  }

  if ($active == 1){
    if ($line =~ /CTL  Port/){
      #print $line . "\n";
      $once++;
      $index = $jump + $index;
      $pom = $count_line;
      next;
    }
    if ($count_line - $pom == 1){
      $pom = $count_line;
      my @array_line = split(" ",$line);
      my $size = scalar @array_line;
      if ($once == 1){
        for (my $i = 0; $i<$size; $i++){
          $jump = $size;
          $array_line[$i] =~ s/^\s+|\s+$//g;
          $column[$index] =~ s/^\s+|\s+$//g;
          if ($column[$index] eq "ID"){
            #print "$array_line[0]$array_line[1]\n";
            $performace_data{"$title"}{"$array_line[0]$array_line[1]"}{$column[$index]} = "$array_line[0]$array_line[1]";
            $index++;
            next;
          }
          $performace_data{"$title"}{"$array_line[0]$array_line[1]"}{$column[$index]} = $array_line[$i];
          $index++;
        }
      }
      else{
        for (my $i = 2; $i<$size; $i++){
          $jump = $size-2;
          $array_line[$i] =~ s/^\s+|\s+$//g;
          $column[$index] =~ s/^\s+|\s+$//g;
          $performace_data{"$title"}{"$array_line[0]$array_line[1]"}{$column[$index]} = $array_line[$i];
          $index++;
        }
      }
      $index = $index - $jump;
    }

  }

  if ($active == 2){
    if ($line =~ /CTL\s+RG/){
      #print $line . "\n";
      $once++;
      $index = $jump + $index;
      $pom = $count_line;
      next;
    }
    if ($count_line - $pom == 1){
      $pom = $count_line;
      my @array_line = split(" ",$line);
      #print @array_line;
      my $id = "";
      my $size = scalar @array_line;
      if ($once == 1){
        for (my $i = 0; $i<$size; $i++){
          $jump = $size;
          $array_line[$i] =~ s/^\s+|\s+$//g;
          $column[$index] =~ s/^\s+|\s+$//g;
          $performace_data{"$title"}{"$array_line[1]$array_line[0]"}{$column[$index]} = $array_line[$i];
          $index++;
          if ($i == 0){
            $id = "$array_line[1]";
            my ($rg_ids) = grep {/$id/}  @rg_id;
            if (!defined $rg_ids){
              #print $id . "\n";
              push(@rg_id,"$id");
            }
          }

        }
      }
      else{
        for (my $i = 2; $i<$size; $i++){
          $jump = $size-2;
          $array_line[$i] =~ s/^\s+|\s+$//g;
          $column[$index] =~ s/^\s+|\s+$//g;
          $performace_data{"$title"}{"$array_line[1]$array_line[0]"}{$column[$index]} = $array_line[$i];
          $index++;
        }
      }
      $index = $index - $jump;
    }
  }

   if ($active == 3){
    if ($line =~ /DP\s+Pool/){
      #print $line . "\n";
      $once++;
      $index = $jump + $index;
      $pom = $count_line;
      next;
    }
    if ($count_line - $pom == 1){
      $pom = $count_line;
      #print "$line\n";
      my $id = "";
      my @array_line = split(" ",$line);
      #print @array_line;
      my $size = scalar @array_line;
      #print $once . "\n";
      if ($once == 1){
        for (my $i = 0; $i<$size; $i++){
          $jump = $size;
          $array_line[$i] =~ s/^\s+|\s+$//g;
          $column[$index] =~ s/^\s+|\s+$//g;
          $performace_data{"$title"}{"$array_line[1]$array_line[0]"}{$column[$index]} = $array_line[$i];
          $index++;
          if ($i == 0){
            $id = "$array_line[1]";
            my ($pool_ids) = grep {/$id/}  @pool_id;
            if (!defined $pool_ids){
              #print $id . "\n";
              push(@pool_id,"$id");
            }
          }
        }
      }
      else{
        for (my $i = 2; $i<$size; $i++){
          $jump = $size-2;
          $array_line[$i] =~ s/^\s+|\s+$//g;
          $column[$index] =~ s/^\s+|\s+$//g;
          $performace_data{"$title"}{"$array_line[1]$array_line[0]"}{$column[$index]} = $array_line[$i];
          $index++;
        }
      }
      $index = $index - $jump;
    }
  }
  if ($active == 4){
    if ($line =~ /CTL\s+LU/){
      #print $line . "\n";
      $once++;
      $index = $jump + $index;
      $pom = $count_line;
      next;
    }
    if ($count_line - $pom == 1){
      $pom = $count_line;
      my @array_line = split(" ",$line);
      #print @array_line;
      my $size = scalar @array_line;
      if ($once == 1){
        for (my $i = 0; $i<$size; $i++){
          $jump = $size;
          $array_line[$i] =~ s/^\s+|\s+$//g;
          $column[$index] =~ s/^\s+|\s+$//g;
          if ($column[$index] eq "ID" || $column[$index] eq "Controller" || $column[$index] eq "IO Rate(IOPS)" || $column[$index] eq "Read Rate(IOPS)" || $column[$index] eq "Write Rate(IOPS)" || $column[$index] eq "Read Hit(%)" || $column[$index] eq "Write Hit(%)" || $column[$index] eq "Read Trans. Size(kB/s)" || $column[$index] eq "Write Trans. Size(kB/s)" || $column[$index] eq "Read CMD Hit Count2" || $column[$index] eq "Read CMD Hit Time(microsec.)" || $column[$index] eq "Read CMD Miss Count" || $column[$index] eq "Read CMD Miss Time(microsec.)" || $column[$index] eq "Read CMD Job Count" || $column[$index] eq "Read CMD Job Time(microsec.)" || $column[$index] eq "Write CMD Hit Count2" || $column[$index] eq "Write CMD Hit Time(microsec.)" || $column[$index] eq "Write CMD Miss Count" || $column[$index] eq "Write CMD Miss Time(microsec.)" || $column[$index] eq "Write CMD Job Count" || $column[$index] eq "Write CMD Job Time(microsec.)") {
            $performace_data{"$title"}{"$array_line[1]$array_line[0]"}{$column[$index]} = $array_line[$i];
            $index++;
          }
          else{
            $index++;
          }
        }
      }
      else{
        for (my $i = 2; $i<$size; $i++){
          $jump = $size-2;
          $array_line[$i] =~ s/^\s+|\s+$//g;
          $column[$index] =~ s/^\s+|\s+$//g;
          if ($column[$index] eq "ID" || $column[$index] eq "CTL" || $column[$index] eq "IO Rate(IOPS)" || $column[$index] eq "Read Rate(IOPS)" || $column[$index] eq "Write Rate(IOPS)" || $column[$index] eq "Read Hit(%)" || $column[$index] eq "Write Hit(%)" || $column[$index] eq "Read Trans. Size(kB/s)" || $column[$index] eq "Write Trans. Size(kB/s)" || $column[$index] eq "Read CMD Hit Count2" || $column[$index] eq "Read CMD Hit Time(microsec.)" || $column[$index] eq "Read CMD Miss Count" || $column[$index] eq "Read CMD Miss Time(microsec.)" ||  $column[$index] eq "Read CMD Job Count" || $column[$index] eq "Read CMD Job Time(microsec.)" || $column[$index] eq "Write CMD Hit Count2" || $column[$index] eq "Write CMD Hit Time(microsec.)" || $column[$index] eq "Write CMD Miss Count" || $column[$index] eq "Write CMD Miss Time(microsec.)" || $column[$index] eq "Write CMD Job Count" || $column[$index] eq "Write CMD Job Time(microsec.)"){
            $performace_data{"$title"}{"$array_line[1]$array_line[0]"}{$column[$index]} = $array_line[$i];
            $index++;
          }
          else{
            $index++;
          }
        }
      }
      $index = $index - $jump;
    }
  }

  if ($active == 5){
     if ($line =~ /Partition/){
      #print $line . "\n";
      $once++;
      $index = $jump + $index;
      $pom = $count_line;
      next;
    }
    if ($count_line - $pom == 1){
      $pom = $count_line;
      #print "$line\n";
      my $id = "";
      my @array_line = split(" ",$line);
      #print @array_line;
      my $size = scalar @array_line;
      #print $once . "\n";
      if ($once == 1){
        for (my $i = 0; $i<$size; $i++){
          $jump = $size;
          $array_line[$i] =~ s/^\s+|\s+$//g;
          $column[$index] =~ s/^\s+|\s+$//g;
          $performace_data{"$title"}{"$array_line[0]$array_line[1]"}{$column[$index]} = $array_line[$i];
          $index++;
        }
      }
      else{
        for (my $i = 2; $i<$size; $i++){
          $jump = $size-2;
          $array_line[$i] =~ s/^\s+|\s+$//g;
          $column[$index] =~ s/^\s+|\s+$//g;
          $performace_data{"$title"}{"$array_line[0]$array_line[1]"}{$column[$index]} = $array_line[$i];
          $index++;
        }
      }
      $index = $index - $jump;
    }
  }

  if ($active == 6){
    if ($line =~ /CTL/){
      #print $line . "\n";
      $once++;
      $index = $jump + $index;
      $pom = $count_line;
      next;
    }
    if ($count_line - $pom == 1){
      $pom = $count_line;
      my @array_line = split(" ",$line);
      #print @array_line;
      my $size = scalar @array_line;
      if ($once == 1){
        for (my $i = 0; $i<$size; $i++){
          $jump = $size;
          $array_line[$i] =~ s/^\s+|\s+$//g;
          $column[$index] =~ s/^\s+|\s+$//g;
          $performace_data{"$title"}{"$array_line[0]"}{$column[$index]} = $array_line[$i];
          $index++;
        }
      }
      else{
        for (my $i = 1; $i<$size; $i++){
          $jump = $size-1;
          $array_line[$i] =~ s/^\s+|\s+$//g;
          $column[$index] =~ s/^\s+|\s+$//g;
          $performace_data{"$title"}{"$array_line[0]"}{$column[$index]} = $array_line[$i];
          $index++;
        }
      }
      $index = $index - $jump;
    }
  }
  if ($active == 7){
    if ($line =~ /CTL\sUnit\sHDU/){
      #print $line . "\n";
      $once++;
      $index = $jump + $index;
      $pom = $count_line;
      next;
    }
    if ($count_line - $pom == 1){
      $pom = $count_line;
      my @array_line = split(" ",$line);
      #print @array_line;
      my $size = scalar @array_line;
      if ($once == 1){
        for (my $i = 0; $i<$size; $i++){
          $jump = $size;
          $array_line[$i] =~ s/^\s+|\s+$//g;
          $column[$index] =~ s/^\s+|\s+$//g;
          $performace_data{"$title"}{"$array_line[1],$array_line[2],$array_line[0]"}{$column[$index]} = $array_line[$i];
          $index++;
          if ($i == 0){
            my $id = "$array_line[1]-$array_line[2]";
            my ($drive_ids) = grep {/$id/}  @drive_id;
            if (!defined $drive_ids){
              #print $id . "\n";
              push(@drive_id,"$id");
            }
          }
        }
      }
      else{
        for (my $i = 3; $i<$size; $i++){
          $jump = $size-3;
          $array_line[$i] =~ s/^\s+|\s+$//g;
          $column[$index] =~ s/^\s+|\s+$//g;
          $performace_data{"$title"}{"$array_line[1],$array_line[2],$array_line[0]"}{$column[$index]} = $array_line[$i];
          $index++;
        }
      }
      $index = $index - $jump;
    }
  }

  if ($active == 8){
    if ($line =~ /CTL\sUnit\sHDU/){
      #print $line . "\n";
      $once++;
      $index = $jump + $index;
      $pom = $count_line;
      next;
    }
    if ($count_line - $pom == 1){
      $pom = $count_line;
      my @array_line = split(" ",$line);
      #print @array_line;
      my $size = scalar @array_line;
      if ($once == 1){
        for (my $i = 0; $i<$size; $i++){
          $jump = $size;
          $array_line[$i] =~ s/^\s+|\s+$//g;
          $column[$index] =~ s/^\s+|\s+$//g;
          $performace_data{"$title"}{"$array_line[1],$array_line[2],$array_line[0]"}{$column[$index]} = $array_line[$i];
          $index++;
        }
      }
      else{
        for (my $i = 3; $i<$size; $i++){
          $jump = $size-3;
          $array_line[$i] =~ s/^\s+|\s+$//g;
          $column[$index] =~ s/^\s+|\s+$//g;
          $performace_data{"$title"}{"$array_line[1],$array_line[2],$array_line[0]"}{$column[$index]} = $array_line[$i];
          $index++;
        }
      }
      $index = $index - $jump;
    }
  }
  if ($active == 9){
    if ($line =~ /CTL\s+Path/){
      #print $line . "\n";
      $once++;
      $index = $jump + $index;
      $pom = $count_line;
      next;
    }
    if ($count_line - $pom == 1){
      $pom = $count_line;
      my @array_line = split(" ",$line);
      #print "@array_line\n";
      my $size = scalar @array_line;
      if ($once == 1){
        for (my $i = 0; $i<$size; $i++){
          $jump = $size;
          $array_line[$i] =~ s/^\s+|\s+$//g;
          $column[$index] =~ s/^\s+|\s+$//g;
          $performace_data{"$title"}{"$array_line[0],$array_line[1]"}{$column[$index]} = $array_line[$i];
          $index++;
        }
      }
      else{
        for (my $i = 2; $i<$size; $i++){
          $jump = $size-2;
          $array_line[$i] =~ s/^\s+|\s+$//g;
          $column[$index] =~ s/^\s+|\s+$//g;
          $performace_data{"$title"}{"$array_line[0],$array_line[1]"}{$column[$index]} = $array_line[$i];
          $index++;
        }
      }
      $index = $index - $jump;
    }
  }
  if ($active == 10){
    if ($line =~ /CTL/){
      #print $line . "\n";
      $once++;
    $index = $jump + $index;
      $pom = $count_line;
      next;
    }
    if ($count_line - $pom == 1){
      $pom = $count_line;
      my @array_line = split(" ",$line);
      #print @array_line;
      my $size = scalar @array_line;
      if ($once == 1){
        for (my $i = 0; $i<$size; $i++){
          $jump = $size;
          $array_line[$i] =~ s/^\s+|\s+$//g;
          $column[$index] =~ s/^\s+|\s+$//g;
          #$performace_data{"$title"}{"$array_line[0]"}{$column[$index]} = $array_line[$i];
          $index++;
        }
      }
      else{
        for (my $i = 1; $i<$size; $i++){
          $jump = $size-1;
          $array_line[$i] =~ s/^\s+|\s+$//g;
          $column[$index] =~ s/^\s+|\s+$//g;
          #$performace_data{"$title"}{"$array_line[0]"}{$column[$index]} = $array_line[$i];
          $index++;
        }
      }
      $index = $index - $jump;
    }
  }
}

sub set_per_rg{
  my $element = "Raid Group Level Statistics\n";
  delete_element($element);
  calculate_w_r_data($element);
  #print Dumper \%performace_data;
  my $ide = 0;
  my $iorate = 0;
  my $riorate = 0;
  my $wiorate = 0;
  my $rtrans = 0;
  my $wtrans = 0;
  my $last_id = "";

   foreach my $id (sort keys %{$performace_data{$element}}){
    #print $performace_data{"Pool Level Statistics\n"}{$id}{"ID"} . "\n";
    #print "$last_id\n";
    if ($performace_data{$element}{$id}{"ID"} ne "$last_id"){
      $iorate = 0;
      $riorate = 0;
      $wiorate = 0;
      $rtrans = 0;
      $wtrans = 0;
      $last_id = $performace_data{$element}{$id}{"ID"};
    }
    #print "$iorate\n";
    foreach my $line (@rg_id){
      #print "$line\n";
      chomp $line;
      $ide = $line;
      #print "$metric\n";
      #print $performace_data{"Pool Level Statistics\n"}{$id}{"$metric"} . "\n";
      if ($performace_data{$element}{$id}{"ID"} eq "$line"){
        $iorate = $performace_data{$element}{$id}{"IO Rate(IOPS)"} + $iorate;
        #print "$iorate\n";
        $riorate = $performace_data{$element}{$id}{"Read Rate(IOPS)"} + $riorate;
        $wiorate = $performace_data{$element}{$id}{"Write Rate(IOPS)"} + $wiorate;
        $rtrans = $performace_data{$element}{$id}{"Read Trans. Size(kB/s)"} + $rtrans;
        $wtrans = $performace_data{$element}{$id}{"Write Trans. Size(kB/s)"} + $wtrans;
        delete $performace_data{$element}{$id};
        last;
      }
    }
    if (!defined $rg_luns{RG}{$ide}{ID}){
      $rg_luns{RG}{$ide}{ID} = $ide;
    }
    $performace_data{$element}{$ide}{"IO Rate(IOPS)"} = "$iorate";
    $performace_data{$element}{$ide}{"Read Rate(IOPS)"} = "$riorate";
    $performace_data{$element}{$ide}{"Write Rate(IOPS)"} = "$wiorate";
    $performace_data{$element}{$ide}{"Read Trans. Size(kB/s)"} = "$rtrans";
    $performace_data{$element}{$ide}{"Write Trans. Size(kB/s)"} = "$wtrans";
    $performace_data{$element}{$ide}{"ID"} = "$ide";
  }

  ### mapping rg luns
  my %rg_lun = get_lun_per_rg();
  foreach my $rg (keys %{$rg_luns{RG}}){
    foreach my $rgs (keys %{$rg_lun{RG}}){
      if ($rg eq $rgs){
        foreach my $lun (keys %{$rg_lun{RG}{$rgs}{LUN}}){
          $rg_luns{RG}{$rg}{LUN}{$lun}{ID} = $rg_lun{RG}{$rgs}{LUN}{$lun}{ID};
          $rg_luns{RG}{$rg}{LUN}{$lun}{CAPACITY} = $rg_lun{RG}{$rgs}{LUN}{$lun}{CAPACITY};
        }
      }
    }
  }
  
  ### rg_luns add response time volumes
  foreach my $resp (keys %{$performace_data{"Volume Level Statistics\n"}}){
    foreach my $rg (keys %{$rg_luns{RG}}){
      if ($rg eq ""){next;}  ### nothing rg;
      if (!defined $rg_luns{RG}{$rg}{LUN}){next;} ### rg has no luns
      foreach my $id_lun (keys %{$rg_luns{RG}{$rg}{LUN}}){
        if (!defined $rg_luns{RG}{$rg}{LUN}{$id_lun}{ID} ){next;}
        if ($performace_data{"Volume Level Statistics\n"}{$resp}{ID} eq $rg_luns{RG}{$rg}{LUN}{$id_lun}{ID} ){
          $rg_luns{RG}{$rg}{LUN}{$id_lun}{"Read response time"} = $performace_data{"Volume Level Statistics\n"}{$resp}{"Read response time"};
          $rg_luns{RG}{$rg}{LUN}{$id_lun}{"Write response time"} = $performace_data{"Volume Level Statistics\n"}{$resp}{"Write response time"};
          $rg_luns{RG}{$rg}{LUN}{$id_lun}{"IO Rate(IOPS)"} = $performace_data{"Volume Level Statistics\n"}{$resp}{"IO Rate(IOPS)"};
          ### total capacity for LUN ##
          $performace_data{"Volume Level Statistics\n"}{$resp}{"Capacity(MB)"} = $rg_luns{RG}{$rg}{LUN}{$id_lun}{CAPACITY};
        }
      }
    }
  }

  #print Dumper \%rg_luns;
  ### response time for rg ###
  my $response_time_r = 0;
  my $numerator_r = 0;
  my $denominator = 0;
  my $response_time_w = 0;
  my $numerator_w = 0;
  foreach my $id (keys %{$rg_luns{RG}}){
    if (!defined $rg_luns{RG}{$id}{LUN}){next;}
    #print $id . "\n";
    $numerator_w = 0;
    $numerator_r = 0;
    $denominator = 0;
    $response_time_r = 0;
    $response_time_w = 0;
    foreach my $id_lun (keys %{$rg_luns{RG}{$id}{LUN}}){
      #print "$id_lun\n";
      $numerator_w = $rg_luns{RG}{$id}{LUN}{$id_lun}{"Write response time"} * $rg_luns{RG}{$id}{LUN}{$id_lun}{"IO Rate(IOPS)"} + $numerator_w;
      $numerator_r = $rg_luns{RG}{$id}{LUN}{$id_lun}{"Read response time"} * $rg_luns{RG}{$id}{LUN}{$id_lun}{"IO Rate(IOPS)"} + $numerator_r;
      $denominator = $rg_luns{RG}{$id}{LUN}{$id_lun}{"IO Rate(IOPS)"} + $denominator;

    }
    #print "$numerator_r\n";
    #print "$denominator\n";
    if ($denominator == 0){
      $rg_luns{RG}{$id}{"Write response time"} = 0;
      $rg_luns{RG}{$id}{"Read response time"} = 0;
    }
    else{
      $response_time_r = $numerator_r / $denominator;
      $response_time_w = $numerator_w / $denominator;
      my $rounded_r = sprintf("%.3f", $response_time_r);
      my $rounded_w = sprintf("%.3f", $response_time_w);
      $rg_luns{RG}{$id}{"Write response time"} = $rounded_w;
      $rg_luns{RG}{$id}{"Read response time"} = $rounded_r;
      #print $rg_luns{RG}{$id}{"Read response time"} . "\n";
      #print Dumper \%rg_luns;
    }
  }
  #print Dumper \%rg_luns;
  ### add response time for rg to performance statistics
  foreach my $id_s (keys %{$performace_data{$element}}){
    foreach my $id (keys %{$rg_luns{RG}}){
      #print "$performace_data{$element}{$id_s}{ID} eq $pool_luns{POOL}{$id}{NAME}\n";
      if ( $performace_data{$element}{$id_s}{ID} eq $rg_luns{RG}{$id}{ID}){
        #print $rg_luns{RG}{$id}{"Write response time"};
        if (defined $rg_luns{RG}{$id}{"Write response time"}){
          $performace_data{$element}{$id_s}{"Write response time"} = $rg_luns{RG}{$id}{"Write response time"};
        }
        if (defined $rg_luns{RG}{$id}{"Read response time"}){
          $performace_data{$element}{$id_s}{"Read response time"} = $rg_luns{RG}{$id}{"Read response time"};
        }
        #$performace_data{$element}{$id_s}{"Write response time"} = $rg_luns{RG}{$id}{"Write response time"};
        #$performace_data{$element}{$id_s}{"Read response time"} = $rg_luns{RG}{$id}{"Read response time"};
        last;
      }
    }
  }
   ### add capacite for rg ###
  my %rg = get_rg_capacite();
  if (%rg eq 0 ){
    return;
  }
  foreach my $id (keys %{$performace_data{$element}}){
    foreach my $ids (keys %{$rg{RG}}){
      if ($ids eq $id ){
        if (defined $rg{RG}{$ids}{"TOTAL"}){
          $performace_data{$element}{$id}{"Total size(TB)"} = $rg{RG}{$ids}{"TOTAL"};
        }
        if (defined $rg{RG}{$ids}{"USED"}){
          $performace_data{$element}{$id}{"Used size(TB)"} = $rg{RG}{$ids}{"USED"};
        }
      }

    }
  }

  #print Dumper \%performace_data;

}

sub get_lun_per_rg{
   my $index_lun;
   my $index_rg;
   my $index_cap;
   my $index = -1;
   my $active = 0;
   my %lun_rg;
  #print "@volume_all\n";
  foreach my $line (@volume_all){
    chomp $line;
    #print "$active\n";
    #print "$line\n";
    $line =~ s/^\s+|\s+$//g;
    my @value = split(",",$line);
    foreach my $header(@value){
      chomp $header;
      $index++;
      $header =~ s/^\s+|\s+$//g;
      if ($header eq "LU"){
        $index_lun = $index;
        $active++;
      }
      if ($header =~ /RAID Group/){
        $index_rg = $index;
        $active++;
      }
      if ($header =~ /Capacity/){
        $index_cap = $index;
        $active++;
      }
      if ($active == 3){
        $active++;
        last;
      }
      #print "$line\n";
      if ($active == 4){
        #print "$value[$index_rg]\n";
        if ($value[$index_rg] eq "N/A"){last;}
        if (!defined $lun_rg{RG}{$value[$index_rg]}{ID}){
          #print "$value[$index_rg]\n";
          $lun_rg{RG}{$value[$index_rg]}{ID} = $value[$index_rg];
        }
        #print Dumper \%lun_rg;
        if (!defined $lun_rg{RG}{$value[$index_rg]}{LUN}{$value[$index_lun]}{ID} && !defined $lun_rg{RG}{$value[$index_rg]}{LUN}{$value[$index_lun]}{CAPACITY}){
          $lun_rg{RG}{$value[$index_rg]}{LUN}{$value[$index_lun]}{ID} = $value[$index_lun];
          my $capacity = $value[$index_cap];
          if ($capacity =~ /TB/){
            $capacity =~ s/TB//g;
            $capacity = $capacity * (1024*1024);
          }
           if ($capacity =~ /GB/){
            $capacity =~ s/GB//g;
            $capacity = $capacity * (1024);
          }
           if ($capacity =~ /MB/){
            $capacity =~ s/MB//g;
          }
           if ($capacity =~ /PB/){
            $capacity =~ s/PB//g;
            $capacity = $capacity * (1024*1024*1024);
          }

          $lun_rg{RG}{$value[$index_rg]}{LUN}{$value[$index_lun]}{CAPACITY} = $capacity;
          last;
        }
      }
    }

  }
  #print Dumper \%lun_rg;
  return %lun_rg;
}

sub get_rg_capacite{
  my %rg_capacite;
  my $header = 1;
  my $index_rg;
  my $index_total_cap;
  my $index_free_cap;
  my $rg_id;
  my $rg_total;
  my $rg_used;
  my $rg_free;
  my $size = scalar @rg_all;
  if ($size eq 0){
    return %rg_capacite;
  }
  foreach my $line (@rg_all){
    chomp $line;
    #print "$line\n";
    $line =~ s/^\s+|\s+$//g;
    if ($header eq 1){
      my @header = split(",",$line);
      my $index = -1;
      foreach my $element(@header){
        chomp $element;
        $index++;
        $element =~ s/^\s+|\s+$//g;
        if ($element eq "RAID Group"){
          $index_rg = $index;
          next;
        }
        if ($element eq "Total Capacity"){
          $index_total_cap = $index;
          next;
        }
        if ($element eq "Free Capacity"){
          $index_free_cap = $index;
          next;
        }
        if (defined $index_free_cap && defined $index_total_cap && defined $index_rg){
          $header = 2;
          last;
        }

      }
    }
    if ($header eq 2){
      $header = 3;
      next;
    }
    if ($header eq 3){
      my @value = split(",",$line);
      $rg_id = $value[$index_rg];
      $rg_total = $value[$index_total_cap];
      $rg_free = $value[$index_free_cap];
      if ($rg_total =~ /TB/){
        $rg_total =~ s/TB//g;
        $rg_total =~ s/^\s+|\s+$//g;
        #print "$rg_total\n";
      }
      if ($rg_total =~ /PB/){
        $rg_total =~ s/PB//g;
        $rg_total =~ s/^\s+|\s+$//g;
        $rg_total = $rg_total * 1024;
      }
      if ($rg_total =~ /GB/){
        $rg_total =~ s/GB//g;
        $rg_total =~ s/^\s+|\s+$//g;
        $rg_total = $rg_total / 1024;
      }
      if ($rg_total =~ /MB/){
        $rg_total =~ s/MB//g;
        $rg_total =~ s/^\s+|\s+$//g;
        $rg_total = $rg_total / (1024*1024);
      }
      if ($rg_free =~ /TB/){
        $rg_free =~ s/TB.*//g;
        $rg_free =~ s/^\s+|\s+$//g;
        $rg_used = $rg_total -$rg_free;
      }
      if ($rg_free =~ /PB/){
        $rg_free =~ s/PB.*//g;
        $rg_free =~ s/^\s+|\s+$//g;
        $rg_free = $rg_free * 1024;
        $rg_used = $rg_total -$rg_free;
      }
      if ($rg_free =~ /GB/){
        $rg_free =~ s/GB.*//g;
        $rg_free =~ s/^\s+|\s+$//g;
        $rg_free = $rg_free / 1024;
        $rg_used = $rg_total - $rg_free;
      }
      if ($rg_free =~ /MB/){
        $rg_free =~ s/MB.*//g;
        $rg_free =~ s/^\s+|\s+$//g;
        $rg_free = $rg_free / (1024*1024);
        $rg_used = $rg_total - $rg_free;
      }
      if ( index($rg_free,"(") > -1){
        $rg_free = 0;
        $rg_used = $rg_total;
      }
    }
    $rg_capacite{RG}{$rg_id}{NAME} = $rg_id;
    $rg_capacite{RG}{$rg_id}{TOTAL} = $rg_total;
    $rg_capacite{RG}{$rg_id}{USED} = $rg_used;
  }
  #print Dumper \%rg_capacite;
  return %rg_capacite;
}


sub set_capacity_lun{

  foreach my $line (@lu_all){
    chomp $line;
    if ($line eq ""){ $active = 0; next;}
    $line =~ s/^\s+|\s+$//g;
    if ($line =~ /LUN/){
      $active = 1;
      #print "$line\n\n";
      next;
    }
    if ($active == 1){
      my @value = split (" ",$line);
      #print "$value[1]\n"; ### lun id
      $value[0] =~ s/^\s+|\s+$//g;
      my $id = $value[0];
      #my $more_id = 0;
      my $index = -1;
      my $tb = "";
      my $mb = "";
      my $gb = "";
      my $pb = "";
      my $used_gb = "";
      my $used_tb = "";
      my $used_mb = "";
      my $used_pb = "";
      my $total = 0;
      foreach my $capacite (@value){
        chomp $capacite;
        #print $capacite . "\n";
        $capacite =~ s/^\s+|\s+$//g;
        $index++;
        #print "$total\n";
        if ($total == 1 || $total == 2){
          if ($tb ne ""){
            $tb = $tb * 1024 * 1024;
            if ($total == 1){
              $performace_data{"Volume Level Statistics\n"}{$id}{"Capacity(MB)"} = "$tb";
            }
            else{
              #print "ahoj\n";
              $performace_data{"Volume Level Statistics\n"}{$id}{"Used(MB)"} = "$tb";
            }
          }
          if ($mb ne ""){
            if ($total == 1){
              $performace_data{"Volume Level Statistics\n"}{$id}{"Capacity(MB)"} = "$mb";
            }
            else{
              $performace_data{"Volume Level Statistics\n"}{$id}{"Used(MB)"} = "$mb";
            }

          }
          if ($gb ne ""){
            $gb = 1024 * $gb;
            if ($total == 1){
              $performace_data{"Volume Level Statistics\n"}{$id}{"Capacity(MB)"} = "$gb";
            }
            else{
              $performace_data{"Volume Level Statistics\n"}{$id}{"Used(MB)"} = "$gb";
            }

          }
          if ($pb ne ""){
            $pb = 1024 * 1024 * 1024 * $pb;
            if ($total == 1){
              $performace_data{"Volume Level Statistics\n"}{$id}{"Capacity(MB)"} = "$pb";
            }
            else{
              $performace_data{"Volume Level Statistics\n"}{$id}{"Used(MB)"} = "$pb";
            }
          }
          $tb = "";
          $gb = "";
          $mb = "";
          $pb = "";

        }
        if ($capacite eq ""){next;}
        if ($capacite eq "TB"){ $tb = $value[$index-1];$total = $total + 1; next;}
        if ($capacite eq "MB"){ $mb = $value[$index-1];$total = $total + 1; next;}
        if ($capacite eq "GB"){ $gb = $value[$index-1];$total = $total + 1; next;}
        if ($capacite eq "PB"){ $tb = $value[$index-1];$total = $total + 1; next;}
      }
    }

  }

}

sub set_per_pool{
  my $size = scalar @pool_id;
  if ( $size==0 ){
    return 0; ## no dp pools
  }
  ### delete element ###
  my $element = "Pool Level Statistics\n";
  #print Dumper \%performace_data;
  delete_element($element);

  ### calculate write trans size and read ###
  calculate_w_r_data($element);
  my $ide = 0;
  my $iorate = 0;
  my $riorate = 0;
  my $wiorate = 0;
  my $rtrans = 0;
  my $wtrans = 0;
  my $last_id = "";
  #print $size . "\n";
  #print "@pool_id\n";

  #print Dumper \%performace_data;
  foreach my $id (sort keys %{$performace_data{$element}}){
    #print $performace_data{"Pool Level Statistics\n"}{$id}{"ID"} . "\n";
    #print "$last_id\n";
    if ($performace_data{$element}{$id}{"ID"} ne "$last_id"){
      $iorate = 0;
      $riorate = 0;
      $wiorate = 0;
      $rtrans = 0;
      $wtrans = 0;
      $last_id = $performace_data{$element}{$id}{"ID"};
    }
    #print "$iorate\n";
    foreach my $line (@pool_id){
      chomp $line;
      $ide = $line;
      #print "$metric\n";
      #print $performace_data{"Pool Level Statistics\n"}{$id}{"$metric"} . "\n";
      if ($performace_data{"Pool Level Statistics\n"}{$id}{"ID"} eq "$line"){
        $iorate = $performace_data{"Pool Level Statistics\n"}{$id}{"IO Rate(IOPS)"} + $iorate;
        #print "$iorate\n";
        $riorate = $performace_data{"Pool Level Statistics\n"}{$id}{"Read Rate(IOPS)"} + $riorate;
        $wiorate = $performace_data{"Pool Level Statistics\n"}{$id}{"Write Rate(IOPS)"} + $wiorate;
        $rtrans = $performace_data{"Pool Level Statistics\n"}{$id}{"Read Trans. Size(kB/s)"} + $rtrans;
        $wtrans = $performace_data{"Pool Level Statistics\n"}{$id}{"Write Trans. Size(kB/s)"} + $wtrans;
        delete $performace_data{"Pool Level Statistics\n"}{$id};
        last;
      }
    }
    $performace_data{"Pool Level Statistics\n"}{$ide}{"IO Rate(IOPS)"} = "$iorate";
    $performace_data{"Pool Level Statistics\n"}{$ide}{"Read Rate(IOPS)"} = "$riorate";
    $performace_data{"Pool Level Statistics\n"}{$ide}{"Write Rate(IOPS)"} = "$wiorate";
    $performace_data{"Pool Level Statistics\n"}{$ide}{"Read Trans. Size(kB/s)"} = "$rtrans";
    $performace_data{"Pool Level Statistics\n"}{$ide}{"Write Trans. Size(kB/s)"} = "$wtrans";
    $performace_data{"Pool Level Statistics\n"}{$ide}{"ID"} = "$ide";
  }

  ### section for total size, used size ###
  my $first_line = 1;
  my @header = "";
  my $total_capacity = 0;
  my $used_capacity = 0;
  my $id_pool;
  my $position_id;
  my $position_used_cap;
  my $position_total_cap;
  my $position = -1;
  my $name_file = "config-DP.txt";

  if ($file_dp =~ /$name_file/){
    my $active = 0;
    foreach my $line (@dp_pool_all){
      chomp $line;
      $line =~ s/^\s+|\s+$//g;
      if ($line =~ /Capacity/){
        $active = 1;
        next;
      }
      if ($line eq ""){
        next;
      }
      if ($active == 1){
        my @array_line = split (" ",$line);
        my $index = -1;
        my $count = 0;
        my $id = $array_line[0];
        $id =~ s/^\s+|\s+$//g;
        foreach my $element (@array_line){
          if ($count == 2){last;}
          $index++;
          chomp $element;
          $element =~ s/^\s+|\s+$//g;
          if ($element =~ /TB/){
            $count++;
            my $capacity = $array_line[$index-1];
            $capacity =~ s/^\s+|\s+$//g;
            if ($count == 1){
              $performace_data{"Pool Level Statistics\n"}{$id}{"Total size(TB)"} = round($capacity);
              next;
            }
            if ($count == 2){
              $performace_data{"Pool Level Statistics\n"}{$id}{"Used size(TB)"} = round($capacity);
              next;
            }
          }
        }
      }
    }
  }
  else{
    foreach my $line (@dp_pool_all){
      if ($first_line == 1){   ### header first line
        @header = split(",",$line);
        $first_line++;
        next;
      }
      $position = -1;
      foreach my $head_el (@header){
        $position++;
        if ($head_el eq "DP Pool"){
        $position_id = $position;
        #print "$position\n";
        }
        if ($head_el eq "Total Capacity"){
        $position_total_cap = $position;
        }
        if ($head_el eq "Consumed Capacity"){
        $position_used_cap = $position;
        }
      }
      my @data_pool = split(",",$line);
      $id_pool = $data_pool[$position_id];
      #print "$id_pool\n";
      $total_capacity = $data_pool[$position_total_cap];
      $used_capacity = $data_pool[$position_used_cap];
      $total_capacity =~ s/^\s+|\s+$//g;
      $used_capacity =~ s/^\s+|\s+$//g;
      #print "$total_capacity $used_capacity\n";
      if ($total_capacity =~ /TB/){
        $total_capacity =~ s/TB//g;
        #print "$total_capacity\n";
        #$total_capacity = $total_capacity * 1024 * 1024;
      }

      if ($used_capacity =~ /TB/){
        $used_capacity =~ s/TB//g;
        #print "$total_capacity\n";
        #$used_capacity = $used_capacity * 1024 * 1024;
      }
      if ($total_capacity =~ /GB/){
        $total_capacity =~ s/GB//g;
        #print "$total_capacity\n";
        $total_capacity = $total_capacity / 1024;
        $total_capacity = round($total_capacity);
      }

      if ($used_capacity =~ /GB/){
        $used_capacity =~ s/GB//g;
        #print "$total_capacity\n";
        $used_capacity = $used_capacity / 1024;
        $used_capacity = round($used_capacity);
      }
      if ($used_capacity =~ /PB/){
        $used_capacity =~ s/PB//g;
        #print "$total_capacity\n";
        $used_capacity = $used_capacity * 1024;
        $used_capacity = round($used_capacity);
      }

      if ($total_capacity =~ /PB/){
        $total_capacity =~ s/PB//g;
        #print "$total_capacity\n";
        $total_capacity = $total_capacity * 1024;
        $total_capacity = round($total_capacity);
      }

      if ($total_capacity =~ /MB/){
        $total_capacity =~ s/MB//g;
        #print "$total_capacity\n";
        $total_capacity = $total_capacity / 1024 / 1024;
        $total_capacity = round($total_capacity);
      }

      if ($used_capacity =~ /MB/){
        $used_capacity =~ s/MB//g;
        #print "$total_capacity\n";
        $used_capacity = $total_capacity / 1024 / 1024;
        $used_capacity = round($total_capacity);
      }
    
      $total_capacity =~ s/^\s+|\s+$//g;
      $used_capacity =~ s/^\s+|\s+$//g;
      #print "$total_capacity $used_capacity\n";
      #$total_capacity =~ s/ //g;
      #$used_capacity =~ s/ //g;
      #print "$id_pool\n";
      $performace_data{"Pool Level Statistics\n"}{$id_pool}{"Total size(TB)"} = "$total_capacity";
      $performace_data{"Pool Level Statistics\n"}{$id_pool}{"Used size(TB)"} = "$used_capacity";
    }
  }
  ### end section ###
  ### section response time ###
  #print Dumper \%pool_luns;
  my $response_time_r = 0;
  my $numerator_r = 0;
  my $denominator = 0;
  my $response_time_w = 0;
  my $numerator_w = 0;
  foreach my $id (keys %{$pool_luns{POOL}}){
    #print $id . "\n";
    $numerator_w = 0;
    $numerator_r = 0;
    $denominator = 0;
    $response_time_r = 0;
    $response_time_w = 0;
    foreach my $id_lun (keys %{$pool_luns{POOL}{$id}{LUN}}){
      #print "$id_lun\n";
      $numerator_w = $pool_luns{POOL}{$id}{LUN}{$id_lun}{"Write response time"} * $pool_luns{POOL}{$id}{LUN}{$id_lun}{"IO Rate(IOPS)"} + $numerator_w;
      $numerator_r = $pool_luns{POOL}{$id}{LUN}{$id_lun}{"Read response time"} * $pool_luns{POOL}{$id}{LUN}{$id_lun}{"IO Rate(IOPS)"} + $numerator_r;
      $denominator = $pool_luns{POOL}{$id}{LUN}{$id_lun}{"IO Rate(IOPS)"} + $denominator;

    }
    #print "$numerator_r\n";
    #print "$denominator\n";
    if ($denominator == 0){
      $pool_luns{POOL}{$id}{"Write response time"} = 0;
      $pool_luns{POOL}{$id}{"Read response time"} = 0;
    }
    else{
      $response_time_r = $numerator_r / $denominator;
      $response_time_w = $numerator_w / $denominator;
      my $rounded_r = sprintf("%.3f", $response_time_r);
      my $rounded_w = sprintf("%.3f", $response_time_w);
      $pool_luns{POOL}{$id}{"Write response time"} = $rounded_w;
      $pool_luns{POOL}{$id}{"Read response time"} = $rounded_r;
      #print Dumper \%pool_luns;
    }
  }
  #print Dumper \%pool_luns;

  foreach my $id_s (keys %{$performace_data{$element}}){
    foreach my $id (keys %{$pool_luns{POOL}}){
      #print "$performace_data{$element}{$id_s}{ID} eq $pool_luns{POOL}{$id}{NAME}\n";
      if ( $performace_data{$element}{$id_s}{ID} eq $pool_luns{POOL}{$id}{NAME}){
        $performace_data{$element}{$id_s}{"Write response time"} = $pool_luns{POOL}{$id}{"Write response time"};
        $performace_data{$element}{$id_s}{"Read response time"} = $pool_luns{POOL}{$id}{"Read response time"};
        last;
      }
    }
  }
}

sub delete_element{
  my $sect = shift;
  #print Dumper \%section;
  #print "$sect";
  my @header = split(",",$section{"$sect"});
  #print "@header\n";
  #print "$header_select";
  my $size = scalar @header;
  $size--;
  my $index = 0;
  foreach my $id (keys %{$performace_data{"$sect"}}){
    foreach my $name (keys %{$performace_data{"$sect"}{$id}}){
      foreach my $element (@header){
        $element =~ s/\n//g;
        if ($element eq $name){
          $index = 0;
          last;
        }
        else{
          if ($index == $size){
            delete $performace_data{"$sect"}{$id}{$name};
            $index = 0;
          }
          else{$index++;}
        }
      }
    }
  }
}

sub calculate_w_r_data{
  my $section = shift;
  foreach my $id (keys %{$performace_data{"$section"}}){
     foreach my $name (keys %{$performace_data{"$section"}{$id}}){
       if ($name eq "Read Trans. Size(kB/s)" || $name eq "Write Trans. Size(kB/s)"){
          my $value = $performace_data{"$section"}{$id}{$name};
          if ($value == 0){
            $performace_data{"$section"}{$id}{$name} = $value;
            next;
          }
          my $int = $interval_lenght;
          $int =~ s/\n//g;
          $int =~ s/\D+//g;
          $value = $value/$int;
          $value = $value * 1024;
          my $rounded = round($value);
          $performace_data{"$section"}{$id}{$name} = $rounded;
        }
     }
  }
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

sub set_per_backend{
  ### delete elements that do not need ###
  my $verify_rate_0 = 0;
  my $r_rate_0 = 0;
  my $w_rate_0 = 0;
  my $r_trans_0 = 0;
  my $w_trans_0 = 0;
  my $r_rate_1 = 0;
  my $w_rate_1 = 0;
  my $r_trans_1 = 0;
  my $w_trans_1 = 0;
  my $verify_rate_1 = 0;
  my $ctl_0 = 0;
  my $ctl_1 = 1;
  my $section = "Backend Level Statistics\n";
  delete_element($section);

  ### calculate write trans. size and read trans size in kB/s
  calculate_w_r_data($section);

  foreach my $key (keys %{$performace_data{$section}}){
    my $controller = $performace_data{$section}{$key}{"Controller"};
    if ($controller eq $ctl_0){
      $verify_rate_0 = $verify_rate_0 + $performace_data{$section}{$key}{"Online Verify Rate(IOPS)"};
      $r_rate_0 =  $r_rate_0 + $performace_data{$section}{$key}{"Read Rate(IOPS)"};
      $w_rate_0 =  $w_rate_0 + $performace_data{$section}{$key}{"Write Rate(IOPS)"};
      $r_trans_0 = $r_trans_0 + $performace_data{$section}{$key}{"Read Trans. Size(kB/s)"};
      $w_trans_0 = $w_trans_0 + $performace_data{$section}{$key}{"Write Trans. Size(kB/s)"};
      delete $performace_data{$section}{$key};
    }
    else{
      $verify_rate_1 = $verify_rate_1 + $performace_data{$section}{$key}{"Online Verify Rate(IOPS)"};
      $r_rate_1 =  $r_rate_1 + $performace_data{$section}{$key}{"Read Rate(IOPS)"};
      $w_rate_1 =  $w_rate_1 + $performace_data{$section}{$key}{"Write Rate(IOPS)"};
      $r_trans_1 = $r_trans_1 + $performace_data{$section}{$key}{"Read Trans. Size(kB/s)"};
      $w_trans_1 = $w_trans_1 + $performace_data{$section}{$key}{"Write Trans. Size(kB/s)"};
      delete $performace_data{$section}{$key};
    }
    #print $r_rate . "\n";
  }
  $performace_data{$section}{$ctl_0}{"Online Verify Rate(IOPS)"} = $verify_rate_0;
  $performace_data{$section}{$ctl_0}{"Read Rate(IOPS)"} = $r_rate_0;
  $performace_data{$section}{$ctl_0}{"Write Rate(IOPS)"} = $w_rate_0;
  $performace_data{$section}{$ctl_0}{"Read Trans. Size(kB/s)"} = $r_trans_0;
  $performace_data{$section}{$ctl_0}{"Write Trans. Size(kB/s)"} = $w_trans_0;
  $performace_data{$section}{$ctl_0}{"Controller"} = "$ctl_0";

  $performace_data{$section}{$ctl_1}{"Online Verify Rate(IOPS)"} = $verify_rate_1;
  $performace_data{$section}{$ctl_1}{"Read Rate(IOPS)"} = $r_rate_1;
  $performace_data{$section}{$ctl_1}{"Write Rate(IOPS)"} = $w_rate_1;
  $performace_data{$section}{$ctl_1}{"Read Trans. Size(kB/s)"} = $r_trans_1;
  $performace_data{$section}{$ctl_1}{"Write Trans. Size(kB/s)"} = $w_trans_1;
  $performace_data{$section}{$ctl_1}{"Controller"} = "$ctl_1";

  #print Dumper \%performace_data;
}

sub set_per_processor{
  my $section = "CPU-CORE Level Statistics\n";
  delete_element($section);
}

sub set_per_operation_drive{
  my $section = "Drive Operate Level Statistics\n";
  delete_element($section);
   my $rate = 0;
   foreach my $line_id (@drive_id){
    foreach my $id (keys %{$performace_data{$section}}){
      if (!defined $performace_data{$section}{$id}{"Unit"}){next;}
       my $unit = $performace_data{$section}{$id}{"Unit"};
      my $hdu = $performace_data{$section}{$id}{"ID"};
      my $ID = "$unit-$hdu";
      if ($line_id eq "$ID"){
        $rate = $rate + $performace_data{$section}{$id}{"Operating Rate(%)"};
        delete($performace_data{$section}{$id});
      }
    }
    $performace_data{$section}{$line_id}{"ID"} = $line_id;
    $performace_data{$section}{$line_id}{"Operating Rate(%)"} = round($rate);
    $rate = 0;
  }


  foreach my $id (keys %{$performace_data{$section}}){
    my $rate = $performace_data{$section}{$id}{"Operating Rate(%)"};
    if (defined $performace_data{"Drive Level Statistics\n"}{$id}){
      $performace_data{"Drive Level Statistics\n"}{$id}{"Operating Rate(%)"} = $rate;
    }
  }
  #print Dumper \%performace_data;
  delete($performace_data{$section});
  delete($section{$section});
}


sub set_per_drive{
  my $section = "Drive Level Statistics\n";
  my $ctl = 0;
  my $last_iops = 0;
  my $io_rate = 0;
  my $r_rate = 0;
  my $w_rate = 0;
  my $r_trans = 0;
  my $w_trans = 0;
  my $last_id = "";
  calculate_w_r_data($section);
  foreach my $line_id (@drive_id){
    foreach my $key (keys %{$performace_data{$section}}){
      if (!defined $performace_data{$section}{$key}{"Unit"}){next;}
      my $unit = $performace_data{$section}{$key}{"Unit"};
      my $hdu = $performace_data{$section}{$key}{"ID"};
      my $ID = "$unit-$hdu";
      if ($line_id eq "$ID"){
        my $iops = $performace_data{$section}{$key}{"IO Rate(IOPS)"};
        if ($iops > $last_iops){
          $ctl = $performace_data{$section}{$key}{"Controller"};
          $last_iops = $iops;
        }
        $io_rate = $io_rate + $performace_data{$section}{$key}{"IO Rate(IOPS)"};
        $r_rate = $r_rate + $performace_data{$section}{$key}{"Read Rate(IOPS)"};
        $w_rate = $w_rate + $performace_data{$section}{$key}{"Write Rate(IOPS)"};
        $r_trans = $r_trans + $performace_data{$section}{$key}{"Read Trans. Size(kB/s)"};
        $w_trans = $w_trans + $performace_data{$section}{$key}{"Write Trans. Size(kB/s)"};
        #$last_id = $performace_data{$section}{$key}{"ID"};
        #print $key . "\n";
        delete $performace_data{$section}{$key};
      }
    }
    $performace_data{$section}{$line_id}{"IO Rate(IOPS)"} = round($io_rate);
    $performace_data{$section}{$line_id}{"Read Rate(IOPS)"} = round($r_rate);
    $performace_data{$section}{$line_id}{"Write Rate(IOPS)"} = round($w_rate);
    $performace_data{$section}{$line_id}{"Read Trans. Size(kB/s)"} = round($r_trans);
    $performace_data{$section}{$line_id}{"Write Trans. Size(kB/s)"} = round($w_trans);
    $performace_data{$section}{$line_id}{"ID"} = $line_id;
    $performace_data{$section}{$line_id}{"Controller"} = $ctl;
    #print Dumper  \%performace_data;
    $ctl = 0;
    $last_iops = 0;
    $io_rate = 0;
    $r_rate = 0;
    $w_rate = 0;
    $r_trans = 0;
    $w_trans = 0;
    $last_id = "";
  }
  #print Dumper \%performace_data;
  delete_element($section);
}


sub set_per_port{
  ### delete elements that do not need ###
  my $element = "Port Level Statistics\n";
  delete_element($element);

  ### calculate write trans. size and read trans size in kB/s
  calculate_w_r_data($element);
  #print Dumper \%performace_data;

}

sub set_per_hw{
  my $drive = "Drive Configuration Information";
  my $ctl = "Controller Information";
  my $cache = "Cache Information";
  my $interface = "Interface Board Information";
  my $batery = "Battery Information";
  my $additional = "Additional Battery Information";
  my $host = "Host Connector Information";
  my $fan = "Fan Information";
  my $enc = "ENC Information";
  my $ac = "AC PS Information";
  my $dc = "DC PS Information";
  my $unit = "Unit Information";
  my $if_module = "I/F Module Information";
  my $active = 0;
  my $status;
  my $name;
  my $error = 0;
  my $index;

  foreach my $line (@hw_all){
    chomp $line;
    my $len = length($line);
    #print "$line\n";
    if ($line =~ /$drive/){
      $active = 1;
      next;
    }
    if ($line =~ /$ctl/){
      $active = 2;
      next;
    }
    if ($line =~ /$cache/){
      $active = 3;
      next;
    }
    if ($line =~ /$interface/){
      $active = 4;
      next;
    }
    if ($line =~ /$batery/){
      $active = 5;
      next;
    }
    if ($line =~ /$host/){
      $active = 6;
      next;
    }
    if ($line =~ /$fan/){
      $active = 7;
      next;
    }
    if ($line =~ /$ac/){
      $active = 8;
      next;
    }
    if ($line =~ /$enc/){
      $active = 9;
      next;
    }
    if ($line =~ /$additional/){
      $active = 5;
      next;
    }
    if ($line =~ /$dc/){
      $active = 8;
      next;
    }
    if ($line =~ /$if_module/){
      $active = 10;
      next;
    }
    if ($line =~ /End/){
      $status = "";
      $name = "";
      $index = "";
      next;
    }
    if ($line eq ""){
      next;
    }

    if ($active == 1){ ### section drive
      if ($line =~ /Status/ || $line =~ /status/ || $line =~ /STATUS/){
        $status = "Status";
      }
      if ($line =~ /Location/ || $line =~ /location/ || $line =~ /LOCATION/){
        $name = "Location";
        next;
      }
      if (defined $status && defined $name){
        my @line_data = split (" ",$line);
        $line_data[0] =~ s/^\s+|\s+$//g;
        $line_data[1] =~ s/^\s+|\s+$//g;
        $line_data[2] =~ s/^\s+|\s+$//g;
        if ($line_data[1] =~ /HDU/){
          $name = "$line_data[0]". "$line_data[1]";
          $status = $line_data[2];
        }
        else{
          $name = "$line_data[0]";
          $status = $line_data[1];
        }
        $hw_section{$drive}{$name}{NAME} = $name;
        $hw_section{$drive}{$name}{STATUS} = $status;
        if ($status ne "Normal" && $status ne "Standby" && $status ne "Undefined"){
          $error = 1;
          last;
        }
        next;
      }

    }

    if ($active == 2){ ### section controller
      if ($line =~ /Status/ || $line =~ /status/ || $line =~ /STATUS/){
        $status = "Status";
        $index = get_status_index($line);

      }
      if ($line =~ /CTL/ || $line =~ /ctl/ || $line =~ /Ctl/){
        $name = "Ctl";
        next;
      }
      if (defined $status && defined $name && $status ne "" && $name ne "" && defined $index && $index ne ""){
        my @line_data = split (" ",$line);
        $line_data[0] =~ s/^\s+|\s+$//g;
        $name = "$line_data[0]";
        $status = substr($line,$index,$len);
        $status =~ s/^\s+|\s+$//g;
        $hw_section{$ctl}{$name}{NAME} = $name;
        $hw_section{$ctl}{$name}{STATUS} = $status;
        if ($status ne "Normal" && $status ne "Standby" && $status ne "Undefined"){
          $error = 1;
          last;
        }
        next;
      }
    }
    if ($active == 3){ ### section cache
      if ($line =~ /Status/ || $line =~ /status/ || $line =~ /STATUS/){
        $status = "Status";
        $index = get_status_index($line);

      }
      if ($line =~ /CTL/ || $line =~ /ctl/ || $line =~ /Ctl/){
        $name = "Ctl";
        next;
      }
      if (defined $status && defined $name && $status ne "" && $name ne "" && defined $index && $index ne ""){
        my @line_data = split (" ",$line);
        $line_data[0] =~ s/^\s+|\s+$//g;
        $name = "$line_data[0]";
        $status = substr($line,$index,$len);
        $status =~ s/^\s+|\s+$//g;
        $hw_section{$cache}{$name}{NAME} = $name;
        $hw_section{$cache}{$name}{STATUS} = $status;
        if ($status ne "Normal" && $status ne "Standby" && $status ne "Undefined" ){
          $error = 1;
          last;
        }
        next;
      }
    }
    if ($active == 4){ ### section interface
      if ($line =~ /Status/ || $line =~ /status/ || $line =~ /STATUS/){
        $status = "Status";
        $index = get_status_index($line);
      }
      if ($line =~ /CTL/ || $line =~ /ctl/ || $line =~ /Ctl/){
        $name = "Ctl";
        next;
      }
      if (defined $status && defined $name && $status ne "" && $name ne "" && defined $index && $index ne ""){
        my @line_data = split (" ",$line);
        $line_data[0] =~ s/^\s+|\s+$//g;
        $name = "$line_data[0]";
        $status = substr($line,$index,$len);
        $status =~ s/^\s+|\s+$//g;
        $hw_section{$interface}{$name}{NAME} = $name;
        #$hw_section{$interface}{$name}{STATUS} = $status;
        $hw_section{$interface}{$name}{STATUS} = $status;
        if ($status ne "Normal" && $status ne "Standby" && $status ne "Undefined"){
          $error = 1;
          last;
        }
        next;
      }
    }

    if ($active == 5){ ### section battery
      if ($line =~ /Status/ || $line =~ /status/ || $line =~ /STATUS/){
        $status = "Status";
        $index = get_status_index($line);

      }
      if ($line =~ /Battery/ || $line =~ /battery/ || $line =~ /BATTERY/){
        $name = "Battery";
        next;
      }
      if (defined $status && defined $name && $status ne "" && $name ne "" && defined $index && $index ne ""){
        my @line_data = split (" ",$line);
        $line_data[0] =~ s/^\s+|\s+$//g;
        $name = "$line_data[0]";
        $status = substr($line,$index,$len);
        $hw_section{$batery}{$name}{NAME} = $name;
        $hw_section{$batery}{$name}{STATUS} = $status;
        if ($status ne "Normal" && $status ne "Standby" && $status ne "Undefined"){
          $error = 1;
          last;
        }
        next;
      }
    }
    if ($active == 6){ ### section host
      if ($line =~ /Status/ || $line =~ /status/ || $line =~ /STATUS/){
        $status = "Status";
        $index = get_status_index($line);

      }
      if ($line =~ /Port/ || $line =~ /port/ || $line =~ /PORT/){
        $name = "Port";
        next;
      }
      if (defined $status && defined $name && $status ne "" && $name ne "" && defined $index && $index ne ""){
        my @line_data = split (" ",$line);
        $line_data[0] =~ s/^\s+|\s+$//g;
        $name = "$line_data[0]";
        $status = substr($line,$index,$len);
        $hw_section{$host}{$name}{NAME} = $name;
        $hw_section{$host}{$name}{STATUS} = $status;
        if ($status ne "Normal" && $status ne "Standby" && $status ne "Undefined"){
          $error = 1;
          last;
        }
        next;
      }
    }

    if ($active == 7){ ### section fan
      if ($line =~ /Status/ || $line =~ /status/ || $line =~ /STATUS/){
        $status = "Status";
        $index = get_status_index($line);

      }
      if ($line =~ /Unit/ || $line =~ /unit/ || $line =~ /UNIT/){
        $name = "Unit";
        next;
      }
      if (defined $status && defined $name && $status ne "" && $name ne "" && defined $index && $index ne ""){
        my @line_data = split (" ",$line);
        $line_data[0] =~ s/^\s+|\s+$//g;
        $name = "$line_data[0]";
        $status = substr($line,$index,$len);
        $hw_section{$fan}{$name}{NAME} = $name;
        $hw_section{$fan}{$name}{STATUS} = $status;
        if ($status ne "Normal" && $status ne "Standby" && $status ne "Undefined" ){
          $error = 1;
          last;
        }
        next;
      }
    }
    if ($active == 8){ ### section ac
      if ($line =~ /Status/ || $line =~ /status/ || $line =~ /STATUS/){
        $status = "Status";
        $index = get_status_index($line);

      }
      if ($line =~ /Unit/ || $line =~ /unit/ || $line =~ /UNIT/){
        $name = "Unit";
        next;
      }
      if (defined $status && defined $name && $status ne "" && $name ne "" && defined $index && $index ne ""){
        my @line_data = split (" ",$line);
        $line_data[0] =~ s/^\s+|\s+$//g;
        $name = "$line_data[0]" . "$line_data[1]";
        $status = substr($line,$index,$len);
        $hw_section{$ac}{$name}{NAME} = $name;
        $hw_section{$ac}{$name}{STATUS} = $status;
        if ($status ne "Normal" && $status ne "Standby" && $status ne "Undefined"){
          $error = 1;
          last;
        }
        next;
      }
    }
    if ($active == 9){ ### section enc
      if ($line =~ /Status/ || $line =~ /status/ || $line =~ /STATUS/){
        $status = "Status";
        $index = get_status_index($line);

      }
      if ($line =~ /Unit/ || $line =~ /unit/ || $line =~ /UNIT/){
        $name = "Unit";
        next;
      }
      if (defined $status && defined $name && $status ne "" && $name ne "" && defined $index && $index ne ""){
        my @line_data = split (" ",$line);
        $line_data[0] =~ s/^\s+|\s+$//g;
        $name = "$line_data[0]";
        $status = substr($line,$index,$len);
        $hw_section{$enc}{$name}{NAME} = $name;
        $hw_section{$enc}{$name}{STATUS} = $status;
        if ($status ne "Normal" && $status ne "Standby" && $status ne "Undefined"){
          $error = 1;
          last;
        }
        next;
      }
    }
    if ($active == 10){ ### section if module
      if ($line =~ /Status/ || $line =~ /status/ || $line =~ /STATUS/){
        $status = "Status";
        $index = get_status_index($line);

      }
      if ($line =~ /CTL/ || $line =~ /ctl/ || $line =~ /Ctl/){
        $name = "Ctl";
        next;
      }
      if (defined $status && defined $name && $status ne "" && $name ne "" && defined $index && $index ne ""){
        my @line_data = split (" ",$line);
        $line_data[0] =~ s/^\s+|\s+$//g;
        $name = "$line_data[0]";
        $status = substr($line,$index,$len);
        $hw_section{$if_module}{$name}{NAME} = $name;
        $hw_section{$if_module}{$name}{STATUS} = $status;
        if ($status ne "Normal" && $status ne "Standby" && $status ne "Undefined"){
          $error = 1;
          last;
        }
        next;
      }
    }
  }
  #print Dumper \%hw_section;
  return $error;

}

sub get_status_index{
  my $line = shift;
  $line =~ s/^\s+|\s+$//g;
  my $start_index = $line;
  $start_index =~ s/Status//g;
  my $length_line = length($start_index);
  return $length_line;
}


sub set_health_status_html{
  my $time = localtime();
  my $status;
  my $report = "Storage $STORAGE_NAME health status = optimal\n";
  #my $error_log = set_per_hw();
  if (set_per_hw() == 0){
    $status = "optimal";
    open(DATA, ">$health_status_html") or error_die ("Cannot open file: $health_status_html : $!");
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
    open(DATA, ">$health_status_html") or error_die ("Cannot open file: $health_status_html : $!");
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

sub set_global_health_status_summary{
  # Global health check
  my $act_timestamp  = time();
  my $main_state     = "OK";
  my $state_suffix   = "ok";
  my $component_name = $STORAGE_NAME;
  #$component_name =~ s/\s+//g;
  my $storage_status = set_health_status_html();

  if ( $storage_status !~ "optimal" ) { $main_state = "NOT_OK"; $state_suffix = "nok"; }
  if (! -d "$inputdir/tmp/health_status_summary" ) {
    mkdir("$inputdir/tmp/health_status_summary", 0755) || error( "$act_time: Cannot mkdir $inputdir/tmp/health_status_summary: $!" . __FILE__ . ":" . __LINE__ ) && exit;
  }
  if ( -f "$inputdir/tmp/health_status_summary/$component_name.ok" )  { unlink ("$inputdir/tmp/health_status_summary/$component_name.ok"); }
  if ( -f "$inputdir/tmp/health_status_summary/$component_name.nok" ) { unlink ("$inputdir/tmp/health_status_summary/$component_name.nok"); }

  open( MAST, ">$inputdir/tmp/health_status_summary/$component_name.$state_suffix" ) || error( "Couldn't open file $inputdir/tmp/health_status_summary/$component_name.$state_suffix $!" . __FILE__ . ":" . __LINE__ ) && exit;
  print MAST "STORAGE : $component_name : $main_state : $act_timestamp\n";
  close(MAST);
}

sub set_per_lun{
  use POSIX qw(ceil);
  my @unsort_id;
  my @sort_id;
  my $iorate = 0;
  my $riorate = 0;
  my $wiorate = 0;
  my $rtrans = 0;
  my $wtrans = 0;
  my $whit = 0;
  my $rhit = 0;
  my $rresp = 0;
  my $sum_rresp = 0;
  my $wresp = 0;
  my $sum_wresp = 0;
  my $io_hit = 0;
  my $io_job = 0;
  my $io_miss = 0;
  my $io_sum = 0;
  my $io_sum_w = 0;
  my $io_hit_time = 0;
  my $io_job_time = 0;
  my $io_miss_time = 0;
  my $last_id = "";
  my $ide;
  my $ctl;
  my $last_ctl;
  my $sum_average_hit_r = 0;
  my $sum_average_hit_w = 0;

  my $section = "Volume Level Statistics\n";
  ### calculate write trans. size and read trans size in kB/s
  calculate_w_r_data($section);
  #print Dumper \%performace_data;
  foreach my $id (sort keys %{$performace_data{$section}}){
    push(@unsort_id,$id);
  }
  @sort_id = sort { $a <=> $b } @unsort_id; ### sort by id
  #print "@sort_id\n";
  foreach my $line (@sort_id){
    #print "$line sort by id\n";
    foreach my $id (keys %{$performace_data{"Volume Level Statistics\n"}}){
      $ide = $performace_data{"Volume Level Statistics\n"}{$id}{"ID"};
      $ctl = $performace_data{"Volume Level Statistics\n"}{$id}{"Controller"};
      if ($id ne "$line"){next;}
      if ($performace_data{"Volume Level Statistics\n"}{$id}{"ID"} ne "$last_id"){
        $iorate = 0;
        $riorate = 0;
        $wiorate = 0;
        $rtrans = 0;
        $wtrans = 0;
        $rhit = 0;
        $whit = 0;
        $rresp = 0;
        $io_hit = 0;
        $io_job = 0;
        $io_miss = 0;
        $io_sum = 0;
        $io_sum_w = 0;
        $io_hit_time = 0;
        $io_job_time = 0;
        $io_miss_time = 0;
        $wresp = 0;
        $sum_wresp = 0;
        $sum_average_hit_w = 0;
        $sum_average_hit_r = 0;
        $sum_rresp = 0;
        $last_id = $performace_data{"Volume Level Statistics\n"}{$id}{"ID"};
        $last_ctl = $performace_data{"Volume Level Statistics\n"}{$id}{"Controller"};
        #print "$last_id\n";
      }
      #print "$ide\n";
      if ($iorate >= $performace_data{"Volume Level Statistics\n"}{$id}{"IO Rate(IOPS)"}){
        $ctl = $last_ctl;
      }
      if ($rhit ne "0" && $performace_data{"Volume Level Statistics\n"}{$id}{"Read Hit(%)"} ne "0"){
        $sum_average_hit_r = ceil((($rhit*$iorate)+($performace_data{"Volume Level Statistics\n"}{$id}{"Read Hit(%)"}*$performace_data{"Volume Level Statistics\n"}{$id}{"IO Rate(IOPS)"}))/($iorate+$performace_data{"Volume Level Statistics\n"}{$id}{"IO Rate(IOPS)"}));
        $rhit = $sum_average_hit_r;
      }
      else{$rhit = $performace_data{"Volume Level Statistics\n"}{$id}{"Read Hit(%)"} + $rhit;}

      if ($whit ne "0" && $performace_data{"Volume Level Statistics\n"}{$id}{"Write Hit(%)"} ne "0"){
        $sum_average_hit_w = ceil((($whit*$iorate)+($performace_data{"Volume Level Statistics\n"}{$id}{"Write Hit(%)"}*$performace_data{"Volume Level Statistics\n"}{$id}{"IO Rate(IOPS)"}))/($iorate+$performace_data{"Volume Level Statistics\n"}{$id}{"IO Rate(IOPS)"}));
        $whit = $sum_average_hit_w;
      }
      else{$whit = $performace_data{"Volume Level Statistics\n"}{$id}{"Write Hit(%)"} + $whit;}

      if ($rresp ne "0" && $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Hit Time(microsec.)"} ne "0"  && $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Miss Time(microsec.)"} ne "0" && $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Job Time(microsec.)"} ne "0"){

        $sum_rresp = (($rresp*$io_sum) + ( $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Hit Time(microsec.)"} * $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Hit Count2"}) + ( $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Miss Time(microsec.)"} * $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Miss Count"} ) + ( $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Job Time(microsec.)"} * $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Job Count)"})) / ($performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Hit Count2"} + $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Miss Count"} + $io_sum +  $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Job Count"} );
        $sum_rresp = $sum_rresp / 1000;
        my $rounded = sprintf("%.3f", $sum_rresp);
        $rresp = $rounded;
      }
      else{
        if ($performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Hit Count2"} eq "0" && $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Miss Count"} eq "0" && $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Job Count"} eq "0"){
          $rresp = $rresp + 0;
        }
        else{

          $rresp = (( $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Hit Time(microsec.)"} * $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Hit Count2"}) + ( $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Miss Time(microsec.)"} * $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Miss Count"} ) + ( $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Job Time(microsec.)"} * $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Job Count"})) / ($performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Hit Count2"} + $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Miss Count"} +  $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Job Count"} );
          $rresp = $rresp / 1000;
          my $rounded = sprintf("%.3f", $rresp);
          $rresp = $rounded;
        }
      }

      if ($wresp ne "0" && $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Hit Time(microsec.)"} ne "0" && $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Miss Time(microsec.)"} ne "0" && $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Job Time(microsec.)"} ne "0"){

      $sum_wresp = (($wresp*$io_sum_w) + ( $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Hit Time(microsec.)"} * $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Hit Count2"}) + ( $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Miss Time(microsec.)"} * $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Miss Count"} ) + ( $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Job Time(microsec.)"} * $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Job Count)"})) / ($performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Hit Count2"} + $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Miss Count"} + $io_sum_w +  $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Job Count"} );
      $sum_wresp = $sum_wresp / 1000;
      my $rounded = sprintf("%.3f", $sum_wresp);
      $wresp = $rounded;
      }
      else{
        if ($performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Hit Count2"} eq "0" && $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Miss Count"} eq "0" && $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Job Count"} eq "0"){
          $wresp = $wresp + 0;
        }
        else{

          $wresp = (( $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Hit Time(microsec.)"} * $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Hit Count2"}) + ( $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Miss Time(microsec.)"} * $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Miss Count"} ) + ( $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Job Time(microsec.)"} * $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Job Count"})) / ($performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Hit Count2"} + $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Miss Count"} +  $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Job Count"} );
          $wresp = $wresp / 1000;
          my $rounded = sprintf("%.3f", $wresp);
          $wresp = $rounded;
        }

      }

      $iorate = $performace_data{"Volume Level Statistics\n"}{$id}{"IO Rate(IOPS)"} + $iorate;
      $io_sum = $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Hit Count2"} + $rresp + $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Miss Count"} + $performace_data{"Volume Level Statistics\n"}{$id}{"Read CMD Job Count"};
      $io_sum_w = $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Hit Count2"} + $rresp + $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Miss Count"} + $performace_data{"Volume Level Statistics\n"}{$id}{"Write CMD Job Count"};
      #print "$iorate\n";
      $riorate = $performace_data{"Volume Level Statistics\n"}{$id}{"Read Rate(IOPS)"} + $riorate;
      $wiorate = $performace_data{"Volume Level Statistics\n"}{$id}{"Write Rate(IOPS)"} + $wiorate;
      $rtrans = $performace_data{"Volume Level Statistics\n"}{$id}{"Read Trans. Size(kB/s)"} + $rtrans;
      $wtrans = $performace_data{"Volume Level Statistics\n"}{$id}{"Write Trans. Size(kB/s)"} + $wtrans;
      #print "$rhit a $iorate\n";
      #$rhit = $performace_data{"Volume Level Statistics\n"}{$id}{"Read Hit(%)"};
      #$whit = $performace_data{"Volume Level Statistics\n"}{$id}{"Write Hit(%)"} + $whit;
      delete $performace_data{"Volume Level Statistics\n"}{$id};
      last;
    }
    $performace_data{"Volume Level Statistics\n"}{$ide}{"IO Rate(IOPS)"} = "$iorate";
    #print $performace_data{"Volume Level Statistics\n"}{$ide}{"IO Rate(IOPS)"} . "\n";
    $performace_data{"Volume Level Statistics\n"}{$ide}{"Read Rate(IOPS)"} = "$riorate";
    $performace_data{"Volume Level Statistics\n"}{$ide}{"Write Rate(IOPS)"} = "$wiorate";
    $performace_data{"Volume Level Statistics\n"}{$ide}{"Read Trans. Size(kB/s)"} = "$rtrans";
    $performace_data{"Volume Level Statistics\n"}{$ide}{"Write Trans. Size(kB/s)"} = "$wtrans";
    $performace_data{"Volume Level Statistics\n"}{$ide}{"Read Hit(%)"} = "$rhit";
    $performace_data{"Volume Level Statistics\n"}{$ide}{"Write Hit(%)"} = "$whit";
    $performace_data{"Volume Level Statistics\n"}{$ide}{"ID"} = "$ide";
    $performace_data{"Volume Level Statistics\n"}{$ide}{"Controller"} = $ctl;
    $performace_data{"Volume Level Statistics\n"}{$ide}{"Read response time"} = $rresp;
    $performace_data{"Volume Level Statistics\n"}{$ide}{"Write response time"} = $wresp;
    #print Dumper \%performace_data;
  }
### section for total size, used size ###
  my $first_line = 1;
  my @header = "";
  my $total_capacity = 0;
  my $used_capacity = 0;
  my $id_lu;
  my $position_id;
  my $position_used_cap;
  my $position_total_cap;
  my $position = -1;
  my $percent_consumed = 0;
  my $unit = "";
  my $POOL_ID = "";
  my $size = scalar @pool_id;
  #$size = 0; ### testing;

  foreach my $line (@lu_all){
    if ($size == 0){
      #set_capacity_lun();
      last;
    }
    chomp $line;
    $line =~ s/^\s+|\s+$//g;
    #$count_line++;
    #print $line . "\n";

    ### mapping pool per lun
    
    if ($line =~ /DP Pool/){
      #next; ### for testing nothing pool;
      my @data_pool = split (":",$line);
      $data_pool[1] =~ s/^\s+|\s+$//g;
      $pool_luns{POOL}{$data_pool[1]}{"NAME"} = $data_pool[1];
      $POOL_ID = $data_pool[1];
      next;
    }

    if ($line =~/LUN/ || $line =~ /DP Pool/ || $line eq ""){    ### blank lines ###
      next;
    }
    my @data_lu = split(" ",$line);
    #print "@data_lu\n";
    $id_lu = $data_lu[0];
    $pool_luns{POOL}{$POOL_ID}{"LUN"}{$id_lu}{NAME} = $data_lu[0];
    $total_capacity = $data_lu[1];
    $unit = $data_lu[2];
    #print "$data_lu[2]\n";
    $percent_consumed = $data_lu[3];
    #print $total_capacity ."\n";

    if ($unit =~ /GB/){
      #$total_capacity =~ s/\D+//g;
      #$total_capacity =~ s/.//g;
      #print "$total_capacity\n";
      my $pom = $total_capacity * 1024;
      $total_capacity = $pom;
      #print $total_capacity ."\n";
    }

    if ($unit =~ /TB/){
      #$total_capacity =~ s/\D+//g;
      my $pom = $total_capacity * (1024*1024);
      $total_capacity = $pom;
      #print $total_capacity ."\n";
    }
    if ($unit =~ /PB/){
      #$total_capacity =~ s/\D+//g;
      my $pom = $total_capacity * (1024*1024*1024);
      $total_capacity = $pom;
      #print $total_capacity ."\n";
    }


    if ($percent_consumed =~ /%/){
      $percent_consumed =~ s/\D+//g;
      #print "$percent_consumed\n";
      $used_capacity = ($percent_consumed/100) * $total_capacity;
      my $rounded = sprintf("%.3f", $used_capacity);
      $used_capacity = $rounded;
    }
    #$total_capacity =~ s/\D+//g;
    #$used_capacity =~ s/\D+//g;
    #print "$id_pool\n";
    $performace_data{"Volume Level Statistics\n"}{$id_lu}{"Capacity(MB)"} = "$total_capacity";
    $performace_data{"Volume Level Statistics\n"}{$id_lu}{"Used(MB)"} = "$used_capacity";
  }
  #print Dumper \%pool_luns;
  foreach my $resp (keys %{$performace_data{"Volume Level Statistics\n"}}){
    foreach my $id_pool (keys %{$pool_luns{POOL}}){
      if ($id_pool eq ""){next;}  ### nothing pool;
      if (!defined $pool_luns{POOL}{$id_pool}{LUN}){next;} ### pool has no luns
      foreach my $id_lun (keys %{$pool_luns{POOL}{$id_pool}{LUN}}){
        if (!defined $pool_luns{POOL}{$id_pool}{LUN}{$id_lun}{NAME} ){next;}
        if ($performace_data{"Volume Level Statistics\n"}{$resp}{ID} eq $pool_luns{POOL}{$id_pool}{LUN}{$id_lun}{NAME} ){
          $pool_luns{POOL}{$id_pool}{LUN}{$id_lun}{"Read response time"} = $performace_data{"Volume Level Statistics\n"}{$resp}{"Read response time"};
          $pool_luns{POOL}{$id_pool}{LUN}{$id_lun}{"Write response time"} = $performace_data{"Volume Level Statistics\n"}{$resp}{"Write response time"};
          $pool_luns{POOL}{$id_pool}{LUN}{$id_lun}{"IO Rate(IOPS)"} = $performace_data{"Volume Level Statistics\n"}{$resp}{"IO Rate(IOPS)"};
        }
      }
    }
  }
  #print Dumper \%performace_data;
  ### end section ###
}

sub set_data {
  my $kind = shift;
  my $header = shift;
  @values = "";
  foreach my $id (keys %{$performace_data{$kind}}){
    if (!@values eq ""){
       my $last = pop(@values);
       $last =~ s/,//g;
       push(@values,$last);
    }
    push(@values,"\n");
    my @headers = split(",",$header);
    foreach my $element(@headers){
      chomp $element;
      $element=~ s/^\s+|\s+$//g;
      #print $element . "\n";
      if (defined $performace_data{$kind}{$id}{$element}){
        push(@values,"$performace_data{$kind}{$id}{$element},");
      }
      else{
         push(@values,",");
      }
    }
    #print "@headers\n";
  }
  my $last = pop(@values);
  $last =~ s/,//g;
  push(@values,$last);
}


### new function for testing ###

sub get_first_perf{
  `"$HUS_CLIDIR"/auperform -unit "$STORAGE_NAME"  -auto 5 -count 1 -pfmstatis -path "$config_directory" -neterrorskip`;
  return "$config_directory/pfm00000.txt";
}

#sub get_first_perf{
#  #my $wrkdir = $wrkdir_data;
#  my @wrkdir_all = <$wrkdir/SUROVE/perform_data/*>;
#  my @files_all;
#  foreach my $paths (@wrkdir_all){
#    my @path = split("/",$paths);
#    foreach my $file (@path){
#      if ($file =~ /.txt/){
#        push(@files_all,$file);
#      }
#    }
#  }
#  my @sort_files = sort { $a cmp $b } @files_all;
#  my $old_file = "$wrkdir/SUROVE/perform_data/$sort_files[0]";
#
#  return $old_file;
#}


sub get_name_perf_file{
  my $dir = "$wrkdir"; ### for testing
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
  #my $name_file = "$dir/$STORAGE_NAME.conf.$year$month$day"."."."$hour$minute";
  #my $name_file = "$dir/HUS110_TEST/HUS110_TEST_husperf_$year$month$day"."_"."$hour$minute$sec".".out";
  my $name_file = "$wrkdir/$STORAGE_NAME"."_husperf_"."$year$month$day"."_"."$hour$minute".".out";
  #print "$name_file\n";
  return $name_file;

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

sub data_structure{
  my  $directory = $configuration;
  if (!-d $directory){
    mkdir $directory || error_die( "Cannot read $file: $!" . __FILE__ . ":" . __LINE__ );
  }
  for (my $i=0;$i<60;$i=$i+5){
    if ($i<10){
      if (!-d "$directory/0$i"){
      mkdir "$directory/0$i" || error_die( "Cannot read $file: $!" . __FILE__ . ":" . __LINE__ );
    }
    }
    else{
      if (!-d "$directory/$i"){
        mkdir "$directory/$i" || error_die( "Cannot read $file: $!" . __FILE__ . ":" . __LINE__ );
      }
    }
  }
}



sub create_config_dp{
  my $file_dp = "$config_directory/config-DP.csv";
  #my $size = scalar @pool_id;
  `"$HUS_CLIDIR/auconfigreport" -unit "$STORAGE_NAME" -filetype csv -resource dp -file "$file_dp"`;
  my $test = test_file_exist($file_dp);
  if ($test){
    return "$file_dp";
  }
  else{
    $file_dp = "$config_directory/config-DP.txt";
    `"$HUS_CLIDIR/audppool" -unit "$STORAGE_NAME" -refer -t > "$file_dp"`;
    $test = test_file_exist($file_dp);
    if ($test){
      return "$file_dp";
    }
    else{
      return 0;
    }
  }
}

sub create_config_lu{
  my $file_lu = "$config_directory/config-LU.txt";
  `"$HUS_CLIDIR/audptrend" -unit "$STORAGE_NAME" -refer -lulist > "$file_lu"`;
  my $test = test_file_exist($file_lu);
  if ($test){
    return "$file_lu";
  }
  else{
    return 0;
  }

}

sub create_config_rg{
  my $file_rg = "$config_directory/config-RG.csv";
  `"$HUS_CLIDIR/auconfigreport" -unit "$STORAGE_NAME" -filetype csv -resource rg -file "$file_rg"`;
  my $test = test_file_exist($file_rg);
  if ($test){
    return "$file_rg";
  }
  else{
    return 0;
  }
}

sub create_config_hw{
  my $file_hw = "$config_directory/config-PORT.txt";
  `"$HUS_CLIDIR/auconstitute" -unit "$STORAGE_NAME" -export -parts "$file_hw"`;
  return "$file_hw";
}

sub create_config_volume{
  my $file_volume = "$config_directory/config-LU.csv";
  `"$HUS_CLIDIR/auconfigreport" -unit "$STORAGE_NAME" -filetype csv -resource lu -file "$file_volume"`;
  return "$file_volume";
}


sub error_die
{
  my $message = shift;
  print STDERR "$message\n";
  exit (1);
}



set_per_lun();
set_per_rg();
set_per_pool();
set_per_port();
#set_per_lun();
set_per_backend();
#print Dumper \%performace_data;
set_per_processor();
set_per_drive();
set_per_operation_drive();
set_global_health_status_summary();

foreach my $sect (keys %section){
  open(DATA, ">>$output") or error_die ("Cannot open file: $output : $!");
  my $title = $sect;
  set_data("$title","$section{$sect}");
  #$output = "$output" . "$title" . "\n" . "$interval_start" . "$interval_end" . "$interval_lenght" . "\n\n" . "$section{$sect}". "\n";
  #$output = "$output" . "@values";
  print DATA $title;
  #print DATA "\n";
  print DATA" $interval_start";
  print DATA" $interval_end";
  print DATA" $interval_lenght";
  print DATA"\n";
  $section{$sect} =~ s/\n//g;
  print DATA $section{$sect};
  #set_data("$title","$section{$sect}");
  print DATA @values;
  print DATA "\n\n";
  close DATA;
}
#open(DATA, ">HUS-output.txt") or error_die ("Cannot open file: HUS-output.txt : $!");
#print DATA $output;
#close DATA;
#print Dumper \%section;


#print Dumper \%performace_data;
#my $remove = "$config_directory/pfm00000.txt";
#unlink $remove or die "Unable to unlink $remove: $!";
alarm(0);
};

if ($@){
  if ($@ =~ /died in SIG ALRM/){
    my $act_time = localtime();
    error_die(" script husperf.pl timed out after : $timeout seconds");
  }
}
