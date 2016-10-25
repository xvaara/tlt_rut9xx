#!/bin/sh
# Copyright (C) 2014 Teltonika

. /lib/teltonika-functions.sh

CONFIG_GET="uci -q get auto_update.auto_update"
CONFIG_SET="uci -q set auto_update.auto_update"
CONF_FILE_PATH="/tmp/config.tar.gz"

EXIT_BAD_USAGE=1
EXIT_DISABLED=2
EXIT_BAD_SERIAL=4
EXIT_BAD_URL=5
EXIT_WGET_ERROR=6
EXIT_SERVER_ERROR=7
EXIT_CONFIG_FILE_NOT_FOUND=8
EXIT_BAD_FILE_SIZE_STRING=9
EXIT_BAD_FREE_RAM_STRING=10
EXIT_NOT_ENOUGH_RAM=11
EXIT_BAD_CONFIG=12
EXIT_BAD_MAC=13

PrintUsage() {
	echo "Usage: `basename $0` [mode (check, download)]"
#	echo "init - perform first start init (used by service init script)"
	echo "check - check for new Config"
#	echo "forced_check - ignore 'enable' tag and check for FW update"
	echo "download - download new Config from server if it exists"

	exit $EXIT_BAD_USAGE
}

IsNumber() {
	local string
	local result

	string="$1"
	result=1

	case "$string" in
		''|*[!0-9]*)
			result=0
			;;
	esac

	return $result
}

download_conf() {
	local serial
	local mac
	local username
	local password
	local type
	local server_url
	
	serial=`mnf_info sn`
	
	IsNumber "$serial"
	if [ $? -eq 0 ]; then
		exit $EXIT_BAD_SERIAL
	fi

	mac=`mnf_info mac`
	if [ ${#mac} -ne 12 ]; then
		exit $EXIT_BAD_MAC
	fi
	
	username=$($CONFIG_GET.userName)
	password=$($CONFIG_GET.password)
	type="config"
	
	server_url=$($CONFIG_GET.server_url)

	if [ "$server_url" == "" ]; then
		exit $EXIT_BAD_URL
	fi
	
	query_string="?type=$type&serial=$serial&mac=$mac&action=get_conf_size&username=$username&password=$password&file=cfg"
	temp=$(wget -q -O - -U "RUT9xx ($serial,$mac) Config update service" "$server_url$query_string" 2>&1)
	if [ $? -eq 0 ]; then
		fw_size=$(echo $temp)
		uci -q set auto_update.auto_update.config_size="$fw_size"
		uci commit
		query_string="?type=$type&serial=$serial&mac=$mac&action=get_conf&username=$username&password=$password&file=cfg"
		temp=$(wget -q -O "$CONF_FILE_PATH" -U "RUT9xx ($serial,$mac) Config update service" "$server_url$query_string" 2>&1)
	else
		echo "Cant recieve file size"
	fi
}

checkForUpdate() {
	local serial
	local mac
	local username
	local password
	local type
	local server_url
	
	serial=`mnf_info sn`
	
	IsNumber "$serial"
	if [ $? -eq 0 ]; then
		exit $EXIT_BAD_SERIAL
	fi

	mac=`mnf_info mac`
	if [ ${#mac} -ne 12 ]; then
		exit $EXIT_BAD_MAC
	fi
	
	username=$($CONFIG_GET.userName)
	password=$($CONFIG_GET.password)
	type="config"
	
	server_url=$($CONFIG_GET.server_url)

	if [ "$server_url" == "" ]; then
		exit $EXIT_BAD_URL
	fi
	
	query_string="?type=$type&serial=$serial&mac=$mac&action=check_conf&username=$username&password=$password&"
	temp=$(wget -q -O - -U "RUT9xx ($serial,$mac) Config update service" "$server_url$query_string" 2>&1)
	echo "Config: $temp"
}

case "$1" in 
	download)
		download_conf
		;;
	check)
		checkForUpdate
		;;
	*)
		PrintUsage
		;;
esac
