--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2008-2011 Jo-Philipp Wich <xm@subsignal.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: system.lua 8122 2011-12-20 17:35:50Z jow $
]]--

module("luci.controller.admin.licences", package.seeall)

function index()
	entry({"admin", "system", "licences"}, alias("admin", "system", "licences","general_info"), _("Licences"), 7)
        entry({"admin", "system", "licences","general_info"}, template("admin_licences/general_info"), _("General Info"), 1).leaf = true
        entry({"admin", "system", "licences","gplv2"}, template("admin_licences/GPLv2"), _("GPLv2"), 2).leaf = true
        entry({"admin", "system", "licences","gplv3"}, template("admin_licences/GPLv3"), _("GPLv3"), 3).leaf = true
        entry({"admin", "system", "licences","lgplv2"}, template("admin_licences/LGPLv2-1"), _("LGPLv2.1"), 4).leaf = true
        entry({"admin", "system", "licences","mit"}, template("admin_licences/MIT"), _("MIT"), 5).leaf = true
        entry({"admin", "system", "licences","bsd-4"}, template("admin_licences/BSD"), _("BSD-4-Clause"), 6).leaf = true 
        entry({"admin", "system", "licences","bsd_like"}, template("admin_licences/BSD_like"), _("BSD"), 7).leaf = true
        entry({"admin", "system", "licences","isc"}, template("admin_licences/ISC"), _("ISC"), 8).leaf = true 
        entry({"admin", "system", "licences","aslv2"}, template("admin_licences/ASLv2"), _("ASLv2"), 9).leaf = true
        entry({"admin", "system", "licences","openssl"}, template("admin_licences/OpenSSL"), _("OpenSSL"), 10).leaf = true
        entry({"admin", "system", "licences","zlib"}, template("admin_licences/ZLIB"), _("ZLIB"), 11).leaf = true 
end
