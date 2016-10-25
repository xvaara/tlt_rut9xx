#!/bin/sh
# Copyright (C) 2014 Teltonika

. /lib/sms_call_functions.sh
NEED_REBOOT=0
RULES_ENABLED=0
RejectCall(){
	local reject_incoming_calls=`uci -q get call_utils.call.reject_incoming_calls`
	if [ "$reject_incoming_calls" == "1" ]; then
			gsmctl -A AT+CHUP
	fi
	}
ExecuteRules() {
	getstate=""
	local phone="$2"
	config_get enabled "$1" "enabled" "0"

	config_get allowed_phone "$1" "allowed_phone" "all"
	case "$allowed_phone" in
		all)
			bad_tel=0
			;;
		single)
			config_get tel "$1" "tel" ""
			if [ "$tel" == "$phone" ]; then
				bad_tel=0
			else
				bad_tel=1
			fi
			;;
		group)
			config_get group "$1" "group" ""
			good_tel=`Check_phone "$group" "$phone"`
			bad_tel=$?
			;;
		*)
			bad_tel=1
		;;
	esac
	if [ "$bad_tel" -eq 1 ] && [ "$enabled" == "1" ]; then
		RejectCall
		return 1
	fi
	if [ "$enabled" != "1" ]; then
		return 1
	fi
	RULES_ENABLED=1
	gsmctl -A AT+CHUP
	config_get action "$1" "action"
	case "$action" in
		reboot)
			message=""
			config_get status_sms "$1" "status_sms" "0"
			if [ "$status_sms" == "1" ]; then
				config_get message "$1" "message" "0"
				uci set sms_utils.smsreboot.enabled="1"
				uci set sms_utils.smsreboot.tel="$phone"
				uci set sms_utils.smsreboot.message="$message"
				
				uci commit sms_utils
			else
				uci set sms_utils.smsreboot.enabled="0"
				uci set sms_utils.smsreboot.tel=""
				uci set sms_utils.smsreboot.message=""
				uci commit sms_utils
			fi
			NEED_REBOOT=1
			;;
		wifi)
			config_get value "$1" "value" "on"
			config_get writecfg "$1" "write_wifi" "0"
			if [ "$value" == "off" ]; then
				ManageWifi "0" "$writecfg"
				/usr/bin/eventslog -i -t EVENTS -n Call -e "WiFi turned off by $phone"
			else
				ManageWifi "1" "$writecfg"
				/usr/bin/eventslog -i -t EVENTS -n Call -e "WiFi turned on by $phone"
			fi
			;;
		mobile)
			config_get value "$1" "value" "on"
			config_get writecfg "$1" "write_mobile" "0"
			if [ "$value" == "off" ]; then
				Manage3G "0" "$writecfg"
				/usr/bin/eventslog -i -t EVENTS -n Call -e "3G turned off by $phone"
			else
				Manage3G "1" "$writecfg"
				/usr/bin/eventslog -i -t EVENTS -n Call -e "3G turned on by $phone"
			fi
			;;
		dout)
			config_get value "$1" "value" "on"
			config_get outputnb "$1" "outputnb"
			config_get timeout "$1" "timeout"
			
			if [ "$timeout" == "1" ]; then
				config_get seconds "$1" "seconds"

				if [ "$value" == "off" ]; then
					gpio.sh clear "$outputnb"&& (sleep "$seconds"; gpio.sh set "$outputnb")&
					/usr/bin/eventslog -i -t EVENTS -n Call -e "GPIO $outputnb turned off by $phone for $seconds seconds"
				else
					gpio.sh set "$outputnb"&& (sleep "$seconds"; gpio.sh clear "$outputnb")&
					/usr/bin/eventslog -i -t EVENTS -n Call -e "GPIO $outputnb turned on by $phone for $seconds seconds"
				fi
			
			elif [ "$value" == "off" ]; then
				gpio.sh set "$outputnb"
				/usr/bin/eventslog -i -t EVENTS -n Call -e "GPIO $outputnb turned off by $phone"
			else
				gpio.sh clear "$outputnb"
				/usr/bin/eventslog -i -t EVENTS -n Call -e "GPIO $outputnb turned on by $phone"
			fi
			;;
		send_status)
			config_get message "$1" "message" "0"
			SendStatus "$phone" "$message"
			/usr/bin/eventslog -i -t EVENTS -n Call -e "Status sent to $phone"
			;;
	esac
}

if [ -n "$1" ] ; then
	config_load call_utils
	config_foreach ExecuteRules "rule" "$1"
	if [ "$RULES_ENABLED" -eq 0 ]; then
		RejectCall
	fi
	if [ "$NEED_REBOOT" -eq 1 ]; then
		/usr/bin/eventslog -i -t EVENTS -n Call -e "Reboot initialized by $1"
		reboot -s
	fi
	return 0
fi
return 1
