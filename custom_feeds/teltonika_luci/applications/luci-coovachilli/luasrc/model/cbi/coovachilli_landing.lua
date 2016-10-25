--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2008 Jo-Philipp Wich <xm@leipzig.freifunk.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: coovachilli.lua 3442 2008-09-25 10:12:21Z jow $
]]--

local function cecho(string)
	luci.sys.call("logger  \"" .. string .. "\"")
end
		
local uci = require "luci.model.uci".cursor()
local nw = require "luci.model.network"
local fs = require "luci.fs"
local localusers = "/etc/chilli/localusers"
local theme_name
--local hotspot_section
-- local cursec = luci.dispatcher.context.requestpath
-- 
-- if #cursec < 5 then
-- 	uci:foreach("coovachilli", "general", function(s)
-- 		if not section then
-- 			section = s[".name"]
-- 		end
-- 	end)
-- else
-- 	section = cursec[#cursec - (#cursec - 5)]
-- end

m = Map("landingpage",	translate( "Wireless Hotspot Landing Settings" ), translate( "" ) )



nw.init(m.uci)

lps = m:section(NamedSection, "general", "general", translate("Landing Page Settings"), translate("") )
lpt = lps:option( Value, "title", translate("Page title"), translate("A string that will be seen as landing page title"))

theme = lps:option( ListValue, "theme", translate("Theme"), translate(""))
	theme.template = "chilli/theme_select"
	theme:value("theme1", "Theme 1")
	theme:value("theme2", "Theme 2")
	theme:value("theme3", "Theme 3")
	theme:value("theme4", "Theme 4")
	theme:value("custom", "Custom")

	theme.default="custom"
	theme.forcewrite = true

	function theme.write(self, section, value)
		local old_value = m.uci:get(self.config, section, self.option)

		if value ~= old_value then
			m:chain("coovachilli")
		end
		theme_name = value
		m.uci:set(self.config, section, self.option, value)
	end

custom_page = lps:option(FileUpload, "loginPage", translate("Upload login page"))
	custom_page:depends("theme", "custom")
	custom_page.size = "51200"
 	custom_page.sizetext = translate("Selected file is too large. Maximum allowed size is 50 KiB")
 	custom_page.sizetextempty = translate("Selected file is empty")

tmplDow = lps:option(Button, "_download")
tmplDow.title = translate("Login page file")
tmplDow.inputtitle = translate("Download")
tmplDow.inputstyle = "apply"
tmplDow.onclick = true

demo = lps:option(Button, "_button", "")
	demo.template="chilli/demo_preview"
	function demo.write() end

tos = m:section( TypedSection, "terms", translate("Terms Of Services"))
	tos.template="chilli/landing_page"
	tos.anonymous = true

--enb_tos = tos:option( Flag, "enabled", translate("Enable TOS"), translate("Enable Terms of Service"))

upload = tos:option(FileUpload, "path", translate("Upload terms of service"), translate("Upload your own terms of service"))
	upload.size = "20480"
	upload.sizetext = translate("Selected file is too large. Maximum allowed size is 20 KiB")
	upload.sizetextempty = translate("Selected file is empty")
	upload.forcewrite = true
	upload.maxWidth="150px"

tos_text = tos:option(Value, "text", translate("Text"))
	tos_text.forcewrite = true
	
tos_text_size = tos:option(Value, "text_size", translate("Text size"), translate(""))
	for i=2, 20, 2 do
		tos_text_size:value(i, i)
	end
	tos_text_size.default="12"
	tos_text_size.maxWidth="50px"

tos_text_color = tos:option(Value, "text_color", translate("Text color"), translate(""))
	tos_text_color:value("#205599", "Teltonika blue")
	tos_text_color:value("#404040", "Teltonika black")
	tos_text_color:value("black", "Black")
	tos_text_color:value("#fff", "White")
	tos_text_color.default="#404040"
	
warning = tos:option(Value, "warning", translate("Warning text"))
	warning.forcewrite = true

wrn_size = tos:option(Value, "wrn_size", translate("Warning size"), translate(""))
	for i=2, 20, 2 do
		wrn_size:value(i, i)
	end
	wrn_size.default="13"
	wrn_size.maxWidth="50px"

wrn_color = tos:option(Value, "wrn_color", translate("Warning color"), translate(""))
	wrn_color:value("#205599", "Teltonika blue")
	wrn_color:value("#404040", "Teltonika black")
	wrn_color:value("black", "Black")
	wrn_color:value("#fff", "White")
	wrn_color.default="#404040"

------------------------------------------------------------------------------------------------
function m.on_parse(self)
	if m:formvalue("cbid.landingpage.general._download") then
		luci.http.redirect(luci.dispatcher.build_url("admin/services/tmpldownload"))
	end
end

bg_img = m:section( TypedSection, "image", translate("Background Configuration"))
	bg_img.template="chilli/landing_page"
	bg_img.anonymous = true

enb_bg = bg_img:option(Flag, "enabled", translate("Enable"), translate("Enable landing page field"))

bg_image = bg_img:option(FileUpload, "path", translate("Background image"))
	bg_image.size = "51200"
	bg_image.sizetext = translate("Selected file is too large. Maximum allowed size is 50 KiB")
	bg_image.sizetextempty = translate("Selected file is empty")

repeat_opt = bg_img:option(ListValue, "rep", translate("Repeat options"))
	repeat_opt:value("repeat", "Repeat")
	repeat_opt:value("repeat-x", "Repeat horizontally")
	repeat_opt:value("repeat-y", "Repeat vertically")
	repeat_opt:value("no-repeat", "No repeat")

repeat_opt = bg_img:option(ListValue, "position", translate("Background position"))
	repeat_opt:value("center", "Center")
	repeat_opt:value("right", "Right")
	repeat_opt:value("left", "Left")
	repeat_opt:value("top", "Top")
	repeat_opt:value("bottom", "Bottom")
	repeat_opt:value("none", "None")

bg_color = bg_img:option(Value, "color", translate("Background color"))
	bg_color:value("#205599", "Teltonika blue")
	bg_color:value("#404040", "Teltonika black")
	bg_color:value("#FFFFFF", "White")
	bg_color:value("#000000", "Black")
	bg_color.default = "#FFFFFF"

-----------------------------------------------------------------------
	--Logo configuration--
-----------------------------------------------------------------------

logo_img = m:section( TypedSection, "logo", translate("Logo Image Configuration"))
	logo_img.template="chilli/landing_page"
	logo_img.anonymous = true

enb_logo = logo_img:option(Flag, "enabled", translate("Enable"), translate("Enable landing page field"))

logo_image = logo_img:option(FileUpload, "path", translate("Logo image"))
	logo_image.size = "51200"
	logo_image.sizetext = translate("Selected file is too large. Maximum allowed size is 50 KiB")
	logo_image.sizetextempty = translate("Selected file is empty")

height = logo_img:option(Value, "height", translate("Height"), translate(""))

width = logo_img:option(Value, "width", translate("Width"), translate(""))

-----------------------------------------------------------------------
	--Link configuration--
-----------------------------------------------------------------------

link = m:section( TypedSection, "link", translate("Link Configuration"))
	link.template="chilli/landing_page"
	link.anonymous = true
	
	function link.cfgsections(self)
		local mode = m.uci:get("coovachilli", "hotspot1", "mode")
		local sections = {}
		self.map.uci:foreach(self.map.config, self.sectiontype,
			function (section)
				if section[".name"] ~= "requested_web" or mode == "mac" then
					if self:checkscope(section[".name"]) then
						table.insert(sections, section[".name"])
					end
				end
			end)

		return sections
	end

link_name = link:option(DummyValue, "name", translate("Name"), translate(""))
	
enb_link = link:option(Flag, "enabled", translate("Enable"), translate("Enable landing page field"))
	enb_link.rmempty = false
	function enb_link.write(self, section, value)
		local old_value = m.uci:get(self.config, section, self.option) or ""
		local url = link_url:formvalue(section) or ""
		local old_url = m.uci:get(self.config, section, "url") or ""

		if old_url ~= url then
			m:chain("coovachilli")
		end

		if value and value ~= old_value then
			m:chain("coovachilli")
		end
		m.uci:set(self.config, section, self.option, value)
	end

link_text = link:option(Value, "text", translate("Link text"), translate(""))

link_url = link:option(Value, "url", translate("Link url"), translate(""))

link_size = link:option(Value, "size", translate("Text size"), translate(""))
	for i=1, 10 do
		link_size:value(i, i)
	end
	link_size.default="1"

link_color = link:option(Value, "color", translate("Text color"), translate(""))
	link_color:value("#205599", "Teltonika blue")
	link_color:value("#404040", "Teltonika black")
	link_color:value("#000000", "Black")
	link_color:value("#FFFFFF", "While")
	link_color.default="#FFFFFF"

-----------------------------------------------------------------------
	--Text configuration--
-----------------------------------------------------------------------

welcome = m:section( TypedSection, "page", translate("Text Configuration"))
	welcome.template="chilli/landing_page"
	welcome.anonymous = true
	
	function welcome.cfgsections(self)
		local mode = m.uci:get("coovachilli", "hotspot1", "mode")
		local sections = {}
		self.map.uci:foreach(self.map.config, self.sectiontype,
			function (section)
				if (section[".name"] ~= "data_limit" and section[".name"] ~= "time_limit" ) or mode == "mac" then
					if self:checkscope(section[".name"]) then
						table.insert(sections, section[".name"])
					end
				end
			end)

		return sections
	end

name = welcome:option(DummyValue, "name", translate("Name"), translate(""))

enb_field = welcome:option(Flag, "enabled", translate("Enable"), translate("Enable landing page field"))

page_title = welcome:option(Value, "title", translate("Title text"), translate(""))

title_size = welcome:option(Value, "title_size", translate("Title size"), translate(""))
	for i=2, 20, 2 do
		title_size:value(i, i)
	end
	title_size.maxWidth="50px"
	title_size.default="20"

title_color = welcome:option(Value, "title_color", translate("Title color"), translate(""))
	title_color:value("#205599", "Teltonika blue")
	title_color:value("#404040", "Teltonika black")
	title_color:value("#F5F5F5", "WhiteSmoke")
	title_color:value("#000000", "Black")
	title_color:value("#FFFFFF", "White")
	title_color.default="#205599"

link_text = welcome:option(Value, "text", translate("Text"), translate(""))

link_size = welcome:option(Value, "text_size", translate("Text size"), translate(""))
	for i=2, 20, 2 do
		link_size:value(i, i)
	end
	link_size.default="1"
	link_size.maxWidth="50px"

text_color = welcome:option(Value, "text_color", translate("Text color"), translate(""))
	text_color:value("#205599", "Teltonika blue")
	text_color:value("#404040", "Teltonika black")
	text_color:value("black", "Black")
	text_color:value("#fff", "White")
	text_color.default="#404040"
	
button = m:section( TypedSection, "button", translate("Button Configuration"))
	button.template="chilli/landing_page"
	button.anonymous = true
	
name = button:option(DummyValue, "name", translate("Name"), translate(""))

link_text = button:option(Value, "text", translate("Text"), translate(""))

link_size = button:option(Value, "text_size", translate("Text size"), translate(""))
	for i=2, 20, 2 do
		link_size:value(i, i)
	end
	link_size.default="1"

text_color = button:option(Value, "text_color", translate("Text color"), translate(""))
	text_color:value("#205599", "Teltonika blue")
	text_color:value("#404040", "Teltonika black")
	text_color:value("black", "Black")
	text_color:value("#fff", "White")
	text_color.default="#404040"
	
input = m:section( TypedSection, "input", translate("Input Configuration"))
	input.template="chilli/landing_page"
	input.anonymous = true
	
input_name = input:option(DummyValue, "name", translate("Name"), translate(""))

input_text = input:option(Value, "text", translate("Text"), translate(""))

input_size = input:option(Value, "text_size", translate("Text size"), translate(""))
	for i=2, 20, 2 do
		input_size:value(i, i)
	end
	input_size.default="1"

input_color = input:option(Value, "text_color", translate("Text color"), translate(""))
	input_color:value("#205599", "Teltonika blue")
	input_color:value("#404040", "Teltonika black")
	input_color:value("black", "Black")
	input_color:value("#fff", "White")
	input_color.default="#404040"

--section - uci config section
--option - uci config option
--property - css style property
--patern - patern to format css value

function get_and_make(config, section, option, property, patern)
	local value = m.uci:get(config, section, option)
	return make_rule(value, property, patern)
end

--value - css style value
--property - css style property
--patern - patern to format css value
function make_rule(value, property, patern)
	local result

	if value and value ~= "" and property then
		if patern then
			patern = "%s: " .. patern .. ";"
			result = string.format(patern, property, value)
		else
			result = string.format("%s: %s;", property, value)
		end

	end
	return result
end

--gender - selector (id, class or "")
--name - element name
--rules - rule or rules table
function make_style(gender, name, rules,mode)
	local style_file = "/www/luci-static/resources/loginpage.css"
	if gender and name and rules then
		if gender == "class" then
			gender = "."
		elseif gender == "id" then
			gender = "#"
		else
			gender = ""
		end
		local file = io.open(style_file, "a")
		file:write(gender..""..name.." {\n")
		if type(rules)=="table" then
			for i, rule in ipairs(rules) do
				if rule and rule ~= "" then
					file:write("\t" .. rule .."\n")
				end
			end
		else
			file:write("\t" .. rules)
		end
		file:write("}\n\n")
		file:close()
	end
end

function enabled(config, section)
	local value = m.uci:get(config, section, "enabled") or "0"

	if value == "1" then
		return true
	else
		return false
	end
end

function make_link(config, section, option, link)
	local command
	local source = m.uci:get(config, section, option)

	if source and source ~= "" then
		os.remove(link)
		luci.fs.link(source, link)
	else
		os.remove(link)
	end
end

function logger(string)
	os.execute("logger \"" ..string.. "\"")
end

function getParam(string)
	local h = io.popen(string)
	local t = h:read()
	h:close()
	return t
end


function m.on_commit(self)
	local config
	if theme_name and theme_name ~= "custom" then
		config = theme_name .. "_tmp"
		local command = string.format("cp /etc/chilli/www/themes/%s /etc/config/%s", theme_name, config)
		os.execute(command)
	else
		config = "landingpage"
	end

	os.remove("/www/luci-static/resources/loginpage.css")
	--body syle
	if enabled(config, "image") then
		local link = "/www/luci-static/resources/background"
		local path = m.uci:get(config, "image", "path")
		local rules = {
			get_and_make(config,"image", "rep", "background-repeat"),
			get_and_make(config,"image", "color", "background-color"),
			get_and_make(config,"image", "position", "background-position")
		}
		if path then
			table.insert(rules, make_rule("background?" .. os.time(), "background-image", "url(\"%s\")"))
		end
		make_link(config, "image", "path", link)
		make_style("", "body", rules)
	end

	--class logo style
	if enabled(config,"logo") then
		local link = "/www/luci-static/resources/logo_image"
		local path = m.uci:get(config, "logo", "path")
		local rules = {
			get_and_make(config,"logo", "height", "height"),
			get_and_make(config,"logo", "width", "width")
		}

		if path then
			table.insert(rules, make_rule("logo_image?" .. os.time(), "content", "url(\"%s\")"))
		end

		make_link(config, "logo", "path", link)
		make_style("id", "logo", rules)
	else
		make_style("id", "logo", "display: none;")
	end

	--class logo
	m.uci:foreach(config, "link", function(s)
		if s.enabled == "1" then
			local rules = {}
			table.insert(rules, make_rule(s.size, "font-size"))
			table.insert(rules, make_rule(s.color, "color"))
			make_style("class", s[".name"], rules)
		else
			make_style("class", s[".name"], "display: none;")
		end
	end)
	--class logo
	--if enabled(config,"terms") then
		local rules = {
			get_and_make(config, "terms", "wrn_size", "font-size"),
			get_and_make(config, "terms", "wrn_color", "color")
		}
		make_style("class", "terms_text", rules)
		rules = {
			get_and_make(config, "terms", "text_size", "font-size"),
			get_and_make(config, "terms", "text_color", "color")
		}
		make_style("class", "terms", rules)
	--end

	m.uci:foreach(config, "page", function(s)

		if s.enabled == "1" then
			local rules = {}
			table.insert(rules, make_rule(s.title_size, "font-size"))
			table.insert(rules, make_rule(s.title_color, "color"))
			make_style("class", s[".name"].."_title", rules)
			rules = {}
			table.insert(rules, make_rule(s.text_size, "font-size"))
			table.insert(rules, make_rule(s.text_color, "color"))
			make_style("class", s[".name"].."_text", rules)
		else
			make_style("clas", s[".name"] .. "_text", "display: none;")
			make_style("class", s[".name"] .. "_title", "display: none;")
		end
	end)
	
	--Button style
	m.uci:foreach(config, "button", function(s)
		local rules = {}
		table.insert(rules, make_rule(s.text_size, "font-size"))
		table.insert(rules, make_rule(s.text_color, "color"))
		make_style("class", s[".name"], rules)
	end)
	
	--Input fields style
	m.uci:foreach(config, "input", function(s)
		local rules = {}
		table.insert(rules, make_rule(s.text_size, "font-size"))
		table.insert(rules, make_rule(s.text_color, "color"))
		make_style("class", s[".name"], rules)
	end)

	if theme_name and theme_name ~= "custom" then
		os.remove("/etc/config/" .. config)
	end
end

return m
