--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2008 Jo-Philipp Wich <xm@leipzig.freifunk.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

$Id: profiles.lua 7362 2011-08-12 13:16:27Z jow $
]]--

module("luci.controller.profiles", package.seeall)

eventlog = require'tlt_eventslog_lua'
local uci = require "luci.model.uci".cursor()
local ds = require "luci.dispatcher"
local sys = require "luci.sys"
local utl = require "luci.util"
local path = uci:get("profiles", "profiles", "path")
enb_debug = false

function index()
	entry( {"admin", "system", "profiles"}, call("action_profiles"), _("Profiles"), 2)
end

function action_profiles()
	local long = false
	local zero = false
	local error_msg = false
	local alphanum = false
	local profnum = false
	local exist = false
	local reset_avail   = os.execute([[grep '"rootfs_data"' /proc/mtd >/dev/null 2>&1]]) == 0
	local sProtocol = "http"
	local sIP = "192.168.1.1"
	local sPort = "80"

	local sFile, sBuf, sLine, sPortHttp, sPortHttps
	local fs = require "nixio.fs"
	
	if luci.http.formvalue("profile-update-button") then
		debug("profile-update-button")
		--
		-- Update profile
		--
		local update = false
		local update_err = false
		local profile = luci.http.formvalue("profile-name")
		local profile_date = luci.http.formvalue("profile-date")
		local profilenumber = tonumber(profilecount())
		local a = updateProfile(profile, profile_date)
		
		if a == 0 then
			update = true
		else
			update_err = true
		end

		luci.template.render("profiles", {
			long = long,
			zero = zero,
			alphanum = alphanum,
			profnum = profnum,
			exist = exist,
			error_msg = error_msg,
			profile = profile,
			updated = update,
			update_err = update_err
		})
	elseif luci.http.formvalue("profile-add-button") then
		--
		-- Add profile
		--
		local profile = luci.http.formvalue("profile-add-name")
		local profilenumber = tonumber(profilecount())
		if #profile > 10 then
			long = true
		elseif #profile == 0 then
			zero = true
		elseif string.find(profile, "%W") then
			alphanum = true
		elseif profilenumber > 4 then
			profnum = true
		else
			local a = createProfile(profile)
			if a == 1 then
				exist = true
			elseif a == 2 then
				error_msg = true
			end
		end
		luci.template.render("profiles", {
			long = long,
			zero = zero,
			alphanum = alphanum,
			profnum = profnum,
			exist = exist,
			error_msg = error_msg,
			profile = profile
		})

	elseif luci.http.formvalue("profile-apply-button") then
		--
		-- Apply profile
		--
		profile_name = luci.http.formvalue("profile-name")
		profile_date = luci.http.formvalue("profile-date")
		if profile_name and profile_date then
			applyProfile(profile_name, profile_date)
			sIP = utl.trim(sys.exec("uci -q get network.lan.ipaddr"))
			wan = utl.trim(sys.exec(". /lib/teltonika-functions.sh; tlt_get_wan_ipaddr"))
			if wan == "" then
				wan = 0
			end
			uci:set("profiles", "profiles", "profile", profile_name)
			uci:set("profiles", "profiles", "date", profile_date)
			uci:save("profiles")
			uci:commit("profiles")

			sFile = "/rom/etc/config/uhttpd"
			if fs.access(sFile) then
				for sLine in io.lines(sFile) do
					if sLine:find("list listen_http\t") and sLine:find("#") ~= 1 then
						sBuf = string.match(sLine:match("(:%d+)"), "(%d+)")
						if sBuf ~= nil then
							sPortHttp = sBuf
						end
					end

					if sLine:find("list listen_https\t") and sLine:find("#") ~= 1 then
						sBuf = string.match(sLine:match("(:%d+)"), "(%d+)")
						if sBuf ~= nil then
							sPortHttps = sBuf
						end
					end
				end

				if sPortHttp ~= nil and sPortHttp ~= "0" then
					sPort = sPortHttp
					sProtocol = "http"
					elseif sPortHttps ~= nil and sPortHttps ~= "0" then
						sPort = sPortHttps
						sProtocol = "https"
				end
			end
		end

		luci.template.render("applying", {
			title = luci.i18n.translate("Restarting..."),
			msg  = luci.i18n.translate("The system is upgrading now."),
			msg1  = luci.i18n.translate("<b>DO NOT POWER OFF THE DEVICE!</b>"),
			msg2  = luci.i18n.translate("It might be necessary to change your computer\'s network settings to reach the device again, depending on your configuration."),
			sProtocol = sProtocol,
			sIP = sIP,
			sPort = sPort,
			wan = wan
		})
	elseif luci.http.formvalue("profile-delete-button") then
		--
		-- Delete profile
		--
		profile_name = luci.http.formvalue("profile-name")
		profile_date = luci.http.formvalue("profile-date")
		local path = uci:get("profiles", "profiles", "path")
		if profile_name and profile_date then
			local profile_cur = uci:get("profiles", "profiles", "profile")
			if profile_cur == profile_name then
				uci:set("profiles", "profiles", "profile", "")
				uci:set("profiles", "profiles", "date", "")
				uci:save("profiles")
				uci:commit("profiles")
			end
			os.remove(string.format("%s/%s_%s.tar.gz", path, profile_name, profile_date))
			os.remove(string.format("%s/%s_%s.md5", path, profile_name, profile_date))
		end
		luci.template.render("profiles", {
		})

	elseif reset_avail and luci.http.formvalue("reset") then
		--
		-- Reset system
		--
		luci.template.render("admin_system/applyreboot", {
			title = luci.i18n.translate("Erasing..."),
			msg   = luci.i18n.translate("The system is erasing the configuration partition now and will reboot itself when finished."),
			addr  = "192.168.1.1"
		})
		--shutdown_telit()
		fork_exec("killall dropbear uhttpd; sleep 1; mtd -r erase rootfs_data")
	elseif tonumber(luci.http.formvalue("step")) == 3 then
		profile_name = uci:get("profiles", "profiles", "profile", profile_name)

		t = {requests = "insert", table = "EVENTS", type="Profile", text="".. profile_name .." was applied "}
		eventlog:insert(t)
		luci.sys.call("luci-reload --check_all")
		luci.sys.call("luci-reload")
	else
		--
		-- Overview
		--
		luci.template.render("profiles", {
		  reset_avail   = reset_avail
		})
	end
