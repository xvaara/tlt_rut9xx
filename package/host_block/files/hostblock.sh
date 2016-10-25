#!/bin/sh
# Copyright (C) 2014 Teltonika

. /lib/functions.sh
. /lib/teltonika-functions.sh

FUNC_NAME="hostblock"
HOST_FILE="/etc/hosts"
HOST_FILE_ORIG="/rom/$HOST_FILE"
HOST_FILE_CURRENT="/tmp/$FUNC_NAME.current"
FIREWALL_FILE="/tmp/$FUNC_NAME.firewall"
BAD_IP="1.1.1.1"
SERVICE_DAEMONIZE=1

restore_orig_host_file() {
	cp -f "$HOST_FILE" "$HOST_FILE_CURRENT"
	cp -f "$HOST_FILE_ORIG" "$HOST_FILE"
}

restore_curr_host_file() {
	cp -f "$HOST_FILE_CURRENT" "$HOST_FILE"
}

clear_host() {
	local host

	config_get "host" "$1" host
	if [ -n "$host" ]; then
		sed -i "/$host/d" "$HOST_FILE"
	fi
}

block_host() {
	local host

	config_get "host" "$1" host
	if [ -n "$host" ]; then
		echo "$BAD_IP $host" >> "$HOST_FILE"
	else
		logger -t "$FUNC_NAME" "No host specified"
	fi
}

block_host_ip() {
	local host
	local enabled
	local ip
	local count
	local coova
	coova=$(ifconfig | grep tun | awk '{print $1}')
	config_get "host" "$1" host
	config_get "enabled" "$1" enabled
	if [ -n "$host" ] && [ "$enabled" = "1" ]; then
		count=0
		for ip in $(resolveip -4 "$host"); do
                if [ -z "$coova" ] || [ "$coova" = "tun_rms" ]; then
                    iptables -I zone_lan_forward -d "$ip" -p tcp -m comment --comment "$FUNC_NAME" -j DROP
                    iptables -I zone_lan_forward -d "$ip" -p udp -m comment --comment "$FUNC_NAME" -j DROP
                    #Save rules for deletion
                    echo "iptables -D zone_lan_forward -d \"$ip\" -p tcp -m comment --comment \"$FUNC_NAME\" -j DROP" >> $FIREWALL_FILE
                    echo "iptables -D zone_lan_forward -d \"$ip\" -p udp -m comment --comment \"$FUNC_NAME\" -j DROP" >> $FIREWALL_FILE
                else
                    iptables -I FORWARD -d "$ip" -i tun+ -p tcp -m comment --comment "$FUNC_NAME" -j DROP
                    iptables -I FORWARD -d "$ip" -i tun+ -p udp -m comment --comment "$FUNC_NAME" -j DROP
                    #Save rules for deletion
                    echo "iptables -I FORWARD -d "$ip" -i tun+ -p tcp -m comment --comment "$FUNC_NAME" -j DROP" >> $FIREWALL_FILE
                    echo "iptables -I FORWARD -d "$ip" -i tun+ -p udp -m comment --comment "$FUNC_NAME" -j DROP" >> $FIREWALL_FILE
                fi	
			count=`expr $count + 1`
		done
		if [ -n "$count" ]; then
			logger -t "$FUNC_NAME" "'$count' IPs block for host '$host'"
		fi
	fi
}

allow_host_ip() {
	local host
	local enabled
	local ip
	local count
	local coova
	coova=$(ifconfig | grep tun | awk '{print $1}')
	config_get "host" "$1" host
	config_get "enabled" "$1" enabled
	if [ -n "$host" ] && [ "$enabled" == "1" ]; then
		count=0

		for ip in $(resolveip -4 "$host"); do
              if [ -z "$coova" ] || [ "$coova" = "tun_rms" ]; then
                iptables -I zone_lan_forward -d "$ip" -p tcp -m comment --comment "$FUNC_NAME" -j ACCEPT
                iptables -I zone_lan_forward -d "$ip" -p udp -m comment --comment "$FUNC_NAME" -j ACCEPT
                #Save rules for deletion
                echo "iptables -D zone_lan_forward -d \"$ip\" -p tcp -m comment --comment \"$FUNC_NAME\" -j ACCEPT" >> $FIREWALL_FILE
                echo "iptables -D zone_lan_forward -d \"$ip\" -p udp -m comment --comment \"$FUNC_NAME\" -j ACCEPT" >> $FIREWALL_FILE
              else
                iptables -I FORWARD -d "$ip" -i tun+ -p tcp -m comment --comment "$FUNC_NAME" -j ACCEPT
                iptables -I FORWARD -d "$ip" -i tun+ -p udp -m comment --comment "$FUNC_NAME" -j ACCEPT
                #Save rules for deletion
                echo "iptables -I FORWARD -d "$ip" -i tun+ -p tcp -m comment --comment "$FUNC_NAME" -j ACCEPT" >> $FIREWALL_FILE
                echo "iptables -I FORWARD -d "$ip" -i tun+ -p udp -m comment --comment "$FUNC_NAME" -j ACCEPT" >> $FIREWALL_FILE
              fi
                count=`expr $count + 1`
		done

		if [ -n "$count" ]; then
			logger -t "$FUNC_NAME" "'$count' IPs allow for host '$host'"
		fi
	fi
}

restore_firewall() {
	local rule

	if ! [ -f "$FIREWALL_FILE" ]; then
		return 1
	fi

	sh "$FIREWALL_FILE" 2>/dev/null
	rm -rf "$FIREWALL_FILE"
	/etc/init.d/firewall restart
	
}

