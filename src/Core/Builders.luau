--!strict

--[=[
	Turns the clicked points and the panel settings into Part specs for every building tool. Nothing
	here changes the place; the specs are previewed and then built by `Geometry.Materialize`.

	@class Builders
]=]

local AxisLock = require("../Pure/AxisLock")
local Geometry = require("./Geometry")
local Settings = require("../Pure/Settings")
local Snap = require("../Pure/Snap")

type Settings = Settings.Settings
type Spec = Geometry.Spec

export type Source = {
	Parts: { BasePart },
	Pivot: CFrame,
	Size: Vector3,
}

local add = Geometry.Add

--[[
	@param a Vector3
	@param b Vector3

	@return Vector3 -- the low corner of the rectangle drawn on a's floor
	@return Vector3 -- the high corner
	@return Vector3 -- the centre
]]
local function rectangle(a: Vector3, b: Vector3): (Vector3, Vector3, Vector3)
	local low = Vector3.new(math.min(a.X, b.X), a.Y, math.min(a.Z, b.Z))
	local high = Vector3.new(math.max(a.X, b.X), a.Y, math.max(a.Z, b.Z))

	return low, high, (low + high) * 0.5
end

--[[
	Adds a wall-like slab running from a to b, standing on the floor under a.
]]
local function segment(out: { Spec }, a: Vector3, b: Vector3, width: number, height: number, name: string)
	local d = b - a
	local length = d.Magnitude

	if length < 0.05 then
		return
	end

	local center = (a + b) * 0.5 + Vector3.new(0, height * 0.5, 0)

	add(out, Vector3.new(width, height, length), CFrame.lookAt(center, center + d), name)
end

--[[
	Extrudes a planar triangle into two exact triangular WedgeParts. The corners may be given in any
	order; the longest side becomes the wedges' shared base.
]]
local function trianglePrism(
	out: { Spec },
	a: Vector3,
	b: Vector3,
	c: Vector3,
	depth: number,
	name: string,
	source: BasePart?
)
	if (b - a).Magnitude < (c - a).Magnitude then
		b, c = c, b
	end

	if (b - a).Magnitude < (c - b).Magnitude then
		a, c = c, a
	end

	local base = b - a

	if base.Magnitude < 0.0001 then
		return
	end

	local unit = base.Unit
	local foot = a + unit * ((c - a):Dot(unit))
	local rise = c - foot
	local height = rise.Magnitude

	if height < 0.001 then
		return
	end

	local up = rise.Unit

	for _, endPoint in { a, b } do
		local run = foot - endPoint

		if run.Magnitude > 0.001 then
			local back = run.Unit
			local center = (foot + endPoint) * 0.5 + rise * 0.5

			add(
				out,
				Vector3.new(depth, height, run.Magnitude),
				CFrame.fromMatrix(center, up:Cross(back), up, back),
				name,
				source,
				"WedgePart"
			)
		end
	end
end

--[[
	Extrudes a planar quad as two triangle prisms.
]]
local function quadPrism(
	out: { Spec },
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	depth: number,
	name: string,
	source: BasePart?
)
	trianglePrism(out, a, b, c, depth, name, source)
	trianglePrism(out, a, c, d, depth, name, source)
end

--[[
	@param a Vector3 -- the start point
	@param b Vector3 -- the end point

	@return CFrame? -- at a, looking at b; nil when they are the same point
]]
local function directionCF(a: Vector3, b: Vector3): CFrame?
	local d = b - a

	if d.Magnitude < 0.05 then
		return nil
	end

	return CFrame.lookAt(a, a + d)
end

local Builders = {}

--[=[
	@param settings Settings
	@param a Vector3 -- one corner
	@param b Vector3 -- the opposite corner
	@return { Spec } -- floor, four walls and an optional ceiling; empty when the room is too small
]=]
function Builders.Room(settings: Settings, a: Vector3, b: Vector3): { Spec }
	local out: { Spec } = {}
	local lo, hi, c = rectangle(a, b)
	local w, d = hi.X - lo.X, hi.Z - lo.Z
	local t, h, f = settings.Thickness, settings.Height, settings.Floor

	if w < 2 * t + 0.05 or d < 2 * t + 0.05 then
		return out
	end

	add(out, Vector3.new(w, f, d), CFrame.new(c - Vector3.new(0, f / 2, 0)), "Floor")
	add(out, Vector3.new(w, h, t), CFrame.new(c.X, a.Y + h / 2, lo.Z + t / 2), "Wall_North")
	add(out, Vector3.new(w, h, t), CFrame.new(c.X, a.Y + h / 2, hi.Z - t / 2), "Wall_South")
	add(out, Vector3.new(t, h, d - 2 * t), CFrame.new(lo.X + t / 2, a.Y + h / 2, c.Z), "Wall_West")
	add(out, Vector3.new(t, h, d - 2 * t), CFrame.new(hi.X - t / 2, a.Y + h / 2, c.Z), "Wall_East")

	if settings.Roof then
		add(out, Vector3.new(w, f, d), CFrame.new(c + Vector3.new(0, h + f / 2, 0)), "Ceiling")
	end

	return out
