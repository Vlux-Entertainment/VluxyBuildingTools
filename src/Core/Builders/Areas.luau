--!strict

--[=[
	Footprint shapes drawn from two corners: floors, foundations, porches, roofs, rooms and
	blocks, and the single pillar.

	Part of the builders: each takes the clicked points and the settings and returns Part specs.
	Nothing here changes the place; the specs are previewed, then built by `Geometry`.

	@class Areas
]=]

local AxisLock = require("../../Pure/AxisLock")
local Geometry = require("../Geometry")
local Settings = require("../../Pure/Settings")
local Shapes = require("./Shapes")

type Settings = Settings.Settings
type Spec = Geometry.Spec

local Areas = {}

local add = Geometry.Add
local rectangle = Shapes.Rectangle
local trianglePrism = Shapes.TrianglePrism
local quadPrism = Shapes.QuadPrism
local fenceRun = Shapes.FenceRun

--[=[
	@param settings Settings
	@param a Vector3 -- one corner, at the height of the top of the floor
	@param b Vector3 -- the opposite corner
	@return { Spec } -- one flat slab as thick as the panel's floor thickness
]=]
function Areas.Floor(settings: Settings, a: Vector3, b: Vector3): { Spec }
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
function Areas.Foundation(settings: Settings, a: Vector3, b: Vector3): { Spec }
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
function Areas.Porch(settings: Settings, a: Vector3, b: Vector3): { Spec }
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

--[=[
	Builds a roof over the rectangle between two corners, bigger by the overhang on every side. Gable
	and shed roofs are solid; hip and pyramid roofs are made of sheets; flat is a single slab.

	@param settings Settings
	@param a Vector3 -- one corner, at the height of the top of the walls
	@param b Vector3 -- the opposite corner
	@return { Spec }
]=]
function Areas.Roof(settings: Settings, a: Vector3, b: Vector3): { Spec }
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
function Areas.Room(settings: Settings, a: Vector3, b: Vector3): { Spec }
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
function Areas.Block(settings: Settings, a: Vector3, b: Vector3, lock: AxisLock.Lock?): { Spec }
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
function Areas.Pillar(settings: Settings, base: Vector3): { Spec }
	local out: { Spec } = {}
	local w, h = settings.PillarWidth, settings.Height

	add(out, Vector3.new(w, h, w), CFrame.new(base + Vector3.new(0, h / 2, 0)), "Pillar")

	return out
end

return Areas
