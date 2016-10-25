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

module("luci.controller.mobile_traffic", package.seeall)
local uci = require("luci.model.uci").cursor()
local luasql = require "lsqlite3"
local utl = require "luci.util"

function index()
	local show = require("luci.tools.status").show_mobile()
	if show then
		--3G data usage page--
		entry({"admin", "status", "usage"}, call("go_to"), _("Mobile Traffic"), 8)

		entry({"admin", "status", "usage", "day"}, template("mobile_traffic/day_data_usage"), _("Today"), 1).leaf = true
		entry({"admin", "status", "usage", "usage_day"}, call("data_current")).leaf = true

		entry({"admin", "status", "usage", "week"}, template("mobile_traffic/week_data_usage"), _("Current Week"), 2).leaf = true
		entry({"admin", "status", "usage", "usage_week"}, call("data_days")).leaf = true

		entry({"admin", "status", "usage", "month"}, template("mobile_traffic/data_usage"), _("Current Month"), 3).leaf = true
		entry({"admin", "status", "usage", "usage_month"}, call("data_days")).leaf = true

		entry({"admin", "status", "usage", "year"}, template("mobile_traffic/year_data_usage"), _("Total"), 5).leaf = true
		entry({"admin", "status", "usage", "usage_month"}, call("data_days")).leaf = true
		entry({"admin", "status", "usage", "delete_all_data"}, call("reset_all_data")).leaf = true

		entry({"admin", "status", "usage", "config"}, cbi("mobile_traffic/configure"), _("Configuration"), 6).leaf = true
	end
end

function go_to()
	local enabled = utl.trim(luci.sys.exec("uci -q get mdcollectd.config.enabled")) or "0"
	local traffic = utl.trim(luci.sys.exec("uci -q get mdcollectd.config.traffic")) or "0"
	local datalimit = utl.trim(luci.sys.exec("uci -q get mdcollectd.config.datalimit")) or "0"
	if enabled == "1" or traffic == "1" or datalimit == "1" then
		luci.http.redirect(luci.dispatcher.build_url("admin", "status", "usage", "day").."/")
	else
		luci.http.redirect(luci.dispatcher.build_url("admin", "status", "usage", "config"))
	end
end

function data_days()
	local path  = luci.dispatcher.context.requestpath
	local sim = path[#path]
	sim = sim == "sim1" and "1" or sim == "sim2" and "0" or sim 

	local dbPath = "/var/"
	local dbName = "mdcollectd.db"
	local dbFullPath = dbPath .. dbName 
	local data = { }
	local query
	luci.http.prepare_content("application/json")
	if fileExists(dbPath, dbName) then
		local db = luasql.open(dbFullPath)
		if sim == "all" then
			query = string.format("SELECT * from days")
		else
			query = string.format("SELECT * from days WHERE sim=%s", sim)
		end
		local stmt = db:prepare(query)
		local count = 0

		if stmt then
			for row in db:nrows(query) do
				
				if #data > 0 then
					same_day = os.date("%d", data[#data].time) == os.date("%d", row.time)
					sim = data[#data].sim ~= row.sim
					if same_day and sim then
						data[#data].rx = data[#data].rx + row.rx
						data[#data].tx = data[#data].tx + row.tx

					else
						table.insert(data, row) 
					end
				else
					table.insert(data, row)
				end
				
			end
			--Prideda paskutini irasa is current lenteles
			if sim == "all" then
				query = string.format("SELECT * FROM current ORDER BY ROWID DESC LIMIT 1;")
			else
				query = string.format("SELECT * FROM current WHERE sim=0 ORDER BY ROWID DESC LIMIT 1;", sim)
			end
			local result = db:prepare(query)
			if result then
				for row in db:nrows(query) do
					local n = table.getn(data)
					data[n].rx = data[n].rx + row.rx
					data[n].tx = data[n].tx + row.tx
				end
			end
			if data then
				luci.http.write("[")
				for id, row in ipairs(data) do
					count = count+1
					if count > 1 then
						luci.http.write(string.format(","))
					end
					luci.http.write(string.format("[ %s, 0, %s, %s ]", row.time,  row.rx, row.tx))

				end
				luci.http.write("]")
			end
		end
		db:close()
	end
end

function reset_all_data(table, sim)
	sim = sim == "sim1" and "1" or sim == "sim2" and "0" or sim
	 --os.execute("echo \"" ..table.." l " ..sim.. "\">>/tmp/sim.log")
	local dbPath = "/var/"
	local dbName = "mdcollectd.db"
	local dbFullPath = dbPath .. dbName
	local query
	luci.http.prepare_content("application/json")
	if fileExists(dbPath, dbName) then
		local db = luasql.open(dbFullPath)
		if sim == "all" then
			query = string.format("DELETE FROM  %s", table)
		else
			query = string.format("DELETE FROM  %s WHERE sim=%s", table, sim)
		end
		os.execute("echo \"" ..table.." l " ..query.. "\">>/tmp/sim.log")
		local stmt = db:prepare(query)
		if stmt then
			stmt:step()
			stmt:finalize()
			db:close()
			luci.http.write("[1]")
		else
			db:close()
			luci.http.write("[0]")
		end
	end
end

function data_current()
	local path  = luci.dispatcher.context.requestpath
	local sim = path[#path]
	sim = sim == "sim1" and "1" or sim == "sim2" and "0" or sim 
	
	local dbPath = "/var/"
	local dbName = "mdcollectd.db"
	local dbFullPath = dbPath .. dbName 
	local query
	luci.http.prepare_content("application/json")
	
	if fileExists(dbPath, dbName) then
		local db = luasql.open(dbFullPath)
		local time = os.time()
		local year, month, day = tonumber(os.date("%Y", time)), tonumber(os.date("%m", time)), tonumber(os.date("%d", time))
		local timestamp = os.time{ year = year, month = month, day = day, hour = 00, min = 00, sec = 00 }
		
		if sim == "all" then
			query = string.format("SELECT * from current WHERE time >= %s;", timestamp)
		else
			query = string.format("SELECT * from current WHERE sim=%s AND time >= %s;", sim, timestamp)
		end
		local stmt = db:prepare(query)
		local count = 0
		luci.http.prepare_content("application/json")

		if stmt then
			luci.http.write("[")
			for row in db:nrows(query) do
				count = count+1
				if count > 1 then
					luci.http.write(string.format(","))
				end
				luci.http.write(string.format("[ %s, 0, %s, %s ]", row.time,  row.rx, row.tx))

			end
			luci.http.write("]")
		end
		db:close()
	end
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
