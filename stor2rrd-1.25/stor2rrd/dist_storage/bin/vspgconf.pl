#!/usr/bin/perl


use strict;
use warnings;
use Data::Dumper;
no warnings 'portable';


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
#my $login = "lukas";
#my $paswd = "zajda007";


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
my $paswd = $ENV{PW};
my $cli_dir= $ENV{VSP_CLIDIR};

my $output_file;
my $file_tmp = get_name_conf_file();
my @volumes;
my @mapping;





### MAIN FUNCTION ###
my $act_directory = localtime();
my @entry_time = split(" ",$act_directory);
(undef, my $active_minute, undef) =  split(":",$entry_time[3]);
$config_directory = "$configuration/$active_minute";


set_configuration_header();
`raidcom -login $login $paswd -I1`;
set_data_port();
set_data_rg();
set_data_ldev();
set_data_host();
set_data_volume();
`raidcom -logout -I1`;
set_data_mapping();

rename ("$file_tmp", "$output_file");




###

sub get_name_conf_file{
  my $dir = "$wrkdir"; ### for testing
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
  my $name_file = "$dir/$STORAGE_NAME". "_" . "vspgconf" . "_" ."$year$month$day" . "_" . "$hour$minute" . ".out-tmp";
  $output_file = "$dir/$STORAGE_NAME". "_" . "vspgconf" . "_" ."$year$month$day" . "_" . "$hour$minute" . ".out";
  #print "$name_file\n";
  return $name_file;

}

sub get_separator{
  my $header = shift;
  my $count = length($header);
  my $separator;
  for (my $i=0;$i<$count;$i++){
    $separator = $separator . "-";
  }
  return "$separator";
}

sub set_data_port{
  my $file_port = create_port_file();
  my $section = "Port Level Configuration";
  my $header = ",,name,,,,,,";
  my $metric = "PORT,TYPE,ATTR";


  my @data = get_data_port($file_port,$section,$metric);
  set_write_data($section,$header,\@data);

}

sub create_port_file{
  my $file = "$config_directory/config-PORT.txt";
  #`raidcom -login $login $paswd -I1`;
  `raidcom get port -I1 > "$file"`;
  #`raidcom -logout -I1`;
  return $file;
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


sub set_data_rg{
  my $file_rg = create_parity_gr_file();
  my $file_rg2 = create_parity_gr_file2();
  my $section = "Raid Group Level Configuration";
  my $metric = "T,GROUP,Num_LDEV,U(%),AV_CAP(GB),R_LVL,R_TYPE,SL,CL,DRIVE_TYPE";
  my $header = ",id,status,,,capacity (GB),,free_capacity (GB),,used_capacity (GB),,,,,,,,";
  my @data = get_data_rg($file_rg,$file_rg2,$section,$metric);
  set_write_data($section,$header,\@data);

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

sub get_data_volume{
  my ($file,$metric,$section) = @_;
  my @data = get_array_data($file);
  my %header;
  my $key_header = "LU#";
  my @metrics = split (",",$metric);
  my @lu;

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
              my $active = 0;
              foreach my $row (@lu){
                my @element = split (",",$row);
                if ("$element[0]" eq "$lun"){
                  $active = 1;
                }
              }
              if ($active == 0){
                push(@lu,"$lun,,,,,,,,$cap_total,,,,,,,,,,,,,\n");
              }
            }
          }
        }
      }
    }
  }
  return @lu;
}

sub set_data_volume{
  my $file = create_volume_file();
  my $section = "Volume Level Configuration";
  my $header = "lun_id,,,,,,pool_id,,capacity (MB),,,,,,,,,,,,interface_type,raid_group_id";
  my $metric = "PORT#,/ALPA/C,TID#,LU#,Seq#,Num,LDEV#,Used(MB),LU_CAP(MB),U(%),T(%),PID";
  my @lun = get_data_volume($file,$metric,$section);
  set_write_data($section,$header,\@lun);


}

sub set_data_mapping{
  my $section = "Port-Mapping Level Configuration";
  my $header = "Host,Host Group,Ports,Volumes";
  set_write_data($section,$header,\@mapping);
}

