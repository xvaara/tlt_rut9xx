
local utl = require "luci.util"
local nw = require "luci.model.network"
local sys = require "luci.sys"
local moduleVidPid = utl.trim(sys.exec("uci get system.module.vid")) .. ":" .. utl.trim(sys.exec("uci get system.module.pid"))
local moduleType = luci.util.trim(luci.sys.exec("uci get system.module.type"))
local m
local function cecho(string)
	luci.sys.call("echo \"" .. string .. "\" >> /tmp/luci.log")
end

m = Map("data_limit", translate("Mobile Data Limit Configuration"))
m.disclaimer_msg = true

s = m:section(NamedSection, "limit", "limit");
s.addremove = false
s:tab("primarytab", translate("SIM1"))
s:tab("secondarytab", translate("SIM2"))


-----------------------
--Primary taboptions---
-----------------------
e = s:taboption("primarytab", Value, "field1")
e.template = "cbi/legend"
e.titleText = "Data Connection Limit Configuration"

prim_enb_conn = s:taboption("primarytab", Flag, "prim_enb_conn", translate("Enable data connection limit"), translate("Disables mobile data when a limit for current period is reached"))
prim_enb_conn.rmempty = false

o1 = s:taboption("primarytab", Value, "prim_conn_limit", translate("Data limit* (MB)"), translate("Disable mobile data after limit value in MB is reached"))
--o1:depends("enb_limit", "1")

function o1:validate(Value)
	local failure	
	if not Value:match("^[+%d]%d*$") then
		m.message = translate("err: mobile data limit value is incorrect!")
		return nil
	elseif Value == "" then
		m.message = translate("err: mobile data limit value is empty!")
		return nil
	end
	return Value
end

o = s:taboption("primarytab", ListValue, "prim_conn_period", translate("Period"), translate("Period for which mobile data limiting should apply"))
o:value("month", translate("Month"))
o:value("week", translate("Week"))
o:value("day", translate("Day"))

o = s:taboption("primarytab", ListValue, "prim_conn_day", translate("Start day"), translate("A starting day in a month for mobile data limiting period"))
o:depends({prim_conn_period = "month"})
for i=1,31 do
	o:value(i, i)
end

o = s:taboption("primarytab", ListValue, "prim_conn_hour", translate("Start hour"), translate("A starting hour in a day for mobile data limiting period"))
o:depends({prim_conn_period = "day"})
for i=1,23 do
	o:value(i, i)
end
o:value("0", "24")

o = s:taboption("primarytab", ListValue, "prim_conn_weekday", translate("Start day"), translate("A starting day in a week for mobile data limiting period"))
o:value("1", translate("Monday"))
o:value("2", translate("Tuesday"))
o:value("3", translate("Wednesday"))
o:value("4", translate("Thursday"))
o:value("5", translate("Friday"))
o:value("6", translate("Saturday"))
o:value("0", translate("Sunday"))
o:depends({prim_conn_period = "week"})


--------------------------------------------------------------------------------
--------------------SMS warninig------------------------------------------------
--------------------------------------------------------------------------------

e = s:taboption("primarytab", Value, "field2")
e.template = "cbi/legend"
e.titleText = "SMS Warning Configuration" 

prim_enb_wrn = s:taboption("primarytab", Flag, "prim_enb_wrn", translate("Enable SMS warning"), translate("Enables sending of warning SMS message when mobile data limit for current period is reached"))
prim_enb_wrn.rmempty = false

o = s:taboption("primarytab", Value, "prim_wrn_limit", translate("Data limit* (MB)"), translate("Send warning SMS message after limit value in MB is reached"))
--o1:depends("enb_limit", "1")

function o:validate(Value)
	local failure	
	if not Value:match("^[+%d]%d*$") then
		m.message = translate("err: mobile data limit value is incorrect!")
		return nil
	elseif Value == "" then
		m.message = translate("err: mobile data limit value is empty!")
		return nil
	end
	return Value
end

o = s:taboption("primarytab", ListValue, "prim_wrn_period", translate("Period"), translate("Period for which SMS warning for mobile data limit should apply"))
o:value("month", translate("Month"))
o:value("week", translate("Week"))
o:value("day", translate("Day"))

o = s:taboption("primarytab", ListValue, "prim_wrn_day", translate("Start day"), translate("A starting day in a month for mobile data limit SMS warning"))
o:depends({prim_wrn_period = "month"})
for i=1,31 do
	o:value(i, i)
end

o = s:taboption("primarytab", ListValue, "prim_wrn_hour", translate("Start hour"), translate("A starting hour in a day for mobile data limit SMS warning"))
o:depends({prim_wrn_period = "day"})
for i=1,23 do
	o:value(i, i)
end
o:value("0", "24")

o = s:taboption("primarytab", ListValue, "prim_wrn_weekday", translate("Start day"), translate("A starting day in a week for mobile data limit SMS warning"))
o:value("1", translate("Monday"))
o:value("2", translate("Tuesday"))
o:value("3", translate("Wednesday"))
o:value("4", translate("Thursday"))
o:value("5", translate("Friday"))
o:value("6", translate("Saturday"))
o:value("0", translate("Sunday"))
o:depends({prim_wrn_period = "week"})


