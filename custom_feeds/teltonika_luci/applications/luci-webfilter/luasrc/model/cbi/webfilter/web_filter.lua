
local utl = require "luci.util"
local nw = require "luci.model.network"
local sys = require "luci.sys"
local ntm = require "luci.model.network".init()
local m
local savePressed = luci.http.formvalue("cbi.apply") and true or false
local filterPath = "/etc/tinyproxy/" 
local filterFile = "filter"
local routerIP = utl.trim(sys.exec("uci get network.lan.ipaddr"))
local dns = utl.trim(sys.exec("uci get network.wan.dns"))
local proto = utl.trim(sys.exec("uci get network.wan.proto"))
local trap = true
local dns_disbale = true
local not_dns = false

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

local function debug(string)
	luci.sys.call("echo \"" .. string .. "\" >> /tmp/filter.log")
end

m2 = Map("hostblock", translate("Site Blocking Settings"), 
	translate(""))
m2.addremove = false

if not dns or dns == "" and proto == "static" then
	not_dns = true
end

if not_dns then
	m2:chain("network")	
end

sc = m2:section(NamedSection, "config","config", translate("Site Blocking"))

enb_block = sc:option(Flag, "enabled", translate("Enable"), translate("Enable host name based websites blocking"))
enb_block.rmempty = false
--[[
function enb_block.write(self, section, val)
	local oldValue = m.uci:get("hostblock", "config", "enabled")
	if val then
		m.uci:set("hostblock", "config", "enabled", val)
		m.uci:save("hostblock")
		m.uci:commit("hostblock")
		if oldValue ~= val and val ~= "1" then
			dns_disbale = false
		end
	end
end

function enb_block.cfgvalue(self, section)
	local val = m.uci:get("hostblock", "config", "enabled")
	return val
end

enb_dns = sc:option(Flag, "block_dns", translate("Block DNS forwarding"))
enb_dns.rmempty = false

function enb_dns.write(self, section, val)
	local fwzone = "nil"
	m.uci:foreach("firewall", "rule", function(s)
		if s.name == "Block_DNS_forwarding" then
			if val == "1" then
				m.uci:delete("firewall", s[".name"], "enabled")
			else
				m.uci:set("firewall", s[".name"], "enabled", val)
			end
		end
	end)
	m.uci:save("firewall")
	m.uci:commit("firewall")
end

function enb_dns.cfgvalue(self, section)
	local val
	m.uci:foreach("firewall", "rule", function(s)
		if s.name == "Block_DNS_forwarding" then
			val = m.uci:get("firewall", s[".name"], "enabled")
		end
	end)
	return val and val or "1"
end
]]--

mode = sc:option(ListValue, "mode", translate("Mode"), translate("Whitelist - allow every site on the list and block everything else. Blacklist - block every site on the list and allow everything else"))
mode:value("whitelist", translate("Whitelist"))
mode:value("blacklist", translate("Blacklist"))
mode.default = "blacklist"

sc1 = m2:section(TypedSection, "block")
sc1.addremove = true
sc1.anonymous = true
sc1.template  = "cbi/tblsection"
sc1.novaluetext = translate("There are no site blocking rules created yet")

enb_cont = sc1:option(Flag, "enabled", translate("Enable"), translate("Check to enable site blocking"))
enb_cont.rmempty = false
enb_cont.default = "1"

url_cont = sc1:option(Value, "host", translate("Host name"), translate("Block/allow site with this host name. example.com"))

