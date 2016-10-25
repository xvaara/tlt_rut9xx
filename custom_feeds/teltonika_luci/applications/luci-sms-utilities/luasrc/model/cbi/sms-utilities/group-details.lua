--[[
LuCI - Lua Configuration Interface

Copyright 2011 Jo-Philipp Wich <xm@subsignal.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: forward-details.lua 8117 2011-12-20 03:14:54Z jow $
]]--

local sys = require "luci.sys"
local dsp = require "luci.dispatcher"
local utl = require "luci.util"
local uci = require "luci.model.uci".cursor()
local m, s, o

arg[1] = arg[1] or ""

m = Map("sms_utils", translate("User Group Configuration"))

m.redirect = dsp.build_url("admin/services/sms/group/")
if m.uci:get("sms_utils", arg[1]) ~= "group" then
	luci.http.redirect(dsp.build_url("admin/services/sms/group"))
	return
end

s = m:section(NamedSection, arg[1], "group", translate("Modify User Group"))
s.anonymous = true
s.addremove = false

src = s:option(Value, "name", translate("Group name"), translate("Name of grouped phone numbers"))
src.datatype = "fieldvalidation('^[a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. ]+$',0)"

src = s:option(DynamicList, "tel", translate("Phone number"), translate("Phone number belonging to a group. Phone number must be in international format. Allowable characters: (0-9#*+)"))
function src.validate(self, value, section)
	for i=1, #value do
		if value[i]:match("^[0-9\*+#]+$") == nil then
			return nil, translatef("Bad phone number %s", i)
		end
	end
	return value
end


return m
