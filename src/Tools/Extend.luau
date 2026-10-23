--!strict

--[=[
	Face Extend: click a plain block to put green handles on its faces, then drag a handle outward
	and release to add a connected block. The new block gets the handles, so dragging can go on.

	The handles' connections belong to the tool: they are made when the tool starts and cleaned up
	when it is left.

	@class Extend
]=]

local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local UserInputService = game:GetService("UserInputService")

local Cursor = require("../Services/Cursor")
local Geometry = require("../Core/Geometry")
local Openings = require("../Core/Builders/Openings")
local Overlay = require("../Core/Overlay")
local Tools = require("../Pure/Tools")
local Trove = require("../Packages/Trove")
local Types = require("./Types")

type Context = Types.Context

--[=[
	@interface ExtendState
	@within Extend
	.Drag { source: BasePart, normal: Vector3, length: number }? -- the handle drag in progress
	.Hover boolean -- the mouse is over a handle, so a click is for the handle, not the block under it
	.Trove Trove -- the handle connections
]=]
type ExtendState = {
	Drag: { source: BasePart, normal: Vector3, length: number }?,
	Hover: boolean,
	Trove: Trove.Trove,
}

local MAX_LENGTH = 2048

--[[
	@param ctx Context
	@param part BasePart?

	Puts the face handles on the block, or takes them away.
]]
local function handle(ctx: Context, part: BasePart?)
	ctx.Overlay.FaceHandles.Adornee = part
	ctx.Overlay.FaceHandles.Visible = part ~= nil
end

--[[
	@param ctx Context
	@param state ExtendState

	Builds the dragged block as one undo step when it is long enough, and moves the handles onto it.
]]
local function release(ctx: Context, state: ExtendState)
	local drag = state.Drag

	if not drag then
		return
	end

	state.Drag = nil

	if drag.length >= math.max(0.05, Cursor.Grid(ctx.Cursor)) and drag.source.Parent then
		local out = Openings.Extend(ctx.Settings, drag.source, drag.normal, drag.length)
		local built: Model?

		if ctx.Edit("Drag face extension", function()
			built = Geometry.Materialize(out, "Face_Extension")
		end) then
			handle(ctx, built and built:FindFirstChildWhichIsA("BasePart"))
			ctx.Say("Added " .. drag.length .. " studs.")
		end
	else
		ctx.Say("Drag a green face handle outward to create an extension.")
	end

	Overlay.ClearGhosts(ctx.Overlay)
	Overlay.HideReadout(ctx.Overlay)
end

--[[
	@param ctx Context
	@param state ExtendState

	Wires the face handles to the tool for as long as it runs.
]]
local function connect(ctx: Context, state: ExtendState)
	local handles = ctx.Overlay.FaceHandles
	local trove = state.Trove

	trove:Connect(handles.MouseEnter, function()
		state.Hover = true
	end)
	trove:Connect(handles.MouseLeave, function()
		state.Hover = false
	end)
	trove:Connect(handles.MouseButton1Down, function(face)
		local part = handles.Adornee

		if not part or not part:IsA("BasePart") or not RunService:IsEdit() then
			return
		end

		state.Drag = {
			source = part,
			normal = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face)),
			length = 0,
		}
	end)
	trove:Connect(handles.MouseDrag, function(_face, distance)
		local drag = state.Drag

		if not drag then
			return
		end

		drag.length = math.clamp(Cursor.Snap(ctx.Cursor, distance), 0, MAX_LENGTH)

		if drag.length > 0.001 then
			local out = Openings.Extend(ctx.Settings, drag.source, drag.normal, drag.length)

			Overlay.DrawGhosts(ctx.Overlay, out)
			Overlay.Readout(ctx.Overlay, out[1].cf.Position, string.format("Extend %.2f studs", drag.length))
			ctx.Say(`Release to add {drag.length} studs; Esc cancels.`)
		else
			Overlay.ClearGhosts(ctx.Overlay)
			Overlay.HideReadout(ctx.Overlay)
		end
	end)
	trove:Connect(handles.MouseButton1Up, function()
		release(ctx, state)
	end)
	trove:Connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and state.Drag then
			task.defer(release, ctx, state)
		end
	end)
end

local tool: Types.Tool = {
	Id = "Extend",
	Begin = function(ctx: Context): ExtendState
		local state: ExtendState = { Drag = nil, Hover = false, Trove = Trove.new() :: any }
		local chosen = Selection:Get()

		connect(ctx, state)

		if #chosen == 1 and Geometry.IsPlainBlock(chosen[1]) and Geometry.InScope(chosen[1]) then
			handle(ctx, chosen[1] :: BasePart)
		end

		return state
	end,
	Preview = function(ctx: Context): Types.Preview?
		local handled = ctx.Overlay.FaceHandles.Adornee

		if handled and not handled:IsDescendantOf(workspace) then
			handle(ctx, nil)
		end

		return nil
	end,
	Click = function(ctx: Context, state: ExtendState)
		if state.Drag or state.Hover then
			return
		end

		local hit = Cursor.Hit(ctx.Cursor)

		if
			hit
			and Geometry.IsPlainBlock(hit.Instance)
			and not hit.Instance.Locked
			and Geometry.InScope(hit.Instance)
		then
			handle(ctx, hit.Instance :: BasePart)
			ctx.Say("Drag a green face handle outward, then release.")
		else
			ctx.Say("Click an unlocked rectangular block, then drag one of its green handles.")
		end
	end,
	Confirm = function(ctx: Context): boolean
		ctx.Say(Tools.Instruction("Extend"))

		return true
	end,
	Busy = function(state: ExtendState): boolean
		return state.Drag ~= nil
	end,
	Finish = function(ctx: Context, state: ExtendState)
		state.Trove:Clean()
		state.Drag = nil
		handle(ctx, nil)
	end,
}

return { tool }
