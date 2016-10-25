--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2011 Jo-Philipp Wich <xm@subsignal.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: network.lua 8259 2012-02-15 22:49:56Z jow $
]]--

module("luci.controller.admin.network", package.seeall)
local sys = require "luci.sys"
local uci = require("luci.model.uci").cursor()
local util = require "luci.util"

function index()
	local uci = require("luci.model.uci").cursor()
	local show = require("luci.tools.status").show_mobile()
	local page
 	local translate, translatef = luci.i18n.translate, luci.i18n.translatef

	page = node("admin", "network")
	page.target = firstchild()
	page.title  = _("Network")
	page.order  = 30
	page.index  = true

		local has_wifi = false

		uci:foreach("wireless", "wifi-device",
			function(s)
				has_wifi = true
				return false
			end)

		if has_wifi then
			local staConfigPresent = false

			page = entry({"admin", "network", "wireless_join"}, call("wifi_join"), nil)
			page.leaf = true
			page = entry({"admin", "network", "wireless_add"}, call("wifi_add"), nil)
			page.leaf = true
			page = entry({"admin", "network", "wireless_delete"}, call("wifi_delete"), nil)
			page.leaf = true
			page = entry({"admin", "network", "wireless_status"}, call("wifi_status"), nil)
			page.leaf = true
			page = entry({"admin", "network", "wireless_reconnect"}, call("wifi_reconnect"), nil)
			page.leaf = true
			page = entry({"admin", "network", "wireless_shutdown"}, call("wifi_reconnect"), nil)
			page.leaf = true
 			page = entry({"admin", "network", "wireless_scan"}, template("admin_network/wifi_join"), nil)
			page = entry({"admin", "network", "wireless"}, arcombine(template("admin_network/wifi_overview"), cbi("admin_network/wifi")), _("Wireless"), 15)
			page.leaf = true
			page.subindex = true

			uci:foreach("wireless", "wifi-iface", function(s)
				if s.mode == "sta" then
					staConfigPresent = true
				end
			end)
		end

		page = entry({"admin", "network", "iface_disabled"}, call("iface_disabled"), nil)
		page.leaf = true

		local dual_sim = uci:get("hwinfo", "hwinfo", "dual_sim")
		if show then
			entry({"admin", "network", "mobile"}, alias("admin", "network", "mobile","general"), _("Mobile"), 10)
		end
		entry({"admin", "network", "mobile","general"}, cbi("admin_network/ifaces_mobile"), _("General"), 1).leaf = true
		if dual_sim == "1" then
			entry({"admin", "network", "mobile","sim_switch"}, cbi("admin_network/sim_switch"), _("SIM Management"), 2).leaf = true
		end
		entry({"admin", "network", "mobile","operators"}, alias("admin", "network", "mobile", "operators", "scan") , _("Network Operators"), 3)
		entry({"admin", "network", "mobile","operators", "scan"}, template("admin_network/operators_list"), _("Network Operators"), 1).leaf = true
		entry({"admin", "network", "mobile","operators", "list"}, cbi("admin_network/operators_list"), _("Operators List"), 2).leaf = true
		entry({"admin", "network", "mobile","limit"}, cbi("admin_network/data_limit"), _("Mobile Data Limit"), 4).leaf = true

		entry({"admin", "network", "mobile", "sim_idle_protection"}, alias("admin", "network", "mobile", "sim_idle_protection", "settings"), _("SIM Idle Protection"), 5)
			entry({"admin", "network", "mobile", "sim_idle_protection", "settings"}, cbi("admin_network/sim_idle_protection"), _("Settings"), 1).leaf = true
			entry({"admin", "network", "mobile", "sim_idle_protection", "test"}, template("admin_network/sim_idle_protection_test"), _("Test"), 2).leaf = true

		page = entry({"admin", "network", "wan"}, cbi("admin_network/ifacesWan"), _("WAN"), 11)
			entry({"admin", "network", "wan", "edit"}, cbi("admin_network/wanEdit")).leaf = true
		page = entry({"admin", "network", "lan"}, cbi("admin_network/ifacesLan"), _("LAN"), 12)

		page  = node("admin", "network", "routes")
		page.target = cbi("admin_network/routes")
		page.title  = _("Static Routes")
		page.order  = 55

		--===================================VLAN=====================================
		entry({"admin", "network", "vlan"}, alias("admin", "network", "vlan", "list"), _("VLAN"), 15)
			entry({"admin", "network", "vlan", "list"}, template("admin_network/vlan"), _("VLAN Networks"), 1).leaf = true
			entry({"admin", "network", "vlan", "lan"}, arcombine(cbi("admin_network/lan_list"), cbi("admin_network/ifacesLan")), _("LAN Networks"), 2).leaf = true

		entry({"admin", "network", "routes"}, alias("admin", "network", "routes", "static_routes"), _("Routing"), 61)
			entry({"admin", "network", "routes", "static_routes"}, cbi("admin_network/routes"), _("Static Routes"), 1).leaf = true

		entry({"admin", "network", "routes", "dynamic_routes"}, alias("admin", "network", "routes", "dynamic_routes", "general"), _("Dynamic Routes"), 2)
			entry({"admin","network","routes","dynamic_routes", "general"}, cbi("bird4/general"), _("General"), 1).leaf = true
			entry({"admin","network","routes","dynamic_routes", "gen_proto"}, cbi("bird4/gen_proto"), _("General Protocols"), 62).leaf = true
			entry({"admin","network","routes","dynamic_routes", "routes_details"}, cbi("bird4/routes_details"), nil).leaf = true
