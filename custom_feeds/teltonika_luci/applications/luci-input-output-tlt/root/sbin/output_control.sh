#!/bin/sh

# $1 - gpio (DOUT1 or DOUT2)
# $2 - action (set or clear)
# $3 - timeout
if [ -n "$3" ]; then
	local action="clear"
	local current_output=`/sbin/gpio.sh get $1`
	
	if [ "$current_output" -eq "1" ]; then
		action="set"
	fi
	
	/sbin/gpio.sh $2 $1
	sleep $3
	/sbin/gpio.sh $action $1
else
	/sbin/gpio.sh $2 $1
fi
