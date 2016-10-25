
local ds = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

local in_out = uci:get("hwinfo","hwinfo","in_out") or "0"
local gps = uci:get("hwinfo","hwinfo","gps") or "0"


m = Map("call_utils", translate("Call Utilities"),translate(""))

s = m:section(TypedSection, "rule", translate("Call Rules"))
s.template  = "cbi/tblsection"
s.addremove = true
s.anonymous = true
s.sortable  = true
s.extedit   = ds.build_url("admin/services/sms/call-utilities/%s")
s.template_addremove = "sms-utilities/cbi_addcall_rule"
s.novaluetext = translate("There are no Call rules created yet")

if in_out == "0" then
	s.hidden_rule2 = {"action", "iostatus"}
	s.hidden_rule3 = {"action", "dout"}
end
if gps == "0" then
	s.hidden_rule4 = {"action", "gps_coordinates"}
	s.hidden_rule5 = {"action", "gps"}
end
function s.create(self, section)
	local a = m:formvalue("_newinput.action")
	created = TypedSection.create(self, section)
	self.map:set(created, "action", a)
end

function s.parse(self, ...)
	TypedSection.parse(self, ...)
	if created then
		m.uci:save("call_utils")
		luci.http.redirect(ds.build_url("admin/services/sms/call-utilities", created ))
	end
end

src = s:option(DummyValue, "action", translate("Action"), translate("The action to be performed when a rule is met"))
src.rawhtml = true
src.width   = "65%"
function src.cfgvalue(self, s)
	local z = self.map:get(s, "action")
	if z == "send_status" then
		return translate("Get status")
	elseif z == "reboot" then
		return translate("Reboot")
	elseif z == "wifi" then
		local state = self.map:get(s, "value")
		if state == "off" then
			return translate("Switch WiFi off")
		else
			return translate("Switch WiFi on")
		end
	elseif z == "mobile" then
		local state = self.map:get(s, "value")
		if state == "off" then
			return translate("Switch mobile data off")
		else
			return translate("Switch mobile data on")
		end
	elseif z == "dout" then
		local state = self.map:get(s, "value")
		if state == "off" then
			return translate("Switch output off")
		else
			return translate("Switch output on")
		end
	elseif z == "firstboot" then
			return translate("Restore to default")
	else
		return translate("N/A")
	end
end

o = s:option(Flag, "enabled", translate("Enable"), translate("Make a rule active/inactive"))

s1 = m:section(TypedSection, "call", translate("Incoming Calls"))
s1.addremove = false
o2 = s1:option(Flag, "reject_incoming_calls", translate("Reject unrecognized incoming calls"), translate("If a call is made from number that is not in the active rule list, it can be rejected with this option"))
function o2.cfgvalue(self, section)
	return m.uci:get("call_utils", "call", "reject_incoming_calls")
end

return m
