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
	Adds a square pillar standing on the floor at base, turned to match a wall that runs along dir.
]]
local function pillar(out: { Spec }, base: Vector3, dir: Vector3, width: number, height: number)
	local center = base + Vector3.new(0, height * 0.5, 0)

	add(out, Vector3.new(width, height, width), CFrame.lookAt(center, center + dir), "Pillar")
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
	source: BasePart?,
	overlap: number?
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
			local extra = overlap or 0
			local center = (foot + endPoint) * 0.5 + rise * 0.5 + back * (extra / 2)

			add(
				out,
				Vector3.new(depth, height, run.Magnitude + extra),
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
	Adds fence posts and two rails from a to b. The end posts can be left out when a neighbour has them.
]]
local function fenceRun(
	out: { Spec },
	a: Vector3,
	b: Vector3,
	height: number,
	spacing: number,
	startPost: boolean,
	endPost: boolean
)
	local d = b - a
	local length = d.Magnitude

	if length < 0.05 then
		return
	end

	local dir = d.Unit
	local count = math.max(1, math.round(length / math.max(0.5, spacing)))

	for i = 0, count do
		if (i > 0 or startPost) and (i < count or endPost) then
			local center = a + dir * (length * i / count) + Vector3.new(0, height * 0.5, 0)

			add(out, Vector3.new(0.5, height, 0.5), CFrame.lookAt(center, center + dir), "FencePost")
		end
	end

	local middle = (a + b) * 0.5

	for _, fraction in { 0.85, 0.45 } do
		local center = middle + Vector3.new(0, height * fraction, 0)

		add(out, Vector3.new(0.3, 0.4, length), CFrame.lookAt(center, center + dir), "FenceRail")
	end
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

--[[
	Adds the curved roof of an arched corridor: quads that follow the half circle, each extruded the
	whole length along the frame's depth.
]]
local function archRoof(out: { Spec }, cf: CFrame, settings: Settings, length: number)
	local radius = settings.Width / 2
	local t = settings.Thickness
	local h = math.max(0.1, settings.Height - radius)
	local count = math.max(2, math.floor(settings.ArchSegments))

	local function point(r: number, angle: number): Vector3
		return cf:PointToWorldSpace(Vector3.new(r * math.cos(angle), h + r * math.sin(angle), 0))
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
			length,
			"ArchedCeiling"
		)
	end
end

--[=[
	@param settings Settings
	@return { Strip } -- the floor and the two side walls of an arched corridor
]=]
function Builders.ArchedStrips(settings: Settings): { Strip }
	local w, t, f = settings.Width, settings.Thickness, settings.Floor
	local h = math.max(0.1, settings.Height - w / 2)
	local offset = (w + t) / 2

	return {
		{ key = "Floor", name = "Floor", low = -w / 2 - t, high = w / 2 + t, rise = -f / 2, height = f },
		{ key = "Right", name = "CorridorWall", low = offset - t / 2, high = offset + t / 2, rise = h / 2, height = h },
		{
			key = "Left",
			name = "CorridorWall",
			low = -offset - t / 2,
			high = -offset + t / 2,
			rise = h / 2,
			height = h,
		},
	}
end

--[=[
	A corridor with a rounded ceiling: a floor, two straight side walls, and a half-circle vault above
	them that spans the clear width. The panel height is the total height at the centre, arch included,
	so the side walls are that height minus the radius of the vault.

	@param settings Settings
	@param a Vector3 -- the start
	@param b Vector3 -- the end
	@return { Spec }
]=]
function Builders.ArchedCorridor(settings: Settings, a: Vector3, b: Vector3, joinDir: Vector3?): { Spec }
	local out: { Spec } = {}
	local d = b - a
	local length = d.Magnitude
	local flat = Vector3.new(d.X, 0, d.Z)

	if length < 0.05 or flat.Magnitude < 0.05 then
		return out
	end

	local up = Vector3.yAxis
	local across = flat.Unit:Cross(up).Unit
	local w, t, f = settings.Width, settings.Thickness, settings.Floor
	local h = math.max(0.1, settings.Height - w / 2)
	local dir = flat.Unit
	local strips = Builders.ArchedStrips(settings)
	local bend = if joinDir then Builders.Bend(a, joinDir, flat, strips, strips) else nil

	if bend then
		for _, spec in bend.beginning do
			table.insert(out, spec)
		end
	end

	--[[
		Adds a block that starts `late` studs after a and runs to b.
	]]
	local function block(key: string, lateral: number, rise: number, width: number, height: number, name: string)
		local late = if bend then bend.start[key] or 0 else 0
		local run = length - late

		if run < 0.05 then
			return
		end

		local center = a + dir * (late + run / 2) + across * lateral + Vector3.new(0, rise, 0)

		add(out, Vector3.new(width, height, run), CFrame.lookAt(center, center + dir), name)
	end

	block("Floor", 0, -f / 2, w + 2 * t, f, "Floor")
	block("Right", (w + t) / 2, h / 2, t, h, "CorridorWall")
	block("Left", -(w + t) / 2, h / 2, t, h, "CorridorWall")

	local middle = (a + b) * 0.5
	local cf = CFrame.fromMatrix(middle, across, up, across:Cross(up))

	archRoof(out, cf, settings, length)

	return out
end

export type ArchWedge = {
	specs: { Spec },
	cutter: CFrame,
	cutterSize: Vector3,
}

