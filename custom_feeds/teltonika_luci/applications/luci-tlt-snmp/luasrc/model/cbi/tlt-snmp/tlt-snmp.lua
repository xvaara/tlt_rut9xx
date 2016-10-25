local m, agent, sys,  o, port, remote, deathtrap = false, enable, com, comname

local uci  = require "luci.model.uci".cursor()
local fw = require "luci.model.firewall"
local fs = require "nixio.fs"
local x = uci.cursor()
local sys = require "luci.sys"
fw.init(uci)

local __define__rule_name = "SNMP_WAN_Access"
local _define_snmp_cfg = "snmpd"
------
-- DBG
------
local function cecho(string)
	luci.sys.call("echo \"" .. string .. "\" >> /tmp/log.log")
end

m = Map("snmpd", translate("SNMP Configuration"))
m:chain("firewall")

agent = m:section(TypedSection, "agent", translate("SNMP Service Settings"))
agent.addremove = false
agent.anonymous = true


-----------------
-- enable/disable
-----------------
o = agent:option(Flag, "enabled", translate("Enable SNMP service"), translate("Run SNMP (Simple Network Management Protocol) service on system\\'s startup"))
o.forcewrite = true
o.rmempty = false
-----------------------
-- enable remote access
-----------------------
remote = agent:option(Flag, "remoteAccess", translate("Enable remote access"), translate("Open port in firewall so that SNMP (Simple Network Management Protocol) service may be reached from WAN"))
remote.forcewrite = true
remote.rmempty = false

-------
-- port
-------
port = agent:option(Value, "portNumber", translate("Port"), translate("SNMP (Simple Network Management Protocol) service\\'s port"))
port.default = "161"
port.datatype = "port"

function port.validate(self, value, section)
	def = m.uci:get("snmpd", "teltonika_auth_service", "portNumber")
-- 	luci.sys.call("echo \"def [".. def .."]\" \"value [".. value .."]\"  >>/tmp/aaa")
	if def ~= value then
		return value
	else
-- 		m.message = translate("This port using for monitoring. Please choose another one!")
		return nil, translate("This port is used for monitoring. Please choose another one!")
-- 		return m.message
	end
end

--
-- community
--
com = agent:option(ListValue, "_community", translate("Community"), translate("The SNMP (Simple Network Management Protocol) Community is an ID that allows access to a router\\'s SNMP data"))
com:value("public", translate("Public"))
com:value("private", translate("Private"))
com:value("custom", translate("Custom"))
com.default = "public"

comname = agent:option(Value, "_community_name", translate("Community name"), translate("Set custom name to access SNMP"))
comname:depends("_community", "custom")
comname.default = "custom"

src = agent:option(Value, "_src", translate("IP or Network"), translate("192.168.1.1 or 192.168.1.0/24"))
src:depends("_community", "private")
src.default = "127.0.0.1"
src.datatype = "ip4addr"

-- sys = m:section(TypedSection, "system", translate("SNMP Configuration Settings"))
-- sys.addremove = false
-- sys.anonymous = true
-- 
-- o = sys:option(Value, "sysLocation", translate("Location"))
-- o = sys:option(Value, "sysContact", translate("Contact"))
-- o = sys:option(Value, "sysName", translate("Name"))

loc = agent:option(Value, "sysLocation", translate("Location"), translate("Trap named sysLocation"))
	function loc.cfgvalue(self, section)
		return luci.sys.exec("uci get snmpd.@system[0].sysLocation")
	end
	function loc.write(self, section, value)
		luci.sys.call("uci set snmpd.@system[0].sysLocation="..value.."; uci commit snmpd")
	end  
	  
con = agent:option(Value, "sysContact", translate("Contact"), translate("Trap named sysContact"))
	function con.cfgvalue(self, section)
		return luci.sys.exec("uci get snmpd.@system[0].sysContact")
	end
	function con.write(self, section, value)
		luci.sys.call("uci set snmpd.@system[0].sysContact="..value.."; uci commit snmpd")
	end
	
