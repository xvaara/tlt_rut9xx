#!/bin/sh
# (C) 2014 Teltonika

. /lib/teltonika-gpio-functions.sh
ACTION=$1
NAME=$2
gpio=""

# logger -s "action == $1 || name == $2"

GPIO_LIST="SIM	DOUT1	DOUT2	DIN1	DIN2	MON	MRST	SDCS	RS485_R"
GPIO_PINS="55	56	57	59	58	60	61	62	63"

usage () {
	echo "GPIO control aplication"
	echo -e "\tUsage: $0 <ACTION> <NAME>"
	echo -e "\tACTION - set, clear, get, export, invert, dirout, dirin"
	echo -e "\tNAME - $GPIO_LIST"
}

validate() {
	id=1
	for i in $GPIO_LIST; do
		if [ "$1" = "$i" ]; then
			pin=`echo $GPIO_PINS | awk -F " " -v x=$id '{print $x}'`
			gpio=$pin
			return
		fi
		id=`expr $id + 1`
	done
	echo "$0: GPIO $1 not supported"
	exit 1
}

do_led() {
	local name
	local sysfs
	config_get name $1 name
	config_get sysfs $1 sysfs
	[ "$name" == "$NAME" -o "$sysfs" = "$NAME" -a -e "/sys/class/leds/${sysfs}" ] && {
		[ "$ACTION" == "set" ] &&
			echo 1 >/sys/class/leds/${sysfs}/brightness \
			|| echo 0 >/sys/class/leds/${sysfs}/brightness
		exit 0
	}
}

func_set() {
	if [ "$NAME" == "DOUT1" ] || [ "$NAME" == "DOUT2" ]; then
		ouput_active_state=`uci get ioman.@ioman[0].active_"$NAME"_status`
		if [ "$ouput_active_state" == "1" ]; then
			gpio_write_tlt $1 1
		else
			gpio_write_tlt $1 0
		fi
	else
		gpio_write_tlt $1 1
	fi
}

func_clear() {
	if [ "$NAME" == "DOUT1" ] || [ "$NAME" == "DOUT2" ]; then
		ouput_active_state=`uci get ioman.@ioman[0].active_"$NAME"_status`
		if [ "$ouput_active_state" == "1" ]; then
			gpio_write_tlt $1 0
		else
			gpio_write_tlt $1 1
		fi
	else
		gpio_write_tlt $1 0
	fi
}

func_get() {
	value=`gpio_read_tlt $1`
	if [ "$value" == "-1" ]; then
		echo "1"
	else
		echo $value
	fi
}

func_export() {
	gpio_export_tlt $1
}

func_invert() {
	gpio_invert_tlt $1
}

func_dirin() {
	gpio_setdir_tlt $1 in
}

func_dirout() {
	gpio_setdir_tlt $1 out
}

if [ "$#" != 2 ] || [ "$ACTION" != "set" -a "$ACTION" != "clear" -a "$ACTION" != "get" \
	 -a "$ACTION" != "export" -a "$ACTION" != "invert" -a "$ACTION" != "dirin" -a "$ACTION" != "dirout" ]; then
	usage
	exit 1
fi

validate $NAME
func_$ACTION $gpio
if [ "$NAME" == "DOUT1" ]; then
	if [ "$ACTION" == "set" ]; then
		/usr/bin/eventslog -i -t EVENTS -n "Output" -e "Digital OC output on"
	elif [ "$ACTION" == "clear" ]; then
		/usr/bin/eventslog -i -t EVENTS -n "Output" -e "Digital OC output off"
	elif [ "$ACTION" == "invert" ]; then
		/usr/bin/eventslog -i -t EVENTS -n "Output" -e "Digital OC output was inverted"
	fi
elif [ "$NAME" == "DOUT2" ]; then
	if [ "$ACTION" == "set" ]; then
		/usr/bin/eventslog -i -t EVENTS -n "Output" -e "Digital relay output on"
	elif [ "$ACTION" == "clear" ]; then
		/usr/bin/eventslog -i -t EVENTS -n "Output" -e "Digital relay output off"
	elif [ "$ACTION" == "invert" ]; then
		/usr/bin/eventslog -i -t EVENTS -n "Output" -e "Digital relay output was inverted"
	fi
fi

