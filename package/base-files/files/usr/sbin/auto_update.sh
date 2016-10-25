#!/bin/sh
# Copyright (C) 2014 Teltonika

. /lib/teltonika-functions.sh

CONFIG_GET="uci -q get auto_update.auto_update"
CONFIG_SET="uci -q set auto_update.auto_update"
CRONTAB_FILE="/etc/crontabs/root"
PRE_SCRIPT_PATH="/tmp/pre_update_script.sh"
POST_SCRIPT_PATH="/tmp/post_update_script.sh"
FW_FILE_PATH="/tmp/firmware.img"
FREE_SPACE_LIMIT=1024000

EXIT_BAD_USAGE=1
EXIT_DISABLED=2
EXIT_MOBILE_DATA=3
EXIT_BAD_SERIAL=4
EXIT_BAD_URL=5
EXIT_WGET_ERROR=6
EXIT_BAD_KEEP_SETTINGS_STRING=7
EXIT_SERVER_ERROR=8
EXIT_FW_FILE_NOT_FOUND=9
EXIT_BAD_FILE_SIZE_STRING=10
EXIT_BAD_FREE_RAM_STRING=11
EXIT_NOT_ENOUGH_RAM=12
EXIT_BAD_CONFIG=13
EXIT_BAD_MAC=14

PrintUsage() {
	echo "Usage: `basename $0` [mode (init, check, forced_check, get), <keep settings string>]"
	echo "init - perform first start init (used by service init script)"
	echo "check - check for FW update"
	echo "forced_check - ignore 'enable' tag and check for FW update"
	echo "get - download new FW from server if it exists"
	echo "<keep settings string> - used only in 'get' mode"

	exit $EXIT_BAD_USAGE
}

