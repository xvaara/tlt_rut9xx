local sys = require "luci.sys"
local dsp = require "luci.dispatcher"
local utl = require "luci.util"

local m, s, o

arg[1] = arg[1] or ""

m = Map("gps", translate("GPS Data Configuration"))

m.redirect = dsp.build_url("admin/services/gps/mode")
if m.uci:get("gps", arg[1]) ~= "rule" then
	luci.http.redirect(dsp.build_url("admin/services/gps/mode"))
	return
end

s = m:section(NamedSection, arg[1], "rule", "")
s.anonymous = true
s.addremove = false

--ft.opt_enabled(s, Button)
o = s:option(Flag, "enabled", translate("Enable"), translate("To enable input configuration"))
o.rmempty = false

o = s:option(ListValue, "wan", translate("WAN"), translate("Select type on your own intended configuration"))
o:value("mobile", translate("Mobile"))
o:value("wifi", translate("WiFi"))
o:value("wired", translate("Wired"))

o = s:option(ListValue, "type", translate("Type"), translate("Select type on your own intended configuration"))
o:depends("wan", "mobile")
o:value("home", translate("Home"))
o:value("roaming", translate("Roaming"))
o:value("both", translate("Both"))
o.rmempty = false

o = s:option(ListValue, "din2", translate("Digital Isolated Input"), translate("Select type on your own intended configuration"))
o:value("low", translate("Low logic level"))
o:value("high", translate("High logic level"))
o:value("both", translate("Both"))

o = s:option(Value, "min_period", translate("Min period"), translate(""))
o.default = "5"
o.datatype = "range(0,999999)"

o = s:option(Value, "min_distance", translate("Min distance"), translate(""))
o.default = "200"
o.datatype = "range(0,999999)"

o = s:option(Value, "min_angle", translate("Min angle"), translate(""))
o.default = "30"
o.datatype = "range(0,999999)"

o = s:option(Value, "min_saved_record", translate("Min saved records"), translate(""))
o.default = "20"
o.datatype = "range(0,999999)"

o = s:option(Value, "send_period", translate("Send period"), translate(""))
o.default = "50"
o.datatype = "range(0,999999)"

local gps_enable = m.uci:get("gps",  arg[1], ".enabled") or "0"
function m.on_commit()
	--Delete all usr_enable from ioman config
	local gpsEnable = m:formvalue("cbid.gps." .. arg[1] .. ".enabled") or "0"
	if gpsEnable ~= gps_enable then
		m.uci:foreach("gps", "rule", function(s)
			local usr_enable = s.usr_enable or ""
			gps_inst2 = s[".name"] or ""
			if usr_enable == "1" then
				m.uci:delete("gps", gps_inst2 , "usr_enable")
			end
		end)
	end
	m.uci:save("gps")
	m.uci.commit("gps")
end

return m
