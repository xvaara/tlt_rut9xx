--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2008 Jo-Philipp Wich <xm@leipzig.freifunk.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: samba.lua 6984 2011-04-13 15:14:42Z soma $
]]--
require("luci.tools.webadmin")
local sys = require "luci.sys"
local utl = require "luci.util"

m = Map("samba", translate("Network Shares"))

s = m:section(TypedSection, "samba", translate("Samba"))
s.anonymous = true

--s:tab("general",  translate("General Settings"))
--s:tab("template", translate("Edit Template"))
o = s:option(Flag, "enable", translate("Enable"), translate("Enable samba"))
o.default= "0"
o.rmempty= false

s:option( Value, "name", translate("Hostname"))
s:option( Value, "description", translate("Description"))
s:option( Value, "workgroup", translate("Workgroup"))
--s:option( Value, "homes", translate("Share home-directories"), translate("Allow system users to reach their home directories via network shares"))



s = m:section(TypedSection, "sambashare", translate("Shared Directories"))
s.anonymous = true
s.addremove = true
s.template = "cbi/tblsection"

s:option(Value, "name", translate("Name"))
pth = s:option(Value, "path", translate("Path"))

local ioman = utl.trim(sys.exec("df | grep /mnt/ | grep -v /mnt/mtdblock | awk -F' ' '{print $6}'"))
for iomans in ioman:gmatch("[^\r\n]+") do 
	pth:value(iomans)
end

-- if nixio.fs.access("/etc/config/fstab") then
--         pth.titleref = luci.dispatcher.build_url("admin", "system", "fstab")
-- end

go = s:option(Flag, "guest_ok", translate("Allow guests"))
go.rmempty = false
go.enabled = "yes"
go.disabled = "no"

local sambausers = luci.sys.sambausers()
r = s:option(DynamicList, "users", translate("Allowed users"))
r.width   = "200px;"
for _, user in ipairs(sambausers) do
	r:value(user["username"], user["username"])
end
r:depends("guest_ok", "")

ro = s:option(Flag, "read_only", translate("Read-only"))
ro.rmempty = false
ro.enabled = "yes"
ro.disabled = "no"

-- cm = s:option(Value, "create_mask", translate("Create mask"))
-- cm.rmempty = true
-- cm.size = 4
-- 
-- dm = s:option(Value, "dir_mask", translate("Directory mask"))
-- dm.rmempty = true
-- dm.size = 4

return m