setup_crontab() {
	sed -i "/$FUNC_NAME/d" /etc/crontabs/root
	echo "01 00 * * 1 /etc/init.d/$FUNC_NAME restart" >> /etc/crontabs/root
	/etc/init.d/cron start
}

delete_crontab() {
	sed -i "/$FUNC_NAME/d" /etc/crontabs/root
}

wait_for_internet() {
	local result
	result=$(ping -W 1 -c 1 "$1" 2>&1 | grep -oc "round-trip")
	if [ "$result" != "1" ]; then
		logger -t "$FUNC_NAME" "No internet connection to resolve hosts"
		while :
		do
			result=$(ping -W 1 -c 1 "$1" 2>&1 | grep -oc "round-trip")
			if [ "$result" = "1" ]; then
				break
			else
				sleep 10
			fi

		done
	fi
}

start() {
	local enabled
	local mode
	local ICMP_HOST

	config_load "$FUNC_NAME"
	config_get mode "config" "mode"
	config_get_bool	enabled "config" "enabled" "0"

	if [ $enabled -ne 1 ]; then
		exit 1
	fi



	rm -rf "$FIREWALL_FILE"
	config_get BAD_IP "config" "redirect_to" "1.1.1.1"

	config_foreach clear_host 'block'
	config_foreach block_host 'block'

	#block IPs only after WAN is connected
	tlt_wait_for_wan hostblock > /dev/null
	restore_orig_host_file

	config_get ICMP_HOST "config" "icmp_host" "8.8.8.8"
	wait_for_internet $ICMP_HOST

	if [ "$mode" == "blacklist" ]; then
		config_foreach block_host_ip 'block'
		restore_curr_host_file
	else
        local coova
        coova=$(ifconfig | grep tun | awk '{print $1}')
        if [ -z "$coova" ] || [ "$coova" = "tun_rms" ]; then
           		iptables -I zone_lan_forward -p tcp -m tcp --dport 80 -m comment --comment "$FUNC_NAME" -j DROP
                iptables -I zone_lan_forward -p udp -m udp --dport 80 -m comment --comment "$FUNC_NAME" -j DROP
                iptables -I zone_lan_forward -p tcp -m tcp --dport 443 -m comment --comment "$FUNC_NAME" -j DROP
                iptables -I zone_lan_forward -p udp -m udp --dport 443 -m comment --comment "$FUNC_NAME" -j DROP
                echo "iptables -D zone_lan_forward -p tcp -m tcp --dport 80 -m comment --comment \"$FUNC_NAME\" -j DROP" >> $FIREWALL_FILE
                echo "iptables -D zone_lan_forward -p udp -m udp --dport 80 -m comment --comment \"$FUNC_NAME\" -j DROP" >> $FIREWALL_FILE
                echo "iptables -D zone_lan_forward -p tcp -m tcp --dport 443 -m comment --comment \"$FUNC_NAME\" -j DROP" >> $FIREWALL_FILE
                echo "iptables -D zone_lan_forward -p udp -m udp --dport 443 -m comment --comment \"$FUNC_NAME\" -j DROP" >> $FIREWALL_FILE 
        else
                iptables -I FORWARD -p tcp -m tcp --dport 80 -m comment --comment "$FUNC_NAME" -j DROP
                iptables -I FORWARD -p udp -m udp --dport 80 -m comment --comment "$FUNC_NAME" -j DROP
                iptables -I FORWARD -p tcp -m tcp --dport 443 -m comment --comment "$FUNC_NAME" -j DROP
                iptables -I FORWARD -p udp -m udp --dport 443 -m comment --comment "$FUNC_NAME" -j DROP
                echo "iptables -D FORWARD -p tcp -m tcp --dport 80 -m comment --comment \"$FUNC_NAME\" -j DROP" >> $FIREWALL_FILE
                echo "iptables -D FORWARD -p udp -m udp --dport 80 -m comment --comment \"$FUNC_NAME\" -j DROP" >> $FIREWALL_FILE
                echo "iptables -D FORWARD -p tcp -m tcp --dport 443 -m comment --comment \"$FUNC_NAME\" -j DROP" >> $FIREWALL_FILE
                echo "iptables -D FORWARD -p udp -m udp --dport 443 -m comment --comment \"$FUNC_NAME\" -j DROP" >> $FIREWALL_FILE 
        fi
        
# 		iptables -I FORWARD -p tcp --dport 80 -m comment --comment "$FUNC_NAME" -j DROP
# 		iptables -I FORWARD -p tcp --dport 443 -m comment --comment "$FUNC_NAME" -j DROP
# 		iptables -I FORWARD -p udp --dport 80 -m comment --comment "$FUNC_NAME" -j DROP
# 		iptables -I FORWARD -p udp --dport 443 -m comment --comment "$FUNC_NAME" -j DROP
# 		echo "iptables -D FORWARD -p tcp --dport 80 -m comment --comment \"$FUNC_NAME\" -j DROP" >> $FIREWALL_FILE
# 		echo "iptables -D FORWARD -p tcp --dport 443 -m comment --comment \"$FUNC_NAME\" -j DROP" >> $FIREWALL_FILE
# 		echo "iptables -D FORWARD -p udp --dport 80 -m comment --comment \"$FUNC_NAME\" -j DROP" >> $FIREWALL_FILE
# 		echo "iptables -D FORWARD -p udp --dport 443 -m comment --comment \"$FUNC_NAME\" -j DROP" >> $FIREWALL_FILE
		config_foreach allow_host_ip 'block'

	fi

	setup_crontab
}

stop() {
	delete_crontab
	restore_orig_host_file
	restore_firewall
	rm -rf "$HOST_FILE_CURRENT"
}

restart() {
	stop
	start
}

$1

