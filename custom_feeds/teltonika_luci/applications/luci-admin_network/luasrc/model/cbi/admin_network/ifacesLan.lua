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

local fs = require "nixio.fs"
local ut = require "luci.util"
local nw = require "luci.model.network"
local fw = require "luci.model.firewall"
local sys = require "luci.sys"
local uci = require("uci").cursor()
local ipv6_enable=uci:get("system", "ipv6", "enable")
local VLAN = false
arg[1] = arg[1] or "lan"
if arg[2] and arg[2]=="vlan" then
	VLAN = true
end
--arg[1] =

local isWan, isLan

local bridge_mode = uci:get("network", "ppp", "method")

if bridge_mode and bridge_mode == "bridge" then
	arg[1] = "lan2"
end

if arg[1] == "wan" then
	isWan = true
elseif arg[1] == "lan" then
	isLan = true
else
	-- Insert handling for unarguemented access
end

local has_dnsmasq  = fs.access("/etc/config/dhcp")
local has_firewall = fs.access("/etc/config/firewall")
local deathTrap = { }
if VLAN then
	name = arg[1]:gsub("^%l", string.upper)
	m = Map("network", translatef("LAN Name: %s", name) , translate(""))
else
	m = Map("network", translate("LAN") , translate(""))
end
m:chain("wireless")

if has_firewall then
	m:chain("firewall")
end

nw.init(m.uci)
fw.init(m.uci)

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
local function debug(string, ...)
	luci.sys.call(string.format("/usr/bin/logger -t Webui \"%s\"", string.format(string, ...)))
end

-- redirect to overview page if network does not exist anymore (e.g. after a revert)
if not net then
	luci.http.redirect(luci.dispatcher.build_url("admin/status/overview"))
	return
end

-- dhcp setup was requested, create section and reload page
if m:formvalue("cbid.dhcp._enable._enable") then
	m.uci:section("dhcp", "dhcp", nil, {
		interface = arg[1],
		start     = "100",
		limit     = "150",
		leasetime = "12h"
	})

	m.uci:save("dhcp")
	if VLAN then
		luci.http.redirect(luci.dispatcher.build_url("admin/network/vlan/lan/" .. arg[1] .. "/vlan"))
	else
		luci.http.redirect(luci.dispatcher.build_url("admin/network/lan"))
	end
	return
end

local ifc = net:get_interface()
local ifcName = ifc:name()

local is3G
if ifcName == "usb0" then
	is3G = true
else
	is3G = false
end

-- Premtively create mode switch section so it would stay on top --
if isWan then
	sModeSwitch = m:section(NamedSection, arg[1], "interface", translate("Configuration"))
	sModeSwitch.addremove = false
end

-- Bac to normal work --
s = m:section(NamedSection, arg[1], "interface", translate("Configuration"))
s.addremove = false

s:tab("general",  translate("General Setup"))
s:tab("advanced", translate("Advanced Settings"))
s:tab("physical", translate("Physical Settings"))

if has_firewall then
	s:tab("firewall", translate("Firewall Settings"))
end

-- Dummy dependency so the button would stay hidden when only one protocol is included --

