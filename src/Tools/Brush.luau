--!strict

--[=[
	Brush (the `Place` mode): paints copies of objects onto surfaces by clicking or dragging. It
	paints the brushes that are switched on in the panel, picking one at random for every copy, or
	the selection when there are no brushes. Clicking an object with no brush ready, or with Ctrl
	held, adds it to the brushes.

	A drag is a stroke: copies are previewed as it goes and all made in one undo step when the
	button is released.

	@class Brush
]=]

local Selection = game:GetService("Selection")
local UserInputService = game:GetService("UserInputService")

local Brushes = require("../Core/Brushes")
local Builders = require("../Core/Builders")
local Cursor = require("../Services/Cursor")
local Geometry = require("../Core/Geometry")
local Overlay = require("../Core/Overlay")
local Types = require("./Types")

type Context = Types.Context

--[=[
	One thing the brush can paint: the objects to copy and their parts' bounds.

	@interface Item
	@within Brush
	.roots { Instance }
	.source Builders.Source
]=]
type Item = { roots: { Instance }, source: Builders.Source }

--[=[
	@interface BrushState
	@within Brush
	.Pool { Item } -- what the brush picks from
	.Item Item? -- the one the next copy uses
	.Scale number -- the size of the next copy
	.Stroke boolean -- true while the mouse is held down painting
	.Last Vector3? -- where the last copy of the stroke was painted
	.Targets { { cf: CFrame, item: Item, scale: number } } -- the stroke's copies
	.Specs { Spec } -- their ghosts
]=]
type BrushState = {
	Pool: { Item },
	Item: Item?,
	Scale: number,
	Stroke: boolean,
	Last: Vector3?,
	Targets: { { cf: CFrame, item: Item, scale: number } },
	Specs: { Geometry.Spec },
}

local MAX_PARTS = 600

--[[
	@param state BrushState
	@return string? -- why the brush has nothing to paint with, or nil when the pool is ready

	Fills the pool from the brushes that are on, or from the selection when none are.
]]
local function fillPool(state: BrushState): string?
	local sets: { { Instance } } = {}

	for _, entry in Brushes.Enabled() do
		table.insert(sets, { entry })
	end

	if #sets == 0 then
		local roots = Geometry.SelectedRoots()

		if #roots > 0 then
			table.insert(sets, roots)
		end
	end

	if #sets == 0 then
		return "Add something to the brushes first: click an object in the viewport, or select it and press Add selected to brushes."
	end

	local pool: { Item } = {}

	for _, roots in sets do
		local parts = Geometry.PartsOf(roots)

		if #parts > MAX_PARTS then
			return "A brush supports up to 600 Parts."
		end

		for _, root in roots do
			if not root.Archivable then
				return "Enable Archivable on each brush object before painting."
			end
		end

		if #parts > 0 then
			local pivot, size = Geometry.Bounds(parts)

			table.insert(pool, { roots = roots, source = { Parts = parts, Pivot = pivot, Size = size } })
		end
	end

	if #pool == 0 then
		return "Those objects have no Parts to paint with."
	end

	state.Pool = pool

	return nil
end

