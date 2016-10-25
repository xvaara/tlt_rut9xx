--[[
config custom_interface '3g'
        option pin 'kazkas'
        option apn 'kazkas'
        option user 'kazkas'
        option password 'kazkas'
        option auth_mode 'chap' ARBA 'pap' (jei nerandu nieko ar kazka kita, laikau kad auth nenaudojama)
        option net_mode 'gsm' ARBA 'umts' ARBA 'auto' (prefered tinklas. jei nerandu nieko arba kazka kita laikau kad auto)
        option data_mode 'enabled' ARBA 'disabled' (ar leisti siusti duomenis. jei nera nieko ar kazkas kitas, laikau kad enabled)
]]

require "teltonika_lua_functions"
local utl = require "luci.util"
local nw = require "luci.model.network"
local sys = require "luci.sys"
local moduleVidPid = utl.trim(sys.exec("uci get system.module.vid")) .. ":" .. utl.trim(sys.exec("uci get system.module.pid"))
local moduleType = utl.trim(luci.sys.exec("uci get system.module.type"))
local m
local modulsevice = "3G"
local modulsevice2 = "0"
local dual_sim = utl.trim(luci.sys.exec("uci get hwinfo.hwinfo.dual_sim"))
Save_value = 0
local function cecho(string)
	luci.sys.call("echo \"" .. string .. "\" >> /tmp/log.log")
end

local function debug(string, ...)
	luci.sys.call(string.format("/usr/bin/logger -t Webui \"%s\"", string.format(string, ...)))
end

if moduleVidPid == "12D1:1573" or moduleVidPid == "12D1:15C1" or moduleVidPid == "12D1:15C3" then
	modulsevice = "LTE"
elseif moduleVidPid == "1BC7:1201" then
	modulsevice = "TelitLTE"
	modulsevice2 = "2"
elseif moduleVidPid == "1BC7:0036" then
	modulsevice = "TelitLTE_V2"
	modulsevice2 = "2"
elseif moduleVidPid == "1199:68C0" then
	modulsevice = "SieraLTE"
elseif moduleVidPid == "05C6:9215" then
	modulsevice = "QuectelLTE"
	modulsevice2 = "2"
end

--ismtys del telit modemu kurie nepalaiko 2g prefered ir 3g prefered pasirinkimo            
if moduleVidPid == "1BC7:0021" then --Telit He910d
	modulsevice2 = "1"
end



