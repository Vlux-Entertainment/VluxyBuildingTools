--!strict

--[=[
	Every tool, by mode id. To add a tool: write its module, add it to `FAMILIES` below, and give it
	an entry in `Pure/Tools` (label, glyph, instruction, and a tile).

	@class Registry
]=]

local Types = require("./Types")

local FAMILIES: { { Types.Tool } } = {
	require("./Draw/Walls"),
	require("./Draw/Corridors"),
	require("./Draw/Areas"),
	require("./Draw/Slopes"),
	require("./Draw/Vents"),
	require("./Openings"),
	require("./CutShape"),
	require("./VentPieces"),
	require("./Pillar"),
	require("./Prop"),
	require("./Brush"),
	require("./Measure"),
}

local Registry: { [string]: Types.Tool } = {}

for _, family in FAMILIES do
	for _, tool in family do
		assert(Registry[tool.Id] == nil, `two tools use the mode {tool.Id}`)
		Registry[tool.Id] = tool
	end
end

return Registry
