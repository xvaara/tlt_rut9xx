--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: forwards.lua 8117 2011-12-20 03:14:54Z jow $
]]--

local ds = require "luci.dispatcher"
local ft = require "luci.tools.gps"

m = Map("gps", translate("GPS Geofencing"),	translate(""))

s = m:section(NamedSection, "geofencing", "geofencing", translate("Geofencing"))

o = s:option(Flag, "enabled", translate("Enable"), translate(""))

o = s:option(Value, "longitude", translate("Longitude (X)"), translate(""))
o.datatype = "float"
o.default = "0.000000"

o = s:option(Value, "latitude", translate("Latitude (Y)"), translate(""))
o.datatype = "float"
o.default = "0.000000"

o = s:option(Value, "radius", translate("Radius"), translate(""))
o.default = "200"
o.datatype = "range(1,999999)"

s = m:section(TypedSection, "geofencing", translate(""))
s.template  = "gps/imagesection"

return m
