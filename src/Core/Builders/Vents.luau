--!strict

--[=[
	Square ducts, the cutters that open walls for them, and the end pieces: grate, cap, fan, peek
	cover and the hole marker.

	Part of the builders: each takes the clicked points and the settings and returns Part specs.
	Nothing here changes the place; the specs are previewed, then built by `Geometry`.

	@class Vents
]=]

local Geometry = require("../Geometry")
local Paths = require("./Paths")
local Settings = require("../../Pure/Settings")
local Shapes = require("./Shapes")

type Settings = Settings.Settings
type Spec = Geometry.Spec
type Cutter = Shapes.Cutter
type Strip = Shapes.Strip

local Vents = {}

local add = Geometry.Add
local quadPrism = Shapes.QuadPrism

--[=[
	@param settings Settings
	@return { Strip } -- the floor, ceiling and two side sheets of a vent, measured from its bottom
]=]
function Vents.VentStrips(settings: Settings): { Strip }
	local w, t = Settings.VentOuter(settings), settings.VentThickness
	local inner = math.max(0.05, w - 2 * t)
	local pad = 0.03

	return {
		{
			key = "Floor",
			name = "VentFloor",
			low = -w / 2 - pad,
			high = w / 2 + pad,
			rise = t / 2 - pad / 2,
			height = t + pad,
		},
		{
			key = "Ceiling",
			name = "VentCeiling",
			low = -w / 2 - pad,
			high = w / 2 + pad,
			rise = w - t / 2 + pad / 2,
			height = t + pad,
		},
		{ key = "Right", name = "VentWall", low = w / 2 - t, high = w / 2 + pad, rise = w / 2, height = inner },
		{ key = "Left", name = "VentWall", low = -w / 2 - pad, high = -w / 2 + t, rise = w / 2, height = inner },
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
function Vents.VentRun(settings: Settings, a: Vector3, b: Vector3, joinDir: Vector3?): { Spec }
	local out: { Spec } = {}
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)

	if flat.Magnitude < 0.05 then
		return out
	end

	local up = Vector3.yAxis
	local dir = flat.Unit
	local across = dir:Cross(up).Unit
	local strips = Vents.VentStrips(settings)
	local bend = if joinDir then Paths.Bend(a, joinDir, flat, strips, strips) else nil

	if bend then
		for _, spec in bend.beginning do
			table.insert(out, spec)
		end
	end

	for _, strip in strips do
		local late = if bend then bend.start[strip.key] or 0 else 0.03
		local run = flat.Magnitude - late - 0.03

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
function Vents.VentDuct(settings: Settings, a: Vector3, b: Vector3): { Spec }
	local out: { Spec } = {}

	if (b - a).Magnitude > 0.2 then
		local inset = (b - a).Unit * 0.03

		a, b = a + inset, b - inset
	end

	local frame = ductFrame(a, b)

	if not frame then
		return out
	end

	local w, t = Settings.VentOuter(settings), settings.VentThickness
	local length = (b - a).Magnitude
	local inner = math.max(0.05, w - 2 * t)
	local reach = w / 2 - t / 2
	local dirN = (b - a).Unit
	local pad = 0.03

	if math.abs(dirN.Y) < 0.99 then
		local flat = Vector3.new(dirN.X, 0, dirN.Z).Unit
		local across = flat:Cross(Vector3.yAxis).Unit
		local gap = w / 2 - t

		local cosine = math.max(0.1, Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude / length)
		local slant = t / cosine

		for _, floor in { true, false } do
			local y1 = if floor then -gap else gap + slant + pad
			local y2 = if floor then -gap - slant - pad else gap

			quadPrism(
				out,
				a + Vector3.new(0, y1, 0),
				b + Vector3.new(0, y1, 0),
				b + Vector3.new(0, y2, 0),
				a + Vector3.new(0, y2, 0),
				w + 2 * pad,
				if floor then "VentFloor" else "VentCeiling"
			)
		end

		for _, side in { -1, 1 } do
			local lateral = across * (side * (reach + pad / 2))

			quadPrism(
				out,
				a + lateral + Vector3.new(0, -gap, 0),
				b + lateral + Vector3.new(0, -gap, 0),
				b + lateral + Vector3.new(0, gap, 0),
				a + lateral + Vector3.new(0, gap, 0),
				t + pad,
				"VentWall"
			)
		end

		return out
	end

	add(out, Vector3.new(w + 2 * pad, t + pad, length), frame * CFrame.new(0, -reach - pad / 2, 0), "VentFloor")
	add(out, Vector3.new(w + 2 * pad, t + pad, length), frame * CFrame.new(0, reach + pad / 2, 0), "VentCeiling")
	add(out, Vector3.new(t + pad, inner, length), frame * CFrame.new(reach + pad / 2, 0, 0), "VentWall")
	add(out, Vector3.new(t + pad, inner, length), frame * CFrame.new(-reach - pad / 2, 0, 0), "VentWall")

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
function Vents.VentCutters(settings: Settings, a: Vector3, b: Vector3): { Cutter }
	local frame = ductFrame(a, b)
	local cutters: { Cutter } = {}

	if not frame then
		return cutters
	end

	local w, t = Settings.VentOuter(settings), settings.VentThickness
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
function Vents.VentJoinCutters(settings: Settings, a: Vector3, b: Vector3): { Cutter }
	local frame = ductFrame(a, b)
	local cutters: { Cutter } = {}

	if not frame then
		return cutters
	end

	local w, t = Settings.VentOuter(settings), settings.VentThickness
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
function Vents.VentCover(settings: Settings, center: Vector3, normal: Vector3): { Spec }
	local out: { Spec } = {}
	local n = normal.Unit
	local reference = if math.abs(n.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
	local u = reference:Cross(n).Unit
	local v = n:Cross(u)
	local frame = CFrame.fromMatrix(center, u, v, n)
	local size = Settings.VentOuter(settings) + 0.4
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
function Vents.VentCap(settings: Settings, center: Vector3, normal: Vector3): { Spec }
	local out: { Spec } = {}
	local size = Settings.VentOuter(settings)

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
function Vents.VentFan(settings: Settings, center: Vector3, normal: Vector3): { Spec }
	local out: { Spec } = {}
	local frame = surfaceFrame(center, normal)
	local size = Settings.VentOuter(settings)
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

Vents.PEEK_HEIGHT = 1.35

--[=[
	A small rectangular louvred cover, for looking out of a vent through a wall.

	@param settings Settings
	@param center Vector3
	@param normal Vector3
	@return { Spec }
]=]
function Vents.VentPeek(settings: Settings, center: Vector3, normal: Vector3): { Spec }
	local out: { Spec } = {}
	local frame = surfaceFrame(center, normal)
	local width, height, bar, depth = 2.4, Vents.PEEK_HEIGHT, 0.12, 0.12
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
	A square outline lying on a surface, showing where a vent hole will be cut.

	@param center Vector3
	@param normal Vector3
	@param size number -- the side of the hole
	@return { Spec }
]=]
function Vents.VentHoleMark(center: Vector3, normal: Vector3, size: number): { Spec }
	local out: { Spec } = {}
	local frame = surfaceFrame(center, normal)
	local bar, depth = 0.15, 0.1
	local half = size / 2 - bar / 2

	add(out, Vector3.new(size, bar, depth), frame * CFrame.new(0, half, 0), "VentHoleMark")
	add(out, Vector3.new(size, bar, depth), frame * CFrame.new(0, -half, 0), "VentHoleMark")
	add(out, Vector3.new(bar, size - 2 * bar, depth), frame * CFrame.new(half, 0, 0), "VentHoleMark")
	add(out, Vector3.new(bar, size - 2 * bar, depth), frame * CFrame.new(-half, 0, 0), "VentHoleMark")

	return out
end

return Vents
