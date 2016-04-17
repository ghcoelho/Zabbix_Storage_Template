
use strict;
use Date::Parse;

my $DEBUG = $ENV{DEBUG};
my $errlog = $ENV{ERRLOG};
my $xport = $ENV{EXPORT_TO_CSV};
my $webdir = $ENV{WEBDIR};
my $basedir = $ENV{INPUTDIR};
my $detail_yes = 1;
my $detail_no  = 0;
my $tmp_dir = "$basedir/tmp"; 
my $wrkdir = "$basedir/data";
my $time_u = time();


# CGI-BIN HTML header
print "Content-type: text/html\n\n";

open(OUT, ">> $errlog")  if $DEBUG == 2 ;

my @items_sorted = "sum_io_total sum_io sum_data_total sum_data io_rate data_rate sum_capacity read_io write_io read write cache_hit r_cache_hit w_cache_hit r_cache_usage w_cache_usage read_pct resp resp_t resp_t_r resp_t_w read_io_b write_io_b read_b write_b resp_t_b resp_t_r_b resp_t_w_b sys compress pprc_rio pprc_wio pprc_data_r pprc_data_w pprc_rt_r pprc_rt_w tier0 tier1 tier2 used io_rate-subsys data_rate-subsys read_io-subsys write_io-subsys read-subsys write-subsys data_cntl io_cntl ssd_r_cache_hit data_in data_out frames_in frames_out credits errors operating_rate write_pend clean_usage middle_usage phys_usage";

# get QUERY_STRING
use Env qw(QUERY_STRING);
print OUT "-- $QUERY_STRING\n" if $DEBUG == 2 ;

( my $host,my $type, my $name, my $st_type, my $item, my $gui, my $referer) = split(/&/,$QUERY_STRING);

# no URL decode here, as it goes immediately into URL again

$host =~ s/host=//;
my $host_url = $host;
$host =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/seg;
$host =~ s/\+/ /g;
$host =~ s/%23/\#/g;
$type =~ s/type=//;
$name =~ s/name=//;
$name =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/seg;
$name =~ s/\+/ /g;
$name =~ s/%23/\#/g;
$item =~ s/item=//;
$st_type =~ s/storage=//;

#print STDERR "$QUERY_STRING : $name\n";

if ( $gui =~ m/gui=/ ) {
  $gui =~ s/gui=//;
}
else {
  $gui=0;
}
# http_base must be passed through cgi-bin script to get location of jquery scripts and others
# it is taken from HTTP_REFERER first time and then passed in the HTML GET
my $html_base = "";
$referer =~ s/referer=//;    #for paging aggregated : PH: not only for paging!!

if ( $referer ne "" && $referer !~ m/none=/ ) {
  # when is referer set then it is already html_base --> not call html_base($refer) again
  $referer =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/seg;
  $referer =~ s/\+/ /g;
  $html_base = $referer ;
}
else {
  $referer = $ENV{HTTP_REFERER};
  $html_base = html_base($referer); # it must be here behind $base setting
}

if ( $name =~ m/^top$/ ) {
  # volumes text tables
  # must be before $item =~ m/^sum$/
  volumes_top_all($host,$type,$item,$st_type,$name);
  exit (0);
} 

if ( $item =~ m/^sum$/ ) {
  # aggregated graphs
  make_agg($host,$type,$name,$item,$st_type);
  exit (0);
} 


# individual "item" graohs
if ( $st_type =~ "^SAN-" ) {
  create_tab_san($host,$type,$name,$st_type,$item);
}
else {
  if ( $item =~ m/^custom$/ ) {
    # Custom group 
    create_tab_custom($host,$type,$name,$st_type,$item);
  }
  else {
    # default stuff
    create_tab($host,$type,$name,$st_type,$item);
  }
}

