#!/bin/sh
# Copyright (C) 2014 Teltonika

. /lib/teltonika-functions.sh

GPIO="/sbin/gpio.sh"
WAN=`get_wan_section type mobile`
CURRENT_SIM=$($GPIO get SIM)

case "$CURRENT_SIM" in
	1)
		CURRENT_SIM="sim1";;
	-1)
		CURRENT_SIM="sim1";;
	0)
		CURRENT_SIM="sim2";;
	*)
		echo "$0. Could not determine current SIM. exiting..."
		exit 1;;
esac

set_bridge() {
	local OLD_IFS=$IFS
	local option value
	IFS=$'\n'       # make newlines the only separator

	uci set network.lan2="interface"
	uci set network.lan2.ifname="br-lan"

	for line in `uci show network.lan`
	do
		option=`echo $line | awk -F. '{print $3}' | awk -F= '{print $1}'`

		if [ $option ] && [ "$option" != "ifname" -a "$option" != "type" ]; then
			value=`echo $line |  awk -F= '{print $2}'`
			uci -q set network.lan2.$option=$value
			uci -q delete network.lan.$option
		fi
	done

	uci set network."$WAN".ifname="3g-ppp" # Wan padarome 3g-ppp nes kitaip bridge neveiks
	uci set network."$WAN".proto="none"

	#lan section
	local lan_ifname=`uci -q get network.lan.ifname`
	uci set network.lan.proto="none"

	lan_ifname="`echo $lan_ifname | sed -e 's/\<eth2\>//g' | sed -e 's/\<wwan0\>//g'`"
	local wan_ifname=`uci get -q system.module.iface`
	uci set network.lan.ifname="$lan_ifname $wan_ifname"

	#wan section
	uci set network.wan.enabled="0"
	uci set network.wan2.enabled="0"
	uci set network.wan3.enabled="0"
	ifdown wan #kitaip setinant bridge kai wan mobile nesusidaro bridge

	#multiwan
	local mwan_enabled=`uci -q get multiwan.config.enabled`
	if [ "$mwan_enabled" == "1" ]; then
		uci set multiwan.config.enabled="0"
 	fi

 	uci commit network
 	IFS=$OLD_IFS
}

disable_bridge() {
	local has_lan2=`uci -q get network.lan2`
	if [ -n "$has_lan2" ]; then

		local OLD_IFS=$IFS
		local option value
		IFS=$'\n'       # make newlines the only separator

		for line in `uci show network.lan2`
		do
			option=`echo $line | awk -F. '{print $3}' | awk -F= '{print $1}'`

			if [ $option ] && [ "$option" != "ifname" -a "$option" != "type" ]; then
				value=`echo $line |  awk -F= '{print $2}'`
				uci -q set network.lan.$option=$value
			fi
		done

		#lan section
		local lan_ifname=`uci -q get network.lan.ifname`
		uci set network.lan.ifname="`echo $lan_ifname | sed -e 's/\<eth2\>//g' | sed -e 's/\<wwan0\>//g'`"

		uci delete -q network.lan2
		uci delete -q network.wan.enabled
		uci commit network
		IFS=$OLD_IFS
	fi
	ifup wan #kitaip keiciant wan is mobile i wired nepakyla eth1
}

firewall_redirect(){
	local enabled_value="$1"
	uci set firewall.E_SSH_W_P.enabled="$enabled_value"
	uci set firewall.E_HTTP_W_P.enabled="$enabled_value"
	uci set firewall.E_HTTPS_W_P.enabled="$enabled_value"
	uci set firewall.E_CLI_W_P.enabled="$enabled_value"
}

set_pbridge() {
	passthrough_mode=`uci -q get simcard."$CURRENT_SIM".passthrough_mode`
	uci set network.ppp.passthrough_dhcp="$passthrough_mode"
	if [ "$passthrough_mode" != "no_dhcp" ]; then
		mac=`uci -q get simcard."$CURRENT_SIM".mac`
		if [ "$mac" ]; then
			uci set network.ppp.mac="$mac"
		fi
		leasetime=`uci -q get simcard."$CURRENT_SIM".leasetime`
		uci set network.ppp.leasetime="$leasetime"
	fi

	firewall_redirect "1"
	#uci set network.ppp.mode="pbridge"
	sysctl -w net.ipv4.conf.all.route_localnet=1
	uci set -q firewall.pbridge.enabled=1
	uci delete -q firewall.A_PASSTH_T.enabled
	uci commit firewall
	uci commit network
	if ! grep -q 'net.ipv4.conf.all.route_localnet=1' /etc/sysctl.conf; then
		echo 'net.ipv4.conf.all.route_localnet=1' >> /etc/sysctl.conf
	fi
}

disable_pbridge() {
	#uci delete network.ppp.mode
	uci -q delete network.ppp.passthrough_dhcp
	uci -q delete network.ppp.leasetime
	uci -q delete network.ppp.mac
	config_load firewall "1"
	firewall_redirect "0"
	sysctl -w net.ipv4.conf.all.route_localnet=0 >/dev/nul
	ifconfig br-lan:0 down  2>/dev/null
	rm -f /tmp/tmp_file/dnsmasq_pbridge.conf
	uci set -q firewall.pbridge.enabled=0
	uci set -q firewall.A_PASSTH_T.enabled=0
	uci commit firewall
	uci commit network
	rm -f /tmp/tmp_file/pbridge_firewall.sh
	sed -i '/net.ipv4.conf.all.route_localnet=1/d' /etc/sysctl.conf
}