--[[
	@param ctx Context
	@param state BrushState

	Chooses the brush and size of the next copy, so the preview shows it.
]]
local function roll(ctx: Context, state: BrushState)
	local item = state.Pool[math.random(1, math.max(1, #state.Pool))]

	if not item then
		return
	end

	local low = math.max(0.05, math.min(ctx.Settings.BrushSizeMin, ctx.Settings.BrushSizeMax))
	local high = math.max(low, ctx.Settings.BrushSizeMax)

	state.Item = item
	state.Scale = low + math.random() * (high - low)
end

--[[
	@param ctx Context
	@param state BrushState

	Reads the brushes again: rolls the next copy when there is something to paint, else empties the pool.
]]
local function reload(ctx: Context, state: BrushState): string?
	local problem = fillPool(state)

	if problem then
		state.Pool, state.Item = {}, nil
	else
		roll(ctx, state)
	end

	return problem
end

--[[
	@param state BrushState
	@return { Instance } -- what the cursor ray passes through: the objects being copied
]]
local function exclude(state: BrushState): { Instance }
	return if state.Item then state.Item.roots else {}
end

--[[
	@param ctx Context
	@param state BrushState
	@param hit RaycastResult -- the surface the brush is over

	Adds one copy to the stroke: the first right under the cursor, the rest scattered within the radius.
]]
local function step(ctx: Context, state: BrushState, hit: RaycastResult)
	local item = state.Item
	local settings = ctx.Settings
	local spot, normal = hit.Position, hit.Normal

	if not item then
		return
	end

	if #state.Targets > 0 and settings.BrushRadius > 0 then
		local angle = math.random() * math.pi * 2
		local reach = math.sqrt(math.random()) * settings.BrushRadius
		local across = (if math.abs(normal.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis):Cross(normal).Unit
		local along = normal:Cross(across)
		local from = hit.Position + across * (math.cos(angle) * reach) + along * (math.sin(angle) * reach)
		local params = RaycastParams.new()

		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = item.roots

		local found = workspace:Raycast(from + normal * 8, -normal * 16, params)

		if not found then
			return
		end

		spot, normal = found.Position, found.Normal
	end

	state.Last = hit.Position

	local yaw = if settings.BrushRandomYaw then math.random() * 360 else settings.Yaw
	local specs, target = Builders.PlaceAt(settings, spot, normal, item.source, yaw, state.Scale)

	table.insert(state.Targets, { cf = target, item = item, scale = state.Scale })

	for _, spec in specs do
		table.insert(state.Specs, spec)
	end

	roll(ctx, state)
end

--[[
	@param ctx Context
	@param state BrushState

	Makes every copy of the stroke as one undo step and clears the stroke.
]]
local function finishStroke(ctx: Context, state: BrushState)
	local targets = state.Targets

	state.Stroke, state.Last, state.Targets, state.Specs = false, nil, {}, {}
	Overlay.ClearGhosts(ctx.Overlay)

	if #targets == 0 then
		return
	end

	ctx.Edit("Brush copies", function()
		local parent = Geometry.GetScope() or workspace

		for _, stamp in targets do
			local pivot = stamp.item.source.Pivot

			for _, root in stamp.item.roots do
				local copy = root:Clone()

				if copy then
					if stamp.scale ~= 1 then
						if copy:IsA("Model") then
							copy:ScaleTo(stamp.scale)
						elseif copy:IsA("BasePart") then
							copy.Size *= stamp.scale
						end
					end

					local relative = pivot:ToObjectSpace((root :: any):GetPivot())
					local scaled = CFrame.new(relative.Position * stamp.scale) * (relative - relative.Position)

					copy.Parent = parent;
					(copy :: any):PivotTo(stamp.cf * scaled)
				end
			end
		end
	end)
end

--[[
	@param ctx Context
	@param state BrushState
	@param hit RaycastResult

	Adds the object under the cursor (its outermost Model) to the brushes.
]]
local function addClicked(ctx: Context, state: BrushState, hit: RaycastResult)
	local object: Instance = hit.Instance

	while object.Parent and object.Parent:IsA("Model") and object.Parent ~= workspace do
		object = object.Parent
	end

	Selection:Set({ object })

	local count, message = Brushes.AddSelected()

	ctx.Sound(if count > 0 then "BrushAdd" else "Warning")
	reload(ctx, state)
	ctx.State.BrushRevision(ctx.State.BrushRevision() + 1)
	ctx.Say(message)
end

local tool: Types.Tool = {
	Id = "Place",
	Turns = true,
	Begin = function(ctx: Context): BrushState
		local state: BrushState = {
			Pool = {},
			Item = nil,
			Scale = 1,
			Stroke = false,
			Last = nil,
			Targets = {},
			Specs = {},
		}

		reload(ctx, state)

		return state
	end,
	Preview = function(ctx: Context, state: BrushState): Types.Preview?
		local hit = Cursor.Hit(ctx.Cursor, exclude(state))
		local item = state.Item
		local out, placeMessage = Builders.Place(ctx.Settings, hit, if item then item.source else nil, state.Scale)
		local message: string? = placeMessage

		if not item then
			out = {}
			message = if reload(ctx, state) then "Click an object to add it to the brushes." else nil
		end

		if state.Stroke then
			if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				finishStroke(ctx, state)
			elseif hit and (not state.Last or (hit.Position - state.Last).Magnitude >= ctx.Settings.BrushSpacing) then
				step(ctx, state, hit)
			end
		end

		for _, spec in state.Specs do
			table.insert(out, spec)
		end

		return { Specs = out, Valid = #out > 0, Message = message }
	end,
	Click = function(ctx: Context, state: BrushState, shown: Types.Preview?)
		local hit = Cursor.Hit(ctx.Cursor, exclude(state))

		if hit and (Cursor.Ctrl() or not state.Item) then
			return addClicked(ctx, state, hit)
		end

		if not shown or not shown.Valid or not hit or not state.Item then
			return
		end

		state.Stroke = true
		state.Targets, state.Specs, state.Last = {}, {}, nil
		step(ctx, state, hit)
	end,
	Release = function(ctx: Context, state: BrushState)
		if state.Stroke then
			finishStroke(ctx, state)
		end
	end,
	Refresh = function(ctx: Context, state: BrushState)
		reload(ctx, state)
	end,
}

return { tool }
