--!strict

local PropData = require("../../src/Pure/PropData")

return {
	["every prop sits in a known category and has parts"] = function(expect)
		local known: { [string]: boolean } = {}

		for _, category in PropData.Categories do
			known[category.Id] = true
		end

		for _, prop in PropData.Props do
			expect.truthy(known[prop.Category])
			expect.truthy(#prop.Parts > 0)
			expect.truthy(prop.Mount == "floor" or prop.Mount == "wall" or prop.Mount == "ceiling")
		end
	end,

	["ids are unique and every category has props"] = function(expect)
		local seen: { [string]: boolean } = {}

		for _, prop in PropData.Props do
			expect.falsy(seen[prop.Id])
			seen[prop.Id] = true
		end

		for _, category in PropData.Categories do
			expect.truthy(#PropData.InCategory(category.Id) > 0)
		end
	end,

	["every shape has a positive size and rests on the floor, or hangs below the ceiling"] = function(expect)
		for _, prop in PropData.Props do
			for _, part in prop.Parts do
				expect.truthy(part.sx > 0 and part.sy > 0 and part.sz > 0)
				if part.lamp or part.lights then
					expect.truthy(part.sx > 0)
				elseif prop.Mount == "ceiling" then
					expect.truthy(part.y + part.sy / 2 <= 0.001)
				else
					expect.truthy(part.y - part.sy / 2 >= -0.001)
				end
			end
		end
	end,

	["Find returns a prop by id"] = function(expect)
		expect.equal((PropData.Find("Toilet") :: PropData.Prop).Label, "Toilet")
		expect.falsy(PropData.Find("Nope"))
	end,
}