if isWan then
	if not net:is_virtual() then
		stp = sModeSwitch:option(Flag, "stp", translate("Enable STP"),
			translate("Enables the Spanning Tree Protocol on this bridge")) -- changed from s to sModeSwitch
		stp:depends("type", "bridge")
		stp.rmempty = true
	end

	if not net:is_floating() then
		ifname_single = sModeSwitch:option(Value, "ifname_single", translate("Interface")) -- changed from s to sModeSwitch
		ifname_single.nocreate = false -- remove the ability for the user to create a custom interface
		ifname_single.template = "cbi/network_ifacelist"
		ifname_single.widget = "radio"
		ifname_single.nobridges = true
		ifname_single.rmempty = false
		ifname_single.network = arg[1]
		ifname_single:depends("type", "")

		function ifname_single.cfgvalue(self, s)
			-- let the template figure out the related ifaces through the network model
			return nil
		end

		function ifname_single.write(self, s, val)
			local i
			local new_ifs = { }
			local old_ifs = { }

			for _, i in ipairs(net:get_interfaces() or { net:get_interface() }) do
				old_ifs[#old_ifs+1] = i:name()
			end

			for i in ut.imatch(val) do
				new_ifs[#new_ifs+1] = i

				-- if this is not a bridge, only assign first interface
				if self.option == "ifname_single" then
					break
				end
			end

			table.sort(old_ifs)
			table.sort(new_ifs)

			for i = 1, math.max(#old_ifs, #new_ifs) do
				if old_ifs[i] ~= new_ifs[i] then
					backup_ifnames()
					for i = 1, #old_ifs do
						net:del_interface(old_ifs[i])
					end
					for i = 1, #new_ifs do
						net:add_interface(new_ifs[i])
					end
					break
				end
			end
		end
	end

	if not net:is_virtual() then
		--luci.sys.call("echo \"iface.lua: not is_virtual(second) trpped!\" >> /tmp/log.log")
		ifname_multi = sModeSwitch:option(Value, "ifname_multi", translate("Interface")) -- changed from s to sModeSwitch
		ifname_multi.template = "cbi/network_ifacelist"
		ifname_multi.nobridges = true
		ifname_multi.rmempty = false
		ifname_multi.network = arg[1]
		ifname_multi.widget = "checkbox"
		ifname_multi:depends("type", "bridge")
		ifname_multi.cfgvalue = ifname_single.cfgvalue
		ifname_multi.write = ifname_single.write
	end

	local ifaceSwitch

	local i_switch

	i_switch = sModeSwitch:option(Button, "_modeSwitch")
	i_switch.title      = translate("Really switch modes?")
	i_switch.inputtitle = translate("Switch mode")
	i_switch.inputstyle = "apply"
end

if m:formvalue("cbid.network.wan._modeSwitch") then
	local newInterface = m:formvalue("cbid.network.wan.ifname_single")
	--luci.sys.call("echo \"ifaces.lua: modeSwitchButton: ifName: "..newInterface.."\" >> /tmp/log.log")
	if newInterface == "usb0" then
		is3G = true
	end
	if (newInterface == "eth1" or newInterface == "usb0") and net:proto() == "static" then
		m:set("wan", "ifname", newInterface)
	-- initiate protocol switch to dhcp
		local ptype = "dhcp"
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

			-- reload page
			luci.http.redirect(luci.dispatcher.build_url("admin/network/lan"))
			return
		end
	else
		m:set("wan", "ifname", newInterface)
		m.uci:save("network")
		m.uci:save("wireless")
		luci.http.redirect(luci.dispatcher.build_url("admin/network/lan"))
		return
	end
end

local isLan = true

local form, ferr = loadfile(
	ut.libpath() .. "/model/cbi/admin_network/proto_static.lua" )

if not form then
	s:taboption("general", DummyValue, "_error",
		translate("Missing protocol extension for proto %q" % net:proto())
	).value = ferr
else
	setfenv(form, getfenv(1))(m, s, net, false, isLan)
end


local _, field
for _, field in ipairs(s.children) do
	if field ~= st and field ~= p and field ~= p_install and field ~= p_switch then
		if next(field.deps) then
			local _, dep
			for _, dep in ipairs(field.deps) do
				dep.deps.proto = net:proto()
			end
		else
			--field:depends("proto", net:proto())
		end
	end
end

--
-- Display 3g configuration
--

local m3g, s3g, o3g

if isWan and is3G then
	m3g = Map("network_3g", translate("Mobile Configuration"),
		translate("Here you can configure your Mobile settings."))
	m3g.addremove = false
	s3g = m3g:section(NamedSection, "userConf", "service3g", translate("Mobile Configuration"));
	s3g.addremove = false



	o3g = s3g:option(Flag, "enabled", "Enabled")

	o3g.enabled  = "1"
	o3g.disabled = "0"
	o3g.default  = o3g.enabled

	o3g = s3g:option(ListValue, "auth", translate("Mobile authentication method"), translate("Select preferred mobile authentication method"))

	o3g.default = "chap"
	o3g:value("chap", translate("CHAP"))
	o3g:value("pap", translate("PAP"))


	o3g = s3g:option(Value, "APN", translate("APN"), translate("APN (Access Point Name) is a name of gateway between mobile network and public Internet"))


	o3g = s3g:option(Value, "Username", translate("Username"), translate("Type your username"))

	o3g = s3g:option(Value, "Password", translate("Password"), translate("Type your password"))
	o3g.password = true;

	o3g = s3g:option(Value, "PIN", translate("PIN number"), translate("Type your PIN number"))
	o3g.datatype = "range(0,9999)"
end

--
-- Display IP Aliases
--
m3 = Map("network")
local ipaliases_s2, ipaliases_ip, ipaliases_nm, ipaliases_gw, ipaliases_ip6, ipaliases_gw6, ipaliases_bcast, ipaliases_dns

ipaliases_s2 = m3:section(TypedSection, "alias", translate("IP Aliases"), translate(" "))
ipaliases_s2.addremove = true
ipaliases_s2.anonymous = true
	ipaliases_s2.template = "cbi/iptsection"
	ipaliases_s2.novaluetext = "There are no IP aliases created yet"


ipaliases_s2:depends("interface", "lan")
ipaliases_s2.defaults.interface = "lan"

ipaliases_s2:tab("general", translate("General Setup"))
ipaliases_s2.defaults.proto = "static"

ipaliases_ip = ipaliases_s2:taboption("general", Value, "ipaddr", translate("IP Address"), translate("Address that the router uses on the LAN (Local Area Network)"))
ipaliases_ip.optional = true
ipaliases_ip.datatype = "ip4addr"

ipaliases_nm = ipaliases_s2:taboption("general", Value, "netmask", translate("Netmask"), translate("A mask used to define how large the WAN (Wide Area Network) is"))
ipaliases_nm.optional = true
ipaliases_nm.datatype = "ip4addr"
ipaliases_nm:value("255.255.255.0")
ipaliases_nm:value("255.255.0.0")
ipaliases_nm:value("255.0.0.0")
ipaliases_nm.default = "255.255.255.0"

ipaliases_gw = ipaliases_s2:taboption("general", Value, "gateway", translate("Gateway"), translate("A route used when IP address does not mach any other route"))
ipaliases_gw.optional = true
ipaliases_gw.datatype = "ip4addr"

if has_ipv6 then
	ipaliases_s2:tab("ipv6", translate("IPv6 Setup"))

	ipaliases_ip6 = ipaliases_s2:taboption("ipv6", Value, "ip6addr", translate("IPv6-Address"), translate("Address that the router uses on the LAN (Local Area Network). CIDR-Notation: address/prefix"))
	ipaliases_ip6.optional = true
	ipaliases_ip6.datatype = "ip6addr"

	ipaliases_gw6 = ipaliases_s2:taboption("ipv6", Value, "ip6gw", translate("IPv6-Gateway"), translate("A route used then IP address does not mach any other route"))
	ipaliases_gw6.optional = true
	ipaliases_gw6.datatype = "ip6addr"
end

ipaliases_s2:tab("advanced", translate("Advanced Settings"))

ipaliases_bcast = ipaliases_s2:taboption("advanced", Value, "bcast", translate("IP Broadcast"), translate("A logical address at which all devices are enabled to receive datagrams"))
ipaliases_bcast.optional = true
ipaliases_bcast.datatype = "ip4addr"

ipaliases_dns = ipaliases_s2:taboption("advanced", Value, "dns", translate("DNS Server"), translate("DNS (Domain Name System) server address"))
ipaliases_dns.optional = true
ipaliases_dns.datatype = "ip4addr"

--
-- Display DNS settings if dnsmasq is available
--

if has_dnsmasq and net:proto() == "static" and ( not bridge_mode or bridge_mode ~= "bridge") then
	includeDHCP = true
	m2 = Map("dhcp", "", "")

	local has_section = false

	m2.uci:foreach("dhcp", "dhcp", function(s)
		if s.interface then
		end
		if s.interface == arg[1] then
			has_section = true
			return false
		end
	end)


	if not has_section then

		s = m2:section(TypedSection, "dhcp", translate("DHCP Server"), translate("Specifies DHCP server\\'s IP address, which directs any requests into server"))
		s.anonymous   = true
		s.cfgsections = function() return { "_enable" } end

		x = s:option(Button, "_enable")
		x.title      = translate("No DHCP Server configured for this interface")
		x.inputtitle = translate("Setup DHCP Server")
		x.inputstyle = "apply"

	else

		s = m2:section(TypedSection, "dhcp", translate("DHCP Server"))
		s.addremove = false
		s.anonymous = true
		s:tab("general",  translate("General Setup"))
		s:tab("advanced", translate("Advanced Settings"))

		function s.filter(self, section)
			return m2.uci:get("dhcp", section, "interface") == arg[1]
		end

		local ignore = s:taboption("general", ListValue, "ignore",
			translate("DHCP"), translate("Manage DHCP server"))
		ignore:value("enable", translate("Enable"))
		ignore:value("disable", translate("Disable"))
		ignore:value("relay", translate("DHCP relay"))

		function ignore.write(self, section, value)

			local fval

			if value == "disable" then
				m.uci:set("dhcp", section, "ignore", "1")
				m.uci:set("dhcp", "dhcp_relay", "enabled", "0")
			elseif value == "relay" then
				m.uci:set("dhcp", "dhcp_relay", "enabled", "1")
				m.uci:set("dhcp", section, "ignore", "1")
				fval = "1"
			elseif value == "enable" then
				m.uci:delete("dhcp", section, "ignore")
				m.uci:set("dhcp", "dhcp_relay", "enabled", "0")
			end
			m.uci:save("dhcp")
			m.uci:commit("dhcp")

			-- stop this function being called twice
			if not deathTrap[2] then deathTrap[2] = true
			else return end

			if not fval then
				fval = "0"
			else
				fval = ""
			end

			local fwRuleInstName
			local needsPortUpdate = false
			m2.uci:foreach("firewall", "rule", function(s)
					if s.name == "Allow-DHCP-Relay" then
						fwRuleInstName = s[".name"]
						m2.uci:set("firewall", fwRuleInstName, "enabled", fval)
						m2.uci:save("firewall")
						m2.uci.commit("firewall")
					end
				end)
		end

		function ignore.cfgvalue(self, section)
			local val

			val = m.uci:get("dhcp", section, "ignore")

			if val == "1" then
				local val_relay = m2.uci:get("dhcp", "dhcp_relay", "enabled")

				if val_relay == "1" then
					return "relay"
				else
					return "disable"
				end
			else
				return "enable"
			end
		end

		local server = s:taboption("general", Value, "sever", translate("DHCP server"), translate("Specifies DHCP server\\'s IP address, which directs any requests into server"))
		server.optional = true
		server.datatype = "ip4addr"
		server:depends("ignore", "relay")


		function server.write(self, section, value)
			m.uci:set("dhcp", "dhcp_relay", "server", value)
			m.uci:save("dhcp")
			m.uci:commit("dhcp")
		end

		function server.cfgvalue(self, section)
			local val = m.uci:get("dhcp", "dhcp_relay", "server")
			return val
		end

		if tonumber(ipv6_enable)==1 then
			local ra = s:taboption("general", Flag, "enable_ra", translate("DHCP IPv6"))
				ra:depends("ignore", "enable")
		else
			sys.call("uci delete -q dhcp.lan.enable_ra")
		end

		local start = s:taboption("general", Value, "start", translate("Start"),
			translate("Lowest leased address as offset from the network address"))
		start.optional = true
		start.datatype = "or(uinteger,ip4addr)"
		start.default = "100"

		local limit = s:taboption("general", Value, "limit", translate("Limit"),
			translate("Maximum number of leased addresses"))
		limit.optional = true
		limit.datatype = "uinteger"
		limit.default = "150"

		local ltime = s:taboption("general", Value, "time", translate("Lease time"), translate("Expire time for leased addresses. Minimum value is 2 minutes"))
		ltime.rmempty = true
		ltime.displayInline = true
		ltime.datatype = "integer"
		ltime.default = "12"
		function ltime.cfgvalue(self, section)
			local value = uci:get("dhcp", section, "leasetime")
			local val = value:match("%d+")
			return val
		end
		function ltime.write(self, section, value)
			local letter = m:formvalue("cbid.dhcp.".. section ..".letter") or ""
			lease = value..""..letter
			
			uci:set("dhcp", section, "time", value)
			uci:set("dhcp", section, "letter", letter)
			uci:set("dhcp", section, "leasetime", lease)
			uci:commit("dhcp")
		end

		o = s:taboption("general", ListValue, "letter", translate(""), translate(""))
		o:value("h", translate("Hours"))
		o:value("m", translate("Minutes"))
		o.displayInline = true

		function o.write(self, section, value)
			local time = m:formvalue("cbid.dhcp.".. section ..".time") or ""
			lease = time..""..value

			uci:set("dhcp", section, "time", time)
			uci:set("dhcp", section, "letter", value)
			uci:set("dhcp", section, "leasetime", lease)
			uci:commit("dhcp")
		end

		local dd = s:taboption("advanced", Flag, "dynamicdhcp",
			translate("Dynamic DHCP"),
			translate("Dynamically allocate DHCP addresses for clients. If disabled, only clients having static leases will be served"))
		dd.default = dd.enabled

		s:taboption("advanced", Flag, "force", translate("Force"),
			translate("Force DHCP on this network even if another server is detected"))

		-- XXX: is this actually useful?
		--s:taboption("advanced", Value, "name", translate("Name"),
		--	translate("Define a name for this network."))

		mask = s:taboption("advanced", Value, "netmask",
			translate("IP netmask"),
			translate("Override the netmask sent to clients. Usually it is calculated from the subnet that is served"))

		mask.optional = true
		mask.datatype = "ip4addr"

		s:taboption("advanced", DynamicList, "dhcp_option", translate("DHCP Options"),
			translate("Define additional DHCP options, for example <code>6,192.168.2.1,192.168.2.2</code> which advertises different DNS servers to clients"))

		for i, n in ipairs(s.children) do
			if n ~= ignore and n~= server then
				n:depends("ignore", "enable")
			end
		end

		sa = m2:section(TypedSection, "host", translate("Static Leases"), translate(" "))
		sa.addremove = true
		sa.anonymous = true
		sa.template = "cbi/tblsection"
		sa.novaluetext = translate("There are no static leases configurated yet")

		name = sa:option(Value, "name", translate("Hostname"))
		name.datatype = "hostname"
		name.rmempty  = true

		mac = sa:option(Value, "mac", translate("MAC address"))
		mac.datatype = "list(macaddr)"
		mac.rmempty = true

		ip = sa:option(Value, "ip", translate("IP address"))
		ip.datatype = "ip4addr"
		ip.rmempty = true

		sys.net.arptable(function(entry)
			ip:value(entry["IP address"])
			mac:value(
				entry["HW address"],
				entry["HW address"] .. " (" .. entry["IP address"] .. ")"
			)
		end)
	end

	function m.on_before_apply(self)
-- 		local let = m:formvalue("cbid.dhcp.lan.letter") or ""
-- 		local num = m:formvalue("cbid.dhcp.lan.time") or ""
-- 		sys.exec("uci set dhcp.lan.leasetime=".. num .."".. let .."; uci dhcp")
		if tonumber(ipv6_enable)==1 then
			num = m:formvalue("cbid.network.lan.ip6addr") or ""
			let = m:formvalue("cbid.network.lan._ip6pr") or "64"
			sys.call("uci set -q network.lan.ip6addr=".. num .."/".. let .."; uci commit network")
		end
	end
end

function m.on_commit(self)
	sys.call("(sleep 10; /sbin/wifi up >/dev/null 2>&1) &")
end

--[[ su parametru m.wizStep = 5 puslapis nuolat persikrauna (kas 10s mazdaug)
local ipaddr = luci.http.getenv("REMOTE_ADDR")
local ipaddr_eth = ut.trim(sys.exec(". /lib/teltonika-functions.sh; check_this_ip " .. ipaddr))
if ipaddr_eth == "LAN" then
	m.wizStep = 5
end
]]--
	if VLAN then
		m.redirect= luci.dispatcher.build_url("admin/network/vlan/lan")
	end

if isWan and is3G then
	--luci.sys.call("echo \"ifaces.lua: [and being returned...]\" >> /tmp/log.log")
	return m, m3g, m2
else
	return m, m2, m3
end
