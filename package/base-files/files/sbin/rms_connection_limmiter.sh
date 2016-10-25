!/bin/sh

local tun_interface=`ifconfig | grep "tun_rms"`

if [ -z "$tun_interface"  ]; then 
	local counter=`cat /tmp/rms_fail_counter.dat`
	if [ -z "$counter"  ]; then 
		counter=0
	fi
	
	counter=$((counter+1))
	echo "$counter" > /tmp/rms_fail_counter.dat
	
	if [ $counter -gt 9 ]; then 
		sed -i /rms_connection_limmiter/d /tmp/spool/cron/crontabs/root
		/etc/init.d/cron restart
		rm -f /tmp/rms_fail_counter.dat
		uci set openvpn.teltonika_auth_service.enable=0
		uci commit openvpn
		luci-reload
	fi 
else
	sed -i /rms_connection_limmiter/d /tmp/spool/cron/crontabs/root
	/etc/init.d/cron restart
	rm -f /tmp/rms_fail_counter.dat
fi
