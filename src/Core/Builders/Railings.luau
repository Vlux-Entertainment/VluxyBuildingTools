--!strict

--[=[
	Railings, half walls and fences, which follow the slope between their two points.

	Part of the builders: each takes the clicked points and the settings and returns Part specs.
	Nothing here changes the place; the specs are previewed, then built by `Geometry`.

	@class Railings
]=]

local Geometry = require("../Geometry")
local Settings = require("../../Pure/Settings")
local Shapes = require("./Shapes")

type Settings = Settings.Settings
type Spec = Geometry.Spec

local Railings = {}

local add = Geometry.Add

local FLAT_RAIL_HEIGHT = 0.2

local STRINGER_RISE = FLAT_RAIL_HEIGHT
local quadPrism = Shapes.QuadPrism
local fenceRun = Shapes.FenceRun

--[[
	Adds a square pillar standing at base, turned to face along dir (flat). The top is `top` above base.
]]
local function newel(out: { Spec }, base: Vector3, flatDir: Vector3, top: number, name: string)
	local center = base + Vector3.new(0, top * 0.5, 0)

	add(out, Vector3.new(0.7, top, 0.7), CFrame.lookAt(center, center + flatDir), name)
end

--[=[
	A straight indoor railing from a to b: a handrail on top, thin bars between and a pillar at each
	end. On the flat a bottom rail lies along the floor. When a and b are at different heights it
	follows the slope, and the bottom rail is a tall board that rises above the step edges as far as
	the flat rail rises above the floor and reaches down into the steps, with the bars standing on it.

	@param settings Settings
	@param a Vector3 -- the start, on the floor or a stair
	@param b Vector3 -- the end, on the floor or a stair
	@param postAtStart boolean? -- false when the railing before this one already has a pillar there
	@return { Spec }
]=]
function Railings.Railing(settings: Settings, a: Vector3, b: Vector3, postAtStart: boolean?): { Spec }
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
	local sloped = math.abs(d.Y) > 0.05
	local sink = if sloped then math.max(0.5, 2 * math.abs(d.Y) / flat.Magnitude) else 0
	local base = if sloped then STRINGER_RISE else 0

	add(out, Vector3.new(0.4, 0.3, length), CFrame.lookAt(middle + up * height, middle + up * height + dir), "Handrail")

	if sloped then
		local board = middle + up * ((STRINGER_RISE - sink) / 2)

		add(out, Vector3.new(0.35, STRINGER_RISE + sink, length), CFrame.lookAt(board, board + dir), "BottomRail")
	else
		local rail = middle + up * (FLAT_RAIL_HEIGHT / 2)

		add(out, Vector3.new(0.3, FLAT_RAIL_HEIGHT, length), CFrame.lookAt(rail, rail + dir), "BottomRail")
	end

	local count = math.max(1, math.round(flat.Magnitude / math.max(0.3, settings.BalusterSpacing)))

	for i = 1, count - 1 do
		local foot = a + d * (i / count) + up * (base - 0.05)
		local reach = height - base + 0.05
		local center = foot + up * (reach * 0.5)

		add(out, Vector3.new(0.2, reach, 0.2), CFrame.lookAt(center, center + flatDir), "Baluster")
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
function Railings.HalfWall(settings: Settings, a: Vector3, b: Vector3, postAtStart: boolean?): { Spec }
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
function Railings.Fence(settings: Settings, a: Vector3, b: Vector3, postAtStart: boolean?): { Spec }
	local out: { Spec } = {}

	fenceRun(out, a, b, settings.FenceHeight, settings.FenceSpacing, postAtStart ~= false, true)

	return out
end

return Railings
