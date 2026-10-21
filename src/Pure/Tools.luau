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
}

local Tools = {}

Tools.List = {
	{ Id = "Wall", Label = "Walls", Glyph = "▥", Key = "1" },
	{ Id = "Room", Label = "Room", Glyph = "⬚", Key = "3" },
	{ Id = "Corridor", Label = "Corridor", Glyph = "║", Key = "2" },
	{ Id = "Block", Label = "Block", Glyph = "■", Key = "4" },
	{ Id = "Stairs", Label = "Stairs", Glyph = "▟", Key = "5" },
	{ Id = "Ramp", Label = "Ramp", Glyph = "◢", Key = "6" },
	{ Id = "Arch", Label = "Archway", Glyph = "∩", Key = "7" },
	{ Id = "ArchOpening", Label = "Arched Door", Glyph = "◠", Key = nil },
	{ Id = "Opening", Label = "Door / Window", Glyph = "▯", Key = "8" },
	{ Id = "Extend", Label = "Face Extend", Glyph = "⧉", Key = nil },
	{ Id = "Place", Label = "Stamp Copies", Glyph = "❐", Key = "9" },
	{ Id = "Measure", Label = "Measure", Glyph = "↔", Key = "0" },
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
