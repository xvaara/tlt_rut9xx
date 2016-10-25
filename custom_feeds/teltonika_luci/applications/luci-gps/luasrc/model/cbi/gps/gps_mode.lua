--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: forwards.lua 8117 2011-12-20 03:14:54Z jow $
]]--

local ds = require "luci.dispatcher"
local ft = require "luci.tools.gps"

m = Map("gps", translate("Gps Mode Configuration"),	translate(""))

s = m:section(TypedSection, "gps", translate("Data sending"))

o = s:option(Value, "min_period", translate("Min period"), translate(""))
o.default = "5"
o.datatype = "range(0,999999)"

o = s:option(Value, "min_distance", translate("Min distance"), translate(""))
o.default = "200"
o.datatype = "range(0,999999)"

o = s:option(Value, "min_angle", translate("Min angle"), translate(""))
o.default = "30"
o.datatype = "range(0,999999)"

o = s:option(Value, "min_saved_record", translate("Min saved records"), translate(""))
o.default = "20"
o.datatype = "range(0,999999)"

o = s:option(Value, "send_period", translate("Send period"), translate(""))
o.default = "50"
o.datatype = "range(0,999999)"

--
-- GPS MODE
--
s = m:section(TypedSection, "rule", translate("Rules"))
s.template  = "cbi/tblsection"
s.addremove = true
s.anonymous = true
s.sortable  = true
s.extedit   = ds.build_url("admin/services/gps/mode/%s")
s.template_addremove = "gps/cbi_add_gps_rule"
s.novaluetext = translate("There are no gps rules created yet")

function s.create(self, section)
	local wan = m:formvalue("_newgps.wan")
	local din = m:formvalue("_newgps.din2")
	local type = m:formvalue("_newgps.type")
	
	created = TypedSection.create(self, section)
	self.map:set(created, "wan", wan)
	self.map:set(created, "type", type)
	self.map:set(created, "din2", din)

	self.map:set(created, "min_period", "5")
	self.map:set(created, "min_distance", "200")
	self.map:set(created, "min_angle", "30")
	self.map:set(created, "min_saved_record", "20")
	self.map:set(created, "send_priod", "50")
	
end

function s.parse(self, ...)
	TypedSection.parse(self, ...)
	if created then
		m.uci:save("gps")
		luci.http.redirect(ds.build_url("admin/services/gps/mode", created	))
	end
end

src = s:option(DummyValue, "wan", translate("Wan"), translate("Specifies type of GPS rule"))
src.rawhtml = true
src.width   = "10%"
function src.cfgvalue(self, s)
	local z = self.map:get(s, "wan")
	--os.execute("echo \"l"..z.."l\" >>/tmp/aaa")
	--return z
	if z == "mobile" then
		return translatef("Mobile")
	elseif z == "wired" then
		return translatef("Wired")
	elseif z == "wifi" then
		return translatef("WiFi")
	else
	    return translatef("N/A")
	end
end

src = s:option(DummyValue, "type", translate("Type"), translate(""))
src.rawhtml = true
src.width   = "10%"
function src.cfgvalue(self, s)
	local z = self.map:get(s, "type")
	if z == "home" then
		return translatef("Home")
	elseif z == "roaming" then
		return translatef("Roaming")
	elseif z == "both" then
		return translatef("Both")
	else
	    return translatef("-")
	end
end

src = s:option(DummyValue, "din2", translate("Digital isolated input"), translate(""))
src.rawhtml = true
src.width   = "10%"
function src.cfgvalue(self, s)
	local z = self.map:get(s, "din2")
	if z == "low" then
		return translatef("Low")
	elseif z == "high" then
		return translatef("High")
	elseif z == "both" then
		return translatef("Both")
	else
	    return translatef("N/A")
	end
end

src = s:option(DummyValue, "min_period", translate("Min period"), translate("sec."))
src.rawhtml = true
src.width   = "10%"

src = s:option(DummyValue, "min_saved_record", translate("Min saved records"), translate(""))
src.rawhtml = true
src.width   = "10%"

src = s:option(DummyValue, "send_period", translate("Send period"), translate("sec."))
src.rawhtml = true
src.width   = "10%"


ft.opt_enabled(s, Flag, translate("Enable"), translate("Uncheck to disable gps rule, Check to enable gps rule")).width = "18%"

local save = m:formvalue("cbi.apply")
if save then
	--Delete all usr_enable from gps config
	m.uci:foreach("gps", "rule", function(s)
		gps_inst = s[".name"] or ""
		gpsEnable = m:formvalue("cbid.gps." .. gps_inst .. ".enabled") or "0"
		gps_enable = s.enabled or "0"
		if gpsEnable ~= gps_enable then
			m.uci:foreach("gps", "rule", function(a)
				gps_inst2 = a[".name"] or ""
				local usr_enable = a.usr_enable or ""
				if usr_enable == "1" then
					m.uci:delete("gps", gps_inst2, "usr_enable")
				end
			end)
		end
	end)
	m.uci:save("gps")
	m.uci.commit("gps")
end

return m
