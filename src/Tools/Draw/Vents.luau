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
local OVERLAP = 0.05
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
	@param model Model -- the vent just built
	@param a Vector3 -- one end of the duct, on its middle line
	@param b Vector3 -- the other end
	@param skip { Instance } -- the vents this one continues end to end, left uncut

	Records the vent's open ends, then cuts the duct and its openings out of every other part it
	passes through, and opens the side of any vent it joins.
]]
local function finish(ctx: Context, model: Model, a: Vector3, b: Vector3, skip: { Instance })
	if (b - a).Magnitude < 0.05 then
		return
	end

	local dir = Snapper.VentFacing(b - a)

	model:SetAttribute("VluxyBT_VentStart", a)
	model:SetAttribute("VluxyBT_VentStartDir", -dir)
	model:SetAttribute("VluxyBT_VentEnd", b)
	model:SetAttribute("VluxyBT_VentEndDir", dir)
	CollectionService:AddTag(model, VENT_TAG)

	local failed = 0
	local cutters = Vents.VentCutters(ctx.Settings, a, b)

	for part in
		touched(cutters, function(candidate)
			return not inVent(candidate) and not candidate:IsA("Terrain")
		end)
	do
		if not Joints.Carve(part, cutters) then
			failed += 1
		end
	end

	local joins = Vents.VentJoinCutters(ctx.Settings, a, b)

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
		finish(ctx, built.Model, ends[1], ends[2], skip)
	end
end

--[[
	@param shaft boolean
	@return (ctx, draw) -> Vector3? -- a start picker for a vent
]]
local function start(shaft: boolean): (ctx: Context, draw: Draw) -> Vector3?
	return function(ctx: Context, draw: Draw): Vector3?
		return Points.Vent(ctx, draw, shaft)
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
		center, facing = mark + vent.HitFace * (size / 2), vent.HitFace
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
		vent.Corner = vent.HitCorner and not vent.Host

		local a = if owner then owner:GetAttribute("VluxyBT_VentStart") else nil
		local b = if owner then owner:GetAttribute("VluxyBT_VentEnd") else nil
		local level = typeof(a) == "Vector3" and typeof(b) == "Vector3" and math.abs(b.Y - a.Y) < 0.05

		if chains and owner and vent.End and level then
			draw.Previous = { model = owner, dir = vent.End, strips = Vents.VentStrips(ctx.Settings) }
			draw.Chained = true
		end
	end
end

--[[ After a build the next section starts in the open, not against a surface or another vent. ]]
local function built(draw: Draw)
	local vent = ventOf(draw)

	vent.Normal, vent.Shift, vent.Host = nil, Vector3.zero, nil
	vent.Owner, vent.End, vent.Corner = nil, nil, nil
	vent.Target, vent.TargetOwner, vent.TargetEnd, vent.TargetAt, vent.Why = nil, nil, nil, nil, nil
end

--[[
	@param ctx Context
	@param origin Vector3
	@param direction Vector3 -- the run's direction along X or Z
	@return number? -- how far the run may go before it meets the side of a level vent under the cursor, so it ends flush against it
]]
local function meetHost(ctx: Context, origin: Vector3, direction: Vector3): number?
	local size = Settings.VentOuter(ctx.Settings)
	local aim = Cursor.Hit(ctx.Cursor)
	local _, _, owner = if aim then Snapper.VentConnect(aim.Position, size * 1.1, 1) else nil, nil, nil
	local hostA = if owner then owner:GetAttribute("VluxyBT_VentStart") else nil
	local hostB = if owner then owner:GetAttribute("VluxyBT_VentEnd") else nil

	if typeof(hostA) ~= "Vector3" or typeof(hostB) ~= "Vector3" or math.abs(hostB.Y - hostA.Y) >= 0.05 then
		return nil
	end

	local along = Vector3.new(hostB.X - hostA.X, 0, hostB.Z - hostA.Z)

	if along.Magnitude <= 0.05 then
		return nil
	end

	local hostDir = along.Unit
	local cross = direction.X * hostDir.Z - direction.Z * hostDir.X
	local reachTo = Vector3.new(hostA.X - origin.X, 0, hostA.Z - origin.Z)
	local s = (reachTo.X * hostDir.Z - reachTo.Z * hostDir.X) / (if cross == 0 then 1 else cross)
	local meet = origin + direction * s
	local position = Vector3.new(meet.X - hostA.X, 0, meet.Z - hostA.Z):Dot(hostDir)
	local centreY = origin.Y + size / 2

	if
		math.abs(cross) > 0.9
		and math.abs(hostA.Y - centreY) < size * 0.5
		and position > -0.1
		and position < along.Magnitude + 0.1
		and s - size / 2 > 0.1
	then
		return s - size / 2
	end

	return nil
end

