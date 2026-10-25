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
		expect.truthy(bar.cf.Position.Y - bar.size.Y / 2 <= 0, "bars reach the floor")
	end,

	["on stairs the bottom rail is a board over the step edges, reaching into the steps"] = function(expect)
		local specs = Railings.Railing(Settings.Defaults(), Vector3.new(0, 0, 0), Vector3.new(12, 6, 0), true)
		local board = named(specs, "BottomRail")[1]

		expect.truthy(board, "a board along the stairs")
		expect.near(
			board.cf.Position.Y + board.size.Y / 2,
			3.2,
			1e-6,
			"its top is as high over the step edges as the flat rail is over the floor"
		)
		expect.truthy(board.size.Y > 0.9, "tall enough to cover the steps")

		for _, bar in named(specs, "Baluster") do
			local line = 6 * bar.cf.Position.X / 12
			local foot = bar.cf.Position.Y - bar.size.Y / 2

			expect.near(foot, line + 0.15, 1e-6, "the bars stand on the board")
		end
	end,
}
