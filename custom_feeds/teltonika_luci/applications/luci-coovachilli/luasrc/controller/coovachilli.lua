--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: coovachilli.lua 7362 2011-08-12 13:16:27Z jow $
]]--

module("luci.controller.coovachilli", package.seeall)

function index()

require("uci")
local x = uci.cursor()
local listofssids = {}
x:foreach("wireless", "wifi-iface", function(s)
		table.insert(listofssids, s.ssid)
	end)

entry( { "admin", "services", "hotspot" }, alias("admin", "services", "hotspot", "general"), _("Hotspot"), 90)
	entry({"admin", "services", "hotspot", "general"}, arcombine(template("chilli/hotspot_overview"), cbi("coovachilli"), template("chilli/clients_managing")),_("General"), 1).leaf = true
	entry({"admin", "services", "hotspot", "user_edit"}, cbi("user_edit")).leaf = true
	entry({"admin", "services", "hotspot", "session_edit"}, cbi("session_edit")).leaf = true
	if listofssids[1] ~= nil then
		entry({"admin", "services", "hotspot", "statistics"}, alias("admin", "services", "hotspot", "statistics", listofssids[1]), _("Statistics"), 6)
		entry({"admin", "services", "hotspot", "hotspot_scheduler"}, alias("admin", "services", "hotspot", "hotspot_scheduler", listofssids[1]), _("Restricted Internet Access"), 2)
		--entry({"admin", "services", "hotspot", "landing"}, alias("admin", "services", "hotspot", "landing", listofssids[1]), _("Landing Page"), 4)

		for Index, Value in pairs( listofssids ) do
			--entry({"admin", "services", "hotspot", "landing", Value}, alias("admin", "services", "hotspot", "landing", Value, "general"), _(Value), Index)
			--entry({"admin", "services", "hotspot", "landing", Value, "general"}, cbi("coovachilli_landing"), _("General"), Index).leaf = true
			--entry({"admin", "services", "hotspot", "landing", Value, "edit"}, cbi("coovachilli_landing_edit"), _("Template"), Index).leaf=true
			entry({"admin", "services", "hotspot", "statistics", Value}, template("chilli/statistics"), _(Value), Index).leaf = true
			entry({"admin", "services", "hotspot", "hotspot_scheduler", Value}, cbi("hotspot_scheduler"), _(Value), Index).leaf = true
		end
	else
		entry({"admin", "services", "hotspot", "hotspot_scheduler"}, template("hotspot_scheduler_nossid"), _("Restricted Internet Access"), 2).leaf = true
	end
	entry({"admin", "services", "hotspot", "loging"}, alias("admin", "services", "hotspot", "loging", "configuration"), _("Logging"), 3)
		entry({"admin", "services", "hotspot", "loging", "configuration"}, cbi("coovachilli_logging"), _("Configuration"), 1).leaf = true
		entry({"admin", "services", "hotspot", "loging", "wifilog"}, template("chilli/log"), _("Log"), 2).leaf = true
 	entry({"admin", "services", "hotspot", "landing"}, alias("admin", "services", "hotspot", "landing", "general"), _("Landing Page"), 4)
 		entry({"admin", "services", "hotspot", "landing", "general"}, cbi("coovachilli_landing"), _("General"), 1).leaf = true
 		entry({"admin", "services", "hotspot", "landing", "edit"}, cbi("coovachilli_landing_edit"), _("Template"), 2).leaf=true
	--entry({"admin", "services", "hotspot", "statistics"}, template("chilli/statistics"), _("Statistics"), 6).leaf = true


	entry({"admin", "services", "hotspot", "delete_mac"}, call("delete_mac")).leaf = true
entry({"admin", "services", "hotspot", "onoff"}, call("enable_disable"), nil).leaf = true
entry({"admin", "services", "hotspot", "logout"}, call("hotspot_logout"), nil).leaf = true


	--cc.i18n = "hotspot"
	--cc.subindex = true

