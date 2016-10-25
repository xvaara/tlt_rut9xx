--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2011 Jo-Philipp Wich <xm@subsignal.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: status.lua 8330 2012-03-04 18:36:05Z jow $
]]--

module("luci.controller.admin.status", package.seeall)
local uci = require("luci.model.uci").cursor()
local luasql = require "lsqlite3"
local sys = require "luci.sys"
local nw = require "luci.model.network"
require "socket"
function index()
	local show = require("luci.tools.status").show_mobile()
	local uci = require("uci").cursor()
	local bus = require "ubus"
	local _ubus = bus.connect()
	local has_3g   = false
	local has_wimax= false
	local modelservice = "3G"
	local moduleVidPid = luci.util.trim(luci.sys.exec("uci get system.module.vid"))..":"..luci.util.trim(luci.sys.exec("uci get system.module.pid"))
	local moduleType = luci.util.trim(luci.sys.exec("uci get system.module.type"))
	local moduleIface = luci.util.trim(luci.sys.exec("uci get system.module.iface"))

	if moduleType == "3g" or moduleType == "3g_ppp" then
		has_3g = true
	end
	
	uci:foreach("network", "interface",
	function (section)
		local ifname = uci:get(
			"network", section[".name"], "ifname"
		)
		local metric = uci:get(
			"network", section[".name"], "metric"
		)
		local info1
		local string1
		if "usb0" == ifname then
			string1 = "network.interface." .. tostring(section[".name"])
			info1 = _ubus:call(string1, "status", { })
			
			if info1 and info1['ipv4-address'] then
				local a
				for _, a in ipairs(info1['ipv4-address']) do
					if a.address  then
						has_wimax = true
					end
				end
			end
		end
	end
)
	if moduleVidPid == "12D1:1573" or moduleVidPid == "12D1:15C1" or moduleVidPid == "12D1:15C3" then
		modelservice = "LTE"
 	end
	local function rut_model()
		x = uci.cursor()
		local rutName
		x:foreach("system", "system", function(s)
			rutName = s.type
		end)
		return rutName or "unknown"
	end
	entry({"admin", "status"}, alias("admin", "status", "overview"), _("Status"), 20).index = true
	entry({"admin", "status", "overview"}, template("admin_status/index"), _("Overview"), 1)
	entry({"admin", "status", "sysinfo"}, template("admin_status/system"), _("System"), 2)

	if show then
		entry({"admin", "status", "netinfo"}, alias("admin", "status", "netinfo", "mobile" ), _("Network"), 3)
	else
		entry({"admin", "status", "netinfo"}, alias("admin", "status", "netinfo", "wan" ), _("Network"), 3)
	end
	if has_wimax then
		entry({"admin", "status", "netinfo", "wimax"}, template("admin_status/netinfo_wimax"), _("WiMAX"), 2).leaf = true
	end

	if show then
		entry({"admin", "status", "netinfo", "mobile" }, template("admin_status/netinfo_lte"), _("Mobile"), 1).leaf = true
	end
	entry({"admin", "status", "netinfo","wan"}, template("admin_status/netinfo_wan"), _("WAN"), 3).leaf = true
	entry({"admin", "status", "netinfo","lan"}, template("admin_status/netinfo_lan"), _("LAN"), 4).leaf = true
	entry({"admin", "status", "netinfo","wireless"}, template("admin_status/netinfo_wireless"), _("Wireless"), 5).leaf = true
	entry({"admin", "status", "netinfo","openvpn"}, template("admin_status/netinfo_openvpn"), _("OpenVPN"), 6).leaf = true
	entry({"admin", "status", "netinfo","vrrp"}, template("admin_status/netinfo_vrrp"), _("VRRP"), 7).leaf = true
	entry({"admin", "status", "netinfo","topology"}, template("admin_status/netinfo_topology"), _("Topology"), 8).leaf = true
	entry({"admin", "status", "netinfo","access"}, template("admin_status/netinfo_access"), _("Access"), 9).leaf = true

	entry({"admin", "status", "device"}, template("admin_status/devinfo"), _("Device"), 4)
	entry({"admin", "status", "service"}, template("admin_status/services"), _("Services"), 5)

	entry({"admin", "status", "routes"}, template("admin_status/routes"), _("Routes"), 6)
	entry({"admin", "status", "syslog"}, call("action_syslog"), nil, nil)
	entry({"admin", "status", "dmesg"}, call("action_dmesg"), nil, nil)

	entry({"admin", "status", "operators"}, call("get_opers"), nil, nil)
	entry({"admin", "status", "connect_network"}, call("connect_network_switch"), nil, nil)
	entry({"admin", "status", "connect_auto"}, call("auto_connect"), nil, nil)
	entry({"admin", "status", "auto_select"}, call("auto_select_switch"), nil, nil)
	entry({"admin", "status", "start_dmn"}, call("send_command"), nil, nil)
	if show then
		entry({"admin", "status", "realtime"}, alias("admin", "status", "realtime", "mobile"), _("Graphs"), 7)
		entry({"admin", "status", "realtime", "mobile"}, template("admin_status/mobile"), _("Mobile Signal"), 1).leaf = true
		if has_wimax then
			entry({"admin", "status", "realtime", "wimax"}, template("admin_status/wimax"), _("WiMAX Signal"), 1).leaf = true
		end
	else
		entry({"admin", "status", "realtime"}, alias("admin", "status", "realtime", "load"), _("Graphs"), 7)
	end

	entry({"admin", "status", "realtime", "mobile_status"}, call("action_mobile")).leaf = true
	entry({"admin", "status", "realtime", "wimax_status"}, call("action_wimax")).leaf = true

	entry({"admin", "status", "realtime", "load"}, template("admin_status/load"), _("Load"), 2).leaf = true
	entry({"admin", "status", "realtime", "load_status"}, call("action_load")).leaf = true

	entry({"admin", "status", "realtime", "bandwidth"}, template("admin_status/bandwidth"), _("Traffic"), 3).leaf = true
	entry({"admin", "status", "realtime", "bandwidth_status"}, call("action_bandwidth")).leaf = true

	entry({"admin", "status", "realtime", "wireless"}, template("admin_status/wireless"), _("Wireless"), 4).leaf = true
	entry({"admin", "status", "realtime", "wireless_status"}, call("action_wireless")).leaf = true

	entry({"admin", "status", "realtime", "connections"}, template("admin_status/connections"), _("Connections"), 5).leaf = true
	entry({"admin", "status", "realtime", "connections_status"}, call("action_connections")).leaf = true


	entry({"admin", "status", "nameinfo"}, call("action_nameinfo")).leaf = true

	entry({"admin", "status", "speedtest"}, template("admin_status/speedtest"), _("Speed Test"), 9)

	entry({"admin", "status", "event"}, call("go_to"), _("Events Log"), 11)
	entry({"admin", "status", "event", "allevent"}, template("admin_status/allevent"), _("All Events"),1).leaf = true
	entry({"admin", "status", "event", "log"}, template("admin_status/eventlog"), _("System Events"),2).leaf = true
	entry({"admin", "status", "event", "connect"}, template("admin_status/connect"), _("Network Events"),3).leaf = true
	entry({"admin", "status", "event", "report"}, arcombine(cbi("events_reporting/events"), cbi("events_reporting/event-details")), _("Events Reporting"),4).leaf = true
	entry({"admin", "status", "event", "log_report"}, arcombine(cbi("eventslog_report/events"), cbi("eventslog_report/event-details")), _("Reporting Configuration"),5).leaf = true