--[[
m = Map("privoxy", translate("Proxy Based Content Blocker"),
	translate("Here you can configure web content filtering"))
m.addremove = false


s = m:section(NamedSection, "privoxy")
s.addremove = false

--watcher = s:option(Value, "watcher")
--watcher.template  = "cbi/watcher"

enb = s:option(Flag, "enabled", translate("Enable filter"))
enb.rmempty = false

function enb.write(self, section, value)
	local oldValue = m.uci:get("privoxy", "privoxy", "enabled")
	local port = luci.http.formvalue("cbid.privoxy.privoxy.port")
	os.execute("/etc/init.d/firewall restart >/dev/null 2>/dev/null")
	local TransparentRule = "iptables -t nat -A PREROUTING -i br-lan -p tcp ! -d "..routerIP.. " --dport 80 -j REDIRECT --to-port ".. port

	if oldValue ~= value then
		if value == "1" then
			os.execute("echo \""..TransparentRule.."\" >> /etc/firewall.user");
		else
			os.execute("sed -i 's/"..TransparentRule.."//g' /etc/firewall.user");
		end
		m.uci:set("privoxy", "privoxy", "enabled", value)
		
	elseif value == "1" then
		os.execute("echo \""..TransparentRule.."\" > /etc/firewall.user");
	end
end

function cfgvalue(self, section)
	local val = m.uci:get("privoxy", "privoxy", "enabled")
	return val
end

mode = s:option(ListValue, "mode", translate("Mode"))

mode:value("whitelist", translate("Whitelist"))
mode:value("blacklist", translate("Blacklist"))
mode.default = "blacklist"


-- serv = s:option(ListValue, "StartServers", translate("Start servers"))
-- for i=1,10 do
-- 	if i == 1 then
-- 		serv:value(i, translate("1"))	
-- 	else
-- 		serv:value(i, translate(i))	
-- 	end
-- 
-- end

port = s:option(Value, "port", translate("Proxy port"))

function set_privoxy()
	local conf_file = "/etc/privoxy/config"
	local value = m.uci:get("privoxy", "privoxy", "port")
	local config = {}
	local file 
	file = assert(io.open(conf_file, "r"))
	while true do
		optn = file:read("*l")
		if not optn then break end
		config[#config+1] = optn
	end
	file:close()
	
	file = assert(io.open(conf_file, "w"))
	for k,val in pairs(config) do
		if val then
			local port = string.match(val, "listen%-address")
			local permit = string.match(val, "permit%-access")
			if port then
				file:write(string.format("listen-address  %s:%s\n",routerIP,value))
			elseif permit then
				local ip = string.match(routerIP, "(%d+.%d+.%d+)")
				file:write(string.format("permit-access  " ..ip.. ".0/%s\n",get_mask()))
			else
				file:write(string.format("%s\n",val))
			end
			
		end
	end
	file:close()
	
	if not_dns  then
		 m.uci:set("network", "wan", "dns", "8.8.8.8")
		 m.uci:save("network")
		 m.uci:commit("network")
	end
end
-- function port.write(self, section, value)
-- 	local conf_file = "/etc/privoxy/config"
-- 	local config = {}
-- 	local file 
-- 	file = assert(io.open(conf_file, "r"))
-- 	while true do
-- 		optn = file:read("*l")
-- 		if not optn then break end
-- 		config[#config+1] = optn
-- 	end
-- 	file:close()
-- 	
-- 	file = assert(io.open(conf_file, "w"))
-- 	for k,val in pairs(config) do
-- 		if val then
-- 			local port = string.match(val, "listen%-address")
-- 			local permit = string.match(val, "permit%-access")
-- 			if port then
-- 				file:write(string.format("listen-address  %s:%s\n",routerIP,value))
-- 			elseif permit then
-- 				local ip = string.match(routerIP, "(%d+.%d+.%d+)")
-- 				file:write(string.format("permit-access  " ..ip.. ".0/%s\n",get_mask()))
-- 			else
-- 				file:write(string.format("%s\n",val))
-- 			end
-- 			
-- 		end
-- 	end
-- 	file:close()
-- end
-- 
-- function port.cfgvalue()
-- 	local conf_file = "/etc/privoxy/config"
-- 	local file = assert(io.open(conf_file, "r"))
-- 	local optn
-- 	while true do
-- 		optn = file:read("*l")
-- 		if not optn then return "1" end
-- 		if  string.find(optn, 'listen%-address') then
-- 			local port = string.match(optn, ":(%d+)")
-- 			return port
-- 		end	
--         end
-- 	file:close()
-- end

s2 = m:section(TypedSection, "rule", translate("Filter URL Rules"))
s2.addremove = true
s2.anonymous = true
s2.template  = "cbi/tblsection"

enb_rul = s2:option(Flag, "enabled", translate("Enable"))
enb_rul.rmempty = false
enb_rul.default = "1"

url_cont = s2:option(Value, "domen", translate("URL content"), translate("example.com, example.*, *.example.com"))
url_cont:depends("custom", "")

function get_mask()
	local lan
	lan = ntm:get_interface("br-lan")
	lan = lan and lan:get_network()
	-- if bridge_on == "1" then
	-- 	lan["sid"] = "lan2"
	-- end
	addrs = lan:_ubus("ipv4-address")
	netmask = addrs[1].mask
	return netmask
end

function m.on_after_commit(self, section, value)
	local action_file = "/etc/privoxy/user.action"
	local enb_val = m.uci:get("privoxy", "privoxy", "enabled")
	local mode_val = m.uci:get("privoxy", "privoxy", "mode")
	if enb_val == "1" then
		set_privoxy()
		local file = assert(io.open(action_file, "w"))
		if mode_val == "blacklist" then
			file:write("{+block{Blacklist}}\n")	
			m.uci:foreach("privoxy", "rule", function(s)
				if s.enabled == "1" and s.domen then
					file:write(string.format(".%s\n",s.domen))
				end
			end)
		else
			file:write("{+block{Blacklist}}\n/ # Block *all* URLs\n\n{-block{Whitelist}}\n")	
			m.uci:foreach("privoxy", "rule", function(s)
				if s.enabled == "1" and s.domen then
					file:write(string.format(".%s\n",s.domen))
				end
			end)
		end
		file:close()
	end
	
end
]]--
-- port = s2:option(Value, "port", translate("Port"), translate("80"))
-- port:depends("custom", "")
-- phrase = s2:option(Value, "phrase", translate("Phrase"), translate("fashion"))
-- phrase:depends("custom", "")
-- custom_expr = s2:option(Value, "custom", translate("Custom regular expression"), translate("google.*:80/.*(fashion|eshop)"))

 
return m2--, m
 
