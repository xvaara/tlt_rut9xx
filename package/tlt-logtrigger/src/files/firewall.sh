#!/bin/sh
# Copyright (C) 2015 Teltonika
# Applies blocked IP rules on firewall restart

. /lib/functions.sh
CONFIG="blocklist"
ENABLED=0
ports=""

rule_enabled() {
	local enabled

	config_get enabled $1 "enabled" "0"
	[ "$enabled" == "1" ] && ENABLED=1
}

unblock_ip() {
	ip=$1
	service=$2
	ports=""
	if [ "$service" == "ssh" ]; then
		section="dropbear"
		config_load $section
		config_foreach $section"_port" $section
	elif [ "$service" == "webui" ]; then
		section="uhttpd"
		config_load $section
		eval $section"_port" main
	fi

	iptables -D delegate_input -s "$ip" -p tcp -m multiport --dport "$ports" -m comment --comment $CONFIG -j DROP
}

block_section()
{
	section=$1
	
	list=$(uci -q get $CONFIG.$section."ip")
	for ip in $list; do
		iptables -I delegate_input -s "$ip" -p tcp -m multiport --dport "$ports" -m comment --comment $CONFIG -j DROP
	done
}

add_ports()
{
	port="$1"
	if [ -z "$ports" ]; then
		ports="$port"
	else
		ports="$ports","$port"
	fi	
}

dropbear_port()
{
	port=$(config_get $1 "Port" | sed -r 's/[ ]+/,/g')
	add_ports "$port"
}

uhttpd_port()
{
	data=$(config_get $1 "listen_http")
	for item in $data; do
		port=$(echo "$item" | awk -F ":" '{print $2}')
		add_ports "$port"
	done
	data=$(config_get $1 "listen_https")
	for item in $data; do
		port=$(echo "$item" | awk -F ":" '{print $2}')
		add_ports "$port"
	done
}

block() {
	config_load "logtrigger"
	config_foreach rule_enabled "rule"
	[ $ENABLED -eq 1 ] || exit

	ports=""
	section="dropbear"
	config_load $section
	config_foreach $section"_port" $section
	block_section $section

	ports=""
	section="uhttpd"
	config_load $section
	eval $section"_port" main
	block_section $section
}

case "$1" in
		-h|--help)
			echo "	Usage:"
			echo "						block adresses"
			echo "		-u|--unblock [ip] [ssh/webui]	unblock adresses"
			;;
		-u|--unblock)
			unblock_ip $2 $3
			;;
		*)
			block
			;;
esac

