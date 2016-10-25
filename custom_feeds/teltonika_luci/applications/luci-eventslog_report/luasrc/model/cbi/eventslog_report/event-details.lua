local sys = require "luci.sys"
local dsp = require "luci.dispatcher"
local utl = require "luci.util"

local m, s, o

arg[1] = arg[1] or ""

m = Map("eventslog_report",
	translate("Events Log Report Configuration"))

m.redirect = dsp.build_url("admin/status/event/log_report")
if m.uci:get("eventslog_report", arg[1]) ~= "rule" then
	luci.http.redirect(dsp.build_url("admin/status/event/log_report"))
	return
else
	--local name = m:get(arg[1], "name") or m:get(arg[1], "_name")
	--if not name or #name == 0 then
	--	name = translate("(Unnamed Entry)")
	--end
	--m.title = "%s - %s" %{ translate("Firewall - Port Forwards"), name }
end

s = m:section(NamedSection, arg[1], "rule", translate("Modify events log file report rule"))
s.anonymous = true
s.addremove = false

o = s:option(Flag, "enable", translate("Enable"), translate("Make a rule active/inactive"))

o = s:option(ListValue, "event", translate("Events log"), translate("Events log for which the rule is applied"))
o:value("system", translate("System"))
o:value("network", translate("Network"))
o:value("all", translate("All"))
function o.cfgvalue(...)
	local v = Value.cfgvalue(...)
	return v
end

o = s:option(ListValue, "type", translate("Transfer type"), translate("Events log file transfer type"))
o:value("Email", translate("Email"))
o:value("FTP", translate("FTP"))
function o.cfgvalue(...)
	local v = Value.cfgvalue(...)
	return v
end

o = s:option(Flag, "compress", translate("Compress file"), translate("Compress events log file using gzip"))

o = s:option(Value, "subject", translate("Subject"), translate("Subject of an email. Allowed characters (a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. )"))                  
o:depends("type", "Email")                                                                   
o.datatype = "fieldvalidation('^[a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. ]+$',0)"

o = s:option(Value, "message", translate("Message"), translate("Message to send in email. Allowed characters (a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. )"))                 
o:depends("type", "Email")                                       
o.datatype = "fieldvalidation('^[a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. ]+$',0)"

o = s:option(Value, "smtpIP", translate("SMTP server"), translate("SMTP (Simple Mail Transfer Protocol) server. Allowed characters (a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. )"))
o:depends("type", "Email")
o.datatype = "fieldvalidation('^[a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. ]+$',0)"

o = s:option(Value, "smtpPort", translate("SMTP server port"), translate("SMTP (Simple Mail Transfer Protocol) server port"))
o:depends("type", "Email")
o.datatype = "port"

o = s:option(Flag, "secureConnection", translate("Secure connection"), translate("Use only if server supports SSL or TLS"))
o:depends("type", "Email")

o = s:option(Value, "host", translate("Host"), translate("FTP (File Transfer Protocol) host name, e.g. ftp.example.com, 192.168.123.123. Allowed characters (a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. )"))                                                 
o:depends("type", "FTP")                                                                                                                
o.datatype = "fieldvalidation('^[a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. ]+$',0)"

o = s:option(Value, "user", translate("User name"), translate("User name for authentication on SMTP (Simple Mail Transfer Protocol) or FTP (File Transfer Protocol) server. Allowed characters (a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. )"))
o.datatype = "fieldvalidation('^[a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. ]+$',0)"

o = s:option(Value, "password", translate("Password"), translate("Password for authentication on SMTP (Simple Mail Transfer Protocol) or FTP (File Transfer Protocol) server. Allowed characters (a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. )"))
o.password = true
o.datatype = "fieldvalidation('^[a-zA-Z0-9!@#$%&*+-/=?^_`{|}~. ]+$',0)"

o = s:option(Value, "senderEmail", translate("Sender's email address"), translate("An address that will be used to send your email from. Allowed characters (a-zA-Z0-9._%+-)"))
o:depends("type", "Email")
o.datatype = "fieldvalidation('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]$',0)"

o = s:option(DynamicList, "recipEmail", translate("Recipient's email address"), translate("For whom you want to send an email to. Allowed characters (a-zA-Z0-9._%+-)"))
o:depends("type", "Email")
function o:validate(Values)
	local smtpIP = m:formvalue("cbid.eventslog_report."..arg[1]..".smtpIP")
	local smtpPort = m:formvalue("cbid.eventslog_report."..arg[1]..".smtpPort") 
	local username = m:formvalue("cbid.eventslog_report."..arg[1]..".user")
	local passwd = m:formvalue("cbid.eventslog_report."..arg[1]..".password")
	local senderEmail = m:formvalue("cbid.eventslog_report."..arg[1]..".senderEmail")
	local failure
	
	if smtpIP == "" then
		m.message = translate("err: SMTP server field is empty!")
		failure = true
	else
		if smtpPort == "" then
			m.message = translate("err: SMTP server port field is empty")
			failure = true
		else
			if senderEmail == "" then
				m.message = translate("err: Sender's email address field is empty!")
				failure = true
			else
				for k,v in pairs(Values) do
					if not v:match("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]$") then
						m.message = translatef("err: Recipient's email address is incorrect!")
						failure = true
					end
				end
			end
		end
	end
	
	if not failure then
		return Values
	end
	return nil
