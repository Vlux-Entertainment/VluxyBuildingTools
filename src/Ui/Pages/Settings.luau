--!strict
--# selene: allow(mixed_table)

--[=[
	The Settings tab, in sections: building defaults, the panel's look, the viewport, sound, sharing
	settings as text, and the folder safety switch with a reset of every setting.

	@class SettingsPage
]=]

local Controls = require("../Controls")
local Kit = require("../Kit")
local Store = require("../../State/Store")
local Theme = require("../Theme")

type Ui = Controls.Ui

local new = Kit.New

--[[
	@param ui Ui
	@return { Instance } -- a box that shows the exported settings, or takes pasted ones, and the Copy and Import buttons
]]
local function share(ui: Ui): { Instance }
	local app = ui.App
	local box: TextBox

	box = new("TextBox")({
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Theme.Field,
		BorderSizePixel = 0,
		Text = "",
		PlaceholderText = "Paste settings here",
		TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.Muted,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ClearTextOnFocus = false,
		Kit.Corner(5),
		Kit.Stroke(),
		Kit.Padding(6, 0),
	})

	return {
		Kit.Row(30, { box }),
		Controls.ButtonRow(ui, {
			{
				Text = "Copy settings",
				Run = function()
					box.Text = Store.Export(app.Store)
					box:CaptureFocus()
					box.SelectionStart = 1
					box.CursorPosition = #box.Text + 1
					app.Say("Settings are in the box; press Ctrl+C to copy them.")
				end,
			},
			{
				Text = "Import settings",
				Primary = true,
				Run = function()
					if Store.Import(app.Store, box.Text) then
						box.Text = ""
						app.Say("Settings imported.")
					else
						app.Say("Paste settings copied from this plugin first.")
					end
				end,
			},
		}),
	}
end

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
			Controls.Switch(ui, { Title = "Zebra rows", Key = "ZebraRows" }),
			Controls.Switch(ui, { Title = "Tooltips", Key = "Tooltips" }),
			number("TooltipDelay", "Tooltip delay (seconds)", 0, 3, 0.1, function()
				return Store.Get(store, "Tooltips") == true
			end),
		}),
		Controls.Card(ui, "VIEWPORT", {
			Controls.Switch(ui, { Title = "Previews use the UI color", Key = "PreviewsFollowUi" }),
			Controls.Switch(ui, { Title = "Hint bar", Key = "HintBar" }),
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
		Controls.Card(ui, "SHARE SETTINGS", share(ui)),
		Controls.Card(ui, "ADVANCED", {
			Controls.Switch(ui, {
				Title = "Allow untagged folders (not recommended)",
				Key = "AllowUntagged",
				Danger = true,
			}),
			Controls.Button(ui, "Reset all settings", function()
				Store.Reset(store)
				app.Say("Settings reset to the defaults.")
			end),
		}),
	}
end
