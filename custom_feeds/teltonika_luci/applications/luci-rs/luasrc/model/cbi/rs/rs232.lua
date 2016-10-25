local function cecho(string)
	luci.sys.call("echo \"" .. string .. "\" >> /tmp/log.log")
end

local util = require "luci.util"
local uci = require "luci.model.uci".cursor()

m = Map("rs", translate("RS232 Configuration"))

sys = m:section(TypedSection, "rs232", translate("RS232 Serial Configuration"))
sys.addremove = false
sys.anonymous = true

o = sys:option(Flag, "enabled", translate("Enabled"), translate("Check to enable RS232 serial configuration"))


o = sys:option(ListValue, "baudrate", translate("Baud rate"), translate("Select supported baud rate"))
o:value("300", "300")
o:value("1200", "1200")
o:value("2400", "2400")
o:value("4800", "4800")
o:value("9600", "9600")
o:value("19200", "19200")
o:value("38400", "38400")
o:value("57600", "57600")
o:value("115200", "115200")
o.default = 115200

dbit = sys:option(ListValue, "databits", translate("Data bits"), translate("Select how many bits will be used for character"))
dbit:value("5", "5")
dbit:value("6", "6")
dbit:value("7", "7")
dbit:value("8", "8")
dbit.default = "8"

p = sys:option(ListValue, "parity", translate("Parity"), translate("Select what kind of parity bit to use for error detection"))
p:value("none", translate("None"))
p:value("odd", translate("Odd"))
p:value("even", translate("Even"))
p.default = none


sbit = sys:option(ListValue, "stopbits", translate("Stop bits"), translate("Select how many stop bits will be used to detect the end of character"))
sbit:value("1", "1")
sbit:value("2", "2")
sbit.default = 1

fl = sys:option(ListValue, "flowcontrol", translate("Flow control"), translate("Select what kind of characters to use for flow control"))
fl:value("none", "None")
fl:value("rts/cts", "RTS/CTS")
fl:value("xon/xoff", "Xon/Xoff")
fl.default = "none"

styp = sys:option(ListValue, "type", translate("Serial type"), translate("Select function of serial interface"))
styp:value("console", translate("Console"))
styp:value("overip", translate("Over IP"))
styp:value("modem", translate("Modem"))
styp:value("modbus", translate("Modbus gateway"))

wan=luci.sys.exec(". /lib/teltonika-functions.sh; tlt_get_wan_ipaddr")
lan=luci.sys.exec("uci get -q network.lan.ipaddr")
mi = sys:option(Value, "modbus_ip", translate("Listening IP"), translate("IP address on which Modbus Gateway should listen for incoming connections."))
mi:depends("type","modbus")
mi:value("0.0.0.0")
if lan ~= nil then
	mi:value(lan)
end
if wan ~= nil then
	mi:value(wan)
end
mi.datatype = "ip4addr"
mi.default = "0.0.0.0"

mp = sys:option(Value, "modbus_port", translate("Port"), translate("Port number for Modbus Gateway."))
mp:depends("type","modbus")
mp.datatype = "port"
mp.default = "502"

ms = sys:option(ListValue, "slave_id_config", translate("Slave ID configuration type"), translate("Redirects ModBus TCP to RTU"));
ms:depends("type", "modbus")
ms:value("single", translate("User defined"))
ms:value("multiple", translate("Obtained from TCP"))
ms.default = "single"

mid = sys:option(Value, "multi_slave_id", translate("Permitted slave IDs"), translate("Redirect packets whose slave IDs is on the list. Individual IDs are separated by \',\' (comma) and range is specifed by \'-'\ (hyphen)"))
mid:depends("slave_id_config", "multiple")
mid.default = "1-247"
function mid.validate(self, value)
		
		for i = 1, #value do
        	        local c = value:byte(i)
                	if (i == 1 or i == value:len()) and (c == 44 or c == 45) then
                        	return nil
	                end
        	        if c ~= 44 and c ~= 45 and c < 48 and c > 57 then
                	        return nil
	                end
        	end
	        	
        	return value
end

smid = sys:option(Value, "single_slave_id", translate("Slave ID"), translate("Redirect packets to Modbus slave ID"))
smid:depends("slave_id_config", "single")
smid.default = "1"
function smid.validate(self, value)
	
		local number = tonumber(value)
		if number ~= nil then
			if number >= 1 and number <= 247 then
				return value
			end
		end
		return nil
