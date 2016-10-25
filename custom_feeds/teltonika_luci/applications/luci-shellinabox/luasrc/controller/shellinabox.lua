module("luci.controller.shellinabox", package.seeall)
local uci = require("luci.model.uci").cursor()
local sys = require "luci.sys"


function index()
	entry({"admin", "services", "cli"}, template("shellinabox/cli"), _("CLI"), 90)
end