e = s:taboption("primarytab", Value, "prim_wrn_number", translate("Phone number"), translate("A phone number to send warning SMS message to, e.g. +37012345678"))

-------------------------
--Secondary taboptions---
-------------------------
e = s:taboption("secondarytab", Value, "field3")
e.template = "cbi/legend"
e.titleText = "Data Connection Limit Configuration"

sec_enb_conn = s:taboption("secondarytab", Flag, "sec_enb_conn", translate("Enable data connection limit"), translate("Disables mobile data when a limit for current period is reached"))
sec_enb_conn.rmempty = false

o1 = s:taboption("secondarytab", Value, "sec_conn_limit", translate("Data limit* (MB)"), translate("Disable mobile data after limit value in MB is reached"))
--o1:depends("enb_limit", "1")

function o1:validate(Value)
	local failure	
	if not Value:match("^[+%d]%d*$") then
		m.message = translate("err: mobile data limit value is incorrect!")
		return nil
	elseif Value == "" then
		m.message = translate("err: mobile data limit value is empty!")
		return nil
	end
	return Value
end

o = s:taboption("secondarytab", ListValue, "sec_conn_period", translate("Period"), translate("Period for which mobile data limiting should apply"))
o:value("month", translate("Month"))
o:value("week", translate("Week"))
o:value("day", translate("Day"))

o = s:taboption("secondarytab", ListValue, "sec_conn_day", translate("Start day"), translate("A starting time for mobile data limiting period"))
o:depends({sec_conn_period = "month"})
for i=1,31 do
	o:value(i, i)
end

o = s:taboption("secondarytab", ListValue, "sec_conn_hour", translate("Start hour"), translate("A starting time for mobile data limiting period"))
o:depends({sec_conn_period = "day"})
for i=1,23 do
	o:value(i, i)
end
o:value("0", "24")

o = s:taboption("secondarytab", ListValue, "sec_conn_weekday", translate("Start day"), translate("A starting time for mobile data limiting period"))
o:value("1", translate("Monday"))
o:value("2", translate("Tuesday"))
o:value("3", translate("Wednesday"))
o:value("4", translate("Thursday"))
o:value("5", translate("Friday"))
o:value("6", translate("Saturday"))
o:value("0", translate("Sunday"))
o:depends({sec_conn_period = "week"})


--------------------------------------------------------------------------------
--------------------SMS warninig section----------------------------------------
--------------------------------------------------------------------------------

e = s:taboption("secondarytab", Value, "field4")
e.template = "cbi/legend"
e.titleText = "SMS Warning Configuration"

o = s:taboption("secondarytab", Flag, "sec_enb_wrn", translate("Enable SMS warning"), translate("Enables sending of warning SMS message when mobile data limit for current period is reached"))
o.rmempty = false

o = s:taboption("secondarytab", Value, "sec_wrn_limit", translate("Data limit* (MB)"), translate("Send warning SMS message after limit value in MB is reached"))

function o:validate(Value)
	local failure	
	if not Value:match("^[+%d]%d*$") then
		m.message = translate("err: mobile data limit value is incorrect!")
		return nil
	elseif Value == "" then
		m.message = translate("err: mobile data limit value is empty!")
		return nil
	end
	return Value
end

o = s:taboption("secondarytab", ListValue, "sec_wrn_period", translate("Period"), translate("Period for which mobile data limiting should apply"))
o:value("month", translate("Month"))
o:value("week", translate("Week"))
o:value("day", translate("Day"))

o = s:taboption("secondarytab", ListValue, "sec_wrn_day", translate("Start day"), translate("A starting time for mobile data limiting period"))
o:depends({sec_wrn_period = "month"})
for i=1,31 do
	o:value(i, i)
end

o = s:taboption("secondarytab", ListValue, "sec_wrn_hour", translate("Start hour"), translate("A starting time for mobile data limiting period"))
o:depends({sec_wrn_period = "day"})
for i=1,23 do
	o:value(i, i)
end
o:value("0", "24")

o = s:taboption("secondarytab", ListValue, "sec_wrn_weekday", translate("Start day"), translate("A starting time for mobile data limiting period"))
o:value("1", translate("Monday"))
o:value("2", translate("Tuesday"))
o:value("3", translate("Wednesday"))
o:value("4", translate("Thursday"))
o:value("5", translate("Friday"))
o:value("6", translate("Saturday"))
o:value("0", translate("Sunday"))
o:depends({sec_wrn_period = "week"})

e = s:taboption("secondarytab", Value, "sec_wrn_number", translate("Phone number"), translate("A phone number to send warning SMS message to, e.g. +37012345678"))

function m.on_commit(map)
	
	local primEnbCon = prim_enb_conn:formvalue("limit")
	local primEnbWrn = prim_enb_wrn:formvalue("limit")
	local secEnbConn = sec_enb_conn:formvalue("limit")
	local secEnbWrn = sec_enb_conn:formvalue("limit")
	cecho("on_commit")
	if secEnbWrn == "1" or primEnbCon == "1" or primEnbWrn == "1" or secEnbConn == "1" then
		m.uci:set("mdcollectd", "config", "datalimit", "1")
	else
		m.uci:set("mdcollectd", "config", "datalimit", "0")
		
	end
	m.uci:save("mdcollectd")
	m.uci:commit("mdcollectd")
end

return m
 
