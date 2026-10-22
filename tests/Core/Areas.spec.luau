--!strict

local Harness = require("../Support/Harness")
local roblox = require("@lune/roblox")

local Settings = require("../../src/Pure/Settings")

local Vector3 = roblox.Vector3
local vec = Harness.Vec
local named = Harness.Named
local Areas = Harness.Load("src/Core/Builders/Areas")

local A = Vector3.new(0, 0, 0)
local B = Vector3.new(20, 0, 16)

return {
	["a room is a floor and four walls, and a ceiling when the roof is on"] = function(expect)
		local settings = Settings.Defaults()
		local open = Areas.Room(settings, A, B)

		expect.equal(#open, 5, "parts without a roof")
		expect.equal(#named(open, "Ceiling"), 0, "no ceiling")

		settings.Roof = true

		local closed = Areas.Room(settings, A, B)

		expect.equal(#closed, 6, "parts with a roof")
		expect.equal(vec(named(closed, "Ceiling")[1].cf.Position), "10,12.5,8", "the ceiling sits on the walls")
	end,

	["room walls span the footprint and the side walls fit between them"] = function(expect)
		local specs = Areas.Room(Settings.Defaults(), A, B)
		local floor = named(specs, "Floor")[1]
		local north = named(specs, "Wall_North")[1]
		local west = named(specs, "Wall_West")[1]

		expect.equal(vec(floor.size), "20,1,16", "floor size")
		expect.equal(vec(floor.cf.Position), "10,-0.5,8", "the floor's top is at the clicked level")
		expect.equal(vec(north.size), "20,12,1", "north wall size")
		expect.equal(vec(north.cf.Position), "10,6,0.5", "north wall inside the footprint")
		expect.equal(vec(west.size), "1,12,14", "west wall stops at the north and south walls")
	end,

	["a room too narrow for two walls builds nothing"] = function(expect)
		expect.equal(#Areas.Room(Settings.Defaults(), A, Vector3.new(2, 0, 16)), 0)
	end,

	["a floor is one slab whose top is at the clicked level, either corner first"] = function(expect)
		local specs = Areas.Floor(Settings.Defaults(), B, A)

		expect.equal(#specs, 1)
		expect.equal(vec(specs[1].size), "20,1,16")
		expect.equal(vec(specs[1].cf.Position), "10,-0.5,8")
		expect.equal(#Areas.Floor(Settings.Defaults(), A, Vector3.new(20, 0, 0)), 0, "a line makes no floor")
	end,

	["a foundation is wider by the margin on every side and stands on the clicked level"] = function(expect)
		local specs = Areas.Foundation(Settings.Defaults(), A, B)

		expect.equal(#specs, 1)
		expect.equal(vec(specs[1].size), "22,2,18")
		expect.equal(vec(specs[1].cf.Position), "10,1,8")
	end,

	["a pillar is the panel width and height, standing on its base"] = function(expect)
		local specs = Areas.Pillar(Settings.Defaults(), Vector3.new(4, 2, 4))

		expect.equal(vec(specs[1].size), "2,12,2")
		expect.equal(vec(specs[1].cf.Position), "4,8,4")
	end,
}
