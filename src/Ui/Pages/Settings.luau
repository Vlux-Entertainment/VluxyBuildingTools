--!strict

--[=[
	The Settings tab, in sections: building defaults, the panel's look, the viewport, sound, and the
	folder safety switch with a reset of every setting.

	@class SettingsPage
]=]

local Controls = require("../Controls")
local Settings = require("../../Pure/Settings")
local Store = require("../../State/Store")
local Theme = require("../Theme")

type Ui = Controls.Ui

--[=[
	@param ui Ui
	@return { Instance } -- the cards of the Settings tab
]=]
return function(ui: Ui): { Instance }
	local app = ui.App
	local store = app.Store

	local function number(
		key: string,
		title: string,
		min: number,
		max: number,
		step: number?,
		visible: (() -> boolean)?
	)
		return Controls.Number(ui, { Key = key, Title = title, Min = min, Max = max, Step = step, Visible = visible })
	end

	local accents: { Controls.Option } = {}

	for _, entry in Theme.Accents do
		table.insert(accents, { Value = entry.Name, Tip = entry.Name .. " UI color." })
	end

	return {
		Controls.Card(ui, "BUILDING", {
			number("Grid", "Grid Snap", 0.05, 128, 0.5),
			number("FineGrid", "Precise Grid Snap", 0.05, 128, 0.25),
			number("StandardHeight", "Standard wall height", 0.1, 2048),
			number("StandardThickness", "Standard wall thickness", 0.05, 512),
			number("StandardDoorWidth", "Standard doorway width", 0.1, 1024),
			number("StandardDoorHeight", "Standard doorway height", 0.1, 1024),
			number("Extend", "Face extend length", 0.1, 2048),
			number("FieldStep", "Arrow step", 0, 100, 0.05),
		}),
		Controls.Card(ui, "INTERFACE", {
			Controls.Choice(ui, {
				Options = accents,
				Columns = 4,
				Get = function()
					return Store.Get(store, "UiAccent")
				end,
				Set = function(name)
					Store.Set(store, "UiAccent", name)
				end,
			}),
			Controls.Switch(ui, { Title = "UI animations", Key = "UiAnimations" }),
			Controls.Slider(ui, "AnimationIntensity", "Animation intensity", function()
				return Store.Get(store, "UiAnimations") == true
			end),
			Controls.Switch(ui, { Title = "Zebra rows", Key = "ZebraRows" }),
			Controls.Switch(ui, { Title = "Tooltips", Key = "Tooltips" }),
			number("TooltipDelay", "Tooltip delay (seconds)", 0, 3, 0.1, function()
				return Store.Get(store, "Tooltips") == true
			end),
		}),
		Controls.Card(ui, "VIEWPORT", {
			Controls.Switch(ui, { Title = "Previews use the UI color", Key = "PreviewsFollowUi" }),
			Controls.Switch(ui, { Title = "Hint bar", Key = "HintBar" }),
			Controls.Switch(ui, { Title = "Prop rotation", Key = "PropSpin" }),
		}),
		Controls.Card(ui, "SOUND", {
			Controls.Switch(ui, {
				Title = "Play sounds",
				Key = "SoundEnabled",
				After = function()
					app.Sound("ToggleOn")
				end,
			}),
			Controls.Slider(ui, "SoundVolume", "Sound volume"),
		}),
		Controls.Card(ui, "ADVANCED", {
			Controls.Switch(ui, {
				Title = "Allow untagged folders (not recommended)",
				Key = "AllowUntagged",
				Danger = true,
			}),
			Controls.Button(ui, "Reset settings", function()
				Store.ResetKeys(store, Settings.Page)
				app.Say("This tab's settings are back to their defaults.")
			end),
		}),
	}
end
