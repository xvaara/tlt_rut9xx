#!/bin/sh

MAX_COUNT="3"
FILE="/tmp/.modem_check_count"
count=`cat "$FILE" 2>/dev/null | grep -o '[0-9]*' | grep "" -m 1`

sleep 5

devs=`ls /dev/ | grep -c ttyACM`
if [ "$devs" -ge 4 ]; then
	rm -f "$FILE"
	exit
fi

sleep 30

devs=`ls /dev/ | grep -c ttyACM`
if [ "$devs" -lt 4 ]; then
	if [ -z "$count" ]; then
		count=1
	fi

	if [ "$count" -gt "$MAX_COUNT" ]; then
		logger -t "modem_check" "Max count '$MAX_COUNT' reached"
		exit
	fi
	
	logger -t "modem_check" "Only '$devs' devices found. Restarting"
	count=`expr $count + 1`
	echo "$count" > "$FILE"
	/etc/init.d/modem restart &
else
	rm -f "$FILE"
fi
