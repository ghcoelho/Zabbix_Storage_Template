#!/usr/bin/perl
#JSON data structures
use strict;
use warnings;
use File::Basename;
use RRDp;
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
my $dashb_rrdheight = $ENV{DASHB_RRDHEIGHT};
my $dashb_rrdwidth  = $ENV{DASHB_RRDWIDTH};
my $legend_height   = $ENV{LEGEND_HEIGHT};
my $alturl          = $ENV{WWW_ALTERNATE_URL};
my $alttmp          = $ENV{WWW_ALTERNATE_TMP};
my $rrdtool        = $ENV{RRDTOOL};
my $wrkdir         = "$basedir/data";
my @pool;
my @test;
my $end_time = time();
my $start_time = $end_time - 3600; # last hour
my $height = 150;
my $width = 650;
my $count_port_in;
my $count_port_out;
my @replace_file;
my %pools;
my %stree;     # Serverr
my %vclusters; # Servers nested by clusters
my %lstree;    # LPARs by Server
my %lhtree;    # LPARs by HMC
my %vtree;     # VMware vCenter
my %cluster;   # VMware Cluster
my %respool;   # VMware Resource Pool
my @lnames;    # LPAR name (for autocomplete)
my %inventory;     # server / type / name
my %times;     # server timestamps
my $free;      # 1 -> free / 0 -> full
my $hasPower;  # flag for IBM Power presence
my $hasVMware; # flag for WMware presence


my $style_html = "td.clr0 {background-color:#737a75;} td.clr1 {background-color:#008000;} td.clr2 {background-color:#29f929;} td.clr3 {background-color:#81fa51;} td.clr4 {background-color:#c9f433;} td.clr5 {background-color:#FFFF66;} td.clr6 {background-color:#ffff00;} td.clr7 {background-color:#FFCC00;} td.clr8 {background-color:#ffa500;} td.clr9 {background-color:#fa610e;} td.clr10 {background-color:#ff0000;}  table.center {margin-left:auto; margin-right:auto;} table {border-spacing: 1px;} .content_legend { height:"."15"."px"."; width:"."15"."px".";}";

print "heatmap-stor   : start ". localtime() . "\n";


if ( !defined $ENV{INPUTDIR} ) {
  die "Not defined INPUTDIR, probably not read etc/lpar2rrd.cfg";
}

if ( !-f "$rrdtool" ) {
  error("Set correct path to rrdtool binary, it does not exist here: $rrdtool");
  exit;
}
RRDp::start "$rrdtool";

my $cpu_max_filter = 100;              # my $cpu_max_filter = 100;  # max 10k peak in % is allowed (in fact it cannot by higher than 1k now when 1 logical CPU == 0.1 entitlement)
if ( defined $ENV{CPU_MAX_FILTER} ) {
  $cpu_max_filter = $ENV{CPU_MAX_FILTER};
}

# set unbuffered stdout
#$| = 1;

# open( OUT, ">> $errlog" ) if $DEBUG == 2;

# get QUERY_STRING
use Env qw(QUERY_STRING);
# print OUT "-- $QUERY_STRING\n" if $DEBUG == 2;

#`echo "QS $QUERY_STRING " >> /tmp/xx32`;
my ( $type, $par1, $par2 );
if (defined $QUERY_STRING) {
  ( $type, $par1, $par2 ) = split( /&/, $QUERY_STRING );
}

if ( !defined $type || $type eq "" ) {
    if (@ARGV) {
        $type = "type=" . $ARGV[0];
        #$basedir  = "..";
    }
    else {
        $type = "type=test";
    }
}

$type =~ s/type=//;

if ( $type eq "test" ) {
    #$basedir = "..";
    #$wrkdir = "/home/stor2rrd/stor2rrd/data";
    &test();
    RRDp::end; # close RRD pipe
    exit;
}

if ( $type eq "dump" ) {
    &dumpHTML();
    RRDp::end; # close RRD pipe
    exit;
}
 
RRDp::end; # close RRD pipe

