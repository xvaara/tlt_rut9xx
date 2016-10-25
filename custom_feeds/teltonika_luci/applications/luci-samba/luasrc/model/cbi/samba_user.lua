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


m = Map("samba", translate("Samba users"))
m.pageaction=false
local sambausers = luci.sys.sambausers()

s = m:section(Table, sambausers, translate("Users"))
s.addremove = true
s.anonymous = true
s.sortable  = false
s.template = "cbi/tblsection"
s.template_addremove = "samba/cbi_addusers"


s:option(DummyValue, "username", translate("Username"))

function m.parse(self, ...)

	Map.parse(self, ...)
	local sobj
	local sids
	for _, sobj in ipairs(self.children) do		
		if utl.instanceof(sobj, NamedSection) then
			sids = { sobj.section }
		elseif utl.instanceof(sobj, TypedSection) then
			sids = sobj:cfgsections()
		elseif utl.instanceof(sobj, Table) then
			-- sids--data table length
			sids = sobj:cfgsections()
			-- sids5 --data table
			sids2 = { sobj.data }
			break
		end
	end
	local delButtonFormString = "cbi.rts.table."
	for _, num in ipairs(sids) do
		if luci.http.formvalue(delButtonFormString .. num) then
			luci.sys.call("deluser ".. sids2[1][num]["username"] ..";")
			luci.sys.call("smbpasswd -x ".. sids2[1][num]["username"] .."")
			luci.http.redirect(luci.dispatcher.build_url("admin/services/samba/user"))
		end
	end
	
end


return m
