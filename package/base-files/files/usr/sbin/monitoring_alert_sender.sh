#!/bin/sh

echo "starting\n" > /tmp/AAASDFA

veiksmas="$1"
eventas="$2"
eventmark="$3"

device_id=`uci -q get hwinfo.hwinfo.serial`
device_mac=`ifconfig | grep 'br-lan' | awk -F ' ' '{print $5}'`
netmask="255.255.224.0"
router_ip=`gsmctl -p tun_rms`
server_ip=`/bin/ipcalc.sh $router_ip $netmask | grep NETWORK | cut -f2 -d= | cut -f1,2,3 -d.`
server_ip_full="$server_ip.1"
id=""

if [ "$eventas" == "Signal strength" ]
then
	echo "IF type signal strength\n" >> /tmp/AAASDFA
	if [ "$veiksmas" == "sendSMS" ]
	then
		echo "IF sendSMS\n" >> /tmp/AAASDFA
		id="${id}1:"
	else
		echo "IF sendEMAIL\n" >> /tmp/AAASDFA
		id="${id}2:"
	fi
elif [ "$eventas" == "SIM switch" ]
then
	echo "IF type SIM switch\n" >> /tmp/AAASDFA
	if [ "$veiksmas" == "sendSMS" ]
	then
		echo "IF sendSMS\n" >> /tmp/AAASDFA
		id="${id}3:"
	else
		echo "IF sendEMAIL\n" >> /tmp/AAASDFA
		id="${id}4:"
	fi
elif [ "$eventas" == "Mobile data" ]
then
	echo "IF type Mobile data\n" >> /tmp/AAASDFA
	echo "IF sendSMS\n" >> /tmp/AAASDFA
	id="${id}5:"
else
	echo "Monitoring alert not found\n" >> /tmp/AAASDFA
	exit 1
fi



case $eventmark in
	"Signal strength droped below -113 dBm") id="${id}0" ;;
	"Signal strength droped below -98 dBm") id="${id}1" ;;
	"Signal strength droped below -93 dBm") id="${id}2" ;;
	"Signal strength droped below -75 dBm") id="${id}3" ;;
	"Signal strength droped below -60 dBm") id="${id}4" ;;
	"Signal strength droped below -50 dBm") id="${id}5" ;;
	
	"SIM 1 to SIM 2") id="${id}6" ;;
	"SIM 2 to SIM 1") id="${id}7" ;;
	
	"SIM1") id="${id}8" ;;
	"SIM2") id="${id}9" ;;
	
	*) echo "ERROR in switch statement" >> /tmp/AAASDFA
esac



echo "id =$id" >> /tmp/AAASDFA

echo "arg1 =|$1|" >> /tmp/AAASDFA
echo "arg2 =|$2|" >> /tmp/AAASDFA
echo "arg3 =|$3|" >> /tmp/AAASDFA
#echo "id = $device_id\n" >> /tmp/AAASDFA
#echo "mac = $device_mac\n" >> /tmp/AAASDFA

komanda="curl -d '{\"v\": \"1\", \"dev\": [\"$device_id\",\"$device_mac\"], \"par\":{\"meth\": \"trap_v1\",\"id\":\"$id\",\"actions\":\"$veiksmas\",\"events\":\"$eventas\",\"event_marks\":\"$eventmark\"}}' http://$server_ip_full/alert_from_device/web.cgi;"
#echo "komanda=$komanda" >> /tmp/AAASDFA1

returnvalue=`eval $komanda`

#echo "returnvalue = $returnvalue\n" >> /tmp/AAASDFA
#echo "netmask = $netmask\n" >> /tmp/AAASDFA
#echo "router_ip = $router_ip\n" >> /tmp/AAASDFA
#echo "server_ip = $server_ip\n" >> /tmp/AAASDFA
#echo "server_ip_full = $server_ip_full\n" >> /tmp/AAASDFA

