#!/bin/sh

[ -n "$INCLUDE_ONLY" ] || {
	. /lib/functions.sh
	. ../netifd-proto.sh
	init_proto "$@"
}

proto_ncm_init_config() {
	no_device=1
	available=1
	proto_config_add_string "device:device"
	proto_config_add_string apn
	proto_config_add_string auth
	proto_config_add_string enabled
	proto_config_add_string username
	proto_config_add_string password
	proto_config_add_string pincode
	proto_config_add_string delay
	proto_config_add_string mode
	proto_config_add_string pdptype
	proto_config_add_boolean ipv6
	proto_config_add_boolean ifname
}

proto_ncm_setup() {
	local interface="$1"

	local manufacturer initialize setmode connect devname devpath

	local device apn auth enabled username password pincode delay mode pdptype ipv6 ifname
	json_get_vars device apn auth enabled username password pincode delay mode pdptype ipv6 ifname

	if [ "$enabled" != "1" ]; then
		ifdown ppp_usb
		return 0
	fi

	ipv6=0

	if [ "$ipv6" = 0 ]; then
		ipv6=""
	else
		ipv6=1
	fi
	
	[ -n "$pdptype" ] && {
		if [ "$pdptype" == "1" ]; then
			pdptype="IP"
		fi
	}

	[ -z "$pdptype" ] && {
		if [ -n "$ipv6" ]; then
			pdptype="IPV4V6"
		else
			pdptype="IP"
		fi
	}

	[ -n "$ctl_device" ] && device=$ctl_device

	[ -n "$device" ] || {
		echo "No control device specified"
		proto_notify_error "$interface" NO_DEVICE
		proto_set_available "$interface" 0
		return 1
	}
	[ -e "$device" ] || {
		echo "Control device not valid"
		proto_set_available "$interface" 0
		return 1
	}

	#[ -n "$apn" ] || {
		#echo "No APN specified"
		#proto_notify_error "$interface" NO_APN
		#return 1
	#}

	#devname="$(basename "$device")"
	#case "$devname" in
	#'tty'*)
	#	devpath="$(readlink -f /sys/class/tty/$devname/device)"
	#	ifname="$( ls "$devpath"/../../*/net )"
	#	;;
	#*)
	#	devpath="$(readlink -f /sys/class/usbmisc/$devname/device/)"
	#	ifname="$( ls "$devpath"/net )"
	#	;;
	#esac
	[ -n "$ifname" ] || {
		echo "The interface could not be found."
		proto_notify_error "$interface" NO_IFACE
		proto_set_available "$interface" 0
		return 1
	}

	[ -n "$delay" ] && sleep "$delay"

	#manufacturer=`gcom -d "$device" -s /etc/gcom/getcardinfo.gcom | awk '/Manufacturer/ { print tolower($2) }'`
	manufacturer="telit"
	[ $? -ne 0 ] && {
		echo "Failed to get modem information"
		proto_notify_error "$interface" GETINFO_FAILED
		return 1
	}

	json_load "$(cat /etc/gcom/ncm.json)"
	json_select "$manufacturer"
	[ $? -ne 0 ] && {
		echo "Unsupported modem"
		proto_notify_error "$interface" UNSUPPORTED_MODEM
		proto_set_available "$interface" 0
		return 1
	}

	if [ -n "$apn" ]; then
		json_get_values initialize initialize
	else
		json_get_values initialize initialize_no_apn
	fi

	for i in $initialize; do
		eval COMMAND="$i" gcom -d "$device" -s /etc/gcom/runcommand.gcom || {
			echo "Failed to initialize modem"
			proto_notify_error "$interface" INITIALIZE_FAILED
			return 1
		}
	done

	[ -n "$pincode" ] && {
		PINCODE="$pincode" gcom -d "$device" -s /etc/gcom/setpin.gcom || {
			echo "Unable to verify PIN"
			proto_notify_error "$interface" PIN_FAILED
			proto_block_restart "$interface"
			return 1
		}
	}

	ifconfig "$ifname" -arp up

	[ -n "$mode" ] && {
		json_select modes
		json_get_var setmode "$mode"
		COMMAND="$setmode" gcom -d "$device" -s /etc/gcom/runcommand.gcom || {
			echo "Failed to set operating mode"
			proto_notify_error "$interface" SETMODE_FAILED
			return 1
		}
		json_select ..
	}

	if [ -n "$apn" ]; then
		json_get_var connect connect
	else
		json_get_var connect connect_no_apn
	fi
	eval COMMAND="$connect" gcom -d "$device" -s /etc/gcom/runcommand.gcom || {
		echo "Failed to connect"
		proto_notify_error "$interface" CONNECT_FAILED
		return 1
	}

	if [ -n "$apn" ]; then
		IP=`gsmctl -A AT+CGPADDR=4 | awk -F '"' '{print $2}'`
	else
		IP=`gsmctl -A AT+CGPADDR=1 | awk -F '"' '{print $2}'`
	fi
	echo "$IP"

	if [ -n "$apn" ]; then
		CGCONTRDP=`gsmctl -A AT+CGCONTRDP=4`
	else
		CGCONTRDP=`gsmctl -A AT+CGCONTRDP=1`
	fi
	GW=`echo $CGCONTRDP | awk -F '"' '{print $6}'`
	NETMASK=`echo $CGCONTRDP | awk -F '"' '{print $4}' | awk -F '.' '{print $5"."$6"."$7"."$8}'`
	DNS=`echo $CGCONTRDP | awk -F '"' '{print $8}'`
	DNS2=`echo $CGCONTRDP | awk -F '"' '{print $10}'`
	echo "$GW"
	ifconfig wwan0 "$IP" netmask "$NETMASK" up
	route add default gw "$GW"
	/sbin/arp –s "$GW" 11:22:33:44:55:66

	echo "nameserver $DNS" >> /tmp/resolv.conf.auto
	echo "nameserver $DNS2" >> /tmp/resolv.conf.auto

	proto_init_update "$ifname" 1 1
	proto_add_ipv4_address "$IP" "$NETMASK" "" "${GW:-2.2.2.2}"
	proto_add_ipv4_route 0.0.0.0 0 "$GW"
	proto_add_dns_server "$DNS"
	proto_add_dns_server "$DNS2"
	proto_send_update "$interface"

	#echo "Connected, starting DHCP on $ifname"
	#proto_init_update "$ifname" 1
	#proto_send_update "$interface"

	#json_init
	#json_add_string name "${interface}_4"
	#json_add_string ifname "@$interface"
	#json_add_string proto "dhcp"
	#ubus call network add_dynamic "$(json_dump)"

	#[ -n "$ipv6" ] && {
	#	json_init
	#	json_add_string name "${interface}_6"
	#	json_add_string ifname "@$interface"
	#	json_add_string proto "dhcpv6"
	#	json_add_string extendprefix 1
	#	ubus call network add_dynamic "$(json_dump)"
	#}
}

