#!/bin/sh

PIPE=$1

mkfifo $PIPE
while [ 1 ]
do
	logread -f > $PIPE
	sleep 1
done
