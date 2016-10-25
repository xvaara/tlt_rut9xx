local sys = require"luci.sys"

m = Map("logtrigger", translate("Block Unwanted Access"))
local section_id = ""
m.uci:foreach("logtrigger", "rule", function(s)
	if s.name == "SSH_WrongPass" then
		section_id = s[".name"]
	end
end)
sct = m:section(NamedSection, section_id, "rule", translate("SSH Access Secure"))
	sct.addremove = false
	sct.anonymous = true


enb = sct:option(Flag, "enabled", translate("Enable"), translate(""))
	enb.rmempty = false
	function enb.write(self, section, value)
		m.uci:foreach(self.config, "rule", function(s)
			if s.name == "SSH_WrongPass" or s.name == "SSH_nonexistent" then
				m.uci:set(self.config, s[".name"], self.option, value or "0")
			end
		end)
	end

reboot = sct:option(Flag, "until_reboot", translate("Clean after reboot"), translate(""))
	reboot.rmempty = false
	function reboot.write(self, section, value)
		m.uci:foreach(self.config, "rule", function(s)
			if s.name == "SSH_WrongPass" or s.name == "SSH_nonexistent" then
				m.uci:set(self.config, s[".name"], self.option, value or "0")
			end
		end)
	end

maxfail = sct:option(Value, "maxfail", translate("Fail count"), translate(""))
	maxfail.datatype = "integer"
	function maxfail.write(self, section, value)
		m.uci:foreach(self.config, "rule", function(s)
			if s.name == "SSH_WrongPass" or s.name == "SSH_nonexistent" then
				m.uci:set(self.config, s[".name"], self.option, value or "0")
			end
		end)
	end
section_id = ""
m.uci:foreach("logtrigger", "rule", function(s)
	if s.name == "WebUI_WrongPass" then
		section_id = s[".name"]
	end
end)
sct1 = m:section(NamedSection, section_id, "rule", translate("WebUI Access Secure"))
	sct1.addremove = false
	sct1.anonymous = true

enb = sct1:option(Flag, "enabled", translate("Enable"), translate(""))
	enb.rmempty = false
	function enb.write(self, section, value)
		m.uci:foreach(self.config, "rule", function(s)
			if s.name == "WebUI_WrongPass" or s.name == "WebUI_nonexistent" then
				m.uci:set(self.config, s[".name"], self.option, value or "0")
			end
		end)
	end

reboot = sct1:option(Flag, "until_reboot", translate("Clean after reboot"), translate(""))
	reboot.rmempty = false
	function reboot.write(self, section, value)
		m.uci:foreach(self.config, "rule", function(s)
			if s.name == "WebUI_WrongPass" or s.name == "WebUI_nonexistent" then
				m.uci:set(self.config, s[".name"], self.option, value or "0")
			end
		end)
	end

maxfail = sct1:option(Value, "maxfail", translate("Fail count"), translate(""))
	maxfail.datatype = "integer"
	function maxfail.write(self, section, value)
		m.uci:foreach(self.config, "rule", function(s)
			if s.name == "WebUI_WrongPass" or s.name == "WebUI_nonexistent" then
				m.uci:set(self.config, s[".name"], self.option, value or "0")
			end
		end)
	end
m_list = Map("blocklist")
list_sct = m_list:section(TypedSection, "dropbear", translate("List Of Blocked Addresses"))
	list_sct.template="admin_system/blocklist"
	list_sct.anonymous = true
	list_sct.addremove = true

service = list_sct:option(DummyValue, "service", translate("Service"))

ip = list_sct:option(DummyValue, "ip", translate("Blocked address"))
block_date = list_sct:option(DummyValue, "date", translate("Blocked date"))

	function ip.cfgvalue(self, secion)
		return m.uci:get("blocklist", secion, self.option) or "-"
	end

function list_sct.parse(self)
	REMOVE_PREFIX = "cbi.del."
	local crval = REMOVE_PREFIX .. self.config
	local name = self.map:formvaluetable(crval)

	for k,v in pairs(name) do
		if k then

			local service = k:match("dropbear") or k:match("uhttpd")
			local ip = k:match("(%d+.%d+.%d+.%d+)")
			if service == "uhttpd" then
				service = "webui"
			elseif service == "dropbear" then
				service = "ssh"
			end
			luci.sys.exec("uci -q del_list blocklist." .. k)
			luci.sys.exec("uci commit blocklist")
			luci.sys.exec("/etc/logtrigger/firewall.sh -u " .. ip .. " " .. service)
		end
	end

end


return m, m_list

