--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2008-2011 Jo-Philipp Wich <xm@subsignal.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: system.lua 8122 2011-12-20 17:35:50Z jow $
]]--

module("luci.controller.admin.system", package.seeall)
eventlog = require'tlt_eventslog_lua'

function index()
	entry({"admin", "system"}, alias("admin", "system", "admin"), _("System"), 50).index = true
-- 	entry({"admin", "system", "system"}, cbi("admin_system/system"), _("System"), 1)
	entry({"admin", "system", "clock_status"}, call("action_clock_status"))

	entry({"admin", "system", "admin"},  alias("admin", "system", "admin", "general"), _("Administration"), 3)
		entry({"admin", "system", "admin", "general"}, cbi("admin_system/admin"), _("General"), 1).leaf = true
		entry({"admin", "system", "admin", "troubleshoot"}, cbi("admin_system/admin_troubleshoot"), _("Troubleshoot"), 2).leaf = true
		entry({"admin", "system", "admin", "backup"}, call("action_backup"), _("Backup"), 3).leaf = true
			entry({"admin", "system", "admin", "auto"}, call("download_conf"), nil, nil)
			entry({"admin", "system", "admin", "check_status"}, call("check_status"), nil, nil)
			entry({"admin", "system", "admin", "download_backup"}, call("download_from_server"), nil, nil)
			--entry({"admin", "system", "admin", "upgrade"}, call("apply_config"), nil, nil)
		entry({"admin", "system", "admin", "access_control"}, alias("admin", "system", "admin", "access_control", "general"), _("Access Control"), 4)
			entry({"admin", "system", "admin", "access_control", "general"}, cbi("admin_system/admin_access_control"), _("General"), 1).leaf = true
			entry({"admin", "system", "admin", "access_control", "safety"}, cbi("admin_system/safety"), _("Safety"), 2).leaf = true
		entry({"admin", "system", "admin", "diagnostics"}, template("admin_system/diagnostics"), _("Diagnostics"), 5).leaf = true
		entry({"admin", "system", "admin", "clonemac"}, template("admin_system/clonemac"), _("MAC Clone"), 6).leaf = true
		entry({"admin", "system", "admin", "overview"}, cbi("admin_system/overview_setup"), _("Overview"), 7).leaf = true
		entry({"admin", "system", "admin", "monitoring"}, cbi("admin_system/admin_access_control_remote"), _("Monitoring"), 8).leaf = true
		local wimax_file
		local f=io.open("/tmp/run/wimax","r")
		if f~=nil then
			io.close(f)
			wimax_file = true
		else
			wimax_file = false
		end
		if(wimax_file) then
		entry({"admin", "system", "admin", "wimax"}, cbi("admin_system/wimax"), _("WiMAX"), 9).leaf = true
		end

	entry({"admin", "system", "admin", "xhr_the_data"}, call("get_page_status"), nil, nil)
	entry({"admin", "system", "admin", "xhr_gps_time"}, call("get_gps_time"), nil, nil)

	entry({"admin", "system", "trdownload"}, call("trdownload"))
	entry({"admin", "system", "trdownload1"}, call("trdownload", "topology"))
	entry({"admin", "system", "tcpdumppcap"}, call("tcpdumppcap"))

	entry({"admin", "system", "reboot"}, call("action_reboot"), _("Reboot"), 9)

	entry({"admin", "system", "diag_ping"}, call("diag_ping"), nil).leaf = true
	entry({"admin", "system", "diag_nslookup"}, call("diag_nslookup"), nil).leaf = true
	entry({"admin", "system", "diag_traceroute"}, call("diag_traceroute"), nil).leaf = true
end

function download_conf()
	luci.sys.exec("sysupgrade --create-backup /tmp/backup.tar")
	luci.template.render("admin_system/download_backup", {})
end

function download_from_server()
--	luci.sys.call("rm -f /tmp/config.tar.gz")
	luci.sys.call("/usr/sbin/auto_update_conf.sh download")
end
--[[
function apply_config()
--	local teltonika_lib = require("teltonika_lua_functions")
--	local exists = teltonika_lib.fileExists("/tmp/","config.tar.gz") or 0
	luci.sys.exec("tar -xzf /tmp/config.tar.gz -C /");

	luci.template.render("admin_system/applyreboot")
	t = {requests = "insert", table = "EVENTS", type="Web UI", text="Configuration was restored from backup!"}
	eventlog:insert(t)
	luci.sys.reboot()
end--]]

