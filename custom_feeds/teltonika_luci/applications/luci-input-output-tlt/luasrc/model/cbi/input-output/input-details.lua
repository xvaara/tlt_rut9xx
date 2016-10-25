local sys = require "luci.sys"
local dsp = require "luci.dispatcher"
local ft = require "luci.tools.input-output"
local utl = require "luci.util"

local m, s, o

arg[1] = arg[1] or ""

m = Map("ioman",
	translate("Input Configuration"))

m.redirect = dsp.build_url("admin/services/input-output/inputs")
if m.uci:get("ioman", arg[1]) ~= "rule" then
	luci.http.redirect(dsp.build_url("admin/services/input-output/inputs"))
	return
else
	--local name = m:get(arg[1], "name") or m:get(arg[1], "_name")
	--if not name or #name == 0 then
	--	name = translate("(Unnamed Entry)")
	--end
	--m.title = "%s - %s" %{ translate("Firewall - Port Forwards"), name }
end

s = m:section(NamedSection, arg[1], "rule", "")
s.anonymous = true
s.addremove = false

--ft.opt_enabled(s, Button)
o = s:option(Flag, "enabled", translate("Enable"), translate("To enable input configuration"))
o.rmempty = false

o = s:option(ListValue, "type", translate("Input type"), translate("Select type on your own intended configuration"))
o:value("digital1", translate("Digital"))
o:value("digital2", translate("Digital isolated"))
o:value("analog", translate("Analog"))

function o.write(self, section, value)
	if value == "analog" then
		luci.sys.call('uci set ioman.'..section..'.rule="false"')
	end
		m.uci:set("ioman", section, "type", value)
		m.uci:save("ioman")
		m.uci:commit("ioman")
end
--local txtM2 = luci.http.formvalue("cbid.ioman.cfg0492bd.type") or "notget2"
--local txtM = luci.http.formvalue("cbid.ioman."..arg[1]..".type") or "notget"
--os.execute("echo \"l"..txtM.."l\" >>/tmp/log.log")
--os.execute("echo \"l"..txtM2.."l\" >>/tmp/log.log")
minval = s:option(Value, "min", translate("Min [V]"), translate("Specify minimum voltage range"))
minval:depends("type", "analog")
function minval:validate(Values)
	Values = string.gsub(Values,",",".")
	if tonumber(Values) and tonumber(Values)>= 0 and tonumber(Values)<= 24 then
		return Values
	else
		return nil
	end
end
maxval = s:option(Value, "max", translate("Max [V]"), translate("Specify maximum voltage range"))
maxval:depends("type", "analog")
function maxval:validate(Values)
	Values = string.gsub(Values,",",".")
	if tonumber(Values) and tonumber(Values)>= 0 and tonumber(Values)<= 24 then
		return Values
	else
		return nil
	end
end

o = s:option(ListValue, "triger", translate("Triger"), translate("Select Triger on your own intended configuration"))
o:value("no", translate("Input open"))
o:value("nc", translate("Input shorted"))
o:value("both", translate("Both"))
o:depends("type", "digital1")
--o:depends("type", "digital2")

o = s:option(ListValue, "triger2", translate("Triger"), translate("Select Triger on your own intended configuration"))
o:value("no", translate("Low logic level"))
o:value("nc", translate("High logic level"))
o:value("both", translate("Both"))
o:depends("type", "digital2")

function o.cfgvalue(self, section)
	local v = m.uci:get("ioman", section, "triger")
	return v
end

function o.write(self, section, value)
	local typ = luci.http.formvalue("cbid.ioman."..arg[1]..".type")
	if typ == "digital2" then
		m.uci:set("ioman", section, "triger", value)
		m.uci:save("ioman")
		m.uci:commit("ioman")
	end
end

o = s:option(ListValue, "triger3", translate("Triger"), translate("Inside range - Input voltage falls in the specified region, Outside range - Input voltage drops out of the specified region"))
o:value("in", translate("Inside range"))
o:value("out", translate("Outside range"))
o:depends("type", "analog")

function o.cfgvalue(self, section)
	local v = m.uci:get("ioman", section, "triger")
	return v
end

function o.write(self, section, value)
	local typ = luci.http.formvalue("cbid.ioman."..arg[1]..".type")
	if typ == "analog" then
	m.uci:set("ioman", section, "triger", value)
	m.uci:save("ioman")
	m.uci:commit("ioman")
	end
	if typ == "digital2" then
		m.uci:set("ioman", section, "triger", value)
		m.uci:save("ioman")
		m.uci:commit("ioman")
	end