-- if moduleType == "3g_ppp" then
	m = Map("simcard", translate("Mobile Configuration"), translate(""))
	m.addremove = false
	nw.init(m.uci)

	s = m:section(NamedSection, "sim1", "", translate("Mobile Configuration"));
	s.template = "cbi/mobile_tabs_switch"
	s.addremove = false
	s:tab("primarytab", translate("SIM 1"))
	if dual_sim == "1" then
		s:tab("secondarytab", translate("SIM 2"))
	end

	if modulsevice == "LTE" or modulsevice == "TelitLTE" or modulsevice == "TelitLTE_V2" or modulsevice == "SieraLTE" or modulsevice == "QuectelLTE" then

		prot = s:taboption("primarytab",ListValue, "proto", translate("Connection type"), translate("An underlying agent for mobile data connection creation and management"))
		prot.javascript="mode_list_check('simcard', 'sim1', 'proto', 'method'); check_for_message('cbid.simcard.sim1.method');"
		prot.template = "cbi/lvalue_onclick"

		if modulsevice ~= "SieraLTE" then
			prot:value("3g", translate("PPP"))
		end

		if modulsevice == "LTE" then
			prot:value("ndis", translate("NDIS"))
		elseif modulsevice == "TelitLTE" or modulsevice == "SieraLTE" or modulsevice == "QuectelLTE" then
			prot:value("qmi", translate("QMI"))
		elseif modulsevice == "TelitLTE_V2" then
			prot:value("ncm", translate("NCM"))
		end

		function prot.write(self, section, value)
			if value then
				m.uci:set(self.config, section, self.option, value)
				if value == "3g" then
					m.uci:set(self.config, section, "ifname", "3g-ppp")
					m.uci:set(self.config, section, "device", "/dev/modem_data")
				elseif value == "qmi" then
					m.uci:set(self.config, section, "ifname", "wwan0")
					m.uci:set(self.config, section, "device", "/dev/cdc-wdm0")
				elseif value == "ncm" then
					m.uci:set(self.config, section, "ifname", "wwan0")
					m.uci:set(self.config, section, "device", "/dev/modem_data")
				else
					m.uci:set(self.config, section, "ifname", "eth2")
					m.uci:set(self.config, section, "device", "/dev/modem_data")
				end
				m.uci:save("simcard")
				m.uci:commit("simcard")
			end
		end

	end

	method = s:taboption("primarytab",ListValue, "method", translate("Mode"), translate("An underlying agent for mobile data connection creation and management"))
		method.template = "cbi/lvalue_onclick"
		method.javascript="check_for_message('cbid.simcard.sim1.method')"
		method:value("nat", translate("NAT"))

		if modulsevice == "LTE" or modulsevice == "TelitLTE" or modulsevice == "TelitLTE_V2" or modulsevice == "SieraLTE" or modulsevice == "QuectelLTE" then
			proto=m.uci:get("simcard", "sim1", "proto")
			if proto ~= "3g" then
				method:value("bridge", translate("Bridge"))
			end
		end

		method:value("pbridge", translate("Passthrough"))
		method.default = "nat"

		--[[function method.write(self, section, value)
			local mobile_section = get_wan_section("type", "mobile")
			if mobile_section ~= "wan" then
				if value == "pbridge" or  value == "bridge" then
					m.message = "err:Mobile is not wan"
					return nil
				end
			end
			m.uci:set(self.config, section, self.option, value)
		end]]--

		--m.message = "err:Using Bridge Mode will disable most of the router capabilities and you can access your router's settings only through its static IP address."

	o = s:taboption("primarytab",Value, "bind_mac", translate("Bind to MAC"), translate("Forward all incoming packets to specified MAC address"))
		o:depends({method = "bridge", proto = "qmi"})
		o.datatype = "macaddr"

	o = s:taboption("primarytab",Value, "apn", translate("APN"), translate("APN (Access Point Name) is a configurable network identifier used by a mobile device when connecting to a GSM carrier"))
	o = s:taboption("primarytab",Value, "pincode", translate("PIN number"), translate("SIM card\\'s PIN (Personal Identification Number) is a secret numeric password shared between a user and a system that can be used to authenticate the user"))
		o.datatype = "lengthvalidation(4,12,'^[0-9]+$')"
	o = s:taboption("primarytab",Value, "dialnumber", translate("Dialing number"), translate("Dialing number is used to establish a mobile PPP (Point-to-Point Protocol) connection. For example *99#"))
	--o.placeholder = "*99#"
	--if modulsevice == "LTE" then
	--	o:hide_deps("_method", "pppd")
	--end
	auth = s:taboption("primarytab",ListValue, "auth_mode", translate("Authentication method"), translate("Authentication method that your GSM carrier uses to authenticate new connections on it\\'s network"))
		auth:value("chap", translate("CHAP"))
		auth:value("pap", translate("PAP"))
		auth:value("none", translate("None"))
		auth.default = "none"

	o = s:taboption("primarytab",Value, "username", translate("Username"), translate("Your username that you would use to connect to your GSM carrier\\'s network"))
		o:depends("auth_mode", "chap")
		o:depends("auth_mode", "pap")

	o = s:taboption("primarytab",Value, "password", translate("Password"), translate("Your password that you would use to connect to your GSM carrier\\'s network"))
		o:depends("auth_mode", "chap")
		o:depends("auth_mode", "pap")
		o.password = true;
	o = s:taboption("primarytab",ListValue, "service", translate("Service mode"), translate("Your network\\'s preference. If your local mobile network supports GSM (2G), UMTS (3G) or LTE (4G) you can specify to which network you prefer to connect to"))
	--Huawei LTE ME909u

	o:value("gprs-only", translate("2G only"))
	if modulsevice2 == "0" then
		o:value("gprs", translate("2G preferred"))
	end

	o:value("umts-only", translate("3G only"))
	if modulsevice2 == "0" then
		o:value("umts", translate("3G preferred"))
	end

	if moduleVidPid == "12D1:1573" or moduleVidPid == "1BC7:1201" or  moduleVidPid == "12D1:15C1" or  moduleVidPid == "12D1:15C3" or modulsevice == "SieraLTE" or modulsevice == "QuectelLTE" or modulsevice == "TelitLTE_V2" then
		o:value("lte-only", translate("4G (LTE) only"))
		if modulsevice2 == "0" then
			o:value("lte", translate("4G (LTE) preferred"))
		end
		o:value("auto", translate("Automatic"))
		o.default = "lte"
	else
		o:value("auto", translate("Automatic"))

		if modulsevice2 == "0" then
			o.default = "umts"
		else
			o.default = "auto"
		end
	end

	o = s:taboption("primarytab", Flag, "roaming", translate("Deny data roaming"), translate("Deny data connection on roaming"))
	o = s:taboption("primarytab", Flag, "pdptype", translate("Use IPv4 only"), translate("Specifies the type of packet data protocol"))

	prot = s:taboption("primarytab",ListValue, "passthrough_mode", translate("DHCP mode"), translate(""))
		prot.template = "cbi/lvalue_onclick"
		prot.javascript="check_mod(this.id,'cbid.simcard.sim1.mac')"
		prot:value("static", translate("Static"))
		prot:value("dynamic", translate("Dynamic"))
		prot:value("no_dhcp", translate("No DHCP"))
		prot.default = "static"
		prot:depends("method", "pbridge")

	mac_address = s:taboption("primarytab",Value, "mac", translate("MAC Address"), translate(""))
		mac_address:depends("passthrough_mode", "static")
		mac_address.datatype = "macaddr"

	local ltime = s:taboption("primarytab", Value, "leasetime", translate("Lease time"), translate("Expire time for leased addresses. Minimum value is 2 minutes"))
		ltime.rmempty = true
		ltime.displayInline = true
		ltime.datatype = "integer"
		ltime.default = "12"
		--ltime:depends("method", "pbridge")
		ltime:depends("passthrough_mode", "static")
		ltime:depends("passthrough_mode", "dynamic")
		sim1_leasetime=utl.trim(sys.exec("uci get simcard.sim1.leasetime"))
		function ltime.cfgvalue(self, section)
			local value = sim1_leasetime
			local val = value:match("%d+")
			return val
		end
		function ltime.write(self, section, value)
		end

	o = s:taboption("primarytab", ListValue, "letter", translate(""), translate(""))
		o:value("h", translate("Hours"))
		o:value("m", translate("Minutes"))
		o.displayInline = true
		--o:depends("method", "pbridge")
		o:depends("passthrough_mode", "static")
		o:depends("passthrough_mode", "dynamic")
		function o.cfgvalue(self, section)
			local value = sim1_leasetime
			if value:find("m") then
				return "m"
			else
				return "h"
			end
		end
		function o.write(self, section, value)
		end


	if dual_sim == "1" then
		--s2 = m:section(NamedSection, "secondary", "interface", translate("Secondary SIM card"));
		--s2.addremove = false
		if modulsevice == "LTE" or modulsevice == "TelitLTE" or modulsevice == "SieraLTE" or modulsevice == "QuectelLTE" or modulsevice == "TelitLTE_V2" then
			prot = s:taboption("secondarytab",ListValue, "proto2", translate("Connection type"), translate("An underlying agent for mobile data connection creation and management"))
			prot.javascript="mode_list_check('simcard', 'sim1', 'proto2', 'method2'); check_for_message('cbid.simcard.sim1.method2');"
				if modulsevice ~= "SieraLTE" then
					prot:value("3g", translate("PPP"))
				end
				prot.template = "cbi/lvalue_onclick"
				if modulsevice == "LTE" then
					prot:value("ndis", translate("NDIS"))
				elseif modulsevice == "TelitLTE" or modulsevice == "SieraLTE" or modulsevice == "QuectelLTE" then
					prot:value("qmi", translate("QMI"))
				elseif modulsevice == "TelitLTE_V2" then
					prot:value("ncm", translate("NCM"))
				end
			function prot.cfgvalue(self, section)
				return m.uci:get("simcard", "sim2", "proto")
			end
			function prot.write(self, section, value)
			end
		end

	method2 = s:taboption("secondarytab",ListValue, "method2", translate("Mode"), translate("An underlying agent for mobile data connection creation and management"))
		method2.template = "cbi/lvalue_onclick"
		method2.javascript="check_for_message('cbid.simcard.sim1.method2')"
		method2:value("nat", translate("NAT"))

		if modulsevice == "LTE" or modulsevice == "TelitLTE" or modulsevice == "SieraLTE" or modulsevice == "QuectelLTE" or modulsevice == "TelitLTE_V2" then
			proto=m.uci:get("simcard", "sim2", "proto")
			if proto ~= "3g" then
				method2:value("bridge", translate("Bridge"))
			end
		end

		function method2.cfgvalue(self, section)
			return m.uci:get("simcard", "sim2", "method")
		end
		function method2.write(self, section, value)
		end

		method2:value("pbridge", translate("Passthrough"))
		method2.default = "nat"
		
		o2 = s:taboption("secondarytab",Value, "bind_mac2", translate("Bind to MAC"), translate("Forward all incoming packets to specified MAC address"))
		o2:depends({method2 = "bridge", proto2 = "qmi"})
		o2.datatype = "macaddr"
		function o2.write(self, section, value)
		end
		function o2.cfgvalue(self, section)
			return m.uci:get("simcard", "sim2", "bind_mac")
		end

		o2 = s:taboption("secondarytab",Value, "apn2", translate("APN"), translate("APN (Access Point Name) is a configurable network identifier used by a mobile device when connecting to a GSM carrier"))
		o2.forcewrite = true
		o2.rmempty = true
		function o2.cfgvalue(self, section)
			return m.uci:get("simcard", "sim2", "apn")
		end
		function o2.write(self, section, value)
		end
		o2 = s:taboption("secondarytab",Value, "pincode2", translate("PIN number"), translate("SIM card\\'s PIN (Personal Identification Number) is a secret numeric password shared between a user and a system that can be used to authenticate the user"))
		o2.datatype = "lengthvalidation(4,4,'^[0-9]+$')"
		function o2.cfgvalue(self, section)
			return m.uci:get("simcard", "sim2", "pincode")
		end
		function o2.write(self, section, value)
		end
		o2 = s:taboption("secondarytab",Value, "dialnumber2", translate("Dialing number"), translate("Dialing number is used to establish a mobile PPP (Point-to-Point Protocol) connection"))
		o2.default = "*99#"
		--if modulsevice == "LTE" then
		--	o2:hide_deps("_method2", "pppd")
		--end
		function o2.write()
		end
		function o2.cfgvalue(self, section)
			return m.uci:get(self.config, "sim2", "dialnumber") or ""
		end

		auth2 = s:taboption("secondarytab",ListValue, "auth_mode2", translate("Authentication method"), translate("Authentication method that your GSM carrier uses to authenticate new connections on it\\'s network"))
		auth2:value("chap", translate("CHAP"))
		auth2:value("pap", translate("PAP"))
		auth2:value("none", translate("None"))
		auth2.default = "none"
		function auth2.cfgvalue(self, section)
			return m.uci:get("simcard", "sim2", "auth_mode")
		end
		function auth2.write(self, section, value)
		end
		o2 = s:taboption("secondarytab",Value, "username2", translate("Username"), translate("Your username that you would use to connect to your GSM carrier\\'s network"))
		o2:depends("auth_mode2", "chap")
		o2:depends("auth_mode2", "pap")
		function o2.cfgvalue(self, section)
			return m.uci:get("simcard", "sim2", "username")
		end
		function o2.write(self, section, value)
		end
		o2 = s:taboption("secondarytab",Value, "password2", translate("Password"), translate("Your password that you would use to connect to your GSM carrier\\'s network"))
		o2:depends("auth_mode2", "chap")
		o2:depends("auth_mode2", "pap")
		o2.password = true;
		function o2.cfgvalue(self, section)
			return m.uci:get("simcard", "sim2", "password")
		end
		function o2.write(self, section, value)
		end
		o2 = s:taboption("secondarytab",ListValue, "service2", translate("Service mode"), translate("Your network\\'s preference. If your local mobile network supports GSM (2G), UMTS (3G) or LTE (4G) you can specify to which network you prefer to connect to"))
		--Huawei LTE ME909u

		o2:value("gprs-only", translate("2G only"))
		if modulsevice2 == "0" then
			o2:value("gprs", translate("2G preferred"))
		end
		o2:value("umts-only", translate("3G only"))
		if modulsevice2 == "0" then
			o2:value("umts", translate("3G preferred"))
		end

		if moduleVidPid == "12D1:1573" or moduleVidPid == "1BC7:1201" or  moduleVidPid == "12D1:15C1" or moduleVidPid == "12D1:15C3" or modulsevice == "SieraLTE" or modulsevice == "QuectelLTE" or modulsevice == "TelitLTE_V2" then
			o2:value("lte-only", translate("4G (LTE) only"))
			if modulsevice2 == "0" then
				o2:value("lte", translate("4G (LTE) preferred"))
			end
			o2:value("auto", translate("Automatic"))
			o2.default = "lte"
		else
			o2:value("auto", translate("Automatic"))
			if modulsevice2 == "0" then
				o2.default = "umts"
			else
				o2.default = "auto"
			end
		end
		
		function o2.cfgvalue(self, section)
			return m.uci:get("simcard", "sim2", "service")
		end
		
		function o2.write(self, section, value)
		end

		o2 = s:taboption("secondarytab", Flag, "roaming2", translate("Deny data roaming"), translate("Deny data connection on roaming"))
		function o2.cfgvalue(self, section)
			return m.uci:get("simcard", "sim2", "roaming")
		end
		o2 = s:taboption("secondarytab", Flag, "pdptype2", translate("Use IPv4 only"), translate("Specifies the type of packet data protocol"))
		function o2.cfgvalue(self, section)
			return m.uci:get("simcard", "sim2", "pdptype")
		end
	
		prot = s:taboption("secondarytab",ListValue, "passthrough_mode2", translate("DHCP mode"), translate(""))
			prot:value("static", translate("Static"))
			prot:value("dynamic", translate("Dynamic"))
			prot:value("no_dhcp", translate("No DHCP"))
			prot:depends("method2", "pbridge")
			prot.default = "static"

		o = s:taboption("secondarytab",Value, "mac2", translate("MAC Address"), translate(""))
			o:depends("passthrough_mode2", "static")
			o.datatype = "macaddr"
			function o.write(self, section, value)
			end
			function o.cfgvalue(self, section)
				return m.uci:get("simcard", "sim2", "mac")
			end

		local ltime = s:taboption("secondarytab", Value, "leasetime2", translate("Lease time"), translate("Expire time for leased addresses. Minimum value is 2 minutes"))
			ltime.rmempty = true
			ltime.displayInline = true
			ltime.datatype = "integer"
			ltime.default = "12"
			--ltime:depends("method2", "pbridge")
			ltime:depends("passthrough_mode2", "static")
			ltime:depends("passthrough_mode2", "dynamic")
			sim1_leasetime=utl.trim(sys.exec("uci get simcard.sim2.leasetime"))
			function ltime.cfgvalue(self, section)
				local value = sim1_leasetime
				local val = value:match("%d+")
				return val
			end
			function ltime.write(self, section, value)
			end

		o = s:taboption("secondarytab", ListValue, "letter2", translate(""), translate(""))
		o:value("h", translate("Hours"))
		o:value("m", translate("Minutes"))
		o.displayInline = true
		--o:depends("method2", "pbridge")
		o:depends("passthrough_mode2", "static")
		o:depends("passthrough_mode2", "dynamic")
		function o.cfgvalue(self, section)
			local value = sim1_leasetime
			if value:find("m") then
				return "m"
			else
				return "h"
			end
		end
		function o.write(self, section, value)
		end
	end
	
	s1 = m:section(NamedSection, "ppp", "interface", translate("Mobile Data On Demand"));
	s1.addremove = false
	o = s1:option(Flag, "demand_enable", translate("Enable"), translate("Mobile data on demand function enables you to keep mobile data connection on only when it\\'s in use"))
	o.nowrite = true
	o.alert={"1", "Available in ppp mode only"}
	function o.write(self, section, value)
			end
	function o.cfgvalue(self, section)
		local value = m.uci:get("network", section, "demand")
		if value then
			return "1"
		else
			return "0"
		end
	end
	time = s1:option(Value, "demand", translate("No data timeout (sec)"), translate("A mobile data connection will be terminated if no data is transfered during the timeout period"))
	--o:depends("demand_enable", "1")
	time.datatype = "range(10,3600)"
	time.default = "10"

	if moduleVidPid == "12D1:1573" or moduleVidPid == "1BC7:1201" or moduleVidPid == "12D1:15C1" or moduleVidPid == "12D1:15C3" or modulsevice == "SieraLTE" or modulsevice == "QuectelLTE" or modulsevice == "TelitLTE_V2" then
		m2 = Map("reregister")
		m2.addremove = false
		s1 = m2:section(TypedSection, "reregister", translate("Force LTE network"))
		s1.addremove = false
		o3 = s1:option(Flag, "enabled", translate("Enable"), translate("Try to connect to LTE network every x seconds (used only if service mode is set to 4G (LTE) preferred)"))
		o3.rmempty = false
		o = s1:option(Flag, "force_reregister", translate("Reregister"), translate("If this enabled, modem will be reregister before try to connect to LTE network."))
		o.rmempty = false
		interval = s1:option(Value, "interval", translate("Interval (sec)"), translate("Time in seconds between tries to connect to LTE network. Range [180 - 3600]"))
		interval.datatype = "range(180,3600)"
	end

