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
		Id = "PillaredWall",
		Label = "Pillared Wall",
		Glyph = "▥",
		Key = nil,
		Description = "Draw walls with a pillar at the start and at the end of each section, so the walls have some depth. Keep clicking to chain them.",
	},
	{
		Id = "Floor",
		Label = "Floor",
		Glyph = "▱",
		Key = nil,
		Description = "Click two corners to lay a flat floor. Its transparency is in the options.",
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
	{ Id = "Arch", Label = "Arch", Glyph = "∩", Key = nil, Description = "Draw an arch frame across a gap." },
	{
		Id = "ArchOpening",
		Label = "Archway",
		Glyph = "◠",
		Key = nil,
		Description = "Cut an archway into a plain wall.",
	},
	{
		Id = "ArchedCorridor",
		Label = "Arched Corridor",
		Glyph = "⌓",
		Key = nil,
		Description = "Draw a corridor with a rounded arch ceiling between two points. Keep clicking to chain it.",
	},
	{
		Id = "Foundation",
		Label = "Foundation",
		Glyph = "▬",
		Key = nil,
		Description = "Click two corners to lay a thick slab a little bigger than the building, so it sits above the ground.",
	},
	{
		Id = "Porch",
		Label = "Porch",
		Glyph = "▤",
		Key = nil,
		Description = "Click two corners for a porch: a floor with corner posts and an optional railing.",
	},
	{
		Id = "Fence",
		Label = "Fence",
		Glyph = "╫",
		Key = nil,
		Description = "Click points to draw a fence or railing: posts with two rails. Keep clicking to chain it.",
	},
	{
		Id = "Railing",
		Label = "Railing",
		Glyph = "╪",
		Key = nil,
		Description = "Click two points for a straight indoor railing: a handrail with bars and a pillar at each end. Click points on stairs and it follows the slope.",
	},
	{
		Id = "HalfWall",
		Label = "Half Wall",
		Glyph = "▃",
		Key = nil,
		Description = "Click two points for a solid low wall with a pillar at each end. It follows a slope when you click points on stairs.",
	},
	{
		Id = "Vent",
		Label = "Vent",
		Glyph = "▤",
		Key = nil,
		Description = "Draw a square duct along the X or Z axis, turning only at right angles. It cuts a hole where it meets a wall, floor or ceiling. Keep clicking to chain it.",
	},
	{
		Id = "VentRamp",
		Label = "Slope Vent",
		Glyph = "◿",
		Key = nil,
		Description = "A straight duct that climbs or drops to another height: click the start and the end of the run, then move the mouse up or down and click.",
	},
	{
		Id = "VentShaft",
		Label = "Shaft Vent",
		Glyph = "▮",
		Key = nil,
		Description = "A vertical duct. Click a floor, wall or ceiling, then move the mouse up or down to set how far it goes and click.",
	},
	{
		Id = "VentCover",
		Label = "Vent Cover",
		Glyph = "▦",
		Key = nil,
		Description = "Place a grate over a vent opening, or on any surface.",
	},
	{
		Id = "Roof",
		Label = "Roof",
		Glyph = "⌂",
		Key = nil,
		Description = "Click two corners to put a roof over a building. Pick gable, hip, shed, pyramid or flat in the options.",
	},
	{
		Id = "Pillar",
		Label = "Pillar",
		Glyph = "▮",
		Key = nil,
		Description = "Click to place a square pillar. The height and width are in the options.",
	},
	{
		Id = "Door",
		Label = "Doorway",
		Glyph = "▯",
		Key = nil,
		Description = "Cut a doorway into a plain wall. It starts at the bottom of the wall.",
	},
	{
		Id = "Window",
		Label = "Window",
		Glyph = "▭",
		Key = nil,
		Description = "Cut a window into a plain wall, a few studs above the bottom.",
	},
	{
		Id = "CircleWindow",
		Label = "Circle Window",
		Glyph = "○",
		Key = nil,
		Description = "Cut a round window into a plain wall. Its size is the smaller of the window width and height.",
	},
	{
		Id = "TriangleWindow",
		Label = "Triangle Window",
		Glyph = "△",
		Key = nil,
		Description = "Cut a triangular window into a plain wall, with the point at the top.",
	},
	{
		Id = "CutShape",
		Label = "Cut Shape",
		Glyph = "✂",
		Key = nil,
		Description = "Click corners on a wall to outline any shape, then click the first corner again or press Enter to cut it out.",
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
		Label = "Brush",
		Glyph = "❐",
		Key = nil,
		Description = "Paint copies of the selection onto surfaces by clicking or dragging.",
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
		Id = "Basic",
		Label = "Basic",
		Glyph = "▥",
		Key = "1",
		Description = "Draw walls, pillared walls, floors, blocks and pillars, or make arches. Pick which one in the options. Press Y to drag a wall's height.",
		Modes = { "Wall", "PillaredWall", "Floor", "Block", "Pillar", "Arch" },
	},
	{
		Id = "Stairs",
		Label = "Stairs",
		Glyph = "▟",
		Key = "2",
		Description = "Draw a flight of stairs or a sloped ramp. Pick which one in the options.",
		Modes = { "Stairs", "Ramp" },
	},
	{
		Id = "Additive",
		Label = "Additive",
		Glyph = "▯",
		Key = "3",
		Description = "Cut a doorway, a window or an archway into a wall. Pick which one in the options.",
		Modes = { "Door", "Window", "CircleWindow", "TriangleWindow", "ArchOpening", "CutShape", "Extend" },
	},
	{
		Id = "Structures",
		Label = "Structures",
		Glyph = "⬚",
		Key = "4",
		Description = "Draw a room, corridor, arched corridor, foundation, porch or roof. Pick which one in the options. Press Y to drag the height.",
		Modes = { "Room", "Corridor", "ArchedCorridor", "Foundation", "Porch", "Roof" },
	},
	{
		Id = "Vents",
		Label = "Vents",
		Glyph = "▤",
		Key = "5",
		Description = "Build duct networks: a square vent that turns at right angles, a sloped vent, a vertical shaft and a grate cover. Pick which one in the options.",
		Modes = { "Vent", "VentRamp", "VentShaft", "VentCover" },
	},
	{
		Id = "Railings",
		Label = "Railings",
		Glyph = "╪",
		Key = "6",
		Description = "Draw railings: an indoor railing with pillar ends that follows stairs, a half wall, or an outdoor fence. Pick which one in the options.",
		Modes = { "Railing", "HalfWall", "Fence" },
	},
	{
		Id = "Place",
		Label = "Brush",
		Glyph = "❐",
		Key = "7",
		Description = "Paint copies of the selection onto surfaces by clicking or dragging.",
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
