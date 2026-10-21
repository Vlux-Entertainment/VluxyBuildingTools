--!strict

local Keymap = require("../../src/Pure/Keymap")
local Tools = require("../../src/Pure/Tools")

return {
	["every number-key badge matches the keymap"] = function(expect)
		for _, tool in Tools.List do
			if tool.Key then
				local names = { "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" }
				local name = if tool.Key == "0" then "Zero" else names[tonumber(tool.Key) :: number]

				expect.equal(Keymap.Resolve(name, false, false, false, false), `Tool:{tool.Id}`, tool.Id)
			end
		end
	end,

	["tool ids are unique and findable"] = function(expect)
		local seen: { [string]: boolean } = {}

		for _, tool in Tools.List do
			expect.falsy(seen[tool.Id], tool.Id)
			seen[tool.Id] = true
			expect.truthy(Tools.Find(tool.Id))
		end

		expect.falsy(Tools.Find("Nope"))
	end,
}