end

prot = sys:option(ListValue, "protocol", translate("Protocol"), translate("Select which protocol to use for data transmission"))
prot:value("tcp", translate("TCP"))
prot:value("udp", translate("UDP"))
prot:depends("type","overip")

mo = sys:option(ListValue, "mode", translate("Mode"), translate("Select mode to apply for router"))
mo:value("server", translate("Server"))
mo:value("client", translate("Client"))
mo:value("bidirect", translate("Bidirect"))
mo:depends("type","overip")

o = sys:option(Flag, "no_leading_zeros", translate("No leading zeros"), translate("Check this to skip hex first zeros"))
o.rmempty = false
o:depends("type","overip") 

o = sys:option(DummyValue, "getinfo", translate("Client settings:"), translate(""))
-- o:depends("mode","client")
o:depends("mode","bidirect")

addr = sys:option(Value, "ip_connect", translate("Server Address"), translate("Specify server address which client have to connect"))
addr:depends("mode","client")
addr:depends("mode","bidirect")
addr.datatype = "host"

tp = sys:option(Value, "port_connect", translate("TCP port"), translate("Specify port number for the connectivity establishment"))
tp:depends("mode","client")
tp:depends("mode","bidirect")
tp.datatype = "port"

ali= sys:option(Value, "recon_interval", translate("Reconnect interval (s)"), translate("Specify intervals connection to server if it fails"))
ali:depends("mode","client")
ali:depends("mode","bidirect")
ali.datatype = "integer"

o = sys:option(DummyValue, "getinfo2", translate("Server settings:"), translate(""))
-- o:depends("mode","server")
o:depends("mode","bidirect")

tp = sys:option(Value, "port_listen", translate("TCP port"), translate("Specify port number for server to listen"))
tp:depends("mode","server")
tp:depends("mode","bidirect")
tp.datatype = "port"

ali= sys:option(Value, "timeout", translate("Timeout (s)"), translate("Disconnect client if not active connection"))
ali:depends("mode","server")
ali:depends("mode","bidirect")
ali.datatype = "integer"

ali= sys:option(ListValue, "gpio", translate("Output"), translate("Output to manage"))
ali:depends("mode","bidirect")
ali:value("56", translate("OC Output"))
ali:value("57", translate("Relay Output"))

ali= sys:option(ListValue, "gpiostate", translate("Output state"), translate("Default output state value, then start application"))
ali:depends("mode","bidirect")
ali:value("0", translate("0"))
ali:value("1", translate("1"))

aa = sys:option(Value, "direct_connect", translate("Direct connect"), translate("Enter hostname:port to maintain constant connection to specified host. Leave empty to use ATD command to initiate connection"))
aa:depends("type","modem")

aa = sys:option(Value, "modem_port", translate(" TCP port"), translate("Specify port to listen for incomming connections. Leave empty to disable incomming connections"))
aa:depends("type","modem")
aa.datatype = "port"

s = m:section(TypedSection, "ip_filter_rs232", translate(""))
s.template = "cbi/tblsection"
s.addremove = true
s.anonymous = true
s.template_addremove = "rs/add_interface_rule"

function s.create(self, section)
	local a = m:formvalue("_newinput.action")
	local add = m:formvalue("cbi-ip_filter_rs232")
	exist = 0
	if add then
		uci:foreach("rs", "ip_filter_rs232", function(s)
			if s.interface == a then
				exist = 1
			end
		end)
		if exist == 0 then
			created = TypedSection.create(self, section)
			self.map:set(created, "interface", a)
		end
	end
	uci:commit("rs")

end

d = s:option(DummyValue, "interface", translate("Interface"), translate(""))
function d.cfgvalue(self, s)
	local z = self.map:get(s, "interface")
	if z == "lan" then
		return translate("LAN")
	elseif z == "wan" then
		return translate("WAN")
	elseif z == "vpn" then
		return translate("VPN")
	end
end

p = s:option(DynamicList, "allow_ip", translate("Allow IP"), translate("Allow ip connecting to server"))
p.datatype = "ipaddr"

return m
