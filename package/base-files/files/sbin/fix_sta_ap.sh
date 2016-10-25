#!/bin/sh
#
# @Author LI Zhuohuan <zixia@zixia.net>
# @Date 3/10/2015
#
# This script fix lost AP signal when STA fail.
# it runs background, loop & check.
# if STA fail, it disable STA and re-enable AP.
#
# I believe when wifi radio in both AP & STA(client) mode, 
# the driver need to know which channel to use first.
# so AP will not functional until STA established the link.
# after STA link connect, AP will know and use the same channel that STA use.
# so AP have to wait, and there will no AP at all if STA setting error.
#


DEBUG=1
TIMEOUT=4
SLEEP=2
SCAN_SLEEP=10
STA_STOP=
STA_SSID=
STA_DISSABLE=
SIGNAL_THRESHOLD=
FIRS_START=0
RETRY="0"
COUNT=
TRIALS=0
 
get_signal_threshold(){
  n=`uci show wireless.@wifi-iface[99] 2>/dev/null | grep @wifi-iface | grep -v =wifi-iface | cut -d. -f2 | uniq | cut -d[ -f2 | cut -d] -f1 | sort | tail -1`
	while [ $n -ge 0 ]; do
		mode=`uci get wireless.@wifi-iface[$n].mode`
		if [ X$mode == Xsta ]; then
			SIGNAL_THRESHOLD=`uci get -q wireless.@wifi-iface[$n].signal_threshold`
		fi
		let n=n-1
	done
}

check_status() {
	n=`uci show wireless.@wifi-iface[99] 2>/dev/null | grep @wifi-iface | grep -v =wifi-iface | cut -d. -f2 | uniq | cut -d[ -f2 | cut -d] -f1 | sort | tail -1`
	while [ $n -ge 0 ]; do
		mode=`uci get wireless.@wifi-iface[$n].mode`
		if [ X$mode == Xsta ]; then
			STA_DISSABLE=`uci get -q wireless.@wifi-iface[$n].disabled`
			STA_STOP=`uci get -q wireless.@wifi-iface[$n].stopped`
			STA_SSID=`uci get -q wireless.@wifi-iface[$n].ssid`
			SCAN_SLEEP=`uci get -q wireless.@wifi-iface[$n].scan_sleep`
			SLEEP=`uci get -q wireless.radio0.scan_sleep`
			RETRY=`uci get -q wireless.radio0.repeat`
			COUNT=`uci get -q wireless.radio0.count`
			[ ! $SCAN_SLEEP ] && SCAN_SLEEP=10
			[ ! $SLEEP ] && SLEEP=2
		fi
		let n=n-1
	done
}

disable_sta() {
	n=`uci show wireless.@wifi-iface[99] 2>/dev/null | grep @wifi-iface | grep -v =wifi-iface | cut -d. -f2 | uniq | cut -d[ -f2 | cut -d] -f1 | sort | tail -1`
	#[ $DEBUG -gt 0 ] && echo "disable_sta: found $n ifaces"

	ap=0
	while [ $n -ge 0 ]; do
		mode=`uci get wireless.@wifi-iface[$n].mode`
		#echo "iface[$n] mode[$mode]"
	 	if [ X$mode == Xsta ]; then
	  		#echo "deleting wifi-iface[$n] for it's in sta mode"
	  		uci set wireless.@wifi-iface[$n].disabled='1'
	  		uci set wireless.@wifi-iface[$n].stopped='1'
	  		uci commit wireless
	 	elif [ X$mode == Xap ]; then
	  		#echo "found wifi-iface[$n] in ap mode."
	  		ap=1
	 	fi
	 		let n=n-1
		done

	wifi up
}

enable_sta() {
	n=`uci show wireless.@wifi-iface[99] 2>/dev/null | grep @wifi-iface | grep -v =wifi-iface | cut -d. -f2 | uniq | cut -d[ -f2 | cut -d] -f1 | sort | tail -1`
	#echo "Enabling STA"
	while [ $n -ge 0 ]; do
		mode=`uci get wireless.@wifi-iface[$n].mode`
		if [ X$mode == Xsta ]; then
			uci delete wireless.@wifi-iface[$n].disabled
	  		uci delete wireless.@wifi-iface[$n].stopped
	  		uci commit wireless
	  	fi
		let n=n-1
	done
	wifi up
}

