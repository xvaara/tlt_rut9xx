--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: wifi.lua 8190 2012-01-24 20:57:54Z jow $
]]--

local wa = require "luci.tools.webadmin"
local nw = require "luci.model.network"
local fs = require "nixio.fs"
local dsp = require "luci.dispatcher"
local savePressed = luci.http.formvalue("cbi.apply") and true or false
arg[1] = arg[1] or ""

m = Map("wireless", "",	translate("Here you can configure your wireless settings like radio frequency, mode, encryption etc..."))
m.redirect = dsp.build_url("admin/network/wireless")
m:chain("network")
m:chain("firewall")

local ifsection
local changes = m.uci:changes("wireless")

if changes.wireless  and not savePressed then
m.message = translate("err:Click Save to take effect")
end

function m.on_commit(map)
	local wnet = nw:get_wifinet(arg[1])
	if ifsection and wnet then
		ifsection.section = wnet.sid
		if wnet:get("mode") == "ap" then
			m.title = translate("Wireless Access Point")
		elseif wnet:get("mode") == "sta" then
			m.title = translate("Wireless Station")
		else
			m.title = translate("Wireless Configuration")
		end
	end

-- 	check = luci.http.formvalue("cbid.wireless.radio0.__toggle") or "0"
-- 	if check then
-- 		if check == "1" then	--//Disable NAT=1 means masq=0
-- 			m.uci:delete("wireless", wnet.sid, "disabled")
-- 			m.uci:set("wireless", wnet.sid, "user_enable", "1")
-- 		else
-- 			m.uci:set("wireless", wnet.sid, "disabled", "1")
-- 			m.uci:set("wireless", wnet.sid, "user_enable", "0")
-- 		end
-- 			m.uci:save("wireless")
-- 	end
end
nw.init(m.uci)

local wnet = nw:get_wifinet(arg[1])

-- redirect to overview page if network does not exist anymore (e.g. after a revert)
if not wnet then
	luci.http.redirect(luci.dispatcher.build_url("admin/network/wireless"))
	return
end

local wirelessMode = wnet:get("mode")
local wdev = wnet and wnet:get_device()

if not wdev then
	luci.http.redirect(luci.dispatcher.build_url("admin/network/wireless"))
	return
end

function m.parse(map)
	--:FIXME sita funkcija reiketu istrinti, nes mygtukas nebeegzistuoja
	if m:formvalue("cbid.wireless.%s.__toggle" % wdev:name()) then
		luci.sys.call("env -i /sbin/wifi down >/dev/null 2>/dev/null")
		if wdev:get("disabled") == "1" or wnet:get("disabled") == "1" then
			wnet:set("disabled", nil)
			wnet:set("user_enable", "1")
		else
			wnet:set("user_enable", "0")
			wnet:set("disabled", "1")
		end
		wdev:set("disabled", nil)
		nw:commit("wireless")
		luci.sys.call("env -i /sbin/wifi up >/dev/null 2>/dev/null")
		luci.http.redirect(luci.dispatcher.build_url("admin/network/wireless", arg[1]))
		return
	end
	if m:formvalue("cbid.wireless.%s.__scan" % wdev:name()) then
		luci.http.redirect(luci.dispatcher.build_url("admin/network/wireless_join") .. "?device=radio0")
		return
	end
	Map.parse(map)
end

if wirelessMode == "ap" then
	m.title = translate("Wireless Access Point")
elseif wirelessMode == "sta" then
	m.title = translate("Wireless Station")
else
	m.title = translate("Wireless Configuration")
end

