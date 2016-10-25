#!/bin/sh

uci set events_reporting.send_blocking.blocked=0
uci commit events_reporting

`sed -i "/signal_strength_protection.sh/d" /etc/crontabs/root`
