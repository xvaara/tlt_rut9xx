--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2008 Jo-Philipp Wich <xm@leipzig.freifunk.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: coovachilli.lua 3442 2008-09-25 10:12:21Z jow $
]]--

local function cecho(string)
	luci.sys.call("echo \"" .. string .. "\" >> /tmp/log.log")
end

local 	m, 		-- General name for a map
		s, 		-- General name for a section
		o, 		-- General name for an option
		
		scc, 	-- Coovachilli configuration section
		cen, 	-- Coovachilli enable flag;
		net, 	-- Network option; The IP address of the router on the hotspot client network: [xxx.xxx.xxx.xxx/cindr]
		ral, 	-- Radius Listen option; The IP address of the radius server [xxx.xxx.xxx.xxx]
		rs1, 	-- Radius server #1 option;
		rs2, 	-- Radius server #2 option;
		rap, 	-- Radius authentication port option;
		hnm, 	-- Hostspot name option;
		rcp, 	-- Radius accounting port option;
		ras, 	-- Radius secret key option;
		ual, 	-- UAM allowed Dynamic list;
		
		sle, 	-- Logging settings section;
		len, 	-- Enable Logging flag;
		
		sft, 	-- FTP options section;
		fen, 	-- Upload via FTP enable flag;
		fhs, 	-- FTP host option;
		fus, 	-- FTP Username;
		fpw, 	-- FTP password option;
		fpt, 	-- FTP port option;
		fhr, 	-- FTP hour option;
		fmn, 	-- FTP min option;
		fwd, 	-- FTP Day option;
		
		snt, 	-- Time Section;
		tnm, 	-- Name of the interval;
		tns, 	-- Fixed time / interval switch;
		thr, 	-- Time hour;
		tmn, 	-- Time minutes;
		twd, 	-- Time weekday;
		tnt 	-- Time interval;
		
local utl = require "luci.util"
local sys = require "luci.sys"

m = Map( "coovachilli", 
	translate( "Wireless Hotspot Logging Settings" ), 
	translate( "" ) )

m:chain("wireless")

sft = m:section( NamedSection, "ftp", "ftp", translate("Logging To FTP Settings"))

fen = sft:option( Flag, "enabled", translate("Enable"), translate("Enable wireless traffic logging and uploading to a FTP server"))

fhs = sft:option( Value, "host", translate("Server address" ), translate("The domain name or IP address of the FTP server that will be used for logs uploading"))

fus = sft:option( Value, "user", translate("User name" ), translate("The user name of the FTP server that will be used for logs uploading"))

fpw = sft:option( Value, "psw", translate("Password" ), translate("The password of the FTP server that will be used for logs uploading"))
fpw.password = true

fpt = sft:option( Value, "port", translate("Port" ), translate("The TCP/IP port of the FTP server that will be used for logs uploading"))
fpt.datatype = "port"

-----------------------------------------------------------------------

snt = m:section( TypedSection, "interval", translate("FTP Upload Settings"), translate("You can configure your timing settings for the log upload via FTP feature here." ))
snt.addremove = false
snt.anonymous = true

--tnm = snt:option( Value, "descr", translate("Description"))

tns = snt:option( ListValue, "fixed", translate("Mode"), translate("The schedule mode to be used for uploading to FTP server"))
tns:value( "1", translate("Fixed" ))
tns:value( "0", translate("Interval" ))

thr = snt:option( Value, "fixed_hour", translate("Hours"), translate("Uploading will be performed on this specific time of the day. Range [0 - 23]"))
thr.datatype = "range(0,23)"
thr:depends( "fixed", "1" )

tmn = snt:option( Value, "fixed_minute", translate("Minutes"), translate("Uploading will be performed on this specific time of the day. Range [0 - 59]"))
tmn.datatype = "range(0,59)"
tmn:depends( "fixed", "1" )

tnt = snt:option( ListValue, "interval_time", translate("Upload interval"), translate("Upload logs to server every x hours"))
tnt:value("1", translate("1 hour"))
tnt:value("2", translatef("%d hours", 2))
tnt:value("4", translatef("%d hours", 4))
tnt:value("8", translatef("%d hours", 8))
tnt:value("12", translatef("%d hours", 12))
tnt:value("24", translatef("%d hours", 24))
tnt:depends( "fixed", "0" )

--twd = snt:option( Value, "weekdays", translate("Weekdays"), translatef("Enter 3 letter weekday keys separated by commas. E.g. Monday, Tuesday and Friday would be %s", "\"mod,tue,fri\"" ))
--twd = snt:option( DummyValue, "", translate("Select days from the list:"))

twd = snt:option(StaticList, "day", translate("Days"), translate("Uploading will be performed on these days only"))

	twd:value("mon",translate("Monday"))
	twd:value("tue",translate("Tuesday"))
	twd:value("wed",translate("Wednesday"))
	twd:value("thu",translate("Thursday"))
	twd:value("fri",translate("Friday"))
	twd:value("sat",translate("Saturday"))
	twd:value("sun",translate("Sunday"))

-----------------------------------------------------------------------

function m.on_parse(self)
	-- We will ettempt to push multiwan to the very end of the parse chain, hopefully making it run last in the init script sequence, hence fixing the problem that has been plagueing me for fucking ever
	--luci.sys.call("echo \"on_parse called\" >> /tmp/log.log")
	self.parsechain[1] = "wireless"
	self.parsechain[2] = "coovachilli"
end
function m.on_before_apply(self)

		local days = utl.trim(sys.exec("uci get coovachilli.cfg044f2a.day"))

		local string = ""
		
		if string.match(days, "mon") ~= nil then
			string = "mon"
		end
		if string.match(days, "tue") ~= nil then
			if #string > 0 then
				string = string..","
			end
			string = string.."tue"
		end
		if  string.match(days, "wed") ~= nil then
			if #string > 0 then
				string = string..","
			end
			string = string.."wed"
		end
		if string.match(days, "thu") ~= nil then
			if #string > 0 then
				string = string..","
			end
			string = string.."thu"
		end
		if string.match(days, "fri") ~= nil then
			if #string > 0 then
				string = string..","
			end
			string = string.."fri"
		end
		if string.match(days, "sat") ~= nil then
			if #string > 0 then
				string = string..","
			end
			string = string.."sat"
		end
		if string.match(days, "sun") ~= nil then
			if #string > 0 then
				string = string..","
			end
			string = string.."sun"
		end

	sys.exec("uci set coovachilli.cfg044f2a.weekdays="..string.."; uci commit")
end

return m
