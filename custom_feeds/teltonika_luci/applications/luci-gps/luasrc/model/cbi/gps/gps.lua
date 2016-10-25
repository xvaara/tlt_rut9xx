local m, agent, sys,  o


local function cecho(string)
	luci.sys.call("echo \"" .. string .. "\" >> /tmp/log.log")
end

m = Map("gps", translate("GPS Configuration"))

agent = m:section(TypedSection, "gps", translate("GPS Settings"))
agent.addremove = false
agent.anonymous = true
agent.add_template = "gps/gps"

-----------------
-- enable/disable
-----------------
o = agent:option(Flag, "enabled", translate("Enable GPS service"), translate("By enabling it will start generate your location coordinates"))
o.forcewrite = true
o.rmempty = false

o = agent:option(Flag, "gps_data", translate("Enable GPS data to server"), translate("By enabling it will start generate your location coordinates"))
o.forcewrite = true
o.rmempty = false

s = agent:option(Value, "ip", translate("IP address"), translate("Insert IP address"))
s.datatype = "ipaddr"

s = agent:option(Value, "port", translate("Port"), translate("Insert port"))
s.datatype = "port"

s = agent:option(Value, "seconds", translate("Seconds"), translate("Insert seconds"))
s.datatype = "range(0,9999999)"

s = agent:option(ListValue, "proto", translate("Protocol"), translate("Insert protocol"))
s:value("tcp", translate("TCP"))
s:value("udp", translate("UDP"))

return m
