--!strict

--[=[
	Corridors and arched corridors. Both can start in the middle of a doorway, chain with turns that
	snap straight on or to the sides, and cut through the rooms and corridors they meet.

	@class DrawCorridors
]=]

local Bends = require("./Bends")
local Cursor = require("../../Services/Cursor")
local Engine = require("./Engine")
local Geometry = require("../../Core/Geometry")
local Joints = require("../../Core/Joints")
local Paths = require("../../Core/Builders/Paths")
local Points = require("./Points")
local Shapes = require("../../Core/Builders/Shapes")
local Types = require("../Types")

type Context = Types.Context
type Draw = Engine.Draw
type Built = Engine.Built

--[[ Corridors stand on floors, join the level of a room they snap to, and can start in a doorway. ]]
local function start(ctx: Context, draw: Draw): Vector3?
	return Points.Floor(ctx, draw, { Raised = true, Joins = true, Doors = true })
end

--[[
	@param ctx Context
	@param draw Draw
	@param a Vector3
	@param b Vector3
	@return Vector3, Vector3 -- after a bend, the end point snapped straight on, left or right of the previous section
]]
local function turn(ctx: Context, draw: Draw, a: Vector3, b: Vector3): (Vector3, Vector3)
	local previous = draw.Previous

	if not draw.Chained or not previous then
		return a, b
	end

	local straight = previous.dir
	local sideways = straight:Cross(Vector3.yAxis)
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local best, bestDot = straight, -math.huge

	for _, option in { straight, sideways, -sideways } do
		local dot = flat:Dot(option)

		if dot > bestDot then
			best, bestDot = option, dot
		end
	end

	return a, a + best * math.max(0, Cursor.Snap(ctx.Cursor, bestDot)) + Vector3.new(0, b.Y - a.Y, 0)
end

--[[ The doorway under the cursor at the first click becomes the corridor's start, setting its size. ]]
local function onStart(_ctx: Context, draw: Draw)
	draw.StartDoor = draw.HoverDoor
end

--[[
	@param draw Draw
	@return Vector3? -- the direction of the previous section, when this one continues it
]]
local function joinDir(draw: Draw): Vector3?
	return if draw.Chained and draw.Previous then draw.Previous.dir else nil
end

--[[
	@param ctx Context
	@param built Built

	Cuts openings where the new corridor meets rooms and corridors, when that is switched on.
]]
local function connect(ctx: Context, built: Built)
	if not built.Model or not ctx.Settings.ConnectStructures then
		return
	end

	local previous = built.Previous
	local failed = Joints.Connect(
		built.Model,
		ctx.Settings.RoomJoin,
		if previous and previous.model:IsA("Model") then previous.model else nil
	)

	if failed > 0 then
		ctx.Say(string.format("%d wall(s) could not be cut where the structures meet.", failed))
	end
end

local corridor: Engine.Shape = {
	Id = "Corridor",
	Start = start,
	Constrain = turn,
	OnStart = onStart,
	HeightDrag = true,
	Chain = true,
	Joins = true,
	Build = function(_ctx, draw, a, b, sized)
		return Paths.Path(sized.Live, a, b, true, not draw.Chained, joinDir(draw))
	end,
	Commit = function(ctx, draw, built)
		Bends.Join(draw, built, Paths.CorridorStrips(ctx.Settings))
		connect(ctx, built)
	end,
}

--[[
	@param ctx Context
	@param built Built
	@return { Shapes.Cutter } -- the two wedges cut from the old and new ceiling at an arched bend
	@return Model? -- the previous section, whose ceiling the first wedge cuts

	Fills the corner of an arched bend with a wedge of arched roof.
]]
local function archedCorner(ctx: Context, built: Built): ({ Shapes.Cutter }, Model?)
	local before = built.Previous
	local cuts: { Shapes.Cutter } = {}

	if not before or not before.model.Parent or built.Segment.Magnitude <= 0.001 then
		return cuts, nil
	end

	local corner = Geometry.Materialize({}, "Vlux_BendArch")

	for index, wedge in Paths.ArchedBend(ctx.Settings, built.Joint, before.dir, built.Segment) do
		if not Geometry.AddCut(corner, wedge.specs, wedge.cutter, wedge.cutterSize, "ArchedCeiling") then
			ctx.Say("Part of the arched corner roof could not be built.")
		end

		cuts[index] = { cf = wedge.cutter, size = wedge.cutterSize, cylinder = false }
	end

	return cuts, if before.model:IsA("Model") then before.model else nil
end

local archedCorridor: Engine.Shape = {
	Id = "ArchedCorridor",
	Start = start,
	Constrain = turn,
	OnStart = onStart,
	Chain = true,
	Joins = true,
	Build = function(_ctx, draw, a, b, sized)
		return Paths.ArchedCorridor(sized.Live, a, b, joinDir(draw))
	end,
	Commit = function(ctx, draw, built)
		local cuts: { Shapes.Cutter }, before: Model? = {}, nil

		if Bends.Join(draw, built, Paths.ArchedStrips(ctx.Settings)) then
			cuts, before = archedCorner(ctx, built)
		end

		local model = built.Model

		if model then
			local problem = Geometry.UnionSides(model, "ArchedCeiling", "Ceiling")

			if problem then
				ctx.Say(problem)
			end

			if before and #cuts == 2 then
				for index, owner in { before, model } do
					for _, child in owner:GetChildren() do
						if
							child:IsA("BasePart") and (child.Name == "Ceiling_Left" or child.Name == "Ceiling_Right")
						then
							Joints.Carve(child, { cuts[index] })
						end
					end
				end
			end
		end

		connect(ctx, built)
	end,
}

return {
	Engine.Tool(corridor),
	Engine.Tool(archedCorridor),
}
