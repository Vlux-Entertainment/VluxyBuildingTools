--!strict

local Cycle = require("../../src/Pure/Cycle")
local PropData = require("../../src/Pure/PropData")

return {
	["step wraps both ways"] = function(expect)
		expect.equal(Cycle.Step(3, 1, 3), 1)
		expect.equal(Cycle.Step(1, -1, 3), 3)
		expect.equal(Cycle.Step(2, 1, 3), 3)
	end,

	["next starts at the first going forward and the last going back"] = function(expect)
		local list = { "a", "b", "c" }

		expect.equal(Cycle.Next(list, nil, 1), "a")
		expect.equal(Cycle.Next(list, nil, -1), "c")
		expect.equal(Cycle.Next(list, "c", 1), "a")
		expect.equal(Cycle.Next(list, "zzz", 1), "a")
		expect.falsy(Cycle.Next({}, nil, 1))
	end,

	["the All section shows every prop and the first section is All"] = function(expect)
		expect.equal(PropData.Sections[1].Id, "All")
		expect.equal(#PropData.Shown("All"), #PropData.Props)

		for _, category in PropData.Categories do
			for _, prop in PropData.Shown(category.Id) do
				expect.equal(prop.Category, category.Id)
			end
		end
	end,
}
