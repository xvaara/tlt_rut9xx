local m, agent, sys,  o

luci.util   = require "luci.util"

local function cecho(string)
	luci.sys.call("echo \"" .. string .. "\" >> /tmp/log.log")
end

m = Map("gps", translate("GPS Configuration"))

agent = m:section(TypedSection, "gps", translate("GPS Settings"))
agent.addremove = false
agent.anonymous = true

-----------------
-- enable/disable
-----------------
o = agent:option(Flag, "enabled", translate("Enable GPS service"), translate("By enabling it will start generate your location coordinates"))
o.forcewrite = true
o.rmempty = false

o = agent:option(Flag, "enabled_server", translate("Enable GPS Data to server"), translate("By enabling it will start generate your location coordinates and transfer them to specified server"))
o.forcewrite = true
o.rmempty = false

s = agent:option(Value, "ip", translate("Remote host/IP address"), translate("Server IP address or domain name to send coordinates to"))
--s.datatype = "ipaddr"

s = agent:option(Value, "port", translate("Port"), translate("Server port used for data transfer"))
s.datatype = "port"

s = agent:option(ListValue, "proto", translate("Protocol"), translate("Protocol to be used for coordinates data transfer to server"))
s:value("tcp", translate("TCP"))
s:value("udp", translate("UDP"))

--find all storage where are sda
local mnt =  luci.util.trim(luci.sys.exec("ls -1 /mnt"))
mnt = tostring(mnt)
local mntList = mnt:split("\n")

--SDA masyvas su visais sda pavadinimais
local sdaTable = {}
for i=1, #mntList do
	sdaTable[i] = "/mnt/"..mntList[i]
end

local got_available_dir = 0

for i=1, #sdaTable do
		dir=sdaTable[i]:sub(1,13)
		if dir ~= "/mnt/mtdblock" then
			got_available_dir = 1
		end
end

if got_available_dir == 1 then
	s = agent:option(ListValue, "storage", translate("Storage directory"), translate("Directory to store data"))
	s:value("", translate("Disable storing"))
	
	for i=1, #sdaTable do
		dir=sdaTable[i]:sub(1,13)
		if dir ~= "/mnt/mtdblock" then
			s:value(sdaTable[i], translate(sdaTable[i]))
		end
	end
end

return m
