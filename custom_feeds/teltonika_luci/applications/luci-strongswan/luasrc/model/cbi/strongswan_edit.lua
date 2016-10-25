local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()
local fw = require "luci.model.firewall"

local section_name

if arg[1] then
	section_name = arg[1]
else
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "vpn", "ipsec"))
end

local m = Map("strongswan", translate("IPsec"), translate(""))

local s = m:section(NamedSection, section_name, "conn", translate("IPsec Configuration"))

local ipsec_on = s:option( Flag, "enabled", translate("Enable"), translate("Enable IPsec (Internet Protocol Security)"))

	function ipsec_on.on_enable(self, section)
		local IPsecESP = m.uci:get("firewall", "IPsecESP", "enabled") or "1"
		local IPsecNAT = m.uci:get("firewall", "IPsecNAT", "enabled") or "1"
		local IPsecIKE = m.uci:get("firewall", "IPsecIKE", "enabled") or "1"

		if IPsecESP ~= "1" or IPsecNAT ~= "1" or IPsecIKE ~= "1" then
			m.uci:set("firewall", "IPsecESP", "enabled", "1")
			m.uci:set("firewall", "IPsecNAT", "enabled", "1")
			m.uci:set("firewall", "IPsecIKE", "enabled", "1")
			m.uci:commit("firewall")
		end
	end

	function ipsec_on.on_disable(self, section)
		local IPsecESP = m.uci:get("firewall", "IPsecESP", "enabled") or "1"
		local IPsecNAT = m.uci:get("firewall", "IPsecNAT", "enabled") or "1"
		local IPsecIKE = m.uci:get("firewall", "IPsecIKE", "enabled") or "1"

		if IPsecESP ~= "0" or IPsecNAT ~= "0" or IPsecIKE ~= "0" then
			local ipsec_enabled = false

			m.uci:foreach(self.config, "conn", function(sec)
				if sec.enabled and sec.enabled == "1" and sec[".name"] ~= section then
					ipsec_enabled = true
				end
			end)

			if not ipsec_enabled then
				m.uci:set("firewall", "IPsecESP", "enabled", "0")
				m.uci:set("firewall", "IPsecNAT", "enabled", "0")
				m.uci:set("firewall", "IPsecIKE", "enabled", "0")
				m.uci:commit("firewall")
			end
		end
	end

o = s:option( ListValue, "keyexchange", translate("IKE version"), translate("Method of key exchange"))
	o.default = "ikev1"
	o:value("ikev1",translate("IKEv1"))
	o:value("ikev2",translate("IKEv2"))

o = s:option( ListValue, "aggressive", translate("Mode"), translate("ISAKMP (Internet Security Association and Key Management Protocol) phase 1 exchange mode"))
	o.default = "main"
	o:value("no",translate("Main"))
	o:value("yes",translate("Aggressive"))

local iden  = s:option( ListValue, "my_identifier_type", translate("My identifier type"), translate("Choose one accordingly to your IPSec configuration"))
	iden.nowrite = true
	iden.default = "fqdn"
	iden:value("fqdn", translate("FQDN"))
	iden:value("user_fqdn", translate("User FQDN"))
	iden:value("address", translate("Address"))

o = s:option( Value, "my_identifier", translate("My identifier"), translate("Set the device identifier for IPSec tunnel"))

	function o.validate(self, value, section)
		if iden:formvalue(section) == "address" then
			if not value:match("[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+") then
				m.message = translate("IP address expected in \"My identifier\" field")
				return nil
			end
		end
		return value
	end

dpd = s:option( Flag, "dpdaction", translate("Dead Peer Detection"), translate("The values clear, hold, and restart all activate DPD."))
	dpd.rmempty = false

	function dpd.write(self, section, value)
		if value and value == "1" then
			self.map:set(section, self.option, "restart")
		else
			self.map:set(section, self.option, "none")
		end
	end

	function dpd.cfgvalue(self, section, value)
		local value = self.map:get(section, self.option)

		if value and value == "restart" then
			return "1"
		else
			return "0"
		end
	end

o = s:option( Value, "psk_key", translate("Pre shared key"), translate("A shared password to authenticate between the peers."))

