#!/usr/bin/lua

require "landing_page_functions"

local config = "coovachilli"
local page_config = "landingpage"
local uamsecret = "uamsecret"
local loginpath = "/cgi-bin/hotspotlogin.cgi"
--Debug variable must be global
debug_enable = 0
local userpassword
local post_length = tonumber(os.getenv("CONTENT_LENGTH")) or 0
local params = {}

if os.getenv ("REQUEST_METHOD") == "POST" and post_length > 0 then
	debug("Request method post, reading stdin")
	POST_DATA = io.read (post_length)  -- read stdin
	if POST_DATA then
		debug("Parsing data")
		params = parse(POST_DATA)
	else
		debug("Cant get form data")
	end

elseif os.getenv ("REQUEST_METHOD") == "GET" then
	debug("Request method get")
	if os.getenv("QUERY_STRING") then
		query = os.getenv("QUERY_STRING")
	end

	if query then
		debug("Parsing data")
		params = parse(query)
	else
		debug("Can't get query string")
	end
end

--query and form values

local button = params['button'] or ""
local send = params['send'] or ""
local tel_num = params['TelNum'] or ""
local res = params['res'] or ""
local reason = params['reason']
local sms = params['sms'] or ""
local username = params['UserName'] or ""
local reply = params['reply'] or ""
reply = url_decode(reply)
local password = params['Password'] or ""
password = url_decode(password)
local uamip = params['uamip'] or ""
local uamport = params['uamport'] or ""
local userurl = params['userurl'] or ""
local userurldecode = url_decode(userurl)
local challenge = params['challenge'] or ""
local redirurl = params['redirurl']
local redirurldecode = url_decode(redirurl)
local tos = params['agree_tos'] or "0"
local mac = params['mac']

local hotspot_section = get_hotspot_section(config, uamip) or "hotspot1"
local hotspot_number = string.match(hotspot_section, "%d+") or "1"
local session_section = "unlimited" .. hotspot_number
local ssid = get_wifi_ssid(hotspot_section) or ""
local is_restricted = uci:get("hotspot_scheduler", ssid, "restricted") or 0 --the restriction flag
local mac_pass = uci:get(config, hotspot_section, "mac_pass_enb") or "0"
local auth_mode = uci:get(config, hotspot_section, "mode")
local page_title = uci:get("landingpage", "general", "title") or ""
local tos_enabled = uci:get(config, hotspot_section, "tos_enb") or "0" --get_values("terms", "enabled") or "0"
local path = uci:get("landingpage", "general", "loginPage") or "/etc/chilli/www/hotspotlogin.tmpl"
local page
local reached = false
local tos_accepted = true
local replace_tags = {
	pageTitle = page_title
}

if auth_mode == "sms" or auth_mode == "mac" then
	reached = check_limit(uamip, mac, session_section, config)
end

if tos_enabled == "1" then
 	if button and button ~= "" and tos ~= "1" then
		debug("Terms of servise not aceepted")
		tos_accepted = false
 		button = ""
 		res = "failed"
 	end
end

if auth_mode == "extrad" or auth_mode == "intrad" then
	debug("Radius authentication")
	userpassword = 1
end