-- 	entry( { "admin", "services", "coovachilli", "network" }, cbi("coovachilli_network"), _("Network Configuration"),      10)
-- 	entry( { "admin", "services", "coovachilli", "radius"  }, cbi("coovachilli_radius"),  _("RADIUS configuration"),       20)
-- 	entry( { "admin", "services", "coovachilli", "auth"    }, cbi("coovachilli_auth"),    _("UAM and MAC Authentication"), 30)

	entry({"admin", "services", "tmpldownload"}, call("tmpl_download"), nil, nil)
end

function tmpl_download()
	local path_to_file
	if luci.sys.exec("uci get -q landingpage.general.loginPage") == "" then
		path_to_file = "cat /etc/chilli/www/hotspotlogin.tmpl - 2>/dev/null"
	elseif luci.sys.exec("uci get -q landingpage.general.loginPage") ~= "" then
		kelias = luci.sys.exec("uci get -q landingpage.general.loginPage")
		path_to_file = "cat "..kelias.." - 2>/dev/null"
	end
	local reader = ltn12_popen(path_to_file)
	luci.http.header('Content-Disposition', 'attachment; filename="hotspotlogin.tmpl"')
	luci.http.prepare_content("application/text")
	luci.ltn12.pump.all(reader, luci.http.write)
end

function hotspot_logout()
	local mac_addr = luci.http.formvalue("mac")
	local socket = luci.http.formvalue("socket")
	local response = logout(mac_addr, socket) or 0
	luci.http.prepare_content("application/json")
	luci.http.write_json({response = response})
end

function logout(mac_addr, socket)
	if mac_addr and socket then
		local command = string.format("/usr/sbin/chilli_query -s %s logout %s", socket, mac_addr)
		local res = io.popen(command)
		if res and res:read("*all") == "" then
			return  1
		end
	end

	return 0
end

function enable_disable()
	local uci = require "luci.model.uci".cursor()
	local rv={}
	local section = luci.http.formvalue("sid")
	local config = "coovachilli"
	local option = "enabled"
	local response

	if section then
		local enabled=uci:get(config, section, option)
		--os.execute("logger ok" .. enabled)
		if enabled ~= nil and enabled == "1" then
			uci:set(config, section, option, "0")
			response = 0
		else
			uci:set(config, section, option, "1")
			response = 1
		end
		uci:commit(config)
-- 		response=luci.sys.exec("/sbin/wifi up; echo $?")
		--luci.sys.exec("/sbin/luci-reload coovachilli &")
		luci.sys.exec("/etc/init.d/chilli restart")
		rv={
			response=response
		}
	end
		luci.http.prepare_content("application/json")
		luci.http.write_json(rv)
	return
end

function delete_mac()
	require "teltonika_lua_functions"
	local sqlite = require "lsqlite3"
	local dbPath = "/var/"
	local dbName = "hotspot.db"
	local stat = 1
	local mac = luci.http.formvalue("mac")
	local ifname = luci.http.formvalue("ifname")
	local socket = string.format("/var/run/chilli.%s.sock", ifname)

	if fileExists(dbPath, dbName) and mac and mac ~= "" then
		local db
		db = sqlite.open(dbPath .. dbName)

		if db then
			local query = "DELETE FROM statistics WHERE mac='" .. mac .. "'"
			stmt = db:prepare(query)

			if stmt then
				stmt:step()
				stmt:finalize()
				stat = 0
				logout(mac, socket)
			end
			closeDB(db)
		end
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json({stat = stat})
	return
end

function ltn12_popen(command)

	local fdi, fdo = nixio.pipe()
	local pid = nixio.fork()

	if pid > 0 then
		fdo:close()
		local close
		return function()
			local buffer = fdi:read(2048)
			local wpid, stat = nixio.waitpid(pid, "nohang")
			if not close and wpid and stat == "exited" then
				close = true
			end

			if buffer and #buffer > 0 then
				return buffer
			elseif close then
				fdi:close()
				return nil
			end
		end
	elseif pid == 0 then
		nixio.dup(fdo, nixio.stdout)
		fdi:close()
		fdo:close()
		nixio.exec("/bin/sh", "-c", command)
	end
end
