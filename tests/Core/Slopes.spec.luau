--!strict

local Harness = require("../Support/Harness")
local roblox = require("@lune/roblox")

local Settings = require("../../src/Pure/Settings")

local Vector3 = roblox.Vector3
local vec = Harness.Vec
local Slopes = Harness.Load("src/Core/Builders/Slopes")

local BOTTOM = Vector3.new(0, 0, 0)
local TOP = Vector3.new(0, 0, -9)

--[[
	@param specs { any }
	@return number -- the lowest point of any piece, from its corners; a wedge has no top front edge
]]
local function lowest(specs: { any }): number
	local low = math.huge

	for _, spec in specs do
		local h = spec.size / 2

		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					if spec.class ~= "WedgePart" or sy < 0 or sz > 0 then
						low = math.min(low, spec.cf:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)).Y)
					end
				end
			end
		end
	end

	return low
end

return {
	["a sloped underside keeps each step one rise tall over a slab under the inner corners"] = function(expect)
		local settings = Settings.Defaults()

		settings.StairUnder = "Slope"

		local specs = Slopes.Stairs(settings, BOTTOM, TOP, false)
		local steps, slab = Harness.Named(specs, "Step_6"), Harness.Named(specs, "StairSlab")

		expect.near(steps[1].size.Y, 1, nil, "the top step is only one rise tall")
		expect.near(steps[1].cf.Position.Y, 5.5, nil, "sitting between the fifth and sixth rise")
		expect.truthy(#slab > 0, "a slab under the steps")
		expect.truthy(lowest(specs) > -1e-3, "nothing goes below the ground")
		expect.near(Slopes.UnderDepth(settings, 9, 6), 1.5 * math.sqrt(81 + 36) / 9, 1e-9, "1.5 square to the slope")
	end,

	["an underside thicker than the stairs are tall keeps them solid"] = function(expect)
		local settings = Settings.Defaults()

		settings.StairUnder = "Slope"
		settings.StairUnderThickness = 20

		expect.equal(Slopes.UnderDepth(settings, 9, 6), nil)
		expect.near(Harness.Named(Slopes.Stairs(settings, BOTTOM, TOP, false), "Step_6")[1].size.Y, 6, nil)
	end,

	["stairs take one step per run length and rise evenly to the stair height"] = function(expect)
		local specs = Slopes.Stairs(Settings.Defaults(), BOTTOM, TOP, false)

		expect.equal(#specs, 6, "9 studs at a 1.5 run")
		expect.equal(specs[1].name, "Step_1")
		expect.near(specs[1].size.Y, 1, nil, "first step rise")
		expect.near(specs[6].size.Y, 6, nil, "the last step reaches the stair height")
		expect.near(specs[6].size.Z, 1.5, nil, "step run")
		expect.equal(vec(specs[1].cf.Position), "0,0.5,-0.75", "the first step starts at the first click")
	end,

	["a run that does not divide evenly shares the length between the steps"] = function(expect)
		local specs = Slopes.Stairs(Settings.Defaults(), BOTTOM, Vector3.new(0, 0, -10), false)

		expect.equal(#specs, 7)
		expect.near(specs[1].size.Z, 10 / 7)
	end,

	["a ramp is one wedge, and a landing adds a block at the top"] = function(expect)
		local settings = Settings.Defaults()

		settings.Landing = 4

		local specs = Slopes.Stairs(settings, BOTTOM, TOP, true)

		expect.equal(#specs, 2)
		expect.equal(specs[1].class, "WedgePart")
		expect.equal(vec(specs[1].size), "8,6,9")
		expect.equal(specs[2].name, "Landing")
		expect.equal(vec(specs[2].cf.Position), "0,3,-11")
	end,

	["stairs with no length build nothing"] = function(expect)
		expect.equal(#Slopes.Stairs(Settings.Defaults(), BOTTOM, BOTTOM, false), 0)
	end,

	["an arch has two posts and a curve, and none when the span is too wide"] = function(expect)
		local settings = Settings.Defaults()
		local specs = Slopes.Arch(settings, Vector3.new(-4, 0, 0), Vector3.new(4, 0, 0))
		local posts = Harness.Named(specs, "Arch_Post")

		expect.equal(#posts, 2)
		expect.near(posts[1].size.Y, 6, nil, "posts rise to the spring line")
		expect.truthy(#Harness.Named(specs, "Arch_Curve") >= settings.ArchSegments, "curve pieces")
		expect.equal(#Slopes.Arch(settings, Vector3.new(-12, 0, 0), Vector3.new(12, 0, 0)), 0, "too wide")
	end,
}
