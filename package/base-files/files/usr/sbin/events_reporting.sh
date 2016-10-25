#!/bin/sh
	

. /lib/functions.sh
. /lib/teltonika-functions.sh

event_type="$1"
msg_text="$1| $2"
if [ $# -eq 3 ]; then
	low_text="$(echo $3 | tr '[A-Z]' '[a-z]')"
else
	low_text="$(echo $2 | tr '[A-Z]' '[a-z]')"
fi
recipients=""

send_sms(){
	local phone_number="$1"
	local text="$2"
	netstate="`gsmctl -g`"
	time=`date "+%Y-%m-%d; %H:%M:%S"`
	if [ "$netstate" == "registered (home)" ] || [ "$netstate" == "registered (roaming)" ]; then
		gsmctl -S -s "$phone_number $text $time"
	else
		
		echo "$phone_number $text $time" >>/tmp/needtosend
		echo "" >>/tmp/needtosend
	fi
}

manage_sms(){
	local rule="$1"
	local uniq_message                                                      
	local message
	local netstate 

	config_get uniq_message "$rule" "uniqMessage" ""                        
	
	if [ "$uniq_message" == "true" ]; then                                                                                                                  
	        config_get message "$rule" "message" ""                                                                                                      
		msg_text=$message                                                                                                                           
	fi  
	
	if [ "$msg_text" != "" ]; then
		config_list_foreach "$rule" "telnum" send_sms "$msg_text"
	fi
}

format_rec_string(){
	if [ -n "$recipients" ]; then
		recipients="$recipients $1"
	else
		recipients="$1"
	fi
}

send_email(){
	local rule="$1"
	local smtp_host
	local smtp_port
	local subject
	local uniq_message
	local message
	local user_name
	local password
	local sender
	local secure_conn

	config_get smtp_host "$rule" "smtpIP" ""
	config_get smtp_port "$rule" "smtpPort" ""
	config_get subject "$rule" "subject" ""                                                                              
	config_get uniq_message "$rule" "uniqMessage" ""
        config_get user_name "$rule" "userName" ""                                                                           
	config_get password "$rule" "password" ""                                                                            
	config_get sender "$rule" "senderEmail" ""                                                                           
	config_get secure_conn "$rule" "secureConnection" ""
	config_list_foreach "$rule" "recipEmail" format_rec_string
	
	if [ "$uniq_message" == "true" ]; then
		config_get message "$rule" "message" ""
		msg_text=$message
	fi

	if [ -z "$smtp_host" ] || [ -z "$smtp_port" ] || [ -z "$user_name" ] || [ -z "$password" ] || [ -z "$sender" ]; then
		return 1
	fi
	
	local check_net=`ping -w 5 -W 5 -q 8.8.8.8 | grep "packet loss" | awk -F ' ' '{print $7}' 2>&1`

	if [ "$check_net" != "100%" ] && [ "$check_net" != "" ]; then
		if [ "$secure_conn" != "1" ]; then
	sendmail -S "$smtp_host:$smtp_port" -f "$sender" -au"$user_name" -ap"$password" $recipients<<EOF
subject:$subject
from:$sender
$msg_text
EOF
		else
	sendmail -H "exec openssl s_client -quiet -connect $smtp_host:$smtp_port -tls1 -starttls smtp" -f "$sender" -au"$user_name" -ap"$password" $recipients <<EOF
subject:$subject
from:$sender
$msg_text
EOF
		fi
	else
		if [ "$secure_conn" != "1" ]; then
			local bla="echo -e \"subject:$subject\nfrom:$sender\n$msg_text\" | sendmail -S \"$smtp_host:$smtp_port\" -f \"$sender\" -au\"$user_name\" -ap\"$password\" $recipients"
			echo "$bla" >>/etc/email
		else
			local bla="echo -e \"subject:$subject\nfrom:$sender\n\"$msg_text | sendmail -H \"exec openssl s_client -quiet -connect $smtp_host:$smtp_port -tls1 -starttls smtp\" -f \"$sender\" -au\"$user_name\" -ap\"$password\" $recipients"
			echo "$bla" >>/etc/email
		fi
	fi

}

execute_rules(){
	local enable
	local event
	local event_mark
	local action
	
	config_get enable "$1" "enable" "0"
	config_get event "$1" "event"
	config_get event_mark "$1" "eventMark"
	config_get action "$1" "action"

	event_mark="$(echo $event_mark | tr '[A-Z]' '[a-z]')" 

	if [ "$event" == "$event_type" ]; then
		if [ "$low_text" == "$event_mark" ] || [ "$event_mark" == "all" ] || ([ $# -lt 3 ] && [ `echo "$low_text" | grep -c -wF "$event_mark"` -gt 0 ]); then
			if [ "$enable" == "1" ]; then
				if [ -n "$action" ]; then
					case "$action" in
						sendSMS)
							manage_sms "$1"
							;;
						sendEmail)
							send_email "$1"
							;;
					esac
				fi
			fi
		fi
	fi
}

config_load events_reporting
 
config_foreach execute_rules "rule"
