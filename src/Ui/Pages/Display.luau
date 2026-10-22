--!strict
--# selene: allow(mixed_table)

--[=[
	The Display tab: the camera light, pastel colors and theme, the surface grid and its look, the
	construction grid, and hidden parts.

	@class DisplayPage
]=]

local Actions = require("../../App/Actions")
local Controls = require("../Controls")
local Display = require("../../Services/Display")
local Kit = require("../Kit")
local Settings = require("../../Pure/Settings")
local Store = require("../../State/Store")
local SurfaceGrid = require("../../Core/SurfaceGrid")
local Theme = require("../Theme")

type Ui = Controls.Ui

local new = Kit.New

local SWATCHES = { "FFFFFF", "FF8A24", "6CD0E0", "FFB3BA", "BAFFC9", "BAE1FF", "9AA0AA", "000000" }
local THEME_TIPS: { [string]: string } = {
	Pastel = "Pastel theme: a random soft color for every part. Partly see-through parts are purple.",
	Unity = "Unity theme: everything grey, except cubes and rectangular blocks, which are orange. Partly see-through parts are purple.",
}

--[[
	@param ui Ui
	@param visible () -> boolean
	@return Frame -- swatches and a hex box for the grid color
]]
local function gridColor(ui: Ui, visible: () -> boolean): Frame
	local store = ui.App.Store
	local hexBox: TextBox

	local function setColor(hex: string)
		if string.match(hex, "^#?%x%x%x%x%x%x$") then
			Store.Set(store, "GridColor", string.upper((string.gsub(hex, "^#", ""))))
		end

		hexBox.Text = store.Values.GridColor
	end

	hexBox = new("TextBox")({
		Size = UDim2.new(0, 70, 1, -2),
		Position = UDim2.new(1, -70, 0, 0),
		BackgroundColor3 = Theme.Field,
		BorderSizePixel = 0,
		Text = function()
			return Store.Get(store, "GridColor")
		end,
		PlaceholderText = "RRGGBB",
		TextColor3 = Theme.Text,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		ClearTextOnFocus = false,
		Kit.Corner(6),
		Kit.Stroke(),
		FocusLost = function()
			setColor(hexBox.Text)
		end,
	})

	local swatches = {}

	for i, hex in SWATCHES do
		table.insert(
			swatches,
			new("TextButton")({
				Size = UDim2.fromOffset(24, 24),
				Position = UDim2.fromOffset((i - 1) * 28, 2),
				BackgroundColor3 = SurfaceGrid.ColorOf(hex),
				BorderSizePixel = 0,
				Text = "",
				Kit.Corner(6),
				Kit.Stroke(),
				ui.Popups.Tip({ Text = "Grid color #" .. hex }),
				MouseButton1Click = function()
					ui.App.Sound("Click")
					setColor(hex)
				end,
			})
		)
	end

	return Kit.Row(30, { swatches, hexBox }, visible)
end

--[=[
	@param ui Ui
	@return { Instance } -- the cards of the Display tab
]=]
return function(ui: Ui): { Instance }
	local app = ui.App
	local state, store = app.State, app.Store

	local function setting(key: string): () -> boolean
		return function()
			return Store.Get(store, key) == true
		end
	end

	local themes: { Controls.Option } = {}

	for _, name in Settings.Themes do
		table.insert(themes, { Value = name, Tip = THEME_TIPS[name] })
	end

	return {
		Controls.Card(ui, "VIEWPORT DISPLAY", {
			Controls.Switch(ui, { Title = "Camera light", Key = "CameraLight" }),
			Controls.Number(ui, {
				Key = "CameraLightRange",
				Title = "Light range (studs)",
				Min = 4,
				Max = 500,
				Step = 10,
				Visible = setting("CameraLight"),
			}),
			Controls.Number(ui, {
				Key = "CameraLightBrightness",
				Title = "Light brightness",
				Min = 0.1,
				Max = 20,
				Step = 0.5,
				Visible = setting("CameraLight"),
			}),
			Controls.Switch(ui, {
				Title = "Pastel colors",
				Get = state.PastelOn,
				Set = function(on)
					Display.SetPastel(app.Display, on)
				end,
			}),
			Controls.Choice(ui, {
				Options = themes,
				Columns = #themes,
				Get = function()
					return Store.Get(store, "ColorTheme")
				end,
				Set = function(name)
					Store.Set(store, "ColorTheme", name)
				end,
				Visible = state.PastelOn,
			}),
			Controls.Switch(ui, {
				Title = "Surface grid",
				Get = state.GridOn,
				Set = function(on)
					Display.SetGrid(app.Display, on)
				end,
			}),
			Controls.Number(ui, {
				Key = "GridTextureSize",
				Title = "Grid tile size (studs)",
				Min = 1,
				Max = 512,
				Step = 1,
				Visible = state.GridOn,
			}),
			gridColor(ui, state.GridOn),
			Controls.Switch(ui, { Title = "Construction grid while drawing", Key = "ShowGrid" }),
			Controls.Text(
				ui,
				"Pastel colors and the surface grid both change the Parts inside your working folder, so your team sees them and they are saved with the place. Each switch undoes itself completely, even after Studio was closed and reopened. Switch them off before publishing."
			),
		}),
		Controls.Card(ui, "HIDDEN PARTS", {
			Controls.Text(ui, function()
				return state.HiddenCount() .. " hidden part(s)"
			end, Theme.Text),
			Controls.Switch(ui, {
				Title = "Show hidden parts (ghosted)",
				Get = state.HiddenView,
				Set = function()
					Actions.ToggleHiddenView(app)
				end,
			}),
			Controls.Number(ui, {
				Key = "GhostTransparency",
				Title = "Ghost transparency (0 solid, 1 clear)",
				Min = 0.3,
				Max = 0.98,
				Step = 0.05,
			}),
			Controls.Button(ui, "Unhide all (Alt+H)", function()
				Actions.UnhideAll(app)
			end),
			Controls.Text(
				ui,
				"Select parts and press H to hide them. Hiding is local to you: nothing in the place changes and nothing is saved."
			),
		}),
	}
end
