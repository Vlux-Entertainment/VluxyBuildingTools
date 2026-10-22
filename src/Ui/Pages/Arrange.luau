--!strict

--[=[
	The Arrange tab: flip the selection, and the array (Blender's Array modifier), which previews
	its copies while the tab is open. Every action needs a working folder.

	@class ArrangePage
]=]

local Actions = require("../../App/Actions")
local ArrayStep = require("../../Pure/ArrayStep")
local Controls = require("../Controls")
local Store = require("../../State/Store")

type Ui = Controls.Ui

--[=[
	@param ui Ui
	@return { Instance } -- the cards of the Arrange tab
]=]
return function(ui: Ui): { Instance }
	local app = ui.App
	local arrange = app.Arrange
	local store = app.Store

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

	local function setting(key: string): () -> boolean
		return function()
			return Store.Get(store, key) == true
		end
	end

	local function offset(key: string, title: string, visible: () -> boolean): Frame
		return Controls.Number(
			ui,
			{ Key = key, Title = title, Min = -2048, Max = 2048, Step = 0.25, Visible = visible }
		)
	end

	local relative, constant = setting("ArrayRelative"), setting("ArrayConstant")

	return {
		Controls.Card(ui, "FLIP SELECTION  (Ctrl+M, then X / Y / Z)", {
			Controls.Text(ui, "Mirrors the selection in place, around its own centre."),
			Controls.ButtonRow(ui, { flip("X"), flip("Y"), flip("Z") }),
		}),
		Controls.Card(ui, "ARRAY", {
			Controls.Text(
				ui,
				"Like Blender's Array modifier: select objects and the copies show as a preview. Apply Array makes them."
			),
			Controls.Number(ui, {
				Key = "ArrayCount",
				Title = "Count",
				Min = 1,
				Max = ArrayStep.MaxCount,
				Step = 1,
				Integer = true,
			}),
			Controls.Switch(ui, { Title = "Relative Offset", Key = "ArrayRelative" }),
			offset("ArrayRelX", "Factor X", relative),
			offset("ArrayRelY", "Factor Y", relative),
			offset("ArrayRelZ", "Factor Z", relative),
			Controls.Switch(ui, { Title = "Constant Offset", Key = "ArrayConstant" }),
			offset("ArrayConstX", "Distance X", constant),
			offset("ArrayConstY", "Distance Y", constant),
			offset("ArrayConstZ", "Distance Z", constant),
			Controls.Button(ui, "Apply Array", guarded(arrange.ApplyArray), true),
		}),
	}
end