sub set_data_host{
  my $file_host = create_host1_file();
  my $section = "Host Level Configuration";
  my $header = ",,name,,,,,Volume IDs,";
  #my $metric = "PORT,GID,HMD,LUN,NUM,LDEV,CM,Serial#,HMO_BITs";
  my $metric = "PORT,GID,GROUP_NAME,Serial#,HDM,HMO_BITs";

  my %host = get_data_host_cfg1($file_host,$section,$metric);
  $file_host = create_host2_file();
  $metric = "PORT,GID,HMD,LUN,NUM,LDEV,CM,Serial#,HMO_BITs";

  my %host2 = get_data_host_cfg2($file_host,$section,$metric,\%host);
  $file_host = create_host3_file();
  $metric = "PORT,GID,GROUP_NAME,HWWN,Serial#,NICK_NAME";

  my %host3 = get_data_host_cfg3($file_host,$section,$metric,\%host2);

  my @data = get_data_host_cfg4(\%host3,$section);
  set_write_data($section,$header,\@data);

}

sub create_host1_file{
  my $file = "$config_directory/config-HOST1.txt";
  delete_file($file);
  my $file_in = "$config_directory/config-PORT.txt";
  my @array = get_array_data($file_in);
  #`raidcom -login $login $paswd -I1`;
  foreach my $line (@array){
    chomp $line;
    if ($line eq ""){next;}
    $line = remove_whitespace($line);
    if ($line =~ /TAR/){
      my @elements = split(" ",$line);
      $elements[0] = remove_whitespace($elements[0]);
      `raidcom get host_grp -port $elements[0] -I1 >> "$file"`;
    }
  }
  #`raidcom -logout -I1`;
  return $file;
}

sub delete_file{
  my $file = shift;
  if ( -e $file ){
    #unlink "$file" or  error_die ("Unable to unlink $file: $!");
  }

}

sub create_host2_file{
  my $file = "$config_directory/config-HOST2.txt";
  delete_file($file);
  my $file_in = "$config_directory/config-HOST1.txt";
  my @array = get_array_data($file_in);
  #`raidcom -login $login $paswd -I1`;
  foreach my $line (@array){
    chomp $line;
    if ($line eq ""){next;}
    $line = remove_whitespace($line);
    if (! (index($line,"GROUP_NAME") > -1)){
      my @elements = split(" ",$line);
      $elements[0] = remove_whitespace($elements[0]);
      $elements[2] = remove_whitespace($elements[2]);
      my $port = "$elements[0] $elements[2]";
      `echo $port >> "$file"`;
      `raidcom get lun -port $port -I1 >> "$file"`;
    }
  }
  #`raidcom -logout -I1`;
  return $file;
}

sub create_host3_file{
  my $file = "$config_directory/config-HOST3.txt";
  delete_file($file);
  my $file_in = "$config_directory/config-HOST1.txt";
  my @array = get_array_data($file_in);
  #`raidcom -login $login $paswd -I1`;
  foreach my $line (@array){
    chomp $line;
    if ($line eq ""){next;};
    $line = remove_whitespace($line);
    if (! (index($line,"GROUP_NAME") > -1)){
      my @elements = split(" ",$line);
      $elements[0] = remove_whitespace($elements[0]);
      $elements[2] = remove_whitespace($elements[2]);
      my $port = "$elements[0] $elements[2]";
      `echo $port >> "$file"`;
      `raidcom get hba_wwn -port $i -I1 > "$file"`;
    }
  }
  #`raidcom -logout -I1`;
  return $file;
}


