--!strict

--[=[
	Joins one segment of a chain to the one before it. When a wall, corridor or vent turns, each
	layer of the old segment (left wall, floor, right wall and so on) is stretched or shortened so it
	meets the matching layer of the new one, and corner filler pieces are added.

	@class Bends
]=]

local Engine = require("./Engine")
local Geometry = require("../../Core/Geometry")
local Paths = require("../../Core/Builders/Paths")
local Shapes = require("../../Core/Builders/Shapes")

type Draw = Engine.Draw
type Built = Engine.Built

local Bends = {}

--[[
	@param child Part -- one piece of the earlier segment
	@param floor Instance? -- the earlier segment's floor, to tell its left wall from its right
	@param across Vector3 -- the earlier segment's sideways direction
	@return string -- the strip key the piece belongs to
]]
local function stripKey(child: Part, floor: Instance?, across: Vector3): string
	local key = if child.Name == "VentFloor"
		then "Floor"
		elseif child.Name == "VentCeiling" then "Ceiling"
		else child.Name

	if key == "CorridorWall" or key == "VentWall" then
		local lateral = if floor and floor:IsA("BasePart") then (child.Position - floor.Position):Dot(across) else 0

		key = if lateral > 0 then "Right" else "Left"
	end

	return key
end

--[=[
	Bends the previous segment to meet the one just placed, and remembers the new one as the segment
	the next will join. Each layer grows or shrinks toward the joint, along the previous direction,
	whichever way its piece faces, so a vent continued from the end it was started at bends right.
	Runs inside the build's undo step.

	@param draw Draw
	@param built Built
	@param strips { Shapes.Strip } -- the layers of the segment just placed
	@return boolean -- true when there was a previous segment and it was bent
]=]
function Bends.Join(draw: Draw, built: Built, strips: { Shapes.Strip }): boolean
	local before = built.Previous
	local segment = built.Segment
	local bent = false

	if before and before.model.Parent and segment.Magnitude > 0.001 then
		local bend = Paths.Bend(built.Joint, before.dir, segment, before.strips, strips)
		local floor = before.model:FindFirstChild("Floor") or before.model:FindFirstChild("VentFloor")
		local across = before.dir:Cross(Vector3.yAxis)
		local pieces: { Instance } = if before.model:IsA("BasePart")
			then { before.model }
			else before.model:GetChildren()

		for _, child in pieces do
			if child:IsA("Part") then
				local delta = bend.finish[stripKey(child, floor, across)]

				if delta and delta ~= 0 then
					child.Size += Vector3.new(0, 0, delta)
					child.CFrame += before.dir.Unit * (delta / 2)
				end
			end
		end

		if #bend.ending > 0 then
			Geometry.Materialize(bend.ending, "Vlux_Bend")
		end

		bent = true
	end

	draw.Previous = if segment.Magnitude > 0.001
		then { model = built.Placed, dir = segment.Unit, strips = strips }
		else nil

	return bent
end

return Bends