proto_ncm_teardown() {
	local interface="$1"

	local manufacturer disconnect

	local device apn
	json_get_vars device apn

	echo "Stopping network"

	#manufacturer=`gcom -d "$device" -s /etc/gcom/getcardinfo.gcom | awk '/Manufacturer/ { print tolower($2) }'`
	manufacturer="telit"
	[ $? -ne 0 ] && {
		echo "Failed to get modem information"
		proto_notify_error "$interface" GETINFO_FAILED
		return 1
	}

	json_load "$(cat /etc/gcom/ncm.json)"
	json_select "$manufacturer" || {
		echo "Unsupported modem"
		proto_notify_error "$interface" UNSUPPORTED_MODEM
		return 1
	}

	if [ -n "$apn" ]; then
		json_get_var disconnect disconnect
	else
		json_get_var disconnect disconnect_no_apn
	fi
	COMMAND="$disconnect" gcom -d "$device" -s /etc/gcom/runcommand.gcom || {
		echo "Failed to disconnect"
		proto_notify_error "$interface" DISCONNECT_FAILED
		return 1
	}

	ifconfig wwan0 "0.0.0.0" down
	proto_init_update "*" 0
	proto_send_update "$interface"
}
[ -n "$INCLUDE_ONLY" ] || {
	add_protocol ncm
}
