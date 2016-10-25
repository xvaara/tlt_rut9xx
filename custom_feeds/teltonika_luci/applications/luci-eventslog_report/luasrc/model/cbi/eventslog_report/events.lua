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

m = Map("eventslog_report", translate("Events Log Files Report"),	translate("Create rules for Events Log reporting."))

--
-- Port Forwards
--

s = m:section(TypedSection, "rule", translate("Events Log Report Rules"))
s.template  = "cbi/tblsection"
s.addremove = true
s.anonymous = true
s.sortable  = true
s.extedit   = ds.build_url("admin/status/event/log_report/%s")
s.template_addremove = "eventslog_report/cbi_addinput"
s.novaluetext = translate("There are no events log files report rules created yet")

function s.create(self, section)
	local e = m:formvalue("_newinput.event")
	local t = m:formvalue("_newinput.type")
	
	created = TypedSection.create(self, section)
	self.map:set(created, "event", e)
	self.map:set(created, "type", t)
end

function s.parse(self, ...)
	TypedSection.parse(self, ...)
	if created then
		m.uci:save("eventslog_report")
		luci.http.redirect(ds.build_url("admin/status/event/log_report", created	))
	end
end
src = s:option(DummyValue, "event", translate("Events log"), translate("Events log for which the rule is applied"))
src.rawhtml = true
src.width = "23%"
function src.cfgvalue(self, s)
	local z = self.map:get(s, "event")
	if z == "system" then 
		return translatef("System")
	elseif z == "network" then
		return translatef("Network")
	elseif z == "all" then
		return translatef("All")
	else
	    return translatef("NA")
	end
end

src = s:option(DummyValue, "action", translate("Transfer type"), translate("Events log file transfer type"))
src.rawhtml = true
src.width = "23%"
function src.cfgvalue(self, s)
	local z = self.map:get(s, "type")
	if z == "Email" then 
		return translatef("Email")
	elseif z == "FTP" then
		return translatef("FTP")
	else
	    return translatef("NA")
	end
end

en = s:option(Flag, "enable", translate("Enable"), translate("Make a rule active/inactive"))
en.width = "23%"

return m