nam = agent:option(Value, "sysName", translate("Name"), translate("Trap named sysName"))
	function nam.cfgvalue(self, section)
		return luci.sys.exec("uci get snmpd.@system[0].sysName")
	end
	function nam.write(self, section, value)
		luci.sys.call("uci set snmpd.@system[0].sysName="..value.."; uci commit snmpd")
	end

function o.write(self, section, value)
	Value.write(self, section, value)
		
	----------------------------------------------------------------------------
	-- community option
	----------------------------------------------------------------------------
	local stateNow = com:formvalue(section)
	local statePreviuos
	local nameNow, namePreviuos
	local needUpdate = false
	local commonName
	
	x:foreach(_define_snmp_cfg, "agent", 
		function(s)	
			statePreviuos = s._community
			namePreviuos = s._community_name
			srcPreviuos = s._src
		end) 	
		
	-- check if there are changes
	if stateNow ~= statePreviuos then 
		needUpdate = true 
	end
	if stateNow == "custom" then
		nameNow = comname:formvalue(section)
		if nameNow ~= namePreviuos then needUpdate = true end
	end
	
	if stateNow == "private" then
		srcNow = src:formvalue(section)
		if srcNow ~= srcPreviuos then needUpdate = true end
	end
	
	if needUpdate then
		if statePreviuos ~= "custom" then commonName = statePreviuos
		else commonName = namePreviuos end
		
		-- delete old sections
		x:delete(_define_snmp_cfg, commonName)
		x:delete(_define_snmp_cfg, commonName .. "_v1")
		x:delete(_define_snmp_cfg, commonName .. "_v2c")
		x:delete(_define_snmp_cfg, commonName .. "_usm")
		x:delete(_define_snmp_cfg, commonName .. "_access")
		
		-- create new sections
		if stateNow == "public" then
			x:set(_define_snmp_cfg, stateNow, "com2sec") -- new section
			x:set(_define_snmp_cfg, stateNow, "secname", "ro")
			x:set(_define_snmp_cfg, stateNow, "source", "default")
			x:set(_define_snmp_cfg, stateNow, "community", stateNow)
			
			x:set(_define_snmp_cfg, stateNow .. "_v1", "group") -- new section
			x:set(_define_snmp_cfg, stateNow .. "_v1", "group", stateNow)
			x:set(_define_snmp_cfg, stateNow .. "_v1", "version", "v1")
			x:set(_define_snmp_cfg, stateNow .. "_v1", "secname", "ro")
			
			x:set(_define_snmp_cfg, stateNow .. "_v2c", "group") -- new section
			x:set(_define_snmp_cfg, stateNow .. "_v2c", "group", stateNow)
			x:set(_define_snmp_cfg, stateNow .. "_v2c", "version", "v2c")	
			x:set(_define_snmp_cfg, stateNow .. "_v2c", "secname", "ro")	

			x:set(_define_snmp_cfg, stateNow .. "_usm", "group") -- new section
			x:set(_define_snmp_cfg, stateNow .. "_usm", "group", stateNow)
			x:set(_define_snmp_cfg, stateNow .. "_usm", "version", "usm")	
			x:set(_define_snmp_cfg, stateNow .. "_usm", "secname", "ro")
		
			x:set(_define_snmp_cfg, stateNow .. "_access", "access") -- new section
			x:set(_define_snmp_cfg, stateNow .. "_access", "group", stateNow)
			x:set(_define_snmp_cfg, stateNow .. "_access", "context", "none")	
			x:set(_define_snmp_cfg, stateNow .. "_access", "version", "any")
			x:set(_define_snmp_cfg, stateNow .. "_access", "level", "noauth")
			x:set(_define_snmp_cfg, stateNow .. "_access", "prefix", "exact")	
			x:set(_define_snmp_cfg, stateNow .. "_access", "read", "all")
			x:set(_define_snmp_cfg, stateNow .. "_access", "write", "none")
			x:set(_define_snmp_cfg, stateNow .. "_access", "notify", "none")	
		elseif stateNow == "private" then
			x:set(_define_snmp_cfg, stateNow, "com2sec") -- new section
			x:set(_define_snmp_cfg, stateNow, "secname", "rw")
			x:set(_define_snmp_cfg, stateNow, "source", srcNow)
			x:set(_define_snmp_cfg, stateNow, "community", stateNow)
			
			x:set(_define_snmp_cfg, stateNow .. "_v1", "group") -- new section
			x:set(_define_snmp_cfg, stateNow .. "_v1", "group", stateNow)
			x:set(_define_snmp_cfg, stateNow .. "_v1", "version", "v1")
			x:set(_define_snmp_cfg, stateNow .. "_v1", "secname", "rw")
			
			x:set(_define_snmp_cfg, stateNow .. "_v2c", "group") -- new section
			x:set(_define_snmp_cfg, stateNow .. "_v2c", "group", stateNow)
			x:set(_define_snmp_cfg, stateNow .. "_v2c", "version", "v2c")	
			x:set(_define_snmp_cfg, stateNow .. "_v2c", "secname", "rw")	

			x:set(_define_snmp_cfg, stateNow .. "_usm", "group") -- new section
			x:set(_define_snmp_cfg, stateNow .. "_usm", "group", stateNow)
			x:set(_define_snmp_cfg, stateNow .. "_usm", "version", "usm")	
			x:set(_define_snmp_cfg, stateNow .. "_usm", "secname", "rw")
		
			x:set(_define_snmp_cfg, stateNow .. "_access", "access") -- new section
			x:set(_define_snmp_cfg, stateNow .. "_access", "group", stateNow)
			x:set(_define_snmp_cfg, stateNow .. "_access", "context", "none")	
			x:set(_define_snmp_cfg, stateNow .. "_access", "version", "any")
			x:set(_define_snmp_cfg, stateNow .. "_access", "level", "noauth")
			x:set(_define_snmp_cfg, stateNow .. "_access", "prefix", "exact")	
			x:set(_define_snmp_cfg, stateNow .. "_access", "read", "all")
			x:set(_define_snmp_cfg, stateNow .. "_access", "write", "all")
			x:set(_define_snmp_cfg, stateNow .. "_access", "notify", "all")	
		elseif stateNow == "custom" then
			x:set(_define_snmp_cfg, nameNow, "com2sec") -- new section
			x:set(_define_snmp_cfg, nameNow, "secname", "rw")
			x:set(_define_snmp_cfg, nameNow, "source", "default")
			x:set(_define_snmp_cfg, nameNow, "community", nameNow)
			
			x:set(_define_snmp_cfg, nameNow .. "_v1", "group") -- new section
			x:set(_define_snmp_cfg, nameNow .. "_v1", "group", nameNow)
			x:set(_define_snmp_cfg, nameNow .. "_v1", "version", "v1")
			x:set(_define_snmp_cfg, nameNow .. "_v1", "secname", "rw")
			
			x:set(_define_snmp_cfg, nameNow .. "_v2c", "group") -- new section
			x:set(_define_snmp_cfg, nameNow .. "_v2c", "group", nameNow)
			x:set(_define_snmp_cfg, nameNow .. "_v2c", "version", "v2c")	
			x:set(_define_snmp_cfg, nameNow .. "_v2c", "secname", "rw")	

			x:set(_define_snmp_cfg, nameNow .. "_usm", "group") -- new section
			x:set(_define_snmp_cfg, nameNow .. "_usm", "group", nameNow)
			x:set(_define_snmp_cfg, nameNow .. "_usm", "version", "usm")	
			x:set(_define_snmp_cfg, nameNow .. "_usm", "secname", "rw")
		
			x:set(_define_snmp_cfg, nameNow .. "_access", "access") -- new section
			x:set(_define_snmp_cfg, nameNow .. "_access", "group", nameNow)
			x:set(_define_snmp_cfg, nameNow .. "_access", "context", "none")	
			x:set(_define_snmp_cfg, nameNow .. "_access", "version", "any")
			x:set(_define_snmp_cfg, nameNow .. "_access", "level", "noauth")
			x:set(_define_snmp_cfg, nameNow .. "_access", "prefix", "exact")	
			x:set(_define_snmp_cfg, nameNow .. "_access", "read", "all")
			x:set(_define_snmp_cfg, nameNow .. "_access", "write", "all")
			x:set(_define_snmp_cfg, nameNow .. "_access", "notify", "all")	
		end	
		x:save(_define_snmp_cfg)
	end	
		------------------------------------------------------------------------
		-- other options
		------------------------------------------------------------------------
		local remoteEnable = remote:formvalue(section)
		local openPort = port:formvalue(section)
		local needsUpdate = false
		local remoteEnableFix
		
		local fwRuleInstName
		local fwRuleEnabled
		local fwRulePort
		local fwRuleFound = false
		

		if not openPort or openPort == "" then
			m.message = translate("err: Please specify SNMP port!")
			return
		end
		
		-- Double execution prevention
		if not deathtrap then deathtrap = true else return end
		
		-- scan existing rules
		uci:foreach("firewall", "rule", function(s)
			if s.name == __define__rule_name then
				fwRuleInstName = s[".name"]
				fwRuleEnabled = s.enable
				fwRulePort = s.dest_port
				fwRuleFound = true
			end
		end)
		
		-- update values if rule exists
		if fwRuleFound then
			-- fix incompatibility
			if remoteEnable == "1" then remoteEnableFix = "" else remoteEnableFix = "0" end
			
			if openPort ~= fwRulePort then
				uci:set("firewall", fwRuleInstName, "dest_port", openPort)
				needsUpdate = true
			end	
			if remoteEnableFix ~= fwRuleEnabled then
				if remoteEnable == "1" then
					uci:delete("firewall", fwRuleInstName, "enabled")
					needsUpdate = true
				elseif remoteEnable == "0" or remoteEnable == nil then
					uci:set("firewall", fwRuleInstName, "enabled", "0")
					needsUpdate = true
				end
			end
		end
		
		
		
		if not fwRuleFound then
			local wanZone = fw:get_zone("wan")
			if not wanZone then
				m.message = translate("err: Error: could not add firewall rule!")
				return
			end
			
			-- fix incompatibility issue
			local enableFlagFix = ""
			if remoteEnable == "0" or remoteEnable == nil then enableFlagFix = "0" end
			 
			local options = {
				target 		= "ACCEPT",
				proto 		= "udp",
				dest_port 	= openPort,
				name 		= __define__rule_name,
				enabled		= enableFlagFix
			}
			wanZone:add_rule(options)
			needsUpdate = true
		end		
		
		if needsUpdate == true then
			uci:save("firewall")
			uci:commit("firewall")
		end
		
		-- duplicate port entry. This value is used by snmpd
		x:set("snmpd", section, "agentaddress", "UDP:" .. openPort)
		x:save(_define_snmp_cfg)
		x:commit(_define_snmp_cfg)