function check_status()
	local conf = tonumber(luci.sys.exec("uci get auto_update.auto_update.config_size") or 0)
	local number = tonumber(luci.sys.exec("ls -al /tmp/config.tar.gz | awk -F ' ' '{print $5}'") or 0)
	local size = "0 %"
	if conf~= nil and number~=nil then
		if tonumber(conf) > 0 and tonumber(number) > 0 then
			number = tonumber(number)*100/tonumber(conf)
			if tonumber(number)==100 then
				size = "done"
			else
				number=string.format("%.0f",number)
				size = number.." %"
			end
		end
	end

	local rv = {
			uptime = size
		}
	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
	return
end

function get_page_status()

	require "luci.fs"
	require "luci.tools.status"
	luci.util = require "luci.util"

	local function cecho(string)
		luci.sys.call("echo \"" .. string .. "\" >> /tmp/log.log")
	end

	function get_error(err_tag, log_file)
		err_found = false
		local m_connection_state
		if log_file == "1" then
			m_connection_state = luci.sys.exec("cat /tmp/mon_openvpn_log | grep -v grep | grep \"" .. err_tag .. "\"")
		else
			m_connection_state = luci.sys.exec("cat /tmp/mon_openvpn_log2 | grep -v grep | grep \"" .. err_tag .. "\"")
		end
		local f = m_connection_state:split("\n")
		if f[1] ~= "" then
			err_found = true
		end
		return err_found
	end

	if luci.http.formvalue("status") == "1" then
		local status, connection_state, router_ip, dev_b, remote, port, default_remote, port_remote, tik, serial_nbr, lan_mac
		status = luci.util.trim(luci.sys.exec("uci -q get openvpn.teltonika_auth_service.enable"))
		dev_b = luci.util.trim(luci.sys.exec("uci -q get openvpn.teltonika_auth_service.dev"))
		remote = luci.util.trim(luci.sys.exec("uci -q get openvpn.teltonika_auth_service.remote"))
		port = luci.util.trim(luci.sys.exec("uci -q get openvpn.teltonika_auth_service.port"))
		default_remote = luci.util.trim(luci.sys.exec("uci -c /rom/etc/config -q get openvpn.teltonika_auth_service.remote"))
		default_port = luci.util.trim(luci.sys.exec("uci -c /rom/etc/config -q get openvpn.teltonika_auth_service.port"))
		router_ip = "N/A"
		serial_nbr = luci.util.trim(luci.sys.exec("uci -q get hwinfo.hwinfo.serial"))
		lan_mac = luci.util.trim(luci.sys.exec("ifconfig | grep 'br-lan' | awk -F ' ' '{print $5}'"))
		if status == "1" then
					if get_error("Network is unreachable", "1") then
						connection_state = "Server is unreachable"
					else
						local dev = dev_b.."[0-9]\{1,\}"
						if remote == default_remote and port == default_port then
							luci.sys.exec("rm /tmp/mon_openvpn_log2")
							connection_state = "Connecting to server"
							tik = true
							if get_error("AUTH_FAILED", "1") then
								connection_state = "Device is not registered in monitoring system"
								tik = false
							end
							if get_error("device " .. dev .. " opened", "1") then
								connection_state = "Primary connection to server made"
								tik = false
							end
							if tik then
								local ptp_ip = luci.sys.exec("cat /tmp/mon_openvpn_log | grep -o '" .. dev .. "[0-9]\{1,\} [0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\} pointopoint [0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | awk '{print $4}'")
								local ptp_err = luci.sys.exec("/usr/bin/eventslog -p -t events | grep '".. ptp_ip .."' | tail -1")
								if ptp_err ~= "" and ptp_err:find("Bad password") then
									connection_state = "Wrong device password in monitoring system"
								end
							end
						else
							if remote == default_remote then
								connection_state = "Connecting to profile tunnel"
								local m_connection_state = luci.sys.exec("cat /tmp/monitoring_log")
								local f = m_connection_state:split("\n")
								router_ip = luci.util.trim(luci.sys.exec("ifconfig "..dev_b.."0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'"))
								if f[1] ~= "" then
										connection_state = f[1]
								end
								if get_error("device " .. dev .. " opened", "1") then
									connection_state = "Connected to profile tunnel"
									local m_connection_state = luci.sys.exec("cat /tmp/monitoring_log")
									local f = m_connection_state:split("\n")
									if f[1] ~= "" then
										connection_state = f[1]
									end
								end
								if get_error("Closing TUN/TAP interface", "2") then
									connection_state = "Connection closed"
									luci.sys.exec("rm /tmp/monitoring_log")
								end
							end
						end
					end
		end
		local rv = {
			status = status,
			connection_state = connection_state,
			router_ip = router_ip,
			serial_nbr = serial_nbr,
			lan_mac = lan_mac
		}
		luci.http.prepare_content("application/json")
		luci.http.write_json(rv)

		return
	end

	local system, model = luci.sys.sysinfo()

