--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2008-2011 Jo-Philipp Wich <xm@subsignal.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: ifaces.lua 7717 2011-10-13 16:26:59Z jow $
]]--
local m, s, o

local fs = require "nixio.fs"
local ut = require "luci.util"
local nw = require "luci.model.network"
local fw = require "luci.model.firewall"
local has_dnsmasq  = fs.access("/etc/config/dhcp")
local dsp = require "luci.dispatcher"

arg[1] = "lan"

m = Map("network", translate("Step - LAN"), translate("Here we will setup the basic settings of a typical LAN configuration. The wizard will cover 2 basic configurations: static IP address LAN and DHCP client."))
m:chain("wireless")

m.wizStep = 3
if m:formvalue("cbid.network._wired._next") then
	x = uci.cursor()
	x:set("system", "wizard", "1")
	x:commit("system")
	luci.http.redirect(luci.dispatcher.build_url("admin/status"))
	return
end
nw.init(m.uci)

local net = nw:get_network(arg[1])
local function backup_ifnames(is_bridge)
	if not net:is_floating() and not m:get(net:name(), "_orig_ifname") then
		local ifcs = net:get_interfaces() or { net:get_interface() }
		if ifcs then
			local _, ifn
			local ifns = { }
			for _, ifn in ipairs(ifcs) do
				ifns[#ifns+1] = ifn:name()
			end
			if #ifns > 0 then
				m:set(net:name(), "_orig_ifname", table.concat(ifns, " "))
				m:set(net:name(), "_orig_bridge", tostring(net:is_bridge()))
			end
		end
	end
end

-- redirect to overview page if network does not exist anymore (e.g. after a revert)
if not net then
	luci.http.redirect(luci.dispatcher.build_url("admin/network/network"))
	return
end

-- protocol switch was requested, rebuild interface config and reload page
if m:formvalue("cbid.network.%s._switch" % net:name()) then
	-- get new protocol
	local ptype = m:formvalue("cbid.network.%s.proto" % net:name()) or "-"
	local proto = nw:get_protocol(ptype, net:name())
	if proto then
		-- backup default
		backup_ifnames()

		-- if current proto is not floating and target proto is not floating,
		-- then attempt to retain the ifnames
		--error(net:proto() .. " > " .. proto:proto())
		if not net:is_floating() and not proto:is_floating() then
			-- if old proto is a bridge and new proto not, then clip the
			-- interface list to the first ifname only
			if net:is_bridge() and proto:is_virtual() then
				local _, ifn
				local first = true
				for _, ifn in ipairs(net:get_interfaces() or { net:get_interface() }) do
					if first then
						first = false
					else
						net:del_interface(ifn)
					end
				end
				m:del(net:name(), "type")
			end

		-- if the current proto is floating, the target proto not floating,
		-- then attempt to restore ifnames from backup
		elseif net:is_floating() and not proto:is_floating() then
			-- if we have backup data, then re-add all orphaned interfaces
			-- from it and restore the bridge choice
			local br = (m:get(net:name(), "_orig_bridge") == "true")
			local ifn
			local ifns = { }
			for ifn in ut.imatch(m:get(net:name(), "_orig_ifname")) do
				ifn = nw:get_interface(ifn)
				if ifn and not ifn:get_network() then
					proto:add_interface(ifn)
					if not br then
						break
					end
				end
			end
			if br then
				m:set(net:name(), "type", "bridge")
			end

		-- in all other cases clear the ifnames
		else
			local _, ifc
			for _, ifc in ipairs(net:get_interfaces() or { net:get_interface() }) do
				net:del_interface(ifc)
			end
			m:del(net:name(), "type")
		end

		-- clear options
		local k, v
		for k, v in pairs(m:get(net:name())) do
			if k:sub(1,1) ~= "." and
			   k ~= "type" and
			   k ~= "ifname" and
			   k ~= "_orig_ifname" and
			   k ~= "_orig_bridge"
			then
				m:del(net:name(), k)
			end
		end

		-- set proto
		m:set(net:name(), "proto", proto:proto())
		m.uci:save("network")
		m.uci:save("wireless")
		m.uci:commit("network")
		m.uci:commit("wireless")

		-- reload page
		luci.http.redirect(luci.dispatcher.build_url("admin/system/wizard/step-lan"))
		return
	end
end

local ifc = net:get_interface()

s = m:section(NamedSection, arg[1], "interface", translate("General Configuration"))
s.addremove = false

local thisIsAWizard = true
local isLan = true

	ipaddr = s:option(Value, "ipaddr", translate("IP address"), translate("Address that the router uses on the LAN network"))
	ipaddr.datatype = "ip4addr"
	netmask = s:option(Value, "netmask", translate("Netmask"), translate("A mask used to define how large the LAN network is"))
	netmask.datatype = "ip4addr"

local includeDHCP
	includeDHCP = true
	m2 = Map("dhcp", "", "")

	local has_section = false

	m2.uci:foreach("dhcp", "dhcp", function(s)
		if s.interface == arg[1] then
			has_section = true
			return false
		end
	end)

	if not has_section then
		s = m2:section(TypedSection, "dhcp", translate("DHCP Server"))
		s.anonymous   = true
		s.cfgsections = function() return { "_enable" } end
		x = s:option(Button, "_enable")
		x.title      = translate("No DHCP Server configured for this interface")
		x.inputtitle = translate("Setup DHCP Server")
		x.inputstyle = "apply"
	else
		igs = s:option(Flag, "igs", translate("Enable DHCP"), translate("This check box enable DHCP server functionality"))
		igs.rmempty = false
		function igs.cfgvalue(self, section)
			ivalue = m.uci:get("dhcp", section, "ignore")
			if ivalue == "1" then
				icval ="0"
			else
				icval ="1"
			end
			return icval
		end
		function igs.write(self, section, value)
			if value == "0" then
				m.uci:set("dhcp", section, "ignore", "1")
			else
				m.uci:delete("dhcp", section, "ignore")
			end
			m.uci:save("dhcp")
		end

		local start = s:option(Value, "start", translate("Start"), translate("Lowest leased address as offset from the network address."))
		start.datatype = "or(uinteger,ip4addr)"
		start.default = "100"
		function start.cfgvalue(self, section)
			ivalue = m.uci:get("dhcp", section, "start")
			return ivalue
		end
		function start.write(self, section, value)
			m.uci:set("dhcp", section, "start", value)
			m.uci:save("dhcp")
		end

		local limit = s:option(Value, "limit", translate("Limit"), translate("Maximum number of leased addresses."))
		limit.datatype = "uinteger"
		limit.default = "150"
		function limit.cfgvalue(self, section)
			ivalue = m.uci:get("dhcp", section, "limit")
			return ivalue
		end
		function limit.write(self, section, value)
			m.uci:set("dhcp", section, "limit", value)
			m.uci:save("dhcp")
		end

		local ltime = s:option(Value, "leasetime", translate("Lease time"),translate("Expiry time of leased addresses, minimum is 2 Minutes (<code>2m</code>)."))
		ltime.rmempty = true
		ltime.default = "12h"
		function ltime.cfgvalue(self, section)
			leasetime = m.uci:get("dhcp", section, "leasetime")
			return leasetime
		end
		function ltime.write(self, section, value)
			m.uci:set("dhcp", section, "leasetime", value)
			m.uci:save("dhcp")
		end
	end


if m:formvalue("cbi.wizard.skip") then
	luci.http.redirect(luci.dispatcher.build_url("/admin/status/overview"))
end

function m.on_after_save()
	if m:formvalue("cbi.wizard.next") then
		x = uci.cursor()
		x:commit("network")
		local oldip= m.uci:get("network", "lan", "ipaddr")
		m.uci:commit("wireless")
		m.uci:commit("dhcp")
		newip= m:formvalue("cbid.network.lan.ipaddr")
		if newip ~= oldip then
			luci.sys.call("/etc/init.d/network restart >/dev/null 2>/dev/null")
		end
		luci.http.redirect(luci.dispatcher.build_url("admin/system/wizard/step-wifi"))
	end
end

if includeDHCP then
	return m, m2
else
	return m
end
