--!strict

--[=[
	The Settings tab: editing preferences, sounds, Blender hotkeys and a reset of every setting.

	@class SettingsPage
]=]

local Controls = require("../Controls")
local Store = require("../../State/Store")
local Theme = require("../Theme")

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

	local accents: { Controls.Option } = {}

	for _, entry in Theme.Accents do
		table.insert(accents, { Value = entry.Name, Tip = entry.Name .. " UI color." })
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
		}),
		Controls.Card(ui, "INTERFACE", {
			Controls.Switch(ui, { Title = "UI animations", Key = "UiAnimations" }),
			Controls.Choice(ui, {
				Options = accents,
				Columns = 4,
				Get = function()
					return Store.Get(app.Store, "UiAccent")
				end,
				Set = function(name)
					Store.Set(app.Store, "UiAccent", name)
				end,
			}),
		}),
		Controls.Card(ui, "RESET", {
			Controls.Button(ui, "Reset all settings", function()
				Store.Reset(app.Store)
				app.Say("Settings reset to the defaults.")
			end),
		}),
	}
end
