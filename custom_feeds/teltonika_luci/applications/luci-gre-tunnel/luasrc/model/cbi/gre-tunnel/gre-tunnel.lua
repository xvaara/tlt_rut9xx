
local fs  = require "nixio.fs"
local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()
local utl = require ("luci.util")
local CFG_MAP = "gre_tunnel"
local CFG_SEC = "gre_tunnel"

local function cecho(string)
	luci.sys.call("echo \"gre_tunnel: " .. string .. "\" >> /tmp/log.log")
end

local m, m2 ,s, o

m2 = Map("firewall", translate("Generic Routing Encapsulation Tunnel"))

s2 = m2:section( NamedSection, "gre_zone", "zone", translate("GRE Tunnel Configuration"), translate("") )
e_nat = s2:option(Flag, "masq", translate("Disable NAT"), translate("Disable NAT for all GRE tunnels"))
e_nat.forcewrite = true
e_nat.enabled  = "0"
e_nat.disabled = "1"


m = Map(CFG_MAP, translate(""))
m.spec_dir = nil
-- m.pageaction = false

s = m:section( TypedSection, CFG_SEC, translate(""), translate("") )
s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection"
s.template_addremove = "gre-tunnel/gre_add_rem"
s.addremoveAdd = true
s.novaluetext = translate("There are no GRE Tunnel configurations yet")

--cecho("zomg called!")
uci:foreach(CFG_MAP, CFG_SEC, function(sec)
	--cecho("section called!")
	-- Entry signifies that there already is a section, therefore we will disable the ability to add or remove another section
	s.addremoveAdd = false
end)

s.extedit = luci.dispatcher.build_url("admin", "services", "vpn", "gre-tunnel", "%s")

local name = s:option( DummyValue, "name", translate("Tunnel name"), translate("Name of the tunnel. Used for easier tunnels management purpose only"))

function name.cfgvalue(self, section)
	return section:gsub("^%l", string.upper) or "Unknown"
end

status = s:option(Flag, "enabled", translate("Enable"), translate("Make a rule active/inactive"))
--[[
local status = s:option( DummyValue, "enabled", translate("Enabled"), translate("Indicates whether a configuration is active or not"))

function status.cfgvalue(self, section)
	local val = AbstractValue.cfgvalue(self, section)
	if val == "1" then
		return translate("Yes")
	else
		return translate("No")
	end
end
--]]
-------------
function s.parse(self, section)
	local cfgname = luci.http.formvalue("cbid." .. self.config .. "." .. self.sectiontype .. ".name") or ""
	-- 'Delete' button does not commit uci changes. So we will do it manually. And here another problem
	-- occurs: 'Delete' button has very long name including vpn instance name and I don't know that
	-- instance name. So I will scan through uci config and try to find out if such instance name exists
	-- as form element. FIXME investigate if another more inteligent approach is available here (O_o)
	local delButtonFormString = "cbi.rts." .. self.config .. "."
	local delButtonPress = false
	local configName
	local uFound
	local existname = false
	uci:foreach("gre_tunnel", "gre_tunnel", function(x)
		if not delButtonPress then
			configName = x[".name"] or ""
			if luci.http.formvalue(delButtonFormString .. configName) then
				delButtonPress = true
			end
		end
		newname= "gre_"..cfgname
		if configName == newname then
			existname = true
		end
	end)
	if delButtonPress then
		luci.sys.call("ip tunnel del "..configName.." 2> /dev/null ")
		luci.sys.call("logger [GRE-TUN] "..configName.." Cleaning up...")
		luci.sys.call("pid=`ps -w | grep gre-tunnel-keep | grep "..configName.." | awk -F ' ' '{print $1}'`; kill -9 $pid 2>/dev/null")
		uci.delete("gre_tunnel", configName)
		uci.save("gre_tunnel")
		luci.sys.call("/etc/init.d/gre-tunnel restart >/dev/null")
		-- delete buttons is pressed, don't execute function 'gre_tunnel_new'
		cfgname = false
		uci.commit("gre_tunnel")
	end
	if cfgname and cfgname ~= '' then
		openvpn_new(self, cfgname, existname)
	end
	TypedSection.parse( self, section )
	uci.commit("gre_tunnel")
end

function openvpn_new(self,name, exist)

	local t = {}

	if exist then
		name = ("gre_"..name)
		m.message = translatef("err: Name %s already exists.", name)
	elseif name and #name > 0 then

		if not (string.find(name, "[%c?%p?%s?]+") == nil) then
			m.message = translate("err: Only alphanumeric characters are allowed.")
		else
		namew = name
		name = ("gre_"..name)
		t["enabled"]= "0"
		t["ifname"]= name
		t["mtu"] = "1476"
		t["ttl"] = "255"
		t["tunnel_ip"] = ""
		t["tunnel_netmask"] = ""
		t["remote_ip"] = ""
		t["remote_network"] = ""
		t["remote_netmask"] = ""
		t["keepalive"] = ""
		t["keepalive_host"] = ""
		uci:section("gre_tunnel", "gre_tunnel", name,t)
		uci:save("gre_tunnel")
		uci.commit("gre_tunnel")
		m.message = translate("scs:New Gre-tunnel instance was created successfully. Configure it now")
		end
	else
		m.message = translate("err: To create a new Gre-tunnel instance it's name has to be entered!")
	end
end

local save = m:formvalue("cbi.apply")
if save then
	--Delete all usr_enable from gre_tunnel config
	m.uci:foreach("gre_tunnel", "gre_tunnel", function(s)
		gre_inst = s[".name"] or ""
		greEnable = m:formvalue("cbid.gre_tunnel." .. gre_inst .. ".enabled") or "0"
		gre_vpn_enable = s.enabled or "0"
		if greEnable ~= gre_vpn_enable then
			m.uci:foreach("gre_tunnel", "gre_tunnel", function(a)
				gre_inst2 = a[".name"] or ""
				local usr_enable = a.usr_enable or ""
				if usr_enable == "1" then
					m.uci:delete("gre_tunnel", gre_inst2, "usr_enable")
				end
			end)
		end
	end)
	m.uci:save("gre_tunnel")
	m.uci.commit("gre_tunnel")
end

return m2, m
