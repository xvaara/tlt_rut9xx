
require "teltonika_lua_functions" 

local moduleType = luci.util.trim(luci.sys.exec("uci get system.module.type"))
local ModuleVidPid = luci.util.trim(luci.sys.exec("uci get system.module.vid"))..":"..luci.util.trim(luci.sys.exec("uci get system.module.pid"))
local m, s, o
local modulservice = "3G"
local modulsevice2 = "0"
local dbPath = "/usr/lib/operators/"
local dbName = "operators.db"

function debug(string)
		os.execute("logger " .. string)
end

if ModuleVidPid == "12D1:1573" or ModuleVidPid == "12D1:15C1" or ModuleVidPid == "12D1:15C3" or ModuleVidPid == "1BC7:1201" or ModuleVidPid == "1BC7:0036" then
	modulservice = "LTE"
end

--ismtys del telit modemu kurie nepalaiko 2g prefered ir 3g prefered pasirinkimo            
if ModuleVidPid == "1BC7:0021" then --Telit He910d
	modulsevice2 = "1"
elseif ModuleVidPid == "1BC7:1201" or ModuleVidPid == "1BC7:0036" then --Telit LE910-EUG
	modulsevice2 = "2"
	
end

if moduleType == "3g_ppp" then
	m = Map("simcard", translate("Mobile Configuration"),
		translate("Next, let's configure your mobile settings so you can start using internet right away."))
	m.wizStep = 2
	m.addremove = false

	s = m:section(NamedSection, "sim1", "", translate("Mobile Configuration (SIM1)"))
	s.addremove = false

	if fileExists(dbPath, dbName) then
		o = s:option(Value, "profile", translate("Operator profile"))
		o.template = "cfgwzd-module/ListValue"
	end

	o = s:option(Value, "apn", translate("APN"), translate("APN (Access Point Name) is configurable network identifier used by a mobile device when connecting to a carrier"))
		
	o = s:option(Value, "pincode", translate("PIN number"), translate("SIM card PIN (Personal Identification Number) is a secret numeric password shared between a user and a system that can be used to authenticate the user"))
		o.datatype = "lengthvalidation(4,12,'^[0-9]+$')"

	o = s:option(Value, "dialnumber", translate("Dialing number"), translate("Dialing number is used to establish a mobile PPP (Point-to-Point Protocol) connection. For example *99#"))
		o.default = "*99#"

	o = s:option(ListValue, "auth_mode", translate("Authentication method"), translate("Authentication method that your carrier uses to authenticate new connections on its network"))
		o:value("chap", translate("CHAP"))
		o:value("pap", translate("PAP"))
		o:value("none", translate("None"))
		o.default = "none"

	o = s:option(Value, "username", translate("Username"), translate("Type in your username"))
		o:depends("auth_mode", "chap")
		o:depends("auth_mode", "pap")

	o = s:option(Value, "password", translate("Password"), translate("Type in your password"))
		o:depends("auth_mode", "chap")
		o:depends("auth_mode", "pap")
		o.password = true;

	o = s:option(ListValue, "service", translate("Service mode"), translate("Your network preference. If your local mobile network supports GSM (2G) and UMTS (3G) you can specify to which network you prefer to connect to"))
		o:value("gprs-only", translate("2G only"))
		if modulsevice2 == "0" then
			o:value("gprs", translate("2G preferred"))
		end
		o:value("umts-only", translate("3G only"))
		if modulsevice2 == "0" then
			o:value("umts", translate("3G preferred"))
		end
		if modulservice == "LTE" then
			o:value("lte-only", translate("4G (LTE) only"))
			if modulsevice2 == "0" then
				o:value("lte", translate("4G (LTE) preferred"))
			end
			o:value("auto", translate("automatic"))
			o.default = "lte"
		else
			o:value("auto", translate("automatic"))
			if modulsevice2 == "0" then		
				o.default = "umts"
			else
				o.default = "auto"
			end
		end
		
		o1 = s:option(Flag, "shw3g", translate("Show mobile info at login page"), translate("Show operator and signal strenght at login page"))
		o1.rmempty = false

		function o1.cfgvalue(...)
			return m.uci:get("teltonika", "sys", "shw3g")
		end

		function o1.write(self, section, value)
			m.uci:set("teltonika", "sys", "shw3g", value)
			m.uci:save("teltonika")
			m.uci:commit("teltonika")
		end
		
else
	m = Map("network_3g", translatef("Step - %s", modulservice), 
			translatef("Next, let's configure your %s settings so you can start using internet right away.", modulservice))
	m.wizStep = 2

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
	m.addremove = false

	s = m:section(NamedSection, "3g", "custom_interface", translatef(" %s Configuration", modulservice));
	s.addremove = false

	o = s:option(Value, "apn", translate("APN"), translate("APN (Access Point Name) is configurable network identifier used by a mobile device when connecting to a carrier"))

	o = s:option(Value, "pin", translate("PIN number"), translate("SIM card PIN (Personal Identification Number) is a secret numeric password shared between a user and a system that can be used to authenticate the user"))
	o.datatype = "range(0,9999)"

	auth = s:option(ListValue, "auth_mode", translatef(" %s authentication method", modulservice), translate("Authentication method that your carrier uses to authenticate new connections on its network"))

	auth:value("chap", translate("CHAP"))
	auth:value("pap", translate("PAP"))
	auth:value("none", translate("none"))
	auth.default = "none"

	o = s:option(Value, "user", translate("Username"), translate("Type in your username"))
	o:depends("auth_mode", "chap")
	o:depends("auth_mode", "pap")

	o = s:option(Value, "password", translate("Password"), translate("Type in your password"))
	o:depends("auth_mode", "chap")
	o:depends("auth_mode", "pap")
	o.password = true;

	o = s:option(ListValue, "net_mode", translate("Prefered network"), translate("Select network that you prefer"))

	o:value("gsm", translate("2G"))
	o:value("umts", translate("3G"))
	o:value("auto", translate("auto"))

	o.default = "auto"
	
	
	o1 = s:option(Flag, "shw3g", translate("Show mobile info at login page"), translate("Show operator and signal strenght at login page"))
	o1.rmempty = false

	function o1.cfgvalue(...)
		return m.uci:get("teltonika", "sys", "shw3g")
	end

	function o1.write(self, section, value)
		m.uci:set("teltonika", "sys", "shw3g", value)
		m.uci:save("teltonika")
		m.uci:commit("teltonika")
	end

	--[[o = s:option(Flag, "data_mode", translate("Data mode"))

	o.enabled = "enabled"
	o.disabled = "disabled"]]
end
function m.on_after_save()
	if m:formvalue("cbi.wizard.next") then
		m.uci:commit("simcard")
--kadangi jau po save tai reikia rankiniu budu perleist inis skripta
		luci.sys.call("/etc/init.d/sim_conf_switch restart >/dev/null")
		luci.sys.call("ifup ppp >/dev/null")
		luci.http.redirect(luci.dispatcher.build_url("admin/system/wizard/step-lan"))
	end
end
if m:formvalue("cbi.wizard.skip") then
	luci.http.redirect(luci.dispatcher.build_url("/admin/status/overview"))
end
return m
