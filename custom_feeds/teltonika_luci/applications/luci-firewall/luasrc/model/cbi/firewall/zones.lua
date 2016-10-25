--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: zones.lua 8108 2011-12-19 21:16:31Z jow $
]]--

local ds = require "luci.dispatcher"
local fw = require "luci.model.firewall"

local m, s, o, p, i, v

m = Map("firewall",
	translate("Firewall"),
	translate("General settings allows you to set up default firewall policy."))

fw.init(m.uci)

s = m:section(TypedSection, "defaults", translate("General Settings"))
s.anonymous = true
s.addremove = false

-- s:option(Flag, "syn_flood", translate("Enable SYN flood protection"), translate("Makes router more resistant to SYN flood attacks"))

o = s:option(Flag, "drop_invalid", translate("Drop invalid packets"), translate("A Drop action is performed on a packet that is determined to be invalid"))
o.default = o.disabled

p = {
	s:option(ListValue, "input", translate("Input"), translate("DEFAULT* action that is to be performed for packets that pass through the Input chain")),
	s:option(ListValue, "output", translate("Output"), translate("DEFAULT* action that is to be performed for packets that pass through the Output chain")),
	s:option(ListValue, "forward", translate("Forward"), translate("DEFAULT* action that is to be performed for packets that pass through the Forward chain"))
}

for i, v in ipairs(p) do
	v:value("REJECT", translate("Reject"))
	v:value("DROP", translate("Drop"))
	v:value("ACCEPT", translate("Accept"))
end

s = m:section(NamedSection, "DMZ", "dmz", translate("DMZ Configuration"))

dmz_en = s:option(Flag, "enabled", translate("Enable"), translate("By enabling DMZ for a specific internet host (e.g. your computer), you will expose that host and its services to the router\\'s WAN network"))
dmz_en.rmempty = false

--[[function dzm_en.cfgvalue(self, section)
	local rtnVal
	if self.map:get(section, "enabled") == "0" then
		rtnVal = "0"
	else
		rtnVal = "1"
	end
	return rtnVal 
end]]

--[[function dzm_en.write(self, section, value)
	if value ~= "0" then
		value = nil
	end
	return Flag.write(self, section, value)
end]]

o = s:option(Value, "dest_ip", translate("DMZ host IP address"), translate("Internal (i.e. LAN) host\\'s IP address"))
o.datatype = "ip4addr"

--[[
s = m:section(TypedSection, "zone", translate("Zones"))
s.template = "cbi/tblsection"
s.anonymous = true
s.addremove = false
s.extedit   = false

function s.create(self)
	local z = fw:new_zone()
	if z then
		luci.http.redirect(
			ds.build_url("admin", "network", "firewall", "zones", z.sid)
		)
	end
end

function s.remove(self, section)
	return fw:del_zone(section)
end

o = s:option(DummyValue, "_info", translate("Zone ⇒ Forwardings"))
o.template = "cbi/firewall_zoneforwards"
o.cfgvalue = function(self, section)
	return self.map:get(section, "name")
end

p = {
	s:option(ListValue, "input", translate("Input")),
	s:option(ListValue, "output", translate("Output")),
	s:option(ListValue, "forward", translate("Forward"))
}

for i, v in ipairs(p) do
	v:value("REJECT", translate("reject"))
	v:value("DROP", translate("drop"))
	v:value("ACCEPT", translate("accept"))
end

s:option(Flag, "masq", translate("Masquerading"))
s:option(Flag, "mtu_fix", translate("MSS clamping"))]]

return m