end

function get_gps_time()
	local utl = require "luci.util"
	local sys = require "luci.sys"
	local gps_time = utl.trim(luci.sys.exec("gpsctl -e"))
	local gps_time_seconds = utl.trim(luci.sys.exec("gpsctl -f"))
	local status = "Update failed"
	
	if gps_time ~= "" and gps_time ~= "0" then
		luci.sys.exec("date -u -s '" .. gps_time .. "'")
		status = "Success!"
	end
	
	local rv = {
			status = status
		}
		
	-- prevent session timeoutby updating mtime	
	local set = tonumber(gps_time_seconds)
	nixio.fs.utimes(luci.sauth.sessionpath .. "/" .. luci.dispatcher.context.authsession, set, set)	
		
	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end

function diag_ping()
	diag_command("ping -c 5 -W 1 %q 2>&1")
end

function diag_traceroute()
	diag_command("traceroute -q 1 -w 1 -n %q 2>&1")
end

function diag_nslookup()
	diag_command("nslookup %q 2>&1 localhost > /tmp/nslook; lncnt=`cat /tmp/nslook | wc -l`; cat /tmp/nslook | tail -n `expr $lncnt - 2`")
end

function diag_command(cmd)
	local path = luci.dispatcher.context.requestpath
	local addr = path[#path]

	if addr and addr:match("^[a-zA-Z0-9%-%.:_]+$") then
		luci.http.prepare_content("text/plain")

		local util = io.popen(cmd % addr)
		if util then
			while true do
				local ln = util:read("*l")
				if not ln then break end
				luci.http.write(ln)
				luci.http.write("\n")
			end

			util:close()
		end

		return
	end

	luci.http.status(500, "Bad address")
end

function action_clock_status()
	local set = tonumber(luci.http.formvalue("set"))
	if set ~= nil and set > 0 then
		local date = os.date("*t", set)
		if date then
			-- prevent session timeoutby updating mtime
			nixio.fs.utimes(luci.sauth.sessionpath .. "/" .. luci.dispatcher.context.authsession, set, set)

			luci.sys.call("date -s '%04d-%02d-%02d %02d:%02d:%02d'" %{
				date.year, date.month, date.day, date.hour, date.min, date.sec
			})
		end
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json({ timestring = os.date("%Y-%m-%d %H:%M:%S") })
end


function tcpdumppcap()
	local mount = luci.util.trim(luci.sys.exec("uci -q get system.system.tcpdump_last_save"))
	local restore_cmd = "tar -xzC/ >/dev/null 2>&1"
	local tcpdump_cmd  = "/etc/init.d/tcpdebug stop &>/dev/null; tar -zcf - "..mount.."/tcpdebug.pcap; /etc/init.d/tcpdebug start &>/dev/null;"
	local fp
	luci.http.setfilehandler(
		function(meta, chunk, eof)
			if not fp then
				fp = io.popen(restore_cmd, "w")
			end
			if chunk then
				fp:write(chunk)
			end
			if eof then
				fp:close()
			end
		end
	)
	local reader = ltn12_popen(tcpdump_cmd)
		luci.http.header('Content-Disposition', 'attachment; filename="tcpdebug-%s-%s.tar.gz"' % {
			luci.sys.hostname(), os.date("%Y-%m-%d")})
		luci.http.prepare_content("application/x-tar")
		luci.ltn12.pump.all(reader, luci.http.write)
		t = {requests = "insert", table = "EVENTS", type="Web UI", text="TCP dump .pcap file was downloaded!"}
		eventlog:insert(t)
	
end

function trdownload(val)
	local include_topology = ""
	local restore_cmd = "tar -xzC/ >/dev/null 2>&1"
	if val == "topology" then
		include_topology = "topology"
	end
	local trouble_backup_cmd  = "troubleshoot.sh " .. include_topology .. "; cat /tmp/troubleshoot.tar.gz  - 2>/dev/null"
	local image_tmp   = "/tmp/firmware.img"
	local fp
	luci.http.setfilehandler(
		function(meta, chunk, eof)
			if not fp then
				if meta and meta.name == "image" then
					fp = io.open(image_tmp, "w")
				else
					fp = io.popen(restore_cmd, "w")
				end
			end
			if chunk then
				fp:write(chunk)
			end
			if eof then
				fp:close()
			end
		end
	)
	-- Assemble file list, generate troubleshoot_backup
	--
	local reader = ltn12_popen(trouble_backup_cmd)
		luci.http.header('Content-Disposition', 'attachment; filename="trouble_backup-%s-%s.tar.gz"' % {
			luci.sys.hostname(), os.date("%Y-%m-%d")})
		luci.http.prepare_content("application/x-tar")
		luci.ltn12.pump.all(reader, luci.http.write)
		t = {requests = "insert", table = "EVENTS", type="Web UI", text="Trobleshoot was downloaded!"}
		eventlog:insert(t)
end

function action_backup()
	local sys = require "luci.sys"
	local fs  = require "luci.fs"

	local restore_cmd = "tar -xzC/ >/dev/null 2>&1"
	local backup_cmd  = "sysupgrade --create-backup - 2>/dev/null"
	local fp
	luci.http.setfilehandler(
		function(meta, chunk, eof)
			if not fp then
				fp = io.popen(restore_cmd, "w")
			end
			if chunk then
				fp:write(chunk)
			end
			if eof then
				fp:close()
			end
		end
	)

	if luci.http.formvalue("backup") then
		--
		-- Assemble file list, generate backup
		--
		local reader = ltn12_popen(backup_cmd)
		luci.http.header('Content-Disposition', 'attachment; filename="backup-%s-%s.tar.gz"' % {
			luci.sys.hostname(), os.date("%Y-%m-%d")})
		luci.http.prepare_content("application/x-targz")
		luci.ltn12.pump.all(reader, luci.http.write)
		t = {requests = "insert", table = "EVENTS", type="Web UI", text="Backup was downloaded!"}
		eventlog:insert(t)

	elseif luci.http.formvalue("restore") then
		--
		-- Unpack received .tar.gz
		--

		local upload = luci.http.formvalue("archive")
		if upload and #upload > 0 then
			luci.sys.call("/sbin/crt_openvpn.sh r >/dev/null 2>/dev/null")
			luci.template.render("admin_system/applyreboot")
			t = {requests = "insert", table = "EVENTS", type="Web UI", text="Configuration was restored from backup!"}
			eventlog:insert(t)
			luci.sys.reboot()
		end

	else
		--
		-- Overview
		--
		luci.template.render("admin_system/backup", {
		})
	end
end

function action_passwd()
	local p1 = luci.http.formvalue("pwd1")
	local p2 = luci.http.formvalue("pwd2")
	local stat = nil

	if p1 or p2 then
		if p1 == p2 then
			stat = luci.sys.user.setpasswd("root", p1)
		else
			stat = 10
		end
	end

	luci.template.render("admin_system/passwd", {stat=stat})
end

function action_reboot()
	local reboot = luci.http.formvalue("reboot")

	if reboot then
		luci.template.render("admin_system/rebootreload", {reboot=reboot})
		luci.sys.reboot()
	else
		luci.template.render("admin_system/reboot", {reboot=reboot})
	end
end

function fork_exec(command)
	local pid = nixio.fork()
	if pid > 0 then
		return
	elseif pid == 0 then
		-- change to root dir
		nixio.chdir("/")

		-- patch stdin, out, err to /dev/null
		local null = nixio.open("/dev/null", "w+")
		if null then
			nixio.dup(null, nixio.stderr)
			nixio.dup(null, nixio.stdout)
			nixio.dup(null, nixio.stdin)
			if null:fileno() > 2 then
				null:close()
			end
		end

		-- replace with target command
		nixio.exec("/bin/sh", "-c", command)
	end
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
