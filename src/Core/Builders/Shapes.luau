--!strict

--[=[
	The types and primitive pieces every builder shares: rectangles, wall segments, pillars,
	prisms and fence runs.

	Part of the builders: each takes the clicked points and the settings and returns Part specs.
	Nothing here changes the place; the specs are previewed, then built by `Geometry`.

	@class Shapes
]=]

local Geometry = require("../Geometry")
local Settings = require("../../Pure/Settings")

type Settings = Settings.Settings
type Spec = Geometry.Spec

local Shapes = {}

local add = Geometry.Add

export type Source = {
	Parts: { BasePart },
	Pivot: CFrame,
	Size: Vector3,
}

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
	The shared pieces, for the other builders.
]=]
Shapes.Rectangle = rectangle
Shapes.Segment = segment
Shapes.Pillar = pillar
Shapes.TrianglePrism = trianglePrism
Shapes.QuadPrism = quadPrism
Shapes.FenceRun = fenceRun
Shapes.DirectionCF = directionCF

return Shapes
