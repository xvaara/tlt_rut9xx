#!/bin/sh

#
# Indicate reset button pressed time
#
# (c) 2014 Teltonika

LEDBAR="/usr/sbin/ledbar.sh"

$LEDBAR
for i in 0 1 2 3 4
do
	sleep 1
	$LEDBAR $i
done

exit 0

