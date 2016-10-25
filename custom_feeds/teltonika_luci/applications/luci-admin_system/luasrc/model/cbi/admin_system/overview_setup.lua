m2 = Map("overview", translate("Overview Page Configuration"), 
	translate(""))
m2.addremove = false
local utl = require "luci.util"
local nw = require "luci.model.network"
local sys = require "luci.sys"
local ntm = require "luci.model.network".init()
local bus = require "ubus"
local _ubus = bus.connect()
local _ubus = bus.connect()
local uci = require "luci.model.uci".cursor()
function getParam(string)
	local h = io.popen(string)
	local t = h:read()
	h:close()
	return t
end

local function debug(string, ...)
	luci.sys.call(string.format("/usr/bin/logger -t Webui \"%s\"", string.format(string, ...)))
end

sc = m2:section(NamedSection, "show","status", translate("Overview Tables"))
if luci.tools.status.show_mobile() then
	enb_block = sc:option(Flag, "mobile", translate("Mobile"), translate(""))
		enb_block.rmempty = false
	enb_block = sc:option(Flag, "sms_counter", translate("SMS counter"), translate(""))
		enb_block.rmempty = false
end

enb_block = sc:option(Flag, "system", translate("System"), translate(""))
enb_block.rmempty = false
enb_block = sc:option(Flag, "wireless", translate("Wireless"), translate(""))
enb_block.rmempty = false
enb_block = sc:option(Flag, "wan", translate("WAN"), translate(""))
enb_block.rmempty = false
enb_block = sc:option(Flag, "local_network", translate("Local network"), translate(""))
enb_block.rmempty = false
enb_block = sc:option(Flag, "access_control", translate("Access control"), translate(""))
enb_block.rmempty = false
enb_block = sc:option(Flag, "system_events", translate("Recent system events"), translate(""))
enb_block.rmempty = false
enb_block = sc:option(Flag, "network_events", translate("Recent network events"), translate(""))
enb_block.rmempty = false

uci:foreach("network", "interface",
	function (section)
		local ifname = uci:get(
			"network", section[".name"], "ifname"
		)
		local metric = uci:get(
			"network", section[".name"], "metric"
		)
		local info1
		local string1
		if "usb0" == ifname then
			string1 = "network.interface." .. tostring(section[".name"])
			info1 = _ubus:call(string1, "status", { })
			
			if info1 and info1['ipv4-address'] then
				local a
				for _, a in ipairs(info1['ipv4-address']) do
					if a.address  then
						enb_block = sc:option(Flag, "wimax", translate("Wimax"), translate(""))
						enb_block.rmempty = false
						debug(tostring(a.address))
					end
				end
			end
		end
	end
)

local open_vpns = luci.sys.exec("cat /etc/config/openvpn")
for line in open_vpns:gmatch("[^\r\n]+") do
	if line:find("config openvpn '") then
		if line ~= "config openvpn 'teltonika_auth_service'" then
			enb_block = sc:option(Flag, "open_vpn_"..string.gsub(string.gsub(line,"config openvpn '",""),"'",""), translate(string.gsub(string.gsub(line,"config openvpn '",""),"'","").. " VPN"), translate(""))
			enb_block.rmempty = false
		end
	end
end

local info = _ubus:call("network.wireless", "status", { })
local interfaces = info.radio0.interfaces
for i, net in ipairs(interfaces) do
	hotspot_id = uci:get("wireless", net.section, "hotspotid") or ""
	if hotspot_id ~= "" then
		enb_block = sc:option(Flag, hotspot_id, translate(net.config.ssid.." Hotspot"), translate(""))
		enb_block.rmempty = false
	end

end
enb_block = sc:option(Flag, "vrrp", translate("VRRP"), translate(""))
enb_block.rmempty = false
enb_block = sc:option(Flag, "monitoring", translate("Monitoring"), translate(""))                                                                                         
enb_block.rmempty = false



 
return m2
