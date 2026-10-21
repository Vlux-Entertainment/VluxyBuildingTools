--!strict

--[=[
	The list of building tools: id, label, icon glyph and number hotkey. The panel draws its tool grid
	from this and the status bar names the active tool from it, so the two never disagree.

	@class Tools
]=]

export type Tool = {
	Id: string,
	Label: string,
	Glyph: string,
	Key: string?,
	Description: string,
}

--[=[
	One tile of the tool grid. A tile with several `Modes` is a group: picking it starts the mode used
	last, and the panel offers the others as options. A plain tile has one mode with its own id.
]=]
export type Tile = {
	Id: string,
	Label: string,
	Glyph: string,
	Key: string?,
	Description: string,
	Modes: { string },
}

local Tools = {}

Tools.List = {
	{
		Id = "Wall",
		Label = "Walls",
		Glyph = "▥",
		Key = nil,
		Description = "Draw walls by clicking a start and an end point. Keep clicking to chain walls. Press Y to drag the height.",
	},
	{
		Id = "Room",
		Label = "Room",
		Glyph = "⬚",
		Key = nil,
		Description = "Draw a room from two opposite corners: a floor and four walls. Press Y to drag the height.",
	},
	{
		Id = "Corridor",
		Label = "Corridor",
		Glyph = "║",
		Key = nil,
		Description = "Draw a corridor with a floor and side walls between two points. Press Y to drag the height.",
	},
	{
		Id = "Block",
		Label = "Block",
		Glyph = "■",
		Key = nil,
		Description = "Draw a plain block. Press Y while drawing to drag it up.",
	},
	{ Id = "Stairs", Label = "Stairs", Glyph = "▟", Key = nil, Description = "Draw a flight of stairs along a run." },
	{ Id = "Ramp", Label = "Ramp", Glyph = "◢", Key = nil, Description = "Draw a sloped ramp as a single wedge." },
	{ Id = "Arch", Label = "Archway", Glyph = "∩", Key = nil, Description = "Draw an arch frame across a gap." },
	{
		Id = "ArchOpening",
		Label = "Arched Door",
		Glyph = "◠",
		Key = nil,
		Description = "Cut an arched doorway into a plain wall.",
	},
	{
		Id = "Opening",
		Label = "Door / Window",
		Glyph = "▯",
		Key = nil,
		Description = "Cut a door or window into a plain wall.",
	},
	{
		Id = "Extend",
		Label = "Face Extend",
		Glyph = "⧉",
		Key = nil,
		Description = "Drag a green face handle to grow a connected block.",
	},
	{
		Id = "Place",
		Label = "Stamp Copies",
		Glyph = "❐",
		Key = nil,
		Description = "Stamp copies of the selection onto surfaces.",
	},
	{
		Id = "Measure",
		Label = "Measure",
		Glyph = "↔",
		Key = nil,
		Description = "Measure the distance between two points.",
	},
} :: { Tool }

Tools.Grid = {
	{
		Id = "Wall",
		Label = "Walls",
		Glyph = "▥",
		Key = "1",
		Description = "Draw walls by clicking a start and an end point. Keep clicking to chain walls. Press Y to drag the height.",
		Modes = { "Wall" },
	},
	{
		Id = "Structures",
		Label = "Structures",
		Glyph = "⬚",
		Key = "2",
		Description = "Draw a room or a corridor. Pick which one in the options. Press Y to drag the height.",
		Modes = { "Room", "Corridor" },
	},
	{
		Id = "Block",
		Label = "Block",
		Glyph = "■",
		Key = "3",
		Description = "Draw a plain block. Press Y while drawing to drag it up.",
		Modes = { "Block" },
	},
	{
		Id = "Stairs",
		Label = "Stairs",
		Glyph = "▟",
		Key = "4",
		Description = "Draw a flight of stairs or a sloped ramp. Pick which one in the options.",
		Modes = { "Stairs", "Ramp" },
	},
	{
		Id = "Arches",
		Label = "Arches",
		Glyph = "∩",
		Key = "5",
		Description = "Draw an arch frame across a gap, or cut an arched door into a wall. Pick which one in the options.",
		Modes = { "Arch", "ArchOpening" },
	},
	{
		Id = "Opening",
		Label = "Door / Window",
		Glyph = "▯",
		Key = "6",
		Description = "Cut a door or window into a plain wall.",
		Modes = { "Opening" },
	},
	{
		Id = "Extend",
		Label = "Face Extend",
		Glyph = "⧉",
		Key = "7",
		Description = "Drag a green face handle to grow a connected block.",
		Modes = { "Extend" },
	},
	{
		Id = "Place",
		Label = "Stamp Copies",
		Glyph = "❐",
		Key = "8",
		Description = "Stamp copies of the selection onto surfaces.",
		Modes = { "Place" },
	},
	{
		Id = "Measure",
		Label = "Measure",
		Glyph = "↔",
		Key = "0",
		Description = "Measure the distance between two points.",
		Modes = { "Measure" },
	},
} :: { Tile }

--[=[
	@param id string -- a tile id
	@return Tile? -- the tile with that id, or nil
]=]
function Tools.FindTile(id: string): Tile?
	for _, tile in Tools.Grid do
		if tile.Id == id then
			return tile
		end
	end

	return nil
end

--[=[
	@param mode string -- a tool mode such as `Room`
	@return Tile? -- the tile that holds that mode, or nil
]=]
function Tools.TileOf(mode: string): Tile?
	for _, tile in Tools.Grid do
		if table.find(tile.Modes, mode) then
			return tile
		end
	end

	return nil
end

--[=[
	@param id string
	@return Tool? -- the tool with that id, or nil
]=]
function Tools.Find(id: string): Tool?
	for _, tool in Tools.List do
		if tool.Id == id then
			return tool
		end
	end

	return nil
end

return Tools