function m.on_before_save(self)
	local passthrough = m:formvalue("cbid.simcard.sim1.passthrough_mode") or ""
	if passthrough == "static" then
		local mac_addr = m:formvalue("cbid.simcard.sim1.mac") or ""
		if mac_addr == nil or mac_addr =="" then
			m.message = "err:MAC address can't be blank in Static DHCP mode"
			return nil
		end
	end
	local passthrough2 = m:formvalue("cbid.simcard.sim1.passthrough_mode2") or ""
	if passthrough2 == "static" then
		local mac_addr2 = m:formvalue("cbid.simcard.sim1.mac2") or ""
		if mac_addr2 == nil or mac_addr2 =="" then
			m.message = "err:MAC address can't be blank in Static DHCP mode"
			return nil
		end
	end
	Save_value = 1
end

function m.on_commit(map)
	if Save_value == 1 then
		local sim1_passthrough = m:formvalue("cbid.simcard.sim1.passthrough_mode") or ""
		local mac_addr = m:formvalue("cbid.simcard.sim1.mac") or ""
		local mac_addr2 = m:formvalue("cbid.simcard.sim1.mac2") or ""
		local sim1_proto = m:formvalue("cbid.simcard.sim1.proto") or ""
		if sim1_proto then
			m.uci:set("simcard", "sim1", "proto", "3g")
		end

		local sim1_method = m:formvalue("cbid.simcard.sim1.method") or ""
		if sim1_method == "pbridge" then
			local sim1_leasetime = m:formvalue("cbid.simcard.sim1.leasetime") or "12"
			local sim1_letter = m:formvalue("cbid.simcard.sim1.letter") or "h"
			m.uci:set("simcard", "sim1", "leasetime", sim1_leasetime..""..sim1_letter)
		end

		local sim1_method = m:formvalue("cbid.simcard.sim1.method2") or ""
		if sim1_method == "pbridge" then
			local sim1_leasetime = m:formvalue("cbid.simcard.sim1.leasetime2") or "12"
			local sim1_letter = m:formvalue("cbid.simcard.sim1.letter2") or "h"
			m.uci:set("simcard", "sim2", "leasetime", sim1_leasetime..""..sim1_letter)
		end


		local sim2_passthrough = m:formvalue("cbid.simcard.sim1.passthrough_mode2") or ""
		if sim1_passthrough == "dynamic" or sim2_passthrough == "dynamic" or sim1_passthrough == "no_dhcp" or sim2_passthrough == "no_dhcp" then
			m.uci:set("dhcp", "lan", "ignore", "1")
			m.uci:set("dhcp", "dhcp_relay", "enabled", "0")
			m.uci:save("dhcp")
			m.uci:commit("dhcp")
		end

		local bind_mac = m:formvalue("cbid.simcard.sim1.bind_mac2") or ""
		local apn = m:formvalue("cbid.simcard.sim1.apn2") or ""
		local pincode = m:formvalue("cbid.simcard.sim1.pincode2") or ""
		local method = m:formvalue("cbid.simcard.sim1.method2") or ""
		local proto2 = m:formvalue("cbid.simcard.sim1.proto2") or ""

		local dialnumber = m:formvalue("cbid.simcard.sim1.dialnumber2") or ""
		local service = m:formvalue("cbid.simcard.sim1.service2") or ""
		local password = m:formvalue("cbid.simcard.sim1.password2") or ""
		local username = m:formvalue("cbid.simcard.sim1.username2") or ""
		local auth_mode = m:formvalue("cbid.simcard.sim1.auth_mode2") or ""
		local roaming = m:formvalue("cbid.simcard.sim1.roaming2") or "0"
		local pdptype = m:formvalue("cbid.simcard.sim1.pdptype2") or ""

		local demand_enable = m:formvalue("cbid.simcard.ppp.demand_enable") or ""
		local demand = m:formvalue("cbid.simcard.ppp.demand") or ""

		if demand_enable == "1" and demand ~= ""  then
				m.uci:set("network", "ppp", "demand", demand)
		elseif demand_enable ~= "1" then
				m.uci:delete("network", "ppp", "demand")
		end
		m.uci:save("network")
		m.uci:commit("network")
		
		if bind_mac then
			m.uci:set("simcard", "sim2", "bind_mac", bind_mac)
		end

		if mac_addr2 then
			m.uci:set("simcard", "sim2", "mac", mac_addr2)
		end

		if roaming then
			m.uci:set("simcard", "sim2", "roaming", roaming)
		end

		if pdptype == nil or pdptype == "" then
			m.uci:delete("simcard", "sim2", "pdptype")
		else
			m.uci:set("simcard", "sim2", "pdptype", pdptype)
			m.uci:save("simcard")
		end

		if apn == nil or apn == "" then
			m.uci:delete("simcard", "sim2", "apn")
		else
			m.uci:set("simcard", "sim2", "apn", apn)
			m.uci:save("simcard")
		end

		if pincode == nil or pincode == "" then
			m.uci:delete("simcard", "sim2", "pincode")
		else
			m.uci:set("simcard", "sim2", "pincode", pincode)
			m.uci:save("simcard")
		end

		if proto2 == nil or proto2 == "" then
			proto2="3g"
		end

		if proto2 then
			m.uci:set("simcard", "sim2", "proto", proto2)
			if proto2 == "3g" then
				m.uci:set("simcard", "sim2", "ifname", "3g-ppp")
				m.uci:set("simcard", "sim2", "device", "/dev/modem_data")
			elseif proto2 == "qmi" then
				m.uci:set("simcard", "sim2", "ifname", "wwan0")
				m.uci:set("simcard", "sim2", "device", "/dev/cdc-wdm0")
			elseif proto2 == "ncm" then
				m.uci:set("simcard", "sim2", "ifname", "wwan0")
				m.uci:set("simcard", "sim2", "device", "/dev/modem_data")
			else
				m.uci:set("simcard", "sim2", "ifname", "eth2")
				m.uci:set("simcard", "sim2", "device", "/dev/modem_data")
			end
		end

		if method then
			m.uci:set("simcard", "sim2", "method", method)
			m.uci:save("simcard")
		end

		if dialnumber == nil or dialnumber == "" then
			m.uci:delete("simcard", "sim2", "dialnumber")
		else
			m.uci:set("simcard", "sim2", "dialnumber", dialnumber)
			m.uci:save("simcard")
		end
		if service == nil or service == "" then
			m.uci:delete("simcard", "sim2", "service")
		else
			m.uci:set("simcard", "sim2", "service", service)
			m.uci:save("simcard")
		end
		if password == nil or password == "" then
			m.uci:delete("simcard", "sim2", "password")
		else
			m.uci:set("simcard", "sim2", "password", password)
			m.uci:save("simcard")
		end
		if username == nil or username == "" then
			m.uci:delete("simcard", "sim2", "username")
		else
			m.uci:set("simcard", "sim2", "username", username)
			m.uci:save("simcard")
		end
		if auth_mode == nil or auth_mode == "" then
			m.uci:delete("simcard", "sim2", "auth_mode")
		else
			m.uci:set("simcard", "sim2", "auth_mode", auth_mode)
			m.uci:save("simcard")
		end
	end
end
if moduleVidPid == "12D1:1573" or moduleVidPid == "1BC7:1201" or moduleVidPid == "12D1:15C1" or moduleVidPid == "12D1:15C3" or modulsevice == "SieraLTE" or modulsevice == "QuectelLTE" or modulsevice == "TelitLTE_V2" then
	return m, m2
else
	return m
end
