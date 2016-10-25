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
local in_out = uci:get("hwinfo","hwinfo","in_out") or "0"
local gps = uci:get("hwinfo","hwinfo","gps") or "0"
local m, s, o

arg[1] = arg[1] or ""

m = Map("sms_utils", translate("SMS Configuration"))

m.redirect = dsp.build_url("admin/services/sms/sms-utilities/")
if m.uci:get("sms_utils", arg[1]) ~= "rule" then
	luci.http.redirect(dsp.build_url("admin/services/sms/sms-utilities"))
  	return
else
	--local name = m:get(arg[1], "name") or m:get(arg[1], "_name")
	--if not name or #name == 0 then
	--	name = translate("(Unnamed Entry)")
	--end
	--m.title = "%s - %s" %{ translate("Firewall - Port Forwards"), name }
end

s = m:section(NamedSection, arg[1], "rule", translate("Modify SMS Rule"))
s.anonymous = true
s.addremove = false

o = s:option(Flag, "enabled", translate("Enable"), translate("Enable this rule"))

o = s:option(ListValue, "action", translate("Action"), translate("The action to be performed when this rule is met"))
o:value("reboot", translate("Reboot"))
o:value("send_status", translate("Send status"))
if in_out == "1" then
	o:value("iostatus", translate("I/O status"))
end
o:value("vpnstatus", translate("OpenVPN status"))
o:value("wifi", translate("Switch WiFi"))
o:value("mobile", translate("Switch mobile data"))
o:value("change_mobile_settings", translate("Change mobile data settings"))
o:value("list_of_profile", translate("Get list of profiles"))
o:value("change_profile", translate("Change profile"))
o:value("vpn", translate("Manage OpenVPN"))
o:value("ssh_access", translate("SSH access control"))
o:value("web_access", translate("Web access control"))
o:value("firstboot", translate("Restore to default"))
o:value("switch_sim", translate("Force SIM switch"))
o:value("fw_upgrade", translate("FW upgrade from server"))
o:value("config_update", translate("Config update from server"))
o:value("monitoring", translate("Switch monitoring"))
o:value("monitoring_status", translate("Monitoring status"))
if gps == "1" then
	o:value("gps", translate("GPS"))
	o:value("gps_coordinates", translate("GPS coordinates"))
end
if in_out == "1" then
	o:value("dout", translate("Switch output"))
end

function o.cfgvalue(...)
	local v = Value.cfgvalue(...)
	return v
end

o = s:option(ListValue, "value", translate(" "), translate(""))
o:value("on", translate("On"))
o:value("off", translate("Off"))
o:depends("action", "wifi")
o:depends("action", "mobile")
o:depends("action", "dout")
o:depends("action", "gps")
o:depends("action", "monitoring")
o:depends("action", "vpn")

o = s:option(Flag, "timeout", translate("Active timeout"), translate("Rule active for a specified time"))
o:depends("action", "dout")
o.default = false
o.rmempty = false

o = s:option(Value, "seconds", translate("Seconds"), translate("Rule active for a specified time, format seconds"))
o:depends("timeout", "1")
o.datatype = "range(1,999999)"
o.default = "5"

src = s:option(Value, "smstext", translate("SMS text"), translate("SMS text that is required to trigger this rule. Allowable characters (a-zA-Z0-9!@#$%&*+-/=?^_`{|}~.)"))
src.datatype = "fieldvalidation('^[a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. ]+$',0)"

dummy = s:option(DummyValue, "getinfo_reboot", translate(""))
dummy.default = translate("SMS text, which let you reboot your router. E.g. \"reboot\"")
dummy:depends("action", "reboot")

dummy = s:option(DummyValue, "getinfo_send_status", translate(""))
dummy.default = translate("SMS text, which let you get router status which you choose to know. E.g. \"status\"")
dummy:depends("action", "send_status")

dummy = s:option(DummyValue, "getinfo_iostatus", translate(""))
dummy.default = translate("SMS text, which let you get input/output status. E.g. \"iostatus\"")
dummy:depends("action", "iostatus")

dummy = s:option(DummyValue, "getinfo_vpnstatus", translate(""))
dummy.default = translate("SMS text, which let you get all OpenVPN status. E.g. \"vpnstatus\"")
dummy:depends("action", "vpnstatus")

dummy = s:option(DummyValue, "getinfo_wifi", translate(""))
dummy.default = translate("SMS text, which let you to turn on or turn off your WiFi. E.g. \"wifion\" or \"wifioff\"")
dummy:depends("action", "wifi")