end

--[=[
	@param settings Settings
	@param a Vector3
	@param b Vector3
	@param corridor boolean -- true for a floored corridor, false for a single wall
	@return { Spec }
]=]
function Builders.Path(settings: Settings, a: Vector3, b: Vector3, corridor: boolean): { Spec }
	local out: { Spec } = {}
	local d = b - a
	local length = d.Magnitude

	if length < 0.05 then
		return out
	end

	if not corridor then
		segment(out, a, b, settings.Thickness, settings.Height, "Wall")

		return out
	end

	local cf = CFrame.lookAt((a + b) * 0.5, (a + b) * 0.5 + d)
	local w, t, h, f = settings.Width, settings.Thickness, settings.Height, settings.Floor

	add(out, Vector3.new(w + 2 * t, f, length), cf * CFrame.new(0, -f / 2, 0), "Floor")

	for _, sign in { -1, 1 } do
		add(out, Vector3.new(t, h, length), cf * CFrame.new(sign * (w + t) / 2, h / 2, 0), "CorridorWall")
	end

	if settings.Roof then
		add(out, Vector3.new(w + 2 * t, f, length), cf * CFrame.new(0, h + f / 2, 0), "Ceiling")
	end

	return out
end

--[=[
	@param settings Settings
	@param a Vector3 -- the first step
	@param b Vector3 -- the end of the run
	@param ramp boolean -- true for one wedge, false for steps
	@return { Spec }
]=]
function Builders.Stairs(settings: Settings, a: Vector3, b: Vector3, ramp: boolean): { Spec }
	local out: { Spec } = {}
	local cf = directionCF(a, b)

	if not cf then
		return out
	end

	local length = (b - a).Magnitude
	local count = math.clamp(math.ceil(length / settings.Run), 1, 200)
	local run = length / count
	local height = if ramp then settings.RampHeight else settings.StairHeight
	local rise = height / count

	if ramp then
		-- A WedgePart rises toward local +Z, so turn it to rise away from the first click.
		add(
			out,
			Vector3.new(settings.Width, height, length),
			cf * CFrame.new(0, height / 2, -length / 2) * CFrame.Angles(0, math.pi, 0),
			"Ramp",
			nil,
			"WedgePart"
		)
	else
		for i = 1, count do
			add(
				out,
				Vector3.new(settings.Width, rise * i, run),
				cf * CFrame.new(0, rise * i / 2, -run * (i - 0.5)),
				"Step_" .. i
			)
		end
	end

	if settings.Landing > 0 then
		add(
			out,
			Vector3.new(settings.Width, height, settings.Landing),
			cf * CFrame.new(0, height / 2, -length - settings.Landing / 2),
			"Landing"
		)
	end

	return out
end

--[[
	@return number -- the centre of the span between two values
	@return number -- its length, or `minimum` when the two are equal
]]
local function span(from: number, to: number, minimum: number): (number, number)
	if math.abs(to - from) < 0.001 then
		return from, minimum
	end

	return (from + to) / 2, math.abs(to - from)
end

--[=[
	A box between two corners. With an axis lock the box follows the drag: the locked axis sets
	that side, and a Y lock sets the height instead of the panel value. Sides the drag does not
	cover are one snap step wide.

	@param settings Settings
	@param a Vector3
	@param b Vector3
	@param lock AxisLock.Lock? -- the lock in force, if any
	@return { Spec }
]=]
function Builders.Block(settings: Settings, a: Vector3, b: Vector3, lock: AxisLock.Lock?): { Spec }
	local out: { Spec } = {}

	if not lock then
		local lo, hi, c = rectangle(a, b)

		add(
			out,
			Vector3.new(hi.X - lo.X, settings.Height, hi.Z - lo.Z),
			CFrame.new(c + Vector3.new(0, settings.Height / 2, 0)),
			"Block"
		)

		return out
	end

	local grid = math.max(0.05, settings.Grid)
	local cx, sx = span(a.X, b.X, grid)
	local cz, sz = span(a.Z, b.Z, grid)
	local cy, sy = a.Y + settings.Height / 2, settings.Height

	if lock.Axis == "Y" and not lock.Plane then
		cy, sy = span(a.Y, b.Y, grid)
	end

	add(out, Vector3.new(sx, sy, sz), CFrame.new(cx, cy, cz), "Block")

	return out
