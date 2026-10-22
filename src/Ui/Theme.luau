--!strict

--[=[
	The panel's colors. Change a color here and the whole panel follows. The accent is a vide
	source, so every place that shows it recolors as soon as the UI color setting changes.

	@class Theme
]=]

local vide = require("../Packages/vide")

local BACKGROUND = Color3.fromRGB(21, 22, 25)

--[=[
	The UI colors that can be picked, in the order the Settings tab shows them.

	@prop Accents { { Name: string, Color: Color3 } }
	@within Theme
]=]
local ACCENTS = {
	{ Name = "Orange", Color = Color3.fromRGB(255, 138, 36) },
	{ Name = "Red", Color = Color3.fromRGB(235, 80, 80) },
	{ Name = "Pink", Color = Color3.fromRGB(240, 110, 170) },
	{ Name = "Purple", Color = Color3.fromRGB(160, 120, 240) },
	{ Name = "Blue", Color = Color3.fromRGB(70, 150, 255) },
	{ Name = "Teal", Color = Color3.fromRGB(40, 200, 190) },
	{ Name = "Green", Color = Color3.fromRGB(90, 200, 100) },
	{ Name = "Yellow", Color = Color3.fromRGB(240, 200, 60) },
}

local accent = vide.source(ACCENTS[1].Color)

local Theme = {
	Background = BACKGROUND,
	Card = Color3.fromRGB(28, 30, 34),
	CardStroke = Color3.fromRGB(44, 46, 52),
	Tile = Color3.fromRGB(24, 25, 29),
	Field = Color3.fromRGB(21, 22, 26),
	Text = Color3.fromRGB(236, 237, 240),
	Muted = Color3.fromRGB(139, 142, 150),
	Danger = Color3.fromRGB(235, 64, 64),
	SwitchOff = Color3.fromRGB(66, 69, 76),
	Tooltip = Color3.fromRGB(34, 36, 41),
	TooltipStroke = Color3.fromRGB(80, 83, 91),
	White = Color3.fromRGB(255, 255, 255),
	Accents = ACCENTS,
}

--[=[
	@return Color3 -- the UI color picked now; read inside a vide property to follow it
]=]
function Theme.Accent(): Color3
	return accent()
end

--[=[
	@return Color3 -- a dark shade of the UI color, for backgrounds behind accent text
]=]
function Theme.AccentDim(): Color3
	return accent():Lerp(BACKGROUND, 0.8)
end

--[=[
	Picks the UI color by name; an unknown name picks the first, orange.

	@param name string
]=]
function Theme.SetAccent(name: string)
	for _, entry in ACCENTS do
		if entry.Name == name then
			accent(entry.Color)

			return
		end
	end

	accent(ACCENTS[1].Color)
end

return Theme