end

function go_to()
 	luci.http.redirect(
	luci.dispatcher.build_url("admin", "status", "event", "allevent").."/")
end


function auto_connect(var)
	luci.http.prepare_content("application/json")
	local timeout = 30
	luci.sys.exec("ifdown ppp")
	sleep(1)
	while true do
		pid = assert(io.popen('pgrep gsmd', 'r'))
		local l = pid:read("*l")
		pid:close()
		if l then
			if var == "0" then
				uci:delete("simcard", "sim1", "numeric")
				uci:delete("network", "ppp", "numeric")
				uci:delete("network", "ppp", "mode")
				uci:delete("simcard", "sim1", "mode")
				uci:set("network", "ppp", "service", "auto")
			else
				uci:delete("simcard", "sim2", "numeric")
				uci:delete("network", "ppp", "numeric")
				uci:delete("network", "ppp", "mode")
				uci:delete("simcard", "sim2", "mode")
				uci:set("network", "ppp", "service", "auto")
			end
			uci:commit("save")
			uci:commit("network")
			uci:commit("simcard")
			local bwc = assert(io.popen('gsmctl -A AT+COPS=0' , 'r'))
			local l = bwc:read("*l")
			luci.http.prepare_content("application/json")
			if l == "OK" then
				luci.http.write_json("Registered")
			else
				luci.http.write_json("Not registered")
			end
			bwc:close()
			break
		else
			sleep(5)
			timeout = timeout - 5
			if timeout < 1 then
				luci.http.write_json("Gsmd id not running, try again.")
				break
			end
		end
	end
	luci.sys.exec("ifup ppp")
