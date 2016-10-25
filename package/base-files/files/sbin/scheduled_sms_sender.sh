#!/bin/sh
# (C) 2015 Teltonika

number="$1"
text="$2"
lock /tmp/scheduled_sms_temp
#echo "number=$1, text=$2"
response=`gsmctl -Ss "$number $text"`
#echo "response=$response"
lock -u /tmp/scheduled_sms_temp
