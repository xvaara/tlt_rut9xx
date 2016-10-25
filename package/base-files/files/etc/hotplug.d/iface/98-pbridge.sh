WIF=$DEVICE
LIF=br-lan
IFCONFIG=/sbin/ifconfig
ROUTE=/sbin/route
IPTABLES=/usr/sbin/iptables
TMP_DIR=/tmp/tmp_file
TMP_PBRIDGE_IP="$TMP_DIR/pbridge_IP"
FWT="$TMP_DIR/pbridge_firewall.sh"
DNS_TC="$TMP_DIR/dnsmasq_pbridge.conf"
mkdir -p "$TMP_DIR"

get_wan_section() {
	NAME=`uci get network.wan.ifname`
	SECTION="wan"
	if [ "$NAME" == "3g-ppp" ]; then
		#3g-ppp gets its IP individually, it does not reflect in wan IP
		SECTION="ppp"
	elif [ "$NAME" == "wwan0" ]; then
		SECTION="ppp_dhcp"
	fi

	echo "$SECTION"
}

EXTERNAL=

pseudo_bridge()
{
	. /lib/functions/network.sh
	network_flush_cache
	network_get_ipaddr WIP "$INTERFACE"
	network_get_gateway WGW "$INTERFACE"
	network_get_subnet SUBNET "$INTERFACE"
	if [ -z "$WIP" -o -z "$WGW" -o -z "$SUBNET"  ]; then
		return 1
	fi
	OLDWIP=`cat $TMP_PBRIDGE_IP 2>/dev/null`

	echo "$WIP" >"$TMP_PBRIDGE_IP"
		WNM=`ipcalc.sh $SUBNET | grep "NETMASK" | awk -F '=' '{print $2}'`
	#/etc/init.d/dnsmasq stop

	LIP=`uci get network.lan.ipaddr`
	LNM=`uci get network.lan.netmask`

	echo "$IPTABLES -t nat -D zone_wan_postrouting -j MASQUERADE" > "$FWT"
	echo "$IPTABLES -t nat -A zone_wan_postrouting -s $LIP/$LNM -o $WIF -j SNAT --to-source $WIP" >> "$FWT"
	chmod +x "$FWT"

	$IFCONFIG $LIF:0 down
	if [ "$OLDWIP" != "$WIP" ]; then
		ifup lan
	fi
	#	remove WAN IF IP
	
	$IFCONFIG $WIF 0.0.0.0 up
	
	#	replace default route to Gateway through WIF
	$ROUTE add -host $WGW dev $WIF
	$ROUTE add default gw $WGW dev $WIF
	#	add route to WAN IP through LAN iface
	$ROUTE add -host $WIP dev $LIF
	# enable proxy_arp so can use WGW s gateway on LAN device
	echo "1" >/proc/sys/net/ipv4/conf/$WIF/proxy_arp
	echo "1" >/proc/sys/net/ipv4/conf/$LIF/proxy_arp

	#	replace MASQ on WIF with SNAT
	#iptables -F
	#iptables -t nat -F
	#iptables -t raw -F
	#iptables -t mangle -F
	#iptables -P FORWARD ACCEPT
	#$IPTABLES -t nat -D zone_wan_postrouting -j MASQUERADE
	#$IPTABLES -t nat -A zone_wan_postrouting -s $LIP/$LNM -o $WIF -j SNAT --to-source $WIP
	#echo "$IPTABLES -t nat -D zone_wan_postrouting -j MASQUERADE" > "$FWT"
	#echo "$IPTABLES -t nat -A zone_wan_postrouting -s $LIP/$LNM -o $WIF -j SNAT --to-source $WIP" >> "$FWT"
	#chmod +x "$FWT"
	#	add a bit of extra firewall
	#$IPTABLES -t nat -I PREROUTING -i $WIF -d ! $WIP -j DROP
	#	intercept HTTP port
	#logger -t MANO "MANO=======$IPTABLES -t nat -A PREROUTING -i $WIF -p tcp --dport 80 -j DNAT --to $LIP"
	#$IPTABLES -t nat -A PREROUTING -i $WIF -p tcp --dport 80 -j DNAT --to $LIP

	#	setup DHCP server
	#	set WAN GW as secondary LAN IP for DHCP to work
	#$IFCONFIG $LIF:0 $WGW netmask $WNM


	passthrough_dhcp=`uci get -q network.ppp.passthrough_dhcp`
	if [ "$passthrough_dhcp" != "no_dhcp" ]; then # nevykdom kai passthrough dhcp mode yra no DHCP
		new_WGW=`echo $WIP | awk -F '.' '{print $1"."$2"."$3}'`

		if [ "$WGW" != "$new_WGW.1" ] && [ "$WIP" != "$new_WGW.1" ]; then
			new_WGW="$new_WGW.1"
		elif [ "$WGW" != "$new_WGW.2" ] && [ "$WIP" != "$new_WGW.2" ]; then
			new_WGW="$new_WGW.2"
		else
			new_WGW="$new_WGW.3"
		fi
		$IFCONFIG $LIF:0 $new_WGW netmask 255.255.255.0
	fi


	#	setup DHCP config

	#/etc/init.d/dnsmasq stop
	#killall dnsmasq
	#rm /tmp/dhcp.leases
	#cp /var/etc/dnsmasq.conf "$DNS_TC"
	#sed -i "/dhcp-range/d" "$DNS_TC"
	rm -f "$DNS_TC"
	#echo "dhcp-range=lan,$WIP,$WIP,$WNM,12h" >> "$DNS_TC"
	#echo "dhcp-range=lan,192.168.1.160,192.168.1.200,255.255.255.0,12h" >> "$DNS_TC"
	#echo "dhcp-range=lan,$WIP,$WIP,$WNM,12h" >> "$DNS_TC"
	if [ "$passthrough_dhcp" != "no_dhcp" ]; then
		leasetime=`uci get -q network.ppp.leasetime`
		echo "dhcp-range=lan,$WIP,$WIP,255.255.255.0,$leasetime" >> "$DNS_TC"

		DMAC=`uci get -q network.ppp.mac`
		if [ "$DMAC" ]; then
			#echo "dhcp-host=$DMAC,192.168.1.151,24h" >> "$DNS_TC"
			echo "dhcp-host=$DMAC,$WIP,12h" >> "$DNS_TC"
		fi
		/etc/init.d/dnsmasq reload
	fi
	/etc/init.d/firewall reload

	#/usr/sbin/dnsmasq -C "$DNS_TC"
}

if [ "$DEVICE" == "eth2" ] || [ "$DEVICE" == "3g-ppp" ] || [ "$DEVICE" == "wwan0" ]; then
	ppp_method=`uci get -q network.ppp.method`
	ppp_enabled=`uci get -q network.ppp.enabled`
	if [ "$ppp_method" == "pbridge" ] && [ "$ppp_enabled" != "0" ]; then
		if [ "$ACTION" == "ifup" -o "$ACTION" == "ifupdate" ]; then
			#logger -t MANO "Darom"
			pseudo_bridge
		elif [ "$ACTION" == "ifdown" ]; then
			$IFCONFIG $LIF:0 down
			rm -f "$DNS_TC"
		fi
	fi
fi