end

o = s:option(ListValue, "repeat", translate("Interval between reports"), translate("Send reports every select time interval"))
o:value("week", translate("Week"))
o:value("month", translate("Month"))
o:value("year", translate("Year"))
function o.cfgvalue(...)
        local v = Value.cfgvalue(...)
                return v
end
function o:validate(Values)
	local host = m:formvalue("cbid.eventslog_report."..arg[1]..".host")
	local user = m:formvalue("cbid.eventslog_report."..arg[1]..".user")
	local failure
	
	if host == "" then
		m.message = translate("err: Host name field is empty!")
		failure = true
	else
		if username == "" then
			m.message = translate("err: Username field is empty!")
			failure = true
		end
	end
	if not failure then
		return Values
	end
	return nil
end

o = s:option(ListValue, "wday", translate("Weekday"), translate("Day of the week to get events log report"))                        
o:value("0", translate("Sunday"))
o:value("1", translate("Monday"))
o:value("2", translate("Tuesday"))
o:value("3", translate("Wednesday"))
o:value("4", translate("Thursday"))
o:value("5", translate("Friday"))
o:value("6", translate("Saturday"))
o:depends("repeat", "week")                                                                                                             
function o.cfgvalue(...)
	local v = Value.cfgvalue(...)
		return v
end		

o = s:option(ListValue, "month", translate("Month"), translate("Month of the year to get events log report"))                              
o:value("1", translate("January"))                                                                                                             
o:value("2", translate("February"))                                                                                                             
o:value("3", translate("March"))                                                                                                        
o:value("4", translate("April"))                                                                                                             
o:value("5", translate("May"))                                                                                                        
o:value("6", translate("June"))                                                                                                             
o:value("7", translate("July"))                                                                                                             
o:value("8", translate("August"))                                                                                                             
o:value("9", translate("September"))                                                                                                             
o:value("10", translate("October"))                                                                                                           
o:value("11", translate("November"))                                                                                                           
o:value("12", translate("December"))
o:depends("repeat", "year") 
function o.cfgvalue(...) 
	local v = Value.cfgvalue(...)
		return v
end

o = s:option(ListValue, "day", translate("Month day"), translate("Day of the month to get events log report")) 
o:value("1", translate("1"))
o:value("2", translate("2"))
o:value("3", translate("3"))
o:value("4", translate("4"))
o:value("5", translate("5"))
o:value("6", translate("6"))                                                                                                             
o:value("7", translate("7"))
o:value("8", translate("8"))                                                                                                             
o:value("9", translate("9"))
o:value("10", translate("10"))                                                                                                             
o:value("11", translate("11"))
o:value("12", translate("12"))                                                                                                             
o:value("13", translate("13"))
o:value("14", translate("14"))                                                                                                             
o:value("15", translate("15"))
o:value("16", translate("16"))                                                                                                             
o:value("17", translate("17"))
o:value("18", translate("18"))                                                                                                             
o:value("19", translate("19"))
o:value("20", translate("20"))                                                                                                           
o:value("21", translate("21"))                                                                                                           
o:value("22", translate("22"))                                                                                                      
o:value("23", translate("23"))                                                                                                           
o:value("24", translate("24"))                                                                                                           
o:value("25", translate("25"))                                                                                                      
o:value("26", translate("26"))                                                                                                           
o:value("27", translate("27"))                                                                                                           
o:value("28", translate("28"))                                                                                              
o:value("29", translate("29")) 
o:value("30", translate("30"))
o:value("31", translate("31"))
o:depends("repeat", "month") 
o:depends("repeat", "year")
function o.cfgvalue(...)
	local v = Value.cfgvalue(...)
		return v
end

o = s:option(ListValue, "hour", translate("Hour"), translate("Hour of the day to get events log report"))                          
o:value("1", translate("1"))                                                                                                          
o:value("2", translate("2"))                                                                                                          
o:value("3", translate("3"))                                                                                                          
o:value("4", translate("4"))                                                                                                          
o:value("5", translate("5"))                                                                                                          
o:value("6", translate("6"))                                                                                                          
o:value("7", translate("7"))                                                                                                          
o:value("8", translate("8"))                                                                                                          
o:value("9", translate("9"))                                                                                                          
o:value("10", translate("10"))                                                                                                        
o:value("11", translate("11"))                                                                                                        
o:value("12", translate("12"))                                                                                                        
o:value("13", translate("13"))                                                                                                        
o:value("14", translate("14"))                                                                                                        
o:value("15", translate("15"))                                                                                                        
o:value("16", translate("16"))                                                                                                        
o:value("17", translate("17"))                                                                                                        
o:value("18", translate("18"))                                                                                                        
o:value("19", translate("19"))                                                                                                        
o:value("20", translate("20"))                                                                                                        
o:value("21", translate("21"))                                                                                                        
o:value("22", translate("22"))                                                                                                        
o:value("23", translate("23"))                                                                                                        
o:value("00", translate("24"))                                                                                                        
function o.cfgvalue(...)                                                                                                              
        local v = Value.cfgvalue(...)                                                                                                 
		return v                                                                                                              
end

return m
