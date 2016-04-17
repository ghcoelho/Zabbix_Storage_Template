#!/usr/bin/perl

use warnings;
use strict;
use Data::Dumper;
my $header_config = "Configuration Data";
my $separator = "-";
my %inventory_host;
my %lun_interface;
my %volumes;

my $STORAGE_NAME = $ENV{STORAGE_NAME};
my $BASEDIR = $ENV{INPUTDIR};
my $HUS_CLIDIR = $ENV{HUS_CLIDIR};
my $bindir = $ENV{BINDIR};
my $wrkdir = "$BASEDIR/data/$STORAGE_NAME";
my $configuration = "$wrkdir/IOSTATS";
my $act_directory = localtime();
my $output_file;

#my $STORAGE_NAME = "HUS110_TEST";
#my $bindir = $ENV{BINDIR};
#my $wrkdir = "/home/stor2rrd/stor2rrd/data/HUS110/hus_conf";
#my $configuration = "$wrkdir/IOSTATS";
#my $act_directory = localtime();
#my $output_file;



### active directory

my @entry_time = split(" ",$act_directory);
(undef, my $active_minute, undef) =  split(":",$entry_time[3]);
#print "$active_minute\n";
my $config_directory = "$configuration/$active_minute";



###

### header configuration ###

#print "$header_config\n";
#print get_separator($header_config);
#print get_header_cfg();
#######

### sub get_separator ###

sub get_separator{
  my $header = shift;
  my $count = length($header);
  my $separator;
  for (my $i=0;$i<$count;$i++){
    $separator = $separator . "-";
  }
  return "$separator\n";
}

###

sub get_header_cfg{
  my $file = create_config_header();
  my @config;
  my $next = 0;
  open( FH, "< $file" ) || error_die( "Cannot read $file: $!" . __FILE__ . ":" . __LINE__ ) && exit 0;
  my @cfg = <FH>;
  close(FH);

  foreach my $line(@cfg){
    chomp $line;
    $line =~ s/^\s+|\s+$//g;
    if ($line =~ /DF Name/){
      push(@config,"$line\n");
      $next = 1;
      next;
    }
    if ($line =~ /--/){
      last;
    }

    if ($next == 1 && $line ne ""){
      push(@config,"$line\n");
    }
  }
  return @config;

}

sub create_config_header{ ### for header and port one last hour
  my $file_header = "$config_directory/config-PORT.txt";
  `"$HUS_CLIDIR/auconstitute" -unit "$STORAGE_NAME" -export -parts "$file_header"`;
  return "$file_header";
}


sub get_value_port{
  my $file = create_config_header();
  my @config;
  my $i =1;
  open( FH, "< $file" ) || error_die( "Cannot read $file: $!" . __FILE__ . ":" . __LINE__ ) && exit 0;
  my @cfg = <FH>;
  close(FH);

  foreach my $line(@cfg){
    chomp $line;
    $line =~ s/^\s+|\s+$//g;
    if ($line =~ /Host Connector/){
    #print "$line\n";
    $i = 2;
    next;

    }
    if ($i==2){
      if ($line =~ /Port/){
        #print $line . "\n";
        $i = 3;
        next;
      }
    }
    if ($i==3){
      if ($line eq ""){last;}
      my @line_cfg = split(" ",$line);
      #print "@line_cfg[0]\n";
      push(@config,",,$line_cfg[0],,,,,,\n");
    }
  }
  return @config;

}

