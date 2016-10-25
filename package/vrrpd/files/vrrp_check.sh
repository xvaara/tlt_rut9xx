#!/bin/sh

 CONFIG_GET="uci get vrrpd.ping"
 CONFIG_SET="uci set vrrpd.ping"

 HOST=`$CONFIG_GET.host`
# LOG_LEVEL=`$CONFIG_GET.log_level`
 WAIT=`$CONFIG_GET.time_out`
 P_SIZE=`$CONFIG_GET.packet_size`
 ENABLE=`$CONFIG_GET.enabled`
 COUNT=`$CONFIG_GET.ping_attempts`
 RETRY=`$CONFIG_GET.retry`
 INTERVAL=`$CONFIG_GET.interval`

 DEBUG=1
 PID_FILE=/var/run/vr_check.pid

debug() {

[ $DEBUG -eq 1 ] && logger "$1"

}


if [ "$ENABLE" = 1 ]; then

	echo $$ > $PID_FILE
	debug "Created pid file: $PID_FILE ID: $$"
	while true; do
		local proces
		proces=`ls /var/run/ | grep vrrp`
		ping -c ${COUNT:-1} -W ${WAIT:-5} -s ${P_SIZE:-56} ${HOST:-8.8.8.8} > /dev/null 2>&1

		case $? in
			0)
				debug "Ping to ${HOST:-8.8.8.8} successful"
				$CONFIG_SET.fail_counter=0
				if [ "$proces" == "" ]
				then
					debug "Starting vrrpd"
					/etc/init.d/vrrpd start
				else
					debug "vrrpd is running"
				fi
				;;
			1)
				if [ "$proces" == "" ]
				then
					debug "vrrpd is stoped"
				else
					local failure=`$CONFIG_GET.fail_counter`
					failure=$(( failure + 1 ))
					$CONFIG_SET.fail_counter=$failure
					debug "PING failed. Retry $failure of $RETRY"

					if [ "$failure" -ge "${RETRY:-5}" ] ; then
						debug "Killing vrrpd after $failure unsuccessful retries"
						/etc/init.d/vrrpd stop
						/usr/bin/eventslog -i -t EVENTS -n 'VRRP' -e 'Stopping vrrp. We are now a backup router'
					fi
				fi

				;;
			*)
				debug "Unknown code $?"
				;;
		esac
		sleep ${INTERVAL-2}
	done
fi

