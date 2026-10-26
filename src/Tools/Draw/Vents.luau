--!strict

--[=[
	The duct tools: a vent that runs along X or Z and turns at right angles, a sloped vent and a
	vertical shaft.

	A vent can start against a wall, floor or ceiling, or from an existing vent, and is pushed so it
	sits against what it started on. Once built, it records its open ends (so covers and later vents
	find them) and cuts its way through every part it passes.

	@class DrawVents
]=]

local CollectionService = game:GetService("CollectionService")

local Bends = require("./Bends")
local Cursor = require("../../Services/Cursor")
local Engine = require("./Engine")
local Geometry = require("../../Core/Geometry")
local Joints = require("../../Core/Joints")
local Points = require("./Points")
local Settings = require("../../Pure/Settings")
local Shapes = require("../../Core/Builders/Shapes")
local Snapper = require("../../Core/Snapper")
local Types = require("../Types")
local VentHoles = require("../../Core/VentHoles")
local Vents = require("../../Core/Builders/Vents")

type Context = Types.Context
type Draw = Engine.Draw
type Built = Engine.Built

local VENT_TAG = "VluxyBT_Vent"
local MAX_STEEP = 2

--[[
	@param draw Draw
	@return Engine.VentState
]]
local function ventOf(draw: Draw): Engine.VentState
	return draw.Vent :: Engine.VentState
end

--[[
	@param part BasePart
	@return boolean -- whether the part belongs to a vent, as one of its pieces or one level deeper
]]
local function inVent(part: BasePart): boolean
	for _, ancestor in { part.Parent, part.Parent and part.Parent.Parent } do
		if ancestor and CollectionService:HasTag(ancestor, VENT_TAG) then
			return true
		end
	end

	return false
end

--[[
	@param cutters { Shapes.Cutter }
	@param keep (part: BasePart) -> boolean
	@return { [BasePart]: boolean } -- the parts in the working folder the cutters touch and `keep` accepts
]]
local function touched(cutters: { Shapes.Cutter }, keep: (part: BasePart) -> boolean): { [BasePart]: boolean }
	local params = OverlapParams.new()
	local scope = Geometry.GetScope()
	local found: { [BasePart]: boolean } = {}

	if scope then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { scope }
	end

	for _, cutter in cutters do
		for _, part in workspace:GetPartBoundsInBox(cutter.cf, cutter.size, params) do
			if keep(part) then
				found[part] = true
			end
		end
	end

	return found
end

--[[
	@param ctx Context
	@param draw Draw
	@return Settings -- the settings to build with: a vent continued from another takes that vent's size, so the two meet flush
]]
local function sizing(ctx: Context, draw: Draw): Settings.Settings
	return ventOf(draw).Match or ctx.Settings
end

--[[
	@param part BasePart
	@param point Vector3 -- where the vent ends against the part
	@param outward Vector3 -- the way the vent points out of that end
	@return number -- how far past the point the part's far face lies along outward, plus a margin, so the opening cuts all the way through however thick the part is
]]
local function wallReach(part: BasePart, point: Vector3, outward: Vector3): number
	local cf, half = part.CFrame, part.Size / 2
	local extent = math.abs(outward:Dot(cf.XVector)) * half.X
		+ math.abs(outward:Dot(cf.YVector)) * half.Y
		+ math.abs(outward:Dot(cf.ZVector)) * half.Z

	return (cf.Position - point):Dot(outward) + extent + 0.25
end

