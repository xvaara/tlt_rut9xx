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

module("luci.controller.admin.fw_upgrade", package.seeall)
eventlog = require'tlt_eventslog_lua'
function index()

	entry({"admin", "system", "flashops"}, alias("admin", "system", "flashops","upgrade"), _("Firmware"), 5)
	entry({"admin", "system", "flashops","upgrade"}, call("action_flashops"), _("Firmware"), 1).leaf = true
	entry({"admin", "system", "flashops","config"}, cbi("auto_update"), _("FOTA"), 2).leaf = true
		entry({"admin", "system", "flashops","auto"}, call("download_fw"), nil, nil)
	entry({"admin", "system", "flashops","check"}, call("check_for_update"), nil, nil)
	entry({"admin", "system", "flashops","download"}, call("start_download"), nil, nil)
	entry({"admin", "system", "flashops","check_status"}, call("check_status"), nil, nil)
end

function start_download()
	a=luci.http.formvalue("status") or ""
	luci.sys.call("rm -f /tmp/firmware.img")
	luci.sys.call("/usr/sbin/auto_update.sh get \""..a.."\" &")
end

function check_status()
	local fw = tonumber(luci.sys.exec("uci -q get auto_update.auto_update.file_size") or 0)
	local number = tonumber(luci.sys.exec("ls -al /tmp/firmware.img | awk -F ' ' '{print $5}'") or 0)
	local size = "0 %"
	if fw~= nil and number~=nil then
		if tonumber(fw) > 0 and tonumber(number) > 0 then
			number = tonumber(number)*100/tonumber(fw)
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



function check_for_update()
	local fw = luci.util.trim(luci.sys.exec("/usr/sbin/auto_update.sh forced_check"))
	if fw == "no_new_update" then
		fw = "No new firmware"
	else
		fw=fw:split("=")
		if (fw[1] == "new_fw_version") then
			fw=fw[2]
		else
			if (fw[2] == "Bad serial") then
				fw = "No new firmware"
			else
				fw="Error"
			end
		end
	end

	local rv = {
		new_fw = fw
	}
	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
	return
end

function download_fw()
	if luci.http.formvalue("step") then
		local step = tonumber(luci.http.formvalue("step") or 1)
		if step == 1 then
			luci.template.render("admin_system/download", {
				download = 1,
				keep		= (not not luci.http.formvalue("keep")),
				keep_network	= (not not luci.http.formvalue("keep_network")),
				keep_3g		= (not not luci.http.formvalue("keep_3g")),
				keep_lan	= (not not luci.http.formvalue("keep_lan")),
				keep_ddns	= (not not luci.http.formvalue("keep_ddns")),
				keep_wireless	= (not not luci.http.formvalue("keep_wireless")),
				keep_firewall	= (not not luci.http.formvalue("keep_firewall")),
				keep_openvpn	= (not not luci.http.formvalue("keep_openvpn"))
			})
		else
			local upgrade_avail = nixio.fs.access("/lib/upgrade/platform.sh")
			luci.template.render("admin_system/flashops", {
				download = 1,
				upgrade_avail = upgrade_avail
			})
		end
	else
		local upgrade_avail = nixio.fs.access("/lib/upgrade/platform.sh")
		luci.template.render("admin_system/flashops", {
			download = 1,
			upgrade_avail = upgrade_avail
		})
	end
end