sub get_data_host_cfg4{
  my ($tmp_host,$section) = @_;
  my %host = %{$tmp_host};
  my %host_inventory;
  my $name_host = "";
  my $id_luns = "";
  my @hosts;
  my @vol;

  foreach my $port (keys %{$host{$section}{PORT}}){
    foreach my $group (keys %{$host{$section}{PORT}{$port}{GROUP}}){
      foreach my $host (keys %{$host{$section}{PORT}{$port}{GROUP}{$group}{HOST}}){
        #print $host . "\n";
        if (!defined $host_inventory{$section}{HOST}{$host}){
          $host_inventory{$section}{HOST}{$host}{NAME} = $host;
          $name_host = $host;
        }
        else{
          $name_host = $host;
        }
        if (!defined $host_inventory{$section}{HOST}{$name_host}{GROUP}{$group}){
          $host_inventory{$section}{HOST}{$name_host}{GROUP}{$group}{NAME} = $group;
        }
        if (!defined $host_inventory{$section}{HOST}{$name_host}{PORT}{$port}){
          $host_inventory{$section}{HOST}{$name_host}{PORT}{$port}{NAME} = $port;
        }

        foreach my $lun (keys %{$host{$section}{PORT}{$port}{GROUP}{$group}{LUN}}){
          if (!defined $host_inventory{$section}{HOST}{$name_host}{LUN}{$lun} && $name_host ne ""){
            $host_inventory{$section}{HOST}{$name_host}{LUN}{$lun}{ID} = $lun;
          }
        }
      }
    }
  }
  $name_host = "";

  foreach my $host (keys %{$host_inventory{$section}{HOST}}){
    if (defined $host_inventory{$section}{HOST}{$host}{NAME}){
      $name_host = $host_inventory{$section}{HOST}{$host}{NAME};
    }
    else{
      next;
    }

    foreach my $lun (keys %{$host_inventory{$section}{HOST}{$host}{LUN}}){
      my $id_lun = "";
      if (defined $host_inventory{$section}{HOST}{$host}{LUN}{$lun}{ID}){
        $id_lun = $host_inventory{$section}{HOST}{$host}{LUN}{$lun}{ID};
      }
      if ($id_lun ne ""){
        $id_luns = $id_luns . " " . $id_lun;
        if (!grep { $id_lun == $_ } @vol) {
          #push(@volumes,"$id_lun,,,,,,,,,,,,,,,,,,,,,\n"); ### seznam volumes
          push(@vol,$id_lun);
        }
      }
    }
    if ($name_host ne ""){
      $id_luns =~ s/ //;
      push (@hosts,",,$name_host,,,,,$id_luns,\n");
      $id_luns = "";
      $name_host = "";
    }
  }
  my @sort_volumes = sort { $a <=> $b } @vol;
  foreach my $id_volume (@sort_volumes){
    push(@volumes,"$id_volume,,,,,,,,,,,,,,,,,,,,,\n"); ### seznam volumes
  }

  ### section Mapping
  my $inv_lun = "";
  my $inv_port = "";
  my $inv_grp =  "";
  my $inv_host = "";


  foreach my $host (keys  %{$host_inventory{$section}{HOST}}){
    if (!defined $host_inventory{$section}{HOST}{$host}{NAME}){
      next;
    }
    else{
      $inv_host = $host_inventory{$section}{HOST}{$host}{NAME};
    }

    foreach my $group (keys %{$host_inventory{$section}{HOST}{$host}{GROUP}}){
      if (!defined $host_inventory{$section}{HOST}{$host}{GROUP}{$group}{NAME}){
        next;
      }
      else{
        $inv_grp = $inv_grp . " " . $host_inventory{$section}{HOST}{$host}{GROUP}{$group}{NAME};
      }

    }

    foreach my $port (keys %{$host_inventory{$section}{HOST}{$host}{PORT}}){
      if (!defined $host_inventory{$section}{HOST}{$host}{PORT}{$port}{NAME}){
        next;
      }
      else{
        $inv_port = $inv_port . " " . $host_inventory{$section}{HOST}{$host}{PORT}{$port}{NAME};
      }

    }

     foreach my $lun (keys %{$host_inventory{$section}{HOST}{$host}{LUN}}){
      if (!defined $host_inventory{$section}{HOST}{$host}{LUN}{$lun}{ID}){
        next;
      }
      else{
        $inv_lun = $inv_lun . " " . $host_inventory{$section}{HOST}{$host}{LUN}{$lun}{ID};
      }

    }

    $inv_lun =~ s/ //;
    $inv_port =~ s/ //;
    $inv_grp =~ s/ //;

    if ($inv_host ne ""){
      push(@mapping,"$inv_host,$inv_grp,$inv_port,$inv_lun\n");
    }

    $inv_lun = "";
    $inv_port = "";
    $inv_grp =  "";
    $inv_host = "";

  }





  ###

  #print Dumper \@mapping;
  #print Dumper \%host_inventory;
  #print Dumper \@volumes;
  return @hosts;

}