--			entry({"admin","network","routes","dynamic_routes","proto_bgp"}, cbi("bird4/bgp_proto"), _("BGP Protocol"), 37).dependent=false
			entry({"admin","network","routes","dynamic_routes","ospf_proto"}, cbi("bird4/ospf_proto"), _("OSPF Protocol"), 38).leaf = true
			entry({"admin","network","routes","dynamic_routes","basic"}, cbi("bird4/basic"), nil).leaf = true
			entry({"admin","network","routes","dynamic_routes","basic_interface"}, cbi("bird4/basic_interface"), nil).leaf = true
			entry({"admin","network","routes","dynamic_routes","basic_network"}, cbi("bird4/basic_network"), nil).leaf = true

end

function wifi_join()

	local function param(x)
		return luci.http.formvalue(x)
	end
	local function ptable(x)
		x = param(x)
		return x and (type(x) ~= "table" and { x } or x) or {}
	end
	local dev  = param("device")
	local ssid = param("join")
	local staConfigPresent = false
	local wan_wifi_enabled = false

	uci:foreach("network", "interface", function(sct)
		if sct.ifname and sct.ifname:match("wlan") then
			if not sct.enabled or (sct.enabled and sct.enabled == "1") then
				wan_wifi_enabled = true
			end
		end
	end)

	uci:foreach("wireless", "wifi-iface", function(s)
			if s.mode == "sta" then
				staConfigPresent = true
			end
		end)

	if dev and ssid then
		local cancel  = (param("cancel") or param("cbi.cancel")) and true or false
		if cancel then
			if wan_wifi_enabled and not staConfigPresent then
				luci.http.redirect(luci.dispatcher.build_url("admin/network/wireless_join") .. "?scan=start")
			else
				luci.http.redirect(luci.dispatcher.build_url("admin/network/wireless/survey") .. "?scan=start")
			end
		else
			local cbi = require "luci.cbi"
			local tpl = require "luci.template"
			local map = luci.cbi.load("admin_network/wifi_add")[1]
			if map:parse() ~= cbi.FORM_DONE then
				tpl.render("header")
				map:render()
				tpl.render("footer")
			end
		end
	else
			luci.template.render("admin_network/wifi_join")
	end
end

function ip_generate()
	local frame = "192.168.%d.254/24"
	local sub = 2
	local ips = {}
	local ip = "192.168.2.254/24"

	uci:foreach("coovachilli", "general",
		function(s)
			b1, b2, b3, b4 = string.match(s.net, "(%d+).(%d+).(%d+).(%d+)")
			table.insert(ips, b3)
			for n, net in ipairs(ips) do
				if sub ==  tonumber(net) then
					sub = sub + 1
				end
			end
		end)
	ip = string.format(frame, sub)
	return ip
end

function get_id()
	local id =  1
	local exists = false
	while true do
		uci:foreach("coovachilli", "general",
			function(s)
				if id == tonumber(string.match(s[".name"], "%d+")) then
					id = id + 1
					exists = true
				end
		end)
		if not exists then
			return id
		end
		exists = false
	end
end

function wifi_add()
	local uci = require "luci.model.uci".cursor()
	local dev = luci.http.formvalue("device")
	local ntm = require "luci.model.network".init()
	local id = get_id()
	local hotspotid = "hotspot" .. id

	dev = dev and ntm:get_wifidev(dev)
	if dev then
		wifi_ssid=util.trim(luci.sys.exec("cat /lib/wifi/mac80211.sh | grep 'ssid' | grep -v '#' | awk -F ' ' '{print $3}'"))
		local net = dev:add_wifinet({
			mode       = "ap",
			network    = "lan",
			ssid       = wifi_ssid,
			encryption = "none",
			hotspotid = hotspotid
		})
		ntm:save("wireless")
		uci:section("coovachilli", "general", hotspotid, {
			enabled = "0",
			mode = "norad",
			protocol = "http",
			net = ip_generate()
		})
		uci:section("coovachilli", "session", "unlimited" .. id, {
			name = 'unlimited',
			id = hotspotid,
			uamlogoutip = "1.1.1.1"
		})
		uci:save("coovachilli")
		uci:commit("coovachilli")
		luci.http.redirect(net:adminlink())
	end