end

-- o = agent:taboption("trap", Flag, "trap_enabled", translate("SNMP Trap"), translate("Enable SNMP (Simple Network Management Protocol) trap functionality"))
-- -----
-- --port
-- -----
-- hst = agent:taboption("trap", Value, "trap_host", translate("Host/IP"), translate("Host to transfer SNMP (Simple Network Management Protocol) traffic to"))
-- hst.datatype = "ipaddr"
--
-- -- -------
-- -- -- port
-- -- -------
-- prt = agent:taboption("trap", Value, "trap_port", translate("Port"), translate("Port for trap\\'s host"))
-- prt.default = "162"
-- prt.datatype = "port"
--
-- -- -- community
-- -- --
-- c = agent:taboption("trap", ListValue, "trap_community", translate("Community"), translate("The SNMP (Simple Network Management Protocol) Community is an ID that allows access to a router\\'s SNMP data"))
-- c:value("public", "Public")
-- c:value("private", "Private")
-- c.default = "Public"
--
-- sig = agent:taboption("trap", Flag, "sigEnb", translate("Signal trap"), translate("Trap that will be triggered if GSM signal\\'s strength drops bellow certain value"))
-- sigstr = agent:taboption("trap", Value, "signal", translate("Signal strength"), translate("GSM signal\\'s strength value in dBm, e.g. -85"))
--
-- cont = agent:taboption("trap", Flag, "conEnb", translate("Connection type trap"), translate("Trap that will be triggered when GSM connection\\'s type changes, e.g. from EDGE to HSUPA"))

return m
