
local utl = require "luci.util"
local nw = require "luci.model.network"
local sys = require "luci.sys"
local ntm = require "luci.model.network".init()
local m
local savePressed = luci.http.formvalue("cbi.apply") and true or false
local filterPath = "/etc/tinyproxy/" 
local filterFile = "filter"
local not_dns = false

local function debug(string)
	luci.sys.call("echo \"" .. string .. "\" >> /tmp/filter.log")
end

m = Map("privoxy", translate("Proxy Based URL Content Blocker Configuration"),
	translate(""))
m.addremove = false

s = m:section(NamedSection, "privoxy", "privoxy", translate("Proxy Based URL Content Blocker"))
s.addremove = false

--watcher = s:option(Value, "watcher")
--watcher.template  = "cbi/watcher"

enb = s:option(Flag, "enabled", translate("Enable"), translate("Enable proxy server based URL content blocking. Works with HTTP protocol only"))
enb.rmempty = false

mode = s:option(ListValue, "mode", translate("Mode"), translate("Whitelist - allow every part of URL on the list and block everything else. Blacklist - block every part of URL on the list and allow everything else"))
mode:value("whitelist", translate("Whitelist"))
mode:value("blacklist", translate("Blacklist"))
mode.default = "blacklist"

s2 = m:section(TypedSection, "rule", translate("URL Filter Rules"))
s2.addremove = true
s2.anonymous = true
s2.template  = "cbi/tblsection"
s2.novaluetext = translate("There are no URL filter rules created yet")

enb_rul = s2:option(Flag, "enabled", translate("Enable"), translate("Make a rule active/inactive"))
enb_rul.rmempty = false
enb_rul.default = "1"

url_cont = s2:option(Value, "domen", translate("URL content"), translate("Block/allow any URL containing this string. example.com, example.*, *.example.com"))
url_cont:depends("custom", "")

function m.on_after_commit(self, section, value)
	local action_file = "/etc/privoxy/user.action"
	local enb_val = m.uci:get("privoxy", "privoxy", "enabled")
	local mode_val = m.uci:get("privoxy", "privoxy", "mode")
	if enb_val == "1" then
		local file = assert(io.open(action_file, "w"))
		if mode_val == "blacklist" then
			file:write("{+block{Blacklist}}\n")	
			m.uci:foreach("privoxy", "rule", function(s)
				if s.enabled == "1" and s.domen then
					file:write(string.format("%s\n",s.domen))
				end
			end)
		else
			file:write("{+block{Blacklist}}\n/ # Block *all* URLs\n\n{-block{Whitelist}}\n")	
			m.uci:foreach("privoxy", "rule", function(s)
				if s.enabled == "1" and s.domen then
					file:write(string.format("%s\n",s.domen))
				end
			end)
		end
		file:close()
	end
	
end
 
return m