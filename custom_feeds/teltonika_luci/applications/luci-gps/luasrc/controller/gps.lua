module("luci.controller.gps", package.seeall)
local utl = require "luci.util"

function index()
	local utl = require "luci.util"
	local sys = require "luci.sys"
	local show = require("luci.tools.status").show_mobile()
	local gps = utl.trim(luci.sys.exec("uci get hwinfo.hwinfo.gps"))
	if gps == "1" and show then
		entry({"admin", "services", "gps"}, call("go_to"), _("GPS"), 86)
		entry({"admin", "services", "gps", "general"}, template("gps/gps"), _("GPS"), 1).leaf = true
		entry({"admin", "services", "gps", "settings"}, cbi("gps/gps_settings"), _("GPS Settings"), 2).leaf = true
		entry({"admin", "services", "gps", "mode"}, arcombine(cbi("gps/gps_mode"), cbi("gps/gps_mode-details")), _("GPS Mode"), 3).leaf = true
		entry({"admin", "services", "gps", "input"}, arcombine(cbi("gps/gps_input"), cbi("gps/gps_input-details")), _("GPS I/O"), 4).leaf = true
		entry({"admin", "services", "gps", "geofencing"}, cbi("gps/gps_geofencing"), _("GPS Geofencing"), 5).leaf = true
		entry({"admin", "services", "gps", "getcord"}, call("get_cord"), nil)
	end

end

function go_to()
	local enabled = utl.trim(luci.sys.exec("uci -q get gps.gps.enabled")) or "0"
	if enabled == "1" then
		luci.http.redirect(luci.dispatcher.build_url("admin", "services", "gps", "general").."/")
	else
		luci.http.redirect(luci.dispatcher.build_url("admin", "services", "gps", "settings"))
	end
end

function get_cord()
	local cord = luci.sys.exec("gpsctl -xi");
	local myTable = cord:split("\n")
	local clong = "0.000000"
	local clat = "0.000000"

	if myTable[1] and #myTable[1] > 5 then
		clong = myTable[1]
	end
	if myTable[2] and #myTable[2] > 5  then
		clat = myTable[2]
	end
	local rv = {
		long = clong,
		lat = clat
	}
	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)

	return
end
