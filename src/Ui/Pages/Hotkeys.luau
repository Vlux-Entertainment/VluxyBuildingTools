--!strict
--# selene: allow(mixed_table)

--[=[
	The Hotkeys tab: every key binding from `Pure/Keymap`, and a few tips.

	@class HotkeysPage
]=]

local Controls = require("../Controls")
local Keymap = require("../../Pure/Keymap")
local Kit = require("../Kit")
local Theme = require("../Theme")

type Ui = Controls.Ui

local new = Kit.New

local TIPS = {
	"Draw tools: click the first point, move the mouse, then click again. The preview shows the size before you build.",
	"Walls and corridors continue from the last point. Press Enter to begin somewhere else.",
	"Door and arch openings replace a childless rectangular wall with separate Parts. Undo restores the original.",
	"Every completed build supports Studio Undo and Redo. The plugin adds no scripts to your game.",
}

--[=[
	@param ui Ui
	@return { Instance } -- the cards of the Hotkeys tab
]=]
return function(ui: Ui): { Instance }
	local bindings = {}

	for _, binding in Keymap.Describe() do
		table.insert(
			bindings,
			Kit.Group({
				new("TextLabel")({
					Size = UDim2.fromOffset(0, 22),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundColor3 = Theme.Tile,
					BorderSizePixel = 0,
					Text = binding[1],
					TextColor3 = Theme.Accent,
					Font = Enum.Font.GothamBold,
					TextSize = 12,
					LayoutOrder = 1,
					Kit.Corner(5),
					Kit.Stroke(),
					new("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
				}),
				Controls.Text(ui, binding[2]),
				new("Frame")({ Size = UDim2.new(1, 0, 0, 6), BackgroundTransparency = 1, LayoutOrder = 1e9 }),
			})
		)
	end

	local tips = {}

	for _, tip in TIPS do
		table.insert(tips, Controls.Text(ui, tip))
	end

	return {
		Controls.Card(ui, "HOTKEYS", bindings),
		Controls.Card(ui, "TIPS", tips),
	}
end
