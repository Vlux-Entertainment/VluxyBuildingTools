--!strict

--[=[
	Grab, rotate and scale (G, R, C), and duplicate (V then move), as in Blender. The selection
	follows the mouse until a click or Enter confirms or Esc cancels; X / Y / Z lock an axis, Alt+X /
	Y / Z a plane, and a typed number sets an exact value. The whole action is one undo step, and
	cancelling puts every part back.

	The maths lives in `Core/Transform`; this wraps it in an undo recording and the modal contract.

	@class Move
]=]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local Arrange = require("../Core/Arrange")
local AxisLock = require("../Pure/AxisLock")
local Common = require("../Tools/Common")
local Cursor = require("../Services/Cursor")
local Geometry = require("../Core/Geometry")
local ModalTypes = require("./Types")
local NumericInput = require("../Pure/NumericInput")
local Overlay = require("../Core/Overlay")
local ToolTypes = require("../Tools/Types")
local Transform = require("../Core/Transform")

type Context = ToolTypes.Context

local GLYPH = "✥"

local Move = {}

--[=[
	Starts moving, turning or sizing the selection.

	@param ctx Context
	@param kind Transform.Kind -- Grab, Rotate or Scale
	@param duplicate boolean -- copy the selection first and move the copy
	@return Modal? -- the running action, or nil after saying why it could not start
]=]
function Move.Start(ctx: Context, kind: Transform.Kind, duplicate: boolean): ModalTypes.Modal?
	local roots = Geometry.SelectedRoots()
	local parts = Geometry.PartsOf(roots)

	if #parts == 0 then
		ctx.Say("Select Parts or Models first.")

		return nil
	end

	if not workspace.CurrentCamera then
		ctx.Say("No camera to work from.")

		return nil
	end

	if duplicate then
		for _, root in roots do
			if not root.Archivable then
				ctx.Say("Enable Archivable on selected objects first.")

				return nil
			end
		end
	end

	local recording = ChangeHistoryService:TryBeginRecording("Vlux_" .. kind, kind)

	if not recording then
		ctx.Say("Finish the other tool action first.")

		return nil
	end

	if duplicate then
		local copies = Arrange.CloneRoots(roots, function(cf)
			return cf
		end)

		Selection:Set(copies)
		parts = Geometry.PartsOf(copies)
	end

	local cursor = ctx.Cursor
	local session = Transform.Begin(kind, parts, Cursor.Screen(), Cursor.Ray(cursor), Cursor.Look())
	local hints = { { "X Y Z", "Axis" }, { "0-9", "Type value" }, { "Enter", "Confirm" }, { "Esc", "Cancel" } }

	if kind == "Rotate" then
		table.insert(hints, 2, { "←↑↓→", "±90°" })
	end

	--[[
		@param commit boolean
		Ends the undo recording, keeping or undoing the change.
	]]
	local function finish(commit: boolean)
		if not commit then
			Transform.Restore(session)
		end

		ChangeHistoryService:FinishRecording(
			recording,
			if commit then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
		)
		Overlay.HideReadout(ctx.Overlay)
		ctx.Say(if commit then "Done; Ctrl+Z undoes it." else "Cancelled.")
	end

	local modal: ModalTypes.Modal

	modal = {
		Activity = { Glyph = GLYPH, Name = kind, Hints = hints },
		Numeric = session.Numeric,
		Step = function(): boolean
			for _, part in session.Parts do
				if not part:IsDescendantOf(workspace) then
					modal.Cancel()

					return false
				end
			end

			local text, position =
				Transform.Update(session, Cursor.Grid(cursor), Cursor.Screen(), Cursor.Ray(cursor), Cursor.Look())

			Overlay.Readout(ctx.Overlay, position, text)

			return true
		end,
		Confirm = function(): boolean
			finish(true)

			return true
		end,
		Cancel = function()
			finish(false)
		end,
		Lock = function(axis: AxisLock.Axis, plane: boolean)
			local updated = AxisLock.Toggle(session.Lock, axis, plane)

			Transform.SetLock(session, updated, Cursor.Ray(cursor), Cursor.Look())
			NumericInput.Clear(session.Numeric)
			ctx.Say(Common.LockMessage(updated, axis, plane))
		end,
		Key = function(name: string): boolean
			if kind ~= "Rotate" then
				return false
			end

			local step = if name == "Up" or name == "Right"
				then 90
				elseif name == "Down" or name == "Left" then -90
				else 0

			if step == 0 then
				return false
			end

			session.Numeric.Text = tostring((NumericInput.Value(session.Numeric) or 0) + step)

			return true
		end,
	}

	ctx.Say(
		(if duplicate then "Duplicate, then move. " else "")
			.. `{kind}: move the mouse. X / Y / Z locks an axis, Alt+X / Y / Z a plane; type a number for an exact value. Click or Enter confirms; Esc cancels.`
	)

	return modal
end

return Move