--[[
	@param ctx Context
	@param settings Settings.Settings -- the sizes the vent was built at
	@param model Model -- the vent just built
	@param a Vector3 -- one end of the duct, on its middle line
	@param b Vector3 -- the other end
	@param skip { Instance } -- the vents this one continues end to end, left uncut

	Records the vent's open ends, then cuts the duct and its openings out of every other part it
	passes through, and opens the side of any vent it joins.
]]
local function finish(
	ctx: Context,
	settings: Settings.Settings,
	model: Model,
	a: Vector3,
	b: Vector3,
	skip: { Instance }
)
	if (b - a).Magnitude < 0.05 then
		return
	end

	local dir = Snapper.VentFacing(b - a)

	Snapper.RememberVentEnds(model, { Start = a, StartDir = -dir, End = b, EndDir = dir }, Snapper.FixPivot(model))
	model:SetAttribute("VluxyBT_VentOuter", Settings.VentOuter(settings))
	model:SetAttribute("VluxyBT_VentThickness", settings.VentThickness)
	CollectionService:AddTag(model, VENT_TAG)
	Snapper.ForgetVents()

	local failed = 0
	local cutters = Vents.VentCutters(settings, a, b)
	local ends = { -dir, dir }
	local reach = { 0, 0 }

	for index, point in { a, b } do
		for part in
			touched({ cutters[index + 1] }, function(candidate)
				return not inVent(candidate) and not candidate:IsA("Terrain")
			end)
		do
			reach[index] = math.max(reach[index], wallReach(part, point, ends[index]))
		end
	end

	cutters = Vents.VentCutters(settings, a, b, reach)

	for part in
		touched(cutters, function(candidate)
			return not inVent(candidate) and not candidate:IsA("Terrain")
		end)
	do
		if not Joints.Carve(part, cutters) then
			failed += 1
		end
	end

	local joins = Vents.VentJoinCutters(settings, a, b)

	for part in
		touched(joins, function(candidate)
			local owner = candidate.Parent

			return owner ~= nil
				and owner ~= model
				and not table.find(skip, owner)
				and owner:IsA("Model")
				and CollectionService:HasTag(owner, VENT_TAG)
		end)
	do
		if not Joints.Carve(part, joins) then
			failed += 1
		end
	end

	if failed > 0 then
		ctx.Say(string.format("%d part(s) could not be cut for the vent.", failed))
	end
end

--[[
	@param ctx Context
	@param draw Draw
	@param built Built

	Finishes the vent from the ends the preview worked out.
]]
local function commit(ctx: Context, draw: Draw, built: Built)
	local vent = ventOf(draw)
	local ends = vent.Ends
	local previous = built.Previous
	local skip: { Instance } = {}

	if previous then
		table.insert(skip, previous.model)
	end

	if vent.Owner and vent.End then
		table.insert(skip, vent.Owner)
	end

	if vent.TargetOwner and vent.TargetEnd then
		table.insert(skip, vent.TargetOwner)
	end

	if ends and built.Model then
		finish(ctx, sizing(ctx, draw), built.Model, ends[1], ends[2], skip)
	end
end

--[[
	@param shaft boolean
	@param headOn boolean? -- start only on open vent ends, holes and plain surfaces, never on a vent's side or top
	@return (ctx, draw) -> Vector3? -- a start picker for a vent
]]
local function start(shaft: boolean, headOn: boolean?): (ctx: Context, draw: Draw) -> Vector3?
	return function(ctx: Context, draw: Draw): Vector3?
		return Points.Vent(ctx, draw, shaft, headOn)
	end
end

--[[
	Before the first click the marker is the outline of the duct where it will start, with a cross
	through its middle: on the surface it starts against, on the open vent end it continues, or on
	the side of the vent it branches from.
]]
local function idle(ctx: Context, draw: Draw, _point: Vector3): { Geometry.Spec }?
	local vent, mark = ventOf(draw), ctx.Cursor.Mark
	local size = Settings.VentOuter(ctx.Settings)
	local center, facing

	if not mark then
		return nil
	elseif vent.HitEnd then
		local sideways = math.abs(vent.HitEnd.Y) > 0.9 and not draw.Shape.Shaft

		center, facing = if sideways then mark + vent.HitEnd * (size / 2) else mark, vent.HitEnd
	elseif vent.HitFace then
		center, facing = mark + vent.HitFace * (vent.HitReach or size / 2), vent.HitFace
	elseif vent.HitNormal then
		center, facing = mark, vent.HitNormal
	else
		return nil
	end

	return Vents.VentStartMark(center + facing * 0.05, facing, size)
end

