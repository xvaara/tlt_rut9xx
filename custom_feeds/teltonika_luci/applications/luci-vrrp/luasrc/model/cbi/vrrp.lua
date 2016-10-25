
m = Map("vrrpd", translate("VRRP Configuration"))

s = m:section( NamedSection, "vid1","vrrpd",  translate("VRRP LAN Configuration Settings"))
s.anonymous = true
s.addremove = false

o = s:option( Flag, "enabled", translate("Enable"), translate("Enable VRRP (Virtual Router Redundancy Protocol) for LAN"))
o.rmempty = false
o.default = "0"

-- local id = s:option(Value, "virtual_id", translate("ID"), translate("ID of the virtual server, range [1 - 255]"))
-- id.datatype = "range(1,255)"
-- id.default = "1"

ip = s:option( DynamicList, "virtual_ip", translate("IP address"), translate("Virtual IP address(es) for LAN\\'s VRRP (Virtual Router Redundancy Protocol) cluster"))
ip.datatype = "ip4addr"
id = s:option( Value, "virtual_id", translate("Virtual ID"), translate("Routers with same IDs will be grouped in the same VRRP (Virtual Router Redundancy Protocol) cluster, range [1 - 255]"))
id.datatype = "range(1,255)"
id.default = "1"

prior = s:option( Value, "priority", translate("Priority"), translate("Router with highest priority value on the same VRRP (Virtual Router Redundancy Protocol) cluster will act as a master, range [1 - 255]"))
prior.datatype = "range(1,255)"
prior.default = "100"

-- local interval = s:option( Value, "delay", translate("Advertisement interval"), translate("(in seconds)"))
-- interval.default = "1"

-- s1 = m:section( NamedSection, "vid2","vrrpd", translate("VRRP WAN Configuration Settings"))
-- 
-- o = s1:option( Flag, "enabled", translate("Enable"), translate("Enable VRRP (Virtual Router Redundancy Protocol) for WAN"))
-- o.rmempty = false
-- o.default = "0"
-- 
-- -- local id = s:option(Value, "virtual_id", translate("ID"), translate("ID of the virtual server, interval [1 - 255]"))
-- -- id.datatype = "range(1,255)"
-- -- id.default = "1"
-- 
-- ip = s1:option( DynamicList, "virtual_ip", translate("IP address"), translate("Virtual IP address(es) for WAN\\'s VRRP (Virtual Router Redundancy Protocol) cluster"))
-- ip.datatype = "ip4addr"
-- id = s1:option( Value, "virtual_id", translate("Virtual ID"), translate("Routers with same IDs will be grouped in the same VRRP (Virtual Router Redundancy Protocol) cluster, range [1 - 255])"))
-- id.datatype = "range(1,255)"
-- id.default = "2"
-- 
-- prior = s1:option( Value, "priority", translate("Priority"), translate("Router with highest priority value on the same VRRP (Virtual Router Redundancy Protocol) cluster will act as a master, range [1 - 255]"))
-- prior.datatype = "range(1,255)"
-- prior.default = "100"

-- local interval = s:option( Value, "delay", translate("Advertisement interval"), translate("(in seconds)"))
-- interval.default = "1"

s2 = m:section( NamedSection, "ping","vrrpd", translate("Check Internet Connection"))

o = s2:option( Flag, "enabled", translate("Enable"), translate("Check to enable internet connection checking"))
o.rmempty = false
o.default = "0"

host = s2:option( Value, "host", translate("Ping IP address"), translate("e.g. 192.168.1.1 (or www.host.com if DNS server configured correctly)"))

interval = s2:option( Value, "interval", translate("Ping interval"), translate("Time interval in seconds between two pings"))
interval.datatype = "integer"
interval.default = "10"

t_out = s2:option( Value, "time_out", translate("Ping timeout (sec)"), translate("Specify time to receive ping, range [1-9999]"))
t_out.datatype = "integer"
t_out.default = "1"

size = s2:option( Value, "packet_size", translate("Ping packet size"), translate("Ping packet size, range [0-1000]"))
size.datatype = "integer"

retry = s2:option( Value, "retry", translate("Ping retry count"), translate("Number of time trying to send ping to a server after time interval if echo receive was unsuccessful, range [1-9999]"))
retry.datatype = "integer"


return m
