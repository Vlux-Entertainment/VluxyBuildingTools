--!strict

--[=[
	The tools that cut an opening into a plain wall: doorway, window, circle window, triangle window
	and archway. The opening is centered on the cursor.

	With the Set cut depth with mouse setting on, the first click fixes the spot and the mouse then
	sets how deep the cut goes; past the far side it cuts all the way through. Otherwise one click
	cuts through, as does a doorway with a frame or door, which only fit an opening that goes through.

	@class OpeningTools
]=]

local Common = require("./Common")
local Cursor = require("../Services/Cursor")
local Geometry = require("../Core/Geometry")
local Joints = require("../Core/Joints")
local Openings = require("../Core/Builders/Openings")
local Overlay = require("../Core/Overlay")
local Settings = require("../Pure/Settings")
local Shapes = require("../Core/Builders/Shapes")
local Snap = require("../Pure/Snap")
local Types = require("./Types")

type Context = Types.Context

type Opening = {
	--[=[ The wall spot the first click fixed, while the cut depth is being set. ]=]
	Locked: RaycastResult?,
	Depth: number?,
	--[=[ From the last preview: the wall to replace, the cuts to carve and what to build. ]=]
	Target: BasePart?,
	Cuts: { Shapes.Cutter }?,
	Specs: { Geometry.Spec },
}

--[[
	@param settings Settings
	@param mode string
	@return { [string]: any } -- the size of the opening to cut, and the door options for a doorway
]]
local function dimensions(settings: Settings.Settings, mode: string): { [string]: any }
	if mode == "Door" then
		return {
			Width = settings.DoorWidth,
			Height = settings.DoorHeight,
			Sill = 0,
			Panel = settings.DoorPanel,
			Frame = settings.DoorFrame,
			FrameWidth = settings.FrameWidth,
			FrameDepth = settings.FrameDepth,
			DoorThickness = settings.DoorThickness,
			DoorTransparency = settings.DoorTransparency,
			DoorCollide = settings.DoorCollide,
		}
	elseif mode == "CircleWindow" then
		local diameter = math.min(settings.WindowWidth, settings.WindowHeight)

		return { Width = diameter, Height = diameter, Sill = settings.WindowSill }
	elseif mode == "Window" or mode == "TriangleWindow" then
		return { Width = settings.WindowWidth, Height = settings.WindowHeight, Sill = settings.WindowSill }
	end

	return { Width = settings.OpenWidth, Height = settings.OpenHeight, Sill = 0 }
end

local SHAPES: { [string]: string } = {
	Door = "Rect",
	Window = "Rect",
	CircleWindow = "Circle",
	TriangleWindow = "Triangle",
	ArchOpening = "Arch",
}

--[[
	@param ctx Context
	@param hit RaycastResult -- the wall spot that was clicked
	@param previous number? -- the depth from the last frame, kept when the camera looks along the wall
	@return number? -- how far into the wall the mouse points, along the wall's normal, snapped to the fine grid

	It intersects the mouse ray with the vertical plane through the clicked spot that holds the wall normal.
]]
local function depthFrom(ctx: Context, hit: RaycastResult, previous: number?): number?
	local plane = hit.Normal:Cross(Vector3.yAxis)

	if plane.Magnitude < 0.1 then
		return previous
	end

	local ray = Cursor.Ray(ctx.Cursor)
	local unit = plane.Unit
	local denominator = ray.Direction:Dot(unit)

	if math.abs(denominator) < 0.05 then
		return previous
	end

	local point = ray.Origin + ray.Direction * ((hit.Position - ray.Origin):Dot(unit) / denominator)
	local step = math.max(0.05, ctx.Settings.FineGrid)

	return math.max(step, Snap.Round((point - hit.Position):Dot(-hit.Normal), step))
end

--[[
	@param ctx Context
	@param state Opening

	Forgets the fixed spot, so the next click starts again.
]]
local function reset(ctx: Context, state: Opening)
	state.Locked, state.Depth, state.Target, state.Cuts, state.Specs = nil, nil, nil, nil, {}
	Overlay.ClearGhosts(ctx.Overlay)
end

--[[
	@param mode string
	@return Tool
]]
local function opening(mode: string): Types.Tool
	local function preview(ctx: Context, state: Opening): Types.Preview
		local locked = state.Locked

		if locked then
			state.Depth = depthFrom(ctx, locked, state.Depth)
		end

		local out, message, target, cut, cuts = Openings.Opening(
			Common.Live(ctx),
			dimensions(ctx.Settings, mode) :: any,
			locked or Cursor.ScopedHit(ctx.Cursor),
			SHAPES[mode],
			state.Depth
		)

		state.Target, state.Cuts, state.Specs = target, cuts, out

		if locked and (#out > 0 or cuts) then
			message = if state.Depth
				then string.format("Cut depth %.2f; click to confirm.", state.Depth)
				else "Move the mouse to set the cut depth, then click."
		end

		return { Specs = out, Valid = #out > 0 or cuts ~= nil, Message = message, Cut = cut }
	end

	local function click(ctx: Context, state: Opening, shown: Types.Preview?)
		if not shown or not shown.Valid then
			return
		end

		local settings = ctx.Settings
		local fitted = mode == "Door" and (settings.DoorFrame or settings.DoorPanel)

		if settings.CutDepth and not fitted and not state.Locked then
			local hit = Cursor.ScopedHit(ctx.Cursor)

			if hit then
				state.Locked = hit
				state.Depth = nil
				ctx.Say("Move the mouse to set the cut depth, then click.")
			end

			return
		end

		local target, specs, cuts = state.Target, state.Specs, state.Cuts
		local name = if mode == "ArchOpening" then "Archway" else "Wall_" .. mode

		ctx.Edit(if mode == "ArchOpening" then "Create archway" else "Create " .. string.lower(mode), function()
			assert(target and target.Parent, "Wall no longer exists")

			if cuts then
				if not Joints.Carve(target, cuts) then
					ctx.Say("The wall could not be cut.")
				end

				if #specs > 0 then
					Geometry.Materialize(specs, "Wall_" .. mode)
				end

				return
			end

			local model = Geometry.Materialize(specs, name)
			local problem = if mode == "ArchOpening"
				then Geometry.UnionSides(model, "Arch_Header", "Arch")
				elseif mode == "CircleWindow" then Geometry.UnionNamed(model, "Circle_Upper", "Circle_Frame")
					or Geometry.UnionNamed(model, "Circle_Lower", "Circle_Frame")
				else nil

			if problem then
				ctx.Say(problem)
			end

			local holder = target.Parent

			target.Parent = nil

			if holder and holder:IsA("Model") and #holder:GetChildren() == 0 then
				holder.Parent = nil
			end
		end)
		reset(ctx, state)
	end

	return {
		Id = mode,
		Begin = function(): Opening
			return { Locked = nil, Depth = nil, Target = nil, Cuts = nil, Specs = {} }
		end,
		Preview = preview,
		Click = click,
		Back = function(ctx: Context, state: Opening): string?
			if not state.Locked then
				return nil
			end

			reset(ctx, state)

			return "Cut cancelled."
		end,
	}
end

return {
	opening("Door"),
	opening("Window"),
	opening("CircleWindow"),
	opening("TriangleWindow"),
	opening("ArchOpening"),
}