--[=[
	The curved roof needs a corner of its own where two arched corridors meet. Each side gets the
	arch carried on past the joint, to be cut flat along the line that bisects the bend.

	@param settings Settings
	@param joint Vector3 -- where the two corridors meet, at floor level
	@param prevDir Vector3
	@param dir Vector3
	@return { ArchWedge } -- two arch pieces, each with the box that is cut out of it
]=]
function Builders.ArchedBend(settings: Settings, joint: Vector3, prevDir: Vector3, dir: Vector3): { ArchWedge }
	local u = Vector3.new(prevDir.X, 0, prevDir.Z)
	local v = Vector3.new(dir.X, 0, dir.Z)
	local wedges: { ArchWedge } = {}

	if u.Magnitude < 0.001 or v.Magnitude < 0.001 then
		return wedges
	end

	u, v = u.Unit, v.Unit

	local turn = math.acos(math.clamp(u:Dot(v), -1, 1))

	if turn < math.rad(2) then
		return wedges
	end

	local reach = math.tan(math.min(turn, math.rad(170)) / 2) * (settings.Width / 2 + settings.Thickness)
	local bisector = (u + v).Unit
	local big = 400

	for _, side in { 1, -1 } do
		local heading = if side == 1 then u else v
		local forward = if side == 1 then 1 else -1
		local center = joint + heading * forward * (reach / 2)
		local cf = CFrame.fromMatrix(
			center,
			heading:Cross(Vector3.yAxis),
			Vector3.yAxis,
			heading:Cross(Vector3.yAxis):Cross(Vector3.yAxis)
		)
		local specs: { Spec } = {}

		archRoof(specs, cf, settings, reach)

		local away = bisector * side

		table.insert(wedges, {
			specs = specs,
			cutter = CFrame.lookAt(joint + away * (big / 2 + 0.02), joint + away * (big + 0.02)),
			cutterSize = Vector3.new(big, big, big),
		})
	end

	return wedges
end

--[=[
	@param settings Settings
	@param a Vector3 -- one corner, at the height of the top of the floor
	@param b Vector3 -- the opposite corner
	@return { Spec } -- one flat slab as thick as the panel's floor thickness
]=]
function Builders.Floor(settings: Settings, a: Vector3, b: Vector3): { Spec }
	local out: { Spec } = {}
	local lo, hi, c = rectangle(a, b)
	local f = settings.Floor

	if hi.X - lo.X < 0.05 or hi.Z - lo.Z < 0.05 then
		return out
	end

	add(out, Vector3.new(hi.X - lo.X, f, hi.Z - lo.Z), CFrame.new(c - Vector3.new(0, f / 2, 0)), "Floor")

	return out
end

--[=[
	@param settings Settings
	@param a Vector3 -- one corner
	@param b Vector3 -- the opposite corner
	@return { Spec } -- one thick slab, a margin wider than the corners, standing on a's level
]=]
function Builders.Foundation(settings: Settings, a: Vector3, b: Vector3): { Spec }
	local out: { Spec } = {}
	local lo, hi, c = rectangle(a, b)
	local m, h = settings.FoundationMargin, settings.FoundationHeight
	local w, d = hi.X - lo.X + 2 * m, hi.Z - lo.Z + 2 * m

	if hi.X - lo.X < 0.05 or hi.Z - lo.Z < 0.05 then
		return out
	end

	add(out, Vector3.new(w, h, d), CFrame.new(c + Vector3.new(0, h / 2, 0)), "Foundation")

	return out
end

--[=[
	@param settings Settings
	@param a Vector3 -- one corner
	@param b Vector3 -- the opposite corner
	@return { Spec } -- a floor, four corner posts and, when switched on, a railing between the posts
]=]
function Builders.Porch(settings: Settings, a: Vector3, b: Vector3): { Spec }
	local out: { Spec } = {}
	local lo, hi, c = rectangle(a, b)
	local w, d = hi.X - lo.X, hi.Z - lo.Z
	local f, h = settings.Floor, settings.Height
	local post = 0.8

	if w < 2 * post or d < 2 * post then
		return out
	end

	add(out, Vector3.new(w, f, d), CFrame.new(c - Vector3.new(0, f / 2, 0)), "Floor")

	local inset = post / 2
	local x0, x1, z0, z1 = lo.X + inset, hi.X - inset, lo.Z + inset, hi.Z - inset
	local corners = {
		Vector3.new(x0, a.Y, z0),
		Vector3.new(x1, a.Y, z0),
		Vector3.new(x1, a.Y, z1),
		Vector3.new(x0, a.Y, z1),
	}

	for _, corner in corners do
		add(out, Vector3.new(post, h, post), CFrame.new(corner + Vector3.new(0, h / 2, 0)), "PorchPost")
	end

	if settings.PorchRailing then
		for i = 1, 4 do
			fenceRun(out, corners[i], corners[i % 4 + 1], settings.RailHeight, settings.FenceSpacing, false, false)
		end
	end

	return out
end

--[[
	Adds a square pillar standing at base, turned to face along dir (flat). The top is `top` above base.
]]
local function newel(out: { Spec }, base: Vector3, flatDir: Vector3, top: number, name: string)
	local center = base + Vector3.new(0, top * 0.5, 0)

	add(out, Vector3.new(0.7, top, 0.7), CFrame.lookAt(center, center + flatDir), name)
end

--[=[
	A straight indoor railing from a to b: a handrail on top, thin bars between, a low bottom rail and
	a pillar at each end. When a and b are at different heights it follows the slope, so it fits stairs.

	@param settings Settings
	@param a Vector3 -- the start, on the floor or a stair
	@param b Vector3 -- the end, on the floor or a stair
	@param postAtStart boolean? -- false when the railing before this one already has a pillar there
	@return { Spec }
]=]
function Builders.Railing(settings: Settings, a: Vector3, b: Vector3, postAtStart: boolean?): { Spec }
	local out: { Spec } = {}
	local d = b - a
	local length = d.Magnitude
	local flat = Vector3.new(d.X, 0, d.Z)

	if length < 0.5 or flat.Magnitude < 0.05 then
		return out
	end

	local dir = d.Unit
	local flatDir = flat.Unit
	local height = settings.RailHeight
	local up = Vector3.new(0, 1, 0)

	if postAtStart ~= false then
		newel(out, a, flatDir, height + 0.3, "RailingPillar")
	end

	newel(out, b, flatDir, height + 0.3, "RailingPillar")

	local middle = (a + b) * 0.5

	add(out, Vector3.new(0.4, 0.3, length), CFrame.lookAt(middle + up * height, middle + up * height + dir), "Handrail")
	add(out, Vector3.new(0.3, 0.2, length), CFrame.lookAt(middle + up * 0.3, middle + up * 0.3 + dir), "BottomRail")

	local count = math.max(1, math.round(flat.Magnitude / math.max(0.3, settings.BalusterSpacing)))

	for i = 1, count - 1 do
		local base = a + d * (i / count)
		local center = base + up * (height * 0.5)

		add(out, Vector3.new(0.2, height, 0.2), CFrame.lookAt(center, center + flatDir), "Baluster")
	end

	return out
end