end

function wifi_delete()
	local uci = require "luci.model.uci".cursor()
	local rv={}
	local network = luci.http.formvalue("status")
	if network then
		--luci.sys.exec("/etc/init.d/chilli stop &")
		hotspot_id = uci:get("wireless", network, "hotspotid")
		if hotspot_id then
			uci:delete("coovachilli", hotspot_id)
			uci:delete("overview","show",hotspot_id)
			uci:foreach("coovachilli", "users",
				function(c)
					if c.id == hotspot_id then
						uci:delete("coovachilli", c[".name"])
					end
			end)
			uci:foreach("coovachilli", "session",
				function(c)
					if c.id == hotspot_id then
						uci:delete("coovachilli", c[".name"])
					end
			end)
			uci:commit("coovachilli")
			uci:commit("overview")
		end
		--luci.sys.call("wifi down")
		luci.sys.call("uci delete wireless.%q; uci commit" % network)
		--luci.sys.exec("/sbin/wifi up")
		--luci.sys.exec("/etc/init.d/firewall restart")
		--luci.sys.exec("/etc/init.d/chilli start &")
		luci.sys.exec("luci-reload")

		rv={
			response=1
		}
	end
		luci.http.prepare_content("application/json")
		luci.http.write_json(rv)
	return
end

function iface_disabled()
	local rv={}
	local sid = luci.http.formvalue("status")
	if sid then
		--luci.sys.exec("/etc/init.d/chilli stop")
		local sta = util.trim(luci.sys.exec("uci get -q wireless."..sid..".mode")) == "sta" and true or false
		local user_enable=util.trim(luci.sys.exec("uci get -q wireless."..sid..".user_enable"))
		if user_enable ~= nil and user_enable ~= "1" then
			luci.sys.call("uci delete -q wireless."..sid..".disabled; uci commit")
			luci.sys.call("uci set -q wireless."..sid..".user_enable=1; uci commit")
		else
			luci.sys.call("uci set -q wireless."..sid..".disabled=1; uci commit")
			luci.sys.call("uci set -q wireless."..sid..".user_enable=0; uci commit")
			local hotspot_id = uci:get("wireless", sid ,"hotspotid")
			if hotspot_id then
				local hotspot_enb = uci:get("coovachilli", hotspot_id, "enabled")
				if hotspot_enb and hotspot_enb == "1"  then
					uci:set("coovachilli", hotspot_id, "enabled", "0")
				end
				uci:commit("coovachilli")
			end
		end
		response=luci.sys.exec("luci-reload")
		--luci.sys.call("(/bin/sleep 10; /etc/init.d/chilli start) &") --siunciam i backgrounda, kad sleep neletintu webui darbo
		--if sta then
		--	luci.sys.call("/etc/init.d/fix_sta_ap restart >/dev/null")
		--end
		rv={
			response=1
		}
	end
		luci.http.prepare_content("application/json")
		luci.http.write_json(rv)
	return
end

function wifi_status()
	local path = luci.dispatcher.context.requestpath
	local s    = require "luci.tools.status"
	local rv   = { }

	local dev
	for dev in path[#path]:gmatch("[%w%.%-]+") do
		rv[#rv+1] = s.wifi_network(dev)
	end

	if #rv > 0 then
		luci.http.prepare_content("application/json")
		luci.http.write_json(rv)
		return
	end

	luci.http.status(404, "No such device")
end

function wifi_reconnect()
	local path  = luci.dispatcher.context.requestpath
	local mode  = path[#path-1]
	local wnet  = path[#path]
	local netmd = require "luci.model.network".init()

	local net = netmd:get_wifinet(wnet)
	local dev = net:get_device()
	if dev and net then
		luci.sys.call("env -i /sbin/wifi down >/dev/null 2>/dev/null")

		dev:set("disabled", nil)
		net:set("disabled", (mode == "wireless_shutdown") and 1 or nil)
		netmd:commit("wireless")

		luci.sys.call("env -i /sbin/wifi up >/dev/null 2>/dev/null")
		luci.http.status(200, (mode == "wireless_shutdown") and "Shutdown" or "Reconnected")

		return
	end

	luci.http.status(404, "No such radio")
end
