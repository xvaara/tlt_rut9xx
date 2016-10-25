#!/bin/sh
INCLUDE_ONLY=1

. /lib/teltonika-functions.sh
. ../netifd-proto.sh
. ./ppp.sh
init_proto "$@"

proto_3g_init_config() {
	no_device=1
	available=1
	ppp_generic_init_config
	proto_config_add_string "device"
	proto_config_add_string "apn"
	proto_config_add_string "service"
	proto_config_add_string "enabled"
	proto_config_add_string "dialnumber"
	proto_config_add_string "roaming"
}

proto_3g_setup() {
	local interface="$1"
	local chat_path="/tmp/chatscripts"
	local chat="$chat_path/3g.chat"
	local evidpid=$(get_ext_vidpid_tlt)

	if [ ! -d "$chat_path" ]; then
		mkdir "$chat_path"
	fi
	
	json_get_var device device
	json_get_var apn apn
	json_get_var service service
	json_get_var enabled enabled
	json_get_var dialnumber dialnumber
	json_get_var roaming roaming
	
	# if roaming - exit
	if [ "$roaming" == "1" ]; then
		local variable=`gsmctl -A "AT+CREG?"`
		local stat=${variable#*,}
		if [ "$stat" == "5" ]; then
			logger -t $0 "roaming detected"
			return 1
		fi
	fi

	[ -e "$device" ] || {
		proto_set_available "$interface" 0
		return 1
	}
	
	# if ppp disabled - exit
	if [ "$enabled" != "1" ]; then
		return 0
	fi
	
	# Check GSMD	
	if [ "$(pidof gsmd)" ] 
	then
		echo "$config(3g): gsmd is running"
	else
		/etc/init.d/gsmd start
		sleep 3
	fi
	
	case "$service" in
		cdma |\
		evdo) 
			chat="$chat_path/evdo.chat"
			;;
		
		*)
	esac
	
	# making chat script
	case "$service" in
		cdma |\
		evdo)
			rm -f $chat > /dev/null 2>&1
			printf "ABORT	BUSY\n" >> $chat
			printf "ABORT 	'NO CARRIER'\n" >> $chat
			printf "ABORT	ERROR\n" >> $chat
			printf "ABORT 	'NO DIAL TONE'\n" >> $chat
			printf "ABORT 	'NO ANSWER'\n" >> $chat
			printf "ABORT 	DELAYED\n" >> $chat
			printf "REPORT	CONNECT\n" >> $chat
			printf "TIMEOUT	10\n" >> $chat
			printf "'' 		AT\n" >> $chat
			printf "OK 		ATZ\n" >> $chat
			printf "SAY     'Calling CDMA/EVDO'\n" >> $chat
			printf "TIMEOUT	30\n" >> $chat
			printf "OK		ATD$dialnumber\n" >> $chat
			printf "CONNECT	''\n" >> $chat
			sync
			;;
				
		*)
			# default to UMTS
			rm -f $chat > /dev/null 2>&1
			printf "ABORT   BUSY\n" >> $chat
			printf "ABORT   'NO CARRIER'\n" >> $chat
			printf "ABORT   ERROR\n" >> $chat
			printf "REPORT  CONNECT\n" >> $chat
			printf "TIMEOUT 10\n" >> $chat
			printf "\"\"      ATZ\n" >> $chat
			printf "\"\"      \"AT&F\"\n" >> $chat
			# Huawei LTE modem has echo enabled by default, so we disable it because it messes up output of GSMD.
			if [ "$evidpid" = "12D1:1573" ]; then
				printf "OK      \"ATVE0\"\n" >> $chat
			else
				printf "OK      \"ATE1\"\n" >> $chat
			fi
			if [ "$evidpid" = "1BC7:1201" ]; then
				printf "OK      'AT+CREG=2'\n" >> $chat
			fi
			printf "OK      'AT+CGDCONT=1,\"IP\",\"\$USE_APN\"'\n" >> $chat
			printf "SAY     \"Calling UMTS/GPRS\"\n" >> $chat
			printf "TIMEOUT 30\n" >> $chat
			printf "OK      \"ATD$dialnumber\"\n" >> $chat
			printf "CONNECT ' '\n" >> $chat
			sync
			;;
	esac
	
	local chat_args=""
	local pppd_aux_args=""
	local enable_chat_log="`uci get system.system.enable_chat_log`"
	local enable_pppd_debug="`uci get system.system.enable_pppd_debug`"

	
	if [ "$enable_chat_log" == "0" ]
	then
		logger "3g.sh: \"chat\" logging disabled by uci"
		chat_args="-t5 -S -E -f $chat"
	else
		chat_args="-t5 -v -E -f $chat"
	fi
	
	if [ "$enable_pppd_debug" == "1" ]
	then
		logger "3g.sh: setting \"pppd\" to debug mode"
		pppd_aux_args="debug"
	fi

	#Clear uncolicited messages from device
	microcom -t 100 "$device" >/dev/null 2>&1

	connect="${apn:+USE_APN=$apn }/usr/sbin/chat  $chat_args"
	ppp_generic_setup "$interface" \
		$pppd_aux_args \
		noaccomp \
		nopcomp \
		novj \
		nobsdcomp \
		noauth \
		lock \
		crtscts \
		115200 "$device"
	return 0
}

proto_3g_teardown() {
	proto_kill_command "$interface"
	# Stop Passthrough
	ifconfig br-lan:0 down 2>/dev/null
}

add_protocol 3g
