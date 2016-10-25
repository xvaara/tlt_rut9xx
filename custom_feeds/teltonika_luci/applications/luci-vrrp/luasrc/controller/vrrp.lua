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

module("luci.controller.vrrp", package.seeall)

function index()
	local vrrp
	vrrp = entry( {"admin", "services", "vrrp"}, cbi("vrrp"), _("VRRP"), 1)
-- 	entry({"admin", "services", "vrrp"}, alias("admin", "services", "vrrp", "lan"), _("VRRP"), 1)		
-- 	entry({"admin", "services", "vrrp", "lan"}, cbi("vrrp"),_("LAN Settings"), 1).leaf = true
-- 	entry({"admin", "services", "vrrp","wan"}, cbi("vrrp_wan"), _("Advanced Settings"), 2).leaf = true
	--vrrp.i18n = "vrrp"
	
end