o = s:option( Value, "right", translate("Remote VPN endpoint"), translate("Domain name or IP address. Leave empty for any"))
	o.datatype = "host"

o = s:option( Value, "dpd_delay", translate("Delay (sec)"), translate("Delay between peer acknowledgement requests"))
o:depends({dpd_enable="1"})
o.datatype = "lengthvalidation(0,64,'^[0-9]+$')"

remip = s:option(DynamicList, "rightsubnet", translate("IP address/Subnet mask"),
	translate("Remote network secure group IP address and mask used to determine to what subnet an IP address belongs to. Range [0 - 32]. IP should differ from device LAN IP"))
	remip.datatype = "ipaddr"

	function remip.validate(self, value, section)
		local networks = {}

		for i, v in ipairs(value) do
			local remote = luci.ip.IPv4(v)
			local ip = m.uci:get("network", "lan", "ipaddr")
			lan = luci.ip.IPv4(ip)
			if remote ~= nil then
				local address = v:gsub("/.+","")
				local networkip = tostring(luci.util.exec(string.format("ipcalc.sh %s |grep NETWORK= | cut -d'=' -f2 | tr -d ''", v)))
				networkip = networkip:match("[%w%.]+")
				if address == networkip then
					table.insert(networks, v)
				else
					m.message = translatef("err: To match specified netmask, Remote network IP address should be %s", networkip);
					return nil
				end
			else
				m.message = translate("\"Remote network secure group\" IP address cannot be empty!")
				return nil
			end
		end

		return networks
	end


o = s:option( Flag, "keep_enabled", translate("Enable keepalive"),  translate("Enable tunnel keep alive"))
o.rmempty = false

o = s:option( Value, "ping_ipaddr", translate("Host"), translate("A host address to which ICMP (Internet Control Message Protocol) echo requests will be sent"))
o.datatype = "ipaddr"
o.nowrite = true

o = s:option( Value, "ping_period", translate("Ping period (sec)"), translate("Send ICMP (Internet Control Message Protocol) echo request every x seconds. Range [0 - 9999999]"))
o.nowrite = true
o.datatype ="range(0,9999999)"

--Phases

local s2 = m:section( TypedSection, "p1_proposal", translate("Phase"), translate("The phase must match with another incoming connection to establish IPSec"))
	s2:tab("phase1",  translate("Phase 1"))
	s2:tab("phase2", translate("Phase 2"))

	function s2.cfgsections(self)
		return {"p1_proposal"}
	end

o = s2:taboption("phase1", ListValue, "ike_encryption_algorithm", translate("Encryption algorithm"), translate("The encryption algorithm must match with another incoming connection to establish IPSec"))
	o.default = "3des"
	o:value("des","DES")
	o:value("3des","3DES")
	o:value("aes128","AES 128")
	o:value("aes192","AES 192")
	o:value("aes256","AES 256")

	function o.write(self, section, value)
		self.map:set(section_name, self.option, value)
	end

	function o.cfgvalue(self, section)
		return self.map:get(section_name, self.option)
	end

o = s2:taboption("phase1", ListValue, "ike_authentication_algorithm", translate("Authentication"), translate("The authentication algorithm must match with another incoming connection to establish IPSec"))
	o.default = "sha1"
	o:value("md5", "MD5")
	o:value("sha1", "SHA1")
	o:value("sha256", "SHA256")
	o:value("sha384", "SHA384")
	o:value("sha512", "SHA512")

	function o.write(self, section, value)
		self.map:set(section_name, self.option, value)
	end

	function o.cfgvalue(self, section)
		return self.map:get(section_name, self.option)
	end

o = s2:taboption("phase1", ListValue, "ike_dh_group", translate("DH group"), translate("The DH (Diffie-Hellman) group must match with another incoming connection to establish IPSec"))
	o.default = "modp1536"
	o:value("modp768", "MODP768")
	o:value("modp1024", "MODP1024")
	o:value("modp1536", "MODP1536")
	o:value("modp2048", "MODP2048")
	o:value("modp3072", "MODP3072")
	o:value("modp4096", "MODP4096")

	function o.write(self, section, value)
		self.map:set(section_name, self.option, value)
	end

	function o.cfgvalue(self, section)
		return self.map:get(section_name, self.option)
	end

