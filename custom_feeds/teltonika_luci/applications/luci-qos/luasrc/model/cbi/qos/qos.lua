--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: qos.lua 7238 2011-06-25 23:17:10Z jow $
]]--

local wa = require "luci.tools.webadmin"
local fs = require "nixio.fs"

m = Map("qos", translate("Quality of Service"),
	translate("With QoS you can prioritize network traffic selected by addresses, ports or services."))
	
s = m:section(TypedSection, "interface", translate("Interfaces"))
s.addremove = true
s.anonymous = false
s.template = "qos/tblsection"
s.sectionhead = "Interface"

e = s:option(Flag, "enabled", translate("Enable"), translate("Check to enable settings/Uncheck to disable settings"))
e.rmempty = false

-- c = s:option(ListValue, "classgroup", translate("Classification group"))
-- c:value("Default", translate("default"))
-- c.default = "Default"

s:option(Flag, "overhead", translate("Calculate overhead"), translate("Check to decrease upload and download ratio to prevent link saturation"))

s:option(Flag, "halfduplex", translate("Half-duplex"), translate("Check to enable data transmission in both directions on a single carrier"))

s:option(Value, "download", translate("Download speed (kbit/s)"), translate("Specify maximal download speed"))

s:option(Value, "upload", translate("Upload speed (kbit/s)"), translate("Specify maximal upload speed"))

s = m:section(TypedSection, "classify", translate("Classification Rules"))
s.template = "cbi/tblsection"
s.anonymous = true
s.addremove = true
s.sortable  = true

t = s:option(ListValue, "target", translate("Target"), translate("Select target for which rule will be applied"))
t:value("Priority", translate("Priority"))
t:value("Express", translate("Express"))
t:value("Normal", translate("Normal"))
t:value("Bulk", translate("Low"))
t.default = "Normal"


srch = s:option(Value, "srchost", translate("Source host"), translate("Select host from which data will be transmitted"))
srch.rmempty = true
srch:value("", translate("All"))
wa.cbi_add_knownips(srch)
srch.maxWidth = "100px"

dsth = s:option(Value, "dsthost", translate("Destination host"), translate("Select host to which data will be transmitted"))
dsth.rmempty = true
dsth:value("", translate("All"))
wa.cbi_add_knownips(dsth)
dsth.maxWidth = "100px"

l7 = s:option(ListValue, "layer7", translate("Service"), translate("Select service for which rule will be applied"))
l7.rmempty = true
l7:value("", translate("All"))
l7.maxWidth = "100px"

local pats = io.popen("find /etc/l7-protocols/ -type f -name '*.pat'")
if pats then
	local l
	while true do
		l = pats:read("*l")
		if not l then break end

		l = l:match("([^/]+)%.pat$")
		if l then
			l7:value(l)
		end
	end
	pats:close()
end

p = s:option(Value, "proto", translate("Protocol"), translate("Select data transmission protocol"))
p:value("", translate("All"))
p:value("tcp", translate("TCP"))
p:value("udp", translate("UDP"))
p:value("icmp", translate("ICMP"))
p.rmempty = true
p.maxWidth = "100px"

ports = s:option(Value, "ports", translate("Ports"), translate("Select which ports will be used for transmission"))
ports.rmempty = true
ports:value("", translate("All"))
ports.maxWidth = "100px"

bytes = s:option(Value, "connbytes", translate("Number of bytes"), translate("Specify the maximal number of bytes for connection"))
bytes.maxWidth = "100px"

local save = m:formvalue("cbi.apply")
if save then
	--Delete all usr_enable from qos config
	m.uci:foreach("qos", "interface", function(s)
		qos_inst = s[".name"] or ""
		qosEnable = m:formvalue("cbid.qos." .. qos_inst .. ".enabled") or "0"
		qos_enable = s.enabled or "0"
		if qosEnable ~= qos_enable then
			m.uci:foreach("qos", "interface", function(a)
				qos_inst2 = a[".name"] or ""
				local usr_enable = a.usr_enable or ""
				if usr_enable == "1" then
					m.uci:delete("qos", qos_inst2, "usr_enable")
				end
			end)
		end
	end)
	m.uci:save("qos")
	m.uci.commit("qos")
end

return m
