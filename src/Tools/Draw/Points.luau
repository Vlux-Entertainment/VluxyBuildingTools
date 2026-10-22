--!strict

--[=[
	Where a drawing tool's point lands. Each picker reads the surface under the mouse and snaps the
	point to the grid, to part corners, to the top of a floor or to a vent opening, depending on what
	the shape wants. A picker that snapped sets `ctx.Cursor.Mark` so the snap shows.

	@class DrawPoints
]=]

local Cursor = require("../../Services/Cursor")
local Engine = require("./Engine")
local Joints = require("../../Core/Joints")
local Snapper = require("../../Core/Snapper")
local Types = require("../Types")

type Context = Types.Context
type Draw = Engine.Draw

--[=[
	How a floor-standing shape picks its first point.

	@interface FloorRule
	@within DrawPoints
	.Raised boolean? -- stand on top of a floor slab: the point is raised by the floor thickness
	.Joins boolean? -- start level with the floor of a room or corridor the point snaps to
	.Doors boolean? -- start in the middle of a doorway near the cursor
]=]
export type FloorRule = { Raised: boolean?, Joins: boolean?, Doors: boolean? }

local Points = {}

--[=[
	@param ctx Context
	@param point Vector3
	@param level boolean -- also take the floor height of the room or corridor snapped to
	@return Vector3 -- the point snapped to nearby parts, standing at the floor of the structure it snapped to
]=]
function Points.SnapLevel(ctx: Context, point: Vector3, level: boolean): Vector3
	local cursor = ctx.Cursor

	cursor.SnapPart = nil

	local snapped = Cursor.PartSnap(cursor, point)
	local part = cursor.SnapPart

	if level and part then
		local floorTop = Joints.FloorLevel(part)

		if floorTop then
			return Vector3.new(snapped.X, floorTop, snapped.Z)
		end
	end

	return snapped
end

--[=[
	@param ctx Context
	@param draw Draw
	@param point Vector3
	@return Vector3? -- the middle of a doorway near the point, on the face of its wall, so a corridor can start exactly there

	Records the doorway in `draw.HoverDoor`.
]=]
function Points.Door(ctx: Context, draw: Draw, point: Vector3): Vector3?
	draw.HoverDoor = nil

	if draw.First or Cursor.Fine() or not ctx.Settings.SnapToParts then
		return nil
	end

	local found = Snapper.Doorway(point, ctx.Settings.SnapRadius)

	if not found then
		return nil
	end

	draw.HoverDoor = found
	ctx.Cursor.Mark = found.point

	return found.point
end

--[=[
	@param ctx Context
	@param draw Draw
	@param rule FloorRule
	@return Vector3? -- the snapped spot on the top of whatever the cursor is over, so a floor drawn from it rests on top
]=]
function Points.Floor(ctx: Context, draw: Draw, rule: FloorRule): Vector3?
	local cursor = ctx.Cursor
	local hit = Cursor.Hit(cursor)

	if not hit then
		return nil
	end

	if rule.Doors then
		local door = Points.Door(ctx, draw, hit.Position)

		if door then
			return door
		end
	end

	if rule.Joins and hit.Normal.Y < 0.7 then
		local level = Joints.FloorLevel(hit.Instance)

		if level then
			return Points.SnapLevel(
				ctx,
				Vector3.new(Cursor.Snap(cursor, hit.Position.X), level, Cursor.Snap(cursor, hit.Position.Z)),
				true
			)
		end
	end

	if hit.Normal.Y < 0.7 then
		return nil
	end

	local point = Vector3.new(
		Cursor.Snap(cursor, hit.Position.X),
		hit.Position.Y + (if rule.Raised then ctx.Settings.Floor else 0),
		Cursor.Snap(cursor, hit.Position.Z)
	)

	return Points.SnapLevel(ctx, point, rule.Joins == true)
end

--[=[
	@param ctx Context
	@param level number? -- the height the point must stay at, or nil to take the height of what it lands on
	@return Vector3? -- the middle of a floor top, else the nearest part corner, else the grid point on the surface
]=]
function Points.Vertex(ctx: Context, level: number?): Vector3?
	local cursor = ctx.Cursor
	local settings = ctx.Settings
	local hit = Cursor.Hit(cursor)

	if not hit then
		return nil
	end

	if settings.SnapToParts and not Cursor.Fine() then
		local part = hit.Instance

		if hit.Normal.Y >= 0.7 and part:IsA("BasePart") and (not level or math.abs(hit.Position.Y - level) < 0.05) then
			local top = Snapper.TopCenter(part, hit.Position, settings.Grid, 1)

			if top then
				cursor.Mark = top

				return top
			end
		end

		local corner = Cursor.Corner(hit.Position)

		if corner then
			cursor.Mark = corner

			return if level then Vector3.new(corner.X, level, corner.Z) else corner
		end
	end

	if level then
		return nil
	end

	local height = if hit.Normal.Y >= 0.7 then hit.Position.Y else Cursor.Snap(cursor, hit.Position.Y)

	return Vector3.new(Cursor.Snap(cursor, hit.Position.X), height, Cursor.Snap(cursor, hit.Position.Z))