sub get_data_host_cfg3{
  my ($file,$section,$metric,$tmp_host) = @_;
  my %host = %{$tmp_host};
  my @metrics = split(",",$metric);


  my @data = get_array_data($file);
  my %header;
  my $key_header = "PORT";
  my $group_name = "";

  foreach my $line (@data){
    chomp $line;
    if ($line eq ""){next;}
    #print "$line\n";
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
      my ($port, $group) = split (" ",$line);
      #my $group_name = "";
      my $nick = "";
      #my $port_name = "";
      if (!defined $host{$section}{PORT}{$port}{GROUP}{$group}{NAME}){
        delete($host{$section}{PORT}{$port}{GROUP}{$group}); ### odstranit spatne groupy ktere se tvori predchozi podminkou
        #print "radky z daty\n";
        if (defined $header{$section}){
          foreach my $id (sort { $a <=> $b} keys %{$header{$section}}){
            if (defined $header{$section}{$id}{LENGTH}){
              my $name = $header{$section}{$id}{NAME};
              if ($name ne "PORT" && $name ne "GROUP_NAME" && $name ne "NICK_NAME"){next;}
              my $start = $header{$section}{$id}{START};
              my $length = $header{$section}{$id}{LENGTH};
              if ($length eq "LAST"){
                $length = length $line;
              }
              if ($start == 0){$length--;}
              my $value = substr($line,$start,$length);
              $value = remove_whitespace($value);
              if ($name eq "PORT"){
                $port = $value;

              }
              #if ($name eq "GROUP_NAME"){
              #  $group = $value;
              #
              #}
              if ($name eq "NICK_NAME"){
                $nick = $value;

              }
              #print "$group_name ... $nick ... $port\n";
              if ($group_name ne "" && $nick ne ""  && $port ne ""){
                $host{$section}{PORT}{$port}{GROUP}{$group_name}{HOST}{$nick}{ID} = $nick;
                $nick = "";
                #$group = "";
                $port = "";
                last;
              }
            }
          }
        }
      }
      else{
        $group_name = $group;

      }

    }

  }
  #print Dumper \%header;
  #print Dumper \%host;
  return %host;


}

sub get_data_host_cfg2{
  my ($file,$section,$metric,$tmp_host) = @_;
  #my @data = @{$data_tmp};
  #my $file = shift;
  #my $section = shift;
  #my $metric = shift;
  my %host = %{$tmp_host};
  my @metrics = split(",",$metric);


  my @data = get_array_data($file);
  my %header;
  my $key_header = "PORT";
  my $group_name = "";

  foreach my $line (@data){
    chomp $line;
    if ($line eq ""){next;}
    #print "$line\n";
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
      ### port_name a $group_name dat nekde vys abychom vedeli hlavne do jake groupy to dat
      my ($port, $group) = split (" ",$line);
      my $lun_name = "";
      my $ldev_name = "";
      if (!defined $host{$section}{PORT}{$port}{GROUP}{$group}{NAME}){
        delete($host{$section}{PORT}{$port}{GROUP}{$group}); ### odstranit spatne groupy ktere se tvori predchozi podminkou
        #print "radky z daty\n";
        #print "$line\n";
        if (defined $header{$section}){
          foreach my $id (sort { $a <=> $b} keys %{$header{$section}}){
            if (defined $header{$section}{$id}{LENGTH}){
              my $name = $header{$section}{$id}{NAME};
              if ($name ne "PORT" && $name ne "LUN" && $name ne "LDEV"){next;}
              my $start = $header{$section}{$id}{START};
              my $length = $header{$section}{$id}{LENGTH};
              if ($start == 0){$length--;}
              my $value = substr($line,$start,$length);
              $value = remove_whitespace($value);
              if ($name eq "PORT"){
                $port = $value;

              }
              if ($name eq "LDEV"){
                $ldev_name = $value;

              }
              if ($name eq "LUN"){
                $lun_name = $value;

              }
              if ($lun_name ne "" && $ldev_name ne ""  && $port ne ""){
                $host{$section}{PORT}{$port}{GROUP}{$group_name}{LUN}{$lun_name}{ID} = $lun_name;
                $host{$section}{PORT}{$port}{GROUP}{$group_name}{LDEV}{$ldev_name}{ID} = $ldev_name;
                $lun_name = "";
                $ldev_name = "";
                last;
              }
            }
          }
        }
      }
      else{
        $group_name = $group;

      }

    }

  }
  #print Dumper \%host;
  return %host;

}

