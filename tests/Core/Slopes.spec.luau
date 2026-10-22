--!strict

local Harness = require("../Support/Harness")
local roblox = require("@lune/roblox")

local Settings = require("../../src/Pure/Settings")

local Vector3 = roblox.Vector3
local vec = Harness.Vec
local Slopes = Harness.Load("src/Core/Builders/Slopes")

local BOTTOM = Vector3.new(0, 0, 0)
local TOP = Vector3.new(0, 0, -9)

return {
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
