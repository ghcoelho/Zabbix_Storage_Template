#!/usr/bin/perl

use strict;
use warnings;
# use Data::Dumper;

use lib "../bin";    # maybe useless, but didn't work for me without that
use Alerting;             # use module

my %cfg = Alerting::getConfig();

print "Content-type: text/html\n\n";

# TABs
my $tab_number = 0;
print <<_MARKER_;
<div id='tabs'> 
  <ul>
    <li><a href='#tabs-1'>Alerts</a></li>
    <li><a href='#tabs-2'>E-mail groups</a></li>
    <li><a href='#tabs-3'>Options</a></li>
    <li><a href='/stor2rrd-cgi/log-cgi.sh?name=alertlogs&gui=1'>Alerting log</a></li>
  </ul>

_MARKER_

print <<_MARKER_;
<div id='tabs-1'> 
  <p>&nbsp;</p>
  <div style='float: left; margin-right: 10px; outline: none'>
    <fieldset class='estimator cggrpnames'>
      <table id="alrttree" class="cfgtree">
        <colgroup>
          <col width="2px">
          <col width="2px">
          <col width="180px">
          <col width="80px">
          <col width="45px">
          <col width="45px">
          <col width="60px">
          <col width="110px">
          <col width="120px">
          <col width="10px">
          <col width="20px">
        </colgroup>
        <thead>
        <tr>
          <th></th>
          <th></th>
          <th id="addcgrpth">Alert <button id="addnewalrt">Add New</button></th>
          <th>Metric</th>
          <th><abbr title="limit value in MB/sec or IOPS">Limit</abbr></th>
          <th><abbr title="time in minutes for length peak above the limit [5-120]">Peak</abbr></th>
          <th><abbr title="minimum time in minutes between 2 alerts for the same rule [5-168]">Repeat</abbr></th>
          <th><abbr title="time range in hours when the alerting is off [0-24]-[0-24]. Ex. 22-05&nbsp;(excludes alerting from 10pm to 5am)">Exclude hours</abbr></th>
          <th>Mail group</th>
          <th></th>
          <!--th><button id="cgcfg-help-button" title="Help on usage">?</button></th-->
        </tr>
        </thead>
        <tbody>
        </tbody>
      </table>
    </fieldset>
    <div style="text-align: center">
      <input type='submit' style='font-weight: bold; margin-top: .7em' name='savegrp' class='savealrtcfg' value='Save configuration'>
    </div>
  </div>

  <br style="clear: both">
  <pre>
  <div id='aclfile' style='text-align: left; margin: auto; background: #fcfcfc; border: 1px solid #c0ccdf; border-radius: 10px; padding: 15px; display: none; overflow: auto'></div>
  </pre>
</div>

<div id='tabs-2'> 
  <p>&nbsp;</p>
  <div style='float: left; margin-right: 10px; outline: none'>
    <fieldset class='estimator cggrpnames'>
      <table id="alrtgrptree" class="cfgtree">
        <colgroup>
          <col width="2px">
          <col width="2px">
          <col width="320px">
          <col width="4px">
          <col width="20px">
        </colgroup>
        <thead>
        <tr>
        <th></th>
        <th></th>
        <th id="addcgrpth">E-mail group &nbsp;<button id="addalrtgrp">Add New</button></th>
        <th></th>
        <!--th><button id="cgcfg-help-button" title="Help on usage">?</button></th-->
        </tr>
        </thead>
        <tbody>
        </tbody>
      </table>
    </fieldset>
    <div style="text-align: center">
      <input type='submit' style='font-weight: bold; margin-top: .7em' name='savegrp' class='savealrtcfg' value='Save configuration'>
    </div>
  </div>
</div>
<style>
#optform  { 
  display: table;
}
#optform div {
  display: table-row;  
}
#optform label {
  display: table-cell; 
}
#optform input { 
  display: table-cell; 
}
</style>
<div id='tabs-3'> 
  <p>&nbsp;</p>
  <div style='float: left; margin-right: 10px; outline: none'>
    <form id="optform" method="post" action="" style="display: table;">
    <fieldset>
    <div>
      <label for="element_2">Nagios alerting &nbsp;</label>
      <input id="element_2" name="NAGIOS" class="alrtoption text medium" type="text" maxlength="255" title="Call this script from nrpe.cfg: bin/check_stor2rrd<br>More details on <a href='http://www.stor2rrd.com/nagios.html'>http://www.stor2rrd.com/nagios.html</a><br>[0/1] on/off" value="$cfg{NAGIOS}"> 
    </div>
    <div>
    <label for="element_3">External script for alerting &nbsp;</label>
      <input id="element_3" name="EXTERN_ALERT" class="alrtoption text medium" type="text" maxlength="255" title="It will be called once an alarm appears with these 5 parameters:<br><pre>script.sh  [storage] [volume] [metric] [actual value] [limit]</pre>- you can use <b>bin/external_alert_example.sh</b> as an example<br>- script must be placed in <b>{LPAR2RRD_HOME}/bin</b> and path start with <b>bin/</b>" value="$cfg{EXTERN_ALERT}"> 
    </div>
    <div>
    <label for="element_4">Include graphs &nbsp;</label>
      <input id="element_4" name="EMAIL_GRAPH" class="alrtoption text medium" type="text" maxlength="255" title="Include graphs into the email notification.<br>Any positive number gives number of hours which the graph contains. Examples: <br>0 - false<br>8 - last 8 hours in the graph<br>25 - last 25 hours in the graph<br>[0 - 256]" value="$cfg{EMAIL_GRAPH}"> 
    </div>
    <div>
    <label for="element_5">Default repeat time (min)&nbsp;</label>
      <input id="element_5" name="REPEAT_DEFAULT" class="alrtoption text medium" type="text" maxlength="255" title="Default time in minutes which says how often you should be alerted. You can specify per volume different value in <b>alert repeat time</b> column of each ALERT<br>[5 - 168]" value="$cfg{REPEAT_DEFAULT}"> 
    </div>
    <div>
    <label for="element_6">Default peak time (min)&nbsp;</label>
      <input id="element_6" name="PEAK_TIME_DEFAULT" class="alrtoption text medium" type="text" maxlength="255" title="The period of time in which avg traffic utilization has to be over the specified limit to generate an alert.<br>You can change it per volume level in <b>time in min</b> column of each ALERT note.<br> It should not be shorter than sample rate for particular storage (usually 5 minutes)<br>[5 - 120]" value="$cfg{PEAK_TIME_DEFAULT}"> 
    </div>
    </fieldset>
    <div style="text-align: center">
      <input type='submit' style='font-weight: bold; margin-top: .7em' name='savegrp' class='savealrtcfg' value='Save configuration'>
    </div>
    </form>
  </div>
</div>
<div id='tabs-4'> 
  <p>&nbsp;</p>
</div>

</div>
_MARKER_
