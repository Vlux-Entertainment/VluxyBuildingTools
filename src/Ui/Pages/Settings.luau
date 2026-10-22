--!strict

--[=[
	The Settings tab: editing preferences, sounds, Blender hotkeys and a reset of every setting.

	@class SettingsPage
]=]

local Controls = require("../Controls")
local Store = require("../../State/Store")

type Ui = Controls.Ui

--[=[
	@param ui Ui
	@return { Instance } -- the cards of the Settings tab
]=]
return function(ui: Ui): { Instance }
	local app = ui.App

	local function number(key: string, title: string, min: number, max: number, step: number?)
		return Controls.Number(ui, { Key = key, Title = title, Min = min, Max = max, Step = step })
	end

	return {
		Controls.Card(ui, "EDITING", {
			Controls.Switch(ui, {
				Title = "Allow untagged folders (not recommended)",
				Key = "AllowUntagged",
				Danger = true,
			}),
			number("FieldStep", "Arrow step", 0, 100, 0.05),
			number("StandardHeight", "Standard wall height", 0.1, 2048),
			number("StandardThickness", "Standard wall thickness", 0.05, 512),
			number("StandardDoorWidth", "Standard doorway width", 0.1, 1024),
			number("StandardDoorHeight", "Standard doorway height", 0.1, 1024),
			number("Extend", "Face extend length", 0.1, 2048),
			Controls.Switch(ui, {
				Title = "Play sounds",
				Key = "SoundEnabled",
				After = function()
					app.Sound("ToggleOn")
				end,
			}),
			Controls.Slider(ui, "SoundVolume", "Sound volume"),
			Controls.Switch(ui, {
				Title = "Blender hotkeys",
				Key = "Hotkeys",
				After = function(on)
					app.Say(
						if on
							then "Blender hotkeys ON. See the Hotkeys tab (F1) for the list."
							else "Blender hotkeys OFF. Only Esc, Enter and [ ] keep working."
					)
				end,
			}),
		}),
		Controls.Card(ui, "RESET", {
			Controls.Text(
				ui,
				"Puts every number and switch on this panel back to its default. Your builds are not touched."
			),
			Controls.Button(ui, "Reset all settings", function()
				Store.Reset(app.Store)
				app.Say("Settings reset to the defaults.")
			end),
		}),
	}
end