end

o = s:option(ListValue, "action", translate("Action"), translate("Select action on your own intended configuration"))
if luci.tools.status.show_mobile() then
	o:value("sendSMS", translate("Send SMS"))
	o:value("changeSimCard", translate("Change SIM Card"))
end
o:value("sendEmail", translate("Send email"))
o:value("changeProfile", translate("Change profile"))
o:value("wifion", translate("Turn on WiFi"))
o:value("wifioff", translate("Turn off WiFi"))
o:value("reboot", translate("Reboot"))
o:value("output", translate("Activate output"))
function o.cfgvalue(...)
	local v = Value.cfgvalue(...)
	return v
end

-- smstxt = s:option(Value, "smstxt", translate("SMS text"), translate("Specify message to send in SMS, field validation (a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. )"))
-- smstxt:depends("action", "sendSMS")
-- smstxt.datatype = "fieldvalidation('^[a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. ]+$',0)"

smstxt = s:option(Value, "smstxt", translate("SMS text"), translate("Specify message to send in SMS, field validation (a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. )"))
smstxt:depends("action", "sendSMS")
smstxt.template = "input-output/ioman_textbox"
smstxt.rows = "4"
smstxt.default = ""
smstxt.indicator = arg[1]

telnum = s:option(DynamicList, "telnum", translate("Recipient's phone number"), translate("Specify Recipient's phone number, e.g. +37012345678"))
telnum:depends("action", "sendSMS")

function telnum:validate(Values)
	local smstxt = m:formvalue("cbid.ioman."..arg[1]..".smstxt")
	local failure
	if smstxt == "" then
		m.message = translate("err: SMS text is incorrect!")
		failure = true
	else
		for k,v in pairs(Values) do
			if not v:match("^[+%d]%d*$") then
				m.message = translatef("err: SMS sender's phone number \"%s\" is incorrect!", v)
				failure = true
			end
		end
	end
	if not failure then
		return Values
	end
	return nil
end

function smstxt.write(self, section, value)
	local value = luci.http.formvalue("cbid.ioman."..arg[1]..".smstxt")
	value = string.gsub(value, "%s", " ")
	if value then
		m.uci:set("ioman", section, "smstxt", value)
		m.uci:save("ioman")
		m.uci:commit("ioman")
	end
end
emailsub = s:option(Value, "subject", translate("Subject"), translate("Specify subject of email, field validation (a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. )"))
emailsub:depends("action", "sendEmail")
emailsub.datatype = "fieldvalidation('^[a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. ]+$',0)"

emailtxt = s:option(Value, "message", translate("Message"), translate("Specify message to send in email, field validation (a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. )"))
emailtxt:depends("action", "sendEmail")
emailtxt.template = "input-output/ioman_textbox"
emailtxt.rows = "4"
emailtxt.default = ""
emailtxt.indicator = arg[1]

function emailtxt.write(self, section, value)
	local value = luci.http.formvalue("cbid.ioman."..arg[1]..".message")
	value = string.gsub(value, "%s", " ")
	if value then
		m.uci:set("ioman", section, "message", value)
		m.uci:save("ioman")
		m.uci:commit("ioman")
	end
end

smtpip = s:option(Value, "smtpIP", translate("SMTP server"), translate("Specify SMTP (Simple Mail Trasfer Protocol) server, field validation (a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. )"))
smtpip:depends("action", "sendEmail")
smtpip.datatype = "fieldvalidation('^[a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. ]+$',0)"

smtpPort = s:option(Value, "smtpPort", translate("SMTP server port"), translate("Specify SNMP server port"))
smtpPort:depends("action", "sendEmail")
smtpPort.datatype = "port"

secCon = s:option(Flag, "secureConnection", translate("Secure connection"), translate("Specify if server support SSL or TLS"))
secCon:depends("action", "sendEmail")

username = s:option(Value, "userName", translate("User name"), translate("Specify user name to connect SNMP server"))
username:depends("action", "sendEmail")
username.datatype = "fieldvalidation('^[a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. ]+$',0)"

passwd = s:option(Value, "password", translate("Password"), translate("Specify the password of the user"))
passwd.password = true
passwd:depends("action", "sendEmail")
passwd.datatype = "fieldvalidation('^[a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. ]+$',0)"

senderEmail = s:option(Value, "senderEmail", translate("Sender’s email address"), translate("Specify your email address"))
senderEmail:depends("action", "sendEmail")
senderEmail.datatype = "fieldvalidation('^[a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. ]+$',0)"

