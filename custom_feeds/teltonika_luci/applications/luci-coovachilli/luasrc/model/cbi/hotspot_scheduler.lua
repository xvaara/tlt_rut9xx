local sys = require "luci.sys"

local pathinfo = os.getenv("PATH_INFO")
local the_paths = {}
local the_path_len = 0

for node in pathinfo:gmatch("[^/]+") do
	table.insert(the_paths, node)
	the_path_len = the_path_len +1
end 
local tab_SSID = the_paths[the_path_len]

require("uci")
local x = uci.cursor()
local listofssids = {}
local list_length = 0

x:foreach("wireless", "wifi-iface", function(s)
		table.insert(listofssids, s.ssid)
		list_length = list_length +1
end)
	if tab_SSID == "hotspot_scheduler" then
		tab_SSID = listofssids[1]
	end

m = Map( "hotspot_scheduler", translate( "Internet Access Restriction Settings" ), translate( "" ) )
s = m:section( NamedSection, "scheduler", "scheduler", translate("Select Time To Restrict Access On Hotspot " .. tab_SSID), translate("" ))

--function m.on_parse(self)
--end
tbl = s:option( Value, "days")
tbl.template="chilli/hotspot_scheduler"

--apsauga nuo vienodu sekciju irasymo kelis kartus
local section_exists = false
x:foreach("hotspot_scheduler", "SSID", function(s)
		if s.name == tab_SSID then
			section_exists = true
		end
end)
if section_exists == false then
	x:set("hotspot_scheduler", tab_SSID, "SSID")
	x:commit("hotspot_scheduler")
end

--nenaudojamu sekciju trynimas
local list_todelete = {}
local list_todelete_len = 0
x:foreach("hotspot_scheduler", "SSID", function(s)
		local usable_section = false
		local sname = s['.name']
		for i=1,list_length,1 do
			if sname == listofssids[i] then
				usable_section = true
			end
		end
		if usable_section == false then
			table.insert(list_todelete, sname)
			list_todelete_len = list_todelete_len +1
		end
end)
if list_todelete_len > 0 then
	for i=1,list_todelete_len,1 do
		os.execute('sed -i /' .. list_todelete[i] .. '/d /etc/crontabs/root')
		m.uci:delete("hotspot_scheduler", list_todelete[i])
		m.uci:commit("hotspot_scheduler")
	end
end

function tbl.write(self, section, value)
	if not trap then
		local path = "/etc/hotspot_scheduler/config"
		local days={"mon", "tue", "wed", "thu", "fri", "sat", "sun"}
		daysnr={[1] = "Mon\n", [2] = "Tue\n", [3] = "Wed\n", [4] = "Thu\n", [5] = "Fri\n", [6] = "Sat\n", [7] = "Sun\n"}
		local script = "/sbin/hotspot_restrict.sh"
		local line, cron
		local set = {}
		local clear = {}
		local old_hr
		local empty = true
		local current_day = sys.exec("date +%a")
		local current_hour = tonumber(sys.exec("date +%H"))

		os.execute('sed -i /' .. tab_SSID .. '/d /etc/crontabs/root')
		
		for i=1,7  do
			n = 1
			hours = string.sub(value, i*24-23, i*24)
			local day_of_week = daysnr[i]
			local hr_nr = 0
			
			for hr in hours:gmatch(".") do
				if day_of_week == current_day and hr_nr == current_hour then
					if hr == "1" then
						sys.exec('/sbin/hotspot_restrict.sh set ' .. tab_SSID)
					elseif hr == "0" then
						sys.exec('/sbin/hotspot_restrict.sh clear ' .. tab_SSID)
					end
				end
				hr_nr = hr_nr + 1
					if hr == "1" then
						table.insert(set, tab_SSID)
					elseif hr == "0" then
						table.insert(clear, tab_SSID)
					end
				
				if old_hr ~= hr then
					cron_conf = io.open("/etc/crontabs/root", "a")

					for key, value in pairs(set) do
						if hr ~= 1 then
							cron = string.format("0 %s * * %s %s set %s%s", n-1, days[i], script, value, "\n")
							cron_conf:write(cron)
							empty = false
						end
						os.execute("logger " ..cron)
					end
					for key, value in pairs(clear) do
						if hr ~= 0 then
							cron = string.format("0 %s * * %s %s clear %s%s", n-1, days[i], script, value, "\n")
							cron_conf:write(cron)
						end
						os.execute("logger " ..cron)
					end
					cron_conf:close()
				end
				n = n + 1
				old_hr = hr
				set = {}
				clear = {}
			end
			x:set("hotspot_scheduler", tab_SSID, days[i], hours)
			x:commit("hotspot_scheduler")
			line = string.format("%s:%s%s", days[i], hours, "\n")
		end
		trap = true
		if empty then
--			os.execute('sed -i "/gpio.sh/d" /etc/crontabs/root')
		end
	end
end

return m