local function txpower_list(iw)
  local list = iw.txpwrlist or { }
  local new = { }
  if #list > 0 then
	local maxdb = list[#list].dbm
	local maxmw = list[#list].mw
	local i
	local step = 20
	for i = 1,5 do
	new[i] = {
	display_dbm = 100 - (step*(i-1)),
	driver_dbm = math.floor(maxdb*((100-(step*(i-1)))/100)),
	driver_mw = math.floor(maxmw*((100-(step*(i-1)))/100))
	}
	end
  end
	return new
end

local iw = luci.sys.wifi.getiwinfo(arg[1])
local hw_modes      = iw.hwmodelist or { }
local tx_power_list = txpower_list(iw)
local tx_power_cur  = wdev:get("txpower")

s = m:section(NamedSection, wdev:name(), "wifi-device", translate("Device Configuration"))
s.addremove = false

s:tab("general", translate("General Setup"))
s:tab("macfilter", translate("MAC Filter"))
s:tab("advanced", translate("Advanced Settings"))

if wirelessMode == "sta" then
	scan = s:taboption("general", Button, "__scan")
	scan.title      = translate("Scan for a new network")
	scan.inputtitle = translate("Scan")
	scan.inputstyle = "apply"

	recon = s:taboption("general", Flag, "repeat" , "Repeat connect", "Check this if you need to connect to hidden SSID")
	recon.default = 0
	recon.rmempty = false

	int = s:taboption("general", Value, "scan_sleep", "Interval", "Set interval in seconds")
	int:depends("repeat", "1")
	int.datatype = "range(1, 3600)"
	int.default = 5

	count = s:taboption("general", Value, "count", "Repeat times", "Set how meny time repeat connect")
	count:depends("repeat", "1")
	count.datatype = "range(1, 24)"
	count.default = 3

end

en = s:taboption("general", Flag, "enable", translate("Enable wireless"), translate("A wireless (IEEE 802.11 b/g/n standard) LAN (Local Area Connection)"))
  	en.rmempty = false

	function en.write(self, section, value)
		if value == "1" then
			m.uci:delete(self.config, wnet.sid, "disabled")
			m.uci:set(self.config, wnet.sid, "user_enable", "1")
			
		else
			m.uci:set(self.config, wnet.sid, "user_enable", "0")
			m.uci:set(self.config, wnet.sid, "disabled", "1")
		end
	end

	function en.cfgvalue(self, section)
		local value = m.uci:get("wireless", wnet.sid, "user_enable") or "0"
			
		return value
	end

local htcaps = wdev:get("ht_capab") and true or false

ch = s:taboption("general", ListValue, "channel", translate("Channel"), translate("Force wireless radio to work on this channel"))
ch:value("auto", translate("Auto"))
for _, f in ipairs(iw and iw.freqlist or luci.sys.wifi.channels()) do
	if not f.restricted then
		ch:value(f.channel, "%i (%.3f GHz)" %{ f.channel, f.mhz / 1000 })
	end
end

mode = s:taboption("advanced", ListValue, "hwmode", translate("Mode"), translate("Different modes provide different wireless standard support which directly impacts radio\\'s throughput performance"))
mode:value("", translate("Auto"))
if hw_modes.b then mode:value("11b", translate("802.11b")) end
if hw_modes.g then mode:value("11g", translate("802.11g")) end
if hw_modes.a then mode:value("11a", translate("802.11a")) end

if htcaps then
	if hw_modes.g and hw_modes.n then mode:value("11ng", translate("802.11g+n")) end
	if hw_modes.a and hw_modes.n then mode:value("11na", translate("802.11a+n")) end

	htmode_b = s:taboption("advanced", ListValue, "htmode_below", translate("HT mode"), translate("HT (High Throughput) mode. 40 MHz bandwidth provides better performance"))
	htmode_b:value("HT20", translate("20MHz"))
	htmode_b:value("HT40-", translate("40MHz 2nd channel below"))

	htmode = s:taboption("advanced", ListValue, "htmode", translate("HT mode"), translate("HT (High Throughput) mode. 40 MHz bandwidth provides better performance"))
	htmode:value("HT20", translate("20MHz"))
	htmode:value("HT40-", translate("40MHz 2nd channel below"))
	htmode:value("HT40+", translate("40MHz 2nd channel above"))

	htmode_a = s:taboption("advanced", ListValue, "htmode_above", translate("HT mode"), translate("HT (High Throughput) mode. 40 MHz bandwidth provides better performance"))
	htmode_a:value("HT20", translate("20MHz"))
	htmode_a:value("HT40+", translate("40MHz 2nd channel above"))

	htmode_m = s:taboption("advanced", ListValue, "htmode_midle", translate("HT mode"), translate("HT (High Throughput) mode. 40 MHz bandwidth provides better performance"))
		htmode_m:value("HT20", translate("20MHz"))
		htmode_m:depends({channel="auto", hwmode="11na",})
		htmode_m:depends({channel="auto", hwmode="11ng",})
	
	local chann = iw and iw.freqlist or luci.sys.wifi.channels()
	for n, f in ipairs(chann) do
		if not f.restricted then
			if n <= 4 then
				htmode_a:depends({channel=f.channel, hwmode="11na",})
				htmode_a:depends({channel=f.channel, hwmode="11ng",})
			end
			if n > 4 and n <= #chann - 4 then
				htmode:depends({channel=f.channel, hwmode="11na",})
				htmode:depends({channel=f.channel, hwmode="11ng",})
				
			end
			if n > #chann - 4 then
				htmode_b:depends({channel=f.channel, hwmode="11na",})
				htmode_b:depends({channel=f.channel, hwmode="11ng",})
			end
		end
	end

	function htmode_b.write(self, section, value)
		if value then
			m.uci:set(self.config, section, htmode.option, value)
			m.uci:commit(self.config)
		end
	end

	function htmode_b.cfgvalue(self, section)
		value = m.uci:get(self.config, section, htmode.option)
		return value
	end

	function htmode_a.write(self, section, value)
		if value then
			m.uci:set(self.config, section, htmode.option, value)
			m.uci:commit(self.config)
		end
	end

	function htmode_a.cfgvalue(self, section)
		value = m.uci:get(self.config, section, htmode.option)
		return value
	end
	
	function htmode_m.write(self, section, value)
		if value then
			m.uci:set(self.config, section, htmode.option, value)
			m.uci:commit(self.config)
		end
	end

	function htmode_m.cfgvalue(self, section)
		value = m.uci:get(self.config, section, htmode.option)
		return value
	end

end

local cl = iw and iw.countrylist
if cl and #cl > 0 then
	cc = s:taboption("advanced", ListValue, "country", translate("Country code"), translate("ISO/IEC 3166 alpha2 country codes as defined in ISO 3166-1 standard"))
	cc.default = tostring(iw and iw.country or "00")
	for _, c in ipairs(cl) do
		cc:value(c.alpha2, "%s - %s" %{ c.alpha2, c.name })
	end
else
	s:taboption("advanced", Value, "country", translate("Country code"), translate("ISO/IEC 3166 alpha2 country codes as defined in ISO 3166-1 standard"))
end

if #tx_power_list ~= 0
then
tp = s:taboption("advanced",ListValue,"txpower", translate("Transmit power"), translate("Before changing transmit power value please save the settings with your country code applied"))
tp.rmempty = true
tp.default = tx_power_cur


function tp.cfgvalue(...)
	return wdev:get("txpower")
end

for _, p in ipairs(tx_power_list) do
	tp:value(p.driver_dbm, "%i %%"	%{ p.display_dbm })
end
end

s:taboption("advanced", Value, "frag", translate("Fragmentation threshold"), translate("Data packets\\' fragmentation. Typically the range used for fragmentation threshold is 256-2346")).datatype = "range(255,2346)"
s:taboption("advanced", Value, "rts", translate("RTS/CTS threshold"), translate("RTS/CTS (Request to Send/Clear to Send) is a mechanism, used to reduce frame collisions introduced by the hidden node problem. RTS/CTS packet size threshold is 0–2347")).datatype = "range(0,2347)"
----------------------- Interface -----------------------

s = m:section(NamedSection, wnet.sid, "wifi-iface", translate("Interface Configuration"))
ifsection = s
s.addremove = false
s.anonymous = true
s.defaults.device = wdev:name()

s:tab("general", translate("General Setup"))
s:tab("encryption", translate("Wireless Security"))
s:tab("macfilter", translate("MAC Filter"))
s:tab("advanced", translate("Advanced Settings"))

ssidname = s:taboption("general", Value, "ssid", translate("SSID"), translate("Your wireless network\\'s identification string that will be visible on the network"))
ssidname.rmempty = false
ssidname.datatype = "lengthvalidation(0,32)"

mode = s:taboption("general", ListValue, "mode", translate("Mode"), translate("Wireless modes of operation"))
mode.isHidden = true
mode.override_values = true
mode:value("ap", translate("Access point"))
mode:value("sta", translate("Client"))
mode:value("adhoc", translate("Ad-Hoc"))

if fs.access("/usr/sbin/iw") then
	mode:value("mesh", "802.11s")
end

mode:value("ahdemo", translate("Pseudo Ad-Hoc (ahdemo)"))
mode:value("monitor", translate("Monitor"))

bssid = s:taboption("general", Value, "bssid", translate("BSSID"), translate("The MAC address, (e.g. 00:11:22:33:44:55)"))
bssid:depends({mode="adhoc"})
bssid:depends({mode="sta"})
bssid:depends({mode="sta-wds"})

mp = s:taboption("macfilter", ListValue, "macfilter", translate("MAC address filter"), translate("Configurable access control using MAC addresses\\' list"))
mp:depends({mode="ap"})
mp:depends({mode="ap-wds"})
mp:value("", translate("Disable"))
mp:value("allow", translate("Allow listed only"))
mp:value("deny", translate("Allow all except listed"))

ml = s:taboption("macfilter", DynamicList, "maclist", translate("MAC list"), translate("e.g. 00:11:22:33:44:55"))
ml.datatype = "macaddr"
ml:depends({macfilter="allow"})
ml:depends({macfilter="deny"})

mode:value("ap-wds", "%s (%s)" % {translate("Access point"), translate("WDS")})
mode:value("sta-wds", "%s (%s)" % {translate("Client"), translate("WDS")})

function mode.write(self, section, value)
	if value == "ap-wds" then
		ListValue.write(self, section, "ap")
		m.uci:set("wireless", section, "network", "lan")
		m.uci:set("wireless", section, "wds", 1)
	elseif value == "sta-wds" then
		ListValue.write(self, section, "sta")
		m.uci:set("wireless", section, "wds", 1)
	else
		ListValue.write(self, section, value)
		m.uci:delete("wireless", section, "wds")
	end
end

function mode.cfgvalue(self, section)
	local mode = ListValue.cfgvalue(self, section)
	local wds  = m.uci:get("wireless", section, "wds") == "1"

	if mode == "ap" and wds then
		return "ap-wds"
	elseif mode == "sta" and wds then
		return "sta-wds"
	else
		return mode
	end
end

isolate = s:taboption("advanced", Flag, "isolate", translate("Separate clients"), translate("Prevent client-to-client communication"))
isolate:depends({mode="ap"})
isolate.rmempty = false

ttl_size = s:taboption("advanced", Flag, "ttl_increase", translate("Increase TTL packet size"), translate("Increase TTL packet size for incoming packets"))
ttl_size:depends({mode="ap"})
ttl_size.rmempty = false

signal_threshold = s:taboption("advanced", Value, "signal_threshold", translate("Signal threshold"), translate("Minimal signal strenght for connection"))
signal_threshold:depends({mode="sta"})
signal_threshold.rmempty = true

hidden = s:taboption("general", Flag, "hidden", translate("Hide SSID"), translate("Will render your SSID hidden from other devices that try to scan the area"))
hidden:depends({mode="ap"})
hidden:depends({mode="ap-wds"})

encr = s:taboption("encryption", ListValue, "encryption", translate("Encryption"), translate("Method of encryption that will be used for users authorization"))
encr.override_values = true
encr.override_depends = true
encr:depends({mode="ap"})
encr:depends({mode="sta"})
encr:depends({mode="adhoc"})
encr:depends({mode="ahdemo"})
encr:depends({mode="ap-wds"})
encr:depends({mode="sta-wds"})
encr:depends({mode="mesh"})

cipher = s:taboption("encryption", ListValue, "cipher", translate("Cipher"), translate("In cryptography, a cipher (or cypher) is an algorithm for performing encryption or decryption"))
cipher:depends({encryption="wpa"})
cipher:depends({encryption="wpa2"})
cipher:depends({encryption="psk"})
cipher:depends({encryption="psk2"})
cipher:depends({encryption="wpa-mixed"})
cipher:depends({encryption="psk-mixed"})
cipher:value("auto", translate("Auto"))
cipher:value("ccmp", translate("Force CCMP (AES)"))
cipher:value("tkip", translate("Force TKIP"))
cipher:value("tkip+ccmp", translate("Force TKIP and CCMP (AES)"))

function encr.cfgvalue(self, section)
	local v = tostring(ListValue.cfgvalue(self, section))
	if v == "wep" then
		return "wep-open"
	elseif v and v:match("%+") then
		return (v:gsub("%+.+$", ""))
	end
	return v
end

function encr.write(self, section, value)
	local e = tostring(encr:formvalue(section))
	local c = tostring(cipher:formvalue(section))
	if value == "wpa" or value == "wpa2"  then
		self.map.uci:delete("wireless", section, "key")
	end
	if e and (c == "tkip" or c == "ccmp" or c == "tkip+ccmp") then
		e = e .. "+" .. c
	end
	self.map:set(section, "encryption", e)
end

function cipher.cfgvalue(self, section)
	local v = tostring(ListValue.cfgvalue(encr, section))
	if v and v:match("%+") then
		v = v:gsub("^[^%+]+%+", "")
		if v == "aes" then v = "ccmp"
		elseif v == "tkip+aes" then v = "tkip+ccmp"
		elseif v == "aes+tkip" then v = "tkip+ccmp"
		elseif v == "ccmp+tkip" then v = "tkip+ccmp"
		end
	end
	return v
end

function cipher.write(self, section)
	return encr:write(section)
end


encr:value("none", translate("No encryption"))
encr:value("wep-open", translate("WEP open system"), {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"}, {mode="adhoc"}, {mode="ahdemo"}, {mode="wds"})
encr:value("wep-shared", translate("WEP shared key"),  {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"}, {mode="adhoc"}, {mode="ahdemo"}, {mode="wds"})

local supplicant = fs.access("/usr/sbin/wpa_supplicant")
local hostapd = fs.access("/usr/sbin/hostapd")

-- Probe EAP support
local has_ap_eap  = (os.execute("hostapd -veap >/dev/null 2>/dev/null") == 0)
local has_sta_eap = (os.execute("wpa_supplicant -veap >/dev/null 2>/dev/null") == 0)

if hostapd and supplicant then
	encr:value("psk", translate("WPA-PSK"), {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"})
	encr:value("psk2", translate("WPA2-PSK"), {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"})
	encr:value("psk-mixed", translate("WPA-PSK/WPA2-PSK mixed mode"), {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"})
if has_ap_eap and has_sta_eap then
	encr:value("wpa", translate("WPA-EAP"), {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"})
	encr:value("wpa2", translate("WPA2-EAP"), {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"})
end
elseif hostapd and not supplicant then
	encr:value("psk", translate("WPA-PSK"), {mode="ap"}, {mode="ap-wds"})
	encr:value("psk2", translate("WPA2-PSK"), {mode="ap"}, {mode="ap-wds"})
	encr:value("psk-mixed", translate("WPA-PSK/WPA2-PSK mixed mode"), {mode="ap"}, {mode="ap-wds"})
	if has_ap_eap then
		encr:value("wpa", translate("WPA-EAP"), {mode="ap"}, {mode="ap-wds"})
		encr:value("wpa2", translate("WPA2-EAP"), {mode="ap"}, {mode="ap-wds"})
end
	encr.description = translate("WPA-Encryption requires wpa_supplicant (for client mode) or hostapd (for AP and ad-hoc mode) to be installed.")
elseif not hostapd and supplicant then
	encr:value("psk", translate("WPA-PSK"), {mode="sta"}, {mode="sta-wds"})
	encr:value("psk2", translate("WPA2-PSK"), {mode="sta"}, {mode="sta-wds"})
	encr:value("psk-mixed", translate("WPA-PSK/WPA2-PSK mixed mode"), {mode="sta"}, {mode="sta-wds"})
	if has_sta_eap then
		encr:value("wpa", translate("WPA-EAP"), {mode="sta"}, {mode="sta-wds"})
		encr:value("wpa2", translate("WPA2-EAP"), {mode="sta"}, {mode="sta-wds"})
	end
	encr.description = translate("WPA-Encryption requires wpa_supplicant (for client mode) or hostapd (for AP and ad-hoc mode) to be installed.")
else
	encr.description = translate("WPA-Encryption requires wpa_supplicant (for client mode) or hostapd (for AP and ad-hoc mode) to be installed.")
end


auth_server = s:taboption("encryption", Value, "auth_server", translate("Radius-Authentication-Server"))
auth_server:depends({mode="ap", encryption="wpa"})
auth_server:depends({mode="ap", encryption="wpa2"})
auth_server:depends({mode="ap-wds", encryption="wpa"})
auth_server:depends({mode="ap-wds", encryption="wpa2"})
auth_server.rmempty = true
auth_server.datatype = "host"

auth_port = s:taboption("encryption", Value, "auth_port", translate("Radius-Authentication-Port"), translatef("Default %d", 1812))
auth_port:depends({mode="ap", encryption="wpa"})
auth_port:depends({mode="ap", encryption="wpa2"})
auth_port:depends({mode="ap-wds", encryption="wpa"})
auth_port:depends({mode="ap-wds", encryption="wpa2"})
auth_port.rmempty = true
auth_port.datatype = "port"

auth_secret = s:taboption("encryption", Value, "auth_secret", translate("Radius-Authentication-Secret"))
auth_secret:depends({mode="ap", encryption="wpa"})
auth_secret:depends({mode="ap", encryption="wpa2"})
auth_secret:depends({mode="ap-wds", encryption="wpa"})
auth_secret:depends({mode="ap-wds", encryption="wpa2"})
auth_secret.rmempty = true
auth_secret.password = true

acct_server = s:taboption("encryption", Value, "acct_server", translate("Radius-Accounting-Server"))
acct_server:depends({mode="ap", encryption="wpa"})
acct_server:depends({mode="ap", encryption="wpa2"})
acct_server:depends({mode="ap-wds", encryption="wpa"})
acct_server:depends({mode="ap-wds", encryption="wpa2"})
acct_server.rmempty = true
acct_server.datatype = "host"

acct_port = s:taboption("encryption", Value, "acct_port", translate("Radius-Accounting-Port"), translatef("Default %d", 1813))
acct_port:depends({mode="ap", encryption="wpa"})
acct_port:depends({mode="ap", encryption="wpa2"})
acct_port:depends({mode="ap-wds", encryption="wpa"})
acct_port:depends({mode="ap-wds", encryption="wpa2"})
acct_port.rmempty = true
acct_port.datatype = "port"

acct_secret = s:taboption("encryption", Value, "acct_secret", translate("Radius-Accounting-Secret"))
acct_secret:depends({mode="ap", encryption="wpa"})
acct_secret:depends({mode="ap", encryption="wpa2"})
acct_secret:depends({mode="ap-wds", encryption="wpa"})
acct_secret:depends({mode="ap-wds", encryption="wpa2"})
acct_secret.rmempty = true
acct_secret.password = true

wpakey = s:taboption("encryption", Value, "_wpa_key", translate("Key"))
wpakey:depends("encryption", "psk")
wpakey:depends("encryption", "psk2")
wpakey:depends("encryption", "psk+psk2")
wpakey:depends("encryption", "psk-mixed")
wpakey.datatype = "wpakey"
-- wpakey.rmempty = false
wpakey.default = "12345678"
wpakey.password = true

function wpakey.validate(self, value, section)
	--keywpa = luci.http.formvalue("cbid.wireless.cfg033579._wpa_key")
	if #value > 0 then
		return value
	else
		return nil, translate("The value is invalid because WPA key can not be empty.")
	end
end

wpakey.cfgvalue = function(self, section, value)
	local key = m.uci:get("wireless", section, "key")
	if key == "1" or key == "2" or key == "3" or key == "4" then
		return nil
	end
	return key
end

wpakey.write = function(self, section, value)
	self.map.uci:set("wireless", section, "key", value)
	self.map.uci:delete("wireless", section, "key1")
end


wepslot = s:taboption("encryption", ListValue, "_wep_key", translate("Used key slot"), translate("String\\'s slot that will be used for encryption"))
wepslot:depends("encryption", "wep-open")
wepslot:depends("encryption", "wep-shared")
wepslot:value("1", translatef("Key #%d", 1))
wepslot:value("2", translatef("Key #%d", 2))
wepslot:value("3", translatef("Key #%d", 3))
wepslot:value("4", translatef("Key #%d", 4))

wepslot.cfgvalue = function(self, section)
	local slot = tonumber(m.uci:get("wireless", section, "key"))
	if not slot or slot < 1 or slot > 4 then
		return 1
	end
	return slot
end

wepslot.write = function(self, section, value)
	self.map.uci:set("wireless", section, "key", value)
end

local slot
for slot=1,4 do
	wepkey = s:taboption("encryption", Value, "key" .. slot, translatef("Key #%d", slot), translate("String that will be used as a key for encryption"))
	wepkey:depends("encryption", "wep-open")
	wepkey:depends("encryption", "wep-shared")
	wepkey.datatype = "wepkey"
	wepkey.rmempty = true
	wepkey.password = true

	function wepkey.write(self, section, value)
		if value and (#value == 5 or #value == 13) then
			value = "s:" .. value
		end
		return Value.write(self, section, value)
	end
end

nasid = s:taboption("encryption", Value, "nasid", translate("NAS ID"))
nasid:depends({mode="ap", encryption="wpa"})
nasid:depends({mode="ap", encryption="wpa2"})
nasid:depends({mode="ap-wds", encryption="wpa"})
nasid:depends({mode="ap-wds", encryption="wpa2"})
nasid.rmempty = true

eaptype = s:taboption("encryption", ListValue, "eap_type", translate("EAP method"))
eaptype:value("tls",  translate("TLS"))
eaptype:value("ttls", translate("TTLS"))
eaptype:value("peap", translate("PEAP"))
eaptype:depends({mode="sta", encryption="wpa"})
eaptype:depends({mode="sta", encryption="wpa2"})
eaptype:depends({mode="sta-wds", encryption="wpa"})
eaptype:depends({mode="sta-wds", encryption="wpa2"})

cacert = s:taboption("encryption", FileUpload, "ca_cert", translate("Path to CA-Certificate"))
cacert:depends({mode="sta", encryption="wpa"})
cacert:depends({mode="sta", encryption="wpa2"})
cacert:depends({mode="sta-wds", encryption="wpa"})
cacert:depends({mode="sta-wds", encryption="wpa2"})

clientcert = s:taboption("encryption", FileUpload, "client_cert", translate("Path to client certificate"))
clientcert:depends({mode="sta", encryption="wpa"})
clientcert:depends({mode="sta", encryption="wpa2"})
clientcert:depends({mode="sta-wds", encryption="wpa"})
clientcert:depends({mode="sta-wds", encryption="wpa2"})

privkey = s:taboption("encryption", FileUpload, "priv_key", translate("Path to private key"))
privkey:depends({mode="sta", eap_type="tls", encryption="wpa2"})
privkey:depends({mode="sta", eap_type="tls", encryption="wpa"})
privkey:depends({mode="sta-wds", eap_type="tls", encryption="wpa2"})
privkey:depends({mode="sta-wds", eap_type="tls", encryption="wpa"})

privkeypwd = s:taboption("encryption", Value, "priv_key_pwd", translate("Password of private key"))
privkeypwd:depends({mode="sta", eap_type="tls", encryption="wpa2"})
privkeypwd:depends({mode="sta", eap_type="tls", encryption="wpa"})
privkeypwd:depends({mode="sta-wds", eap_type="tls", encryption="wpa2"})
privkeypwd:depends({mode="sta-wds", eap_type="tls", encryption="wpa"})


auth = s:taboption("encryption", Value, "auth", translate("Authentication"))
auth:value("PAP")
auth:value("CHAP")
auth:value("MSCHAP")
auth:value("MSCHAPV2")
auth:depends({mode="sta", eap_type="peap", encryption="wpa2"})
auth:depends({mode="sta", eap_type="peap", encryption="wpa"})
auth:depends({mode="sta", eap_type="ttls", encryption="wpa2"})
auth:depends({mode="sta", eap_type="ttls", encryption="wpa"})
auth:depends({mode="sta-wds", eap_type="peap", encryption="wpa2"})
auth:depends({mode="sta-wds", eap_type="peap", encryption="wpa"})
auth:depends({mode="sta-wds", eap_type="ttls", encryption="wpa2"})
auth:depends({mode="sta-wds", eap_type="ttls", encryption="wpa"})

identity = s:taboption("encryption", Value, "identity", translate("Identity"))
identity:depends({mode="sta", eap_type="peap", encryption="wpa2"})
identity:depends({mode="sta", eap_type="peap", encryption="wpa"})
identity:depends({mode="sta", eap_type="ttls", encryption="wpa2"})
identity:depends({mode="sta", eap_type="ttls", encryption="wpa"})
identity:depends({mode="sta-wds", eap_type="peap", encryption="wpa2"})
identity:depends({mode="sta-wds", eap_type="peap", encryption="wpa"})
identity:depends({mode="sta-wds", eap_type="ttls", encryption="wpa2"})
identity:depends({mode="sta-wds", eap_type="ttls", encryption="wpa"})

password = s:taboption("encryption", Value, "password", translate("Password"))
password:depends({mode="sta", eap_type="peap", encryption="wpa2"})
password:depends({mode="sta", eap_type="peap", encryption="wpa"})
password:depends({mode="sta", eap_type="ttls", encryption="wpa2"})
password:depends({mode="sta", eap_type="ttls", encryption="wpa"})
password:depends({mode="sta-wds", eap_type="peap", encryption="wpa2"})
password:depends({mode="sta-wds", eap_type="peap", encryption="wpa"})
password:depends({mode="sta-wds", eap_type="ttls", encryption="wpa2"})
password:depends({mode="sta-wds", eap_type="ttls", encryption="wpa"})

------------------- WRP100 configuration ---------------------------------------
local mapWRP, secWRP, opWRP, deathTrap = false

mapWRP = Map("wifid")

secWRP = mapWRP:section(NamedSection, "default_server", "wifid", translate("WRP100 Configuration"))
secWRP.addremove = false

opWRP = secWRP:option(Flag, "enabled", translate("Connect WRP100 automatically"), translate("Let Teltonika WRP100 wireless repeater connect to this router automatically"))
opWRP.rmempty = false

function opWRP.write(self, section, value)
	if not deathTrap then
		deathTrap = true
	else
		return
	end
	Value.write(self, section, value)
	luci.sys.call("/etc/init.d/wifid stop")
end

function mapWRP.on_after_commit(map)
	enabledFlag = mapWRP:formvalue("cbid.wifid.default_server.enabled")
	if enabledFlag == "1" then
		luci.sys.call("/etc/init.d/wifid start")
	end
end

return m, mapWRP