if (button and button ~= "") or res == "wispr" and username ~= "" then
	print("Content-type: text/html\n\n")
	hexchal = fromhex(challenge)

	if uamsecret then
		debug("Uamsecret \""..uamsecret.."\" defined")
		newchal  = md5.sum(hexchal..""..uamsecret)
 	else
		debug("Uamsecret not defined")
 		newchal  = hexchal
 	end

 	if ntresponse == 1 then
		debug("Encoding plain text into NT-Password ")
		--Encode plain text into NT-Password
		--response = chilli_response -nt "$challenge" "$uamsecret" "$username" "$password"
		logonUrl = "http://"..uamip..":"..uamport.."/logon?username="..username.."&ntresponse="..response
 	elseif userpassword == 1 then
		debug("Encoding plain text password with challenge")
		--Encode plain text password with challenge
		--(which may or may not be uamsecret encoded)

		--If challange isn't long enough, repeat it until it is
		while string.len(newchal) < string.len(password) do
			newchal = newchal..""..newchal
		end
		local result = ""
		local index = 1

		while index <= string.len(password) do
			result = result .. char(bit.bxor(string.byte(password, index), string.byte(newchal, index)))
			index = index + 1
		end

		pappassword = tohex(result)
		logonUrl = "http://"..uamip..":"..uamport.."/logon?username="..username.."&password="..pappassword

	else
		debug("Generating a CHAP response with the password and the")
		--Generate a CHAP response with the password and the
		--challenge (which may have been uamsecret encoded)
		response = md5.sumhexa("\0"..password..""..newchal)
		logonUrl = "http://"..uamip..":"..uamport.."/logon?username="..username.."&response="..response.."&userurl="..userurl
	end

	print ([[<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
	<html>
		<head>
			<title>]] .. page_title.. [[ Login</title>
			<link rel="stylesheet" href="/luci-static/resources/loginpage.css">
			<meta http-equiv="Cache-control" content="no-cache">
			<meta http-equiv="Pragma" content="no-cache">
			<meta http-equiv='refresh' content="0;url=']] .. logonUrl .. [['>
		</head>
	<body >
		<div style="width:100%;height:100%;margin:auto;">
			<div style="text-align: center;position: absolute;top: 50%;left: 50%;height: 30%;width: 50%;margin: -15% 0 0 -25%;">
				<div style="width: 280px;margin: auto;">
					<small><img src="../luci-static/teltonikaExp/wait.gif"/> logging...</small>
				</div>
			</div>
		</div>
	</body>
	<!--
	<?xml version="1.0" encoding="UTF-8"?>
	<WISPAccessGatewayParam
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xsi:noNamespaceSchemaLocation="http://www.acmewisp.com/WISPAccessGatewayParam.xsd">
	<AuthenticationReply>
	<MessageType>120</MessageType>
	<ResponseCode>201</ResponseCode>
	<LoginResultsURL>]]..logonUrl..[[</LoginResultsURL>
	</AuthenticationReply>
	</WISPAccessGatewayParam>
	-->
	</html>
	]])
os.exit(0)
end

if send and send ~= "" and tel_num then
	local ifname = get_ifname(uamip)
	local pass = getParam("/usr/bin/pwgen -nc 10 1")
	tel_num = tel_num:gsub("%%2B", "+")
	local exists = getParam("grep \"" ..tel_num.. "\" /etc/chilli/" .. ifname .. "/smsusers")
	local user = string.format("%s", pass)
	local uri = os.getenv("REQUEST_URI")
	local message = string.format("%s Password - %s  \n Link - http://%s%s?challenge=%s&uamport=%s&uamip=%s&userurl=%s&UserName=%s&button=1", tel_num, pass, uamip, uri, challenge, uamport, uamip, userurl, pass)

	message = getParam(string.format("/usr/sbin/gsmctl -Ss \"%s\"", message))

	if message == "OK" then
		sms = "sent"

		if exists then
			os.execute("sed -i 's/" ..exists.. "/" ..user.. "/g' /etc/chilli/" .. ifname .. "/smsusers")
		else
			os.execute("echo \"" ..user.. "\" >>/etc/chilli/" .. ifname .. "/smsusers")
		end
	else
		res = "notyet"
		sms = "error"
	end
end

--Default: It was not a form request
local result = check_result(res)
--Otherwise it was not a form request
--Send out an error message
if result == 0 then
	section = "warning"
