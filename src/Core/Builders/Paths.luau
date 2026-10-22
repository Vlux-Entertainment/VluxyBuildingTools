--!strict

--[=[
	Walls and corridors drawn along a path, the arched corridor, and how one segment of a chain
	bends into the next.

	Part of the builders: each takes the clicked points and the settings and returns Part specs.
	Nothing here changes the place; the specs are previewed, then built by `Geometry`.

	@class Paths
]=]

local Geometry = require("../Geometry")
local Settings = require("../../Pure/Settings")
local Shapes = require("./Shapes")

type Settings = Settings.Settings
type Spec = Geometry.Spec
type Strip = Shapes.Strip
type Bend = Shapes.Bend

local Paths = {}

local add = Geometry.Add
local segment = Shapes.Segment
local pillar = Shapes.Pillar
local trianglePrism = Shapes.TrianglePrism
local quadPrism = Shapes.QuadPrism

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
function Paths.ArchedStrips(settings: Settings): { Strip }
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
function Paths.ArchedCorridor(settings: Settings, a: Vector3, b: Vector3, joinDir: Vector3?): { Spec }
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
	local strips = Paths.ArchedStrips(settings)
	local bend = if joinDir then Paths.Bend(a, joinDir, flat, strips, strips) else nil

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
function Paths.ArchedBend(settings: Settings, joint: Vector3, prevDir: Vector3, dir: Vector3): { ArchWedge }
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
	@return { Strip } -- the one strip a plain wall is made of, across its thickness
]=]
function Paths.WallStrips(settings: Settings): { Strip }
	local t, h = settings.Thickness, settings.Height

	return { { key = "Wall", name = "Wall", low = -t / 2, high = t / 2, rise = h / 2, height = h } }
end

--[=[
	@param settings Settings
	@return { Strip } -- the floor, the two side walls and the optional ceiling of a corridor, each across its own width
]=]
function Paths.CorridorStrips(settings: Settings): { Strip }
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
function Paths.Bend(joint: Vector3, prevDir: Vector3, dir: Vector3, prevStrips: { Strip }, strips: { Strip }): Bend
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
function Paths.Path(
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
				local strips = Paths.WallStrips(settings)
				local bend = Paths.Bend(a, joinDir, d, strips, strips)

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
	local strips = Paths.CorridorStrips(settings)
	local bend = if joinDir then Paths.Bend(a, joinDir, d, strips, strips) else nil

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

return Paths