sub create_tab_san
{
  #host=ASAN11&type=PORT&name=port9&storage=SAN-BRCD&item=san&gui=1&none=none::
  #( my $host,my $type, my $name, my $st_type, my $item, my $gui, my $referer) = split(/&/,$QUERY_STRING);

  my ($host,$type,$name,$st_type,$item)= @_;

  if ( $item eq "san" ) {
    my @graph = ("$item\_data","$item\_io","$item\_io_size","$item\_credits","$item\_errors");

    # print out tabs
    my $tab_number = 0;
    print "<div  id=\"tabs\"> <ul>\n";
    foreach $item (<@graph>) {

      # Show BBCredits only for fc ports
      if ( $item eq "san_credits" && $st_type eq "SAN-CISCO" ) {
        my $go_bbc = 0;
        if ( $name =~ "^portfc" || $name =~ "portChannel" ) { $go_bbc = 1; }
        if ( $go_bbc == 0 ) { next; }
      }

      # data source back/fron end
      my $data_type = "tabfrontend";
      my $tab_name = text_tab($item,"item");
      print "  <li class=\"$data_type\"><a href=\"#tabs-$tab_number\">$tab_name</a></li>\n";
      $tab_number++;
    }
    print "   </ul> \n";

    $tab_number = 0;
    foreach $item (<@graph>) {
      my $item_name = $item;

      # Show BBCredits only for fc ports
      if ( $item eq "san_credits" && $st_type eq "SAN-CISCO" ) {
        my $go_bbc = 0;
        if ( $name =~ "^portfc" || $name =~ "portChannel" ) { $go_bbc = 1; }
        if ( $go_bbc == 0 ) { next; }
      }

      print "<div id=\"tabs-$tab_number\"><br><br><center>\n";
      if ( $gui == 0 ) {
        print "<center><h3>$item_name</h3></center>";
      }

      print "<table align=\"center\" summary=\"Graphs\">\n";

      print "<tr>\n";
      print_item ($host,$type,$name,$item,"d",$detail_yes);
      print_item ($host,$type,$name,$item,"w",$detail_yes);
      print "</tr><tr>\n";
      print_item ($host,$type,$name,$item,"m",$detail_yes);
      print_item ($host,$type,$name,$item,"y",$detail_yes);
      print "</tr>\n";

      #if ( $item_name eq "san_credits" ) { print "<tr><td align=\"center\" colspan=\"2\">Counts the number of times that the transmit credit has reached 0.</td></tr>\n"; }
      if ( $item_name eq "san_errors" )  {
        print "<tr><td align=\"center\" colspan=\"2\">Counts the number of CRC errors detected for frames received.</td></tr>\n";
        #print "<tr><td align=\"left\" colspan=\"2\"><b>swFCPortRxEncOutFrs</b> : Counts the number of encoding error or disparity error outside frames received.</td></tr>\n";
      }
      # BBCredits a href
      if ( $item eq "san_credits" ) {
        print "<div id=\'hiw\'><a href=\'http://www.stor2rrd.com/BBCredit.htm\' target=\'_blank\'><img src=\'css/images/help-browser.gif\' alt=\'What is BBCredits?\' title=\'What is BBCredits?\'></a></div>\n";
      }

      print "</table></center>\n";
      print "</div>\n";
      $tab_number++;
    }

    print "</div><br>\n";
    if ( $gui == 0 ) {
      print "</BODY></HTML>";
    }
  }

  if ( $item eq "san_data_sum" || $item eq "san_io_sum" ) {
    my @graph = ("$item\_in","$item\_out");

    if ( $item eq "san_io_sum" ) {
      @graph = ("$item\_in","$item\_out","$item\_credits","$item\_crc_errors");
    }

    # print out tabs
    my $tab_number = 0;
    print "<div  id=\"tabs\"> <ul>\n";
    foreach $item (<@graph>) {
      # data source back/fron end
      my $data_type = "tabfrontend";
      my $tab_name = text_tab($item,"item");
      print "  <li class=\"$data_type\"><a href=\"#tabs-$tab_number\">$tab_name</a></li>\n";
      $tab_number++;
    }
    print "   </ul> \n";

    $tab_number = 0;
    foreach $item (<@graph>) {
      my $item_name = $item;

      print "<div id=\"tabs-$tab_number\"><br><br><center>\n";
      if ( $gui == 0 ) {
        print "<center><h3>$item_name</h3></center>";
      }

      print "<table align=\"center\" summary=\"Graphs\">\n";

      print "<tr>\n";
      print_item ($host,$type,$name,$item,"d",$detail_yes);
      print_item ($host,$type,$name,$item,"w",$detail_yes);
      print "</tr><tr>\n";
      print_item ($host,$type,$name,$item,"m",$detail_yes);
      print_item ($host,$type,$name,$item,"y",$detail_yes);
      print "</tr>\n";

      if ( $item_name eq "san_io_sum_crc_errors" )      { print "<tr><td align=\"center\" colspan=\"2\">Counts the number of CRC errors detected for frames received.</td></tr>\n"; }
      #if ( $item_name eq "san_io_sum_credits" )         { print "<tr><td align=\"center\" colspan=\"2\">Counts the number of times that the transmit credit has reached 0.</td></tr>\n"; }
      #if ( $item_name eq "san_io_sum_encoding_errors" ) { print "<tr><td align=\"center\" colspan=\"2\">Counts the number of encoding error or disparity error outside frames received.</td></tr>\n"; }
      # BBCredits a href
      if ( $item eq "san_io_sum_credits" ) {
        print "<div id=\'hiw\'><a href=\'http://www.stor2rrd.com/BBCredit.htm\' target=\'_blank\'><img src=\'css/images/help-browser.gif\' alt=\'What is BBCredits?\' title=\'What is BBCredits?\'></a></div>\n";
      }

      print "</table></center>\n";
      print "</div>\n";
      $tab_number++;
    }

    print "</div><br>\n";
    if ( $gui == 0 ) {
      print "</BODY></HTML>";
    }
  }

  if ( $item eq "san_data_sum_tot" || $item eq "san_io_sum_tot" ) {
    my @graph = ("$item\_in","$item\_out");

    if ( $item eq "san_io_sum_tot" ) {
      @graph = ("$item\_in","$item\_out","$item\_credits","$item\_crc_errors");
    }

    # print out tabs
    my $tab_number = 0;
    print "<div  id=\"tabs\"> <ul>\n";
    foreach $item (<@graph>) {
      # data source back/fron end
      my $data_type = "tabfrontend";
      my $tab_name = text_tab($item,"item");
      print "  <li class=\"$data_type\"><a href=\"#tabs-$tab_number\">$tab_name</a></li>\n";
      $tab_number++;
    }
    print "   </ul> \n";

    $tab_number = 0;
    foreach $item (<@graph>) {
      my $item_name = $item;

      print "<div id=\"tabs-$tab_number\"><br><br><center>\n";
      if ( $gui == 0 ) {
        print "<center><h3>$item_name</h3></center>";
      }

      print "<table align=\"center\" summary=\"Graphs\">\n";

      print "<tr>\n";
      print_item ($host,$type,$name,$item,"d",$detail_yes);
      print_item ($host,$type,$name,$item,"w",$detail_yes);
      print "</tr><tr>\n";
      print_item ($host,$type,$name,$item,"m",$detail_yes);
      print_item ($host,$type,$name,$item,"y",$detail_yes);
      print "</tr>\n";

      if ( $item_name eq "san_io_sum_tot_crc_errors" )      { print "<tr><td align=\"center\" colspan=\"2\">Counts the number of CRC errors detected for frames received.</td></tr>\n"; }
      #if ( $item_name eq "san_io_sum_tot_credits" )         { print "<tr><td align=\"center\" colspan=\"2\">Counts the number of times that the transmit credit has reached 0.</td></tr>\n"; }
      #if ( $item_name eq "san_io_sum_tot_encoding_errors" ) { print "<tr><td align=\"center\" colspan=\"2\">Counts the number of encoding error or disparity error outside frames received.</td></tr>\n"; }
      # BBCredits a href
      if ( $item eq "san_io_sum_tot_credits" ) {
        print "<div id=\'hiw\'><a href=\'http://www.stor2rrd.com/BBCredit.htm\' target=\'_blank\'><img src=\'css/images/help-browser.gif\' alt=\'What is BBCredits?\' title=\'What is BBCredits?\'></a></div>\n";
      }

      print "</table></center>\n";
      print "</div>\n";
      $tab_number++;
    }

    print "</div><br>\n";
    if ( $gui == 0 ) {
      print "</BODY></HTML>";
    }
  }

  if ( $item eq "san_fabric" ) {
    my @graph = ("$item\_data_in","$item\_frames_in","$item\_credits","$item\_crc_errors","$item\_conf");

    # print out tabs
    my $tab_number = 0;
    print "<div  id=\"tabs\"> <ul>\n";
    foreach $item (<@graph>) {
      # data source back/fron end
      my $data_type = "tabfrontend";
      my $tab_name = text_tab($item,"item");
      print "  <li class=\"$data_type\"><a href=\"#tabs-$tab_number\">$tab_name</a></li>\n";
      $tab_number++;
    }
    print "   </ul> \n";

    $tab_number = 0;
    foreach $item (<@graph>) {
      my $item_name = $item;

      print "<div id=\"tabs-$tab_number\"><br><br><center>\n";
      if ( $gui == 0 ) {
        print "<center><h3>$item_name</h3></center>";
      }

      if ( $item_name eq "san_fabric_conf" ) {
        if ( -f "$webdir/fabric_cfg.html" ) {
          open(FAC, "< $webdir/fabric_cfg.html") || error ("file does not exists : $webdir/fabric_cfg.html ".__FILE__.":".__LINE__) && return 0;
          my @lines = <FAC>;
          close (FAC);

          print @lines;
          #foreach my $line (@lines) {
          #  pr
          #}
        }
        else {
          print "Fabric configuration table not found!";
        }
      }
      else {
        print "<table align=\"center\" summary=\"Graphs\">\n";

        print "<tr>\n";
        print_item ($host,$type,$name,$item,"d",$detail_yes);
        print_item ($host,$type,$name,$item,"w",$detail_yes);
        print "</tr><tr>\n";
        print_item ($host,$type,$name,$item,"m",$detail_yes);
        print_item ($host,$type,$name,$item,"y",$detail_yes);
        print "</tr>\n";

        if ( $item_name eq "san_fabric_crc_errors" )      { print "<tr><td align=\"center\" colspan=\"2\">Counts the number of CRC errors detected for frames received.</td></tr>\n"; }
        #if ( $item_name eq "san_fabric_credits" )         { print "<tr><td align=\"center\" colspan=\"2\">Counts the number of times that the transmit credit has reached 0.</td></tr>\n"; }
        #if ( $item_name eq "san_fabric_encoding_errors" ) { print "<tr><td align=\"center\" colspan=\"2\">Counts the number of encoding error or disparity error outside frames received.</td></tr>\n"; }
        # BBCredits a href
        if ( $item eq "san_fabric_credits" ) {
          print "<div id=\'hiw\'><a href=\'http://www.stor2rrd.com/BBCredit.htm\' target=\'_blank\'><img src=\'css/images/help-browser.gif\' alt=\'What is BBCredits?\' title=\'What is BBCredits?\'></a></div>\n";
        }

        print "</table></center>\n";
        print "</div>\n";
      }
      $tab_number++;
    }

    print "</div><br>\n";
    if ( $gui == 0 ) {
      print "</BODY></HTML>";
    }
  }

  if ( $item eq "san_isl" ) {
    my @graph = ("$item\_data_in","$item\_data_out","$item\_frames_in","$item\_frames_out","$item\_frame_size_in","$item\_frame_size_out","$item\_credits","$item\_crc_errors");

    # print out tabs
    my $tab_number = 0;
    print "<div  id=\"tabs\"> <ul>\n";
    foreach $item (<@graph>) {
      # data source back/fron end
      my $data_type = "tabfrontend";
      my $tab_name = text_tab($item,"item");
      print "  <li class=\"$data_type\"><a href=\"#tabs-$tab_number\">$tab_name</a></li>\n";
      $tab_number++;
    }
    print "   </ul> \n";

    $tab_number = 0;
    foreach $item (<@graph>) {
      my $item_name = $item;

      print "<div id=\"tabs-$tab_number\"><br><br><center>\n";
      if ( $gui == 0 ) {
        print "<center><h3>$item_name</h3></center>";
      }

      print "<table align=\"center\" summary=\"Graphs\">\n";

      print "<tr>\n";
      print_item ($host,$type,$name,$item,"d",$detail_yes);
      print_item ($host,$type,$name,$item,"w",$detail_yes);
      print "</tr><tr>\n";
      print_item ($host,$type,$name,$item,"m",$detail_yes);
      print_item ($host,$type,$name,$item,"y",$detail_yes);
      print "</tr>\n";

      if ( $item_name eq "san_isl_crc_errors" )      { print "<tr><td align=\"center\" colspan=\"2\">Counts the number of CRC errors detected for frames received.</td></tr>\n"; }
      #if ( $item_name eq "san_isl_credits" )         { print "<tr><td align=\"center\" colspan=\"2\">Counts the number of times that the transmit credit has reached 0.</td></tr>\n"; }
      #if ( $item_name eq "san_fabric_encoding_errors" ) { print "<tr><td align=\"center\" colspan=\"2\">Counts the number of encoding error or disparity error outside frames received.</td></tr>\n"; }
      # BBCredits a href
      if ( $item eq "san_isl_credits" ) {
        print "<div id=\'hiw\'><a href=\'http://www.stor2rrd.com/BBCredit.htm\' target=\'_blank\'><img src=\'css/images/help-browser.gif\' alt=\'What is BBCredits?\' title=\'What is BBCredits?\'></a></div>\n";
      }

      print "</table></center>\n";
      print "</div>\n";
      $tab_number++;
    }

    print "</div><br>\n";
    if ( $gui == 0 ) {
      print "</BODY></HTML>";
    }
  }

}