--[=[
	A solid low wall from a to b with a pillar at each end, following the slope when a and b are at
	different heights.

	@param settings Settings
	@param a Vector3
	@param b Vector3
	@param postAtStart boolean? -- false when the wall before this one already has a pillar there
	@return { Spec }
]=]
function Builders.HalfWall(settings: Settings, a: Vector3, b: Vector3, postAtStart: boolean?): { Spec }
	local out: { Spec } = {}
	local d = b - a
	local flat = Vector3.new(d.X, 0, d.Z)

	if d.Magnitude < 0.5 or flat.Magnitude < 0.05 then
		return out
	end

	local flatDir = flat.Unit
	local height = settings.RailHeight
	local up = Vector3.new(0, height, 0)

	if postAtStart ~= false then
		newel(out, a, flatDir, height + 0.3, "HalfWallPillar")
	end

	newel(out, b, flatDir, height + 0.3, "HalfWallPillar")
	quadPrism(out, a, b, b + up, a + up, 0.5, "HalfWall")

	return out
end

--[=[
	@param settings Settings
	@param a Vector3 -- the start point
	@param b Vector3 -- the end point
	@param postAtStart boolean? -- false when the fence before this one already has a post there
	@return { Spec } -- posts and rails running from a to b
]=]
function Builders.Fence(settings: Settings, a: Vector3, b: Vector3, postAtStart: boolean?): { Spec }
	local out: { Spec } = {}

	fenceRun(out, a, b, settings.FenceHeight, settings.FenceSpacing, postAtStart ~= false, true)

	return out
end

--[=[
	Builds a roof over the rectangle between two corners, bigger by the overhang on every side. Gable
	and shed roofs are solid; hip and pyramid roofs are made of sheets; flat is a single slab.

	@param settings Settings
	@param a Vector3 -- one corner, at the height of the top of the walls
	@param b Vector3 -- the opposite corner
	@return { Spec }
]=]
function Builders.Roof(settings: Settings, a: Vector3, b: Vector3): { Spec }
	local out: { Spec } = {}
	local lo, hi, c = rectangle(a, b)

	if hi.X - lo.X < 0.5 or hi.Z - lo.Z < 0.5 then
		return out
	end

	local o, rise, t, y = settings.RoofOverhang, settings.RoofRise, settings.RoofThickness, a.Y
	local x0, x1, z0, z1 = lo.X - o, hi.X + o, lo.Z - o, hi.Z + o
	local w, d = x1 - x0, z1 - z0
	local style = settings.RoofStyle

	if style == "Flat" then
		add(out, Vector3.new(w, t, d), CFrame.new(c.X, y + t / 2, c.Z), "Roof")
	elseif style == "Shed" then
		trianglePrism(out, Vector3.new(x0, y, c.Z), Vector3.new(x1, y, c.Z), Vector3.new(x1, y + rise, c.Z), d, "Roof")
	elseif style == "Pyramid" then
		local apex = Vector3.new(c.X, y + rise, c.Z)
		local p00, p10 = Vector3.new(x0, y, z0), Vector3.new(x1, y, z0)
		local p11, p01 = Vector3.new(x1, y, z1), Vector3.new(x0, y, z1)

		trianglePrism(out, p00, p10, apex, t, "Roof")
		trianglePrism(out, p10, p11, apex, t, "Roof")
		trianglePrism(out, p11, p01, apex, t, "Roof")
		trianglePrism(out, p01, p00, apex, t, "Roof")
	elseif style == "Hip" then
		local p00, p10 = Vector3.new(x0, y, z0), Vector3.new(x1, y, z0)
		local p11, p01 = Vector3.new(x1, y, z1), Vector3.new(x0, y, z1)

		if w >= d then
			local r0 = Vector3.new(x0 + d / 2, y + rise, c.Z)
			local r1 = Vector3.new(x1 - d / 2, y + rise, c.Z)

			quadPrism(out, p00, p10, r1, r0, t, "Roof")
			quadPrism(out, p01, p11, r1, r0, t, "Roof")
			trianglePrism(out, p00, p01, r0, t, "Roof")
			trianglePrism(out, p10, p11, r1, t, "Roof")
		else
			local r0 = Vector3.new(c.X, y + rise, z0 + w / 2)
			local r1 = Vector3.new(c.X, y + rise, z1 - w / 2)

			quadPrism(out, p00, p01, r1, r0, t, "Roof")
			quadPrism(out, p10, p11, r1, r0, t, "Roof")
			trianglePrism(out, p00, p10, r0, t, "Roof")
			trianglePrism(out, p01, p11, r1, t, "Roof")
		end
	elseif w >= d then
		trianglePrism(out, Vector3.new(c.X, y, z0), Vector3.new(c.X, y, z1), Vector3.new(c.X, y + rise, c.Z), w, "Roof")
	else
		trianglePrism(out, Vector3.new(x0, y, c.Z), Vector3.new(x1, y, c.Z), Vector3.new(c.X, y + rise, c.Z), d, "Roof")
	end

	return out
end

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

export type Cutter = { cf: CFrame, size: Vector3, cylinder: boolean, thickness: number? }

export type Strip = {
	key: string,
	name: string,
	low: number,
	high: number,
	rise: number,
	height: number,
}

export type Bend = {
	finish: { [string]: number },
	start: { [string]: number },
	ending: { Spec },
	beginning: { Spec },
}

--[=[
	@param settings Settings
	@return { Strip } -- the one strip a plain wall is made of, across its thickness
]=]
function Builders.WallStrips(settings: Settings): { Strip }
	local t, h = settings.Thickness, settings.Height

	return { { key = "Wall", name = "Wall", low = -t / 2, high = t / 2, rise = h / 2, height = h } }
end

--[=[
	@param settings Settings
	@return { Strip } -- the floor, the two side walls and the optional ceiling of a corridor, each across its own width
]=]
function Builders.CorridorStrips(settings: Settings): { Strip }
	local w, t, h, f = settings.Width, settings.Thickness, settings.Height, settings.Floor
	local offset = (w + t) / 2
	local strips: { Strip } = {
		{ key = "Floor", name = "Floor", low = -w / 2 - t, high = w / 2 + t, rise = -f / 2, height = f },
		{ key = "Right", name = "CorridorWall", low = offset - t / 2, high = offset + t / 2, rise = h / 2, height = h },
		{
			key = "Left",
			name = "CorridorWall",
			low = -offset - t / 2,
			high = -offset + t / 2,
			rise = h / 2,
			height = h,
		},
	}

	if settings.Roof then
		table.insert(
			strips,
			{ key = "Ceiling", name = "Ceiling", low = -w / 2 - t, high = w / 2 + t, rise = h + f / 2, height = f }
		)
	end

	return strips
