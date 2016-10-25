#!/bin/sh

CONFIG=$config

log(){
	logger -t "openvpn-$1" "$2"
}

if [ -n $CONFIG ]; then
  AUTH_FILE=`echo $config | sed 's/openvpn-//g' | sed 's/.conf//g'`
  AUTH_FILE_PATH=/etc/openvpn/auth_$AUTH_FILE

  userpass=`cat $1`
  username=`echo $userpass | awk '{print $1}'`
  password=`echo $userpass | awk '{print $2}'`
  localuserpass=`cat $AUTH_FILE_PATH`
  localusername=`echo $localuserpass | awk '{print $1}'`
  localpassword=`echo $localuserpass | awk '{print $2}'`

  if [ "$username" = "$localusername" -a "$password" = "$localpassword" ]
  then
  	log $AUTH_FILE "OpenVPN authentication successfull: $username"
  	exit 0
  fi

  log $AUTH_FILE "OpenVPN authentication failed"
  exit 1
fi

return 1