usage() {
	echo "`basename $0`: utility to set correct SIM config."
	echo -e "usage:\n\t`basename $0` <SWITCH_SIM>"
	echo -e "options:\n\t<SWITCH_SIM> - Use this argument if SIM needs to be switched. Optional.\n\t 1 - perform SIM switch only,\n\t 2 - perform SIM switch and restart the modem."
	echo -e "\t default - perform switch to default SIM and restart the modem."
	echo -e "\nexample:\n\t`basename $0`"
	echo -e "\t`basename $0` 1"

	exit 1
}

if [ $# -gt 1 ]; then
	if [ "$1" == "set" ] && [ $# -eq 3 ]; then
		case "$2" in
			"bridge")
				case "$3" in
					"1")
						#echo "bridge enable"
						set_bridge
						exit 0;;
					"0")
						disable_bridge
						exit 0;;
					*)
						usage
						exit 1;;
				esac;;
			"pbridge")
				case "$3" in
					"1")
						set_pbridge
						exit 0;;
					"0")
						disable_pbridge
						exit 0;;
					*)
						usage
						exit 1;;
				esac;;
			*)
				usage
				exit 1;;
		esac
	else
		usage
	fi
else
	if [ -n "$1" ] && [ "$1" != "1" ] && [ "$1" != "2" ] && [ "$1" != "default" ]; then
		usage
	fi
fi

IS_FIRST_LOGIN=`uci -q get teltonika.sys.first_login`
#Don't do anything on firsboot
[ "$IS_FIRST_LOGIN" = 1 ] && exit 0

PRIMARY_SIM=`uci -q get simcard.simcard.default`
case "$PRIMARY_SIM" in
	sim1)
		SECONDARY_SIM="sim2";;
	sim2)
		SECONDARY_SIM="sim1";;
	*)
		echo "$0. Could not determine primary SIM. exiting..."
		exit 1;;
esac

SWITCH_SIM=$1

if [ -n "$SWITCH_SIM" ]; then
	if [ "$CURRENT_SIM" = "$PRIMARY_SIM" ] && [ "$SWITCH_SIM" != "default" ]; then
		CURRENT_SIM="$SECONDARY_SIM"
		if [ "$PRIMARY_SIM" = "sim1" ]; then
			action="clear" # use SIM2
		elif [ "$PRIMARY_SIM" = "sim2" ]; then
			action="set" # use SIM1
		fi
	elif [ "$CURRENT_SIM" = "$SECONDARY_SIM" ]; then
		CURRENT_SIM="$PRIMARY_SIM"
		if [ "$PRIMARY_SIM" = "sim1" ]; then
			/usr/bin/eventslog -i -t EVENTS -n "Web UI" -e "Switched from SIM 2 to SIM 1"
			action="set" # use SIM1
		elif [ "$PRIMARY_SIM" = "sim2" ]; then
			/usr/bin/eventslog -i -t EVENTS -n "Web UI" -e "Switched from SIM 1 to SIM 2"
			action="clear" # use SIM2
		fi
	fi
fi

PARAMS="apn pincode dialnumber auth_mode service proto username password ifname roaming pdptype numeric method leasetime mac mode bind_mac"

#Copy SIM parameters to network config
case "$CURRENT_SIM" in
	"sim1") # master (SIM1)
		sim_index=1;;
	"sim2") # slave (SIM2)
		sim_index=2;;
	*)
		echo "$0. Error. Wrong CURRENT_SIM '$CURRENT_SIM'"
		exit 1;;
esac

method_value=`uci -q get simcard.sim"$sim_index".method`
for item in $PARAMS
do
	value=`uci -q get simcard.sim"$sim_index"."$item"`
	if [ "$item" == "ifname" ]; then

		uci set system.module.iface="$value"
		uci commit system

		if [ $WAN ] && [ "$method_value" != "bridge" ]; then
			wan_ifname=`uci -q get network."$WAN".ifname`

			if [ "$wan_ifname" != "$value" ]; then
				uci set network."$WAN".ifname="$value"
				if [ "$value" == "eth2" ]; then
					uci set network."$WAN".proto="dhcp"
				elif [ "$value" == "3g-ppp" ] || [ "$value" == "wwan0" ]; then
					uci set network."$WAN".proto="none"
				fi
			fi
		fi

	elif [ "$item" == "method" ]; then
		local network_method=`uci -q get network.ppp.method`

		if [ "$network_method" != "bridge" ] && [ "$value" == "bridge" ] && [ "$WAN" == "wan" ]; then
			set_bridge
		elif [ "$network_method" == "bridge" ] && [ "$value" != "bridge" ]; then
			disable_bridge
		fi

		if [ "$network_method" != "pbridge" ] && [ "$value" == "pbridge" ] && [ "$WAN" == "wan" ]; then
			set_pbridge
		elif [ "$network_method" == "pbridge" ] && [ "$value" != "pbridge" ]; then
			disable_pbridge
		fi

	elif [ "$item" == "proto" ]; then
		if [ "$value" == "qmi" ]; then
			uci set network.ppp.device="/dev/cdc-wdm0"
		else
			uci set network.ppp.device="/dev/modem_data"
		fi
	fi
	uci set network.ppp."$item"="$value"
done

uci commit network

RESTART_GSMD="TRUE"

if [ -n "$SWITCH_SIM" ]; then
	if [ "$SWITCH_SIM" == "1" ]; then
		$GPIO "$action" SIM
	elif [ "$SWITCH_SIM" == "2" ] || [ "$SWITCH_SIM" == "default" ]; then
		modem_vidpid=$(get_ext_vidpid_tlt)

		if [ "$modem_vidpid" != "" ] && [ "$modem_vidpid" != "-1" ] && [ -n "$action" ]; then
			sim_switch change $CURRENT_SIM 1 1
			RESTART_GSMD=""
		fi
	fi
fi

if [ -n "$RESTART_GSMD" ]; then
	/etc/init.d/gsmd reload
fi
echo "default sim: $CURRENT_SIM"
