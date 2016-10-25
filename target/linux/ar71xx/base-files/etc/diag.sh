#!/bin/sh
# Copyright (C) 2009-2013 OpenWrt.org

. /lib/functions/leds.sh
. /lib/ar71xx.sh

get_status_led() {
	case $(ar71xx_board_name) in
	tlt-rut900)
		status_led="status_green"
		;;
	esac
}

set_state() {
	get_status_led

	case "$1" in
	preinit)
		status_led_blink_preinit
		;;
	failsafe)
		status_led_blink_failsafe
		;;
	esac
}