end
function connect_network(var, number, mode)
	luci.http.prepare_content("application/json")
	local sim_id = luci.util.trim(luci.sys.exec("/usr/sbin/sim_switch sim"))
	local timeout = 30
	local moduleVidPid = luci.util.trim(luci.sys.exec("uci get system.module.vid"))..":"..luci.util.trim(luci.sys.exec("uci get system.module.pid"))
	if mode == "Manual-Auto" and ( moduleVidPid == "12D1:15C1" or moduleVidPid == "12D1:15C3" ) then
		luci.http.write_json("Not supported")
		return nil
	end
	luci.sys.exec("ifdown ppp")
	sleep(1)
	while true do
		pid = assert(io.popen('pgrep gsmd', 'r'))
		local l = pid:read("*l")
		pid:close()
		if l then
			local num = luci.http.formvalue("numeric")
			local typ = luci.http.formvalue("acs_typ")
			local bwc
			local str
			local resp
			local cops
			local maximum = 10
			local c = 0
			if mode == "Manual-Auto" then 
				bwc = assert(io.popen('gsmctl -A AT+COPS=4,2,'..num..'' , 'r'))
				uci:set("simcard", sim_id, "mode", mode)
			else
				bwc = assert(io.popen('gsmctl -A AT+COPS=1,2,'..num..'' , 'r'))
				uci:delete("simcard", sim_id, "mode")
			end
			uci:set("simcard", sim_id, "numeric", num)
			uci:commit("save")
			uci:commit("simcard")
			luci.sys.exec("/usr/sbin/sim_switch config")

			local l = bwc:read("*l")
			if mode == "Manual-Auto" then
				if moduleVidPid ~= "1BC7:0021" and moduleVidPid ~= "1199:68C0" and moduleVidPid ~= "12D1:1573" and
					moduleVidPid ~= "1BC7:1201" and moduleVidPid ~= "05C6:9215" then
					luci.http.write_json("Not supported")
					break
				end

				sleep(6)
				local netState = luci.util.trim(luci.sys.exec("gsmctl -g"))
				while (netState == "searching" and c < maximum) do
					sleep(1)
					netState = luci.util.trim(luci.sys.exec("gsmctl -g"))
					c = c + 1
				end
				sleep(2)
				netState = luci.util.trim(luci.sys.exec("gsmctl -g"))
				if (netState == "denied") then
					luci.http.write_json(tostring(netState))
				else
					i, j = string.find(netState, "registered")
					if i ~= nil or j ~= nil then
						cops = luci.util.trim(luci.sys.exec("gsmctl -A AT+COPS?"))

						oper = string.match(cops, "\"%d+\"")
						oper = string.gsub(oper, '"', '')
						resp = string.sub(cops, 8, 8)
						if (resp == "4") or (resp == "1") then
							if oper ~= num then
								luci.http.write_json("registered automatic")
							else
								luci.http.write_json("registered manual")
							end
						elseif (resp == "0") then
							luci.http.write_json("registered automatic")
						end
					else
						luci.http.write_json("unregistered")
					end
				end
			else
				if moduleVidPid ~= "12D1:1573" and moduleVidPid ~= "1BC7:0021" and moduleVidPid ~= "1BC7:1201" and
					moduleVidPid ~= "12D1:15C1" and moduleVidPid ~= "1199:68C0" and moduleVidPid ~= "05C6:9215" then
					luci.http.write_json("Not supported")
					break
				end

				sleep(6)
				local netState = luci.util.trim(luci.sys.exec("gsmctl -g"))
				while (netState == "searching" and counter < maximum) do
					sleep(1)
					netState = luci.util.trim(luci.sys.exec("gsmctl -g"))
					counter = counter + 1
				end
				sleep(2)
				netState = luci.util.trim(luci.sys.exec("gsmctl -g"))
				if (netState == "denied") then
					luci.http.write_json(tostring(netState))
				else
					i, j = string.find(netState, "unregistered")
					if i ~= nil or j ~= nil then
						cops = luci.util.trim(luci.sys.exec("gsmctl -A AT+COPS?"))
						resp = string.sub(cops, 8, 8)
						if (resp == "1") then
							luci.http.write_json("unregistered")
						end
					else
						i, j = string.find(netState, "registered")
						if i ~= nil or j ~= nil then
							str = string.sub(netState, i, j)
							sleep(1)
							cops = luci.util.trim(luci.sys.exec("gsmctl -A AT+COPS?"))
							resp = string.sub(cops, 8, 8)
							oper = string.match(cops, "\"%d+\"")
							oper = string.gsub(oper, '"', '')
							if (resp == "1") then
								if oper ~= num then
									luci.http.write_json("registered automatic")
								else
									luci.http.write_json("registered manual")
								end
							elseif (resp == "0") then
								luci.http.write_json("registered automatic")
							end
						end
					end
				end
			end
			bwc:close()
			break
		else
			sleep(5)
			timeout = timeout - 5
			if timeout < 1 then
				luci.http.write_json("Gsmd is not running, try again.")
				break
			end
		end
	end
	luci.sys.exec("ifup ppp")
