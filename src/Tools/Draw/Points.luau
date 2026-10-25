--!strict

--[=[
	Where a drawing tool's point lands. Each picker reads the surface under the mouse and snaps the
	point to the grid, to part corners, to the top of a floor or to a vent opening, depending on what
	the shape wants. A picker that snapped sets `ctx.Cursor.Mark` so the snap shows.

	@class Points
]=]

local Cursor = require("../../Services/Cursor")
local Engine = require("./Engine")
local Joints = require("../../Core/Joints")
local Settings = require("../../Pure/Settings")
local Snapper = require("../../Core/Snapper")
local Types = require("../Types")
local VentHoles = require("../../Core/VentHoles")

type Context = Types.Context
type Draw = Engine.Draw

--[=[
	How a floor-standing shape picks its first point.

	@interface FloorRule
	@within Points
	.Raised boolean? -- stand on top of a floor slab: the point is raised by the floor thickness
	.Joins boolean? -- start level with the floor of a room or corridor the point snaps to
	.Doors boolean? -- start in the middle of a doorway near the cursor
	.Level boolean? -- on a floor already built, stay level with its top instead of stacking on it
]=]
export type FloorRule = { Raised: boolean?, Joins: boolean?, Doors: boolean?, Level: boolean? }

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

	local onFloor = rule.Level == true and hit.Instance.Name == "Floor"
	local point = Vector3.new(
		Cursor.Snap(cursor, hit.Position.X),
		hit.Position.Y + (if rule.Raised and not onFloor then ctx.Settings.Floor else 0),
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

local RAIL_INSET = 0.35

--[=[
	@param ctx Context
	@return Vector3? -- when the cursor is on a step or landing of a stair, the spot on its top near the side edge closest to the cursor, in the middle of the step, so a railing lines up with the stair
]=]
function Points.StairEdge(ctx: Context): Vector3?
	local cursor = ctx.Cursor
	local hit = Cursor.Hit(cursor)

	if not hit or hit.Normal.Y < 0.7 or not ctx.Settings.SnapToParts or Cursor.Fine() then
		return nil
	end

	local part = hit.Instance
	local step = string.match(part.Name, "^Step_") ~= nil
	local landing = part.Name == "Landing" and part.Parent ~= nil and part.Parent:FindFirstChild("Step_1") ~= nil

	if not part:IsA("BasePart") or not (step or landing) then
		return nil
	end

	local cf, size = part.CFrame, part.Size
	local spot = cf:PointToObjectSpace(hit.Position)
	local side = math.max(0, size.X / 2 - RAIL_INSET)
	local along = if step then 0 else math.clamp(spot.Z, -size.Z / 2, size.Z / 2)
	local point = cf:PointToWorldSpace(Vector3.new(if spot.X >= 0 then side else -side, size.Y / 2, along))

	cursor.Mark = point

	return point
end

--[=[
	Keeps a railing post on the top it stands on: a point near an edge or corner of the top face
	under the cursor moves in by half a post, so the post sits just inside the corner.

	@param ctx Context
	@param point Vector3? -- the picked point
	@return Vector3? -- the point, moved in from the edges when needed
]=]
function Points.InsetOnTop(ctx: Context, point: Vector3?): Vector3?
	local hit = Cursor.Hit(ctx.Cursor)

	if not point or not hit or hit.Normal.Y < 0.7 or Cursor.Fine() or not hit.Instance:IsA("BasePart") then
		return point
	end

	local part = hit.Instance :: BasePart
	local cf, size = part.CFrame, part.Size

	if cf.UpVector.Y < 0.99 then
		return point
	end

	local spot = cf:PointToObjectSpace(point)
	local halfX, halfZ = size.X / 2, size.Z / 2

	if math.abs(spot.X) > halfX + 0.05 or math.abs(spot.Z) > halfZ + 0.05 then
		return point
	end

	local x = if halfX > RAIL_INSET then math.clamp(spot.X, -halfX + RAIL_INSET, halfX - RAIL_INSET) else 0
	local z = if halfZ > RAIL_INSET then math.clamp(spot.Z, -halfZ + RAIL_INSET, halfZ - RAIL_INSET) else 0
	local moved = cf:PointToWorldSpace(Vector3.new(x, spot.Y, z))

	if (moved - point).Magnitude > 1e-3 then
		ctx.Cursor.Mark = moved
	end

	return moved
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
	@param headOn boolean? -- only start on a vent's open end, never on its side, top or corner
	@return Vector3? -- where a vent starts: on a vent hole or an open vent end, else against the surface under the cursor so the duct sits beside it, on top of it or under it

	Fills `draw.Vent` with what is under the cursor: the surface normal, the vent it would join and
	the spots a vent can start from.
]=]
function Points.Vent(ctx: Context, draw: Draw, shaft: boolean, headOn: boolean?): Vector3?
	local cursor = ctx.Cursor
	local vent = draw.Vent :: Engine.VentState
	local hit = Cursor.Hit(cursor)
	local size = Settings.VentOuter(ctx.Settings)
	local hole = if not shaft then VentHoles.Find(Cursor.Ray(cursor), nil, if hit then hit.Distance else nil) else nil

	if hole and math.abs(hole.Normal.Y) < 0.5 then
		vent.HitNormal, vent.HitHost, vent.HitOwner, vent.HitFace = hole.Normal, nil, nil, nil
		vent.HitEnd, vent.HitCorner = hole.Normal, false
		cursor.Mark = hole.Center

		return hole.Center - Vector3.new(0, size / 2, 0)
	end

	local step = math.max(0.05, Cursor.Grid(cursor))
	local endPoint, openEnd, owner = Snapper.VentEndOnRay(Cursor.Ray(cursor), size, if hit then hit.Distance else nil)
	local corner = false

	if not endPoint and hit then
		endPoint, openEnd, owner, corner = Snapper.VentConnect(hit.Position, size * 1.1, step, size / 2)
	elseif not endPoint then
		return nil
	end

	vent.HitNormal, vent.HitHost, vent.HitOwner, vent.HitEnd, vent.HitFace = nil, nil, owner, openEnd, nil
	vent.HitReach = nil
	vent.HitCorner = corner

	if headOn and endPoint and not (openEnd and math.abs(openEnd.Y) < 0.5) then
		vent.HitOwner, vent.HitEnd, vent.HitCorner = nil, nil, false

		return nil
	end

	if endPoint and owner then
		local ends = Snapper.VentEnds(owner)

		if ends and hit and not openEnd then
			vent.HitHost = if corner and not shaft then nil else (ends.End - ends.Start).Unit
			vent.HitFace = hit.Normal
			vent.HitReach = math.max(0, (hit.Position - endPoint):Dot(hit.Normal))
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

	if not hit then
		return nil
	end

	local normal = hit.Normal
	local y = hit.Position.Y

	if math.abs(normal.Y) < 0.5 then
		local part = hit.Instance :: BasePart
		local reach = halfHeight(part)
		local bottom, top = part.Position.Y - reach, part.Position.Y + reach
		local floorTop = Joints.FloorLevel(part) or bottom
		local best = if ctx.Settings.SnapToParts and not Cursor.Fine() then math.huge else -1

		y = Cursor.Snap(cursor, hit.Position.Y)

		for _, height in { floorTop + size / 2, bottom + size / 2, (bottom + top) / 2, top - size / 2 } do
			if height >= bottom + size / 2 - 0.01 and height <= top - size / 2 + 0.01 then
				local gap = math.abs(height - hit.Position.Y)

				if gap < size * 0.75 and gap < best then
					best, y = gap, height
				end
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
