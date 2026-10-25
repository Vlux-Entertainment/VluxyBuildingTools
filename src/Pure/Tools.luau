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

	@interface Tile
	@within Tools
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
		Description = "Draw walls; Y drags the height.",
	},
	{
		Id = "PillaredWall",
		Label = "Pillared Wall",
		Glyph = "▥",
		Key = nil,
		Description = "Draw walls with a pillar at each end.",
	},
	{
		Id = "Floor",
		Label = "Floor",
		Glyph = "▱",
		Key = nil,
		Description = "Lay a flat floor.",
	},
	{
		Id = "Room",
		Label = "Room",
		Glyph = "⬚",
		Key = nil,
		Description = "Draw a room with a floor and four walls.",
	},
	{
		Id = "Corridor",
		Label = "Corridor",
		Glyph = "║",
		Key = nil,
		Description = "Draw a corridor with a floor and side walls.",
	},
	{
		Id = "Block",
		Label = "Block",
		Glyph = "■",
		Key = nil,
		Description = "Draw a plain block.",
	},
	{ Id = "Stairs", Label = "Stairs", Glyph = "▟", Key = nil, Description = "Draw a flight of stairs." },
	{ Id = "Ramp", Label = "Ramp", Glyph = "◢", Key = nil, Description = "Draw a sloped ramp." },
	{ Id = "Arch", Label = "Arch", Glyph = "∩", Key = nil, Description = "Draw an arch across a gap." },
	{
		Id = "ArchOpening",
		Label = "Archway",
		Glyph = "◠",
		Key = nil,
		Description = "Cut an archway into a wall.",
	},
	{
		Id = "ArchedCorridor",
		Label = "Arched Corridor",
		Glyph = "⌓",
		Key = nil,
		Description = "Draw a corridor with an arched ceiling.",
	},
	{
		Id = "Foundation",
		Label = "Foundation",
		Glyph = "▬",
		Key = nil,
		Description = "Lay a thick slab under a building.",
	},
	{
		Id = "Porch",
		Label = "Porch",
		Glyph = "▤",
		Key = nil,
		Description = "Build a porch floor with posts and a railing.",
	},
	{
		Id = "Fence",
		Label = "Fence",
		Glyph = "╫",
		Key = nil,
		Description = "Draw a fence of posts and rails.",
	},
	{
		Id = "Railing",
		Label = "Railing",
		Glyph = "╪",
		Key = nil,
		Description = "Draw an indoor railing that follows stairs.",
	},
	{
		Id = "HalfWall",
		Label = "Half Wall",
		Glyph = "▃",
		Key = nil,
		Description = "Draw a low solid wall.",
	},
	{
		Id = "Vent",
		Label = "Vent",
		Glyph = "▤",
		Key = nil,
		Description = "Draw a square duct that turns at right angles.",
	},
	{
		Id = "VentRamp",
		Label = "Slope Vent",
		Glyph = "◿",
		Key = nil,
		Description = "Draw a duct that climbs or drops.",
	},
	{
		Id = "VentShaft",
		Label = "Shaft Vent",
		Glyph = "▮",
		Key = nil,
		Description = "Draw a vertical duct.",
	},
	{
		Id = "VentCover",
		Label = "Vent Cover",
		Glyph = "▦",
		Key = nil,
		Description = "Place a grate over a vent or any surface.",
	},
	{
		Id = "Prop",
		Label = "Prop",
		Glyph = "◧",
		Key = nil,
		Description = "Place a prop from the Props tab.",
	},
	{
		Id = "VentCap",
		Label = "End Cap",
		Glyph = "■",
		Key = nil,
		Description = "Close a vent end with a plate.",
	},
	{
		Id = "VentFan",
		Label = "Fan End",
		Glyph = "✲",
		Key = nil,
		Description = "Close a vent end with a fan.",
	},
	{
		Id = "VentHole",
		Label = "Vent Hole",
		Glyph = "▣",
		Key = nil,
		Description = "Cut a vent-sized hole.",
	},
	{
		Id = "VentPeek",
		Label = "Peek Cover",
		Glyph = "▭",
		Key = nil,
		Description = "Place a small cover to look out of a vent.",
	},
	{
		Id = "Roof",
		Label = "Roof",
		Glyph = "⌂",
		Key = nil,
		Description = "Put a roof over a building.",
	},
	{
		Id = "Pillar",
		Label = "Pillar",
		Glyph = "▮",
		Key = nil,
		Description = "Place a square pillar.",
	},
	{
		Id = "Door",
		Label = "Doorway",
		Glyph = "▯",
		Key = nil,
		Description = "Cut a doorway into a wall.",
	},
	{
		Id = "Window",
		Label = "Window",
		Glyph = "▭",
		Key = nil,
		Description = "Cut a window into a wall.",
	},
	{
		Id = "CircleWindow",
		Label = "Circle Window",
		Glyph = "○",
		Key = nil,
		Description = "Cut a round window into a wall.",
	},
	{
		Id = "TriangleWindow",
		Label = "Triangle Window",
		Glyph = "△",
		Key = nil,
		Description = "Cut a triangle window into a wall.",
	},
	{
		Id = "CutShape",
		Label = "Cut Shape",
		Glyph = "✂",
		Key = nil,
		Description = "Cut any shape out of a wall.",
	},
	{
		Id = "Place",
		Label = "Brush",
		Glyph = "❐",
		Key = nil,
		Description = "Paint copies of the selection onto surfaces.",
	},
	{
		Id = "Measure",
		Label = "Measure",
		Glyph = "↔",
		Key = nil,
		Description = "Measure lines, squares, boxes, circles and balls; kept ones are snap guides.",
	},
} :: { Tool }