end

function debug(string)
	luci.sys.call("logger \"status.lua "..os.date().." ".. string .. "\"")
end

function sleep(n)
	socket.select(nil, nil, n)
end

function send_command()
	luci.util.exec("ifdown ppp")
	luci.util.exec("/etc/init.d/ledsman stop")
	os.execute("sleep 2")
	os.execute("/sbin/switch_checker.sh &")
end

function up_connection()
	luci.util.exec("ifup ppp")
	luci.util.exec("/etc/init.d/ledsman start")
	os.remove('/tmp/operators')
end

function get_opers()
	--Parsina duomenis is failo
	if fileExists("/tmp/", "operators") then
		local operators = {}
		local bwc = assert(io.open('/tmp/operators' , 'r'))
		local timeout = 10
		luci.http.prepare_content("application/json")
		--debug(" get opers")
		while true do
			local l = bwc:read("*l")
			if l then
				os.execute("cp /tmp/operators /tmp/opers")
				if l:match("OK") == "OK" then
					--debug("Match OK")
					up_connection()
					break
				end

				if l:match("Timeout") == "Timeout" then
					--debug("Timeout")
					operators = "timeout"
					luci.http.write_json(operators)
					up_connection()
					break
				end

				if l:match("error") == "error" then
					--debug("error")
					operators = "error"
					luci.http.write_json(operators)
					up_connection()
					break
				end

				if l:match("+COPS:") then
					--debug("+cops")
					l = string.gsub(l, "+COPS:", "")
					local i = 1
					for word in string.gmatch(l, '%b()') do
						local n = 1
						operators[i] = {}
						for val in string.gmatch(word, '([^(),]+)') do
							val = string.gsub(val, '"', "")
							if val == "" then
								val = "-"
							end
							operators[i][n] = tostring(val)
							n = n + 1
						end
						i = i + 1
					end
					--debug("send opers data")
					luci.http.write_json(operators)
					bwc:close()
					up_connection()
					return
				end
			else
				--debug("wait")
				luci.http.write_json("wait")
				bwc:close()
				return
			end
		end
	end
end

function action_syslog()
	local syslog = luci.sys.syslog()
	luci.template.render("admin_status/syslog", {syslog=syslog})
end

function action_dmesg()
	local dmesg = luci.sys.dmesg()
	luci.template.render("admin_status/dmesg", {dmesg=dmesg})
end

