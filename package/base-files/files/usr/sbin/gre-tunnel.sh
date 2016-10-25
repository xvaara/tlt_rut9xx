#!/bin/sh

. /lib/teltonika-functions.sh

local ENABLED="$1"
if [ "$ENABLED" = "1" ]; then
	# Wait for WAN interface to get an IP address.
	local wan_ip=`tlt_wait_for_wan gre-tunnel`
	local ifname="$2"
	local remote_ip="$3"
	local remote_network="$4"
	local remote_netmask="$5"
	local tunnel_ip="$6"
	local tunnel_netmask="$7"
	local tunnel_network=`ipcalc.sh $tunnel_ip $tunnel_netmask | grep NETWORK | cut -d= -f2`

	local ttl="$8"
	local pmtud="$9"
	local mtu="$10"

	local keepalive="$11"
	local keepalive_host="$12"
	local keepalive_interval="$13"
	echo "$ifname $remote_ip $wan_ip $tunnel_ip"
	if [ -n "$ifname" -a -n "$remote_ip" -a -n "$wan_ip" -a -n "$tunnel_ip" ]; then
		error=0
		logger "[GRE-TUN] ${ifname} Setuping new tunnel..."
		if [ "$pmtud" = "1" ]; then
			ip tunnel add "$ifname" mode gre remote "$remote_ip" local "$wan_ip" nopmtudisc
		else
			ip tunnel add "$ifname" mode gre remote "$remote_ip" local "$wan_ip" ttl "$ttl"
		fi
		error=`expr $error + $?`
		ifconfig "$ifname" up
		error=`expr $error + $?`
		ifconfig "$ifname" "$tunnel_ip"
		error=`expr $error + $?`
		ifconfig "$ifname" pointopoint 0.0.0.0
		error=`expr $error + $?`

		if [ "$mtu" -ne 0 ]; then
			ip link set "$ifname" mtu "$mtu"
		fi

		ip route add "$remote_network"/"$remote_netmask" dev "$ifname"
		error=`expr $error + $?`
		ip route add "$tunnel_network"/"$tunnel_netmask" dev "$ifname"
		error=`expr $error + $?`
		if [ "$error" -eq 0 ]; then
			logger -t "GRE-TUN" "${ifname} Started successful."
			/sbin/chroutes
			sleep 5
			ping "$remote_network" -c 3
			sleep 1
			if [ "$keepalive" = "1" -a -n "$keepalive_host" -a -n "$keepalive_interval" ]; then
				gre-tunnel-keepalive.sh "$keepalive_host" "$keepalive_interval" "$ifname"  & 2>&1 1>/dev/null
			fi
		else
			logger -t "GRE-TUN" "${ifname} Error on setuping new tunnel."
		fi
	else
		logger -t "GRE-TUN" "${ifname} error: Tunnel not created (Remote_ip=${remote_ip}, WAN_ip=${wan_ip}, Tunnel_ip=${tunnel_ip})"
	fi
fi