--[[
	@param keepNormal boolean -- whether the run remembers the surface it started on
	@param chains boolean -- whether a run started on the open end of a level vent turns its corner like a chained section

	@return (ctx, draw) -> () -- records what the vent started on at the first click
]]
local function onStart(keepNormal: boolean, chains: boolean): (ctx: Context, draw: Draw) -> ()
	return function(ctx: Context, draw: Draw)
		local vent = ventOf(draw)
		local owner, outward = vent.HitOwner, vent.HitEnd

		vent.Normal = if keepNormal then vent.HitNormal else nil
		vent.Host = vent.HitHost
		vent.Shift = Vector3.zero
		vent.Owner = owner
		vent.End = if outward and math.abs(outward.Y) < 0.5 then outward else nil
		vent.Axis = vent.HitAxis
		vent.Corner = vent.HitCorner and not vent.Host
		vent.Face, vent.Reach = vent.HitFace, vent.HitReach

		local ends = if owner then Snapper.VentEnds(owner) else nil
		local level = ends ~= nil and math.abs(ends.End.Y - ends.Start.Y) < 0.05
		local outer, thickness = if owner then Snapper.VentSizing(owner) else nil, nil

		vent.Match = nil

		if owner and (vent.End or vent.Corner) and outer and thickness then
			local matched = table.clone(ctx.Settings)

			matched.VentThickness = thickness
			matched.VentSize = math.max(0.05, outer - 2 * thickness)
			vent.Match = matched

			if draw.First then
				local drop = (Settings.VentOuter(ctx.Settings) - outer) / 2

				draw.First += Vector3.new(0, drop, 0)
			end
		end

		if chains and owner and vent.End and level then
			draw.Previous = { model = owner, dir = vent.End, strips = Vents.VentStrips(sizing(ctx, draw)) }
			draw.Chained = true
		end
	end
end

--[[ After a build the next section starts in the open, not against a surface or another vent. ]]
local function built(draw: Draw)
	local vent = ventOf(draw)

	vent.Normal, vent.Shift, vent.Host = nil, Vector3.zero, nil
	vent.Owner, vent.End, vent.Corner, vent.Face, vent.Reach, vent.Axis = nil, nil, nil, nil, nil, nil
	vent.Target, vent.TargetOwner, vent.TargetEnd, vent.TargetAt, vent.Why = nil, nil, nil, nil, nil
end

--[[
	@param draw Draw
	@return { Instance } -- the vents a run may touch: the one it continues, and the one it starts from unless that is a corner it leaves
]]
local function skipped(draw: Draw): { Instance }
	local skip: { Instance } = {}
	local owner = ventOf(draw).Owner

	if draw.Previous then
		table.insert(skip, draw.Previous.model)
	end

	if owner and not ventOf(draw).Corner then
		table.insert(skip, owner)
	end

	return skip
end

--[[
	@param ctx Context
	@param draw Draw
	@param a Vector3
	@param b Vector3
	@return Vector3, Vector3 -- the run pulled onto X or Z, never doubling back on the last section, leaving through the vent face it started on, ending flush against a vent it meets, and pushed against the surface it started on
]]
local function constrain(ctx: Context, draw: Draw, a: Vector3, b: Vector3): (Vector3, Vector3)
	local vent = ventOf(draw)

	if draw.Rise then
		return a, b
	end

	local d = b - a
	local alongX = math.abs(d.X) >= math.abs(d.Z)
	local sign = if alongX then (if d.X >= 0 then 1 else -1) else (if d.Z >= 0 then 1 else -1)
	local axis = if alongX then Vector3.xAxis else Vector3.zAxis

	if draw.Chained and draw.Previous and (axis * sign):Dot(draw.Previous.dir) < -0.5 then
		alongX = not alongX
		axis = if alongX then Vector3.xAxis else Vector3.zAxis
		sign = if alongX then (if d.X >= 0 then 1 else -1) else (if d.Z >= 0 then 1 else -1)
	end

	local host = vent.Host

	if not draw.Chained and host and math.abs(host.Y) < 0.9 and math.abs(axis:Dot(host)) >= 0.5 then
		alongX = not alongX
		axis = if alongX then Vector3.xAxis else Vector3.zAxis
		sign = if alongX then (if d.X >= 0 then 1 else -1) else (if d.Z >= 0 then 1 else -1)
	end

	local direction = axis * sign
	local outward = vent.End

	if not draw.Chained and outward then
		direction = if math.abs(outward.X) >= math.abs(outward.Z)
			then Vector3.xAxis * math.sign(outward.X)
			else Vector3.zAxis * math.sign(outward.Z)
	end

	local through = vent.Axis

	if not draw.Chained and through then
		direction = through * (if (b - a):Dot(through) >= 0 then 1 else -1)
	end

	local face = vent.Face
	local leaves = not draw.Chained and (vent.Corner or vent.Host ~= nil) and face ~= nil and math.abs(face.Y) < 0.5

	if leaves and face then
		direction = if math.abs(face.X) >= math.abs(face.Z)
			then Vector3.xAxis * math.sign(face.X)
			else Vector3.zAxis * math.sign(face.Z)
	end

	b = a + direction * math.max(0, (b - a):Dot(direction))

	local half = Settings.VentOuter(sizing(ctx, draw)) / 2
	local endShifts = true

	vent.Shift = Vector3.zero

	if leaves then
		vent.Shift, endShifts = direction * (vent.Reach or half), false
	elseif not draw.Chained and vent.Corner then
		vent.Shift, endShifts = direction * half, false
	elseif not draw.Chained and vent.Host then
		local into = math.abs(direction:Dot(vent.Host)) < 0.5
		local hostOuter = if vent.Owner then Snapper.VentSizing(vent.Owner) else nil
		local hostHalf = if hostOuter then hostOuter / 2 else half

		vent.Shift, endShifts = if into then direction * hostHalf else Vector3.zero, false
	elseif not draw.Chained and vent.Normal then
		local sideways = math.abs(direction:Dot(vent.Normal)) < 0.5

		vent.Shift = if sideways then vent.Normal * (half - 0.03) else Vector3.zero
	end

	local from = a + vent.Shift
	local to = if endShifts then b + vent.Shift else b
	local up = Vector3.new(0, half, 0)
	local stop = Snapper.VentStop(from + up, direction, half, Settings.VentOuter(ctx.Settings), skipped(draw))

	if stop and stop < (to - from):Dot(direction) then
		to = from + direction * stop
	end

	return from, to