recEmail = s:option(DynamicList, "recipEmail", translate("Recipien’t email address"), translate("Specify for whom you want to send email"))
recEmail:depends("action", "sendEmail")
function recEmail:validate(Values)
	local failure
	for k,v in pairs(Values) do
		if not v:match("^[a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. ]+$") then
			m.message = translatef("err: Recipien’t email address is incorrect!")
			failure = true
		end
	end
	if not failure then
		return Values
	end
	return nil
end

reboott = s:option(Value, "reboottime", translate("Reboot after (s)"), translate("Device will reload after a specified time, format seconds"))
reboott:depends("action", "reboot")
reboott.datatype = "uinteger"

o = s:option(ListValue, "continuous", translate("Output activated"), translate("Output activated for specified time, or while condition exist"))
o:depends({action = "output",triger = "no"})
o:depends({action = "output",triger = "nc"})
o:depends({action = "output",triger2 = "no"})
o:depends({action = "output",triger2 = "nc"})
o:depends({action = "output",triger3 = "in"})
o:depends({action = "output",triger3 = "out"})
o:value("0", translate("Seconds"))
o:value("1", translate("While exist"))

outputt = s:option(Value, "outputtime", translate("Seconds"), translate("Device will be activated for specified time, format seconds"))
outputt:depends("continuous", "0")
outputt.datatype = "uinteger"

outputtype = s:option(ListValue, "outputnb", translate("Output type"), translate("Select output type, which will be activated, depending on output time"))
outputtype:value("1", translate("Open collector"))
outputtype:value("2", translate("Relay output"))
outputtype:depends("action", "output")

changeSim = s:option(ListValue, "simcard", translate("Sim"), translate("Select which one sim card will be changed"))
changeSim:value("primary", translate("Primary"))
changeSim:value("secondary", translate("Secondary"))
changeSim:depends({action = "changeSimCard",triger = "no"})
changeSim:depends({action = "changeSimCard",triger = "nc"})

local uci = require "luci.model.uci".cursor()
local path = uci:get("profiles", "profiles", "path")
function fileList()
	local cmd = "ls ".. path
	local h = io.popen(cmd)
	local t = h:read("*all")
	h:close()

	return t
end
function getProfiles()
	local profiles = {}
	local list = fileList()

	for name, date in string.gmatch(list, "([%w_]+)_(%d+-%d+-%d+)%.tar%.gz") do
		profiles[#profiles+1] = { name, date }
	end

	return profiles
end

o = s:option(ListValue, "profile", translate("Profile"), translate("Select which one profile will be set and used"))

for _,profile in ipairs(getProfiles()) do
	--o:value(profile[1], profile[1].." "..profile[2])
	o:value(profile[1], profile[1])
end
o:depends({action = "changeProfile",triger = "no"})
o:depends({action = "changeProfile",triger = "nc"})
o:depends({action = "changeProfile",type = "analog"})

function o.write(self, section, value)
	local act = luci.http.formvalue("cbid.ioman."..arg[1]..".action")
	local trig = luci.http.formvalue("cbid.ioman."..arg[1]..".triger")
	local typ = luci.http.formvalue("cbid.ioman."..arg[1]..".type")
	if ( typ == "analog" and act == "changeProfile" ) or ( trig == "no" and act == "changeProfile" ) or ( trig == "nc" and act == "changeProfile" ) then
	m.uci:set("ioman", section, "profiles", value)
	m.uci:save("ioman")
	m.uci:commit("ioman")
	end
end

o = s:option(MultiValue, "profiles", translate("Profiles"), translate("Rotate between selected profiles"))
for _,profile in ipairs(getProfiles()) do
	--o:value(profile[1], profile[1].." "..profile[2])
	o:value(profile[1], profile[1])
end
o:depends({action = "changeProfile",triger = "both"})

local ioman_enable = utl.trim(sys.exec("uci -q get ioman. " .. arg[1] .. ".enabled")) or "0"
function m.on_commit()
	--Delete all usr_enable from ioman config
	local iomanEnable = m:formvalue("cbid.ioman." .. arg[1] .. ".enabled") or "0"
	if iomanEnable ~= ioman_enable then
		m.uci:foreach("ioman", "rule", function(s)
			local usr_enable = s.usr_enable or ""
			ioman_inst2 = s[".name"] or ""
			if usr_enable == "1" then
				m.uci:delete("ioman", ioman_inst2, "usr_enable")
			end
		end)
	end
	m.uci:save("ioman")
	m.uci.commit("ioman")
end




return m
