--!strict

--[=[
	Extrude (T): grows a new block out of one face of a plain block. The mouse pulls the face out,
	or a typed number sets the length; click or Enter builds it as one undo step.

	The face is the one under the cursor, or, with one block selected and nothing under the cursor,
	the face of the selection that looks most toward the camera.

	@class Extrude
]=]

local Selection = game:GetService("Selection")

local Cursor = require("../Services/Cursor")
local Geometry = require("../Core/Geometry")
local ModalTypes = require("./Types")
local NumericInput = require("../Pure/NumericInput")
local Openings = require("../Core/Builders/Openings")
local Overlay = require("../Core/Overlay")
local ToolTypes = require("../Tools/Types")

type Context = ToolTypes.Context

local MAX_LENGTH = 2048
local FACES = { Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis }

local Extrude = {}

--[[
	@param ctx Context
	@return BasePart? -- the block to extrude
	@return Vector3 -- the world normal of the face to grow from
]]
local function pickFace(ctx: Context): (BasePart?, Vector3)
	local hit = Cursor.Hit(ctx.Cursor)

	if hit and Geometry.IsPlainBlock(hit.Instance) and Geometry.InScope(hit.Instance) then
		return hit.Instance :: BasePart, hit.Normal
	end

	local selected = Selection:Get()
	local chosen = selected[1]

	if #selected == 1 and chosen and Geometry.IsPlainBlock(chosen) and Geometry.InScope(chosen) then
		local part = chosen :: BasePart
		local toward = -Cursor.Look()
		local best, bestDot = Vector3.yAxis, -math.huge

		for _, face in FACES do
			local world = part.CFrame:VectorToWorldSpace(face)
			local dot = world:Dot(toward)

			if dot > bestDot then
				best, bestDot = world, dot
			end
		end

		return part, best
	end

	return nil, Vector3.yAxis
end

--[=[
	Starts extruding the face under the cursor or of the selected block.

	@param ctx Context
	@return Modal? -- the running action, or nil after saying why it could not start
]=]
function Extrude.Start(ctx: Context): ModalTypes.Modal?
	local part, picked = pickFace(ctx)

	if not part then
		ctx.Say("Point at a rectangular block, or select one, then press T to extrude a face.")

		return nil
	end

	local axis, side = Openings.FaceAxis(part, picked)
	local localUnit = if axis == 1 then Vector3.xAxis elseif axis == 2 then Vector3.yAxis else Vector3.zAxis
	local half = (if axis == 1 then part.Size.X elseif axis == 2 then part.Size.Y else part.Size.Z) / 2
	local normal = part.CFrame:VectorToWorldSpace(localUnit * side)
	local origin = part.Position + normal * half
	local numeric = NumericInput.new()
	local length = 0
	local modal: ModalTypes.Modal

	local function clear()
		Overlay.ClearGhosts(ctx.Overlay)
		Overlay.HideReadout(ctx.Overlay)
	end

	modal = {
		Activity = {
			Glyph = "⧉",
			Name = "Extrude",
			Hints = { { "0-9", "Type length" }, { "Enter", "Confirm" }, { "Esc", "Cancel" } },
		},
		Numeric = numeric,
		Step = function(): boolean
			if not part:IsDescendantOf(workspace) then
				clear()

				return false
			end

			local typed = NumericInput.Value(numeric)
			local along = if typed then nil else Cursor.AlongLine(ctx.Cursor, origin, normal)

			length = math.clamp(typed or (if along then Cursor.Snap(ctx.Cursor, along) else 0), 0, MAX_LENGTH)

			if length <= 0.001 then
				clear()

				return true
			end

			local out = Openings.Extend(ctx.Settings, part, normal, length)

			Overlay.DrawGhosts(ctx.Overlay, out)

			if out[1] then
				Overlay.Readout(ctx.Overlay, out[1].cf.Position, string.format("Extrude %.2f studs", length))
			end

			return true
		end,
		Confirm = function(): boolean
			if length < math.max(0.05, Cursor.Grid(ctx.Cursor) * 0.5) then
				ctx.Say("Move the mouse away from the face, or type a length, then click.")

				return false
			end

			local out = Openings.Extend(ctx.Settings, part, normal, length)

			ctx.Edit("Extrude face", function()
				Geometry.Materialize(out, "Face_Extension")
			end)
			clear()
			ctx.Say(string.format("Extruded %.2f studs; press T to keep going.", length))

			return true
		end,
		Cancel = function()
			clear()
			ctx.Say("Extrude cancelled.")
		end,
		Lock = function()
			ctx.Say("Type a number for an exact length.")
		end,
	}

	ctx.Say("Extrude: move the mouse, then click; Esc cancels.")

	return modal
end

return Extrude
