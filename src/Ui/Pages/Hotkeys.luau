--!strict
--# selene: allow(mixed_table)

--[=[
	The Hotkeys tab: one card per section of `Pure/Keymap`, each binding a compact row with its key
	chips on the left and a short meaning on the right.

	@class HotkeysPage
]=]

local Controls = require("../Controls")
local Keymap = require("../../Pure/Keymap")
local Kit = require("../Kit")
local Theme = require("../Theme")

type Ui = Controls.Ui

local new = Kit.New

local KEY_WIDTH = 112
local KEY_GAP = 8
local LINE_HEIGHT = 20

--[[ A key chip in the UI color, or a muted joining word such as "+" or "then". ]]
local function token(text: string, index: number): TextLabel
	if Keymap.IsJoiner(text) then
		return new("TextLabel")({
			Size = UDim2.fromOffset(0, LINE_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = Theme.Muted,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			LayoutOrder = index,
		})
	end

	return new("TextLabel")({
		Size = UDim2.fromOffset(0, LINE_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.AccentDim,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = Theme.Accent,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		LayoutOrder = index,
		Kit.Corner(4),
		new("UIPadding")({ PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
	})
end

--[[ One binding: the keys wrap inside a fixed-width column and the meaning wraps beside them. ]]
local function row(binding: Keymap.Binding): Frame
	local tokens = {}

	for index, text in binding.Keys do
		table.insert(tokens, token(text, index))
	end

	return new("Frame")({
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = Kit.Next(),
		new("Frame")({
			Size = UDim2.fromOffset(KEY_WIDTH, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			new("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				Wraps = true,
				Padding = UDim.new(0, 4),
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			tokens,
		}),
		new("TextLabel")({
			Position = UDim2.fromOffset(KEY_WIDTH + KEY_GAP, 0),
			Size = UDim2.new(1, -(KEY_WIDTH + KEY_GAP), 0, LINE_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = binding.Meaning,
			TextColor3 = Theme.Text,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
	})
end

--[=[
	@param ui Ui
	@return { Instance } -- the cards of the Hotkeys tab
]=]
return function(ui: Ui): { Instance }
	local app = ui.App
	local cards: { Instance } = {
		Controls.Card(ui, nil, {
			Controls.Switch(ui, {
				Title = "Blender hotkeys",
				Key = "Hotkeys",
				After = function(on)
					app.Say(if on then "Blender hotkeys on." else "Blender hotkeys off; Esc, Enter and [ ] still work.")
				end,
			}),
		}),
	}

	for _, section in Keymap.Sections() do
		local rows = {}

		for _, binding in section.Bindings do
			table.insert(rows, row(binding))
		end

		table.insert(cards, Controls.Card(ui, section.Title, rows))
	end

	return cards
end