sub get_data_host_cfg1{
  my $file = shift;
  my $section = shift;
  my $metric = shift;
  my @metrics = split(",",$metric);

  my @data = get_array_data($file);
  my %header;
  my $key_header = "PORT";
  my %hash_host;
  my $port_name = "";

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
      if (defined $header{$section}){
        foreach my $id (sort { $a <=> $b} keys %{$header{$section}}){
          if (defined $header{$section}{$id}{LENGTH}){
            my $name = $header{$section}{$id}{NAME};
            if ($name ne "PORT" && $name ne "GROUP_NAME"){next;}
            my $start = $header{$section}{$id}{START};
            my $length = $header{$section}{$id}{LENGTH};
            if ($start == 0){$length--;}
            my $value = substr($line,$start,$length);
            $value = remove_whitespace($value);
            if ($name eq "PORT"){
              if (!defined $hash_host{$section}{PORT}{$value}{NAME}){
                $hash_host{$section}{PORT}{$value}{NAME} = $value;
                $port_name = $value;
              }
            }
            if ($name eq "GROUP_NAME" && $port_name ne ""){
              if (!defined $hash_host{$section}{PORT}{$port_name}{GROUP}{$value}{NAME}){
                $hash_host{$section}{PORT}{$port_name}{GROUP}{$value}{NAME} = $value;
              }
            }
          }
        }
      }
    }
  }
  #print Dumper \%hash_host;
  return %hash_host;

}

sub set_data_ldev{
  my $file_ldev = "$config_directory/config-LDEV.txt";
  my $section = "Ldev Level Configuration";
  my $header = "ldev_id,name,,,,,pool_id,,capacity (MB),,,,,,,,,,,,interface_type,raid_group_id,tier1 (MB),tier2 (MB),tier3 (MB)";
  my $metric = "LDEV,VOL_Capacity(BLK),F_POOLID,B_POOLID,LDEV_NAMING,Used_Block(BLK),TIER#1(MB),TIER#2(MB),TIER#3(MB),NUM_GROUP,RAID_GROUPs";

  my @data = get_data_ldev($file_ldev,$section,$metric);
  set_write_data($section,$header,\@data);


}

sub create_ldev_file{
  my $file = "$config_directory/config-LDEV.txt";
  #`raidcom -login $login $paswd -I1`;
  `raidcom get ldev -ldev_list defined -I1 > "$file"`;
  #`raidcom -logout -I1`;
  return $file;
}

