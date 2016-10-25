#!/bin/sh

local host="$1"
local interval="$2"

while [ 1 ]; do
	ping -c 1 "$host"
	sleep "$interval"
done
