local m, s, e, v

m = Map("auto_update", translate("Firmware Over The Air Configuration"), translate(""))
s = m:section(NamedSection, "auto_update","auto_update", translate("Server Settings"))
s.addremove = false

v = s:option(Value, "server_url", translate("Server address"),translate("Specify server address where to check for updates"))
v.rmempty = false

v = s:option(Value, "userName", translate("User name"),translate("Type in username"))
v.rmempty = true

v = s:option(Value, "password", translate("Password"),translate("Type in password"))
v.password = true
v.rmempty = true

e = s:option(Flag, "enable", translate("Enable auto check"), translate("Check to enable auto check"))
e.rmempty = true

action = s:option(ListValue, "mode", translate("Auto check mode"), translate("Select mode when to check for updates"))
action:value("on_start", translate("On router startup"))
action:value("periodic", translate("Periodic check"))

day = s:option(StaticList, "day", translate("Days"), translate("Select weekdays when to check for updates"))
	day:value("7",translate("Sunday"))
	day:value("1",translate("Monday"))
	day:value("2",translate("Tuesday"))
	day:value("3",translate("Wednesday"))
	day:value("4",translate("Thursday"))
	day:value("5",translate("Friday"))
	day:value("6",translate("Saturday"))
day:depends({mode="periodic"})

t = s:option(Value, "hours", translate("Hours"), translate("Specify hours for auto check (must be between 0 and 23)"))
t.default = "23"
t.datatype = "range(0,23)"
t:depends({mode="periodic"})

t = s:option(Value, "minutes", translate("Minutes"), translate("Specify minutes for auto check (must be between 0 and 59)"))
t.default = "0"
t.datatype = "range(0,59)"
t:depends({mode="periodic"})

e = s:option(Flag, "not_mobile", translate("WAN wired"), translate("Check if WAN is wired"))
e.rmempty = false

return m