function action_flashops()
	local sys = require "luci.sys"
	local fs  = require "luci.fs"

	local upgrade_avail = nixio.fs.access("/lib/upgrade/platform.sh")
	local reset_avail   = os.execute([[grep '"rootfs_data"' /proc/mtd >/dev/null 2>&1]]) == 0

	local restore_cmd = "tar -xzC/ >/dev/null 2>&1"
	local backup_cmd  = "sysupgrade --create-backup - 2>/dev/null"
	local trouble_backup_cmd  = "troubleshoot.sh; cat /tmp/troubleshoot.tar.gz  - 2>/dev/null"
	local image_tmp   = "/tmp/firmware.img"

	-- After finishing flashing/erasing procedure 'reboot -f' command will be
	-- applied. So Telit modem won't boot up properly. Here we will do force modem shutdown.
	local function shutdown_telit()
		x = uci.cursor()
		--pid = x:get("system", "module", "pid") or ""
		--vid = x:get("system", "module", "vid") or ""
		--if pid == "0021" and vid == "1BC7" then
			luci.sys.call("/etc/init.d/modem stop")
		--end
	end

	local function image_supported()
		-- XXX: yay...
		return ( 0 == os.execute(
			". /etc/functions.sh; " ..
			"include /lib/upgrade; " ..
			"platform_check_image %q >/dev/null"
				% image_tmp
		) )
	end

	local function image_checksum()
		return (luci.sys.exec("/sbin/chkimage %q" % image_tmp))
	end

	local function storage_size()
		local size = 0
		if nixio.fs.access("/proc/mtd") then
			for l in io.lines("/proc/mtd") do
				local d, s, e, n = l:match('^([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+"([^%s]+)"')
				if n == "linux" or n == "firmware" then
					size = tonumber(s, 16)
					break
				end
			end
		elseif nixio.fs.access("/proc/partitions") then
			for l in io.lines("/proc/partitions") do
				local x, y, b, n = l:match('^%s*(%d+)%s+(%d+)%s+([^%s]+)%s+([^%s]+)')
				if b and n and not n:match('[0-9]') then
					size = tonumber(b) * 1024
					break
				end
			end
		end
		return size
	end


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

	if luci.http.formvalue("backup") then
		--
		-- Assemble file list, generate backup
		--
		local reader = ltn12_popen(backup_cmd)
		luci.http.header('Content-Disposition', 'attachment; filename="backup-%s-%s.tar.gz"' % {
			luci.sys.hostname(), os.date("%Y-%m-%d")})
		luci.http.prepare_content("application/x-targz")
		luci.ltn12.pump.all(reader, luci.http.write)
	elseif luci.http.formvalue("trouble_backup") then
		--
		-- Assemble file list, generate troubleshoot_backup
		--
		local reader = ltn12_popen(trouble_backup_cmd)
		luci.http.header('Content-Disposition', 'attachment; filename="trouble_backup-%s-%s.tar.gz"' % {
			luci.sys.hostname(), os.date("%Y-%m-%d")})
		luci.http.prepare_content("application/x-tar")
		luci.ltn12.pump.all(reader, luci.http.write)

	elseif luci.http.formvalue("restore") then
		--
		-- Unpack received .tar.gz
		--
		local upload = luci.http.formvalue("archive")
		if upload and #upload > 0 then
			luci.template.render("admin_system/applyreboot")
			luci.sys.reboot()
		end
	elseif luci.http.formvalue("image") or luci.http.formvalue("step") then
		--
		-- Initiate firmware flash
		--
		local step = tonumber(luci.http.formvalue("step") or 1)
		if step == 1 then
			if image_supported() then
				local download = tonumber(luci.http.formvalue("download") or 0)
				luci.template.render("admin_system/upgrade", {
					checksum	= image_checksum(),
					storage		= storage_size(),
					download	= download,
					size		= nixio.fs.stat(image_tmp).size,
					keep		= (not not luci.http.formvalue("keep")),
					keep_network	= (not not luci.http.formvalue("keep_network")),
					keep_3g		= (not not luci.http.formvalue("keep_3g")),
					keep_lan	= (not not luci.http.formvalue("keep_lan")),
					keep_ddns	= (not not luci.http.formvalue("keep_ddns")),
					keep_wireless	= (not not luci.http.formvalue("keep_wireless")),
					keep_firewall	= (not not luci.http.formvalue("keep_firewall")),
					keep_openvpn	= (not not luci.http.formvalue("keep_openvpn"))
				})
			else
				nixio.fs.unlink(image_tmp)
				luci.template.render("admin_system/flashops", {
					reset_avail   = reset_avail,
					upgrade_avail = upgrade_avail,
					image_invalid = true
				})
			end
		--
		-- Start sysupgrade flash
		--
		elseif step == 2 then
			download		= luci.http.formvalue("download")
			keep		= luci.http.formvalue("keep")
			keep_network	= luci.http.formvalue("keep_network")
			keep_3g		= luci.http.formvalue("keep_3g")
			keep_lan	= luci.http.formvalue("keep_lan")
			keep_ddns	= luci.http.formvalue("keep_ddns")
			keep_wireless	= luci.http.formvalue("keep_wireless")
			keep_firewall	= luci.http.formvalue("keep_firewall")
			keep_openvpn	= luci.http.formvalue("keep_openvpn")
			
			local redirect = ""
			--If true redirect to configurated IP address
			if keep_network ~= "" or keep_lan ~= "" then
				redirect = "1"
			end
			
			if redirect == "" then
				local sProtocol = "http"
				local sIP = "192.168.1.1"
				local sPort = "80"

				local sFile, sBuf, sLine, sPortHttp, sPortHttps
				local fs = require "nixio.fs"

				sFile = "/rom/lib/functions/uci-defaults.sh"
				if fs.access(sFile) then
					for sLine in io.lines(sFile) do
						if sLine:find("set network.lan.ipaddr='") and sLine:find("#") ~= 1 then
							sBuf = sLine:match("(%d+.%d+.%d+.%d+)")
							if sBuf ~= nil then
								sIP = sBuf
								break
							end
						end
					end
				end

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

				sBufAddr = "\"" .. sProtocol .. "://" .. sIP .. ":" .. sPort .. "\""
			end
			luci.template.render("admin_system/applyflashing", {
				title = luci.i18n.translate("Upgrading..."),
				msg  = luci.i18n.translate("The system is upgrading now."),
				msg1  = luci.i18n.translate("<b>DO NOT POWER OFF THE DEVICE!</b>"),
				msg2  = luci.i18n.translate("It might be necessary to change your computer\'s network settings to reach the device again, depending on your configuration."),
				addr = sBufAddr,
				keep_s = keep,
				keep_n = keep_network,
				keep_3 = keep_3g,
				keep_l = keep_lan,
				keep_d = keep_ddns,
				keep_w = keep_wireless,
				keep_f = keep_firewall,
				keep_o = keep_openvpn,
				download = download
			})
		elseif step == 3 then
			local keep			= (luci.http.formvalue("keep_s") == "1") and "" or "-n"
			local keep_network	= (luci.http.formvalue("keep_n") == "1") and "network dhcp simcard teltonika uhttpd multiwan" or ""
			local keep_3g		= (luci.http.formvalue("keep_3") == "1") and "sim1 sim2 ppp" or ""
			local keep_lan		= (luci.http.formvalue("keep_l") == "1") and "lan" or ""
			local keep_ddns		= (luci.http.formvalue("keep_d") == "1") and "ddns" or ""
			local keep_wireless	= (luci.http.formvalue("keep_w") == "1") and "wireless" or ""
			local keep_firewall	= (luci.http.formvalue("keep_f") == "1") and "firewall" or ""
			local keep_openvpn	= (luci.http.formvalue("keep_o") == "1") and "openvpn" or ""
			local download		= luci.http.formvalue("download")
			check_pre_post=""
			if tonumber(download) == 1 then
				t = {requests = "insert", table = "EVENTS", type="FW", text="Upgrade from server"}
				eventlog:insert(t)
				check_pre_post="-k"
			elseif tonumber(download) == 0 then
				t = {requests = "insert", table = "EVENTS", type="FW", text="Upgrade from file"}
				eventlog:insert(t)
			end
			local dateold = luci.util.trim(luci.sys.exec("date +%s"))
			local datenew = dateold + 20 --per kiek laiko perraso fw tiek reikia pridet
			datenew = tostring(datenew)
			luci.sys.exec("date +%s -s @".. datenew)
			luci.sys.call("touch /etc/init.d/luci_fixtime")
				--workaround reboot irasymas cia ne sys upgrade, nes ten neissisaugo patachintas failas
				t = {requests = "insert", table = "EVENTS", type="Reboot", text="Request after FW upgrade"}
				eventlog:insert(t)
				local dateold = luci.util.trim(luci.sys.exec("date +%s"))
				local datenew = dateold + 105 --per kiek laiko perraso fw tiek reikia pridet
				datenew = tostring(datenew)
				luci.sys.exec("date +%s -s @".. datenew)
			luci.sys.call("touch /etc/init.d/luci_fixtime")
			luci.sys.call("uci set system.device_info.reboot=1")
			luci.sys.call("uci commit system")
			
			--useful for debugging folowing conditions
			--luci.sys.call("/usr/bin/eventslog insert \"Reboot\" \". %s . %s . %s . %s . %s . %s .\"" %{ luci.http.formvalue("keep_s"), keep, tostring((luci.http.formvalue("keep_s") == "1")) , keep_3g, keep_lan, keep_network })
			
			if keep == "" then
				--Keep all settings
				luci.sys.call("echo kazkas > /etc/uci-defaults/99_touch-firstboot")
				fork_exec("killall dropbear uhttpd; sleep 1; /sbin/sysupgrade %s %s %q" %{ keep, check_pre_post, image_tmp })
			else
				--Use keep settings with sysupgrade if at least some config files are kept
				if keep_network ~= "" or keep_ddns ~= "" or keep_wireless ~= "" or keep_firewall ~= "" or keep_openvpn ~= "" then
					keep = ""
				end
				if keep_network == "" then
					fork_exec("killall dropbear uhttpd; sleep 1; /sbin/keep_settings.sh store %s %s; /sbin/leave_config.sh %s %s %s %s %s; mkdir -p /etc/uci-defaults; echo kazkas > /etc/uci-defaults/99_touch-firstboot; /sbin/sysupgrade %s %s %q" %{ keep_3g, keep_lan, keep_network, keep_ddns, keep_wireless, keep_firewall, keep_openvpn, keep, check_pre_post, image_tmp})
				else
					--All network settings are kept so don't store 3g and lan settings in flash
					fork_exec("killall dropbear uhttpd; sleep 1; /sbin/leave_config.sh %s %s %s %s %s; mkdir -p /etc/uci-defaults; echo kazkas > /etc/uci-defaults/99_touch-firstboot; /sbin/sysupgrade %s %s %q" %{ keep_network, keep_ddns, keep_wireless, keep_firewall, keep_openvpn, keep, check_pre_post, image_tmp})
				end

			end
		end
	elseif reset_avail and luci.http.formvalue("reset") then
		--
		-- Reset system
		--
		luci.template.render("admin_system/applyreboot", {
			title = luci.i18n.translate("Erasing..."),
			msg   = luci.i18n.translate("The system is erasing the configuration partition now and will reboot itself when finished."),
			
		})
		--shutdown_telit()
		--fork_exec("killall dropbear uhttpd; sleep 1; mtd -r erase rootfs_data")
		fork_exec("killall dropbear; sleep 1; echo y | firstboot; reboot -o")

	else
		--
		-- Overview
		--
		luci.template.render("admin_system/flashops", {
			reset_avail   = reset_avail,
			upgrade_avail = upgrade_avail
		})
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
