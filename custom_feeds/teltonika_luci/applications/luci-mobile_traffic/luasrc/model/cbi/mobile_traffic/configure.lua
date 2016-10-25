local utl = require "luci.util"
local sys = require "luci.sys"
local moduleVidPid = utl.trim(sys.exec("uci get system.module.vid")) .. ":" .. utl.trim(sys.exec("uci get system.module.pid"))
local sim_switch = utl.trim(sys.exec("uci get simcard.rules.switchdata"))

function fileExists(path, name)
	local string = "ls ".. path
	local h = io.popen(string)
	local t = h:read("*all")
	h:close()

	for i in string.gmatch(t, "%S+") do
		if i == name then
			return 1
		end
	end
end

m = Map("mdcollectd", translate("Mobile Traffic Usage Logging"), translate(""))
m.addremove = false

s = m:section(NamedSection, "config", "mdcollectd");
s.addremove = false

o = s:option(Flag, "traffic", translate("Enable"), translate('Check to enable mobile traffic usage logging (can not be disabled if SIM switch is enabled)'))
o.rmempty = false

o = s:option(Value, "interval", translate("Interval between records (sec)"), translate("The interval between logging records (minimum 60s)"))
o.datatype = "min(60)"
o.rmempty = false

return m

