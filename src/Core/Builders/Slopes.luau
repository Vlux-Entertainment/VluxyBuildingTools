--!strict

--[=[
	Stairs, ramps and arches.

	Part of the builders: each takes the clicked points and the settings and returns Part specs.
	Nothing here changes the place; the specs are previewed, then built by `Geometry`.

	@class Slopes
]=]

local Geometry = require("../Geometry")
local Settings = require("../../Pure/Settings")
local Shapes = require("./Shapes")
local StairSnap = require("../../Pure/StairSnap")

type Settings = Settings.Settings
type Spec = Geometry.Spec

local Slopes = {}

local add = Geometry.Add
local quadPrism = Shapes.QuadPrism
local directionCF = Shapes.DirectionCF

--[=[
	The step layout of stairs or a ramp, which `Stairs` builds from and which is recorded on the
	built stairs so railings can find each step.

	@param settings Settings
	@param a Vector3 -- the first step
	@param b Vector3 -- the end of the run
	@param ramp boolean
	@return StairSnap.Layout? -- nil when a and b are the same point
	@return CFrame? -- the stairs' frame: at a, looking up the run
]=]
function Slopes.StairLayout(settings: Settings, a: Vector3, b: Vector3, ramp: boolean): (StairSnap.Layout?, CFrame?)
	local cf = directionCF(a, b)

	if not cf then
		return nil, nil
	end

	local length = (b - a).Magnitude
	local count = math.clamp(math.ceil(length / settings.Run), 1, 200)
	local height = if ramp then settings.RampHeight else settings.StairHeight

	return {
		Run = length / count,
		Rise = height / count,
		Count = count,
		Width = settings.Width,
		Landing = settings.Landing,
		Ramp = ramp,
	},
		cf
end

--[=[
	How deep a sloped underside reaches straight down from the line of the steps' inner corners,
	for the thickness measured square to the slope.

	@param settings Settings
	@param length number -- the run
	@param height number -- the rise
	@return number? -- nil when the slab would reach the ground everywhere, so the stairs stay solid
]=]
function Slopes.UnderDepth(settings: Settings, length: number, height: number): number?
	if length <= 0 or height <= 0 then
		return nil
	end

	local depth = settings.StairUnderThickness * math.sqrt(length * length + height * height) / length

	return if depth < height then depth else nil
end

--[=[
	Stairs or a ramp. With `StairUnder` set to "Slope" the underside is a sloped slab as thick as
	`StairUnderThickness`, measured square to the slope from the line of the steps' inner corners,
	instead of solid down to the ground.

	@param settings Settings
	@param a Vector3 -- the first step
	@param b Vector3 -- the end of the run
	@param ramp boolean -- true for one wedge, false for steps
	@return { Spec }
]=]
function Slopes.Stairs(settings: Settings, a: Vector3, b: Vector3, ramp: boolean): { Spec }
	local out: { Spec } = {}
	local layout, cf = Slopes.StairLayout(settings, a, b, ramp)

	if not layout or not cf then
		return out
	end

	local length = (b - a).Magnitude
	local count = layout.Count
	local run = layout.Run
	local height = layout.Rise * count
	local rise = layout.Rise

	local under = if settings.StairUnder == "Slope" then Slopes.UnderDepth(settings, length, height) else nil

	--[[ A point in the stairs' side profile: `along` up the run from the first step, `y` up. ]]
	local function profile(along: number, y: number): Vector3
		return cf:PointToWorldSpace(Vector3.new(0, y, -along))
	end

	if under then
		local foot = math.min(length, under * length / height)

		quadPrism(
			out,
			profile(0, 0),
			profile(length, height),
			profile(length, height - under),
			profile(foot, 0),
			settings.Width,
			if ramp then "Ramp" else "StairSlab"
		)
	end

	if ramp and not under then
		-- A WedgePart rises toward local +Z, so turn it to rise away from the first click.
		add(
			out,
			Vector3.new(settings.Width, height, length),
			cf * CFrame.new(0, height / 2, -length / 2) * CFrame.Angles(0, math.pi, 0),
			"Ramp",
			nil,
			"WedgePart"
		)
	elseif not ramp then
		for i = 1, count do
			local low = if under then rise * (i - 1) else 0

			add(
				out,
				Vector3.new(settings.Width, rise * i - low, run),
				cf * CFrame.new(0, (rise * i + low) / 2, -run * (i - 0.5)),
				"Step_" .. i
			)
		end
	end

	if settings.Landing > 0 then
		local thick = if under then math.min(under, height) else height

		add(
			out,
			Vector3.new(settings.Width, thick, settings.Landing),
			cf * CFrame.new(0, height - thick / 2, -length - settings.Landing / 2),
			"Landing"
		)
	end

	return out
end

--[=[
	@param settings Settings
	@param a Vector3 -- one inner edge, at ground level
	@param b Vector3 -- the other inner edge
	@return { Spec } -- two posts and a curved header; empty when the span is too wide for the height
]=]
function Slopes.Arch(settings: Settings, a: Vector3, b: Vector3): { Spec }
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

	--[[ A point on the arch at radius r and an angle from the springing line, in world space. ]]
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

return Slopes
