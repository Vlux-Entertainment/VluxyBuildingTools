--!strict

local Harness = require("../Support/Harness")
local roblox = require("@lune/roblox")

local Settings = require("../../src/Pure/Settings")

local Vector3 = roblox.Vector3
local vec = Harness.Vec
local named = Harness.Named
local Paths = Harness.Load("src/Core/Builders/Paths")

local START = Vector3.new(0, 0, 0)
local FINISH = Vector3.new(20, 0, 0)

return {
	["a square wall corner grows the wall arriving and starts the other a half thickness late"] = function(expect)
		local strips = Paths.WallStrips(Settings.Defaults())
		local bend = Paths.Bend(FINISH, Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), strips, strips)

		expect.near(bend.finish.Wall, 0.5, 1e-6, "the arriving wall covers the corner square")
		expect.near(bend.start.Wall, 0.5, 1e-6, "the other starts past it")
	end,

	["a wall runs the whole path, as thick and tall as the panel says"] = function(expect)
		local specs = Paths.Path(Settings.Defaults(), START, FINISH, false)

		expect.equal(#specs, 1)
		expect.equal(specs[1].name, "Wall")
		expect.equal(vec(specs[1].size), "1,12,20")
		expect.equal(vec(specs[1].cf.Position), "10,6,0")
	end,

	["pillared walls put a pillar at each end and the wall between them"] = function(expect)
		local settings = Settings.Defaults()

		settings.PillaredWalls = true

		local specs = Paths.Path(settings, START, FINISH, false)

		expect.equal(#named(specs, "Pillar"), 2, "pillars")
		expect.equal(vec(named(specs, "Wall")[1].size), "1,12,18", "the wall stops at the pillars")
		expect.equal(#named(Paths.Path(settings, START, FINISH, false, false), "Pillar"), 1, "no start pillar")
	end,

	["a corridor has a floor under both walls, and a ceiling with the roof on"] = function(expect)
		local settings = Settings.Defaults()
		local specs = Paths.Path(settings, START, FINISH, true)
		local walls = named(specs, "CorridorWall")

		expect.equal(#specs, 3, "floor and two walls")
		expect.equal(vec(named(specs, "Floor")[1].size), "10,1,20", "the floor spans the width and both walls")
		expect.equal(#walls, 2)
		expect.equal(math.abs(walls[1].cf.Position.Z), 4.5, "walls stand outside the width")
		expect.equal(vec(walls[1].size), "1,12,20")

		settings.Roof = true

		expect.equal(#named(Paths.Path(settings, START, FINISH, true), "Ceiling"), 1, "ceiling")
	end,

	["a wall that turns a right angle starts half a thickness in, with no filler wedges"] = function(expect)
		local specs = Paths.Path(Settings.Defaults(), FINISH, Vector3.new(20, 0, 20), false, nil, Vector3.xAxis)

		expect.equal(#specs, 1)
		expect.equal(vec(specs[1].size), "1,12,19.5")
	end,

	["a wall that turns at 45 degrees gets wedges to close the corner"] = function(expect)
		local specs = Paths.Path(Settings.Defaults(), FINISH, Vector3.new(30, 0, 10), false, nil, Vector3.xAxis)
		local wedges = 0

		for _, spec in specs do
			if spec.class == "WedgePart" then
				wedges += 1
			end
		end

		expect.truthy(wedges > 0, "wedges at the bend")
	end,

	["a path shorter than the minimum builds nothing"] = function(expect)
		expect.equal(#Paths.Path(Settings.Defaults(), START, Vector3.new(0.01, 0, 0), true), 0)
	end,
}
