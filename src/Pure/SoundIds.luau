--!strict

--[=[
	Every sound the plugin plays, in one place. To swap a sound, change its `Id` (or `Volume`) here and
	nothing else. The ids are guesses from the Roblox library and are meant to be replaced.

	@class SoundIds
]=]

export type Entry = {
	Id: string,
	Volume: number,
}

local SoundIds: { [string]: Entry } = {
	Click = { Id = "rbxassetid://15675032796", Volume = 0.5 },
	Tab = { Id = "rbxassetid://15675037413", Volume = 0.4 },
	ToggleOn = { Id = "rbxassetid://10128760939", Volume = 0.5 },
	ToggleOff = { Id = "rbxassetid://10066968815", Volume = 0.5 },
	Hotkey = { Id = "rbxassetid://15675059323", Volume = 0.4 },
	Tool = { Id = "rbxassetid://15675037413", Volume = 0.5 },
	ToolOff = { Id = "rbxassetid://10066914500", Volume = 0.5 },
	Cancel = { Id = "rbxassetid://10066914500", Volume = 0.5 },
	Build = { Id = "rbxassetid://9120916241", Volume = 0.6 },
	Heavy = { Id = "rbxassetid://9120960694", Volume = 0.6 },
	Prop = { Id = "rbxassetid://9117556149", Volume = 0.6 },
	Delete = { Id = "rbxassetid://10066926605", Volume = 0.5 },
	Undo = { Id = "rbxassetid://15675046931", Volume = 0.4 },
	BrushAdd = { Id = "rbxassetid://15675055424", Volume = 0.6 },
	Success = { Id = "rbxassetid://10066947742", Volume = 0.5 },
	Warning = { Id = "rbxassetid://15675085146", Volume = 0.5 },
}

return SoundIds
