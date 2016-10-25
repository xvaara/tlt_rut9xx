--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2008 Jo-Philipp Wich <xm@leipzig.freifunk.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: openvpn.lua 7362 2011-08-12 13:16:27Z jow $
]]--

module("luci.controller.openvpn", package.seeall)

function index()
	entry( {"admin", "services", "vpn"}, alias("admin", "services", "vpn", "openvpn-tlt"), _("VPN"), 54)
	entry( {"admin", "services", "vpn", "openvpn-tlt"}, arcombine(cbi("openvpn"), cbi("cbasic")), _("OpenVPN"), 1).leaf=true
	entry( {"admin", "services", "vpn", "gre-tunnel"}, arcombine(cbi("gre-tunnel/gre-tunnel"), cbi("gre-tunnel/gre-tunnel_edit")), _("GRE Tunnel"), 3).leaf=true
	entry( {"admin", "services", "vpn", "pptp"}, arcombine( cbi("pptp/pptp"),cbi("pptp/pptp_edit")), _("PPTP"), 4).leaf=true
	entry( {"admin", "services", "vpn", "l2tp"}, arcombine( cbi("l2tp/l2tp"),cbi("l2tp/l2tp_edit")), _("L2TP"), 5).leaf=true
end
