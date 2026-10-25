--!strict

local Harness = require("../Support/Harness")
local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3
local Vector2 = roblox.Vector2
local CFrame = roblox.CFrame
local Ray = roblox.Ray
local vec = Harness.Vec

local LOOK = Vector3.new(0, 0, -1)

--[[
	@param x number -- how far right of the selection the mouse ray passes
	@return any -- a ray straight into the screen
]]
local function rayAt(x: number): any
	return Ray.new(Vector3.new(x, 0, 10), LOOK)
end

return {
	["Grab moves the parts by the mouse motion, snapped to the grid"] = function(expect)
		local Transform = Harness.Load("src/Core/Transform")
		local part = Harness.Part(Vector3.new(2, 2, 2), CFrame.new())
		local session = Transform.Begin("Grab", { part }, Vector2.zero, rayAt(0), LOOK)

		Transform.Update(session, 4, Vector2.zero, rayAt(9.1), LOOK)

		expect.equal(vec(part.CFrame.Position), "8,0,0")
	end,

	["Grab pulls a corner of the selection onto a measuring guide point near it"] = function(expect)
		local context = Harness.new()
		local Transform = context:Require("src/Core/Transform")
		local Guides = context:Require("src/Core/Guides")
		local part = Harness.Part(Vector3.new(2, 2, 2), CFrame.new())
		local session = Transform.Begin("Grab", { part }, Vector2.zero, rayAt(0), LOOK)

		Guides.Add({ Lines = {}, Points = { Vector3.new(9.4, 1, 1) } })
		Transform.Update(session, 4, Vector2.zero, rayAt(9.1), LOOK, 1.5)
		expect.equal(vec(part.CFrame.Position), "8.4,0,0", "the corner lands on the guide point")

		Transform.Update(session, 4, Vector2.zero, rayAt(9.1), LOOK, nil)
		expect.equal(vec(part.CFrame.Position), "8,0,0", "with guide snapping off, the grid alone")
	end,

	["a typed number on a locked axis moves exactly that far"] = function(expect)
		local Transform = Harness.Load("src/Core/Transform")
		local NumericInput = Harness.Load("src/Pure/NumericInput")
		local part = Harness.Part(Vector3.new(2, 2, 2), CFrame.new())
		local session = Transform.Begin("Grab", { part }, Vector2.zero, rayAt(0), LOOK)

		Transform.SetLock(session, { Axis = "Y", Plane = false }, rayAt(0), LOOK)
		NumericInput.Press(session.Numeric, "Five")
		Transform.Update(session, 4, Vector2.zero, rayAt(3), LOOK)

		expect.equal(vec(part.CFrame.Position), "0,5,0")
	end,

	["Rotate turns in 5 degree steps around the selection's centre"] = function(expect)
		local Transform = Harness.Load("src/Core/Transform")
		local part = Harness.Part(Vector3.new(4, 1, 1), CFrame.new(2, 0, 0))
		local other = Harness.Part(Vector3.new(4, 1, 1), CFrame.new(-2, 0, 0))
		local session = Transform.Begin("Rotate", { part, other }, Vector2.zero, rayAt(0), LOOK)

		Transform.Update(session, 4, Vector2.new(181, 0), rayAt(0), LOOK)

		expect.equal(vec(part.CFrame.Position), "0,0,-2", "half a pixel per degree: 90 degrees")
	end,

	["Scale grows sizes and spacing from the centre, and Restore undoes it"] = function(expect)
		local context = Harness.new()
		local Transform = context:Require("src/Core/Transform")
		local part = Harness.Part(Vector3.new(2, 2, 2), CFrame.new(4, 0, 0), context.Workspace)
		local other = Harness.Part(Vector3.new(2, 2, 2), CFrame.new(-4, 0, 0), context.Workspace)
		local session = Transform.Begin("Scale", { part, other }, Vector2.zero, rayAt(0), LOOK)

		Transform.Update(session, 4, Vector2.new(100, 0), rayAt(0), LOOK)

		expect.equal(vec(part.Size), "4,4,4", "double size")
		expect.equal(vec(part.CFrame.Position), "8,0,0", "double distance")

		Transform.Restore(session)

		expect.equal(vec(part.Size), "2,2,2", "restored")
	end,
}
