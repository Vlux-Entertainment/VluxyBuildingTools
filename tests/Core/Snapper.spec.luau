--!strict

local Harness = require("../Support/Harness")
local roblox = require("@lune/roblox")

local Settings = require("../../src/Pure/Settings")

local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local vec = Harness.Vec

local DOOR = { Width = 4, Height = 7.75, Sill = 0, Panel = true, Frame = true }

--[[
	Cuts a framed door into a 20 x 12 x 1 wall at the origin and builds it.

	@return any -- the context
	@return any -- its Snapper module
]]
local function doorway(): (any, any)
	local context = Harness.new()
	local Geometry = context:Require("src/Core/Geometry")
	local Openings = context:Require("src/Core/Builders/Openings")
	local wall = Harness.Part(Vector3.new(20, 12, 1), CFrame.new(0, 6, 0), context.Workspace)
	local specs = Openings.Opening(Settings.Defaults(), DOOR, Harness.Hit(wall, Vector3.new(0, 3, 0.5)), "Rect")

	wall.Parent = nil
	Harness.SyncPositions(Geometry.Materialize(specs, "Door"))

	return context, context:Require("src/Core/Snapper")
end

return {
	["Doorway finds a built door and points out of the side the cursor is on"] = function(expect)
		local _, Snapper = doorway()
		local front = Snapper.Doorway(Vector3.new(1, 0, 3), 4)
		local back = Snapper.Doorway(Vector3.new(1, 0, -3), 4)

		expect.truthy(front, "a doorway in front")
		expect.near(front.width, 4.5, nil, "the hole is the door plus its frame")
		expect.near(front.height, 8, nil, "up to the header")
		expect.equal(vec(front.point), "0,0,0.5", "on the front face, at the floor")
		expect.equal(vec(front.normal), "0,0,1")
		expect.equal(vec(back.normal), "0,0,-1", "the other side points the other way")
	end,

	["Doorway finds nothing far from a door"] = function(expect)
		local _, Snapper = doorway()

		expect.equal(Snapper.Doorway(Vector3.new(40, 0, 3), 4), nil)
	end,

	["vent ends follow the vent when it is moved and turned"] = function(expect)
		local Snapper = Harness.Load("src/Core/Snapper")
		local model = roblox.Instance.new("Model")
		local built = CFrame.new(5, 2, 0)
		local ends = {
			Start = Vector3.new(0, 2, 0),
			StartDir = Vector3.new(-1, 0, 0),
			End = Vector3.new(10, 2, 0),
			EndDir = Vector3.new(1, 0, 0),
		}

		Snapper.RememberVentEnds(model, ends, built)

		local get = function(name)
			return model:GetAttribute(name)
		end
		local turned = CFrame.new(20, 2, 20) * CFrame.Angles(0, math.rad(90), 0)
		local read = Snapper.ReadVentEnds(get, turned)

		expect.equal(vec(read.Start), "20,2,25", "the first end turned with the vent")
		expect.equal(vec(read.End), "20,2,15", "and the other end too")
		expect.equal(vec(read.StartDir), "0,0,1")
		expect.equal(vec(read.EndDir), "0,0,-1")
		expect.equal(vec(Snapper.ReadVentEnds(get, built).End), "10,2,0", "unmoved, they are where they were built")
	end,

	["a vent from before relative ends reads its world ends"] = function(expect)
		local Snapper = Harness.Load("src/Core/Snapper")
		local old: { [string]: any } = {
			VluxyBT_VentStart = Vector3.new(0, 2, 0),
			VluxyBT_VentStartDir = Vector3.new(-1, 0, 0),
			VluxyBT_VentEnd = Vector3.new(10, 2, 0),
			VluxyBT_VentEndDir = Vector3.new(1, 0, 0),
		}
		local read = Snapper.ReadVentEnds(function(name)
			return old[name]
		end, CFrame.new(99, 0, 0))

		expect.equal(vec(read.Start), "0,2,0")
		expect.equal(vec(read.End), "10,2,0")
	end,

	["either opening of a vent is found by aiming into it, from any side"] = function(expect)
		local Snapper = Harness.Load("src/Core/Snapper")
		local openings = {
			{ At = Vector3.new(0, 2, 0), Dir = Vector3.new(-1, 0, 0) },
			{ At = Vector3.new(10, 2, 0), Dir = Vector3.new(1, 0, 0) },
		}
		local function aim(from: any, at: any, limit: number?): number?
			return Snapper.AimedOpening(from, at - from, openings, 4, limit)
		end

		expect.equal(aim(Vector3.new(-8, 5, 3), Vector3.new(0, 2.5, 0.5)), 1, "the first end, aimed at from outside")
		expect.equal(aim(Vector3.new(18, 6, -4), Vector3.new(10, 1.5, 0)), 2, "the other end, from the other side")
		expect.equal(
			aim(Vector3.new(18, 6, -4), Vector3.new(10, 1.5, 0), 9.5),
			2,
			"a thin wall in front still lets it through"
		)
		expect.equal(aim(Vector3.new(18, 6, -4), Vector3.new(10, 1.5, 0), 3), nil, "a part well in front hides it")
		expect.equal(aim(Vector3.new(5, 10, 10), Vector3.new(5, 2, 0)), nil, "the middle of the vent is no opening")
	end,

	["TopCenter moves a point onto the middle line of a thin wall, and to its end near the end"] = function(expect)
		local Snapper = Harness.Load("src/Core/Snapper")
		local wall = Harness.Part(Vector3.new(1, 12, 20), CFrame.new(0, 6, 0))

		expect.equal(vec(Snapper.TopCenter(wall, Vector3.new(0.3, 12, 3.1), 4, 1)), "0,12,2", "snapped along the wall")
		expect.equal(vec(Snapper.TopCenter(wall, Vector3.new(0.3, 12, 9.5), 4, 1)), "0,12,10", "the end")
		expect.equal(Snapper.TopCenter(Harness.Part(Vector3.new(8, 1, 8), CFrame.new()), Vector3.zero, 4, 1), nil)
	end,
}