end

--[=[
	Closes the corner where a wall or corridor continues another, with an exact miter and no
	overlap. Each strip (a wall, a floor) is cut along the line that bisects the bend: the strip
	keeps a plain rectangle up to the shorter end of that cut, and a small triangular prism fills the
	rest. A right angle needs no triangle: the earlier strip runs on to cover the corner square. The earlier segment's rectangles move by `finish` and the new segment's by `start`; the
	triangles go in `ending` and `beginning`.

	@param joint Vector3 -- where the two segments meet, at the base level
	@param prevDir Vector3 -- the direction of the earlier segment
	@param dir Vector3 -- the direction of the new segment
	@param prevStrips { Strip } -- the strips of the earlier segment
	@param strips { Strip } -- the strips of the new segment
	@return Bend -- `finish` and `start` are keyed by strip key, in studs along each segment's direction
]=]
function Builders.Bend(joint: Vector3, prevDir: Vector3, dir: Vector3, prevStrips: { Strip }, strips: { Strip }): Bend
	local bend: Bend = { finish = {}, start = {}, ending = {}, beginning = {} }
	local u = Vector3.new(prevDir.X, 0, prevDir.Z)
	local v = Vector3.new(dir.X, 0, dir.Z)

	if u.Magnitude < 0.001 or v.Magnitude < 0.001 then
		return bend
	end

	u, v = u.Unit, v.Unit

	local turn = math.acos(math.clamp(u:Dot(v), -1, 1))

	if turn < math.rad(2) then
		return bend
	end

	local ru = u:Cross(Vector3.yAxis)
	local rv = v:Cross(Vector3.yAxis)
	local turning = if v:Dot(ru) > 0 then 1 else -1
	local slope = turning * math.tan(math.min(turn, math.rad(170)) / 2)
	local square = math.abs(turn - math.pi / 2) < math.rad(1)

	for _, strip in prevStrips do
		local atLow, atHigh = -slope * strip.low, -slope * strip.high
		local short, long = math.min(atLow, atHigh), math.max(atLow, atHigh)
		local shortSide = if atLow < atHigh then strip.low else strip.high
		local longSide = if atLow < atHigh then strip.high else strip.low
		local lift = Vector3.new(0, strip.rise, 0)

		bend.finish[strip.key] = if square then long else short

		if not square and long - short > 0.01 then
			trianglePrism(
				bend.ending,
				joint + u * short + ru * shortSide + lift,
				joint + u * short + ru * longSide + lift,
				joint + u * long + ru * longSide + lift,
				strip.height,
				strip.name
			)
		end
	end

	for _, strip in strips do
		local atLow, atHigh = slope * strip.low, slope * strip.high
		local early, late = math.min(atLow, atHigh), math.max(atLow, atHigh)
		local earlySide = if atLow < atHigh then strip.low else strip.high
		local lateSide = if atLow < atHigh then strip.high else strip.low
		local lift = Vector3.new(0, strip.rise, 0)

		bend.start[strip.key] = late

		if not square and late - early > 0.01 then
			trianglePrism(
				bend.beginning,
				joint + v * early + rv * earlySide + lift,
				joint + v * late + rv * earlySide + lift,
				joint + v * late + rv * lateSide + lift,
				strip.height,
				strip.name
			)
		end
	end

	return bend
end

