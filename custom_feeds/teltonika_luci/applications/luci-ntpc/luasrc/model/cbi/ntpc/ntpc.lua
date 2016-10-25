--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2008 Jo-Philipp Wich <xm@leipzig.freifunk.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: ntpc.lua 6065 2010-04-14 11:36:13Z ben $
]]--
require("luci.sys")
require("luci.sys.zoneinfo")
require("luci.tools.webadmin")
require("luci.fs")
require("luci.config")

local utl = require "luci.util"
local sys = require "luci.sys"

local has_gps = utl.trim(luci.sys.exec("uci get hwinfo.hwinfo.gps"))
local port

local function cecho(string)
	luci.sys.call("echo \"" .. string .. "\" >> /tmp/log.log")
end

m = Map("ntpclient", translate("Time Synchronisation"), translate(""))

--------- General

s = m:section(TypedSection, "ntpclient", translate("General"))
s.anonymous = true
s.addremove = false


--s:option(DummyValue, "_time", translate("Current system time")).value = os.date("%c")

o = s:option(DummyValue, "_time", translate("Current system time"), translate("Device\\'s current system time. Format [year-month-day, hours:minutes:seconds]"))
o.template = "admin_system/clock_status"

local tzone = s:option(ListValue, "zoneName", translate("Time zone"), translate("Time zone of your country"))
tzone:value(translate("UTC"))
for i, zone in ipairs(luci.sys.zoneinfo.TZ) do
	tzone:value(zone[1])
end

function tzone.write(self, section, value)
	local cfgName
	local cfgTimezone

	Value.write(self, section, value)

	local function lookup_zone(title)
		for _, zone in ipairs(luci.sys.zoneinfo.TZ) do
			if zone[1] == title then return zone[2] end
		end
	end

	m.uci:foreach("system", "system", function(s)
		cfgName = s[".name"]
		cfgTimezone = s.timezone
	end)

	local timezone = lookup_zone(value) or "GMT0"
	m.uci:set("system", cfgName, "timezone", timezone)
	m.uci:save("system")
	m.uci:commit("system")
	luci.fs.writefile("/etc/TZ", timezone .. "\n")
end

s:option(Flag, "enabled", translate("Enable NTP"), translate("Enable system\\'s time synchronization with time server using NTP (Network Time Protocol)"))

el1 = s:option(Value, "interval", translate("Update interval (in seconds)"), translate("How often the router should update system\\'s time"))
el1.rmempty = true
el1.datatype = "integer"

el = s:option(Value, "save", translate("Save time to flash"), translate("Save last synchronized time to flash memory"))
el.template = "cbi/flag"

function el1.validate(self, value, section)
	aaa=luci.http.formvalue("cbid.ntpclient.cfg0c8036.save")
	if tonumber(aaa) == 1 then
		if tonumber(value) >= 3600 then
			return value
		else
			return nil, "The value is invalid because min value 3600"
		end
	else
		if tonumber(value) >= 10 then
			return value
		else
			return nil, "The value is invalid because  min value 10"
		end
	end
end

a = s:option(Value, "count", translate("Count of time synchronizations"), translate("How many time synchronizations NTP (Network Time Protocol) client should perform. Empty value - infinite"))
a.datatype = "fieldvalidation('^[0-9]+$',0)"
a.rmempty = true

------ GPS synchronisation
if has_gps == "1" then
	gps = s:option(Flag, "gps_sync", translate("GPS synchronization"), translate("Enable periodic time synchronization of the system, using GPS module (does not require internet connection)"))
	gps_int = s:option(ListValue, "gps_interval", translate("GPS time update interval"), translate("Update period for updating system time from GPS module"))
	gps_int:value("1", translate("Every 5 minutes"))
	gps_int:value("2", translate("Every 30 minutes"))
	gps_int:value("3", translate("Every hour"))
	gps_int:value("4", translate("Every 6 hours"))
	gps_int:value("5", translate("Every 12 hours"))
	gps_int:value("6", translate("Every 24 hours"))
	gps_int:value("7", translate("Every week"))
	gps_int:value("8", translate("Every month"))
	gps_int:depends("gps_sync", "1")
	gps_int.default = "6"
	gps_int.rmempty = true
	gps_int.datatype = "integer"
end

------- Clock Adjustment
s2 = m:section(TypedSection, "ntpdrift", translate("Clock Adjustment"))
s2.anonymous = true
s2.addremove = false
b = s2:option(Value, "freq", translate("Offset frequency"), translate("Adjust the drift of the local clock to make it run more accurately"))
b.datatype = "fieldvalidation('^[0-9]+$',0)"
b.rmempty = true

function m.on_after_commit(self)
	luci.sys.call("export ACTION=ifdown; sh /etc/hotplug.d/iface/20-ntpclient")
	luci.sys.call("export ACTION=; sh /etc/hotplug.d/iface/20-ntpclient")
	
	if has_gps == "1" then
		local gps_service_enabled = utl.trim(luci.sys.exec("uci get gps.gps.enabled"))
		local gps_sync_enabled = utl.trim(luci.sys.exec("uci get ntpclient.@ntpclient[0].gps_sync"))
		local gps_sync_period = utl.trim(luci.sys.exec("uci get ntpclient.@ntpclient[0].gps_interval"))

		luci.sys.exec('sed -i "/gps_time_sync.sh/d" /etc/crontabs/root')
		
		if gps_sync_enabled == "1" then
			cron_conf = io.open("/etc/crontabs/root", "a")
			if gps_sync_period == "1" then
				cron_conf:write("*/5 * * * * /sbin/gps_time_sync.sh") --every 5 min
			elseif gps_sync_period == "2" then
				cron_conf:write("*/30 * * * * /sbin/gps_time_sync.sh")  --every 30 min
			elseif gps_sync_period == "3" then
				cron_conf:write("0 * * * * /sbin/gps_time_sync.sh")  --every hour
			elseif gps_sync_period == "4" then
				cron_conf:write("* */6 * * * /sbin/gps_time_sync.sh") --every 6 hours
			elseif gps_sync_period == "5" then
				cron_conf:write("* */12 * * * /sbin/gps_time_sync.sh") -- every 12 hours
			elseif gps_sync_period == "6" then
				cron_conf:write("0 0 * * * /sbin/gps_time_sync.sh") -- every 24h (day)
			elseif gps_sync_period == "7" then
				cron_conf:write("* * * * 0 /sbin/gps_time_sync.sh") --every week
			elseif gps_sync_period == "8" then
				cron_conf:write("0 0 1 * * /sbin/gps_time_sync.sh") --every month
			end
			cron_conf:close()
			
			if gps_service_enabled ~= "1" then
				luci.sys.exec("uci set gps.gps.enabled='1'")
				luci.sys.exec("uci commit gps")
				luci.sys.exec("/sbin/luci-reload")
			end
		end
	end
end

return m
