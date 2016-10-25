--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: openvpn.lua 5448 2009-10-31 15:54:11Z jow $
]]--

local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()
local util = require ("luci.util")

local CFG_MAP = "openvpn"
local CFG_SEC = "openvpn"

local function cecho(string)
	luci.sys.call("echo \"openvpn: " .. string .. "\" >> /tmp/log.log")
end

local m ,s, o

m = Map(CFG_MAP, translate("OpenVPN"))
m.spec_dir = nil
--m.pageaction = false

s = m:section( TypedSection, CFG_SEC, translate("OpenVPN Configuration"), translate("") )
s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection"
s.template_addremove = "openvpn/vpn_add_rem"
s.addremoveAdd = true
s.novaluetext = translate("There are no openVPN configurations yet")

uci:foreach(CFG_MAP, CFG_SEC, function(sec)
	-- Entry signifies that there already is a section, therefore we will disable the ability to add or remove another section
	s.addremoveAdd = false
end)

s.extedit = luci.dispatcher.build_url("admin", "services", "vpn", "openvpn-tlt", "%s")

local name = s:option( DummyValue, "_name", translate("Tunnel name"), translate("Name of the tunnel. Used for easier tunnels management purpose only"))

function name.cfgvalue(self, section)
	return section:gsub("^%l", string.upper) or "Unknown"
end

local dev = s:option( DummyValue, "dev", translate("TUN/TAP"), translate("Virtual VPN interface type"))

function dev.cfgvalue(self, section)
	local val = AbstractValue.cfgvalue(self, section)
	return val and val:gsub("^%l", string.upper)  or "-"
end


local proto = s:option( DummyValue, "proto", translate("Protocol"), translate("A transport protocol used for connection"))

function proto.cfgvalue(self, section)
	local val = AbstractValue.cfgvalue(self, section)
	return val and string.upper(val) or "-"
end

local port = s:option( DummyValue, "port", translate("Port"), translate("TCP or UDP port number used for connection"))

function port.cfgvalue(self, section)
	local val = AbstractValue.cfgvalue(self, section)
	return val or "-"
end

status = s:option(Flag, "enable", translate("Enable"), translate("Make a rule active/inactive"))

--[[
local status = s:option( DummyValue, "enable", translate("Enabled"), translate("Indicates whether a configuration is active or not"))

function status.cfgvalue(self, section)
	local val = AbstractValue.cfgvalue(self, section)
	if val == "1" then
		return translate("Yes")
	else
		return translate("No")
	end
end
--]]
-------------
function s.validate(self, value)
	if value == "teltonika_auth_service" or value == "teltonika_management_service" then
		return nil
	end
	return value
end
-------------
function s.parse(self, section)
-- 	mix.echo("OpenVPN sekcijos parsinimas")
	local cfgname = luci.http.formvalue("cbid." .. self.config .. "." .. self.sectiontype .. ".name") or ""
	local webrole = luci.http.formvalue("cbid." .. self.config .. "." .. self.sectiontype .. ".role") or ""

	-- 'Delete' button does not commit uci changes. So we will do it manually. And here another problem
	-- occurs: 'Delete' button has very long name including vpn instance name and I don't know that
	-- instance name. So I will scan through uci config and try to find out if such instance name exists
	-- as form element. FIXME investigate if another more inteligent approach is available here (O_o)
	local delButtonFormString = "cbi.rts." .. self.config .. "."
	local delButtonPress = false
	local configName
-- 	local uFound
	local existname = false
	uci:foreach("openvpn", "openvpn", function(x)
		if not delButtonPress then
			configName = x[".name"] or ""
			if luci.http.formvalue(delButtonFormString .. configName) then
				delButtonPress = true
			end
		end
-- 		if configName ~= "teltonika_auth_service" and configName ~= "teltonika_management_service" then
-- 			uFound = true
-- 		end

		newname= webrole.."_"..cfgname
		if configName == newname then
			existname = true
		end
	end)

	if delButtonPress then
 		uci.delete("openvpn", configName)
 		uci.delete("overview","show","open_vpn_"..configName)
 		uci.save("openvpn")
 		uci.save("overview")
 		luci.sys.call("/etc/init.d/openvpn restart >/dev/null")
		-- delete buttons is pressed, don't execute function 'openvpn_new'
		cfgname = false
		uci.commit("openvpn")
		uci.commit("overview")
	end

	if cfgname and cfgname ~= '' then
		--if not uFound then
		openvpn_new(self, cfgname, existname)
		--else
		--	m.message = translate("Only one VPN instance is allowed.")
		--	return
		--end
	end
	TypedSection.parse( self, section )
	uci.commit("openvpn")
end

function openvpn_new(self,name, exist)
	local t = {}
	local role = luci.http.formvalue("cbid." .. self.config .. "." .. self.sectiontype .. ".role"
	)
	local num_vpn = util.trim(sys.exec("cat /etc/config/openvpn | grep 'config openvpn' -c")) or "1"

	if tonumber(num_vpn) > 5 then
		m.message = translatef("err: Maximum OpenVPN instance count has been reached")

	elseif exist then
		name = (role.."_"..name)
		m.message = translatef("err: Name %s already exists.", name)

	elseif name and #name > 0 and role then

		if not (string.find(name, "[%c?%p?%s?]+") == nil) then
			m.message = translate("err: Only alphanumeric characters are allowed.")
		else
			namew = name
			name = (role.."_"..name)
			t["persist_key"] = "1"
			t["persist_tun"] = "1"
			t["verb"] = "5"
			t["port"] = "1194"
			if role == "server" then
				t["dev"] = "tun_s_"..namew
			else
				t["dev"] = "tun_c_"..namew
			end
			t["proto"] = "udp"

			if role == "server" then
				t["status"] = "/tmp/openvpn-status_"..name..".log"
				t["keepalive"] = "10 120"
			end

			if role == "client" then
				t["nobind"] = "1"
			end

			uci:section("openvpn", "openvpn", name,t)
			uci:save("openvpn")
			uci.commit("openvpn")
			m.message = translate("scs:New OpenVPN instance was created successfully. Configure it now")
		end
	else
		m.message = translate("err: To create a new OpenVPN instance it's name has to be entered!")
	end
end

local restart = "false"
save = m:formvalue("cbi.apply")
if save then
	--Delete all usr_enable from openvpn config
	m.uci:foreach("openvpn", "openvpn", function(s)
		open_vpn = s[".name"] or ""
		if open_vpn ~= "teltonika_auth_service" then
			vpnEnable = m:formvalue("cbid.openvpn." .. open_vpn .. ".enable") or "0"
			open_vpn_enable = s.enable or "0"
			if open_vpn_enable ~= vpnEnable then
				restart = "true"
				name = util.trim(util.split( open_vpn, "_")[1])
				m.uci:foreach("openvpn", "openvpn", function(a)
					name2 = util.trim(util.split( a[".name"], "_")[1])
					open_vpn2 = a[".name"] or ""
					if name2 ~= "teltonika" then
						local usr_enable = a.usr_enable or ""
						if name == name2 and usr_enable == "1" then
							m.uci:delete("openvpn", open_vpn2, "usr_enable")
						end
					end
				end)
			end
		end
	end)
end

function m.on_commit(map)
	if restart == "true" then
		m.uci:save("openvpn")
		m.uci.commit("openvpn")
		sys.call("/etc/init.d/openvpn restart > /dev/null")
		sys.call("/etc/init.d/firewall restart >/dev/null")
	end
end

return m