--[=[
	@param settings Settings
	@param a Vector3
	@param b Vector3
	@param corridor boolean -- true for a floored corridor, false for a single wall
	@param pillarAtStart boolean? -- false when the start already has a pillar from the wall before it
	@param joinDir Vector3? -- the direction of the wall or corridor this one continues, so the corner closes without a notch
	@return { Spec }
]=]
function Builders.Path(
	settings: Settings,
	a: Vector3,
	b: Vector3,
	corridor: boolean,
	pillarAtStart: boolean?,
	joinDir: Vector3?
): { Spec }
	local out: { Spec } = {}
	local d = b - a
	local length = d.Magnitude

	if length < 0.05 then
		return out
	end

	if not corridor then
		if not settings.PillaredWalls then
			local start = a

			if joinDir then
				local strips = Builders.WallStrips(settings)
				local bend = Builders.Bend(a, joinDir, d, strips, strips)

				start = a + d.Unit * (bend.start.Wall or 0)

				for _, spec in bend.beginning do
					table.insert(out, spec)
				end
			end

			segment(out, start, b, settings.Thickness, settings.Height, "Wall")

			return out
		end

		local dir = d.Unit
		local width = math.max(settings.PillarWidth, settings.Thickness)

		if pillarAtStart ~= false then
			pillar(out, a, dir, width, settings.Height)
		end

		pillar(out, b, dir, width, settings.Height)

		if length > width + 0.05 then
			segment(out, a + dir * (width / 2), b - dir * (width / 2), settings.Thickness, settings.Height, "Wall")
		end

		return out
	end

	local w, t, h, f = settings.Width, settings.Thickness, settings.Height, settings.Floor
	local dir = d.Unit
	local right = dir:Cross(Vector3.yAxis)
	local strips = Builders.CorridorStrips(settings)
	local bend = if joinDir then Builders.Bend(a, joinDir, d, strips, strips) else nil

	if bend then
		for _, spec in bend.beginning do
			table.insert(out, spec)
		end
	end

	--[[
		Adds a block along the corridor that starts `late` studs after a and runs to b.
	]]
	local function block(late: number, lateral: number, rise: number, width: number, height: number, name: string)
		local run = length - late

		if run < 0.05 then
			return
		end

		local center = a + dir * (late + run / 2) + right * lateral + Vector3.new(0, rise, 0)

		add(out, Vector3.new(width, height, run), CFrame.lookAt(center, center + d), name)
	end

	local function late(key: string): number
		return if bend then bend.start[key] or 0 else 0
	end

	block(late("Floor"), 0, -f / 2, w + 2 * t, f, "Floor")
	block(late("Right"), (w + t) / 2, h / 2, t, h, "CorridorWall")
	block(late("Left"), -(w + t) / 2, h / 2, t, h, "CorridorWall")

	if settings.Roof then
		block(late("Ceiling"), 0, h + f / 2, w + 2 * t, f, "Ceiling")
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
	@param base Vector3 -- the point the pillar stands on
	@return { Spec } -- one square pillar as tall as the panel height
]=]
function Builders.Pillar(settings: Settings, base: Vector3): { Spec }
	local out: { Spec } = {}
	local w, h = settings.PillarWidth, settings.Height

	add(out, Vector3.new(w, h, w), CFrame.new(base + Vector3.new(0, h / 2, 0)), "Pillar")

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
	@param dims { Width: number, Height: number, Sill: number } -- the opening to cut
	@param hit RaycastResult? -- what the cursor is over
	@param arched boolean
	@return { Spec }
	@return string -- what to tell the user
	@return BasePart? -- the wall to delete when the opening is built
]=]
function Builders.Opening(
	settings: Settings,
	dims: { Width: number, Height: number, Sill: number, Panel: boolean? },
	hit: RaycastResult?,
	shape: string,
	depth: number?
): ({ Spec }, string, BasePart?, { cf: CFrame, size: Vector3 }?, { Cutter }?)
	local out: { Spec } = {}
	local wall = hit and hit.Instance
	local plain = Geometry.IsPlainBlock(wall)
	local carvable = wall ~= nil
		and wall:IsA("BasePart")
		and not wall:IsA("Terrain")
		and (wall.ClassName == "UnionOperation" or wall.ClassName == "Part")

	if not hit or not wall or not (plain or carvable) then
		return out, "Click a Part or union wall (not a mesh, wedge or terrain).", nil
	end

	local carve = not plain

	local p = wall :: Part

	for _, child in p:GetChildren() do
		if not (child:IsA("Texture") and child.Name == "VluxGridTexture") then
			return out, "Use an undecorated wall. Openings replace the wall with new Parts.", nil
		end
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

	local arched = shape == "Arch"
	local w, h = dims.Width, dims.Height
	local sill = if arched then 0 else dims.Sill

	if arched and h < w / 2 then
		return out, "Arch height must be at least half the opening width.", nil
	end

	if carve and shape == "Triangle" then
		return out, "The triangle window needs a plain Part wall. Rooms cut by a neighbour are unions.", nil
	end

	local localHit = cf:PointToObjectSpace(hit.Position)
	local x = Snap.Round(localHit.X, settings.Grid)
	local bottom = -size.Y / 2 + sill
	local top = bottom + h
	local left, right = x - w / 2, x + w / 2

	if left <= -size.X / 2 + 0.01 or right >= size.X / 2 - 0.01 or sill < 0 or top > size.Y / 2 + 0.001 then
		return out, "Opening must fit inside the wall, with wall remaining on both sides.", nil
	end

	if dims.Panel and shape == "Rect" and not (depth and depth < size.Z - 0.01) then
		add(out, Vector3.new(w, h, math.min(size.Z, 0.3)), cf * CFrame.new(x, bottom + h / 2, 0), "Door_Panel")
	end

	if carve then
		local reach = if depth and depth < size.Z - 0.01 then depth else size.Z + 0.2
		local near = if localHit.Z >= 0 then 1 else -1
		local zMid = if depth and depth < size.Z - 0.01 then near * (size.Z / 2 - reach / 2) else 0
		local cutters: { Cutter } = {}

		if shape == "Circle" then
			local diameter = math.min(w, h)

			table.insert(cutters, {
				cf = cf * CFrame.new(x, bottom + diameter / 2, zMid) * CFrame.Angles(0, math.pi / 2, 0),
				size = Vector3.new(reach, diameter, diameter),
				cylinder = true,
			})
		else
			local boxHeight = if arched then h - w / 2 else h

			table.insert(cutters, {
				cf = cf * CFrame.new(x, bottom + boxHeight / 2, zMid),
				size = Vector3.new(w, boxHeight, reach),
				cylinder = false,
			})

			if arched then
				table.insert(cutters, {
					cf = cf * CFrame.new(x, bottom + h - w / 2, zMid) * CFrame.Angles(0, math.pi / 2, 0),
					size = Vector3.new(reach, w, w),
					cylinder = true,
				})
			end
		end

		local openHeight = if shape == "Circle" then math.min(w, h) else h
		local openWidth = if shape == "Circle" then math.min(w, h) else w
		local shown = {
			cf = cf * CFrame.new(x, bottom + openHeight / 2, near * (size.Z / 2 - math.min(reach, size.Z) / 2)),
			size = Vector3.new(openWidth, openHeight, math.min(reach, size.Z)),
		}

		return out, "Click to cut this wall. Undo restores it.", p, shown, cutters
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

	if shape == "Circle" then
		local radius = math.min(w, h) / 2
		local cy = bottom + radius
		local count = math.max(8, math.floor(settings.ArchSegments) * 2)
		local wallTop, wallBottom = size.Y / 2, -size.Y / 2

		for i = 0, count - 1 do
			local from = math.pi - i * math.pi / count
			local to = math.pi - (i + 1) * math.pi / count

			for _, side in { 1, -1 } do
				local x1, y1 = x + radius * math.cos(from), cy + side * radius * math.sin(from)
				local x2, y2 = x + radius * math.cos(to), cy + side * radius * math.sin(to)
				local edge = if side == 1 then wallTop else wallBottom

				quadPrism(
					out,
					cf:PointToWorldSpace(Vector3.new(x1, y1, 0)),
					cf:PointToWorldSpace(Vector3.new(x2, y2, 0)),
					cf:PointToWorldSpace(Vector3.new(x2, edge, 0)),
					cf:PointToWorldSpace(Vector3.new(x1, edge, 0)),
					size.Z,
					if side == 1 then "Circle_Upper" else "Circle_Lower",
					p
				)
			end
		end
	elseif shape == "Triangle" then
		local apex = Vector3.new(x, top, 0)
		local wallTop = size.Y / 2

		for _, side in { -1, 1 } do
			local corner = Vector3.new(x + side * w / 2, bottom, 0)
			local a = if side == -1 then corner else apex
			local b = if side == -1 then apex else corner

			quadPrism(
				out,
				cf:PointToWorldSpace(a),
				cf:PointToWorldSpace(b),
				cf:PointToWorldSpace(Vector3.new(b.X, wallTop, 0)),
				cf:PointToWorldSpace(Vector3.new(a.X, wallTop, 0)),
				size.Z,
				"Triangle_Frame",
				p
			)
		end
	elseif arched then
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

	if depth and depth < size.Z - 0.01 then
		local back = size.Z - depth
		local side = if localHit.Z >= 0 then -1 else 1
		local z = side * (size.Z / 2 - back / 2)

		local function at(px: number, py: number): Vector3
			return cf:PointToWorldSpace(Vector3.new(px, py, z))
		end

		if shape == "Circle" then
			local radius = math.min(w, h) / 2
			local cy = bottom + radius
			local count = math.max(8, math.floor(settings.ArchSegments) * 2)

			for i = 0, count - 1 do
				local from = math.pi - i * math.pi / count
				local to = math.pi - (i + 1) * math.pi / count
				local x1, x2 = x + radius * math.cos(from), x + radius * math.cos(to)
				local s1, s2 = radius * math.sin(from), radius * math.sin(to)

				quadPrism(
					out,
					at(x1, cy + s1),
					at(x2, cy + s2),
					at(x2, cy - s2),
					at(x1, cy - s1),
					back,
					"Opening_Back",
					p
				)
			end
		elseif shape == "Triangle" then
			trianglePrism(out, at(x - w / 2, bottom), at(x, top), at(x + w / 2, bottom), back, "Opening_Back", p)
		elseif arched then
			local radius = w / 2
			local spring = bottom + h - radius
			local count = math.floor(settings.ArchSegments)

			add(
				out,
				Vector3.new(w, spring - bottom, back),
				cf * CFrame.new(x, (bottom + spring) / 2, z),
				"Opening_Back",
				p
			)

			for i = 0, count - 1 do
				local from = math.pi - i * math.pi / count
				local to = math.pi - (i + 1) * math.pi / count
				local x1, y1 = x + radius * math.cos(from), spring + radius * math.sin(from)
				local x2, y2 = x + radius * math.cos(to), spring + radius * math.sin(to)

				quadPrism(out, at(x1, y1), at(x2, y2), at(x2, spring), at(x1, spring), back, "Opening_Back", p)
			end
		else
			add(out, Vector3.new(w, h, back), cf * CFrame.new(x, (bottom + top) / 2, z), "Opening_Back", p)
		end
	end

	local reach = if depth and depth < size.Z - 0.01 then depth else size.Z
	local openHeight = if shape == "Circle" then math.min(w, h) else h
	local openWidth = if shape == "Circle" then math.min(w, h) else w
	local near = if localHit.Z >= 0 then 1 else -1
	local cut = {
		cf = cf * CFrame.new(x, bottom + openHeight / 2, near * (size.Z / 2 - reach / 2)),
		size = Vector3.new(openWidth, openHeight, reach),
	}

	return out, "Click to replace this wall with an opening. Undo restores the original wall.", p, cut
