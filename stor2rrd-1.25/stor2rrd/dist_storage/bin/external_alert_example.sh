#!/bin/ksh
#
# STOR2RRD example script for external alerting
#

STORAGE=$1	# storage
VOLUME=$2 	# volume
METRIC=$3	# metric
ACTUAL_VALUE=$4 # actual utilization
LIMIT=$5 	# utilization limit - maximum
TIME=$6

#
# here is place for your code ....
#

OUT_FILE=/tmp/alert_log

echo "Received alert : $TIME: $STORAGE $VOLUME $METRIC : $ACTUAL_VALUE : $LIMIT" >> $OUT_FILE

exit 0
