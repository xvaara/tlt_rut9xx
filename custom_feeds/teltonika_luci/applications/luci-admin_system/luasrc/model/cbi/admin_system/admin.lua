--[[
Teltonika R&D. ver 0.1
]]--

local fs = require "nixio.fs"
local fw = require "luci.model.firewall"
require("luci.fs")
require("luci.config")

local sys = require"luci.sys"
local util = require "luci.util"

local logDir, o, needReboot = false
local deathTrap = { }

local confleds = luci.util.trim(luci.sys.exec("uci get system.@leds[0].enable"))

m = Map("system", translate("Administration Settings"),
	translate(""))
	
	
s2 = m:section(TypedSection, "system", translate("Router Name And Host Name"))
s2.addremove = false
s2.anonymous = true

routername = s2:option(Value, "routername", translate("Router name"), translate("Specifies router name, it will be seen in Status page"))
routername.datatype = "network"

function routername.write(self, section, value)
	m.uci:set("system", section, "routername", value)
	m.uci:save("system")
	m.uci:commit("system")
end

hostname = s2:option(Value, "hostname", translate("Host name"), translate("Specifies how router will be seen by other devices"))
hostname.datatype = "network"
hostname.rmempty = false

function hostname.write(self, section, value)
	m.uci:set("system", section, "hostname", value)
	m.uci:save("system")
  	m.uci:commit("system")
	luci.sys.hostname(value)
end
	
	
s = m:section(TypedSection, "_dummy", translate("Administrator Password"))
s.addremove = false
s.anonymous = true

pw1 = s:option(Value, "pw1", translate("New password"), translate("Enter your new administration password"))
pw1.password = true

pw2 = s:option(Value, "pw2", translate("Confirm new password"), translate("Re-enter your new administration password"))
pw2.password = true

function s.cfgsections()
	return { "_pass" }
end

se = m:section(TypedSection, "system", translate("Language Settings"))
se.addremove = false
se.anonymous = true

o2 = se:option(ListValue, "lang", translate("Language"), translate("Website will be translated into selected language"))
o2:value("en","English")

local i18ndir = luci.i18n.i18ndir .. "base."
--  luci.http.prepare_content("application/json")
--  luci.http.write_json(luci.util.kspairs(luci.config.languages))
for k, v in luci.util.kspairs(luci.config.languages) do
	local file = i18ndir .. k:gsub("_", "-")
	if k:sub(1, 1) ~= "." and luci.fs.access(file .. ".lmo") then
		o2:value(k, v)
	end
end

function o2.cfgvalue(...)
	return m.uci:get("luci", "main", "lang")
end

function o2.write(self, section, value)
	m.uci:set("luci", "main", "lang", value)
	m.uci:save("luci")
	m.uci:commit("luci")
end	

function m.on_commit(map)
	local v1 = pw1:formvalue("_pass")
	local v2 = pw2:formvalue("_pass")
	local ledsman = luci.http.formvalue("cbid.system.cfg0a036d.enable")
	if ledsman == nil then
		ledsman = "0"
	end
	
	if v1 and v2 and #v1 > 0 and #v2 > 0 then
		if v1 == v2 then
			if luci.sys.user.setpasswd(luci.dispatcher.context.authuser, v1) == 0 then
				m.message = translate("scs: Password successfully changed!")
				m.uci:set("teltonika", "sys", "pass_changed", "1")
				m.uci:save("teltonika")
				m.uci:commit("teltonika")
			else
				m.message = translate("err: Unknown error, password not changed!")
			end
		else
			m.message = translate("err: Given password confirmation did not match, password not changed!")
		end
	end
	
	if needReboot then
		m.message = translate("scs: You must reboot the router for the changes to take effect.")
	end

	if confleds ~= ledsman then
		luci.sys.call("/etc/init.d/ledsman restart")
	end
end

ipv = m:section(TypedSection, "ipv6", translate("IPv6 Support"))
ipv.addremove = false

ip = ipv:option(Flag, "enable", translate("Enable"), translate("Enable IPv6 support for all services"))
ip.rmempty = false
ip.default = '0'

function ip.write(self, section, value)
	local old_value=util.trim(sys.exec("uci get -q system.ipv6.enable"))
	if tonumber(value) ~= tonumber(old_value) then
		sys.call("uci set -q system.ipv6.enable="..tonumber(value))
		if tonumber(value)==1 then
			sys.call("sed -i 's/.*net.ipv6.conf.default.disable_ipv6.*/net.ipv6.conf.default.disable_ipv6=0/' /etc/sysctl.conf")
			sys.call("sed -i 's/.*net.ipv6.conf.all.disable_ipv6.*/net.ipv6.conf.all.disable_ipv6=0/' /etc/sysctl.conf")
			proto=util.trim(sys.exec("uci get -q network.wan.proto"))
			if proto=="dhcp" then
				sys.call("uci set -q network.wan6=interface; uci set -q network.wan6.ifname='@wan'; uci set -q network.wan6.proto='dhcpv6'; uci commit network")
			else
				sys.call("uci delete -q network.wan6; uci commit network")
			end
		else
			sys.call("uci delete -q dhcp.lan.enable_ra")
			sys.call("uci delete -q network.wan6; uci commit network")
			sys.call("sed -i 's/.*net.ipv6.conf.default.disable_ipv6.*/net.ipv6.conf.default.disable_ipv6=1/' /etc/sysctl.conf")
			sys.call("sed -i 's/.*net.ipv6.conf.all.disable_ipv6.*/net.ipv6.conf.all.disable_ipv6=1/' /etc/sysctl.conf")
		end
		sys.call("sysctl -p >/dev/null 2>/dev/null &")
	end
	m.uci:commit("system")
end

--m2 = Map("teltonika")
md = m:section(TypedSection, "system", translate("Login Page"))
md.addremove = false

if luci.tools.status.show_mobile() then
	o1 = md:option(Flag, "shw3g", translate("Show mobile info at login page"), translate("Show operator and signal strenght at login page"))
	o1.rmempty = false


	function o1.cfgvalue(...)
		return m.uci:get("teltonika", "sys", "shw3g")
	end

	function o1.write(self, section, value)
		m.uci:set("teltonika", "sys", "shw3g", value)
		m.uci:save("teltonika")
		m.uci:commit("teltonika")
	end
end
o2 = md:option(Flag, "showwan", translate("Show WAN IP at login page"), translate("Show WAN IP at login page"))
o2.rmempty = false

function o2.cfgvalue(...)
	return m.uci:get("teltonika", "sys", "showwan")
end

function o2.write(self, section, value)
	m.uci:set("teltonika", "sys", "showwan", value)
	m.uci:save("teltonika")
	m.uci:commit("teltonika")
end	

mo = m:section(TypedSection, "leds", translate("LEDs Indication"))
mo.addremove = false

oo = mo:option(Flag, "enable", translate("Enable"), translate("Enable signal strenght, LAN and connection status indication using LEDs"))
oo.rmempty = false
oo.default = '1'

	------lua kodas skirtas resetui ivykdyti
md = m:section(TypedSection, "system", translate("Restore Default Settings"))
md.addremove = false
md.anonymous = true
md.add_template = "admin_system/reset"

return m
