-- ------ extra functions ------ --

function rule_check() -- determine if rule needs a protocol specified
	local sport = ut.trim(sys.exec("uci get -p /var/state load_balancing." .. arg[1] .. ".src_port"))
	local dport = ut.trim(sys.exec("uci get -p /var/state load_balancing." .. arg[1] .. ".dest_port"))
	if sport ~= "" or dport ~= "" then -- ports configured
		local proto = ut.trim(sys.exec("uci get -p /var/state load_balancing." .. arg[1] .. ".proto"))
		if proto == "" or proto == "all" then -- no or improper protocol
			err_proto = 1
		end
	end
end

function rule_warn() -- display warning message at the top of the page
	if err_proto == 1 then
		return "<font color=\"ff0000\"><strong>WARNING: this rule is incorrectly configured with no or improper protocol specified! Please configure a specific protocol!</strong></font>"
	else
		return ""
	end
end

function cbi_add_policy(field)
	uci.cursor():foreach("load_balancing", "policy",
		function (section)
			field:value(section[".name"])
		end
	)
end

function cbi_add_protocol(field)
	local protos = ut.trim(sys.exec("cat /etc/protocols | grep '	# ' | awk -F' ' '{print $1}' | grep -vw -e 'ip' -e 'tcp' -e 'udp' -e 'icmp' -e 'esp' | grep -v 'ipv6' | sort | tr '\n' ' '"))
	for p in string.gmatch(protos, "%S+") do
		field:value(p)
	end
end

-- ------ rule configuration ------ --

dsp = require "luci.dispatcher"
sys = require "luci.sys"
ut = require "luci.util"
arg[1] = arg[1] or ""

err_proto = 0
rule_check()


m5 = Map("load_balancing", translate("Load Balancing Rule Configuration - ") .. arg[1],
	translate(rule_warn()))
	m5.redirect = dsp.build_url("admin", "network", "balancing", "configuration")


mwan_rule = m5:section(NamedSection, arg[1], "rule", "")
	mwan_rule.addremove = false
	mwan_rule.dynamic = false


src_ip = mwan_rule:option(Value, "src_ip", translate("Source address"),
	translate("Supports CIDR notation (eg \"192.168.100.0/24\") without quotes"))
	src_ip.datatype = ipaddr

src_port = mwan_rule:option(Value, "src_port", translate("Source port"),
	translate("May be entered as a single or multiple port(s) (eg \"22\" or \"80,443\") or as a portrange (eg \"1024:2048\") without quotes"))

dest_ip = mwan_rule:option(Value, "dest_ip", translate("Destination address"),
	translate("Supports CIDR notation (eg \"192.168.100.0/24\") without quotes"))
	dest_ip.datatype = ipaddr
	dest_ip.default = "0.0.0.0/0"

dest_port = mwan_rule:option(Value, "dest_port", translate("Destination port"),
	translate("May be entered as a single or multiple port(s) (eg \"22\" or \"80,443\") or as a portrange (eg \"1024:2048\") without quotes"))

proto = mwan_rule:option(Value, "proto", translate("Protocol"),
	translate("View the contents of /etc/protocols for protocol descriptions"))
	proto.default = "all"
	proto.rmempty = false
	proto:value("all")
	proto:value("ip")
	proto:value("tcp")
	proto:value("udp")
	proto:value("icmp")
	proto:value("esp")
	cbi_add_protocol(proto)

use_policy = mwan_rule:option(ListValue, "use_policy", translate("Policy assigned"))
	cbi_add_policy(use_policy)

return m5