--If login successful, not logged in yet, requested a success pop up window
elseif result == 1 or result == 4 or result == 12 then
	local web_page = uci:get(config, hotspot_section, "web_page")
	section = "success"
	link_tag = [[<a href='http://]] .. uamip .. [[:]] .. uamport .. [[/logoff'>]]
	replace_tags.loginLogout = make_link(page_config, "logout_link", link_tag)
	replace_tags.loginLogoutClass = "logout_link"

	if userurldecode and userurldecode ~= "" then
		if web_page == "link" then
			link_tag = [[<a href=']] .. userurldecode .. [['> ]]
			replace_tags.requestedWeb = [[<br>]] .. make_link(page_config, "requested_web", link_tag)
		elseif web_page == "auto" then
			local uamlogoutip = uci:get(config, session_section, "uamlogoutip")
			local its_logout = find(userurldecode, uamlogoutip)

			if not its_logout then
				print("Content-type: text/html\n\n")
				print([[<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
					<html>
						<head>
							<meta http-equiv='refresh' content="0;url=]] .. userurldecode .. [[">
						</head>
						<body >
						</body>
					</html>]])
				os.exit(0)
			end
		end
	end
--If logout successful, logout pop up window
elseif result == 3 or result == 13 then
	section = "logout"
	link_tag = [[<a href='http://]].. uamip .. [[:]] .. uamport .. [[/prelogin'>]]
	replace_tags.loginLogout = make_link(page_config, "login_link", link_tag)
	replace_tags.loginLogoutClass = "login_link"
