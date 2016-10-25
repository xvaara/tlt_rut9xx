module("luci.controller.rs", package.seeall)

function index()
	local sys = require "luci.sys"
	local utl = require "luci.util"
	local rs232 = utl.trim(luci.sys.exec("uci get hwinfo.hwinfo.rs232"))
	local rs485 = utl.trim(luci.sys.exec("uci get hwinfo.hwinfo.rs485"))
	if rs232 == "1" then
		entry({"admin", "services", "rs"},  alias("admin", "services", "rs", "rs232"), _("RS232/RS485"), 52)
		entry({"admin", "services", "rs", "rs232"}, cbi("rs/rs232"), _("RS232"), 1)
	end
	if rs485 == "1" then
		if rs232 == "0" then
			entry({"admin", "services", "rs"},  alias("admin", "services", "rs", "rs485"), _("RS232/RS485"), 52)
		end
		entry({"admin", "services", "rs", "rs485"}, cbi("rs/rs485"), _("RS485"), 2)
	end
end