sub test{
  use Data::Dumper;
  readMenu();
  #print Dumper \%inventory;
  set_utilization_in_san();
  set_utilization_out_san();
  get_html_san();
  print "heatmap-stor   : end ". localtime(). "\n";
}

#sub dumpHTML{};

sub readMenu{
  my $alt     = shift;
  my $tmppath = "tmp";
  if ($alturl) {
    my @parts = split( /\//, $ENV{HTTP_REFERER} );
    if (   $ENV{HTTP_REFERER}
            && ( $parts[-1] ne $alturl )
            && ( $parts[-2] ne $alturl ) )
    {              # URL doesn't match WWW_ALTERNATE_URL
      $tmppath = $alttmp;    # use menu from WWW_ALTERNATE_TMP
    }
    if ($alt) {
      $tmppath = $alttmp;
    }
  }

  my $skel = "$basedir/$tmppath/menu.txt";
  my $jump_port = 0;
  #my $skel = "/home/stor2rrd/stor2rrd/$tmppath/menu.txt";
  #my $skel = "menu.txt";
  #print "$skel\n";
  open( SKEL, $skel ) or error_die ("Cannot open file: $! $skel");
  while ( my $line = <SKEL> ) {
    my ( $hmc, $srv, $txt, $url );
    chomp $line;
    my @val = split( ':', $line );
    for (@val) {
      &colons($_);
    }
    {
      "O" eq $val[0] && do {
        $free = ( $val[1] == 1 ) ? 1 : 0;
        last;
      };

      #S:ahmc11:BSRV21:CPUpool-pool:CPU pool:ahmc11/BSRV21/pool/gui-cpu.html::1399967748
      "W" eq $val[0] && do {
      $jump_port = 1;
      my $san = $val[1];
                last;
            };
              "D" eq $val[0] && do {
                $jump_port = 0;
                last;
              };
            "$jump_port" eq "0" && do{
              last;
            };
            "L" eq $val[0] && do {
                my ( $san, $type, $port, $url )
                    = ( $val[1], $val[2], $val[3], $val[5] );
                if ( "$type" eq "SANPORT" )
                { $inventory{$san}{PORT}{$port}{NAME} = $port;
                  $inventory{$san}{PORT}{$port}{URL} = $url;
                }
                last;
            };
        };
    }

  close(SKEL);

}

sub urlencode {
    my $s = shift;
    $s =~ s/ /+/g;
    $s =~ s/([^A-Za-z0-9\+-_])/sprintf("%%%02X", ord($1))/seg;
    return $s;
}

sub urldecode {
    my $s = shift;
    $s =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
    $s =~ s/\+/ /g;
    return $s;
}


sub colons {
    return s/===double-col===/:/g;
}

sub uniq {
    my %seen;
    return grep { !$seen{$_}++ } @_;
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
sub boolean {
    my $val = shift;
    if ($val) {
      return "true";
    } else {
      return "false";
    }
}

#########################################################################
# SAN
##########################################################################


sub get_percent_to_color{
  use POSIX qw(ceil);
  my $percent = shift;
  if ("$percent" eq "-nan" || "$percent" eq "NaNQ" || $percent =~ /NAN/ || $percent =~ /NaN/){
    return "clr0";
  }
  my $pom = ceil($percent);
  $percent = $pom;
  if ($percent>=0 && $percent<=10){
    return "clr1"
  }
  if ($percent>=11 && $percent<=20){
    return "clr2";
  }
  if ($percent>=21 && $percent<=30){
    return "clr3"
  }
  if ($percent>=31 && $percent<=40){
    return "clr4";
  }
  if ($percent>=41 && $percent<=50){
    return "clr5"
  }
  if ($percent>=51 && $percent<=60){
    return "clr6";
  }
  if ($percent>=61 && $percent<=70){
    return "clr7"
  }
  if ($percent>=71 && $percent<=80){
    return "clr8";
  }
  if ($percent>=81 && $percent<=90){
    return "clr9"
  }
  if ($percent>=91){
    return "clr10";
  }
}

sub get_live_ports{
  my @array_file;
  my @wrkdir_all = <$wrkdir/*>;
  foreach my $san_all (@wrkdir_all) {
    my $san = basename($san_all);
    if ( -l $san_all )        { next;}
    if ( !-d $san_all )       { next; }
    my $san_space = $san;
    if ( $san =~ m/ / ) {
      $san_space = "\"".$san."\""; # it must be here to support space with server names
    }
    my @ports_all = <$wrkdir/$san_space/*>;
    my $test = grep {/SAN-BRCD/} @ports_all;
    if (!$test){$test = grep {/SAN-CISCO/} @ports_all;}
    if ($test){
      foreach my $port_all (@ports_all){
        my $port = basename($port_all);
        if ( $port !~ /\.rrd$/ ) { next; }
        #print "$port_all a $port\n";
        push(@array_file,"$port_all,$san,$port");
      }
    }
    else{next;}
  }
  return @array_file;
}


sub set_utilization_in_san{
  $count_port_in = 0;
  foreach my $line (get_live_ports()){
    my ($path, $san, $rrd_file) = split(",",$line);
    #print "$path, $san, $rrd_file\n";
    $rrd_file =~ s/.rrd//g;
    my $name_port = $rrd_file;
    $path =~ s/:/\\:/g;
    my $val = (1024 * 1024) /4;
    foreach my $sanm (keys %inventory){
      if ("$san" eq "$sanm"){
        foreach my $port (keys %{$inventory{$san}{PORT}}){
          if ("$port" eq "$name_port"){
            my $answer;
             my $rrd_out_name = "graph.png";
            eval { RRDp::cmd qq(graph "$rrd_out_name"
            "--start" "$start_time"
            "--end" "$end_time"
            "--step=60"
            "DEF:bytesrec=$path:bytes_rec:AVERAGE"
            "DEF:portspeed=$path:port_speed:AVERAGE"
            "CDEF:transfer=bytesrec,$val,/"
            "CDEF:transferspeed=portspeed,1024,/"
            "CDEF:utilper=transfer,transferspeed,/,100,*"
            "PRINT:utilper:AVERAGE:Utilization IN percent %2.2lf"
            );
            $answer = RRDp::read;
            };
            if ($@) {
              if ( $@ =~ "ERROR" ) {
                error("Rrrdtool error : $@");
                next;
              }
            }
            my $aaa = $$answer;
            #if ( $aaa =~ /NaNQ/ ) { next; }
            ( undef, my $utilization_in_percent ) = split( "\n", $aaa );
            $utilization_in_percent =~ s/Utilization IN percent\s+//;
            #print $utilization_in_percent . "\n";
            $inventory{$sanm}{PORT}{$port}{IN} = $utilization_in_percent;
            #print $inventory{ASAN11}{PORT}{port3}{IN} . "\n";
            $count_port_in++;
          }
        }
      }
    }
  }
  print "heatmap-stor   : set Data IN utilization for $count_port_in ports\n";
}

sub get_table_in_san{
  use POSIX qw(ceil);
  my $count_row = 1;
  my $nasob = 0;
  if ($count_port_in == 0){return ""};
  my $cell_size = ($height * $width)/$count_port_in;
  my $td_width = ceil(sqrt($cell_size));
  my $td_height = $td_width;
  my $new_row = 0;
  my $count_column = 1;

  if ($td_width < 10){
    $td_width = 10;
    $td_height = 10;
  }

  $td_height = $td_height-2;
  ################
  my $style_in =" .content_in { height:"."$td_height"."px"."; width:"."$td_height"."px".";} h3 {text-align:center;}";
  my $table = "<table>\n<tbody>\n<tr>\n";
  foreach my $san (sort keys %inventory){
    foreach my $port (sort { lc $inventory{$san}{PORT}{$a}{NAME} cmp lc $inventory{$san}{PORT}{$b}{NAME} || $inventory{$san}{PORT}{$a}{NAME} cmp $inventory{$san}{PORT}{$b}{NAME}} keys %{$inventory{$san}{PORT}}){
      if (defined $inventory{$san}{PORT}{$port}{IN}){
        if ( ($new_row+$td_width) > $width){
          $table = $table . "</tr>\n<tr>\n";
          $new_row = 0;
        }
        my $percent_util = $inventory{$san}{PORT}{$port}{IN};
        if ("$percent_util" eq "-nan" || "$percent_util" eq "NaNQ" || $percent_util =~ /NAN/ || $percent_util =~ /NaN/){
          $percent_util = "nan";
        }
        else{
          my $ceil = ceil($percent_util);
          $percent_util = $ceil;
          $percent_util = $percent_util . "%";
        }
        my $url = $inventory{$san}{PORT}{$port}{URL};
        my $name = $inventory{$san}{PORT}{$port}{NAME};
        #print "$url_name\n";
        $table = $table . "<td class=".'"'.get_percent_to_color($inventory{$san}{PORT}{$port}{IN}).'"'.">\n<a href=".'"'."$url".'"'."><div title =".'"'."$san : $name"." : ".$percent_util.'"'. "class=".'"'."content_in".'"'."></div>\n</a>\n</td>\n";
        $new_row = $td_width + $new_row;
      }
      else{next;}
    }
  }
  $table = $table . "</tr>\n</tbody>\n</table><br>\n";
  my $tb_and_styl = "$table" . "@" . "$style_in";
  return ($tb_and_styl);
  #print "$table\n";
  #print "$count_lpars\n";
}


sub get_html_san{
  my $check = get_table_in_san();
  if ($check eq ""){
    return 0;
  }
  else{
    my ($table_in_san, $style_in) = split("@",get_table_in_san());
    my ($table_out_san, $style_out) = split("@",get_table_out_san());
    my $style = "<style>"."$style_in". "$style_out"."$style_html". "</style>";
    #print $style . "\n";
    my $html = "<!DOCTYPE html>\n<html>\n<head>".$style."</head><body>\n<table class=".'"'."center".'"'.">\n<tbody><tr><td><h3>Data IN</h3></td></tr>\n<tr>\n<td>".$table_in_san ."</td></tr>\n<tr>\n<td>&nbsp;</td>\n</tr><tr><td><h3>Data OUT</h3></td></tr>\n<tr><td>".$table_out_san."</td></tr><tr><td>" . get_report()."\n</td></tr><tr><td>&nbsp;</td></tr><tr><td><b>LEGEND</b>:<tr><td>". get_legend() ."</td></tr>\n</tbody>\n</table>\n</body></html>";
    open(DATA, ">$webdir/heatmap.html") or error_die ("Cannot open file: $!");
    print DATA $html;
    close DATA;
    #print $html . "\n";
  }
}


sub set_utilization_out_san{
  $count_port_out = 0;
  foreach my $line (get_live_ports()){
    my ($path, $san, $rrd_file) = split(",",$line);
    #print "$path, $san, $rrd_file\n";
    $rrd_file =~ s/.rrd//g;
    my $name_port = $rrd_file;
    $path =~ s/:/\\:/g;
    my $val = (1024 * 1024) /4;
    foreach my $sanm (keys %inventory){
      if ("$san" eq "$sanm"){
        foreach my $port (keys %{$inventory{$san}{PORT}}){
          if ("$port" eq "$name_port"){
            my $answer;
             my $rrd_out_name = "graph.png";
            eval { RRDp::cmd qq(graph "$rrd_out_name"
            "--start" "$start_time"
            "--end" "$end_time"
            "--step=60"
            "DEF:bytestra=$path:bytes_tra:AVERAGE"
            "DEF:portspeed=$path:port_speed:AVERAGE"
            "CDEF:transfer=bytestra,$val,/"
            "CDEF:transferspeed=portspeed,1024,/"
            "CDEF:utilper=transfer,transferspeed,/,100,*"
            "PRINT:utilper:AVERAGE:Utilization OUT percent %2.2lf"
            );
            $answer = RRDp::read;
            };
            if ($@) {
              if ( $@ =~ "ERROR" ) {
                error("Rrrdtool error : $@");
                next;
              }
            }
            my $aaa = $$answer;
            #if ( $aaa =~ /NaNQ/ ) { next; }
            ( undef, my $utilization_in_percent ) = split( "\n", $aaa );
            $utilization_in_percent =~ s/Utilization OUT percent\s+//;
            #print $utilization_in_percent . "\n";
            $inventory{$sanm}{PORT}{$port}{OUT} = $utilization_in_percent;
            $count_port_out++;
            #print $inventory{ASAN11}{PORT}{port3}{OUT} = $utilization_in_percent;
          }
        }
      }
    }
  }
  print "heatmap-stor   : set Data OUT utilization for $count_port_out ports\n";
}

sub get_table_out_san{
  use POSIX qw(ceil);
  my $count_row = 1;
  my $nasob = 0;
  if ($count_port_out == 0){return ""};
  my $cell_size = ($height * $width)/$count_port_out;
  my $td_width = ceil(sqrt($cell_size));
  my $td_height = $td_width;
  my $new_row = 0;
  my $count_column = 1;

  if ($td_width < 10){
    $td_width = 10;
    $td_height = 10;
  }

  $td_height = $td_height-2;
  ################
  my $style_out =" .content_out { height:"."$td_height"."px"."; width:"."$td_height"."px".";} h3 {text-align:center;}";
  my $table = "<table>\n<tbody>\n<tr>\n";
  foreach my $san (sort keys %inventory){
    foreach my $port (sort { lc $inventory{$san}{PORT}{$a}{NAME} cmp lc $inventory{$san}{PORT}{$b}{NAME} || $inventory{$san}{PORT}{$a}{NAME} cmp $inventory{$san}{PORT}{$b}{NAME}} keys %{$inventory{$san}{PORT}}){
      if (defined $inventory{$san}{PORT}{$port}{OUT}){
        if ( ($new_row+$td_width) > $width){
          $table = $table . "</tr>\n<tr>\n";
          $new_row = 0;
        }
        my $percent_util = $inventory{$san}{PORT}{$port}{OUT};
        if ("$percent_util" eq "-nan" || "$percent_util" eq "NaNQ" || $percent_util =~ /NAN/ || $percent_util =~ /NaN/){
          $percent_util = "nan";
        }
        else{
          my $ceil = ceil($percent_util);
          $percent_util = $ceil;
          $percent_util = $percent_util . "%";
        }
        my $url = $inventory{$san}{PORT}{$port}{URL};
        my $name = $inventory{$san}{PORT}{$port}{NAME};
        #print "$url_name\n";
        $table = $table . "<td class=".'"'.get_percent_to_color($inventory{$san}{PORT}{$port}{OUT}).'"'.">\n<a href=".'"'."$url".'"'."><div title =".'"'."$san : $name"." : ".$percent_util.'"'. "class=".'"'."content_out".'"'."></div>\n</a>\n</td>\n";
        $new_row = $td_width + $new_row;
      }
      else{next;}
    }
  }
  $table = $table . "</tr>\n</tbody>\n</table><br>\n";
  my $tb_and_styl = "$table" . "@" . "$style_out";
  return ($tb_and_styl);
  #print "$table\n";
}


sub get_report {
  my $time = localtime;
  my $table = "<table>\n<tbody>\n<tr>\n<td>Heat map has been created at: "."$time"."</td>\n</tr>\n<tr>\n<td>Heat map shows average utilization from last 1 hour.</td>\n</tr>\n</tbody>\n</table>";
  return $table;

}

sub get_legend{
  my $table = "<table>\n<tbody><tr>";
  my $i =0;
  my $from = 0;
  my $to = 10;
  my $title ="";
  while ($i<11){
    if ($i==0){
      $title = "nan";
    }
    $table = $table . "\n<td title=".'"'."$title".'"'."class=".'"'."clr$i".'"'."><div class =".'"'."content_legend".'"'."></div></td>";
    $i++;
    $title = "$from-$to " ."%";
    $from = $to + 1;
    $to = $to + 10;
  }
  $table = $table . "</tr>\n</tbody>\n</table>";
  return $table;
}

sub error_die
{
  my $message = shift;

  print STDERR "$message\n";
  RRDp::end; # close RRD pipe
  exit (1);
}