monitor_scan() {
	sleep 10
	killall -9 iw
}

sta_err=0

while [ 1 -gt 0 ]; do

	ifnames=`ubus call network.wireless status | grep ifname | cut -d\" -f4`

	for ifname in $ifnames ; do
		#[ $DEBUG -gt 0 ] && echo "checking $ifname after sleep $SLEEP seconds..."
		iftype=`iw dev $ifname info | grep type | cut -d' ' -f2`
		#[ $DEBUG -gt 0 ] && echo "checking $ifname 's type: $iftype"
		if [ X$iftype == Xmanaged ]; then
			ssid=`iw dev $ifname link | grep SSID | cut -d' ' -f 2`
			#echo "ifname $ifname is STA mode, ssid[$ssid]"
			if [ X$ssid == "X" ]; then # AP mode disabled
				let sta_err=$sta_err+1 
				#echo "ifname $ifname not connected. err counter: $sta_err"
			else
				sta_err=0
				get_signal_threshold
				
				if [ $SIGNAL_THRESHOLD ] && [ $FIRS_START -ne 1 ] && [ "$STA_SSID" != "" ]; then
					sleep 2
					logger -t "fix_sta_ap" "Checking threshold on start"		
					monitor_scan &
					mon_pid=$!
					scan_results=`iw wlan0 scan | grep -E "signal|SSID" | grep "$STA_SSID" -B1`
					if [ "$scan_results" != "" ]; then
						FIRS_START=1
						signal=`echo $scan_results | awk '{split($0,a," "); print int(a[2])}'`
						#logger -t "fix_sta_ap" "Signal: $signal, required: $SIGNAL_THRESHOLD"
						if [ $signal -lt $SIGNAL_THRESHOLD  ]; then
							logger -t "fix_sta_ap" "Disabling on start"
							disable_sta
						fi
					fi
	# 				echo "end of scann"
					kill -9 $mon_pid >/dev/null 2>&1
				fi
			fi
		fi
		check_status
		if [ "$STA_STOP" == "1" ] && [ "$STA_DISSABLE" == "1" ]; then
# 			echo "scaning for STA"
			monitor_scan &
			mon_pid=$!
			scan_results=`iw wlan0 scan | grep -E "signal|SSID" | grep "$STA_SSID" -B1`
			scan_sta=`echo $scan_results | grep "$STA_SSID"`
# 			echo "end of scann"
			kill -9 $mon_pid >/dev/null 2>&1
			
			if [ "$scan_sta" != "" ]; then
				get_signal_threshold
				if [ $SIGNAL_THRESHOLD ]; then
					signal=`echo $scan_results | awk '{split($0,a," "); print int(a[2])}'`
					if [ $signal -ge $SIGNAL_THRESHOLD  ]; then
	# 					echo "FOUND $STA_SSID"
						#logger -t "fix_sta_ap" "Enabling sta (current $signal, $SIGNAL_THRESHOLD required)"
						enable_sta
					fi
				else
					logger -t "fix_sta_ap" "Enabling STA"
					enable_sta
				fi
			fi
			if [ "$RETRY" == "1" ]; then
				logger "TRIALS ==$TRIALS"
				if [ $TRIALS -lt $((COUNT)) ]; then
					logger -t "fix_sta_ap after retry" "Enabling STA"
					enable_sta
					TRIALS=$((TRIALS+1))
				fi
			fi
			sleep $SCAN_SLEEP
		fi
	done

	sleep $SLEEP;

	let err_time=$sta_err*$SLEEP
	#[ $DEBUG -gt 0 ] && [ $err_time -gt 0 ] && echo "err_time: $err_time"

	if [ $err_time -gt $TIMEOUT ]; then
		#echo "*** STA connect timeout[$err_time]. disable STA mode now... ***"
		sleep 1
		logger -t "fix_sta_ap" "Disabling STA"
		disable_sta
		sta_err=0
	fi

done

