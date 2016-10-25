#!/bin/sh

# iptables log
INPUT=$1
# filtered log
OUTPUT=$2
# wait untile next read
# in seconds
PERIOD=$3

usage() {
	echo "wifitracker <INPUT_FILE> \
<OUTPUT_FILE> <WAIT_PERIOD>"
}

if [ "$#" != "3" ]
then
	usage
	exit 1
fi

if [ ! -e $INPUT ]
then
	echo "no input"
	exit 1
fi

while [ 1 ]
do
	while read LINE
	do
		# parse iptables log entry into bash variables
		# acording to KEY=VALUE instances using GAWK.
		# NOTICE: this piece of code is very iptables-log
		# output format specific.
		if [ `echo $LINE | grep -c "URGP"` -eq "1" ]
		then
			eval `echo $LINE | awk '
			BEGIN {
				pmonth=""
				pday=""
				ptime=""
				prawtime=""
				piniface=""
				poutiface=""
				pmacs=""
				psrcip=""
				pdstip=""
				psrcport=""
				pdstport=""
				rawtime=""
				dstmac=""
				srcmac=""
				year=""
				FS=" "
			}
			
				{
				if ( NF == "25" )
				{
					{ pmonth=$1; sub(/^.*=/,"",pmonth) }
					{ pday=$2; sub(/^.*=/,"",pday) }
					{ ptime=$3; sub(/^.*=/,"",ptime) }
					{ prawtime=$7; sub(/^.*=/,"",prawtime) }
					{ rawtime=substr(prawtime,2,index(prawtime, ".")) }
					{ piniface=$8; sub(/^.*=/,"",piniface) }
					{ poutiface=$9; sub(/^.*=/,"",poutiface) }
					{ pmacs=$10; sub(/^.*=/,"",pmacs) }
					{ dstmac=substr(pmacs,1,17) }
					{ srcmac=substr(pmacs,19,17) }
					{ psrcip=$11; sub(/^.*=/,"",psrcip) }
					{ pdstip=$12; sub(/^.*=/,"",pdstip) }
					{ psrcport=$20; sub(/^.*=/,"",psrcport) }
					{ pdstport=$21; sub(/^.*=/,"",pdstport) }
					{ year=strftime("%Y") }
				}
				else if ( NF == "26" )
				{
					{ pmonth=$1; sub(/^.*=/,"",pmonth) }
					{ pday=$2; sub(/^.*=/,"",pday) }
					{ ptime=$3; sub(/^.*=/,"",ptime) }
					{ prawtime=$8; sub(/^.*=/,"",prawtime) }
					{ rawtime=substr(prawtime,2,index(prawtime, ".")) }
					{ piniface=$9; sub(/^.*=/,"",piniface) }
					{ poutiface=$10; sub(/^.*=/,"",poutiface) }
					{ pmacs=$11; sub(/^.*=/,"",pmacs) }
					{ dstmac=substr(pmacs,1,17) }
					{ srcmac=substr(pmacs,19,17) }
					{ psrcip=$12; sub(/^.*=/,"",psrcip) }
					{ pdstip=$13; sub(/^.*=/,"",pdstip) }
					{ psrcport=$21; sub(/^.*=/,"",psrcport) }
					{ pdstport=$22; sub(/^.*=/,"",pdstport) }
					{ year=strftime("%Y") }
				}
				else if ( NF == "27" )
				{
					{ pmonth=$2; sub(/^.*=/,"",pmonth) }
					{ pday=$3; sub(/^.*=/,"",pday) }
					{ ptime=$4; sub(/^.*=/,"",ptime) }
					{ prawtime=$9; sub(/^.*=/,"",prawtime) }
					{ rawtime=substr(prawtime,2,index(prawtime, ".")) }
					{ piniface=$10; sub(/^.*=/,"",piniface) }
					{ poutiface=$11; sub(/^.*=/,"",poutiface) }
					{ pmacs=$12; sub(/^.*=/,"",pmacs) }
					{ dstmac=substr(pmacs,1,17) }
					{ srcmac=substr(pmacs,19,17) }
					{ psrcip=$13; sub(/^.*=/,"",psrcip) }
					{ pdstip=$14; sub(/^.*=/,"",pdstip) }
					{ psrcport=$22; sub(/^.*=/,"",psrcport) }
					{ pdstport=$23; sub(/^.*=/,"",pdstport) }
					{ year=strftime("%Y") }
				}
				}
		
			END {
				printf "pmonth=\"%s\"\n", pmonth
				printf "pday=\"%s\"\n", pday
				printf "ptime=\"%s\"\n", ptime
				printf "prawtime=\"%s\"\n", prawtime
				printf "rawtime=\"%s\"\n", rawtime
				printf "piniface=\"%s\"\n", piniface
				printf "poutiface=\"%s\"\n", poutiface
				printf "pmacs=\"%s\"\n", pmacs
				printf "dstmac=\"%s\"\n", dstmac
				printf "srcmac=\"%s\"\n", srcmac
				printf "psrcip=\"%s\"\n", psrcip
				printf "pdstip=\"%s\"\n", pdstip
				printf "psrcport=\"%s\"\n", psrcport
				printf "pdstport=\"%s\"\n", pdstport
				printf "year=\"%s\"\n", year
			}'`
			
			# some entry handle logic 
			if [ "$pdstport" == "80" -o \
				"$pdstport" == "443" -o \
				"$pdstport" == "21" ]
			then
				if [ "$srcmac" != "" -a \
					"$pdstip" != "" -a \
					"$year" != "" -a \
					"$pmonth" != "" -a \
					"$pday" != "" -a \
					"$ptime" != "" ]
				then
					if [ "$srcmac" != "$last_srcmac" -o \
						"$pdstip" != "$last_pdstip" -o \
						"$year" != "$last_year" -o \
						"$pmonth" != "$last_pmonth" -o \
						"$pday" != "$last_pday" ]
					then
						echo "$srcmac;$pdstip;$year-$pmonth-$pday;$ptime;$pdstport" >> $OUTPUT
					elif [ "$ptime" != "$last_ptime" ]; then
						if [ ! -z $last_record ]; then
							seconds=`date -d "$ptime" "+%s"`
							time_interval=$(( seconds-last_record ))
						else
							time_interval=11
						fi

						if [ $time_interval -gt 10 ]; then
							echo "$srcmac;$pdstip;$year-$pmonth-$pday;$ptime;$pdstport" >> $OUTPUT
							last_record=`date -d "$ptime" "+%s"`
						fi
					fi
					last_srcmac=$srcmac
					last_pdstip=$pdstip
					last_year=$year
					last_pmonth=$pmonth
					last_pday=$pday
					last_ptime=$ptime
				fi
			fi
		fi
	done < $INPUT
	
	sleep $PERIOD
	sync
	# prevent full flash here
	freeleft=`df -Pk . | tail -1 | awk '{print $4}'`
	if [ "$freeleft" -lt "200" ]
	then
		logger "wifitracker: not enough space - exiting"
		exit 1
	fi
done
