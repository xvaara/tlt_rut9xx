local dsp = require "luci.dispatcher"

arg[1] = arg[1] or ""

m = Map( "output_control", translate( "Periodic Output Control" ), translate( "" ) )
m.redirect = dsp.build_url("admin/services/input-output/output/periodic/")

snt = m:section( NamedSection, arg[1], "rule", translate("Edit Output Control Rule"), translate("" ))
snt.addremove = false
snt.anonymous = true

enb = snt:option(Flag, "enabled", translate("Enable"), translate("Enable output control configuration"))

pin = snt:option(ListValue, "gpio", translate("Output"), translate("Specifies for which output type rule will be applied"))
	pin:value("DOUT1", "Digital OC output")
	pin:value("DOUT2", "Digital relay output")

act = snt:option(ListValue, "action", translate("Action"), translate("Specifies what action will happen"))
	act:value("on", translate("On"))
	act:value("off", translate("Off"))

del = snt:option(Flag, "timeout", translate("Action timeout"), translate("Specifies if action should end after some time"))
	del.datatype = "integer"

tim = snt:option(Value, "timeout_time", translate("Timeout (sec)"), translate("Specifies after how much time this action should end"))
	tim.datatype = "integer"

tns = snt:option( ListValue, "mode", translate("Mode"), translate("Repetition mode. It can be fixed (happens at specified time) or interval (happens constantly after specified time from each other)"))
	tns:value( "fixed", translate("Fixed" ))
	tns:value( "interval", translate("Interval" ))

thr = snt:option( Value, "fixed_hour", translate("Hours"), translate("Specifies exact hour"))
	thr.datatype = "range(0,23)"
	thr:depends( "mode", "fixed" )

tmn = snt:option( Value, "fixed_minute", translate("Minutes"), translate("Specifies exact minutes"))
	tmn:depends( "mode", "fixed" )
	tmn.datatype = "range(0,59)"

time = snt:option(ListValue, "interval_time", translate("Interval"), translate("Specifies the interval of the selected action"))
	time:depends("mode", "interval")
	time:value("1", translate("1 min"))
	time:value("2", translate("2 mins"))
	time:value("3", translate("3 mins"))
	time:value("4", translate("4 mins"))
	time:value("5", translate("5 mins"))
	time:value("10", translate("10 mins"))
	time:value("15", translate("15 mins"))
	time:value("30", translate("30 mins"))
	time:value("60", translate("1 hour"))
	time:value("120", translate("2 hours"))
	time:value("180", translate("3 hours"))
	time:value("240", translate("4 hours"))
	time:value("360", translate("6 hours"))
	time:value("480", translate("8 hours"))
	time:value("720", translate("12 hours"))

twd = snt:option(StaticList, "day", translate("Days"), translate("Specifies in which weekdays action should happen"))
	twd:value("mon",translate("Monday"))
	twd:value("tue",translate("Tuesday"))
	twd:value("wed",translate("Wednesday"))
	twd:value("thu",translate("Thursday"))
	twd:value("fri",translate("Friday"))
	twd:value("sat",translate("Saturday"))
	twd:value("sun",translate("Sunday"))

return m