sub create_tab 
{
  my ($host,$type,$name,$st_type,$item)= @_;

  my $item="data_rate";
  my @graph = "";
  my $graph_indx = 0;

  foreach $item (<@items_sorted>) {
    #print STDERR "01 $item $host $type : $tmp_dir/$host/$type-$item-d.cmd : $QUERY_STRING\n";

    if ( $item =~ m/-subsys/ ) {
      next; # skip Storwize  PORT subsys graphs per port, they are only in agg graphs
    }

    if ( ! -f "$tmp_dir/$host/$type-$item-d.cmd" ) {
       next; # non existing item
    }

    if ( $name !~ m/^sum/ && $item =~ m/^sum/ ) {
      next; # avoid sum graphs for normail item details
    }

    if ( $item =~ m/^sum_capacity$/ && $st_type =~ m/DS8K/ ) {
      next;
    }
  
    if ( $item =~ m/_cntl$/ ) {
      next; # controller info is only for aggregated, not for individual pools or volumes
    }

    #print STDERR "02 $item $host $type\n";

    if ( $type =~ m/^POOL$/ ) {
      if ( $item =~ m/^read$/ && $st_type !~ m/XIV/ && $st_type !~ m/DS8K/ && $st_type !~ m/HUS/ && $st_type !~ m/NETAPP/ && $st_type !~ m/3PAR/  && $st_type !~ m/VSPG/) {
        $item = "data_rate";
      }
      if ( $item =~ m/^read_io$/ && $st_type !~ m/XIV/ && $st_type !~ m/DS8K/ && $st_type !~ m/HUS/ && $st_type !~ m/NETAPP/ && $st_type !~ m/3PAR/ && $st_type !~ m/VSPG/ ) {
        $item = "io_rate";
      }
      if ( $st_type =~ m/SWIZ/ ) {
        if ( $item !~ m/^read_io_b$/ && $item !~ m/^write_io_b$/ && $item !~ m/^read_b$/ && $item !~ m/^write_b$/ && $item !~ m/^resp_t_r_b$/ && $item !~ m/^resp_t_w_b$/ &&
             $item !~ m/tier/ && $item !~ m/^sum_capacity$/ && $item !~ m/^io_rate$/ && $item !~ m/^data_rate$/ && $item !~ m/resp/ ) {
          next;
        }
      }
      if ( $st_type =~ m/DS8K/ ) {
        if ( $item !~ m/tier/ && $item !~ m/^read_io$/ && $item !~ m/^write_io$/ && $item !~ m/^read_io_b$/ && $item !~ m/^write_io_b$/ &&
             $item !~ m/^resp_t_r$/ && $item !~ m/^resp_t_w$/ &&
             $item !~ m/^read$/ && $item !~ m/^write$/ && $item !~ m/^read_b$/ && $item !~ m/^write_b$/ && $item !~ m/^resp_t_r_b$/ && $item !~ m/^resp_t_w_b$/ ) {
          next;
        }
      }
      if ( $st_type =~ m/DS5K/ && $item =~ m/cache/ ) {
        next;
      }
    }
    if ( $st_type =~ m/DS8K/ && $type =~ m/^PORT$/ && $item =~ /^pprc/ ) {
      if ( ! -f "$basedir/data/$host/$type/$name.rrp" ) {
        # display PPRC tabs only where are some PPRC data (data file *.rrp)
        next;
      }
    }

    if ( $type =~ m/^HOST$/ ) {
      if ( ! -f "$basedir/data/$host/$type/hosts.cfg" || find_vols ($host,$type,$name) == 0 ) {
        # when a host does not have any attached volume then print message and exit
        non_existing_data($host,$name);
        exit (0);
      }
      # add "?" with How it works link
      print "<div id=\'hiw\'><a href=\'http://www.stor2rrd.com/host_docu.htm\' target=\'_blank\'><img src=\'css/images/help-browser.gif\' alt=\'How it works?\' title=\'How it works?\'></a></div>\n";
    }

    #print STDERR "02 $item $host $type : $tmp_dir/$host/$type-$item-d.cmd : $QUERY_STRING\n";
    $graph[$graph_indx] = $item;
    $graph_indx++;
    if ( $st_type =~ m/SWIZ/ && $item =~ /^sys$/ ) {
      # add compress 
      $graph[$graph_indx] = "compress";
      $graph_indx++;
    }
  }

  # print out tabs
  my $tab_number = 0;
  print "<div  id=\"tabs\"> <ul>\n";
  foreach $item (<@graph>) {
    # data source back/fron end
    my $data_type = "tabfrontend";
    if ( $item =~ m/_b$/ ) {
      $data_type = "tabbackend";
    }
  
    my $tab_name = text_tab($item,"item",$st_type,$type);
    print "  <li class=\"$data_type\"><a href=\"#tabs-$tab_number\">$tab_name</a></li>\n";
    $tab_number++;
  }
  print "   </ul> \n";

  $tab_number = 0;
  foreach $item (<@graph>) {
    my $item_name = $item;

    print "<div id=\"tabs-$tab_number\"><br><br><center>\n";
    if ( $gui == 0 ) {
      print "<center><h3>$item_name</h3></center>";
    }
  
    print "<table align=\"center\" summary=\"Graphs\">\n";
  
    print "<tr>\n";
    print_item ($host,$type,$name,$item,"d",$detail_yes);
    print_item ($host,$type,$name,$item,"w",$detail_yes);
    print "</tr><tr>\n";
    print_item ($host,$type,$name,$item,"m",$detail_yes);
    print_item ($host,$type,$name,$item,"y",$detail_yes);
    print "</tr>\n";
    print "</table></center>\n";
    print "</div>\n";
    $tab_number++;
  }

  print "</div><br>\n";
  if ( $gui == 0 ) {
    print "</BODY></HTML>";
  }
} # create_tab

  
sub html_base
{
  my $refer = shift;

    # Print link to full lpar cfg (must find out at first html_base
    # find out HTML_BASE
    # renove from the path last 3 things
    # http://nim.praha.cz.ibm.com/lpar2rrd/hmc1/PWR6B-9117-MMA-SN103B5C0%20ttt/pool/top.html
    # --> http://nim.praha.cz.ibm.com/lpar2rrd
    my $html_base = "";
      my @full_path = split(/\//, $refer);
      my $k = 0;
      foreach my $path (@full_path){
        $k++
      }
      $k--;
      if ( $refer !~ m/topten-glo/ && $refer !~ m/cpu_max_check/ ) { # when top10 global then just once
        $k--; $k--;
      }
      my $j = 0;
      foreach my $path (@full_path){
        if ($j < $k) {
          if ( $j == 0 ) {
            $html_base .= $path;
          }
          else {
            $html_base .= "/".$path;
          }
          $j++;
        }
      }

    return $html_base;
}

sub make_agg
{
  my $host = shift;
  my $type = shift;
  my $name = shift;
  my $item = shift;
  my $st_type = shift;
  my $cache_once = 0;

  # list of all items with its priority
  my @items_high = "io data resp cap cache cpu cache-node pprc operating";


  # print out tabs
  my $tab_number = 0;
  print "<div  id=\"tabs\"> <ul>\n";

  # go though all @items_high and check if at least one is available
  my $data_string = "sum_data data data_rate read write read_b write_b ";


  # create tab header
  foreach my $item_high (<@items_high>) {
    #print STDERR "00 - $item_high - $name -\n";
    if ( $name !~ m/$item_high/ ) {
      next;
    }
    foreach my $name_act (<@items_sorted>) {
      #print STDERR "01 $item_high,$name_act \n";
      if ( ! -f "$tmp_dir/$host/$type-$name_act-d.cmd" ) {
        next; # non existing metric
      }
      
      if ($item_high !~ m/^cpu$/ && $item_high !~ m/^cap$/ && $name_act !~ m/data/ && $name_act !~ m/^read$/ && $name_act !~ m/^write$/ && $name_act !~ m/$item_high/ && $name_act !~ m/^read_b$/ && $name_act !~ m/^write_b$/ && $name_act !~ m/-subsys$/ && $item_high !~ m/^cache-node$/ && $item_high !~ m/^operating$/ ) {
        next;
      }

      #print STDERR "03 $item_high,$name_act: $item_high - $data_string\n";
      if ($name_act =~ m/data/ || $name_act =~ m/^read$/ || $name_act =~ m/^write$/ || $name_act =~ m/^read_b$/ || $name_act =~ m/^write_b$/) {
        if ( $data_string !~ m/$item_high / && $name_act !~ m/pprc/ && $name_act !~ m/-subsys$/ ) {
          next;
        }
      }

      if ( $name_act =~ m/-subsys$/ && $item_high =~ m/io/ ) {
        if ( $name_act !~ m/io_rate-subsys/ && $name_act !~ m/write_io-subsys/ && $name_act !~ m/read_io-subsys/ ) {
          next;
        }
      }
      if ( $name_act =~ m/-subsys$/ && $item_high =~ m/data/ ) {
        if ( $name_act !~ m/data_rate-subsys/ && $name_act !~ m/write-subsys/ && $name_act !~ m/read-subsys/ ) {
          next;
        }
      }
      if ( $name_act =~ m/-subsys$/ && $item_high =~ m/resp/ ) {
        next;
      }

      if ( $item_high =~ m/operating/ && $name_act !~ m/operating/ ) {
        next;
      }

      #print STDERR "04 $item_high,$name_act: $item_high - $data_string\n";
      # capacity POOL
      if ($item_high =~ m/^cap$/ ) {
        if ( $name_act !~ m/^tier/ && $name_act !~ m/^used$/ && $name_act !~ m/^sum_capacity$/ ) {
          next;
        }
      }
      #print STDERR "05 $item_high,$name_act: $item_high - $data_string\n";

      # port and data_rate && io_rate vrs PPRC ....
      if ( $item_high =~ m/data/ || $item_high =~ m/io/ )  {
        if ( $type =~ /PORT/ && $name_act =~ m/pprc/ ) {
          next;
        }
      }
      #print STDERR "06 $item_high,$name_act\n";

      

      # found it, create the page and tabs  

      # data source back/fron end
      my $data_type = "tabfrontend";
      if ( $type =~ /^POOL$/ && $st_type !~ m/^DS8K$/ && $st_type !~ m/^SWIZ$/ ) {
        $data_type = "tabbackend";
      }
      if ( $st_type =~ m/^DS5K$/ || $st_type =~ m/^HUS$/ || $st_type =~ m/^NETAPP/ || $st_type =~ m/^3PAR/ || $st_type =~ m/^VSPG/ ) {
        $data_type = "tabfrontend";
      }
      if ( $type =~ /^RANK$/ || $name_act =~ m/_b$/ ) {
        $data_type = "tabbackend";
      }
      if ( $type =~ /^NODE-CACHE$/ ) {
        $data_type = "tabfrontend";
      }
      if ( $item_high =~ m/^cache$/ && $cache_once == 0 ) {
        # cache for storwirwize, table, not graphs
        if ( -f "$webdir/$host/cache-r_cache_hit.html" ) {
          print "  <li class=\"$data_type\"><a href=\"$host/cache-r_cache_hit.html\">read hit avrg</a></li>\n";
        }
        if ( -f "$webdir/$host/cache-w_cache_hit.html" ) {
          print "  <li class=\"$data_type\"><a href=\"$host/cache-w_cache_hit.html\">write hit avrg</a></li>\n";
        }
        if ( -f "$webdir/$host/cache-cache_hit.html" ) {
          print "  <li class=\"$data_type\"><a href=\"$host/cache-cache_hit.html\">cache hit avrg</a></li>\n";
        }
        if ( -f "$webdir/$host/cache-read_pct.html" ) {
          print "  <li class=\"$data_type\"><a href=\"$host/cache-read_pct.html\">read percent avrg</a></li>\n";
        }
        if ( -f "$webdir/$host/cache-ssd_r_cache_hit.html" ) {
          print "  <li class=\"$data_type\"><a href=\"$host/cache-ssd_r_cache_hit.html\">SSD read cache hit avrg</a></li>\n";
        }
        $cache_once++;
      }

      my $tab_name = text_tab($name_act,"aggregated",$st_type,$type);
      print "  <li class=\"$data_type\"><a href=\"#tabs-$tab_number\">$tab_name</a></li>\n";
      $tab_number++;
      #print STDERR "02 $item_high,$host,$type,$name_act,$st_type,$item\n";
    }
  }
  print "</ul>\n";

  my $tab_number = 0;
  $cache_once = 0;
  # create body of the tabs
  foreach my $item_high (<@items_high>) {
    if ( $name !~ m/$item_high/ ) {
      next;
    }
    foreach my $name_act (<@items_sorted>) {
      if ( ! -f "$tmp_dir/$host/$type-$name_act-d.cmd" ) {
        next; # non existing metric
      }
      if ($item_high !~ m/^cpu$/ && $item_high !~ m/^cap$/ && $name_act !~ m/data/ && $name_act !~ m/^read$/ && $name_act !~ m/^write$/ && $name_act !~ m/$item_high/ && $name_act !~ m/^read_b$/ && $name_act !~ m/^write_b$/ && $name_act !~ m/-subsys$/ && $item_high !~ m/^cache-node$/ && $item_high !~ m/^operating$/ ) {
        next;
      }
      if ($name_act =~ m/data/ || $name_act =~ m/^read$/ || $name_act =~ m/^write$/ || $name_act =~ m/^read_b$/ || $name_act =~ m/^write_b$/) {
        if ( $data_string !~ m/$item_high / && $name_act !~ m/pprc/ && $name_act !~ m/-subsys$/ ) {
          next;
        }
      }

      if ( $name_act =~ m/-subsys$/ && $item_high =~ m/io/ ) {
        if ( $name_act !~ m/io_rate-subsys/ && $name_act !~ m/write_io-subsys/ && $name_act !~ m/read_io-subsys/ ) {
          next;
        }
      }
      if ( $name_act =~ m/-subsys$/ && $item_high =~ m/data/ ) {
        if ( $name_act !~ m/data_rate-subsys/ && $name_act !~ m/write-subsys/ && $name_act !~ m/read-subsys/ ) {
          next;
        }
      }
      if ( $name_act =~ m/-subsys$/ && $item_high =~ m/resp/ ) {
        next;
      }

      if ( $item_high =~ m/operating/ && $name_act !~ m/operating/ ) {
        next;
      }

      # capacity POOL
      if ($item_high =~ m/^cap$/ ) {
        if ( $name_act !~ m/^tier/ && $name_act !~ m/^used$/ && $name_act !~ m/^sum_capacity$/ ) {
          next;
        }
      }

      # port and data_rate && io_rate vrs PPRC ....
      if ( $item_high =~ m/data/ || $item_high =~ m/io/ )  {
        if ( $type =~ /PORT/ && $name_act =~ m/pprc/ ) {
          next;
        }
      }
      # found it, create the page and tabs  

      # data source back/fron end
      my $data_type = "tabfrontend";
      if ( $type =~ /^POOL$/ && $st_type !~ m/^DS8K$/ && $st_type !~ m/^SWIZ$/ ) {
        $data_type = "tabbackend";
      }
      if ( $st_type =~ m/^DS5K$/ || $st_type =~ m/^HUS$/ || $st_type =~ m/^NETAPP/ || $st_type =~ m/^3PAR/ ) {
        $data_type = "tabfrontend";
      }
      if ( $type =~ /^RANK$/ || $name_act =~ m/_b$/ ) {
        $data_type = "tabbackend";
      }
      if ( $type =~ /^NODE-CACHE$/ ) {
        $data_type = "tabfrontend";
      }

      print "<div id=\"tabs-$tab_number\"><br><br><center>\n";
      $tab_number++;
      create_tab_agg($item_high,$host,$type,$name_act,$st_type,$item);
      print "</div>\n";
    }
  }
  print "</div>\n";

}


sub create_tab_agg
{
  my ($item_high,$host,$type,$name,$st_type,$item) = @_;

  print "<table align=\"center\" summary=\"Graphs\">\n";

  print "<tr>\n";
  print_item ($host,$type,$name,$item,"d",$detail_yes);
  print_item ($host,$type,$name,$item,"w",$detail_yes);
  print "</tr><tr>\n";
  print_item ($host,$type,$name,$item,"m",$detail_yes);
  print_item ($host,$type,$name,$item,"y",$detail_yes);
  print "</tr>\n";
  print "</table>\n";

  return 1;
}

sub print_item
{
  my ($host,$type,$name,$item,$time,$detail) = @_;
  my $refresh = "";
  my $legend_class = "nolegend";

  if ($item !~ /^sum/) {
	$legend_class = ""; 
  }
  if ($name =~ /^sum/) {
	$legend_class = "";
  }
  if (( $name =~ m/^sum_data$/ ) ||
      ( $name =~ m/^sum_io$/ )   ||
      ( $name =~ m/^sum_io_total$/ )   ||
      ( $name =~ m/^sum_data_total$/ )   ||
      ( $name =~ m/^sum_capacity$/ ) ||
      ( $name =~ m/^tier0$/ )    ||
      ( $name =~ m/^tier1$/ )    ||
      ( $name =~ m/^tier2$/ )    ||
      ( $name =~ m/^io_rate-subsys$/ )    ||
      ( $name =~ m/^data_rate-subsys$/ )  ||
      ( $name =~ m/^read_io-subsys$/ )    ||
      ( $name =~ m/^write_io-subsys$/ )   ||
      ( $name =~ m/^read-subsys$/ )    ||
      ( $name =~ m/^write-subsys$/ )   ||
      ( $name =~ m/^used$/ )   ||
      ( $name =~ m/^sys$/ )
     ) {
      $legend_class = "";
  }
  if ($type =~ m/HOST/) {
    $legend_class = "nolegend";
  }
  if ( $st_type =~ "^SAN-" ) {
    if ( $item eq "san_data" || $item eq "san_io" || $item eq "san_io_size" || $item eq "san_errors" || $item eq "san_credits" ) {
      $legend_class = "";
    }
    else {
      $legend_class = "nolegend";
    }
  }
  if ( $item =~ "^custom-group" ) {
    $legend_class = "nolegend";
  }

  # It must be here otherwise does notwork for example "#" in the $name
  $name =~s/([^A-Za-z0-9\+-_])/sprintf("%%%02X",ord($1))/seg;
  $host =~s/([^A-Za-z0-9\+-_])/sprintf("%%%02X",ord($1))/seg;
  # print STDERR "009 print_item enter:$host,$type,$name,$item,$time,$detail,$legend_class,\n";

  if ( $detail > 0 ) {
    print "<td valign=\"top\" class=\"relpos\">
      <div>
        <div class=\"favs favoff\"></div>
        <div class=\"popdetail\"></div>$refresh
        <a class=\"detail\" href=\"/stor2rrd-cgi/detail-graph.sh?host=$host&type=$type&name=$name&item=$item&time=$time&detail=1&none=$time_u\">
        <div title=\"Click to show detail\">
        <img class=\"lazy $legend_class\" border=\"0\" data-src=\"/stor2rrd-cgi/detail-graph.sh?host=$host&type=$type&name=$name&item=$item&time=$time&detail=0&none=$time_u\" src=\"$html_base/jquery/images/loading.gif\">
        <div class=\"zoom\" title=\"Click and drag to select range\"></div>
        </div>
        </a>
        <div class=\"legend\"></div>
        <div class=\"updated\"></div>
      </div>
      </td>\n";
  }
  else {
    print "<td align=\"center\" valign=\"top\" colspan=\"2\"><div><img class=\"lazy\" border=\"0\" data-src=\"/stor2rrd-cgi/detail-graph.sh?host=$host&type=$type&name=$name&item=$item&time=$time&detail=0&none=$time_u\" src=\"$html_base/jquery/images/loading.gif\"></div></td>\n";
  }
  return 1;
}

sub basename {
  my $full = shift;
  my $out = "";

  # basename without direct function
  my @base = split(/\//,$full);
  foreach my $m (@base) {
    $out = $m;
  }

  return $out;
}

sub text_tab 
{
  my $item = shift;
  my $type_out = shift;
  my $st_type = shift;
  my $type = shift;
  my $text_out = $item;

 
  if ( $type_out =~ m/^aggregated$/ ) {
    if ( $item =~ m/^sum_io$/ )        { $text_out = "total"; };
    if ( $item =~ m/^sum_io_total$/ )  { $text_out = "total"; };
    if ( $item =~ m/^sum_data$/ )      { $text_out = "total"; };
    if ( $item =~ m/^sum_data_total$/ ){ $text_out = "total"; };
    if ( $item =~ m/^io_rate$/ )       { $text_out = "total"; };
    if ( $item =~ m/^io_rate$/ && $type =~ m/POOL/ && $st_type =~ m/DS5K/)    { $text_out = "aggregated"; };
    if ( $item =~ m/^io_rate$/ && $type =~ m/POOL/ && $st_type =~ m/HUS/)     { $text_out = "aggregated"; };
    if ( $item =~ m/^io_rate$/ && $type =~ m/RANK/ && $st_type =~ m/NETAPP/)  { $text_out = "aggregated"; };
    if ( $item =~ m/^io_rate$/ && $type =~ m/POOL/ && $st_type =~ m/3PAR/)    { $text_out = "aggregated"; };
    if ( $item =~ m/^io_rate$/ && $type =~ m/RANK/ && $st_type =~ m/HUS/)     { $text_out = "aggregated"; };
    if ( $item =~ m/^io_rate$/ && $type =~ m/POOL/ && $st_type =~ m/VSPG/)     { $text_out = "aggregated"; };
    if ( $item =~ m/^data_rate$/ )     { $text_out = "total"; };
    if ( $item =~ m/^data_rate$/ && $type =~ m/POOL/ && $st_type =~ m/DS5K/)  { $text_out = "aggregated"; };
    if ( $item =~ m/^data_rate$/ && $type =~ m/POOL/ && $st_type =~ m/HUS/)   { $text_out = "aggregated"; };
    if ( $item =~ m/^data_rate$/ && $type =~ m/POOL/ && $st_type =~ m/VSPG/)   { $text_out = "aggregated"; };
    if ( $item =~ m/^data_rate$/ && $type =~ m/RANK/ && $st_type =~ m/NETAPP/){ $text_out = "aggregated"; };
    if ( $item =~ m/^data_rate$/ && $type =~ m/POOL/ && $st_type =~ m/3PAR/)  { $text_out = "aggregated"; };
    if ( $item =~ m/^data_rate$/ && $type =~ m/RANK/ && $st_type =~ m/HUS/)   { $text_out = "aggregated"; };
    if ( $item =~ m/^sum_capacity$/ )  { $text_out = "capacity"; };
    if ( $item =~ m/^read_io$/ )       { $text_out = "read"; };
    if ( $item =~ m/^write_io$/ )      { $text_out = "write"; };
    if ( $item =~ m/^read$/ )          { $text_out = "read"; };
    if ( $item =~ m/^write$/ )         { $text_out = "write"; };
    if ( $item =~ m/^r_cache_hit$/ )   { $text_out = "read hit"; };
    if ( $item =~ m/^w_cache_hit$/ )   { $text_out = "write hit"; };
    if ( $item =~ m/^r_cache_usage$/ ) { $text_out = "read usage"; };
    if ( $item =~ m/^w_cache_usage$/ ) { $text_out = "write usage"; };
    if ( $item =~ m/^resp_t$/ )        { $text_out = "total"; };
    if ( $item =~ m/^resp_t_r$/ )      { $text_out = "read"; };
    if ( $item =~ m/^resp_t_w$/ )      { $text_out = "write"; };
    if ( $item =~ m/^read_io_b$/ )     { $text_out = "read back"; };
    if ( $item =~ m/^write_io_b$/ )    { $text_out = "write back"; };
    if ( $item =~ m/^read_b$/ )        { $text_out = "read back"; };
    if ( $item =~ m/^write_b$/ )       { $text_out = "write back"; };
    if ( $item =~ m/^resp_t_b$/ )      { $text_out = "total back"; };
    if ( $item =~ m/^resp_t_r_b$/ )    { $text_out = "read back"; };
    if ( $item =~ m/^resp_t_w_b$/ )    { $text_out = "write back"; };
    if ( $item =~ m/^sys$/ )           { $text_out = "CPU"; };
    if ( $item =~ m/^compress$/ )      { $text_out = "compress"; };
    if ( $item =~ m/^pprc_rio$/ )      { $text_out = "IO read"; };
    if ( $item =~ m/^pprc_wio$/ )      { $text_out = "IO write"; };
    if ( $item =~ m/^pprc_data_r$/ )   { $text_out = "read"; };
    if ( $item =~ m/^pprc_data_w$/ )   { $text_out = "write"; };
    if ( $item =~ m/^pprc_rt_r$/ )     { $text_out = "resp read"; };
    if ( $item =~ m/^pprc_rt_w$/ )     { $text_out = "resp write"; };
    if ( $item =~ m/^tier0$/ )         { $text_out = "tier 0"; };
    if ( $item =~ m/^tier1$/ )         { $text_out = "tier 1"; };
    if ( $item =~ m/^tier2$/ )         { $text_out = "tier 2"; };
    if ( $item =~ m/^used$/ )          { $text_out = "used"; };
    if ( $item =~ m/^cache_hit$/ )     { $text_out = "cache hit"; };
    if ( $item =~ m/^data_cntl$/ )     { $text_out = "controller"; };
    if ( $item =~ m/^io_cntl$/ )       { $text_out = "controller"; };
    if ( $item =~ m/^ssd_r_cache_hit$/ ) { $text_out = "SSD read cache"; };
    if ( $item =~ m/^write_pend$/ ) { $text_out = "write pending"; };
    if ( $item =~ m/^clean_usage$/ ) { $text_out = "clean queue"; };
    if ( $item =~ m/^middle_usage$/ ) { $text_out = "middle queue"; };
    if ( $item =~ m/^phys_usage$/ ) { $text_out = "physical queue"; };
    if ( $item =~ m/^operating_rate$/ ) { $text_out = "operating"; };
  }
  else {
    if ( $item =~ m/^sum_io$/ ) { $text_out = "IO"; };
    if ( $item =~ m/^sum_io_total$/ ) { $text_out = "IO"; };
    if ( $item =~ m/^sum_data$/ ) { $text_out = "data"; };
    if ( $item =~ m/^sum_data_total$/ ) { $text_out = "data"; };
    if ( $item =~ m/^io_rate$/ ) { $text_out = "IO"; };
    if ( $item =~ m/^data_rate$/ ) { $text_out = "data"; };
    if ( $item =~ m/^sum_capacity$/ ) { $text_out = "capacity"; };
    if ( $item =~ m/^read_io$/ ) { $text_out = "IO read"; };
    if ( $item =~ m/^write_io$/ ) { $text_out = "IO write"; };
    if ( $item =~ m/^read$/ ) { $text_out = "read"; };
    if ( $item =~ m/^write$/ ) { $text_out = "write"; };
    if ( $item =~ m/^r_cache_hit$/ ) { $text_out = "read cache hit"; };
    if ( $item =~ m/^w_cache_hit$/ ) { $text_out = "write cache hit"; };
    if ( $item =~ m/^r_cache_usage$/ ) { $text_out = "read usage"; };
    if ( $item =~ m/^w_cache_usage$/ ) { $text_out = "write usage"; };
    if ( $item =~ m/^resp_t$/ ) { $text_out = "resp time"; };
    if ( $item =~ m/^resp_t_r$/ ) { $text_out = "resp read"; };
    if ( $item =~ m/^resp_t_w$/ ) { $text_out = "resp write"; };
    if ( $item =~ m/^read_io_b$/ ) { $text_out = "IO read back"; };
    if ( $item =~ m/^write_io_b$/ ) { $text_out = "IO write back"; };
    if ( $item =~ m/^read_b$/ ) { $text_out = "read back"; };
    if ( $item =~ m/^write_b$/ ) { $text_out = "write back"; };
    if ( $item =~ m/^resp_t_b$/ ) { $text_out = "resp time back"; };
    if ( $item =~ m/^resp_t_r_b$/ ) { $text_out = "resp read back"; };
    if ( $item =~ m/^resp_t_w_b$/ ) { $text_out = "resp write back"; };
    if ( $item =~ m/^sys$/ ) { $text_out = "CPU"; };
    if ( $item =~ m/^compress$/ ) { $text_out = "compress"; };
    if ( $item =~ m/^pprc_rio$/ ) { $text_out = "PPRC IO read"; };
    if ( $item =~ m/^pprc_wio$/ ) { $text_out = "PPRC IO write"; };
    if ( $item =~ m/^pprc_data_r$/ ) { $text_out = "PPRC read"; };
    if ( $item =~ m/^pprc_data_w$/ ) { $text_out = "PPRC write"; };
    if ( $item =~ m/^pprc_rt_r$/ ) { $text_out = "PPRC resp read"; };
    if ( $item =~ m/^pprc_rt_w$/ ) { $text_out = "PPRC resp write"; };
    if ( $item =~ m/^tier0$/ ) { $text_out = "tier 0"; };
    if ( $item =~ m/^tier1$/ ) { $text_out = "tier 1"; };
    if ( $item =~ m/^tier2$/ ) { $text_out = "tier 2"; };
    if ( $item =~ m/^used$/ ) { $text_out = "used"; };
    if ( $item =~ m/^read_pct$/ ) { $text_out = "read percent"; };
    if ( $item =~ m/^cache_hit$/ ) { $text_out = "cache hit"; };
    if ( $item =~ m/^ssd_r_cache_hit$/ ) { $text_out = "SSD read cache hit"; };
    if ( $item =~ m/^san_data_sum_in$/ ) { $text_out = "IN"; };
    if ( $item =~ m/^san_data_sum_out$/ ) { $text_out = "OUT"; };
    if ( $item =~ m/^san_io_sum_credits$/ ) { $text_out = "BBCredits"; };
    if ( $item =~ m/^san_io_sum_crc_errors$/ ) { $text_out = "CRC errors"; };
    #if ( $item =~ m/^san_io_sum_encoding_errors$/ ) { $text_out = "Encoding errors"; };
    if ( $item =~ m/^san_io_sum_in$/ ) { $text_out = "IN"; };
    if ( $item =~ m/^san_io_sum_out$/ ) { $text_out = "OUT"; };
    if ( $item =~ m/^san_data_sum_tot_in$/ ) { $text_out = "IN"; };
    if ( $item =~ m/^san_data_sum_tot_out$/ ) { $text_out = "OUT"; };
    if ( $item =~ m/^san_io_sum_tot_credits$/ ) { $text_out = "BBCredits"; };
    if ( $item =~ m/^san_io_sum_tot_crc_errors$/ ) { $text_out = "CRC errors"; };
    #if ( $item =~ m/^san_io_sum_tot_encoding_errors$/ ) { $text_out = "Encoding errors"; };
    if ( $item =~ m/^san_io_sum_tot_in$/ ) { $text_out = "IN"; };
    if ( $item =~ m/^san_io_sum_tot_out$/ ) { $text_out = "OUT"; };
    if ( $item =~ m/^san_data$/ ) { $text_out = "Data"; };
    if ( $item =~ m/^san_io$/ ) { $text_out = "Frames"; };
    if ( $item =~ m/^san_io_size$/ ) { $text_out = "Frame size"; };
    if ( $item =~ m/^san_credits$/ ) { $text_out = "BBCredits"; };
    if ( $item =~ m/^san_errors$/ ) { $text_out = "Errors"; };
    if ( $item =~ m/^san_fabric_data_in$/ ) { $text_out = "Data in"; };
    if ( $item =~ m/^san_fabric_frames_in$/ ) { $text_out = "Frames in"; };
    if ( $item =~ m/^san_fabric_credits$/ ) { $text_out = "BBCredits"; };
    if ( $item =~ m/^san_fabric_crc_errors$/ ) { $text_out = "CRC errors"; };
    #if ( $item =~ m/^san_fabric_encoding_errors$/ ) { $text_out = "Encoding errors"; };
    if ( $item =~ m/^san_fabric_conf$/ ) { $text_out = "Configuration"; };
    if ( $item =~ m/^san_isl_data_in$/ ) { $text_out = "Data in"; };
    if ( $item =~ m/^san_isl_data_out$/ ) { $text_out = "Data out"; };
    if ( $item =~ m/^san_isl_frames_in$/ ) { $text_out = "Frames in"; };
    if ( $item =~ m/^san_isl_frames_out$/ ) { $text_out = "Frames out"; };
    if ( $item =~ m/^san_isl_frame_size_in$/ ) { $text_out = "Frame size in"; };
    if ( $item =~ m/^san_isl_frame_size_out$/ ) { $text_out = "Frame size out"; };
    if ( $item =~ m/^san_isl_credits$/ ) { $text_out = "BBCredits"; };
    if ( $item =~ m/^san_isl_crc_errors$/ ) { $text_out = "CRC errors"; };
    # custom groups
    if ( $item =~ m/^data_in$/ ) { $text_out = "Data in"; };
    if ( $item =~ m/^data_out$/ ) { $text_out = "Data out"; };
    if ( $item =~ m/^frames_in$/ ) { $text_out = "Frames in"; };
    if ( $item =~ m/^frames_out$/ ) { $text_out = "Frames out"; };
    if ( $item =~ m/^credits$/ ) { $text_out = "BBCredits"; };
    if ( $item =~ m/^errors$/ ) { $text_out = "CRC errors"; };
    if ( $item =~ m/^crc_errors$/ ) { $text_out = "CRC errors"; };

    if ( $item =~ m/^write_pend$/ ) { $text_out = "write pending"; };
    if ( $item =~ m/^clean_usage$/ ) { $text_out = "clean queue"; };
    if ( $item =~ m/^middle_usage$/ ) { $text_out = "middle queue"; };
    if ( $item =~ m/^phys_usage$/ ) { $text_out = "physical queue"; };
    if ( $item =~ m/^operating_rate$/ ) { $text_out = "operating"; };
  }
  
    return $text_out;
}


sub non_existing_data
{
  my $host = shift;
  my $name = shift;

  print "There is no any volume attached to that host: $name\n";
  
  return 0;
}

sub find_vols
{
  my $host = shift;
  my $type = shift;
  my $lpar = shift;

  if ( ! -f "$wrkdir/$host/$type/hosts.cfg" ) {
    return 0;
  }
  open(FHH, "< $wrkdir/$host/$type/hosts.cfg") || error ("Can't open $wrkdir/$host/$type/hosts.cfg : $! ".__FILE__.":".__LINE__) && return "";
  my @hosts = <FHH>;
  close(FHR);

  foreach my $line (@hosts) {
    chomp ($line);
    (my $host_name, my $volumes ) = split (/ : /,$line);
    if ( ! defined ($volumes) ) {
      next;
    }
    $volumes =~ s/ //g;

    # must be used this no regex construction otherwise m// does not work with names with ()
    if ( $host_name eq $lpar && ! $volumes eq '' ) {
      return 1;
    }
  }
  return 0;
}

sub volumes_top_all
{
  my $host = shift;
  my $type = shift;
  my $item = shift;
  my $st_type = shift;
  my $name = shift;
  my $CGI_DIR = "stor2rrd-cgi";
  my $time_unix = time();
  my $data_type = "tabfrontend";
  my $class = "class=\"$data_type\"";
  my $class_url = "class=\"lazy\" src=\"$html_base/jquery/images/loading.gif\"";
  $class_url = "";
 
  # print tab page only
  print "<div  id=\"tabs\"> <ul>\n";
  print "  <li $class><a $class_url href=\"/$CGI_DIR/detail-graph.sh?host=$host&type=$type&name=$name&item=avrg&time=d&detail=0&none=$time_unix\">daily</a></li>\n";
  print "  <li $class><a $class_url href=\"/$CGI_DIR/detail-graph.sh?host=$host&type=$type&name=$name&item=avrg&time=w&detail=0&none=$time_unix\">weekly</a></li>\n";
  print "  <li $class><a $class_url href=\"/$CGI_DIR/detail-graph.sh?host=$host&type=$type&name=$name&item=avrg&time=m&detail=0&none=$time_unix\">monthly</a></li>\n";
  #print "  <li $class><a $class_url href=\"/$CGI_DIR/detail-graph.sh?host=$host&type=$type&name=$name&item=avrg&time=y&detail=0&none=$time_unix\">yearly</a></li>\n";
  print "  <li $class><a $class_url href=\"/$CGI_DIR/detail-graph.sh?host=$host&type=$type&name=$name&item=max&time=d&detail=0&none=$time_unix\">daily max</a></li>\n";
  print "  <li $class><a $class_url href=\"/$CGI_DIR/detail-graph.sh?host=$host&type=$type&name=$name&item=max&time=w&detail=0&none=$time_unix\">weekly max</a></li>\n";
  print "  <li $class><a $class_url href=\"/$CGI_DIR/detail-graph.sh?host=$host&type=$type&name=$name&item=max&time=m&detail=0&none=$time_unix\">monthly max</a></li>\n";
  #print "  <li $class><a $class_url href=\"/$CGI_DIR/detail-graph.sh?host=$host&type=$type&name=$name&item=max&time=y&detail=0&none=$time_unix\">yearly max</a></li>\n";
  print "</ul> \n";
  print "</div>\n";
    
  return 1;
}

sub error
{
  my $text = shift;
  my $act_time = localtime();

  if ( $text =~ m/no new input files, exiting data load/ ) {
    print "ERROR          : $text \n";
    print STDERR "$act_time: $text \n";
  }
  else {
    print "ERROR          : $text : $!\n";
    print STDERR "$act_time: $text : $!\n";
  }

  return 1;
}

sub create_tab_custom
{
  # /stor2rrd-cgi/detail.sh?host=na&type=VOLUME&name=Agrp1&storage=na&item=custom&gui=1&none=none 
  #( my $host,my $type, my $name, my $st_type, my $item, my $gui, my $referer) = split(/&/,$QUERY_STRING);

  my ($host,$type,$name,$st_type,$item)= @_;

  # tab summary at first
  my $data_type = "tabfrontend";
  my $tab_number = 0;
  print "<div  id=\"tabs\"> <ul>\n";
  foreach my $item_act (<@items_sorted>) {
    if ( ! -f "$tmp_dir/custom-group/$name-$item_act-d.cmd" ) {
      next;
    }
    # print out tabs
    my $tab_name = text_tab($item_act,"item");
    print "  <li class=\"$data_type\"><a href=\"#tabs-$tab_number\">$tab_name</a></li>\n";
    $tab_number++;
  }
  print "   </ul> \n";

  my $notice_file = "$tmp_dir/custom-group/.$name-ll.cmd";
  my @final_notice = "";
  if ( -f $notice_file) {
     open(FH, "$notice_file") || error("Cannot open $notice_file: $!".__FILE__.":".__LINE__) && return 0;
     @final_notice = <FH>;
     close (FH);
  }

  # tab body
  $tab_number = 0;
  foreach my $item_act (<@items_sorted>) {
    if ( ! -f "$tmp_dir/custom-group/$name-$item_act-d.cmd" ) {
      next;
    }
    print "<div id=\"tabs-$tab_number\"><br><br><center>\n";
    print "<table align=\"center\" summary=\"Graphs\">\n";

    print "<tr>\n";
    print_item ($host,$type,$name,"custom-group-".$item_act,"d",$detail_yes);
    print_item ($host,$type,$name,"custom-group-".$item_act,"w",$detail_yes);
    print "</tr><tr>\n";
    print_item ($host,$type,$name,"custom-group-".$item_act,"m",$detail_yes);
    print_item ($host,$type,$name,"custom-group-".$item_act,"y",$detail_yes);
    print "</tr>\n";
    print "</table>@final_notice</center>\n";
    print "</div>\n";
    $tab_number++;
  }

  print "</div><br>\n";

  return 1;
}

