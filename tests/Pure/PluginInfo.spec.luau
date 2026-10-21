--!strict

local PluginInfo = require("../../src/Pure/PluginInfo")

return {
	["names the plugin"] = function(expect)
		expect.equal(PluginInfo.Name, "VluxyBuildingTools")
	end,
}
