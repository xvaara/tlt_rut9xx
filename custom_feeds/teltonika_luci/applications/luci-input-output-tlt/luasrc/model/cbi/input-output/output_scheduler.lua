local sys = require "luci.sys"
local trap = false

m = Map( "output_control", translate( "Output Scheduler" ), translate( "" ) )

s = m:section( NamedSection, "scheduler", "scheduler", translate("Configure Scheduled Outputs"), translate("" ))

gpio = s:option(ListValue, "gpio", translate("Output"), translate("Select which output will be configured"))
	gpio:value("DOUT1", translate("Digital OC output"))
	gpio:value("DOUT2", translate("Digital relay output"))
	gpio:value("all", translate("All"))
	
function gpio.write() end
	
tbl = s:option( Value, "days")
tbl.template="input-output/scheduler"

function tbl.write(self, section, value)
	if not trap then
		local path = "/etc/scheduler/config"
		local days={"mon", "tue", "wed", "thu", "fri", "sat", "sun"}
		local script = "/sbin/gpio.sh"
		local pin = m.uci:get("output_control", "scheduler", "gpio")
		local line, cron
		local pin_state = {}
		local set = {}
		local clear = {}
		local old_hr
		local empty = true
		local current_day = sys.exec("date +%a")
		local current_hour = tonumber(sys.exec("date +%H"))
		daysnr={[1] = "Mon\n", [2] = "Tue\n", [3] = "Wed\n", [4] = "Thu\n", [5] = "Fri\n", [6] = "Sat\n", [7] = "Sun\n"}
		file = io.open(path, "w+")
		os.execute('sed -i "/gpio.sh/d" /etc/crontabs/root')

		for i=1,7  do
			n = 1
			hours = string.sub(value, i*24-23, i*24)
			local day_of_week = daysnr[i]
			local hr_nr = 0
			
			for hr in hours:gmatch(".") do

				if day_of_week == current_day and hr_nr == current_hour then
						if hr == "1" then
							sys.exec('/sbin/gpio.sh set DOUT1')
							sys.exec('/sbin/gpio.sh clear DOUT2')
						elseif hr == "2" then
							sys.exec('/sbin/gpio.sh clear DOUT1')
							sys.exec('/sbin/gpio.sh set DOUT2')
						elseif hr == "3" then
							sys.exec('/sbin/gpio.sh set DOUT1')
							sys.exec('/sbin/gpio.sh set DOUT2')
						elseif hr == "0" then
							sys.exec('/sbin/gpio.sh clear DOUT1')
							sys.exec('/sbin/gpio.sh clear DOUT2')
						end
					end
					hr_nr = hr_nr + 1
					
				if hr == "1" then
					table.insert(set, "DOUT1")
					table.insert(clear, "DOUT2")
				elseif hr == "2" then
					table.insert(set, "DOUT2")
					table.insert(clear, "DOUT1")
				elseif hr == "3" then
					table.insert(set, "DOUT1")
					table.insert(set, "DOUT2")
				elseif hr == "0" then
					table.insert(clear, "DOUT1")
					table.insert(clear, "DOUT2")
				end
				
				if old_hr ~= hr then
					cron_conf = io.open("/etc/crontabs/root", "a")

					for key, value in pairs(set) do
						if pin_state[value] ~= 1 then
							cron = string.format("0 %s * * %s %s set %s%s", n-1, days[i], script, value, "\n")
							cron_conf:write(cron)
							pin_state[value] = 1
							empty = false
						end
						os.execute("logger " ..cron)
					end
					
					for key, value in pairs(clear) do
						if pin_state[value] ~= 0 then
							cron = string.format("0 %s * * %s %s clear %s%s", n-1, days[i], script, value, "\n")
							cron_conf:write(cron)
							pin_state[value] = 0
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
			line = string.format("%s:%s%s", days[i], hours, "\n")
			--os.execute("logger " ..line)
			file:write(line)
		end
		file:close()
		trap = true
		if empty then
			os.execute('sed -i "/gpio.sh/d" /etc/crontabs/root')
		end
	end
end

return m
