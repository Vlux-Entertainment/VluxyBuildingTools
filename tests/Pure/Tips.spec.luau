--!strict

local Tips = require("../../src/Pure/Tips")
local Tools = require("../../src/Pure/Tools")

return {
	["every tip has text"] = function(expect)
		for name, tip in Tips.Entries do
			expect.truthy(#tip.Text > 0, name)
		end
	end,

	["every tool has a description"] = function(expect)
		for _, tool in Tools.List do
			expect.truthy(#tool.Description > 0, tool.Id)
		end
	end,

	["finds a tip by label"] = function(expect)
		expect.equal((Tips.Find("Themes") :: Tips.Tip).Key, "P")
		expect.falsy(Tips.Find("No such control"))
	end,
}