ike_keylife = s2:taboption("phase1", Value, "ikelifetime", translate("Lifetime (h)"), translate("The time duration for phase 1"))
	ike_keylife.datatype = "lengthvalidation(0,64,'^[0-9]+$')"
	ike_keylife.displayInline = true
	ike_keylife.forcewrite = true
	ike_keylife.default = "8"

	function ike_keylife.write(self, section, value)
		local letter = ike_time:formvalue(section)
		if letter then
			value = string.format("%s%s", value, letter)
		end

		self.map:set(section_name, self.option, value)
	end

	function ike_keylife.cfgvalue(self, section)
		local value = self.map:get(section_name, self.option)

		if value then
			value = value:match("%d+")
		end

		return  value
	end

ike_time = s2:taboption("phase1", ListValue, "ikeletter", translate(""), translate(""))
		ike_time:value("h", translate("Hours"))
		ike_time:value("m", translate("Minutes"))
		ike_time:value("s", translate("Seconds"))
		ike_time.displayInline = true
		ike_time.default = "h"

	function ike_time.write() end

	function ike_time.cfgvalue(self, section)
		local value = self.map:get(section_name, ike_keylife.option)

		if value then
			value = value:match("%a+")
		end

		return  value
	end

o = s2:taboption("phase2", ListValue, "esp_encryption_algorithm", translate("Encryption algorithm"), translate("The encryption algorithm must match with another incoming connection to establish IPSec"))
	o.default = "3des"
	o:value("des","DES")
	o:value("3des","3DES")
	o:value("aes128","AES 128")
	o:value("aes192","AES 192")
	o:value("aes256","AES 256")

	function o.write(self, section, value)
		self.map:set(section_name, self.option, value)
	end

	function o.cfgvalue(self, section)
		return self.map:get(section_name, self.option)
	end

o = s2:taboption("phase2", ListValue, "esp_hash_algorithm", translate("Hash algorithm"), translate("The hash algorithm must match with another incoming connection to establish IPSec"))
	o.default = "sha1"
	o:value("md5", "MD5")
	o:value("sha1", "SHA1")
	o:value("sha256", "SHA256")
	o:value("sha384", "SHA384")
	o:value("sha512", "SHA512")

	function o.write(self, section, value)
		self.map:set(section_name, self.option, value)
	end

	function o.cfgvalue(self, section)
		return self.map:get(section_name, self.option)
	end

o = s2:taboption("phase2", ListValue, "esp_pfs_group", translate("PFS group"), translate("The PFS (Perfect Forward Secrecy) group must match with another incoming connection to establish IPSec"))
	o.default = "modp1536"
	o:value("modp768", "MODP768")
	o:value("modp1024", "MODP1024")
	o:value("modp1536", "MODP1536")
	o:value("modp2048", "MODP2048")
	o:value("modp3072", "MODP3072")
	o:value("modp4096", "MODP4096")
	o:value("no_pfs", "No PFS")

	function o.write(self, section, value)
		self.map:set(section_name, self.option, value)
	end

	function o.cfgvalue(self, section)
		return self.map:get(section_name, self.option)
	end

keylife = s2:taboption("phase2", Value, "keylife", translate("Lifetime (h)"), translate("The time duration for phase 2"))
	keylife.datatype = "lengthvalidation(0,64,'^[0-9]+$')"
	keylife.displayInline = true
	keylife.forcewrite = true
	keylife.default = "8"

	function keylife.write(self, section, value)
		local letter = time:formvalue(section)

		if letter then
			value = string.format("%s%s", value, letter)
		end

		self.map:set(section_name, self.option, value)
	end

	function keylife.cfgvalue(self, section)
		local value = self.map:get(section_name, self.option)

		if value then
			value = value:match("%d+")
		end

		return  value
	end

time = s2:taboption("phase2", ListValue, "letter", translate(""), translate(""))
		time:value("h", translate("Hours"))
		time:value("m", translate("Minutes"))
		time:value("s", translate("Seconds"))
		time.displayInline = true
		time.default = "h"

	function time.write() end

	function time.cfgvalue(self, section)
		local value = self.map:get(section_name, keylife.option)

		if value then
			value = value:match("%a+")
		end

		return  value
	end

return m