end

function debug(string)
	if enb_debug then
		os.execute("echo \" luci-profiles: " ..string.. "\" >>/tmp/luci.log")
	end
end

function directory_exists(name)
	if type(name)~="string" then return false end
	return os.rename(name,name) and true or false
end

debug("Profiles page")
function createProfile(name)
	if name then
		if not directory_exists(path) then
			os.execute("mkdir " ..path)
		end
		local date = os.date("%F")
		local filename = string.format("%s_%s.tar.gz", name, date)
		local md5file = string.format("%s_%s.md5", name, date)
		local fullname = string.format("%s/%s", path, filename)
		local fullmd5 = string.format("%s/%s", path, md5file)
		if not fileExists(name) then
			debug("Saving profile to: " ..fullname)
			local h = io.popen(string.format("sysupgrade -p %s", fullname))
			h:close()
			h = io.popen(string.format("md5sum /etc/config/* /etc/shadow | grep -v profiles | md5sum > %s", fullmd5))
			h:close()
			if not fileExists(name) then
				return 2
			end
		else
			return 1
		end
	end
end

function read_whole_file(path)
	local file = assert(io.open(path, "r"))
	local text = file:read("*all")
	file:close()
	
	return text
end



function updateProfile(name, prof_date)
	if name and prof_date then
		if not directory_exists(path) then
			return 2
		end
		
		local filename = string.format("%s_%s.tar.gz", name, prof_date)
		local md5file = string.format("%s_%s.md5", name, prof_date)
		local fullname = string.format("%s/%s", path, filename)
		local fullmd5 = string.format("%s/%s", path, md5file)
		
		if not fileExists(name) then
			debug("Profile files does not exist " ..fullname)
			return 1
		else
			local md5s = getParam("md5sum /etc/config/* /etc/shadow | grep -v profiles | md5sum")
			os.remove(fullname)
			os.remove(fullmd5)
			local h = io.popen(string.format("sysupgrade -p %s", fullname))
			h:close()
			h = io.popen(string.format("md5sum /etc/config/* /etc/shadow | grep -v profiles | md5sum > %s", fullmd5))
			h:close()
			local curr_md5s = read_whole_file(fullmd5):gsub("\n", "")
				
			if md5s == curr_md5s then
				return 0
			end
		end
	end
	
	return 1
end

function applyProfile(name, date)
	if name and date then
		if fileExists(name) then
			local filename = string.format("%s_%s.tar.gz", name, date)
			local fullname = string.format("%s/%s", path, filename)
			os.execute("rm -r /etc/rc.d")
			local h = io.popen(string.format("tar -C / -xzf %s", fullname))
			h:close()
		end
	end
end

function fileExists(name)
	local list = fileList()
	for item in string.gmatch(list, "([%w_]+)_%d+-%d+-%d+%.tar%.gz") do
		if item == name then return 1 end
	end
end

function fileList()
	local cmd = "ls ".. path
	local h = io.popen(cmd)
	local t = h:read("*all")
	h:close()
	return t
end

function profilecount()
	local list = fileList()
	local count = "0"
	for item in string.gmatch(list, "([%w_]+)_%d+-%d+-%d+%.tar%.gz") do
		count = count + "1"
	end
	return count
end

function getParam(cmd)
	local h = io.popen(cmd)
	local t = h:read()
	h:close()
	return t
end
