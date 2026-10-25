--!strict

local Harness = require("../Support/Harness")
local roblox = require("@lune/roblox")

local Settings = require("../../src/Pure/Settings")

local Vector3 = roblox.Vector3
local named = Harness.Named
local Railings = Harness.Load("src/Core/Builders/Railings")

return {
	["on the flat, the bottom rail lies on the floor and the bars stand on it"] = function(expect)
		local specs = Railings.Railing(Settings.Defaults(), Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), true)
		local bottom = named(specs, "BottomRail")[1]
		local bar = named(specs, "Baluster")[1]

		expect.truthy(bottom, "a bottom rail")
		expect.near(bottom.cf.Position.Y - bottom.size.Y / 2, 0, 1e-6, "touching the floor")
		expect.near(bar.cf.Position.Y - bar.size.Y / 2, 0, 1e-6, "bars reach the floor")
	end,

	["on a slope there is no bottom rail, and the bars reach below the line"] = function(expect)
		local specs = Railings.Railing(Settings.Defaults(), Vector3.new(0, 0, 0), Vector3.new(12, 6, 0), true)

		expect.equal(#named(specs, "BottomRail"), 0)

		for _, bar in named(specs, "Baluster") do
			local along = bar.cf.Position.X / 12
			local line = 6 * along

			expect.truthy(bar.cf.Position.Y - bar.size.Y / 2 < line - 0.4, "the bar sinks into the steps")
		end
	end,
}
