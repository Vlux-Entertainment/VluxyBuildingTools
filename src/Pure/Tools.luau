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

local Tools = {}

Tools.List = {
	{
		Id = "Wall",
		Label = "Walls",
		Glyph = "▥",
		Key = "1",
		Description = "Draw walls by clicking a start and an end point. Keep clicking to chain walls.",
	},
	{
		Id = "Room",
		Label = "Room",
		Glyph = "⬚",
		Key = "3",
		Description = "Draw a room from two opposite corners: a floor and four walls.",
	},
	{
		Id = "Corridor",
		Label = "Corridor",
		Glyph = "║",
		Key = "2",
		Description = "Draw a corridor with a floor and side walls between two points.",
	},
	{
		Id = "Block",
		Label = "Block",
		Glyph = "■",
		Key = "4",
		Description = "Draw a plain block. Press Y while drawing to drag it up.",
	},
	{ Id = "Stairs", Label = "Stairs", Glyph = "▟", Key = "5", Description = "Draw a flight of stairs along a run." },
	{ Id = "Ramp", Label = "Ramp", Glyph = "◢", Key = "6", Description = "Draw a sloped ramp as a single wedge." },
	{ Id = "Arch", Label = "Archway", Glyph = "∩", Key = "7", Description = "Draw an arch frame across a gap." },
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
		Key = "8",
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
		Key = "9",
		Description = "Stamp copies of the selection onto surfaces.",
	},
	{
		Id = "Measure",
		Label = "Measure",
		Glyph = "↔",
		Key = "0",
		Description = "Measure the distance between two points.",
	},
} :: { Tool }

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
