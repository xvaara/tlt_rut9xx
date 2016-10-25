module("luci.controller.tlt-snmp", package.seeall)

function index()
	entry({"admin", "services", "snmp"}, alias("admin", "services", "snmp", "snmp-settings"), _("SNMP"), 85)
	entry({"admin", "services", "snmp", "snmp-settings" }, cbi("tlt-snmp/tlt-snmp"), _("SNMP Settings"), 1).leaf = true
	entry({"admin", "services", "snmp", "trap-settings"},arcombine(cbi("tlt-snmp/tlt-trap"), cbi("tlt-snmp/tlt-trap-details")),_("Trap Settings"), 2).leaf = true
end
