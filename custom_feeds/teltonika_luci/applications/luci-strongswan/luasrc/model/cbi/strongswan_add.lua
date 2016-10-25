
local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()
local util = require ("luci.util")

local m = Map("strongswan", translate("IPsec"))

local s = m:section( TypedSection, "conn", translate("IPsec Configuration"), translate("") )
	s.addremove = true
	s.template = "strongswan/tblsection"
	s.novaluetext = translate("There are no IPsec configurations yet")
	s.extedit = luci.dispatcher.build_url("admin", "services", "vpn", "ipsec", "%s")
	s.defaults = {enabled = "0"}
	s.sectionhead = "Name"



local status = s:option(Flag, "enabled", translate("Enabled"), translate("Make a rule active/inactive"))

o = s:option( DummyValue, "aggressive", translate("Mode"), translate("ISAKMP (Internet Security Association and Key Management Protocol) phase 1 exchange mode"))

	function o.cfgvalue(self, section)
		local value = self.map:get(section, self.option)

		if value and value == "yes" then
			return "Aggressive"
		else
			return "Main"
		end
	end

dpd = s:option( DummyValue, "dpdaction", translate("Dead Peer Detection"), translate("The values clear, hold, and restart all activate DPD."))

	function dpd.cfgvalue(self, section, value)
		local value = self.map:get(section, self.option)

		if value and value == "restart" then
			return "Enabled"
		else
			return "Disabled"
		end
	end


o = s:option( DummyValue, "right", translate("Remote VPN endpoint"), translate("Domain name or IP address. Leave empty for any"))

	function o.cfgvalue(self, section)
		return self.map:get(section, self.option) or "-"
	end

function m.on_commit()
	local ipsec_enabled = false
	local IPsecESP = m.uci:get("firewall", "IPsecESP", "enabled") or "1"
	local IPsecNAT = m.uci:get("firewall", "IPsecNAT", "enabled") or "1"
	local IPsecIKE = m.uci:get("firewall", "IPsecIKE", "enabled") or "1"

	m.uci:foreach(status.config, "conn", function(sec)
		local enabled = status:formvalue(sec[".name"])
		if enabled and enabled == "1" then
			ipsec_enabled = true
		end
	end)

	if ipsec_enabled then
		if IPsecESP ~= "1" or IPsecNAT ~= "1" or IPsecIKE ~= "1" then
			m.uci:set("firewall", "IPsecESP", "enabled", "1")
			m.uci:set("firewall", "IPsecNAT", "enabled", "1")
			m.uci:set("firewall", "IPsecIKE", "enabled", "1")
			m.uci:commit("firewall")
		end
	else
		if IPsecESP ~= "0" or IPsecNAT ~= "0" or IPsecIKE ~= "0" then
			m.uci:set("firewall", "IPsecESP", "enabled", "0")
			m.uci:set("firewall", "IPsecNAT", "enabled", "0")
			m.uci:set("firewall", "IPsecIKE", "enabled", "0")
			m.uci:commit("firewall")
		end
	end
end

return m
