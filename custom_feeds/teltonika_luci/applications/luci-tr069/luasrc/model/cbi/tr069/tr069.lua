local m
local uci = require "luci.model.uci".cursor()

m = Map("easycwmp", translate("TR-069 Client Configuration"), 
	translate(""))
m.addremove = false

sc = m:section(TypedSection, "acs", translate("TR-069 Parameters Configuration"))

enb_block = sc:option(Flag, "periodic_enable", translate("Enable"), translate("Enables TR-069 client periodic data transmission to TR-069 server"))
enb_block.rmempty = false

serv_r = sc:option(Flag, "server_request", translate("Accept server request"), translate(""))
serv_r.rmempty = false

function serv_r.write(self, section, value)
	m.uci:set("firewall", "TR069", "enabled", value)
	m.uci:save("firewall")
end

function serv_r.cfgvalue(self, section)
	value = m.uci:get("firewall", "TR069", "enabled")
	return value
end

o = sc:option(Value, "periodic_interval", translate("Sending Interval"), translate("Periodic data transmission interval (allowed: 60s-9999999s)"))
o.datatype = "range(60,9999999)"
o.default = "100"

o = sc:option(Value, "username", translate("User name"), translate("User name for authentication on TR-069 server. Allowed characters (a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. )"))
o.datatype = "fieldvalidation('^[a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. ]+$',0)"

o = sc:option(Value, "password", translate("Password"), translate("Password for authentication on TR-069 server. Allowed characters (a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. )"))
o.password = true
o.datatype = "fieldvalidation('^[a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. ]+$',0)"

o = sc:option(Value, "url", translate("URL"), translate("TR-069 server's URL to send data to"))
o.default = "http://192.168.1.110:8080/openacs/acs"

return m
