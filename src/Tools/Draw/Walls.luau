--!strict

--[=[
	The line tools: walls, pillared walls, railings, half walls and fences. Each is drawn point to
	point and chains, so clicking on keeps adding sections.

	@class DrawWalls
]=]

local Bends = require("./Bends")
local Cursor = require("../../Services/Cursor")
local Engine = require("./Engine")
local Paths = require("../../Core/Builders/Paths")
local Points = require("./Points")
local Railings = require("../../Core/Builders/Railings")
local Snap = require("../../Pure/Snap")
local Types = require("../Types")

type Context = Types.Context
type Draw = Engine.Draw

local ALIGN = math.rad(12)

--[[
	@param draw Draw
	@return Vector3? -- the direction of the previous section, when this one continues it
]]
local function joinDir(draw: Draw): Vector3?
	return if draw.Chained and draw.Previous then draw.Previous.dir else nil
end

--[[ Walls and pillared walls start on a part corner or floor top, and stay on the level they started on. ]]
local function startOnVertex(ctx: Context, _draw: Draw): Vector3?
	return Points.Vertex(ctx, nil)
end

local function nextOnVertex(ctx: Context, _draw: Draw, origin: Vector3): Vector3?
	return Points.Vertex(ctx, origin.Y)
end

--[[ Railings and half walls follow stairs, so their points sit on whatever top is under the cursor. ]]
local function startOnFloor(ctx: Context, draw: Draw): Vector3?
	return Points.StairEdge(ctx) or (Points.InsetOnTop(ctx, Points.Floor(ctx, draw, {})))
end

--[[ The direction of each chain's last section, so the next one can line up with it. ]]
local lastRun: { [Draw]: Vector3? } = setmetatable({}, { __mode = "k" }) :: any

--[[
	After the first point a railing snaps to stair edges the same way, then to any top. Off the
	stairs, a point that nearly continues the last section, or nearly turns square from it, lines
	up exactly, so a railing coming up stairs runs on along their edge and turns square around the
	opening.
]]
local function nextOnTop(ctx: Context, draw: Draw, origin: Vector3): Vector3?
	local onStairs = Points.StairEdge(ctx)

	if onStairs then
		return onStairs
	end

	local point, onEdge = Points.InsetOnTop(ctx, Points.SurfaceTop(ctx))
	local last = lastRun[draw]

	if not point or onEdge or not last or not draw.Chained or Cursor.Fine() then
		return point
	end

	local dx, dz, lined = Snap.Align(point.X - origin.X, point.Z - origin.Z, last.X, last.Z, ALIGN)

	if not lined then
		return point
	end

	local aligned = Vector3.new(origin.X + dx, point.Y, origin.Z + dz)

	ctx.Cursor.Mark = aligned

	return aligned
end

--[[ Remembers the direction of the section just built, for the next one to line up with. ]]
local function remember(_ctx: Context, draw: Draw, built: Engine.Built)
	local run = built.Segment

	lastRun[draw] = if run.Magnitude > 0.05 then run.Unit else nil
end

local wall: Engine.Shape = {
	Id = "Wall",
	Start = startOnVertex,
	Next = nextOnVertex,
	HeightDrag = true,
	Chain = true,
	Loose = true,
	Build = function(_ctx, draw, a, b, sized)
		local path = table.clone(sized.Live)

		path.PillaredWalls = false

		return Paths.Path(path, a, b, false, not draw.Chained, joinDir(draw))
	end,
	Commit = function(ctx, draw, built)
		Bends.Join(draw, built, Paths.WallStrips(ctx.Settings))
	end,
}

local pillaredWall: Engine.Shape = {
	Id = "PillaredWall",
	Start = startOnVertex,
	Next = nextOnVertex,
	HeightDrag = true,
	Chain = true,
	Build = function(_ctx, draw, a, b, sized)
		local path = table.clone(sized.Live)

		path.PillaredWalls = true

		return Paths.Path(path, a, b, false, not draw.Chained, nil)
	end,
}

local railing: Engine.Shape = {
	Id = "Railing",
	Start = startOnFloor,
	Next = nextOnTop,
	Chain = true,
	Build = function(_ctx, draw, a, b, sized)
		return Railings.Railing(sized.Live, a, b, not draw.Chained)
	end,
	Commit = remember,
}

local halfWall: Engine.Shape = {
	Id = "HalfWall",
	Start = startOnFloor,
	Next = nextOnTop,
	Chain = true,
	Loose = true,
	Build = function(_ctx, draw, a, b, sized)
		return Railings.HalfWall(sized.Live, a, b, not draw.Chained)
	end,
	Commit = remember,
}

local fence: Engine.Shape = {
	Id = "Fence",
	Start = startOnFloor,
	Chain = true,
	Build = function(_ctx, draw, a, b, sized)
		return Railings.Fence(sized.Live, a, b, not draw.Chained)
	end,
	Commit = remember,
}

return {
	Engine.Tool(wall),
	Engine.Tool(pillaredWall),
	Engine.Tool(railing),
	Engine.Tool(halfWall),
	Engine.Tool(fence),
}