end

--[[
	@param ctx Context
	@param draw Draw
	@return Vector3 -- from the floor of the duct to its middle line
]]
local function lift(ctx: Context, draw: Draw): Vector3
	return Vector3.new(0, Settings.VentOuter(sizing(ctx, draw)) / 2, 0)
end

local vent: Engine.Shape = {
	Id = "Vent",
	Vents = true,
	Start = start(false),
	Idle = idle,
	OnStart = onStart(true, true),
	Constrain = constrain,
	Built = built,
	Chain = true,
	Build = function(ctx, draw, a, b)
		local up = lift(ctx, draw)
		local outward = ventOf(draw).End

		ventOf(draw).Ends = { a + up, b + up }

		if draw.Chained and draw.Previous then
			return Vents.VentRun(sizing(ctx, draw), a, b, draw.Previous.dir)
		elseif outward then
			return Vents.VentRun(sizing(ctx, draw), a, b, outward)
		end

		return Vents.VentRun(sizing(ctx, draw), a, b, nil)
	end,
	Commit = function(ctx, draw, result)
		Bends.Join(draw, result, Vents.VentStrips(sizing(ctx, draw)))
		commit(ctx, draw, result)
	end,
}

--[[
	@param ctx Context
	@param draw Draw
	@param origin Vector3 -- the slope's first point, at the floor of the duct
	@return Vector3? -- while the cursor is on a vent at another height, the spot under that vent on the start's level, so the slope can run to it

	Records the vent aimed at in `Target`, `TargetOwner` and `TargetEnd`.
]]
local function aim(ctx: Context, draw: Draw, origin: Vector3): Vector3?
	local state = ventOf(draw)
	local hit = Cursor.Hit(ctx.Cursor)

	state.Target, state.TargetOwner, state.TargetEnd, state.TargetAt = nil, nil, nil, nil

	local size = Settings.VentOuter(ctx.Settings)
	local hole =
		VentHoles.Find(Cursor.Ray(ctx.Cursor), origin + Vector3.new(0, size / 2, 0), if hit then hit.Distance else nil)

	if hole and math.abs(hole.Normal.Y) < 0.5 and math.abs(hole.Center.Y - size / 2 - origin.Y) >= 0.1 then
		state.Target, state.TargetEnd, state.TargetAt = hole.Center.Y - size / 2, hole.Normal, hole.Center
		ctx.Cursor.Mark = hole.Center

		return Vector3.new(hole.Center.X, origin.Y, hole.Center.Z)
	end

	if not hit or not ctx.Settings.SnapToParts or Cursor.Fine() then
		return nil
	end

	local step = math.max(0.05, Cursor.Grid(ctx.Cursor))
	local point, outward, owner = Snapper.VentEndOnRay(Cursor.Ray(ctx.Cursor), size, hit.Distance, state.Owner)

	if not point then
		point, outward, owner = Snapper.VentConnect(hit.Position, size * 1.1, step, size / 2)
	end

	local bottom = if point then point.Y - size / 2 else origin.Y

	if not point or not owner or owner == state.Owner or math.abs(bottom - origin.Y) < 0.1 then
		return nil
	elseif outward and math.abs(outward.Y) > 0.5 then
		return nil
	elseif outward and outward:Dot(Vector3.new(origin.X - point.X, 0, origin.Z - point.Z)) <= 0 then
		return nil
	end

	state.Target, state.TargetOwner, state.TargetEnd = bottom, owner, outward
	state.TargetAt = if outward then point else nil
	ctx.Cursor.Mark = point

	return Vector3.new(point.X, origin.Y, point.Z)