dummy = s:option(DummyValue, "getinfo_mobile", translate(""))
dummy.default = translate("SMS text, which let you to turn on or turn off your mobile data. E.g. \"mobileon\" or \"mobileoff\"")
dummy:depends("action", "mobile")

dummy = s:option(DummyValue, "getinfo_change_mobile_settings", translate(""))
dummy.default = translate("SMS text, which let you to change your mobile settings to SIM1 or SIM2. E.g. \"cellular apn=internet.gprs dialnumber=*99***1# auth_mode=pap service=3gonly username=user password=user\"")
dummy:depends("action", "change_mobile_settings")

dummy = s:option(DummyValue, "getinfo_list_of_profile", translate(""))
dummy.default = translate("SMS text, which let you to get list of created profiles. E.g. \"profdisp\"")
dummy:depends("action", "list_of_profile")

dummy = s:option(DummyValue, "getinfo_change_profile", translate(""))
dummy.default = translate("SMS text, which let you to change router profile. After secret word you have to write profile name. E.g. \"pr profile_name\"")
dummy:depends("action", "change_profile")

dummy = s:option(DummyValue, "getinfo_vpn", translate(""))
dummy.default = translate("SMS text, which let you to stop or start OpenVPN instance. After secret word you have to write OpenVPN name. E.g. \"vpnon client_name\" or \"vpnoff client_name\"")
dummy:depends("action", "vpn")

dummy = s:option(DummyValue, "getinfo_ssh_access", translate(""))
dummy.default = translate("SMS text, which let you to manage your router ssh access, by your selected settings. E.g. \"ssh\"")
dummy:depends("action", "ssh_access")

dummy = s:option(DummyValue, "getinfo_web_access", translate(""))
dummy.default = translate("SMS text, which let you to manage your router web access, by your selected settings. E.g. \"web\"")
dummy:depends("action", "web_access")

dummy = s:option(DummyValue, "getinfo_firstboot", translate(""))
dummy.default = translate("SMS text, which let you to set your router‘s default settings. After this rule execute, router will reboot. E.g. \"restore\"")
dummy:depends("action", "firstboot")

dummy = s:option(DummyValue, "getinfo_switch_sim", translate(""))
dummy.default = translate("SMS text, which let you to change sim to another one. E.g. \"sim_switch\"")
dummy:depends("action", "switch_sim")

dummy = s:option(DummyValue, "getinfo_fw_upgrade", translate(""))
dummy.default = translate("SMS text, which let you to upgrade your router form server. After this rule execute, router will reboot. E.g. \"fw_upgrade\"")
dummy:depends("action", "fw_upgrade")

dummy = s:option(DummyValue, "getinfo_config_update", translate(""))
dummy.default = translate("SMS text, which let you to update your router config form server. After this rule execute, router will reboot. E.g. \"config_update\"")
dummy:depends("action", "config_update")

dummy = s:option(DummyValue, "getinfo_gps", translate(""))
dummy.default = translate("SMS text, which let you to turn on or turn off your gps. E.g. \"gps_on\" or \"gps_off\"")
dummy:depends("action", "gps")

dummy = s:option(DummyValue, "getinfo_gps_coordinates", translate(""))
dummy.default = translate("SMS text, which let you to get your router gps coordinates. E.g. \"gps\"")
dummy:depends("action", "gps_coordinates")

dummy = s:option(DummyValue, "getinfo_dout", translate(""))
dummy.default = translate("SMS text, which let you to manage your router output, by your selected settings. E.g. \"dout\"")
dummy:depends("action", "dout")

dummy = s:option(DummyValue, "getinfo_monitoring", translate(""))
dummy.default = translate("SMS text, which let you to turn on or turn off your monitoring. E.g. \"monitoringon\" or \"monitoringoff\"")
dummy:depends("action", "monitoring")

dummy = s:option(DummyValue, "getinfo_monitoring_status", translate(""))
dummy.default = translate("SMS text, which let you to get monitoring status. E.g. \"monitoring_status\"")
dummy:depends("action", "monitoring_status")

o = s:option(ListValue, "authorisation", translate("Authorization method"), translate("What kind of authorization to use for SMS management"))
o:value("no", translate("No authorization"))
o:value("serial", translate("By serial"))
o:value("password", translate("By router admin password"))

o = s:option(ListValue, "allowed_phone", translate("Allowed users"), translate("Whitelist of allowed users"))
o:value("all", translate("From all numbers"))
o:value("group", translate("From group"))
o:value("single", translate("From single number"))

src = s:option(Value, "tel", translate("Sender's phone number"), translate("A whitelisted phone number. Phone number must be in international format. Allowable characters (0-9#*+)"))
src.datatype = "fieldvalidation('^[0-9#*+]+$',0)"
src:depends("allowed_phone", "single")

