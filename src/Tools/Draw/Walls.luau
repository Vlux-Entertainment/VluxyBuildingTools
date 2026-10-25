--!strict

--[=[
	The line tools: walls, pillared walls, railings, half walls and fences. Each is drawn point to
	point and chains, so clicking on keeps adding sections.

	@class DrawWalls
]=]

local Bends = require("./Bends")
local Engine = require("./Engine")
local Paths = require("../../Core/Builders/Paths")
local Points = require("./Points")
local Railings = require("../../Core/Builders/Railings")
local Types = require("../Types")

type Context = Types.Context
type Draw = Engine.Draw

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
	return Points.StairEdge(ctx) or Points.Floor(ctx, draw, {})
end

--[[ After the first point a railing snaps to stair edges the same way, then to any top. ]]
local function nextOnTop(ctx: Context, _draw: Draw, _origin: Vector3): Vector3?
	return Points.StairEdge(ctx) or Points.SurfaceTop(ctx)
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
}

local fence: Engine.Shape = {
	Id = "Fence",
	Start = startOnFloor,
	Chain = true,
	Build = function(_ctx, draw, a, b, sized)
		return Railings.Fence(sized.Live, a, b, not draw.Chained)
	end,
}

return {
	Engine.Tool(wall),
	Engine.Tool(pillaredWall),
	Engine.Tool(railing),
	Engine.Tool(halfWall),
	Engine.Tool(fence),
}