sub get_data_ldev{
  my $file = shift;
  my $section = shift;
  my $metric = shift;
  my @metrics = split(",",$metric);

  my @data = get_array_data($file);
  my %header;
  my $key_header = "GROUP";
  my @array_ldev;
  my $active = 0;
  my $ldev_id = "";

  foreach my $line (@data){
    chomp $line;
    if ($line eq ""){
      $active = 0;
      $ldev_id = "";
      next;
    }
    $line = remove_whitespace($line);

    if ( index($line,"Serial") > -1){
      $active = 1;
      next;
    }
    foreach my $element (@metrics){
      if (index($line,$element) > -1 && $active == 1){

        my @array_line = split (":",$line);
        my $header_element = "";
        foreach my $array_element (@array_line){
          chomp $array_element;
          $array_element = remove_whitespace($array_element);
          if (index($array_element,$element) > -1) {
            $header_element = $array_element;
            next;
          }
          if ($header_element eq "LDEV"){
            $header{$section}{$array_element}{ID} = $array_element;
            $ldev_id = "$array_element";
            next;
          }
          if ($header_element eq "VOL_Capacity(BLK)" && $ldev_id ne ""){
            my $transfer_cap = ($array_element * 512)/(1024*1024);
            $array_element = round($transfer_cap);
            $header{$section}{$ldev_id}{CAPACITY} = $array_element;
            next;
          }
          if ($header_element eq "F_POOLID" && $ldev_id ne ""){
            $header{$section}{$ldev_id}{FPOOL_ID} = $array_element;
            next;
          }
          if ($header_element eq "B_POOLID" && $ldev_id ne ""){
            $header{$section}{$ldev_id}{BPOOL_ID} = $array_element;
            next;
          }
          if ($header_element eq "LDEV_NAMING" && $ldev_id ne ""){
            $header{$section}{$ldev_id}{NAME} = $array_element;
            next;
          }
          if ($header_element eq "Used_Block(BLK)" && $ldev_id ne ""){
            my $transfer_cap = ($array_element * 512)/(1024*1024);
            $array_element = round($transfer_cap);
            $header{$section}{$ldev_id}{USED_CAPACITY} = $array_element;
            next;
          }
          if ($header_element eq "TIER#1(MB)" && $ldev_id ne ""){
            $header{$section}{$ldev_id}{"TIER1(MB)"} = $array_element;
            next;
          }
          if ($header_element eq "TIER#2(MB)" && $ldev_id ne ""){
            $header{$section}{$ldev_id}{"TIER2(MB)"} = $array_element;
            next;
          }
          if ($header_element eq "TIER#3(MB)" && $ldev_id ne ""){
            $header{$section}{$ldev_id}{"TIER3(MB)"} = $array_element;
            next;
          }

          if ($header_element eq "NUM_GROUP" && $ldev_id ne ""){
            $header{$section}{$ldev_id}{"$header_element"} = $array_element;
            next;
          }
          if ($header_element eq "RAID_GROUPs" && $ldev_id ne "" ){
            if ($header{$section}{$ldev_id}{"NUM_GROUP"} == 1){
              $header{$section}{$ldev_id}{"$header_element"} = $array_element;
              next;
            }
            else{
              $header{$section}{$ldev_id}{"$header_element"}{"$array_element"}{"ID"} = $array_element;
              next;
            }
          }

        }
        last;
      }


    }

  }
  #print Dumper \%header;
  foreach my $id (sort { $a <=> $b} keys %{$header{$section}}){
    my $name;
    my $pool_id;
    my $cap;
    my $raid_gr = "";
    my $tier1;
    my $tier2;
    my $tier3;
    if (defined $header{$section}{$id}{ID}){
      $id = $header{$section}{$id}{ID};
    }
    else{
      $id = "";
    }
    if (defined $header{$section}{$id}{NAME}){
      $name = $header{$section}{$id}{NAME};
    }
    else{
      $name = "";
    }
    if (defined $header{$section}{$id}{FPOOL_ID}){
      if ($header{$section}{$id}{FPOOL_ID} ne "NONE"){
        $pool_id = $header{$section}{$id}{FPOOL_ID};
      }
      else{
        $pool_id = "";
      }
    }
    else{
      if (defined $header{$section}{$id}{BPOOL_ID}){
        $pool_id = $header{$section}{$id}{BPOOL_ID};
      }
      else{
        $pool_id = "";
      }
    }
    if (defined $header{$section}{$id}{CAPACITY}){
      $cap = $header{$section}{$id}{CAPACITY};
    }
    else{
      $cap = "";
    }

    if (defined $header{$section}{$id}{NUM_GROUP}){
      if ($header{$section}{$id}{NUM_GROUP} == 1){
        $raid_gr = $header{$section}{$id}{RAID_GROUPs};
      }
      else{
        foreach my $gr (sort keys %{$header{$section}{$id}{RAID_GROUPs}}){
          $raid_gr = $raid_gr . " " . $header{$section}{$id}{RAID_GROUPs}{$gr}{ID};
        }
      }
    }
    else{
      $raid_gr = "";
    }

    if (defined $header{$section}{$id}{"TIER1(MB)"}){
      $tier1 = $header{$section}{$id}{"TIER1(MB)"};
    }
    else{
      $tier1 = "";
    }
    if (defined $header{$section}{$id}{"TIER2(MB)"}){
      $tier2 = $header{$section}{$id}{"TIER2(MB)"};
    }
    else{
      $tier2 = "";
    }
    if (defined $header{$section}{$id}{"TIER3(MB)"}){
      $tier3 = $header{$section}{$id}{"TIER3(MB)"};
    }
    else{
      $tier3 = "";
    }

    #my $header = "ldev_id,name,,,,,pool_id,,capacity (MB),,,,,,,,,,,,interface_type,raid_group_id,tier1 (MB),tier2 (MB),tier3 (MB)";
    push(@array_ldev,"$id,$name,,,,,$pool_id,,$cap,,,,,,,,,,,,,$raid_gr,$tier1,$tier2,$tier3\n");

  }
  #print Dumper \@array_ldev;
  #print Dumper \%header;
  return @array_ldev;

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

sub get_data_rg{
  my $file = shift;
  my $file2 = shift;
  my $section = shift;
  my $metric = shift;
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
          push(@array_rg,",$group,,,,$total_cap,,$size_free,,$size_usage,,,,,,,,\n");
        }
        else{
          if (defined $total_capacity{$group}){
            my $total_cap = $total_capacity{$group};
            #$size_free = ($percent_free/100) * $total_cap;
            $size_usage = $total_cap -  $size_free;
            push(@array_rg,",$group,,,,$total_cap,,$size_free,,$size_usage,,,,,,,,\n");
          }
          else{
            push(@array_rg,",$group,,,,,,,,,,,,,,,,\n");
          }
        }

      }
    }
  }
  #print Dumper \%header;
  return @array_rg;
  #print "$line\n";
}

