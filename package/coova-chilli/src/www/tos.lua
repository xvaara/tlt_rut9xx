#!/usr/bin/lua

require("uci")

local uci = uci.cursor()
local fs = require "luci.fs"
local path = uci:get("landingpage", "terms", "path") or ""
local text = luci.fs.readfile(path) or ""
-- HTTP header
print [[
Content-Type: text/html;
]]

print [[
<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
	<meta charset="utf-8">
	<meta http-equiv="Cache-control" content="no-cache">
	<meta http-equiv="Pragma" content="no-cache">
</head>
<body>
<textarea style='height:100%; width:100%;'rows='10' maxlength='10000'>]]

print(text)

print [[
	</textarea>
</body>
</html>
]]