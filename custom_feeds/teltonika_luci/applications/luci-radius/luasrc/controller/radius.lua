--[[
LuCI - Lua Configuration Interface

Copyright 2015 Teltonika

]]--

module("luci.controller.radius", package.seeall)

function index()

entry({"admin", "services", "hotspot", "radius"}, cbi("radius/radius"),_("Radius Server"), 4)
entry({"admin", "services", "hotspot", "radius", "user"}, arcombine(cbi("radius/radius"), cbi("radius/users_edit"))).leaf = true
entry({"admin", "services", "hotspot", "radius", "session"}, arcombine(cbi("radius/radius"), cbi("radius/session_edit"))).leaf = true

end