Tools.Grid = {
	{
		Id = "Basic",
		Label = "Basic",
		Glyph = "▥",
		Key = "1",
		Description = "Walls, floors, blocks, pillars and arches.",
		Modes = { "Wall", "PillaredWall", "Floor", "Block", "Pillar", "Arch" },
	},
	{
		Id = "Stairs",
		Label = "Stairs",
		Glyph = "▟",
		Key = "2",
		Description = "Stairs and ramps.",
		Modes = { "Stairs", "Ramp" },
	},
	{
		Id = "Additive",
		Label = "Additive",
		Glyph = "▯",
		Key = "3",
		Description = "Cut doorways, windows and other openings into walls.",
		Modes = { "Door", "Window", "CircleWindow", "TriangleWindow", "ArchOpening", "CutShape", "VentHole" },
	},
	{
		Id = "Structures",
		Label = "Structures",
		Glyph = "⬚",
		Key = "4",
		Description = "Rooms, corridors, foundations, porches and roofs.",
		Modes = { "Room", "Corridor", "ArchedCorridor", "Foundation", "Porch", "Roof" },
	},
	{
		Id = "Vents",
		Label = "Vents",
		Glyph = "▤",
		Key = "5",
		Description = "Vent ducts and their end pieces.",
		Modes = { "Vent", "VentRamp", "VentShaft", "VentCover", "VentCap", "VentFan", "VentPeek" },
	},
	{
		Id = "Railings",
		Label = "Railings",
		Glyph = "╪",
		Key = "6",
		Description = "Railings, half walls and fences.",
		Modes = { "Railing", "HalfWall", "Fence" },
	},
	{
		Id = "Place",
		Label = "Brush",
		Glyph = "❐",
		Key = "7",
		Description = "Paint copies of the selection onto surfaces.",
		Modes = { "Place" },
	},
	{
		Id = "Measure",
		Label = "Measure",
		Glyph = "↔",
		Key = "0",
		Description = "Measure lines, squares, boxes, circles and balls; kept ones are snap guides.",
		Modes = { "Measure" },
	},
} :: { Tile }

--[=[
	How to use each tool, by tool id: the status line shows it when the tool starts and after each build.

	@prop Instructions { [string]: string }
	@within Tools
]=]
Tools.Instructions = {
	PillaredWall = "Click points; Enter starts a new chain.",
	Wall = "Click points; Enter starts a new chain.",
	ArchedCorridor = "Click a start and an end; keep clicking to chain.",
	Corridor = "Click a start and an end; keep clicking to chain.",
	Floor = "Click two corners.",
	Room = "Click two corners.",
	Foundation = "Click two corners.",
	Porch = "Click two corners.",
	Railing = "Click points; Enter starts a new chain.",
	HalfWall = "Click points; Enter starts a new chain.",
	Fence = "Click points; Enter starts a new chain.",
	Roof = "Click two corners over the top of the walls.",
	Block = "Click two corners, then press Y to drag it up.",
	Stairs = "Click the bottom step, then the end of the run.",
	Ramp = "Click the bottom, then the top.",
	Arch = "Click the two inner edges at ground level.",
	ArchOpening = "Click a plain wall.",
	Vent = "Click points; Enter starts a new chain.",
	VentRamp = "Click the start and end, then move up or down and click.",
	VentShaft = "Click a surface, then move up or down and click.",
	Prop = "Click a floor or wall; R turns it.",
	VentCover = "Click a vent opening or any surface.",
	VentCap = "Click a vent opening or any surface.",
	VentFan = "Click a vent opening.",
	VentPeek = "Click a wall or vent opening.",
	VentHole = "Click a wall, floor or vent.",
	Pillar = "Click to place a pillar.",
	Door = "Click a plain wall.",
	CircleWindow = "Click a plain wall.",
	CutShape = "Click corners on a wall; Enter cuts the shape.",
	TriangleWindow = "Click a plain wall.",
	Window = "Click a plain wall.",
	Place = "Select an object, then click or drag over surfaces.",
	Measure = "Pick a shape, then click its points; kept measurements are snap guides, Esc clears them.",
} :: { [string]: string }

--[=[
	@param mode string? -- a tool id, or nil when no tool is on
	@return string -- how to use the tool, or a nudge to pick one
]=]
function Tools.Instruction(mode: string?): string
	return (mode and Tools.Instructions[mode]) or "Choose a drawing tool first."
end

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