sub remove_whitespace{
  my $value = shift;
  $value =~ s/^\s+|\s+$//g;
  return $value;

}

sub set_write_data{
  my ($section,$header,$data_tmp) = @_;
  my @data = @{$data_tmp};

  open(DATA, ">>$file_tmp") or error_die ("Cannot open file: $file_tmp : $!");
  print DATA $section;
  print DATA "\n";
  print DATA get_separator($section);
  print DATA "\n";
  print DATA $header;
  print DATA "\n";
  print DATA @data;
  print DATA "\n";
  close(DATA);

}

sub set_configuration_header{
  my $header = "$STORAGE_NAME";
  my $section = "Configuration Data";
  my @data = "";
  set_write_data($section,$header,\@data);


}

sub get_data_port{
  my $file = shift;
  my $section = shift;
  my $metric = shift;
  my @metrics = split(",",$metric);

  my @data = get_array_data($file);
  my %header;
  my @array_port;


  foreach my $line (@data){
    chomp $line;
    if ($line eq ""){next;}
    if ($line =~ /PORT/){
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
    if ($line =~ /TAR/){
      foreach my $id (sort { $a <=> $b} keys %{$header{$section}}){
        if (defined $header{$section}{$id}{LENGTH}){
          my $name = $header{$section}{$id}{NAME};
          if ($name ne "PORT"){next;}
          my $start = $header{$section}{$id}{START};
          my $length = $header{$section}{$id}{LENGTH};
          if ($start == 0){$length--;}
          my $value = substr($line,$start,$length);
          $value = remove_whitespace($value);
          push(@array_port,",,$value,,,,,,\n");
        }
      }

    }

  }
  return @array_port;
  #print Dumper \%header;
  #print Dumper \@data;
  #print Dumper \@array_port;

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

sub test_file_exist{
  my $file = shift;
  if (!-e $file || -z $file){
    return 0;
  }
  else{
    return 1;
  }
}

sub error_die
{
  my $message = shift;
  print STDERR "$message\n";
  `raidcom -logout -I1`;
  exit (1);
}

sub error {
    my $text     = shift;
    my $act_time = localtime();
    chomp($text);

    #print "ERROR          : $text : $!\n";
    print STDERR "$act_time: $text : $!\n";

    return 1;
}