end

--[=[
	@param ctx Context
	@return Vector3? -- the snapped spot on the top of whatever the cursor is over, height not snapped, so a railing can stand on the steps of a stair
]=]
function Points.SurfaceTop(ctx: Context): Vector3?
	local cursor = ctx.Cursor
	local hit = Cursor.Hit(cursor)

	if not hit or hit.Normal.Y < 0.7 then
		return nil
	end

	return Cursor.PartSnap(
		cursor,
		Vector3.new(Cursor.Snap(cursor, hit.Position.X), hit.Position.Y, Cursor.Snap(cursor, hit.Position.Z))
	)
end

--[[
	@param part BasePart
	@return number -- half the part's height in world space, whatever way it is turned
]]
local function halfHeight(part: BasePart): number
	return (
		math.abs(part.CFrame.RightVector.Y) * part.Size.X
		+ math.abs(part.CFrame.UpVector.Y) * part.Size.Y
		+ math.abs(part.CFrame.LookVector.Y) * part.Size.Z
	) / 2
end

--[=[
	@param ctx Context
	@param draw Draw -- must have vent state
	@param shaft boolean -- true for a vertical vent, whose point is on the surface itself
	@return Vector3? -- where a vent starts: on an open vent end, else against the surface under the cursor so the duct sits beside it, on top of it or under it

	Fills `draw.Vent` with what is under the cursor: the surface normal, the vent it would join and
	the spots a vent can start from.
]=]
function Points.Vent(ctx: Context, draw: Draw, shaft: boolean): Vector3?
	local cursor = ctx.Cursor
	local vent = draw.Vent :: Engine.VentState
	local hit = Cursor.Hit(cursor)

	if not hit then
		return nil
	end

	local size = ctx.Settings.VentSize
	local step = math.max(0.5, ctx.Settings.FineGrid)
	local endPoint, openEnd, owner = Snapper.VentConnect(hit.Position, size * 1.1, step)

	vent.HitNormal = nil
	vent.HitHost = nil
	table.clear(vent.Marks)

	if endPoint and owner then
		local a = owner:GetAttribute("VluxyBT_VentStart")
		local b = owner:GetAttribute("VluxyBT_VentEnd")

		if typeof(a) == "Vector3" and typeof(b) == "Vector3" and (b - a).Magnitude > 0.05 then
			for along = 0, (b - a).Magnitude, step do
				table.insert(vent.Marks, a + (b - a).Unit * along)
			end

			table.insert(vent.Marks, b)

			if not openEnd then
				vent.HitHost = (b - a).Unit
			end
		end

		if not shaft and openEnd and math.abs(openEnd.Y) > 0.9 then
			local centre = endPoint - openEnd.Unit * (size / 2)

			vent.HitHost = openEnd.Unit
			cursor.Mark = centre

			return centre - Vector3.new(0, size / 2, 0)
		end

		cursor.Mark = endPoint

		return if shaft then endPoint else endPoint - Vector3.new(0, size / 2, 0)
	end

	local normal = hit.Normal
	local y = hit.Position.Y

	if math.abs(normal.Y) < 0.5 then
		local part = hit.Instance :: BasePart
		local reach = halfHeight(part)
		local bottom, top = part.Position.Y - reach, part.Position.Y + reach
		local floorTop = Joints.FloorLevel(part) or bottom
		local best = math.huge

		y = Cursor.Snap(cursor, hit.Position.Y)

		for _, height in { floorTop + size / 2, bottom + size / 2, (bottom + top) / 2, top - size / 2 } do
			if height >= bottom + size / 2 - 0.01 and height <= top - size / 2 + 0.01 then
				local gap = math.abs(height - hit.Position.Y)

				if gap < size * 0.75 and gap < best then
					best, y = gap, height
				end

				table.insert(
					vent.Marks,
					Vector3.new(
						if math.abs(normal.X) < 0.5 then Cursor.Snap(cursor, hit.Position.X) else hit.Position.X,
						height,
						if math.abs(normal.Z) < 0.5 then Cursor.Snap(cursor, hit.Position.Z) else hit.Position.Z
					)
				)
			end
		end
	end

	local centre = Vector3.new(
		if math.abs(normal.X) < 0.5 then Cursor.Snap(cursor, hit.Position.X) else hit.Position.X,
		y,
		if math.abs(normal.Z) < 0.5 then Cursor.Snap(cursor, hit.Position.Z) else hit.Position.Z
	)

	vent.HitNormal = normal
	cursor.Mark = centre

	return if shaft then centre else centre - Vector3.new(0, size / 2, 0)
end

return Points