function action_bandwidth()
	local path  = luci.dispatcher.context.requestpath
	local iface = path[#path]

	luci.http.prepare_content("application/json")

	local bwc = io.popen("luci-bwc -i %q 2>/dev/null" % iface)
	if bwc then
		luci.http.write("[")

		while true do
			local ln = bwc:read("*l")
			if not ln then break end
			luci.http.write(ln)
		end

		luci.http.write("]")
		bwc:close()
	end
end

function action_wireless()
	local path  = luci.dispatcher.context.requestpath
	local iface = path[#path]

	luci.http.prepare_content("application/json")

	str=sys.exec("iwinfo %q info" % iface)
	for line in str:gmatch("[^\r\n]+") do
		if line:find("Signal: ") then
			s = string.gsub(line,"Signal: ","")
			if s:find(" dBm  Noise:") then
				signal = string.gsub(string.gsub(s," dBm  Noise:.*","")," ","")
			else
				signal = -100
			end
			n = string.gsub(line,"Signal:.*: ","")
			if n:find(" dBm") then
				noise = string.gsub(string.gsub(n," dBm", "")," ","")
			else
				noise = -100
			end
		end

		if line:find("Bit Rate: ") then
			r = string.gsub(string.gsub(line, "Bit Rate: ",""),".0","")
			if r:find(" MBit/s") then
				rate = string.gsub(string.gsub(r," MBit/s","")," ","")
			else
				rate = 0
			end
		end
	end





	luci.http.write("[")
	local ln = "[ " .. luci.sys.uptime() .. ", " .. rate .. ", " .. signal .. ", " .. noise .. "]"
	luci.http.write(ln)
	luci.http.write("]")
end

function action_load()
	luci.http.prepare_content("application/json")

	local bwc = io.popen("luci-bwc -l 2>/dev/null")
	if bwc then
		luci.http.write("[")

		while true do
			local ln = bwc:read("*l")
			if not ln then break end
			luci.http.write(ln)
		end

		luci.http.write("]")
		bwc:close()
	end
end

function action_mobile()
	luci.http.prepare_content("application/json")
	local s = io.popen("gsmctl -t 2>/dev/null")
	local signal = s:read("*l")
	local str = io.popen("gsmctl -q 2>/dev/null")
	local strength = str:read("*l")
	--2G:
	local GSM = -120
	local GPRS = -120
	local EDGE = -120

	--3G:
	local WCDMA = -120
	local HSDPA = -120
	local HSUPA = -120
	local HSPA = -120
	local HSPAplus = -120
	local DCHSPAplus = -120

	--4G:
	local LTE = -120

	local con_type = 10

	if signal == "GSM" then
		GSM = strength
		con_type = 0
	elseif signal == "GPRS" then
		GPRS = strength
		con_type = 1
	elseif signal == "EDGE" then
		EDGE = strength
		con_type = 2
	elseif signal == "WCDMA" then
		WCDMA = strength
		con_type = 3
	elseif signal == "HSDPA" then
		HSDPA = strength
		con_type = 4
	elseif signal == "HSUPA" or signal == "HSDPA/HSUPA" then
		HSUPA = strength
		con_type = 5
	elseif signal == "HSPA" then
		HSPA = strength
		con_type = 6
	elseif signal == "HSPA+" then
		HSPAplus = strength
		con_type = 7
	elseif signal == "DC-HSPA+" then
		DCHSPAplus = strength
		con_type = 8
	elseif signal == "LTE" then
		LTE = strength
		con_type = 9
	end

	luci.http.write("[")
	local ln = "[ " .. luci.sys.uptime() .. ", " .. GSM .. ", " .. GPRS .. ", " .. EDGE .. ", " .. WCDMA .. ", " .. HSDPA .. ", " .. HSUPA .. ", " .. HSPA .. ", " .. HSPAplus .. ", " .. DCHSPAplus .. ", " .. LTE .. ", " .. con_type .. "]"
	luci.http.write(ln)
	luci.http.write("]")
	str:close()
	s:close()
end
function action_wimax()
	luci.http.prepare_content("application/json")

	local strength = nw:wimaxCGICall({ call ="signal-strength" })

	luci.http.write("[")
	local ln = "[ " .. luci.sys.uptime() .. ", " .. strength .."]"
	luci.http.write(ln)
	luci.http.write("]")
end
function action_connections()
	local sys = require "luci.sys"

	luci.http.prepare_content("application/json")

	luci.http.write("{ connections: ")
	luci.http.write_json(sys.net.conntrack())

	local bwc = io.popen("luci-bwc -c 2>/dev/null")
	if bwc then
		luci.http.write(", statistics: [")

		while true do
			local ln = bwc:read("*l")
			if not ln then break end
			luci.http.write(ln)
		end

		luci.http.write("]")
		bwc:close()
	end

	luci.http.write(" }")
end

function action_temperature()
	luci.http.prepare_content("application/json")
	local tmp = io.popen("cat /tmp/temperature")
	local temperature = tmp:read("*l")
	local dot = string.find(temperature, "%.")
	if string.len(temperature) - dot == 6 then
		luci.http.write("[")
		local ln = "[ " .. luci.sys.uptime() .. ", " .. temperature .. "]"
		luci.http.write(ln)
		luci.http.write("]")
	end
	tmp:close()
end

function action_nameinfo(...)
	local i
	local rv = { }
	for i = 1, select('#', ...) do
		local addr = select(i, ...)
		local fqdn = nixio.getnameinfo(addr)
		rv[addr] = fqdn or (addr:match(":") and "[%s]" % addr or addr)
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end

function fileExists(path, name)
	local string = "ls ".. path
	local h = io.popen(string)
	local t = h:read("*all")
	h:close()

	for i in string.gmatch(t, "%S+") do
		if i == name then
			return 1
		end
	end
end

function auto_select_switch()
	luci.http.prepare_content("application/json")
	local timeout = 30
	local var = luci.http.formvalue("numeric")
	local activeSim = luci.http.formvalue("active")
	if var == "0" and activeSim == "SIM 1" or var == "1" and activeSim == "SIM 2" then
		auto_connect(var)
	else
		auto_select(var)
	end

end

function connect_network_switch() -- depends on selected tab and current active sim
	luci.http.prepare_content("application/json")
	local timeout = 30
	local number = luci.http.formvalue("numeric")
	local activeSim = luci.http.formvalue("active")
	local var = luci.http.formvalue("numerictab")
	local mode = luci.http.formvalue("oper_mode")
	if var == "0" and activeSim == "SIM 1" or var == "1" and activeSim == "SIM 2" then
		connect_network(var, number, mode)
	else
		select_network(var, number, mode)
	end

end
function select_network(var, number, mode)
	luci.http.prepare_content("application/json")
	local timeout = 30
	local sim_id
	--local var = luci.http.formvalue("numeric")
	--luci.sys.exec("ifdown ppp")
	if var == "0" then
		sim_id="sim1"
	else
		sim_id="sim2"
	end
	uci:set("simcard", sim_id, "numeric", number)
	if mode == "Manual-Auto" then
		uci:set("simcard", sim_id, "mode", mode)
	else
		uci:delete("simcard", sim_id, "mode")
	end
	uci:commit("save")
	uci:commit("simcard")
	local l
	if var == "0" then
		l = luci.util.trim(luci.sys.exec("uci -q get simcard.sim1.numeric"))
	else
		l = luci.util.trim(luci.sys.exec("uci -q get simcard.sim2.numeric"))
	end
	luci.http.prepare_content("application/json")
	if l ~= "" then
		luci.http.write_json("Selected")
	else
		luci.http.write_json("Not selected")
	end
end

function auto_select(var)
	luci.http.prepare_content("application/json")
	local timeout = 30
	--local var = luci.http.formvalue("numeric")
	--luci.sys.exec("ifdown ppp")
	if var == "0" then
		uci:delete("simcard", "sim1", "numeric")
		uci:delete("simcard", "sim1", "mode")
		--uci:set("network", "ppp", "service", "auto")
	else
		uci:delete("simcard", "sim2", "numeric")
		uci:delete("simcard", "sim2", "mode")
		--uci:set("network", "ppp", "service", "auto")
	end
	uci:commit("save")
	--uci:commit("network")
	uci:commit("simcard")
	local l
	if var == "0" then
		l = luci.util.trim(luci.sys.exec("uci -q get simcard.sim1.numeric"))
	else
		l = luci.util.trim(luci.sys.exec("uci -q get simcard.sim2.numeric"))
	end
	luci.http.prepare_content("application/json")
	if l == "" then
		luci.http.write_json("Selected")
	else
		luci.http.write_json("Not selected")
	end
end