end

--[=[
	@param settings Settings
	@param a Vector3 -- one inner edge, at ground level
	@param b Vector3 -- the other inner edge
	@return { Spec } -- two posts and a curved header; empty when the span is too wide for the height
]=]
function Builders.Arch(settings: Settings, a: Vector3, b: Vector3): { Spec }
	local out: { Spec } = {}
	local direction = b - a
	local width = direction.Magnitude

	if width < 0.1 then
		return out
	end

	local radius = width / 2
	local t = settings.Thickness
	local spring = settings.ArchHeight - radius

	if spring < 0 then
		return out
	end

	local right = direction.Unit
	local up = Vector3.yAxis
	local back = right:Cross(up)
	local cf = CFrame.fromMatrix((a + b) * 0.5, right, up, back)
	local depth = settings.ArchDepth

	for _, sign in { -1, 1 } do
		add(out, Vector3.new(t, spring, depth), cf * CFrame.new(sign * (radius + t / 2), spring / 2, 0), "Arch_Post")
	end

	local count = math.floor(settings.ArchSegments)

	local function point(r: number, angle: number): Vector3
		return cf:PointToWorldSpace(Vector3.new(r * math.cos(angle), spring + r * math.sin(angle), 0))
	end

	for i = 0, count - 1 do
		local x = i * math.pi / count
		local y = (i + 1) * math.pi / count

		quadPrism(
			out,
			point(radius, x),
			point(radius + t, x),
			point(radius + t, y),
			point(radius, y),
			depth,
			"Arch_Curve"
		)
	end

	return out
end

--[=[
	Cuts a door, window or arched doorway into the plain wall under the cursor, by rebuilding the
	wall as separate Parts around the hole.

	@param settings Settings
	@param hit RaycastResult? -- what the cursor is over
	@param arched boolean
	@return { Spec }
	@return string -- what to tell the user
	@return BasePart? -- the wall to delete when the opening is built
]=]
function Builders.Opening(settings: Settings, hit: RaycastResult?, arched: boolean): ({ Spec }, string, BasePart?)
	local out: { Spec } = {}
	local wall = hit and hit.Instance

	if not hit or not wall or not Geometry.IsPlainBlock(wall) then
		return out, "Click a rectangular Part wall (not a mesh, union, or wedge).", nil
	end

	local p = wall :: Part

	if #p:GetChildren() > 0 then
		return out, "Use an undecorated wall. Openings replace the wall with new Parts.", nil
	end

	if p.Locked then
		return out, "Unlock the wall before creating an opening.", nil
	end

	local cf = p.CFrame
	local size = p.Size

	if size.Z > size.X then
		cf = cf * CFrame.Angles(0, math.pi / 2, 0)
		size = Vector3.new(size.Z, size.Y, size.X)
	end

	local w, h = settings.OpenWidth, settings.OpenHeight
	local sill = if arched then 0 else settings.Sill

	if arched and h < w / 2 then
		return out, "Arch height must be at least half the opening width.", nil
	end

	local localHit = cf:PointToObjectSpace(hit.Position)
	local x = Snap.Round(localHit.X, settings.Grid)
	local bottom = -size.Y / 2 + sill
	local top = bottom + h
	local left, right = x - w / 2, x + w / 2

	if left <= -size.X / 2 + 0.01 or right >= size.X / 2 - 0.01 or sill < 0 or top > size.Y / 2 + 0.001 then
		return out, "Opening must fit inside the wall, with wall remaining on both sides.", nil
	end

	add(
		out,
		Vector3.new(left + size.X / 2, size.Y, size.Z),
		cf * CFrame.new((-size.X / 2 + left) / 2, 0, 0),
		"Opening_Left",
		p
	)
	add(
		out,
		Vector3.new(size.X / 2 - right, size.Y, size.Z),
		cf * CFrame.new((right + size.X / 2) / 2, 0, 0),
		"Opening_Right",
		p
	)

	if arched then
		local radius = w / 2
		local spring = bottom + h - radius
		local count = math.floor(settings.ArchSegments)

		for i = 0, count - 1 do
			local from = math.pi - i * math.pi / count
			local to = math.pi - (i + 1) * math.pi / count
			local x1, y1 = x + radius * math.cos(from), spring + radius * math.sin(from)
			local x2, y2 = x + radius * math.cos(to), spring + radius * math.sin(to)

			quadPrism(
				out,
				cf:PointToWorldSpace(Vector3.new(x1, y1, 0)),
				cf:PointToWorldSpace(Vector3.new(x2, y2, 0)),
				cf:PointToWorldSpace(Vector3.new(x2, size.Y / 2, 0)),
				cf:PointToWorldSpace(Vector3.new(x1, size.Y / 2, 0)),
				size.Z,
				"Arch_Header",
				p
			)
		end
	else
		add(
			out,
			Vector3.new(w, size.Y / 2 - top, size.Z),
			cf * CFrame.new(x, (top + size.Y / 2) / 2, 0),
			"Opening_Header",
			p
		)
	end

	if sill > 0 then
		add(out, Vector3.new(w, sill, size.Z), cf * CFrame.new(x, -size.Y / 2 + sill / 2, 0), "Opening_Sill", p)
	end

	return out, "Click to replace this wall with an opening. Undo restores the original wall.", p