o = s:option(ListValue, "group", translate("Group"), translate("A whitelisted users group"))
m.uci:foreach("sms_utils", "group", function(s)
	o:value(s.name, s.name)
end)
o:depends("allowed_phone", "group")

--srl = s:option(Value, "serial", translate("Serial number"), translate("Specifies your router serial number"))
--srl.datatype = "fieldvalidation('^[a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. ]+$',0)"
--srl:depends("action", "safe_mode")

stat_e = s:option(Flag, "status_sms", translate("Get status via SMS after reboot"), translate("Receive router status information via SMS after reboot"))
stat_e:depends("action", "reboot")

wifiw = s:option(Flag, "write_wifi", translate("Write to config"), translate("Permanently save wireless network state to configuration"))
wifiw:depends("action", "wifi")

w3g = s:option(Flag, "write_mobile", translate("Write to config"), translate("Permanently save mobile network state to configuration"))
w3g:depends("action", "mobile")

send = s:option(DummyValue, "getinfo", translate("Get information:"), translate("Which status information should be included in SMS"))
send:depends("action", "send_status")
send:depends("status_sms", "1")

message = s:option(Value, "message", translate("Message text"), translate("Message to send. Allowed characters (a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. )"))
message:depends("action", "send_status")
message:depends("status_sms", "1")
message.template = "sms-utilities/status_textbox"
message.default = "Router name - %rn; WAN IP - %wi; Data Connection state - %cs; Connection type - %ct; Signal strength - %ss; New FW available - %fs;"
message.rows = "6"
message.indicator = arg[1]

function message.write(self, section, value)
	local value = luci.http.formvalue("cbid.sms_utils."..arg[1]..".message")
	value = string.gsub(value, "%s", " ")
	if value then
		m.uci:set("sms_utils", section, "message", value)
		m.uci:save("sms_utils")
		m.uci:commit("sms_utils")
	end
end

outputtype = s:option(ListValue, "outputnb", translate("Output type"), translate("Type of output which will be activated"))
outputtype:value("DOUT1", translate("Digital OC output"))
outputtype:value("DOUT2", translate("Relay output"))
outputtype:depends("action", "dout")

outputtype = s:option(ListValue, "simcard", translate("SIM card"), translate("SIM card for which mobile data settings will be changed"))
outputtype:value("sim1", translate("SIM 1"))
outputtype:value("sim2", translate("SIM 2"))
outputtype:depends("action", "change_mobile_settings")

-- send = s:option(Flag, "leave_sms", translate("Keep SMS utilities settings"))
-- send:depends("action", "default_settings")

p = s:option(Flag, "ssh_access_enabled",  translate("Enable SSH access"), translate("Possibility to reach router via SSH from LAN (Local Area Network)"))
p.rmempty = false
p.enabled = "1"
p.disabled = "0"
p:depends("action", "ssh_access")
o = s:option(Flag, "ssh_access_remote", translate("Enable remote SSH access"), translate("Possibility to reach router via SSH from WAN (Wide Area Network)"))
o.rmempty = false
o.enabled = "1"
o.disabled = "0"
o:depends("action", "ssh_access")


enb = s:option(Flag, "web_access_enabled", translate("Enable HTTP access"), translate("Possibility to reach router via HTTP from LAN (Local Area Network)"))
enb.rmempty = false
enb:depends("action", "web_access")
o = s:option(Flag, "web_access_http", translate("Enable remote HTTP access"), translate("Possibility to reach router via HTTP from WAN (Wide Area Network)"))
o.rmempty = false
o:depends("action", "web_access")
o = s:option(Flag, "web_access_https", translate("Enable remote HTTPS access"), translate("Possibility to reach router via HTTPS from WAN (Wide Area Network)"))
o.rmempty = false
o:depends("action", "web_access")

local sms_enable = utl.trim(sys.exec("uci -q get sms_utils. " .. arg[1] .. ".enabled")) or "0"
function m.on_commit()
	--Delete all usr_enable from sms_utlis config
	local smsEnable = m:formvalue("cbid.sms_utils." .. arg[1] .. ".enabled") or "0"
	if smsEnable ~= sms_enable then
		m.uci:foreach("sms_utils", "rule", function(s)
			local usr_enable = s.usr_enable or ""
			sms_inst2 = s[".name"] or ""
			if usr_enable == "1" then
				m.uci:delete("sms_utils", sms_inst2, "usr_enable")
			end
		end)
	end
	m.uci:save("sms_utils")
	m.uci.commit("sms_utils")
end

return m
