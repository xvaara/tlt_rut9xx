#!/bin/sh
# Copyright (C) 2015 Teltonika

. /lib/functions.sh
CONFIG="blocklist"
commit=0
ports=""
section=""
name=""
max_blocks=1100
blocks=0
delete=10

add_ports()
{
	port="$1"
	if [ -z "$ports" ]; then
		ports="$port"
	else
		ports="$ports","$port"
	fi
}

clear_blocks()
{
	get_section="$1"
	block_list=`uci get -q blocklist.$get_section.ip`
	counter=0
	for block in $block_list
	do
		uci del_list blocklist."$get_section".ip="$block"
		let counter+=1
		if [ "$counter" -eq "$delete" ]; then
			uci commit blocklist
			break
		fi
	done
}

blocks_count()
{
	uhttpd_blocklist=`uci get -q blocklist.uhttpd.ip`
	dropbear_blocklist=`uci get -q blocklist.dropbear.ip`
	uhttpd_blocklist_count=$(echo "$uhttpd_blocklist" | tr -d -c '.' | wc -c)
	dropbear_blocklist_count=$(echo "$dropbear_blocklist" | tr -d -c '.' | wc -c)
	let blocks=$(((uhttpd_blocklist_count + dropbear_blocklist_count) / 3))
	if [ "$blocks" -ge "$max_blocks" ]; then
		block_section="$1"
		if [ "$block_section" == "uhttpd" ] && [ "$uhttpd_blocklist_count" -gt "$delete" ]; then
			clear_blocks "$block_section"
		elif [ "$block_section" == "dropbear" ] && [ "$dropbear_blocklist_count" -gt "$delete" ]; then
			clear_blocks "$block_section"
		elif [ "$uhttpd_blocklist_count" -ge "$dropbear_blocklist_count" ]; then
			clear_blocks "uhttpd"
		else
			clear_blocks "dropbear"
		fi
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

check_for_dublicates()
{
	section=$1
	
	if [ $(uci get $CONFIG.$section."ip" | grep -c "$LT_ip") -ne 0 ]; then
		logger -s -t "$CONFIG" "IP '$LT_ip' is already in '$section' list"
		exit
	fi
}

if [ ! -z $LT_ip ]; then
	is_ip=`ipcalc.sh $LT_ip | head -1`
	if [ "$is_ip" != "IP=0.0.0.0" ]; then
		if [ $(echo "$LT_name" | grep -ci "ssh") -ne 0 ]; then
			section="dropbear"
			blocks_count "$section"
			name="SSH"
			uci set $CONFIG.$section=$section
			check_for_dublicates "$section"
			uci add_list $CONFIG.$section."ip"="$LT_ip"
			commit=1
		elif [ $(echo "$LT_name" | grep -ci "webui") -ne 0 ]; then
			section="uhttpd"
			blocks_count "$section"
			name="Web UI"
			uci set $CONFIG.$section=$section
			check_for_dublicates "$section"
			uci add_list $CONFIG.$section."ip"="$LT_ip"
			commit=1
		else
			logger -s -t "$CONFIG" "Unknown type '$LT_name'"
		fi

		if [ $commit == 1 ]; then
			uci commit $CONFIG
			config_load $section
			config_foreach $section"_port" $section
			if [ -n "$ports" ]; then
				iptables -I delegate_input -s "$LT_ip" -p tcp -m multiport --dport "$ports" -m comment --comment $CONFIG -j DROP
				text="IP $LT_ip blocked after $LT_count failed attempts"
				/usr/bin/eventslog -i -t EVENTS -n "$name blocked" -e "$text"
				logger -t "$CONFIG" "$name access for $text"
			else
				logger -s -t "$CONFIG" "Can't get ports to block"
			fi
		fi
	fi
fi
