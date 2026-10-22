--!strict

local Harness = require("../Support/Harness")
local roblox = require("@lune/roblox")

local Settings = require("../../src/Pure/Settings")

local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local vec = Harness.Vec
local named = Harness.Named

local DOOR = {
	Width = 4,
	Height = 7.75,
	Sill = 0,
	Panel = true,
	Frame = true,
	FrameWidth = 0.25,
	FrameDepth = 1.1,
	DoorThickness = 0.2,
	DoorTransparency = 0.5,
	DoorCollide = false,
}

--[[
	@return any -- a fresh context
	@return any -- the Openings module in it
	@return any -- a 20 x 12 x 1 wall standing on the ground at the origin
]]
local function setup(): (any, any, any)
	local context = Harness.new()
	local wall = Harness.Part(Vector3.new(20, 12, 1), CFrame.new(0, 6, 0), context.Workspace)

	return context, context:Require("src/Core/Builders/Openings"), wall
end

return {
	["a framed door gives two posts, a header and a see-through panel"] = function(expect)
		local _, Openings, wall = setup()
		local specs, message, replaced =
			Openings.Opening(Settings.Defaults(), DOOR, Harness.Hit(wall, Vector3.new(0.3, 3, 0.5)), "Rect")
		local frame = named(specs, "Door_Frame")
		local panel = named(specs, "Door_Panel")[1]

		expect.equal(message, "Click to cut an opening in this wall.")
		expect.equal(replaced, wall, "the wall is replaced")
		expect.equal(#frame, 3, "frame pieces")
		expect.equal(vec(frame[1].size), "0.25,7.75,1.1", "left post")
		expect.equal(vec(frame[2].size), "0.25,7.75,1.1", "right post")
		expect.equal(vec(frame[3].size), "4.5,0.25,1.1", "header")
		expect.equal(vec(panel.size), "4,7.75,0.2", "panel")
		expect.equal(panel.transparency, 0.5, "panel transparency")
	end,

	["the wall around a door is rebuilt as left, right and header pieces"] = function(expect)
		local _, Openings, wall = setup()
		local specs = Openings.Opening(Settings.Defaults(), DOOR, Harness.Hit(wall, Vector3.new(0, 3, 0.5)), "Rect")

		expect.equal(vec(named(specs, "Opening_Left")[1].size), "7.75,12,1")
		expect.equal(vec(named(specs, "Opening_Right")[1].size), "7.75,12,1")
		expect.equal(vec(named(specs, "Opening_Header")[1].size), "4.5,4,1", "the header fills above the frame")
		expect.equal(#named(specs, "Opening_Sill"), 0, "a door has no sill")
		expect.equal(named(specs, "Opening_Left")[1].source, wall, "pieces copy the wall's look")
	end,

	["a window has a sill under it"] = function(expect)
		local _, Openings, wall = setup()
		local window = { Width = 5, Height = 4, Sill = 3 }
		local specs = Openings.Opening(Settings.Defaults(), window, Harness.Hit(wall, Vector3.new(0, 4, 0.5)), "Rect")

		expect.equal(vec(named(specs, "Opening_Sill")[1].size), "5,3,1")
		expect.equal(vec(named(specs, "Opening_Header")[1].size), "5,5,1")
	end,

	["a wedge, a locked wall or a door too wide is refused with a reason"] = function(expect)
		local context, Openings, wall = setup()
		local wedge = roblox.Instance.new("WedgePart")

		wedge.Parent = context.Workspace

		local _, wedgeMessage = Openings.Opening(Settings.Defaults(), DOOR, Harness.Hit(wedge, Vector3.zero), "Rect")

		expect.truthy(string.find(wedgeMessage, "Click a Part", 1, true), wedgeMessage)

		wall.Locked = true

		local _, lockedMessage = Openings.Opening(Settings.Defaults(), DOOR, Harness.Hit(wall, Vector3.zero), "Rect")

		expect.truthy(string.find(lockedMessage, "Unlock", 1, true), lockedMessage)

		wall.Locked = false

		local wide = table.clone(DOOR)

		wide.Width = 30

		local specs, wideMessage = Openings.Opening(Settings.Defaults(), wide, Harness.Hit(wall, Vector3.zero), "Rect")

		expect.equal(#specs, 0)
		expect.truthy(string.find(wideMessage, "fit inside", 1, true), wideMessage)
	end,

	["the panel is built see-through and walk-through"] = function(expect)
		local context, Openings, wall = setup()
		local Geometry = context:Require("src/Core/Geometry")
		local specs = Openings.Opening(Settings.Defaults(), DOOR, Harness.Hit(wall, Vector3.new(0, 3, 0.5)), "Rect")
		local model = Geometry.Materialize(specs, "Door")
		local panel = model:FindFirstChild("Door_Panel")

		expect.equal(model.Parent, context.Workspace, "built into Workspace")
		expect.near(panel.Transparency, 0.5)
		expect.equal(panel.CanCollide, false)
	end,
}
