#!/bin/ash

local cpudatatick=$(top -n1 | awk ' { print $7 }' | tail -n20 | sed 's/[^0-9]//g' | awk '{ sum+=$1} END {print sum}')
echo "$cpudatatick" >> "/tmp/top_output"

local cpudataloglength=$(wc -w < /tmp/top_output)

if [ $cpudataloglength -ge 4 ]
then
local cpufivedata=$(cat /tmp/top_output | tail -n4)
local cpudataloglength=4
echo "$cpufivedata" > "/tmp/top_output"
fi

local cpudatasum=0; for i in `cat /tmp/top_output`; do cpudatasum=$(($cpudatasum + $i)); done;
local cpuloadaverage=$(awk "BEGIN {printf \"%.2f\",${cpudatasum}/${cpudataloglength}}")

echo "$cpuloadaverage"




