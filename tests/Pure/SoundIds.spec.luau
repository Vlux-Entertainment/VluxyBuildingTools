--!strict

local SoundIds = require("../../src/Pure/SoundIds")

return {
	["every sound has an asset id and a sensible volume"] = function(expect)
		for name, entry in SoundIds do
			expect.truthy(string.match(entry.Id, "^rbxassetid://%d+$"), name)
			expect.truthy(entry.Volume > 0 and entry.Volume <= 1, name)
		end
	end,

	["the names the plugin plays exist"] = function(expect)
		for _, name in
			{
				"Click",
				"Tab",
				"ToggleOn",
				"Hotkey",
				"Tool",
				"ToolOff",
				"Cancel",
				"Build",
				"Prop",
				"Undo",
				"BrushAdd",
				"Warning",
			}
		do
			expect.truthy(SoundIds[name], name)
		end
	end,
}
