--!strict

--[=[
	The corner-to-corner tools: rooms, floors, foundations, porches, roofs and blocks. Two clicks
	mark opposite corners of the footprint.

	@class DrawAreas
]=]

local Areas = require("../../Core/Builders/Areas")
local Engine = require("./Engine")
local Geometry = require("../../Core/Geometry")
local Joints = require("../../Core/Joints")
local Points = require("./Points")
local Types = require("../Types")

type Context = Types.Context
type Draw = Engine.Draw
type Spec = Geometry.Spec

--[[
	@param rule Points.FloorRule
	@return (ctx, draw) -> Vector3? -- a start picker that stands on floors by the rule
]]
local function onFloor(rule: Points.FloorRule): (ctx: Context, draw: Draw) -> Vector3?
	return function(ctx: Context, draw: Draw): Vector3?
		return Points.Floor(ctx, draw, rule)
	end
end

--[[ Rooms, blocks: the size of the first part built, or the footprint while there is none. ]]
local function boxReadout(_draw: Draw, a: Vector3, b: Vector3, specs: { Spec }): string
	local first = specs[1]

	if first then
		return string.format("%.1f × %.1f × %.1f studs", first.size.X, first.size.Y, first.size.Z)
	end

	return string.format("%.1f × %.1f studs", math.abs(b.X - a.X), math.abs(b.Z - a.Z))
end

--[[ Floors, foundations, porches, roofs: the footprint. ]]
local function areaReadout(_draw: Draw, a: Vector3, b: Vector3): string
	return string.format("%.1f × %.1f studs", math.abs(b.X - a.X), math.abs(b.Z - a.Z))
end

--[[ Blocks and arches start on the grid at the floor level setting. ]]
local function onGrid(_ctx: Context, _draw: Draw): Vector3?
	return nil
end

local room: Engine.Shape = {
	Id = "Room",
	Start = onFloor({ Raised = true, Joins = true }),
	HeightDrag = true,
	Joins = true,
	Readout = boxReadout,
	Build = function(_ctx, _draw, a, b, sized)
		return Areas.Room(sized.Live, a, b)
	end,
	Commit = function(ctx, _draw, built)
		if built.Model and ctx.Settings.ConnectStructures then
			local failed = Joints.Connect(built.Model, ctx.Settings.RoomJoin, nil)

			if failed > 0 then
				ctx.Say(string.format("%d wall(s) could not be cut where the structures meet.", failed))
			end
		end
	end,
}

local floor: Engine.Shape = {
	Id = "Floor",
	Start = onFloor({ Raised = true }),
	Loose = true,
	Readout = areaReadout,
	Build = function(_ctx, _draw, a, b, sized)
		return Areas.Floor(sized.Live, a, b)
	end,
	Commit = function(ctx, _draw, built)
		local transparency = ctx.Settings.FloorTransparency

		if transparency <= 0 then
			return
		end

		local pieces: { Instance } = if built.Placed:IsA("BasePart")
			then { built.Placed }
			else built.Placed:GetChildren()

		for _, child in pieces do
			if child:IsA("BasePart") then
				child.Transparency = math.clamp(transparency, 0, 1)
			end
		end
	end,
}

local foundation: Engine.Shape = {
	Id = "Foundation",
	Start = onFloor({}),
	Loose = true,
	Readout = areaReadout,
	Build = function(_ctx, _draw, a, b, sized)
		return Areas.Foundation(sized.Live, a, b)
	end,
}

local porch: Engine.Shape = {
	Id = "Porch",
	Start = onFloor({ Raised = true }),
	Readout = areaReadout,
	Build = function(_ctx, _draw, a, b, sized)
		return Areas.Porch(sized.Live, a, b)
	end,
}

local roof: Engine.Shape = {
	Id = "Roof",
	Start = onFloor({}),
	Readout = areaReadout,
	Build = function(_ctx, _draw, a, b, sized)
		return Areas.Roof(sized.Live, a, b)
	end,
}

local block: Engine.Shape = {
	Id = "Block",
	Start = onGrid,
	Loose = true,
	Readout = boxReadout,
	Build = function(ctx, draw, a, b)
		return Areas.Block(ctx.Settings, a, b, draw.Lock)
	end,
}

return {
	Engine.Tool(room),
	Engine.Tool(floor),
	Engine.Tool(foundation),
	Engine.Tool(porch),
	Engine.Tool(roof),
	Engine.Tool(block),
}