sub create_config_dp{
   my $file_dp = "$config_directory/config-DP.csv";
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

sub create_config_host1{
  my $file_host = "$config_directory/config-HOST1.txt";
  `"$HUS_CLIDIR/auhgwwn" -unit "$STORAGE_NAME" -refer > "$file_host"`;
  return "$file_host";
}

sub create_config_host2{
  my $file_host = "$config_directory/config-HOST2.txt";
  `"$HUS_CLIDIR/auhgmap" -unit "$STORAGE_NAME" -refer > "$file_host"`;
  return "$file_host";
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

sub get_value_pool{
  my @config = "";
  my $file = create_config_dp();
  if ($file eq 0){
    return 0;
  }
  my $i =1;
  open( FH, "< $file" ) || error_die( "Cannot read $file: $!" . __FILE__ . ":" . __LINE__ ) && exit 0;
  my @cfg = <FH>;
  close(FH);

  my $file_name = "config-DP.txt";
  if ($file =~ /$file_name/){
    my $active = 0;
    my $total_capacity;
    my $used_capacity;
    my $free_capacity;
    my $status = "Status";
    my $position;
    foreach my $line (@cfg){
      my $pom_line = $line;
      chomp $line;
      $line =~ s/^\s+|\s+$//g;
      if ($line =~ /Capacity/ && $line =~ /Status/){
        $active = 1;
        my @chars = split ("",$pom_line);
        my $key_word;
        my $int = -1;
        foreach my $char (@chars){
          $key_word = $key_word . $char;
          #$key_word =~ s/^\s+//;
          $int++;
          if ($key_word =~ /$status/){
            $position = $int - 5;
            last;
          }
        }
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

        ### status ###
        my $len = length $line;
        my $STATUS = substr($pom_line,$position,$len);
        if ($STATUS =~ /\)/ && $STATUS =~ /\(/){
          my @separ_status = split(/\)/,$STATUS);
          $STATUS = $separ_status[0];
          if ($STATUS =~ /\(/){$STATUS = $STATUS . ")";}
        }
        else{
          $STATUS  =~ s/\s+/ /g;
          my @separ = split(" ",$STATUS);
          $separ[0] =~ s/^\s+|\s+$//g;
          $STATUS = $separ[0];
        }
        foreach my $element (@array_line){
          if ($count == 2){
            push(@config,",$id,$STATUS,,,$total_capacity,,$free_capacity,,$used_capacity,,,,,,,,\n");
            last;
          }
          $index++;
          chomp $element;
          $element =~ s/^\s+|\s+$//g;
          if ($element =~ /TB/){
            $count++;
            my $capacity = $array_line[$index-1];
            $capacity =~ s/^\s+|\s+$//g;
            if ($count == 1){
              $total_capacity = $capacity * 1024;  ## in GB
              $total_capacity = round($total_capacity);
              next;
            }
            if ($count == 2){
              $used_capacity = $capacity * 1024; ## in GB
              $used_capacity = round($used_capacity);
              $free_capacity = $total_capacity - $used_capacity;
              $free_capacity = round($free_capacity);
              next;
            }
          }
        }
      }
    }
  }
  else{
    foreach my $line(@cfg){
      chomp $line;
      if ($i ==1){
        $i++;
        next;
      }
      my @config_line = split(",",$line);
      my $id = $config_line[0];
      my $total_capacity = $config_line[2];
      my $used_capacity = $config_line[3];
      my $status = $config_line[5];
      my $free_capacity;

      if ($total_capacity =~ /TB/){
        $total_capacity =~ s/TB//g;
        $total_capacity = $total_capacity * 1024;
      }
      if ($total_capacity =~ /GB/){
        $total_capacity =~ s/GB//g;
      }
      if ($total_capacity =~ /PB/){
        $total_capacity =~ s/PB//g;
        $total_capacity = $total_capacity * 1024 * 1024;
      }

      if ($total_capacity =~ /MB/){
        $total_capacity =~ s/MB//g;
        $total_capacity = $total_capacity / 1024;
        my $rounded = round($total_capacity);
        $rounded = $total_capacity;
      }

      if ($used_capacity =~ /TB/){
        $used_capacity =~ s/TB//g;
        $used_capacity = $used_capacity * 1024;
      }
      if ($used_capacity =~ /GB/){
        $used_capacity =~ s/GB//g;
      }
      if ($used_capacity =~ /PB/){
        $used_capacity =~ s/PB//g;
        $used_capacity = $used_capacity * 1024 * 1024;
      }

      if ($used_capacity =~ /MB/){
        $used_capacity =~ s/MB//g;
        $used_capacity = $used_capacity / 1024;
        my $rounded = round($used_capacity);
        $rounded = $used_capacity;
      }

      $free_capacity = $total_capacity - $used_capacity;
      $free_capacity =~ s/^\s+|\s+$//g;
      $total_capacity =~ s/^\s+|\s+$//g;
      $used_capacity =~ s/^\s+|\s+$//g;
      push(@config,",$id,$status,,,$total_capacity,,$free_capacity,,$used_capacity,,,,,,,,\n");
    }
  }
  return @config;
}



sub create_config_lu{
  my $file_lu = "$config_directory/config-LU.csv";
  `"$HUS_CLIDIR/auconfigreport" -unit "$STORAGE_NAME" -filetype csv -resource lu -file "$file_lu"`;
  return "$file_lu";
}

#sub create_config_lun{
#  my $file_lu = "$wrkdir/config12.txt";
#  return $file_lu;
#
#}


#sub get_value_volume{
#  my $file = create_config_lun();
#  open( FH, "< $file" ) || error_die( "Cannot read $file: $!" . __FILE__ . ":" . __LINE__ ) && exit 0;
#  my @cfg = <FH>;
#  close(FH);
#  my $active = 0;
#  my @config;
#  my $id = "" ;
#
#  foreach my $line(@cfg){
#    chomp $line;
#    if ($line eq ""){ $active = 0; next;}
#    $line =~ s/^\s+|\s+$//g;
#    if ($line =~ /LUN/){
#      $active = 1;
#      #print "$line\n\n";
#      next;
#    }
#    if ($active == 1){
#      my @value = split (" ",$line);
#      #print "$value[1]\n"; ### lun id
#      $value[0] =~ s/^\s+|\s+$//g;
#      $value[1] =~ s/^\s+|\s+$//g;
#      $id = $value[0];
#      #my $more_id = 0;
#      push(@config,"$value[0],");
#      push(@config,",");                 ### id
#      push(@config,",");                 ### lun name
#      push(@config,",,,");
#      if ($value[1] ne "N/A" && $value[1] ne "n/a" && $value[1] ne "na" && $value[1] ne "NA"){
#        push(@config,"$value[1],");
#        #$more_id = 1;
#      }
#      else{
#        push(@config,",");
#      }
#      #push(@config,"$value[1],");
#      my $index = -1;
#      my $tb = "";
#      my $mb = "";
#      my $gb = "";
#      my $pb = "";
#      my $used_gb = "";
#      my $used_tb = "";
#      my $used_mb = "";
#      my $used_pb = "";
#      my $total = 0;
#      foreach my $capacite (@value){
#        chomp $capacite;
#        $capacite =~ s/^\s+|\s+$//g;
#        $index++;
#        if ($total == 1 || $total == 2){
#          if ($tb ne ""){
#            $tb = $tb * 1024 * 1024;
#            push(@config,"$tb,");
#          }
#          if ($mb ne ""){
#            push(@config,"$mb,");
#          }
#          if ($gb ne ""){
#            $gb = 1024 * $gb;
#            push(@config,"$gb,");
#          }
#          if ($pb ne ""){
#            $pb = 1024 * 1024 * 1024 * $pb;
#            push(@config,"$pb,");
#          }
#          $tb = "";
#          $gb = "";
#          $mb = "";
#          $pb = "";
#
#        }
#        if ($capacite eq ""){next;}
#        if ($capacite eq "TB"){ $tb = $value[$index-1];$total = $total + 1; next;}
#        if ($capacite eq "MB"){ $mb = $value[$index-1];$total = $total + 1; next;}
#        if ($capacite eq "GB"){ $gb = $value[$index-1];$total = $total + 1; next;}
#        if ($capacite eq "PB"){ $tb = $value[$index-1];$total = $total + 1; next;}
#      }
#      push(@config,",,,,,,,,,,,");
#      foreach my $ids (keys %lun_interface){
#        if ($ids eq "$id"){
#          push(@config,"$lun_interface{$id}{INTERFACE}\n");
#          last;
#        }
#      }
#
#    }
#  }
#
#  return @config;

#}


sub get_value_mapping_port{
  my $host_name = "";
  my $group_name;
  my $volume_name;
  my $port_name;
  my @cfg_mapping;

  ### mapping per host group ###

  #foreach my $group (keys %{$inventory_host{"HOST GROUP"}}){
  #  if (!defined $inventory_host{"HOST GROUP"}{$group}{"GROUP NAME"}){next;}
  #  $group_name = $inventory_host{"HOST GROUP"}{$group}{"GROUP NAME"};
  #  $host_name = "";
  #  $port_name = "";
  #  $volume_name = "";
  #  #print "$group_name\n";
  #  foreach my $host (keys %{$inventory_host{"HOST GROUP"}{$group}{HOST}}){
  #    if (!defined $inventory_host{"HOST GROUP"}{$group}{HOST}{$host}{"HOST NAME"}){next;}
  #    $host_name = $host_name . $inventory_host{"HOST GROUP"}{$group}{HOST}{$host}{"HOST NAME"} . " ";
  #  }
  #  foreach my $port (keys %{$inventory_host{"HOST GROUP"}{$group}{PORT}}){
  #    if (!defined $inventory_host{"HOST GROUP"}{$group}{PORT}{$port}{"PORT NAME"}){next;}
  #    $port_name = $port_name . $inventory_host{"HOST GROUP"}{$group}{PORT}{$port}{"PORT NAME"} . " ";
  #  }
  #
  #  foreach my $volume (keys %{$inventory_host{"HOST GROUP"}{$group}{LUN}}){
  #    if (!defined $inventory_host{"HOST GROUP"}{$group}{LUN}{$volume}{"LUN ID"}){next;}
  #    $volume_name = $volume_name . $inventory_host{"HOST GROUP"}{$group}{LUN}{$volume}{"LUN ID"} . " ";
  #  }
  #
  #  if (defined $group_name && defined $host_name && $group_name ne "" && $host_name ne "" && defined $port_name && $port_name ne "" && defined $volume_name && $volume_name ne ""){
  #    $group_name =~ s/^\s+|\s+$//g;
  #    $host_name =~ s/^\s+|\s+$//g;
  #    $port_name =~ s/^\s+|\s+$//g;
  #    $volume_name =~ s/^\s+|\s+$//g;
  #    push(@cfg_mapping,"$group_name,$host_name,$port_name,$volume_name\n");
  #  }
  #}

  ### end mapping per host group ###


  foreach my $host (keys %{$volumes{"HOST"}}){
    foreach my $group (keys %{$inventory_host{"HOST GROUP"}}){
      if (defined $inventory_host{"HOST GROUP"}{$group}{HOST}{$host}{"HOST NAME"}){
        #print $inventory_host{"HOST GROUP"}{$group}{HOST}{$host}{"HOST NAME"} . "\n";
        if (defined $inventory_host{"HOST GROUP"}{$group}{"GROUP NAME"}){
          $volumes{HOST}{$host}{GROUP}{$group}{"GROUP NAME"} = $inventory_host{"HOST GROUP"}{$group}{"GROUP NAME"};
        }
        foreach my $port (keys %{$inventory_host{"HOST GROUP"}{$group}{PORT}}){
          if (defined $inventory_host{"HOST GROUP"}{$group}{PORT}{$port}{"PORT NAME"}){
            $volumes{HOST}{$host}{PORT}{$port}{"PORT NAME"} = $inventory_host{"HOST GROUP"}{$group}{PORT}{$port}{"PORT NAME"};
          }
        }
      }
    }
  }
  #print Dumper \%volumes;
  ### mapping per host ###

  foreach my $host (keys %{$volumes{"HOST"}}){
    if (!defined $volumes{"HOST"}{$host}{"HOST NAME"}){next;}
    $host_name = $volumes{"HOST"}{$host}{"HOST NAME"};
    $group_name = "";
    $port_name = "";
    $volume_name = "";
    #print "$group_name\n";
    foreach my $group (keys %{$volumes{"HOST"}{$host}{"GROUP"}}){
      if (!defined $volumes{"HOST"}{$host}{GROUP}{$group}{"GROUP NAME"}){next;}
      if ($volumes{"HOST"}{$host}{GROUP}{$group}{"GROUP NAME"} eq "GROUP_UNIQUE007ZAJD"){next;} ### skip unique group ###
      $group_name = $group_name . $volumes{"HOST"}{$host}{GROUP}{$group}{"GROUP NAME"} . " ";
      #print "$host_name $group_name\n";
    }

    foreach my $port (keys %{$volumes{"HOST"}{$host}{"PORT"}}){
      if (!defined $volumes{"HOST"}{$host}{PORT}{$port}{"PORT NAME"}){next;}
      $port_name = $port_name . $volumes{"HOST"}{$host}{PORT}{$port}{"PORT NAME"} . " ";
      #print "$host_name $group_name\n";
    }

    foreach my $volume (keys %{$volumes{"HOST"}{$host}{"LUN"}}){
      if (!defined $volumes{"HOST"}{$host}{LUN}{$volume}{"LUN ID"}){next;}
      $volume_name = $volume_name . $volumes{"HOST"}{$host}{LUN}{$volume}{"LUN ID"} . " ";
      #print "$host_name $group_name\n";
    }

    if (!defined $group_name || $group_name eq ""){
      $group_name = "";
    }

    if (!defined $port_name || $port_name eq ""){
      $port_name = "";
    }
    if (!defined $volume_name || $volume_name eq ""){
      $volume_name = "";
    }

    if ( defined $host_name && $host_name ne ""){
      $group_name =~ s/^\s+|\s+$//g;
      $host_name =~ s/^\s+|\s+$//g;
      $port_name =~ s/^\s+|\s+$//g;
      $volume_name =~ s/^\s+|\s+$//g;
      push(@cfg_mapping,"$host_name,$group_name,$port_name,$volume_name\n");
    }

  }

  ### mapping per host old ###


  #print Dumper \%inventory_host;
  #print Dumper \%volumes;
  #print Dumper \@cfg_mapping;
  #my @cfg_pom;
  #foreach my $volume (keys %{$volumes{"HOST"}}){
  #  if (defined $volumes{"HOST"}{$volume}){
  #    my $name_host = $volumes{"HOST"}{$volume}{"HOST NAME"};
  #    my $group_name = "";
  #    my $port_name = "";
  #    my $volume_name = "";
  #    my $group_names = "";
  #    my $port_names = "";
  #    my $volume_names = "";
  #    foreach my $line (@cfg_mapping){
  #      chomp $line;
  #      #print $name_host . "\n";
  #      #$name_host = "$name_host";
  #      #print "$name_host\n";
  #      if ($line =~ /$name_host/){
  #        ( $group_name,undef,$port_name,$volume_name) = split (",",$line);
  #        #push(@cfg_pom,"$name_host,$group_name,$port_name,$volume_name\n");
  #        $group_names = $group_names . $group_name . " ";
  #        if ($port_names !~ /$port_name/){
  #          $port_names = $port_names . $port_name . " ";
  #        }
  #        if ($volume_names !~ /$volume_name/){
  #          $volume_names = $volume_names . $volume_name . " ";
  #        }
  #
  #      }
  #    }
  #    if (defined $group_names && defined $name_host && $group_names ne "" && $name_host ne "" && defined $port_names && $port_names ne "" && defined $volume_names && $volume_names ne "" ){
  #      $group_names =~ s/^\s+|\s+$//g;
  #      $port_names =~ s/^\s+|\s+$//g;
  #      $volume_names =~ s/^\s+|\s+$//g;
  #      push(@cfg_pom,"$name_host,$group_names,$port_names,$volume_names\n");
  #    }
  #
  #  }
  #}
  #@cfg_mapping = @cfg_pom;
  #print Dumper \@cfg_mapping;
  return @cfg_mapping;

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

sub create_config_rg{
  my $file_rg = "$config_directory/config-RG.csv";
  `"$HUS_CLIDIR/auconfigreport" -unit "$STORAGE_NAME" -filetype csv -resource rg -file "$file_rg"`;
  my $test = test_file_exist($file_rg);
  if ($test){
    return "$file_rg";
  }
  else{
    $file_rg = "$config_directory/config-RG.txt";
    `"$HUS_CLIDIR/auconstitute" -unit "$STORAGE_NAME" -export -config "$file_rg" -rgdplu`;
    return "$file_rg";
  }
}

sub get_value_rg{

### check rg if Not Avaible then list rg form create_config() else select the best commands for all rg;
  my $file = create_config_rg();
  my @config;
  my $file_name = "config-RG.txt";
  my $i =1;
  my $index_rg;
  open( FH, "< $file" ) || error_die( "Cannot read $file: $!" . __FILE__ . ":" . __LINE__ ) && exit 0;
  my @cfg = <FH>;
  close(FH);
  if ($file =~ /$file_name/){
    foreach my $line (@cfg){
      chomp $line;
      $line =~ s/^\s+|\s+$//g;
      if ($line =~ /DP RAID Configuration/){
        $i = 2;
        next;
      }
      if ($line eq ""){next;}
      if ($line =~ /End/ && $i == 2){
        return @config;
      }
      if ($i == 2 && $line =~ /RAID/){
        my @header = split (" ",$line);
        my $index = -1;
        foreach my $element (@header){
          #print "$element\n";
          chomp $element;
          $index++;
          $element =~ s/^\s+|\s+$//g;
          if ($element eq "RAID"){
            $index_rg = $index;
            last;
          }
        }
      }
      if (defined $index_rg && $i == 2 && $line !~ /RAID|Pool/){
        my @header = split (" ",$line);
        my $index = -1;
        foreach my $element (@header){
          #print "$element\n";
          chomp $element;
          my $id = $header[$index_rg];
          push(@config,",$id,,,,,,,,,,,,,,,,\n");
          last;
        }
      }

    }
    return @config;
  }
  else{
    #my %rg_capacite;
    my $header = 1;
    my $index_rg;
    my $index_total_cap;
    my $index_free_cap;
    my $index_status;
    my $rg_id;
    my $rg_total;
    my $rg_used;
    my $rg_free;
    my $rg_status;
    foreach my $line (@cfg){
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
          if ($element eq "Status"){
            $index_status = $index;
            next;
          }
          if (defined $index_free_cap && defined $index_total_cap && defined $index_rg && defined $index_status){
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
        $rg_status = $value[$index_status];
        if ($rg_total =~ /TB/){
          $rg_total =~ s/TB//g;
          $rg_total =~ s/^\s+|\s+$//g;
          #print "$rg_total\n";
          $rg_total = $rg_total * 1024;
        }
        if ($rg_total =~ /PB/){
          $rg_total =~ s/PB//g;
          $rg_total =~ s/^\s+|\s+$//g;
          $rg_total = $rg_total * 1024 * 1024;
        }
        if ($rg_total =~ /GB/){
          $rg_total =~ s/GB//g;
          $rg_total =~ s/^\s+|\s+$//g;
        }
        if ($rg_total =~ /MB/){
          $rg_total =~ s/MB//g;
          $rg_total =~ s/^\s+|\s+$//g;
          $rg_total = $rg_total / (1024);
          $rg_total = round($rg_total);
        }
        if ($rg_free =~ /TB/){
          $rg_free =~ s/TB.*//g;
          $rg_free =~ s/^\s+|\s+$//g;
          $rg_free = $rg_free * 1024;
          $rg_used = $rg_total - $rg_free;
        }
        if ($rg_free =~ /PB/){
          $rg_free =~ s/PB.*//g;
          $rg_free =~ s/^\s+|\s+$//g;
          $rg_free = $rg_free * 1024 * 1024;
          $rg_used = $rg_total -$rg_free;
        }
        if ($rg_free =~ /GB/){
          $rg_free =~ s/GB.*//g;
          $rg_free =~ s/^\s+|\s+$//g;
          $rg_used = $rg_total - $rg_free;
        }
        if ($rg_free =~ /MB/){
          $rg_free =~ s/MB.*//g;
          $rg_free =~ s/^\s+|\s+$//g;
          $rg_free = $rg_free / (1024);
          $rg_free = round($rg_free);
          $rg_used = $rg_total - $rg_free;
        }
        if ( index($rg_free,"(") > -1){
          $rg_free = 0;
          $rg_used = $rg_total;
        }
      }
      if (defined $rg_total && defined $rg_free && defined $rg_used ){
        push(@config,",$rg_id,$rg_status,,,$rg_total,,$rg_free,,$rg_used,,,,,,,,\n");
      }
    }
    return @config;
  }
}



sub get_value_lun{
  my $file = create_config_lu();
  my @config;
  my $i =1;
  open( FH, "< $file" ) || error_die( "Cannot read $file: $!" . __FILE__ . ":" . __LINE__ ) && exit 0;
  my @cfg = <FH>;
  close(FH);

  foreach my $line(@cfg){
    chomp $line;
    if ($i == 1){$i++; next;}
    my @config_line = split(",",$line);
    #print "@config_line\n";
    push(@config,"$config_line[0],");   ### lun id
    push(@config,",");                 ### id
    push(@config,",");                 ### lun name
    push(@config,",,,");
    my $id_rg = $config_line[3];
    #print "$config_line[4]\n";
    my $id_pool = $config_line[4];
    if ($id_pool ne "N/A" && $id_pool ne "n/a" && $id_pool ne "na" && $id_pool ne "NA"){
      push(@config,"$id_pool,");
      #$more_id = 1;
    }
    else{
      push(@config,",");
    }
    #push(@config,"$config_line[4],");   ### pool id
    push(@config,",");                 ### pool name
    if ($config_line[1] =~ /TB/){
      my $capacity = $config_line[1];
      $capacity =~ s/TB//g;
      $capacity = $capacity * (1024 * 1024);
      $capacity =~ s/^\s+|\s+$//g;
      push(@config,"$capacity,");   ### capacity
    }
    if ($config_line[1] =~ /PB/){
      my $capacity = $config_line[1];
      $capacity =~ s/PB//g;
      $capacity = $capacity * (1024 * 1024 * 1024);
      $capacity =~ s/^\s+|\s+$//g;
      push(@config,"$capacity,");   ### capacity
    }

    if ($config_line[1] =~ /GB/){
      my $capacity = $config_line[1];
      $capacity =~ s/GB//g;
      $capacity = $capacity * 1024;
      $capacity =~ s/^\s+|\s+$//g;
      push(@config,"$capacity,");   ### capacity
    }
    if ($config_line[1] =~ /MB/){
      my $capacity = $config_line[1];
      $capacity =~ s/MB//g;
      $capacity =~ s/^\s+|\s+$//g;
      push(@config,"$capacity,");   ### capacity
    }
    push(@config,",,,,,,,,,,,");
    #print "ahoj\n";
    #$lun_interface{$config_line[0]}{NAME} = $config_line[0];
    #$lun_interface{$config_line[0]}{INTERFACE} = $config_line[6];
    push(@config,"$config_line[6],");  ### interface_type
    if ($id_rg ne "N/A" && $id_rg ne "n/a" && $id_rg ne "na" && $id_rg ne "NA"){
      push(@config,"$id_rg\n");
      #$more_id = 1;
    }
    else{
      push(@config,"\n");
    }
  }

  return @config;
}

sub get_value_host{
  my $file = create_config_host1();
  my $file2 = create_config_host2();
  open( FH, "< $file" ) || error_die( "Cannot read $file: $!" . __FILE__ . ":" . __LINE__ ) && exit 0;
  my @cfg1 = <FH>;
  close(FH);
  open( FH, "< $file2" ) || error_die( "Cannot read $file: $!" . __FILE__ . ":" . __LINE__ ) && exit 0;
  my @cfg2 = <FH>;
  close(FH);
  my $active = 0;
  my $header = 0;
  my $count_group;
  my $count_host;
  my $count_line;
  my $port_name;

  my $end_host;
  my $start_host;
  my $start_host_group;
  my $end_host_group;
  my $start_host_without_group;
  my $end_host_without_group;

  foreach my $line (@cfg1){
    chomp $line;
    if ($line =~ /Host Group/ && $header == 1){
      #my $new_way = $line;
      my $pom_line = $line;
      $line =~ s/^\s+|\s+$//g;
      #my $line_group = $line;
      #my $line_host = $line;
      #$count_line = length($line);
      #$line_group =~ s/Host Group//g;
      #$count_group = length($line_group);
      #my $line_host = $line_group;
      #$line_host =~ s/^\s+|\s+$//g;
      #$line_host =~ s/Port Name//;
      #$count_host = length($line_host);
      #$count_host = $count_line - $count_host;

      $end_host = index($pom_line, "Port Name") - 1;
      $start_host = 0;
      $start_host_group = index($pom_line,"Host Group");
      $end_host_group = length($pom_line);

    }
    if ($line =~ /Name/ && $header == 2){
      $start_host_without_group = 0;
      $end_host_without_group = index($line,"Port Name") - 1;
      next;
    }
    if ($line =~ /^Port/ ){
      $active = 0;
      $header = 0;
      my $select_port_name = $line;
      $select_port_name =~ s/Port//;
      $select_port_name =~ s/^\s+|\s+$//g;
      if ( index($select_port_name,"Host Group") > -1){
        my $end_port_name = index ($select_port_name, "Host Group");
        $end_port_name--;
        $port_name = substr($select_port_name,0,$end_port_name);
        $port_name =~ s/^\s+|\s+$//g;
      }
      next;
    }
    if ($line =~ /Assigned/){
      $active = 1;
      $header = 1;
      next;
    }
    if ($line =~ /Name/ || $line =~ /Assignable/ || $line eq "" ){
      $header = 0;
      next;
    }
    if ($line =~ /Detected/){
      $header = 2;
      $active = 2;
      next;
    }
    if ($active == 2){
      my $len = length($line);
      my $name_group = "GROUP_UNIQUE007ZAJD";
      if ($len <= $start_host_without_group ){next;}
      my $host_name =  substr($line,$start_host_without_group,$end_host_without_group);
      if (!defined $host_name) {next;}
      $host_name =~ s/^\s+|\s+$//g;
      if ($host_name eq ""){next;}

      if (!defined  $inventory_host{"HOST GROUP"}{$name_group}{"GROUP NAME"}){
        $inventory_host{"HOST GROUP"}{$name_group}{"GROUP NAME"} = $name_group;
      }
      if (!defined  $inventory_host{"HOST GROUP"}{$name_group}{HOST}{$host_name}{"HOST NAME"}){
        $inventory_host{"HOST GROUP"}{$name_group}{HOST}{$host_name}{"HOST NAME"} = $host_name;
      }
       if (defined $port_name && $port_name ne ""){
        if(!defined $inventory_host{"HOST GROUP"}{$name_group}{"PORT"}{$port_name}{"PORT NAME"}){
          $inventory_host{"HOST GROUP"}{$name_group}{"PORT"}{$port_name}{"PORT NAME"} = $port_name;
        }
      }
    }
    if ($active == 1){
      #$line =~ s/^\s+|\s+$//g;
      #print "$line\n";
      #my $test_all = $line;
      #$test_all =~ s/\s+/ /g;
      #my @value = split(" ",$line);
      #if (!defined $value[2]){next;}
      $count_line = length($line);
      #print "$count_line a $count_group\n";
      #if ($count_line < $count_group){next;}
      #if (0 > $count_host){next;}
      if ($count_line <= $start_host_group ){next;}
      if ($count_line <= $start_host ){next;}
      my $name_group = substr($line,$start_host_group,$end_host_group);
      my $name_host =  substr($line,$start_host,$end_host);
      #print "$name_group and $name_host\n";
      if (!defined $name_group  || !defined $name_host){next;}
      $name_group =~ s/^\s+|\s+$//g;
      $name_host =~ s/^\s+|\s+$//g;
      $name_group = "$name_group";
      $name_host = "$name_host";
      if ($name_group eq "" || $name_host eq ""){next;}
      #print "$name_group and $name_host\n";
      if (!defined  $inventory_host{"HOST GROUP"}{$name_group}{"GROUP NAME"}){
	$inventory_host{"HOST GROUP"}{$name_group}{"GROUP NAME"} = $name_group;
      }
      if (!defined  $inventory_host{"HOST GROUP"}{$name_group}{HOST}{$name_host}{"HOST NAME"}){
        $inventory_host{"HOST GROUP"}{$name_group}{HOST}{$name_host}{"HOST NAME"} = $name_host;
      }
      ### port name ### port name from config-HOST1.txt
      if (defined $port_name && $port_name ne ""){
        if(!defined $inventory_host{"HOST GROUP"}{$name_group}{"PORT"}{$port_name}{"PORT NAME"}){
          $inventory_host{"HOST GROUP"}{$name_group}{"PORT"}{$port_name}{"PORT NAME"} = $port_name;
        }
      }
    }
  }
  $active = 0;
  my $len_lun;
  my $end_port;
  my $end_group;
  my $start_group;
  foreach my $line (@cfg2){
    chomp $line;
    my $pom_line = $line;
    if ($line =~ /^Port/ ){
      $line =~ s/^\s+|\s+$//g;
      $line =~ s/LUN//g;
      #print "$line\n";
      $len_lun = length($line);
      #$line =~ s/H-//g;
      #$line =~ s/Group//g;


      #### separation PORT AND HOST GROUP

      $pom_line =~ s/^\s+|\s+$//g;
      #print "$pom_line\n";
      my $len_line = length($pom_line);
      $pom_line =~ s/Port//g;
      $pom_line =~ s/^\s+|\s+$//g;
      my $len_port = length($pom_line);
      #print "$len_line,$len_port\n";
      $end_port = $len_line - $len_port - 1;
      #print "$pom_line\n";

      $start_group = $end_port + 1;
      $len_line = length($pom_line);
      $pom_line =~ s/Group//g;
      $pom_line =~ s/^\s+|\s+$//g;
      my $len_group = length($pom_line);
      $end_group = $len_line - $len_group;



      $active = 1;
      next;
    }
    if ($line eq ""){next;}
    if ($active == 1){
      if ($line eq ""){next;}
      $line =~ s/^\s+|\s+$//g;
      my $len_line = length($line);
      my $lun_id = substr($line,$len_lun,$len_line);
      $lun_id =~ s/^\s+|\s+$//g;
      $lun_id = "$lun_id";
      my $name_group = "";

      ### Port mapping ### 

      my $name_port = substr($pom_line,0,$end_port);
      $name_port =~ s/^\s+|\s+$//g;
      #print "$end_port\n";
      #print "$end_port,$end_group\n";
      #print "$name_port\n";
      my $name_group_host = substr($pom_line,$start_group,$end_group);
      $name_group_host =~ s/^\s+|\s+$//g;

      foreach my $find_group (keys %{$inventory_host{"HOST GROUP"}}){
        #print $inventory_host{"HOST GROUP"}{$find_group}{"GROUP NAME"} . "\n";
        if ($inventory_host{"HOST GROUP"}{$find_group}{"GROUP NAME"} eq $name_group_host){
          $name_group = $inventory_host{"HOST GROUP"}{$find_group}{"GROUP NAME"};
          last;
        }
      }
      #print "$lun_id a $name_group\n";
      if ($name_group eq "" || $lun_id eq ""){next};
      #print "$lun_id a $name_group\n";
      #$line =~ s/\s+/ /g;
      #my @value = split(" ",$line);
      #my $name_group = $value[1];
      #my $lun_id = $value[3];
      foreach my $group (keys %{$inventory_host{"HOST GROUP"}}){
        if ($name_group eq  $inventory_host{"HOST GROUP"}{$group}{"GROUP NAME"}){
          if(!defined $inventory_host{"HOST GROUP"}{$group}{LUN}{$lun_id}{"LUN ID"}){
            $inventory_host{"HOST GROUP"}{$group}{LUN}{$lun_id}{"LUN ID"} = $lun_id;
            $name_group = "";
          }
          if(!defined $inventory_host{"HOST GROUP"}{$group}{"PORT"}{$name_port}{"PORT NAME"}){
            $inventory_host{"HOST GROUP"}{$group}{"PORT"}{$name_port}{"PORT NAME"} = $name_port;
          }
        }
      }
    }
  }
  my %host_lun;
  my @host_value;
  foreach my $group (keys %{$inventory_host{"HOST GROUP"}}){
    foreach my $host (keys %{$inventory_host{"HOST GROUP"}{$group}{HOST}}){
      if (!defined $host_lun{"HOST"}{$host}{"HOST NAME"}){
        $host_lun{"HOST"}{$host}{"HOST NAME"} = $host;
      }
      foreach my $lun (keys %{$inventory_host{"HOST GROUP"}{$group}{LUN}}){
        if (!defined $host_lun{"HOST"}{$host}{"LUN"}{$lun}{"LUN ID"}){
          $host_lun{"HOST"}{$host}{"LUN"}{$lun}{"LUN ID"} = $lun;
        }
      }
    }
  }
  #print Dumper \%inventory_host;
  #print Dumper \%host_lun;
  %volumes = %host_lun;
  foreach my $host (keys %{$host_lun{"HOST"}}){
    my $name_host = $host_lun{"HOST"}{$host}{"HOST NAME"};
    #print $name_host . "\n";
    my $lun_ids = "";
    foreach my $lun (keys %{$host_lun{"HOST"}{$host}{"LUN"}}){
        if(defined $host_lun{"HOST"}{$host}{"LUN"}{$lun}{"LUN ID"}){
          my $lun_id =  $host_lun{"HOST"}{$host}{"LUN"}{$lun}{"LUN ID"};
          $lun_ids = $lun_ids . "$lun_id ";
          #print "$lun_ids\n";
        }
      }
    chop $lun_ids;
    push(@host_value,",,$name_host,,,,,$lun_ids,\n");
  }
  return @host_value;
}

sub get_name_conf_file{
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
  my $name_file = "$dir/$STORAGE_NAME". "_" . "husconf" . "_" ."$year$month$day" . "_" . "$hour$minute" . ".out-tmp";
  $output_file = "$dir/$STORAGE_NAME". "_" . "husconf" . "_" ."$year$month$day" . "_" . "$hour$minute" . ".out";
  #print "$name_file\n";
  return $name_file;

}

### main function ###
#check_pool();




my $output = get_name_conf_file();
open(DATA, ">$output") or error_die ("Cannot open file: $output : $!");

### header configuration ###

print DATA "$header_config\n";
print DATA get_separator($header_config);
print DATA get_header_cfg();
#######

### section LUN ###
my $header_lun = "Volume Level Configuration\n";
my $header_lun_value = "lun_id,,,,,,pool_id,,capacity (MB),,,,,,,,,,,,interface_type,raid_group_id\n";

print DATA "\n";
print DATA "$header_lun";
print DATA get_separator($header_lun);
print DATA $header_lun_value;
print DATA get_value_lun();
#print DATA get_value_volume();
#print DATA get_value_lun();

###

### section VOLUME TEST ###
#get_value_volume();
#print DATA get_value_volume();



### section PORT ###
my $header_port = "Port Level Configuration\n";
my $header_port_value = ",,name,,,,,,\n";

print DATA "\n";
print DATA "$header_port";
print DATA get_separator($header_port);
print DATA $header_port_value;
print DATA get_value_port();
###


### section POOL ###
### not has got pool
if (get_value_pool() ne 0){
  my $header_pool = "Pool Level Configuration\n";
  my $header_pool_value = ",id,status,,,capacity (GB),,free_capacity (GB),,used_capacity (GB),,,,,,,,\n";

  print DATA "\n";
  print DATA "$header_pool";
  print DATA get_separator($header_pool);
  print DATA $header_pool_value;
  print DATA get_value_pool();
}
###


### section RG ###
my $header_rg = "Raid Group Level Configuration\n";
my $header_rg_value = ",id,status,,,capacity (GB),,free_capacity (GB),,used_capacity (GB),,,,,,,,\n";

print DATA "\n";
print DATA "$header_rg";
print DATA get_separator($header_rg);
print DATA $header_rg_value;
print DATA get_value_rg();
###

### section HOST ###
my $header_host = "Host Level Configuration\n";
my $header_host_value = ",,name,,,,,Volume IDs,\n";

print DATA "\n";
print DATA "$header_host";
print DATA get_separator($header_host);
print DATA $header_host_value;
print DATA get_value_host();

### section “Port mapping ###

my $header_port_map = "Port-Mapping Level Configuration\n";
my $header_port_map_value = "Host,Host Group,Ports,Volumes\n";

print DATA "\n";
print DATA "$header_port_map";
print DATA get_separator($header_port_map);
print DATA $header_port_map_value;
print DATA get_value_mapping_port();
close DATA;


rename ("$output", "$output_file");


###

sub error_die
{
  my $message = shift;
  print STDERR "$message\n";
  exit (1);
}