--If logout successful, not logged in yet
elseif result == 2 or result == 5 then
	replace_tags.formHeader = [[<form name="myForm" method="post" action="]] .. loginpath .. [[">
			<INPUT TYPE="hidden" NAME="challenge" VALUE="]] .. challenge .. [[">
			<INPUT TYPE="hidden" NAME="uamip" VALUE="]] .. uamip .. [[">
			<INPUT TYPE="hidden" NAME="uamport" VALUE="]] .. uamport .. [[">
			<INPUT TYPE="hidden" NAME="userurl" VALUE="]] ..userurldecode .. [[">
			<INPUT TYPE="hidden" NAME="res" VALUE="]] .. res .. [[">]]
	replace_tags.formFooter = [[</form>]]

	debug("authmode:" ..auth_mode)
	if auth_mode == "sms" and result ~= 2 then
		section = "password"

		if sms == "notsent" then
			section = "phone"
		elseif sms == "error" then
			section = "error"
		end
	elseif result == 2 then
		section = "failed"
		debug("tos_enabled " .. tos_enabled)
		if tos_enabled == "1" and not tos_accepted and not reason then
			debug("tos error")
			section = "terms"
			replace_tags.statusTitle = get_values(page_config, "welcome", "title")
			replace_tags.statusContent = get_values(page_config, section, "warning")
		end

		if reason then
			debug("reason " .. reason)
			if reason == "blocked" then
				section = "data_limit"
				local display_data_limit = get_values(page_config, section, "enabled")

				if display_data_limit then
					replace_tags.statusContent = get_values(page_config, section, "text")
				end
			elseif reason == "timeout" then
				section = "time_limit"
				local display_time_limit = get_values(page_config, section, "enabled")

				if display_time_limit then
					replace_tags.statusContent = get_values(page_config, section, "text")
				end
			end
		end
	elseif result == 5 then
		section = "welcome"
	end

	if auth_mode == "sms" then
		replace_tags.inputUsername = [[<input type="hidden" name="UserName" value="-">]]

		if sms == "notsent" or sms == "error" then
			if not reached then
				local label = get_values(page_config, "tel_number", "text") or ""
				replace_tags.inputPassword = [[<label class="cbi-value-tel tel_number">]] .. label .. [[</label><input id="focus_password" class="cbi-input-password" type="text" name="TelNum" pattern="[0-9+]{4,20}">]]
			end
		else
			local label = get_values(page_config, "pass", "text") or ""
			replace_tags.inputPassword = [[<label class="cbi-value-password pass">]] .. label .. [[</label><input id="focus_password" class="cbi-input-password" type="text" name="UserName">]]
		end
	elseif auth_mode == "mac" then
		if mac_pass == "1" and not reached then
			local label = get_values(page_config, "pass", "text") or ""
			replace_tags.inputPassword = [[<label class="cbi-value-password pass">]] .. label .. [[</label><input id="focus_password" class="cbi-input-password" type="password" name="Password">]]
		else
			replace_tags.loginClass = "hidden_box"
			replace_tags.statusContent = ""
			replace_tags.inputPassword = [[<input id="focus_password" class="cbi-input-password" type="password" name="Password" value="-">]]
		end
	else
		local u_label = get_values(page_config, "username", "text") or ""
		local p_label = get_values(page_config, "pass", "text") or ""
		replace_tags.inputUsername = [[<label class="cbi-value-title1 username">]] .. u_label .. [[</label><input class="cbi-input-user" type="text" name="UserName">]]
		replace_tags.inputPassword = [[<label class="cbi-value-password pass">]] .. p_label .. [[</label><input id="focus_password" class="cbi-input-password" type="password" name="Password">]]
	end

	if tos_enabled == "1" and not reached then --add terms of service
		if (auth_mode == "sms" and (sms ~= "notsent" and sms ~= "error")) or (auth_mode ~= "sms")then
			local link_tag = [[<a href="tos.lua" target="_blank" "style="text-decoration: underline;">]]
			local terms_link = make_link(page_config, "terms", link_tag)

			replace_tags.inputTos = [[
				<input type="checkbox" name="agree_tos" value="1"> ]] .. terms_link

			if (auth_mode == "mac" and mac_pass ~= "1") or auth_mode == "sms" then
				replace_tags.statusContent = get_values(page_config, "terms", "warning")
			end
		end


	end

	if is_restricted == "1" then
		replace_tags.submitButton = [[Access restricted!]]
	else
		if not reached then
			if auth_mode == "sms" and (sms == "notsent" or sms == "error") then
				local value = get_values(page_config, "send", "text")
				replace_tags.submitButton = [[<input type="submit" value="]] .. value .. [[" class="cbi-button cbi-button-apply3 send" name="send">]]
			else
				local value = get_values(page_config, "login", "text")
				replace_tags.submitButton = [[<input type="submit" value="]] .. value .. [[" class="cbi-button cbi-button-apply3 login" name="button">]]
			end
		end
	end
end

if get_values(page_config, "link", "enabled") == "1" then --add link
	link_tag = [[<a id="link" href="http://]]  .. get_values(page_config, "link", "url") .. [[">]]
	replace_tags.link = make_link(page_config, "link", link_tag)
end

if not reached then
	replace_tags.statusContent = replace_tags.statusContent or get_values(page_config, section, "text")
else
	left = count_date(hotspot_section, config)

	if reached == 1 or reached == 2 then
		section = "data_limit"
		local display_data_limit = get_values(page_config, section, "text") or ""
		replace_tags.statusContent = display_data_limit
		replace_tags.dateUse = make_date(page_config, "limit_expiration", left.date)
	elseif reached == 3 then
		section = "time_limit"
		local display_time_limit = get_values(page_config, section, "text") or ""
		replace_tags.statusContent = display_time_limit
		replace_tags.dateUse = make_date(page_config, "limit_expiration", left.date)
	end
	debug("replace_tags.statusContent " .. replace_tags.statusContent)
end

replace_tags.statusTitle = replace_tags.statusTitle or get_values(page_config, section, "title")
replace_tags.statusTitleId = section .. "_title"
replace_tags.statusContentClass = section .. "_text"

if path then
	local file = assert(io.open(path, "r"))
	template = file:read("*all")
	file:close()
	page = replace(template, replace_tags)
end

-- HTTP header
print [[
Content-Type: text/html
]]
--Print all page
print(page)
