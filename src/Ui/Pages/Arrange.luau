--!strict

--[=[
	The Arrange tab: flip and turn the selection, make repeated copies, and quick actions. Every
	action needs a working folder.

	@class ArrangePage
]=]

local Actions = require("../../App/Actions")
local Controls = require("../Controls")

type Ui = Controls.Ui

--[=[
	@param ui Ui
	@return { Instance } -- the cards of the Arrange tab
]=]
return function(ui: Ui): { Instance }
	local app = ui.App
	local arrange = app.Arrange

	local function guarded(run: () -> ()): () -> ()
		return Actions.Guarded(app, run)
	end

	local function flip(axis: string): Controls.Item
		return {
			Text = "Flip " .. axis,
			Run = guarded(function()
				arrange.Flip(axis)
			end),
		}
	end

	local function turn(axis: string, degrees: number): Controls.Item
		return {
			Text = (if degrees > 0 then "+90° " else "−90° ") .. axis,
			Run = guarded(function()
				arrange.RotateBy(axis, degrees)
			end),
		}
	end

	return {
		Controls.Card(ui, "FLIP SELECTION  (Ctrl+M, then X / Y / Z)", {
			Controls.Text(ui, "Mirrors the selection in place, around its own centre."),
			Controls.ButtonRow(ui, { flip("X"), flip("Y"), flip("Z") }),
		}),
		Controls.Card(ui, "ROTATE 90°  (O, then X / Y / Z)", {
			Controls.ButtonRow(ui, { turn("X", 90), turn("Y", 90), turn("Z", 90) }),
			Controls.ButtonRow(ui, { turn("X", -90), turn("Y", -90), turn("Z", -90) }),
		}),
		Controls.Card(ui, "REPEAT SELECTED OBJECTS", {
			Controls.Number(
				ui,
				{ Key = "Copies", Title = "Extra copies", Min = 1, Max = 100, Step = 1, Integer = true }
			),
			Controls.Number(ui, { Key = "DX", Title = "X spacing", Min = -2048, Max = 2048 }),
			Controls.Number(ui, { Key = "DY", Title = "Y spacing", Min = -2048, Max = 2048 }),
			Controls.Number(ui, { Key = "DZ", Title = "Z spacing", Min = -2048, Max = 2048 }),
			Controls.Button(ui, "Make repeated copies", guarded(arrange.RepeatCopies), true),
		}),
		Controls.Card(ui, "QUICK ACTIONS", {
			Controls.ButtonRow(ui, {
				{ Text = "Snap selection", Run = guarded(arrange.SnapSelection) },
				{ Text = "Show dimensions", Run = guarded(arrange.ShowDimensions) },
			}),
			Controls.Button(ui, "Anchor selection", guarded(arrange.AnchorSelection)),
		}),
	}
end
