
local utl = require "luci.util"
local nw = require "luci.model.network"
local sys = require "luci.sys"
local ntm = require "luci.model.network".init()
local m
local savePressed = luci.http.formvalue("cbi.apply") and true or false



m2 = Map("sms_gateway", translate("SMS Forwarding To HTTP Configuration"), 
	translate(""))
m2.addremove = false

sc = m2:section(NamedSection, "forwarding_to_http","forwarding_to_http", translate("SMS Forwarding To HTTP Settings"))

enb_block = sc:option(Flag, "enabled", translate("Enable"), translate("Enable/disable sms forwarding to HTTP"))
enb_block.rmempty = false

o = sc:option(ListValue, "method", translate("Method"), translate("Choose witch HTTP request method will be used"))
o:value("post", translate("Post"))
o:value("get", translate("Get"))
o.default = "get"

o = sc:option(Value, "url", translate("URL"), translate("URL to whitch message is going to be forwarded"))

o = sc:option(Value, "number_name", translate("Number value name"), translate("Sender phone number codename for query string name/value pair"))
--o.datatype = "fieldvalidation('^[0-9#*+]+$',0)"

o = sc:option(Value, "message_name", translate("Message value name"), translate("Message codename for query string name/value pair"))
--o.datatype = "fieldvalidation('^[0-9#*+]+$',0)"

o = sc:option(Value, "extra_name1", translate("Extra data pair 1"), translate("Extra html query name/value pair. Enter name to the left field and value to right"))
o.displayInline = true
o.rmempty = true

o = sc:option(Value, "extra_value1", translate(""), translate(""))
o.displayInline = true
o.rmempty = true

o = sc:option(Value, "extra_name2", translate("Extra data pair 2"), translate("Extra html query name/value pair. Enter name to the left field and value to right"))
o.displayInline = true
o.rmempty = true

o = sc:option(Value, "extra_value2", translate(""), translate(""))
o.displayInline = true
o.rmempty = true

o = sc:option(ListValue, "mode", translate("Mode"), translate("Choose witch messages are going to be forwarded"))
o:value("everyone", translate("All messages"))
o:value("list", translate("From listed numbers"))
o.default = "everyone"

o = sc:option(DynamicList, "number", translate("Sender's phone number(s)"), translate("Number(s) from witch received messages will be forwarded to HTTP"))
o:depends("mode", "list")
function o:validate(Values)
	local failure
	for k,v in pairs(Values) do
		if not v:match("^[+%d]%d*$") then
			m2.message = translatef("err: SMS sender's phone number \"%s\" is incorrect!", v)
			failure = true
		end
	end
	if not failure then
		return Values
	end
	return nil
end

return m2
 