end

--[=[
	The tool that cuts a polygon out of a wall: each triangle of the polygon is extruded through
	the wall as a pair of wedges, to be subtracted from it.

	@param corners { Vector3 } -- the polygon's corners, on the face of the wall
	@param triangles { { number } } -- triples of indexes into corners
	@param depth number -- how far the cut reaches, centred on the corners moved by `shift`
	@param shift Vector3 -- where the corners move to, into the middle of the wall
	@return { Spec }
]=]
function Builders.CutShape(corners: { Vector3 }, triangles: { { number } }, depth: number, shift: Vector3): { Spec }
	local out: { Spec } = {}

	for _, t in triangles do
		local a, b, c = corners[t[1]] + shift, corners[t[2]] + shift, corners[t[3]] + shift
		local middle = (a + b + c) / 3

		--[[ Each triangle is a hair bigger so neighbours overlap and no sliver is left between them. ]]
		local function grow(p: Vector3): Vector3
			local away = p - middle

			return if away.Magnitude > 0.001 then p + away.Unit * 0.03 else p
		end

		trianglePrism(out, grow(a), grow(b), grow(c), depth, "Cut", nil, 0.03)
	end

	return out
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
	@param settings Settings
	@return { Strip } -- the floor, ceiling and two side sheets of a vent, measured from its bottom
]=]
function Builders.VentStrips(settings: Settings): { Strip }
	local w, t = settings.VentSize, settings.VentThickness
	local inner = math.max(0.05, w - 2 * t)

	return {
		{ key = "Floor", name = "VentFloor", low = -w / 2, high = w / 2, rise = t / 2, height = t },
		{ key = "Ceiling", name = "VentCeiling", low = -w / 2, high = w / 2, rise = w - t / 2, height = t },
		{ key = "Right", name = "VentWall", low = w / 2 - t, high = w / 2, rise = w / 2, height = inner },
		{ key = "Left", name = "VentWall", low = -w / 2, high = -w / 2 + t, rise = w / 2, height = inner },
	}
end

--[=[
	A level vent from a to b. Both points are at the bottom of the duct. When it continues another
	vent its corner is closed the same way a corridor's is.

	@param settings Settings
	@param a Vector3
	@param b Vector3
	@param joinDir Vector3? -- the direction of the vent this one continues
	@return { Spec }
]=]
function Builders.VentRun(settings: Settings, a: Vector3, b: Vector3, joinDir: Vector3?): { Spec }
	local out: { Spec } = {}
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)

	if flat.Magnitude < 0.05 then
		return out
	end

	local up = Vector3.yAxis
	local dir = flat.Unit
	local across = dir:Cross(up).Unit
	local strips = Builders.VentStrips(settings)
	local bend = if joinDir then Builders.Bend(a, joinDir, flat, strips, strips) else nil

	if bend then
		for _, spec in bend.beginning do
			table.insert(out, spec)
		end
	end

	for _, strip in strips do
		local late = if bend then bend.start[strip.key] or 0 else 0
		local run = flat.Magnitude - late

		if run >= 0.05 then
			local center = a + dir * (late + run / 2) + across * ((strip.low + strip.high) / 2) + up * strip.rise

			add(
				out,
				Vector3.new(strip.high - strip.low, strip.height, run),
				CFrame.lookAt(center, center + dir),
				strip.name
			)
		end
	end

	return out
end

