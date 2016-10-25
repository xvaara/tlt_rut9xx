require("luci.fs")
require("luci.config")
require "teltonika_lua_functions"

local utl = require "luci.util"
local nw = require "luci.model.network"
local sys = require "luci.sys"


m = Map("openvpn", translate("Remote Monitoring "), translate(""))
--m:chain("snmpd")

s = m:section(NamedSection, "teltonika_auth_service", "openvpn", translate("Remote Access Control"))
open_e = s:option(Flag, "enable", translate("Enable remote monitoring"), translate("Enable remote monitoring, if device is not registered in RMS system within 10 minutes, remote monitoring will be switched off automatically"))
open_e.rmempty = false

s = m:section(NamedSection, "", "", translate(""));
s.template = "admin_system/netinfo_monitoring"

function m.on_commit(map)
	local enabled = m:formvalue("cbid.openvpn.teltonika_auth_service.enable") or ""

	if enabled == "1" then 
		local cron_conf = io.open("/tmp/spool/cron/crontabs/root", "a")
		cron_conf:write("* * * * * /sbin/rms_connection_limmiter.sh\n")
		cron_conf:close()
		os.execute('/etc/init.d/cron restart')
	else
		os.execute('sed -i /rms_connection_limmiter/d /tmp/spool/cron/crontabs/root')
		os.execute('rm -f /tmp/rms_fail_counter.dat')
		os.execute('/etc/init.d/cron restart')
	end

end

--[[function open_e.write(self, section, value)
	if value then
		m.uci:set("openvpn", "teltonika_auth_service", "enable", value)
		m.uci:commit("openvpn")
	end
end

function m.on_after_commit(self)
	luci.sys.call("/etc/init.d/openvpn restart")
end
--]]
return m