end

--[[
	@param ctx Context
	@param draw Draw
	@param from Vector3 -- the low or first end, on the middle line
	@param to Vector3 -- the other end, on the middle line
	@return { Spec } -- the sloped duct, ending flush against the vents it continues
]]
local function slope(ctx: Context, draw: Draw, from: Vector3, to: Vector3): { Geometry.Spec }
	ventOf(draw).Ends = { from, to }

	return Vents.VentDuct(sizing(ctx, draw), from, to)
end

local ventRamp: Engine.Shape = {
	Id = "VentRamp",
	Vents = true,
	Start = start(false, true),
	Next = aim,
	Idle = idle,
	OnStart = onStart(true, false),
	Constrain = constrain,
	Built = built,
	Rise = true,
	Reached = function(draw)
		return ventOf(draw).Target ~= nil
	end,
	RiseOrigin = function(draw, a)
		return a + ventOf(draw).Shift
	end,
	Build = function(ctx, draw, a, b, sized)
		local up = lift(ctx, draw)
		local state = ventOf(draw)
		local target = state.Target

		if not draw.Rise and target then
			local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			local stop = if state.TargetEnd or flat.Magnitude < 0.05 then b else b - flat.Unit * up.Y
			local run = Vector3.new(stop.X - a.X, 0, stop.Z - a.Z).Magnitude
			local rise = target - a.Y
			local at = state.TargetAt
			local aside = if at then Vector3.new(at.X - stop.X, 0, at.Z - stop.Z).Magnitude else 0

			state.Why = if aside > 0.15
				then string.format("The openings are %.2f studs out of line; line them up along X or Z.", aside)
				elseif
					run < 0.5 or math.abs(rise) > run * MAX_STEEP
				then "Too steep to reach that vent; start the slope further back."
				else nil

			if state.Why then
				state.Ends = nil

				return {}
			end

			return slope(ctx, draw, a + up, stop + Vector3.new(0, rise, 0) + up)
		elseif not draw.Rise then
			return Vents.VentRun(sizing(ctx, draw), a, b, nil)
		end

		local run = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
		local top = b + Vector3.new(0, math.clamp(sized.Signed, -run, run), 0)

		return slope(ctx, draw, a + up, top + up)
	end,
	Problem = function(_specs, draw)
		return if ventOf(draw).Target then ventOf(draw).Why else nil
	end,
	Commit = commit,
}

local ventShaft: Engine.Shape = {
	Id = "VentShaft",
	Vents = true,
	Start = start(true),
	Idle = idle,
	OnStart = onStart(false, false),
	Built = built,
	Shaft = true,
	Build = function(ctx, draw, a, _b, sized)
		local size = Settings.VentOuter(sizing(ctx, draw))
		local host = ventOf(draw).Host
		local top = a + Vector3.new(0, sized.Signed, 0)
		local bottom = a

		if host and math.abs(host.Y) < 0.5 and math.abs(sized.Signed) > size / 2 + 0.1 then
			bottom = a + Vector3.new(0, math.sign(sized.Signed) * size / 2, 0)
		end

		ventOf(draw).Ends = { bottom, top }

		return Vents.VentDuct(sizing(ctx, draw), bottom, top)
	end,
	Commit = commit,
}

return {
	Engine.Tool(vent),
	Engine.Tool(ventRamp),
	Engine.Tool(ventShaft),
}
