--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2008 Jo-Philipp Wich <xm@leipzig.freifunk.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: ddns.lua 6588 2010-11-29 15:14:50Z jow $
]]--
local dsp = require "luci.dispatcher"
local utl = require ("luci.util")
local sys = require("luci.sys")

local DNS_INST
		
if arg[1] then
	DNS_INST = arg[1]
else
	--print("[Openvpn.cbasic] Fatal Err: Pass openvpn instance failed")
	--Shoud redirect back to overview
	return nil
end

m = Map("ddns", translate("Dynamic DNS"),
	translate("Dynamic DNS allows you to reach your router using a fixed hostname while having a dynamically changing IP address."))
m:chain("network");

m.redirect = dsp.build_url("admin/services/ddns")

s = m:section(NamedSection, DNS_INST, "service",  translate("DDNS"))
s.addremove = false
s.anonymous = false
s.addtitle = translate("Name")

s:option(Flag, "enabled", translate("Enable"), translate("Enable current configuration"))

state = s:option(Label, "state", translate("Status"), translate("Timestamp of the last IP check or update"))

svc = s:option(ListValue, "service_name", translate("Service"), translate("Your dynamic DNS service provider"))
svc.rmempty = false

local services = { }
local fd = io.open("/usr/lib/ddns/services", "r")
if fd then
	local ln
	repeat
		ln = fd:read("*l")
		local s = ln and ln:match('^%s*"([^"]+)"')
		if s then services[#services+1] = s end
	until not ln
	fd:close()
end

local v
for _, v in luci.util.vspairs(services) do
	svc:value(v)
end

function svc.cfgvalue(...)
	local v = Value.cfgvalue(...)
	if not v or #v == 0 then
		return "-"
	else
		return v
	end
end

function svc.write(self, section, value)
	if value == "-" then
		m.uci:delete("ddns", section, self.option)
	else
		Value.write(self, section, value)
	end
end

svc:value("-", "-- "..translate("custom").." --")


url = s:option(Value, "update_url", translate("Custom update URL"), translate("Custom hostname and the update URL"))
url:depends("service_name", "-")
url.rmempty = true

s:option(Value, "domain", translate("Hostname"), translate("Domain name which will be linked with dynamic IP address")).rmempty = true
s:option(Value, "username", translate("User name"), translate("Name of the user account")).rmempty = true
pw = s:option(Value, "password", translate("Password"), translate("Password of the user account"))
pw.rmempty = true
pw.password = true


require("luci.tools.webadmin")

iface = s:option(ListValue, "ip_source", translate("IP source"), translate("Type of the IP source"))
iface:value("web", translate("Public"))
iface:value("network2", translate("Private"))
iface:value("network", translate("Custom"))
iface.rmempty = true


dummy = s:option(DummyValue, "getinfo_ip_source_status", translate(""))
dummy.default = translate("Private or custom IP source setting, will disable DNS rebinding protection")
dummy:depends("ip_source", "network")
dummy:depends("ip_source", "network2")

--function iface.cfgvalue(self, section)
--	value = m.uci:get("ddns", section, "ip_source")
--	if value == "network" then
--		ip_network = m.uci:get("ddns", section, "ip_network")
--		if ip_network == "wan" then
--			return "network2"
--		end
--	end
--	return value
--end

function iface.write(self, section, value)
	--if value == "network2" then
		--m.uci:set("ddns", section, self.option,"network")
		--m.uci:save("ddns")
		--m.uci:set("ddns", section, "ip_network", "wan")
		--m.uci:save("ddns")
		--m.uci:commit("ddns")
	--else
		m.uci:set("ddns", section, self.option,value)
		m.uci:save("ddns")
	--end
end

iface = s:option(ListValue, "ip_network", translate("Network"), translate("Source network"))
iface:depends("ip_source", "network")
iface.rmempty = true
luci.tools.webadmin.cbi_add_networks(iface)

iface = s:option(ListValue, "ip_interface", translate("Interface"), translate("Source IP interface"))
iface:depends("ip_source", "interface")
iface.rmempty = true
for k, v in pairs(luci.sys.net.devices()) do
	iface:value(v)
end

web = s:option(Value, "ip_url", translate("URL"), translate("Source URL, e.g. http://checkip.dyndns.com/"))
web:depends("ip_source", "web")
web.defaults = "http://checkip.dyndns.com/"
web.rmempty = true

function web.write(self, section, value)
	m.uci:set("ddns", section, self.option,value)
	m.uci:save("ddns")
end
ch_int = s:option(Value, "check_interval",
	translate("IP renew interval (min)"), translate("Time interval (in minutes) to check if the IP address of the device has changed. Range [5 - 600000]"))
ch_int.default = 10
s.defaults.check_unit = "minutes"
ch_int.datatype ="range(5,600000)"

f_int = s:option(Value, "force_interval", translate("Force IP renew (min)"), translate("Time interval (in minutes) to force IP address renewal. Range [5 - 600000]"))
s.defaults.force_unit = "minutes"
f_int.default = 472
f_int.datatype = "range(5,600000)"

local dns_enable = utl.trim(sys.exec("uci -q get ddns. " .. DNS_INST .. ".enabled")) or "0"
function m.on_commit()

	--set dnsmasq rebind protection for private IPs 
	--checking if atleast one enabled ddns needs to work with private IPs
	local private_ip_possible = "0"
	local usr_enable = "0"
	
	m.uci:foreach("ddns", "service", function(s)
		usr_enable = s.enabled or "0"
		if usr_enable == "1" then
			if s.ip_source == "network" or s.ip_source == "network2" then
				private_ip_possible = "1"
			end
		end
	end)
	
	if private_ip_possible == "1" then
		sys.exec("uci -q set dhcp.@dnsmasq[0].rebind_protection=0")
	else
		sys.exec("uci -q set dhcp.@dnsmasq[0].rebind_protection=1")
	end

	sys.exec("uci -q commit dhcp")

	--Delete all usr_enable from ddns config
	local dnsEnable = m:formvalue("cbid.ddns." .. DNS_INST .. ".enabled") or "0"
	if dnsEnable ~= dns_enable then
		m.uci:foreach("ddns", "service", function(s)
			local usr_enable = s.usr_enable or ""
			dns_inst2 = s[".name"] or ""
			if usr_enable == "1" then
				m.uci:delete("ddns", dns_inst2, "usr_enable")
			end
		end)
	end
	m.uci:save("ddns")
	m.uci.commit("ddns")
end

return m