if [ $# -gt 0 ] && [ $# -lt 3 ]; then
	if [ $# -eq 1 ] && [ "$1" == "get" ]; then
		PrintUsage
	fi
	if [ $# -eq 2 ] && [ "$1" != "get" ]; then
		PrintUsage
	fi
else
	PrintUsage
fi

local keep_settings

keep_settings="$2"

SubStringPos () {
	local string
	local substring
	local index
	local tmp

	string="$1"
	substring="$2"
	index="99999999999"

	case "$string" in
		*$substring*)
			tmp=${string%%$substring*}
			index=${#tmp}
			;;
	esac

	return "$index"
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

CheckEnabledFlag() {
	local enabled
	local found

	enabled=$($CONFIG_GET.enable)

	if [ "$enabled" -ne 1 ]; then
		found=$(grep -q "/usr/sbin/auto_update.sh" "$CRONTAB_FILE"; echo $?)
		if [ "$found" -eq 0 ]; then
			sed -i "\/usr\/sbin\/auto_update.sh/d" "$CRONTAB_FILE"
			found=$(ps | grep -q "[*c]rond"; echo $?)
			if [ "$found" -eq 0 ]; then
				/etc/init.d/cron restart&
			fi
		fi

		exit $EXIT_DISABLED
	fi
}

Init() {
	local found
	local mode
	local hours
	local minutes
	local days
	local temp

	mode=$($CONFIG_GET.mode)

	if [ "$mode" == "on_start" ]; then
		if [ -f "$CRONTAB_FILE" ]; then
			sed -i "\/usr\/sbin\/auto_update.sh/d" "$CRONTAB_FILE"
		fi

		found=$(ps | grep -q "[*c]rond"; echo $?)
		if [ "$found" -eq 0 ]; then
			/etc/init.d/cron restart&
		fi

		tlt_wait_for_wan auto-update > /dev/null
		CheckForUpdate
	elif [ "$mode" == "periodic" ]; then
		if [ -f "$CRONTAB_FILE" ]; then
			sed -i "\/usr\/sbin\/auto_update.sh/d" "$CRONTAB_FILE"
		fi

		hours=$($CONFIG_GET.hours)
		minutes=$($CONFIG_GET.minutes)
		days=$($CONFIG_GET.day)
		temp=${days// /""}

		if [ "$hours" != "" ] && [ "$minutes" != "" ] && [ "$temp" != "" ]; then
			IsNumber "$hours"
			if [ $? -eq 0 ]; then
				exit $EXIT_BAD_CONFIG
			fi

			IsNumber "$minutes"
			if [ $? -eq 0 ]; then
				exit $EXIT_BAD_CONFIG
			fi

			IsNumber "$temp"
			if [ $? -eq 0 ]; then
				exit $EXIT_BAD_CONFIG
			fi
		else
			exit $EXIT_BAD_CONFIG
		fi

		days=${days// /,}
		echo "$minutes $hours * * $days /usr/sbin/auto_update.sh check" >> "$CRONTAB_FILE"
		found=$(ps | grep -q "[*c]rond"; echo $?)
		if [ "$found" -eq 0 ]; then
			/etc/init.d/cron restart&
		fi
	else
		exit $EXIT_BAD_CONFIG
	fi
}

CheckForUpdate() {
	local forced_check
	local not_mobile
	local wan_ifname
	local server_url
	local username
	local password
	local serial
	local mac
	local temp
	local auth_string
	local query_string
	local fw_version
	local fw_version_string

	forced_check="$1"

	if [ "$forced_check" != "forced" ]; then
		not_mobile=$($CONFIG_GET.not_mobile)

		if [ "$not_mobile" -eq 1 ]; then
			wan_ifname=$(uci -q get network.wan.ifname)

			temp=0
			for name in `echo "$wan_ifname"`; do
				case "$name" in
					3g-ppp)
						temp=1
						;;
					eth2)
						temp=1
						;;
				esac
			done

			if [ "$temp" -eq 1 ]; then
				exit $EXIT_MOBILE_DATA
			fi
		fi
	fi

	serial=$(dd if=/dev/mtdblock1 of=/tmp/serial bs=1 skip=48 count=8 > /dev/null 2>&1; cat /tmp/serial; rm /tmp/serial)
	IsNumber "$serial"
	if [ $? -eq 0 ]; then
		exit $EXIT_BAD_SERIAL
	fi
	
	mac=`mnf_info mac`
	if [ ${#mac} -ne 12 ]; then
		exit $EXIT_BAD_MAC
	fi

	server_url=$($CONFIG_GET.server_url)
	if [ "$server_url" == "" ]; then
		exit $EXIT_BAD_URL
	fi

	SubStringPos "$server_url" "https://"
	if [ "$?" != "0" ]; then
		SubStringPos "$server_url" "http://"
		if [ "$?" != "0" ]; then
			server_url="http://$server_url"
		fi
	fi

	fw_version=""
	if [ -f "/etc/version" ]; then
		fw_version=$(cat /etc/version)
	fi

	if [ "$fw_version" != "" ]; then
		fw_version_string="&fw_version=$fw_version"
	fi

	username=$($CONFIG_GET.userName)
	password=$($CONFIG_GET.password)

	auth_string=""
	if [ "$username" != "" ] && [ "$password" != "" ]; then
		auth_string="&username=$username&password=$password"
	fi

	query_string="?type=firmware&serial=$serial&mac=$mac&action=check$fw_version_string$auth_string"
	temp=$(wget -q -O - -U "RUT9xx ($serial,$mac) FW update service" "$server_url$query_string" 2>&1)

	if [ $? -eq 0 ]; then
		SubStringPos "$temp" "error:"
		if [ "$?" != "0" ]; then
			if [ "$temp" != "" ] && [ "$fw_version" != "$temp" ]; then
				$CONFIG_SET.fw_version="$temp"
				uci commit auto_update
				echo "new_fw_version=$temp"
			else
				echo "no_new_update"
			fi
		else
			temp=${temp#error:}
			echo "server_error=$temp"

			exit $EXIT_SERVER_ERROR
		fi
	else
		echo "wget_error=$temp"

		exit $EXIT_WGET_ERROR
	fi
}

GetUpdate() {
	local not_mobile
	local wan_ifname
	local server_url
	local username
	local password
	local serial
	local mac
	local temp
	local auth_string
	local query_string
	local fw_version
	local fw_version_string
	local keep_settings
	local pre_cmd_size
	local fw_size
	local post_cmd_size
	local size

	keep_settings="$1"

	rm "$PRE_SCRIPT_PATH" > /dev/null 2>&1
	rm "$POST_SCRIPT_PATH" > /dev/null 2>&1
	rm "$FW_FILE_PATH" > /dev/null 2>&1
	$CONFIG_SET.pre_fw_post=""
	uci commit auto_update

	IsNumber "$keep_settings"
	if [ $? -eq 0 ]; then
		exit $EXIT_BAD_KEEP_SETTINGS_STRING
	fi

	not_mobile=$($CONFIG_GET.not_mobile)

	if [ "$not_mobile" -eq 1 ]; then
		wan_ifname=$(uci -q get network.wan.ifname)

		temp=0
		case "$wan_ifname" in
			*3g-ppp*)
				temp=1
				;;
			*eth2*)
				temp=1
				;;
		esac

		if [ "$temp" -eq 1 ]; then
			exit $EXIT_MOBILE_DATA
		fi
	fi

	serial=$(dd if=/dev/mtdblock1 of=/tmp/serial bs=1 skip=48 count=8 > /dev/null 2>&1; cat /tmp/serial; rm /tmp/serial)
	IsNumber "$serial"
	if [ $? -eq 0 ]; then
		exit $EXIT_BAD_SERIAL
	fi
	
	mac=`mnf_info mac`

	server_url=$($CONFIG_GET.server_url)
	if [ "$server_url" == "" ]; then
		exit $EXIT_BAD_URL
	fi

	SubStringPos "$server_url" "https://"
	if [ "$?" != "0" ]; then
		SubStringPos "$server_url" "http://"
		if [ "$?" != "0" ]; then
			server_url="http://$server_url"
		fi
	fi

	fw_version=""
	if [ -f "/etc/version" ]; then
		fw_version=$(cat /etc/version)
	fi

	if [ "$fw_version" != "" ]; then
		fw_version_string="&fw_version=$fw_version"
	fi

	username=$($CONFIG_GET.userName)
	password=$($CONFIG_GET.password)

	auth_string=""
	if [ "$username" != "" ] && [ "$password" != "" ]; then
		auth_string="&username=$username&password=$password"
	fi

	query_string="?type=firmware&serial=$serial&mac=$mac&action=get_url&keep_settings=$keep_settings$fw_version_string$auth_string"
	temp=$(wget -q -O - -U "RUT9xx ($serial,$mac) FW update service" "$server_url$query_string" 2>&1)

	pre_cmd_size=0
	fw_size=0
	post_cmd_size=0
	if [ $? -eq 0 ]; then
		SubStringPos "$temp" "error:"
		if [ "$?" != "0" ]; then
			pre_cmd_size=$(echo $temp | cut -f 1 -d \|)
			fw_size=$(echo $temp | cut -f 2 -d \|)
			post_cmd_size=$(echo $temp | cut -f 3 -d \|)

			IsNumber "$pre_cmd_size"
			if [ $? -eq 0 ]; then
				exit $EXIT_BAD_FILE_SIZE_STRING
			fi

			IsNumber "$fw_size"
			if [ $? -eq 0 ]; then
				exit $EXIT_BAD_FILE_SIZE_STRING
			fi

			IsNumber "$post_cmd_size"
			if [ $? -eq 0 ]; then
				exit $EXIT_BAD_FILE_SIZE_STRING
			fi
		else
			temp=${temp#error:}
			echo "server_error=$temp"

			exit $EXIT_SERVER_ERROR
		fi
	else
		echo "wget_error=$temp"

		exit $EXIT_WGET_ERROR
	fi

	if [ "$fw_size" == "0" ]; then
		exit $EXIT_FW_FILE_NOT_FOUND
	fi

	temp=$(df -k /tmp | awk '/[0-9]%/{print $(NF-2)}')
	IsNumber "$temp"
	if [ $? -eq 0 ]; then
		exit $EXIT_BAD_FREE_RAM_STRING
	fi

	temp=$((temp * 1024))
	size=$((pre_cmd_size + fw_size + post_cmd_size))
	temp=$((temp - size))
	if [ "$temp" -lt $FREE_SPACE_LIMIT ]; then
		exit $EXIT_NOT_ENOUGH_RAM
	fi

	if [ "$pre_cmd_size" != "0" ]; then
		query_string="?type=firmware&serial=$serial&mac=$mac&action=get_file&file=pre_cmd&keep_settings=$keep_settings$fw_version_string$auth_string"
		temp=$(wget -q -O "$PRE_SCRIPT_PATH" -U "RUT9xx ($serial,$mac) FW update service" "$server_url$query_string" 2>&1)

		if [ $? -eq 0 ]; then
			SubStringPos "$temp" "error:"
			if [ "$?" == "0" ]; then
				rm "$PRE_SCRIPT_PATH" > /dev/null 2>&1
				temp=${temp#error:}
				echo "server_error=$temp"

				exit $EXIT_SERVER_ERROR
			fi
		else
			rm "$PRE_SCRIPT_PATH" > /dev/null 2>&1
			echo "wget_error=$temp"

			exit $EXIT_WGET_ERROR
		fi
	fi

	if [ "$post_cmd_size" != "0" ]; then
		query_string="?type=firmware&serial=$serial&mac=$mac&action=get_file&file=post_cmd&keep_settings=$keep_settings$fw_version_string$auth_string"
		temp=$(wget -q -O "$POST_SCRIPT_PATH" -U "RUT9xx ($serial,$mac) FW update service" "$server_url$query_string" 2>&1)

		if [ $? -eq 0 ]; then
			SubStringPos "$temp" "error:"
			if [ "$?" == "0" ]; then
				rm "$POST_SCRIPT_PATH" > /dev/null 2>&1
				temp=${temp#error:}
				echo "server_error=$temp"

				exit $EXIT_SERVER_ERROR
			fi
		else
			rm "$POST_SCRIPT_PATH" > /dev/null 2>&1
			echo "wget_error=$temp"

			exit $EXIT_WGET_ERROR
		fi
	fi

	$CONFIG_SET.file_size="$fw_size"
	uci commit auto_update
	query_string="?type=firmware&serial=$serial&mac=$mac&action=get_file&file=fw&keep_settings=$keep_settings$fw_version_string$auth_string"
	temp=$(wget -q -O "$FW_FILE_PATH" -U "RUT9xx ($serial,$mac) FW update service" "$server_url$query_string" 2>&1)

	if [ $? -eq 0 ]; then
		SubStringPos "$temp" "error:"
		if [ "$?" == "0" ]; then
			rm "$FW_FILE_PATH" > /dev/null 2>&1
			temp=${temp#error:}
			echo "server_error=$temp"
			exit $EXIT_SERVER_ERROR
		else
			$CONFIG_SET.pre="$pre_cmd_size"
			$CONFIG_SET.post="$post_cmd_size"
			uci commit auto_update
		fi
	else
		rm "$FW_FILE_PATH" > /dev/null 2>&1
		echo "wget_error=$temp"

		exit $EXIT_WGET_ERROR
	fi
}

case "$1" in
	init)
		CheckEnabledFlag
		Init
		;;
	check)
		CheckEnabledFlag
		CheckForUpdate
		;;
	forced_check)
		CheckForUpdate "forced"
		;;
	get)
		GetUpdate "$keep_settings"
		;;
	*)
		PrintUsage
		;;
esac
