local sys = require("luci.sys")
local dsp = require "luci.dispatcher"
local utl = require ("luci.util")

local VPN_INST

local function cecho(string)
	luci.sys.call("echo \"vpn: " .. string .. "\" >> /tmp/log.log")
end

if arg[1] then
	VPN_INST = arg[1]
else
	return nil
end

local mode, o

local m = Map("gre_tunnel", translatef("GRE Tunnel Instance: %s", VPN_INST:gsub("^%l", string.upper)), "")

m.redirect = dsp.build_url("admin/services/vpn/gre-tunnel/")

local s = m:section( NamedSection, VPN_INST, "gre_tunnel", translate("Main Settings"), "")

e = s:option(Flag, "enabled", translate("Enabled"), translate("Enable GRE (Generic Routing Encapsulation) tunnel."))
	e.rmempty = false

k = s:option(Value, "remote_ip", translate("Remote endpoint IP address"), translate("IP address of the remote GRE tunnel device."))
	k.datatype = "ip4addr"

remote_network = s:option(Value, "remote_network", translate("Remote network"), translate("IP address of LAN network on the remote device."))
	remote_network.datatype = "ipaddr"

remote_netmask = s:option(Value, "remote_netmask", translate("Remote network netmask"),translate("Netmask of LAN network on the remote device. Range [0 - 32]."))
	remote_netmask.datatype ="range(0,32)"

	function remote_netmask:validate(Value)
		local txtip = tostring(m:formvalue("cbid.gre_tunnel." .. VPN_INST .. ".remote_network"))
		--local remote_ip = route_ip:formvalue(section)
		local networkip = tostring(luci.util.exec("ipcalc.sh ".. txtip .." ".. Value .." |grep NETWORK= | cut -d'=' -f2 | tr -d ''"))
		networkip = networkip:match("[%w%.]+")
		if txtip == networkip then
			return Value
		else
			m.message = translatef("err: To match specified netmask, Remote network IP address should be %s", networkip);
			return nil
		end
		return Value
	end


t = s:option(Value, "tunnel_ip", translate("Local tunnel IP"), translate("Local virtual IP address. Can not be in the same subnet as LAN network."))
	t.datatype = "ipaddr"

l = s:option(Value, "tunnel_netmask", translate("Local tunnel netmask"),translate("Netmask of local virtual IP address. Range [0 - 32]."))
	l.datatype ="range(0,32)"

-- mtu
n = s:option(Value, "mtu", translate("MTU"),translate("MTU (Maximum Transmission Unit) for tunnel connection. Range [0 - 1500]."))
	n.datatype = "range(0,1500)"
	n.default = "1476"

-- ttl
v = s:option(Value, "ttl", translate("TTL"),translate("TTL (Time To Live) for tunnel connection. Range [0 - 255]."))
	v.datatype ="range(0,255)"

-- pmtud
o = s:option(Flag, "pmtud", translate("PMTUD"), translate("Enable PMTUD (Path Maximum Transmission Unit Discovery) technique for this tunnel."))

-- keepalive
p = s:option(Flag, "keepalive", translate("Enable Keep alive"), translate("Enable Keep Alive."))

r = s:option(Value, "keepalive_host", translate("Keep Alive host"), translate("Keep Alive host IP address. Preferably IP address which belongs to the LAN network on the remote device."))
	r.datatype = "ipaddr"

s = s:option(Value, "keepalive_interval", translate("Keep Alive interval"),translate("Time interval for Keep Alive in seconds. Range [0 - 255]."))
	s.datatype = "range(0,255)"

local gre_enable = utl.trim(sys.exec("uci -q get gre_tunnel. " .. VPN_INST .. ".enabled")) or "0"
function m.on_commit()
	--Delete all usr_enable from gre_tunnel config
	local greEnable = m:formvalue("cbid.gre_tunnel." .. VPN_INST .. ".enabled") or "0"
	if greEnable ~= gre_enable then
		m.uci:foreach("gre_tunnel", "gre_tunnel", function(s)
			local usr_enable = s.usr_enable or ""
			gre_inst = s[".name"] or ""
			if usr_enable == "1" then
				m.uci:delete("gre_tunnel", gre_inst, "usr_enable")
			end
		end)
	end
end

return m
