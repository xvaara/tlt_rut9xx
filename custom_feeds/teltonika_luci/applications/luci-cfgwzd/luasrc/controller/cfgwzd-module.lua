module("luci.controller.cfgwzd-module", package.seeall)
require("uci")
local sys = require "luci.sys"
local utl = require "luci.util"


function index()
	local translate, translatef = luci.i18n.translate, luci.i18n.translatef
	local order	-- Used to indicate the step number
	order = 1

	entry({"admin", "system", "wizard"}, firstchild(), "Setup Wizard" , 1).dependent=false

	entry({"admin", "system", "wizard", "step-pwd"}, cbi("cfgwzd-module/step_pwd"), translatef("Step %d - General", order), 10)
	order = order + 1

	if luci.tools.status.show_mobile() then
		entry({"admin", "system", "wizard", "step-mobile"}, cbi("cfgwzd-module/step_3g"), translatef("Step %d - Mobile ", order), 20)
		order = order + 1
	end
	
	entry({"admin", "system", "wizard", "step-lan"}, cbi("cfgwzd-module/step_lan"),translatef("Step %d - LAN", order),  30)
	order = order + 1

	entry({"admin", "system", "wizard", "step-wifi"}, cbi("cfgwzd-module/step_wifi"), translatef("Step %d - WiFi", order), 40)
	entry({"admin", "system", "wizard", "change_lan"}, call("change_lan")).leaf = true
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

function isIpAddress(ip)
	 if not ip then return false end
	 local a,b,c,d=ip:match("^(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)$")
	 a=tonumber(a)
	 b=tonumber(b)
	 c=tonumber(c)
	 d=tonumber(d)
	 if not a or not b or not c or not d then return false end
	 if a<0 or 255<a then return false end
	 if b<0 or 255<b then return false end
	 if c<0 or 255<c then return false end
	 if d<0 or 255<d then return false end
	 return true
end

function change_lan()
		local ipaddr=luci.http.formvalue("ipaddr")
		local netmask=luci.http.formvalue("netmask")
		local igs=luci.http.formvalue("igs")
		local limit=luci.http.formvalue("limit")
		local start=luci.http.formvalue("start")
		local leasetime=luci.http.formvalue("leasetime")
		old_ip=utl.trim(sys.exec("uci get -q network.lan.ipaddr"))
		client_ip=luci.http.getenv("REMOTE_ADDR")
		client_ip1, client_ip2 = client_ip:match("([^.]+).([^.]+)")
		old_ip1, old_ip2 = old_ip:match("([^.]+).([^.]+)")
		local redirect=0
		local url=luci.http.formvalue("sesion")
		if old_ip1~=client_ip1 or old_ip2~=client_ip2 then
			new_url=url:sub( 1, -5)
			new_url=new_url.."wifi/"
			redirect=1
		end
		local new_ip=0
		if old_ip ~= ipaddr then
			if isIpAddress(ipaddr) then
				sys.call("uci set network.lan.ipaddr="..ipaddr)
				new_ip=1
			else
				ipaddr=old_ip
			end
		end
		if isIpAddress(netmask) then
			sys.call("uci set network.lan.netmask="..netmask)
		end
		if igs == "true" then
			sys.call("uci delete -q dhcp.lan.ignore")
		elseif igs == "false" then
			sys.call("uci set dhcp.lan.ignore=1")
		end
		sys.call("uci set dhcp.lan.limit="..tonumber(limit))
		sys.call("uci set dhcp.lan.start="..tonumber(start))
		sys.call("uci set dhcp.lan.leasetime="..leasetime)
		sys.call("uci commit")
		sys.call("luci-reload &")
		--sys.call("/etc/init.d/dnsmasq reload &")
		img_link = "http://"..ipaddr.."/luci-static/resources/icons/loading.gif?"
		local new_link
		if redirect==1 then
			new_link=new_url
		else
			local addr=url:sub( 1, 7)
			new_link=addr..""..ipaddr..""..luci.dispatcher.build_url("admin", "system", "wizard", "step-wifi")
		end
		local rv={
				new_link=new_link,
				ip=ipaddr,
				new_ip=new_ip,
				img_link=img_link
			}
		luci.http.prepare_content("application/json")
		luci.http.write_json(rv)
		return
end