end

--[=[
	Works out which local axis a face normal points along. Used to grow a block out of that face.

	@param part BasePart
	@param normal Vector3 -- world-space face normal
	@return number -- 1, 2 or 3 for the part's X, Y or Z axis
	@return number -- 1 or -1, the side of that axis
]=]
function Builders.FaceAxis(part: BasePart, normal: Vector3): (number, number)
	local n = part.CFrame:VectorToObjectSpace(normal)
	local axis = 1

	if math.abs(n.Y) > math.abs(n.X) then
		axis = 2
	end

	if math.abs(n.Z) > math.abs(if axis == 1 then n.X else n.Y) then
		axis = 3
	end

	local component = if axis == 1 then n.X elseif axis == 2 then n.Y else n.Z

	return axis, if component >= 0 then 1 else -1
end

--[=[
	A block of the same size as a face, grown outward from that face.

	@param settings Settings
	@param part BasePart -- the block being extended
	@param normal Vector3 -- world-space normal of the face
	@param distance number? -- how far to grow; the panel's Extend setting when left out
	@return { Spec }
]=]
function Builders.Extend(settings: Settings, part: BasePart, normal: Vector3, distance: number?): { Spec }
	local out: { Spec } = {}
	local axis, side = Builders.FaceAxis(part, normal)
	local unit = if axis == 1 then Vector3.xAxis elseif axis == 2 then Vector3.yAxis else Vector3.zAxis
	local old = if axis == 1 then part.Size.X elseif axis == 2 then part.Size.Y else part.Size.Z
	local length = distance or settings.Extend
	local size = if axis == 1
		then Vector3.new(length, part.Size.Y, part.Size.Z)
		elseif axis == 2 then Vector3.new(part.Size.X, length, part.Size.Z)
		else Vector3.new(part.Size.X, part.Size.Y, length)

	add(out, size, part.CFrame * CFrame.new(unit * side * (old + length) / 2), "FaceExtension", part)

	return out
end

--[=[
	Copies of the source selection, seated flush on the surface under the cursor.

	@param settings Settings
	@param hit RaycastResult? -- what the cursor is over
	@param source Source? -- the selection being stamped
	@return { Spec }
	@return string -- what to tell the user
	@return CFrame? -- where the source's pivot lands
]=]
function Builders.Place(settings: Settings, hit: RaycastResult?, source: Source?): ({ Spec }, string, CFrame?)
	local out: { Spec } = {}

	if not hit or not source then
		return out, "Select an object, then choose Stamp copies.", nil
	end

	for _, part in source.Parts do
		if not part:IsDescendantOf(workspace) then
			return out, "Selection changed or was removed. Choose Stamp copies again.", nil
		end
	end

	local rot = CFrame.Angles(0, math.rad(settings.Yaw), 0)
	local normal = hit.Normal

	if settings.Align then
		local reference = if math.abs(normal.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
		local right = reference:Cross(normal).Unit

		rot = CFrame.fromMatrix(Vector3.zero, right, normal, right:Cross(normal)) * rot
	end

	-- Project the rotated bounding box onto the hit normal to seat it flush.
	local radius = (
		math.abs(normal:Dot(rot.RightVector)) * source.Size.X
		+ math.abs(normal:Dot(rot.UpVector)) * source.Size.Y
		+ math.abs(normal:Dot(rot.LookVector)) * source.Size.Z
	) / 2
	local target = CFrame.new(hit.Position + normal * (radius + settings.Offset)) * rot

	for _, part in source.Parts do
		add(out, part.Size, target * source.Pivot:ToObjectSpace(part.CFrame), part.Name)
	end

	return out, "Click to place a copy flush to this surface. Yaw and offset are in the panel.", target
end

return Builders