--[[
	@return CFrame -- a frame at the middle of the duct from a to b, looking along it, with Y as the duct's up
]]
local function ductFrame(a: Vector3, b: Vector3): CFrame?
	local d = b - a

	if d.Magnitude < 0.05 then
		return nil
	end

	local dir = d.Unit
	local reference = if math.abs(dir.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local right = dir:Cross(reference).Unit
	local up = right:Cross(dir)

	return CFrame.fromMatrix((a + b) * 0.5, right, up, -dir)
end

--[[
	@return CFrame -- a frame looking along the duct for the cuts at its ends: a sloped duct gets an upright one that looks along its horizontal direction, so the hole it cuts is not tilted
]]
local function ductEndFrame(a: Vector3, b: Vector3): CFrame
	local d = b - a

	if math.abs(d.Unit.Y) > 0.99 then
		return ductFrame(a, b) :: CFrame
	end

	local flat = Vector3.new(d.X, 0, d.Z).Unit

	return CFrame.lookAt((a + b) * 0.5, (a + b) * 0.5 + flat)
end

--[=[
	A straight vent in any direction, for slopes and vertical shafts. The points are on the middle
	line of the duct.

	@param settings Settings
	@param a Vector3
	@param b Vector3
	@return { Spec }
]=]
function Builders.VentDuct(settings: Settings, a: Vector3, b: Vector3): { Spec }
	local out: { Spec } = {}
	local frame = ductFrame(a, b)

	if not frame then
		return out
	end

	local w, t = settings.VentSize, settings.VentThickness
	local length = (b - a).Magnitude
	local inner = math.max(0.05, w - 2 * t)
	local reach = w / 2 - t / 2
	local dirN = (b - a).Unit

	if math.abs(dirN.Y) < 0.99 then
		local flat = Vector3.new(dirN.X, 0, dirN.Z).Unit
		local across = flat:Cross(Vector3.yAxis).Unit
		local gap = w / 2 - t

		local cosine = math.max(0.1, Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude / length)
		local slant = t / cosine

		for _, floor in { true, false } do
			local y1 = if floor then -gap else gap + slant
			local y2 = if floor then -gap - slant else gap

			quadPrism(
				out,
				a + Vector3.new(0, y1, 0),
				b + Vector3.new(0, y1, 0),
				b + Vector3.new(0, y2, 0),
				a + Vector3.new(0, y2, 0),
				w,
				if floor then "VentFloor" else "VentCeiling"
			)
		end

		for _, side in { -1, 1 } do
			local lateral = across * (side * reach)

			quadPrism(
				out,
				a + lateral + Vector3.new(0, -gap, 0),
				b + lateral + Vector3.new(0, -gap, 0),
				b + lateral + Vector3.new(0, gap, 0),
				a + lateral + Vector3.new(0, gap, 0),
				t,
				"VentWall"
			)
		end

		return out
	end

	add(out, Vector3.new(w, t, length), frame * CFrame.new(0, -reach, 0), "VentFloor")
	add(out, Vector3.new(w, t, length), frame * CFrame.new(0, reach, 0), "VentCeiling")
	add(out, Vector3.new(t, inner, length), frame * CFrame.new(reach, 0, 0), "VentWall")
	add(out, Vector3.new(t, inner, length), frame * CFrame.new(-reach, 0, 0), "VentWall")

	return out
end

--[=[
	The shapes that are cut out of whatever a vent passes through: a box the size of the duct along
	its length, and the opening at each end, reaching a little into the wall behind it.

	@param settings Settings
	@param a Vector3 -- one end, on the middle line
	@param b Vector3 -- the other end
	@return { Cutter }
]=]
function Builders.VentCutters(settings: Settings, a: Vector3, b: Vector3): { Cutter }
	local frame = ductFrame(a, b)
	local cutters: { Cutter } = {}

	if not frame then
		return cutters
	end

	local w, t = settings.VentSize, settings.VentThickness
	local length = (b - a).Magnitude
	local inner = math.max(0.05, w - 2 * t)

	table.insert(cutters, { cf = frame, size = Vector3.new(w - 0.04, w - 0.04, length), cylinder = false })

	for _, side in { -1, 1 } do
		local endPoint = if side == 1 then b else a
		local level = ductEndFrame(a, b)

		table.insert(cutters, {
			cf = level + (endPoint - level.Position),
			size = Vector3.new(inner, inner, 2.5),
			cylinder = false,
		})
	end

	return cutters
end

--[=[
	The openings that let a vent join the side of another vent: a box at each end that starts just
	inside the vent and reaches out past its end, far enough to cut through the wall it ends in.

	@param settings Settings
	@param a Vector3
	@param b Vector3
	@return { Cutter }
]=]
function Builders.VentJoinCutters(settings: Settings, a: Vector3, b: Vector3): { Cutter }
	local frame = ductFrame(a, b)
	local cutters: { Cutter } = {}

	if not frame then
		return cutters
	end

	local w, t = settings.VentSize, settings.VentThickness
	local inner = math.max(0.05, w - 2 * t)
	local reach = w / 2 + 0.4

	for _, side in { -1, 1 } do
		local endPoint = if side == 1 then b else a
		local level = ductEndFrame(a, b)

		table.insert(cutters, {
			cf = level + level.LookVector * side * (reach / 2 - 0.1) + (endPoint - level.Position),
			size = Vector3.new(inner, inner, reach),
			cylinder = false,
		})
	end

	return cutters
end

--[=[
	A grate: a thin frame with slats, standing on a surface.

	@param settings Settings
	@param center Vector3 -- the middle of the grate, already lifted off the surface
	@param normal Vector3 -- the way the surface faces
	@return { Spec }
]=]
function Builders.VentCover(settings: Settings, center: Vector3, normal: Vector3): { Spec }
	local out: { Spec } = {}
	local n = normal.Unit
	local reference = if math.abs(n.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
	local u = reference:Cross(n).Unit
	local v = n:Cross(u)
	local frame = CFrame.fromMatrix(center, u, v, n)
	local size = settings.VentSize + 0.4
	local bar, depth = 0.2, 0.15
	local edge = size / 2 - bar / 2

	add(out, Vector3.new(size, bar, depth), frame * CFrame.new(0, edge, 0), "VentCoverFrame")
	add(out, Vector3.new(size, bar, depth), frame * CFrame.new(0, -edge, 0), "VentCoverFrame")
	add(out, Vector3.new(bar, size - 2 * bar, depth), frame * CFrame.new(edge, 0, 0), "VentCoverFrame")
	add(out, Vector3.new(bar, size - 2 * bar, depth), frame * CFrame.new(-edge, 0, 0), "VentCoverFrame")

	local slats = 5
	local gap = size - 2 * bar

	for i = 1, slats do
		local y = -gap / 2 + gap * (i - 0.5) / slats

		add(out, Vector3.new(gap, 0.12, depth * 0.6), frame * CFrame.new(0, y, 0), "VentSlat")
	end

	return out
end

--[[
	@return CFrame -- a frame on a surface: X and Y lie in the surface, Z points out of it
]]
local function surfaceFrame(center: Vector3, normal: Vector3): CFrame
	local n = normal.Unit
	local reference = if math.abs(n.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
	local u = reference:Cross(n).Unit

	return CFrame.fromMatrix(center, u, n:Cross(u), n)
end

--[=[
	A plain square plate that closes the end of a vent.

	@param settings Settings
	@param center Vector3 -- the middle of the opening, lifted a little off the surface
	@param normal Vector3 -- the way the opening faces
	@return { Spec }
]=]
function Builders.VentCap(settings: Settings, center: Vector3, normal: Vector3): { Spec }
	local out: { Spec } = {}
	local size = settings.VentSize

	add(out, Vector3.new(size, size, 0.2), surfaceFrame(center, normal) * CFrame.new(0, 0, 0.05), "VentCap")

	return out
end

--[=[
	A frame with four fan blades set at an angle, closing the end of a vent.

	@param settings Settings
	@param center Vector3
	@param normal Vector3
	@return { Spec }
]=]
function Builders.VentFan(settings: Settings, center: Vector3, normal: Vector3): { Spec }
	local out: { Spec } = {}
	local frame = surfaceFrame(center, normal)
	local size = settings.VentSize
	local bar, depth = 0.25, 0.35
	local edge = size / 2 - bar / 2
	local hub = 0.6
	local reach = size / 2 - bar
	local length = reach - hub / 2 + 0.05

	add(out, Vector3.new(size, bar, depth), frame * CFrame.new(0, edge, 0), "VentFanFrame")
	add(out, Vector3.new(size, bar, depth), frame * CFrame.new(0, -edge, 0), "VentFanFrame")
	add(out, Vector3.new(bar, size - 2 * bar, depth), frame * CFrame.new(edge, 0, 0), "VentFanFrame")
	add(out, Vector3.new(bar, size - 2 * bar, depth), frame * CFrame.new(-edge, 0, 0), "VentFanFrame")
	add(out, Vector3.new(hub, hub, depth), frame, "VentFanHub")

	local pitch = math.rad(28)
	local middle = hub / 2 + length / 2 - 0.05

	for turn = 0, 3 do
		local spin = frame * CFrame.Angles(0, 0, turn * math.pi / 2) * CFrame.new(middle, 0, 0)

		add(out, Vector3.new(length, 0.7, 0.06), spin * CFrame.Angles(pitch, 0, 0), "VentFanBlade")
	end

	return out
end

--[=[
	A small rectangular louvred cover, for looking out of a vent through a wall.

	@param settings Settings
	@param center Vector3
	@param normal Vector3
	@return { Spec }
]=]
Builders.PEEK_HEIGHT = 1.35

function Builders.VentPeek(settings: Settings, center: Vector3, normal: Vector3): { Spec }
	local out: { Spec } = {}
	local frame = surfaceFrame(center, normal)
	local width, height, bar, depth = 2.4, Builders.PEEK_HEIGHT, 0.12, 0.12
	local halfH, halfW = height / 2 - bar / 2, width / 2 - bar / 2

	add(out, Vector3.new(width, bar, depth), frame * CFrame.new(0, halfH, 0), "VentPeekFrame")
	add(out, Vector3.new(width, bar, depth), frame * CFrame.new(0, -halfH, 0), "VentPeekFrame")
	add(out, Vector3.new(bar, height - 2 * bar, depth), frame * CFrame.new(halfW, 0, 0), "VentPeekFrame")
	add(out, Vector3.new(bar, height - 2 * bar, depth), frame * CFrame.new(-halfW, 0, 0), "VentPeekFrame")

	for _, y in { -0.27, 0, 0.27 } do
		add(
			out,
			Vector3.new(width - 2 * bar, 0.07, depth * 1.5),
			frame * CFrame.new(0, y, 0) * CFrame.Angles(math.rad(-30), 0, 0),
			"VentPeekSlat"
		)
	end

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
function Builders.Place(
	settings: Settings,
	hit: RaycastResult?,
	source: Source?,
	scale: number?
): ({ Spec }, string, CFrame?)
	local out: { Spec } = {}

	if not hit or not source then
		return out, "Select an object, then choose Brush.", nil
	end

	for _, part in source.Parts do
		if not part:IsDescendantOf(game) then
			return out, "Selection changed or was removed. Choose Brush again.", nil
		end
	end

	local specs, target = Builders.PlaceAt(settings, hit.Position, hit.Normal, source, settings.Yaw, scale)

	return specs, "Click or drag to paint copies onto surfaces. Radius, spacing and rotation are in the panel.", target
end

--[=[
	One copy of the source seated flush on a surface point.

	@param settings Settings
	@param position Vector3 -- where the surface is
	@param normal Vector3 -- which way the surface faces
	@param source Source
	@param yaw number -- turn about the surface normal, in degrees
	@param scale number? -- how much bigger or smaller than the original, 1 when left out
	@return { Spec }
	@return CFrame -- where the source's pivot lands
]=]
function Builders.PlaceAt(
	settings: Settings,
	position: Vector3,
	normal: Vector3,
	source: Source,
	yaw: number,
	scale: number?
): ({ Spec }, CFrame)
	local out: { Spec } = {}
	local grow = scale or 1
	local rot = CFrame.Angles(0, math.rad(yaw), 0)

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
	)
		/ 2
		* grow
	local target = CFrame.new(position + normal * (radius + settings.Offset)) * rot

	for _, part in source.Parts do
		local relative = source.Pivot:ToObjectSpace(part.CFrame)
		local scaled = CFrame.new(relative.Position * grow) * (relative - relative.Position)

		add(out, part.Size * grow, target * scaled, part.Name)
	end

	return out, target
end

return Builders
