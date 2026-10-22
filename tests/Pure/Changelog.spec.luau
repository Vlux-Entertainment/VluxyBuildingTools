--!strict

local Changelog = require("../../src/Pure/Changelog")
local PluginInfo = require("../../src/Pure/PluginInfo")

return {
	["the newest entry is the version the plugin reports"] = function(expect)
		expect.equal(Changelog[1].Version, PluginInfo.Version)
	end,

	["every release has a date and at least one change"] = function(expect)
		for _, release in Changelog do
			expect.truthy(string.match(release.Date, "^%d%d%d%d%-%d%d%-%d%d$"), release.Version)
			expect.truthy(#release.Changes > 0, release.Version)
		end
	end,

	["versions are unique"] = function(expect)
		local seen = {}

		for _, release in Changelog do
			expect.falsy(seen[release.Version], release.Version)
			seen[release.Version] = true
		end
	end,
}