--[[
	@param ctx Context
	@param draw Draw
	@param a Vector3
	@param b Vector3
	@return Vector3, Vector3 -- the run pulled onto X or Z, never doubling back on the last section, ending flush against a vent it meets, and pushed against the surface it started on
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

	b = a + direction * math.max(0, (b - a):Dot(direction))

	local meet = meetHost(ctx, a, direction)

	if meet then
		b = a + direction * meet
	end

	if not draw.Chained and vent.Corner then
		vent.Shift = direction * (Settings.VentOuter(ctx.Settings) / 2)

		return a + vent.Shift, b
	end

	if not draw.Chained and vent.Normal then
		local sideways = math.abs(direction:Dot(vent.Normal)) < 0.5

		vent.Shift = if sideways then vent.Normal * (Settings.VentOuter(ctx.Settings) / 2 - 0.03) else Vector3.zero
	end

	if not draw.Chained and vent.Host then
		local into = math.abs(direction:Dot(vent.Host)) < 0.5

		vent.Shift = if into then direction * (Settings.VentOuter(ctx.Settings) / 2) else Vector3.zero

		return a + vent.Shift, b
	end

	return a + vent.Shift, b + vent.Shift
end

--[[
	@param ctx Context
	@return Vector3 -- from the floor of the duct to its middle line
]]
local function lift(ctx: Context): Vector3
	return Vector3.new(0, Settings.VentOuter(ctx.Settings) / 2, 0)
end

--[[
	@param ctx Context
	@param draw Draw
	@param a Vector3 -- the start, on the middle line
	@param b Vector3 -- the end, on the middle line
	@return boolean -- whether the run would pass through a vent other than the ones it starts from
]]
local function blocked(ctx: Context, draw: Draw, a: Vector3, b: Vector3): boolean
	local skip: { Instance } = {}
	local owner = ventOf(draw).Owner

	if draw.Previous then
		table.insert(skip, draw.Previous.model)
	end

	if owner and not ventOf(draw).Corner then
		table.insert(skip, owner)
	end

	return (b - a).Magnitude > 0.1 and Snapper.VentBlocked(a, b, Settings.VentOuter(ctx.Settings), skip)
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
		local up = lift(ctx)

		if blocked(ctx, draw, a + up, b + up) then
			ventOf(draw).Ends = nil

			return {}
		end

		local outward = ventOf(draw).End

		ventOf(draw).Ends = { a + up, b + up }

		if draw.Chained and draw.Previous then
			return Vents.VentRun(ctx.Settings, a, b, draw.Previous.dir)
		elseif outward then
			return Vents.VentRun(ctx.Settings, a - outward * OVERLAP, b, outward)
		end

		return Vents.VentRun(ctx.Settings, a, b, nil)
	end,
	Problem = function(_specs, draw)
		local ends = ventOf(draw).Ends

		return if ends == nil and draw.First then "That would run into another vent; start beside it." else nil
	end,
	Commit = function(ctx, draw, result)
		Bends.Join(draw, result, Vents.VentStrips(ctx.Settings))
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
	local point, outward, owner = Snapper.VentConnect(hit.Position, size * 1.1, step, size / 2)
	local bottom = if point then point.Y - size / 2 else origin.Y

	if not point or not owner or owner == state.Owner or math.abs(bottom - origin.Y) < 0.1 then
		return nil
	elseif outward and math.abs(outward.Y) > 0.5 then
		return nil
	end

	state.Target, state.TargetOwner, state.TargetEnd = bottom, owner, outward
	ctx.Cursor.Mark = point

	return Vector3.new(point.X, origin.Y, point.Z)
end

--[[
	@param ctx Context
	@param draw Draw
	@param from Vector3 -- the low or first end, on the middle line
	@param to Vector3 -- the other end, on the middle line
	@return { Spec } -- the sloped duct, reaching a little into the vents it continues so no gap shows
]]
local function slope(ctx: Context, draw: Draw, from: Vector3, to: Vector3): { Geometry.Spec }
	local state = ventOf(draw)
	local along = (to - from).Unit

	ventOf(draw).Ends = { from, to }

	if state.End then
		from -= along * (OVERLAP + 0.03)
	end

	if state.TargetEnd then
		to += along * (OVERLAP + 0.03)
	end

	return Vents.VentDuct(ctx.Settings, from, to)
end

local ventRamp: Engine.Shape = {
	Id = "VentRamp",
	Vents = true,
	Start = start(false),
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
		local up = lift(ctx)
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
				then string.format("The holes are %.2f studs out of line; line them up along X or Z.", aside)
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
			return Vents.VentRun(ctx.Settings, a, b, nil)
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
		local size = Settings.VentOuter(ctx.Settings)
		local host = ventOf(draw).Host
		local top = a + Vector3.new(0, sized.Signed, 0)
		local bottom = a

		if host and math.abs(host.Y) < 0.5 and math.abs(sized.Signed) > size / 2 + 0.1 then
			bottom = a + Vector3.new(0, math.sign(sized.Signed) * size / 2, 0)
		end

		ventOf(draw).Ends = { bottom, top }

		return Vents.VentDuct(ctx.Settings, bottom, top)
	end,
	Commit = commit,
}

return {
	Engine.Tool(vent),
	Engine.Tool(ventRamp),
	Engine.Tool(ventShaft),
}
