--!strict

--[=[
	The tool settings and their saved form. Everything here is plain data, so it runs under Lune.

	@class Settings
]=]

export type Settings = {
	Version: number,
	Grid: number,
	FineGrid: number,
	Elevation: number,
	Height: number,
	Thickness: number,
	Width: number,
	Floor: number,
	Run: number,
	Landing: number,
	Extend: number,
	OpenWidth: number,
	OpenHeight: number,
	PillarWidth: number,
	DoorWidth: number,
	DoorHeight: number,
	WindowWidth: number,
	WindowHeight: number,
	WindowSill: number,
	Offset: number,
	Copies: number,
	ArchHeight: number,
	ArchDepth: number,
	ArchSegments: number,
	GridTextureSize: number,
	GridColor: string,
	ColorTheme: string,
	StairHeight: number,
	RampHeight: number,
	DX: number,
	DY: number,
	DZ: number,
	Yaw: number,
	VentSize: number,
	VentThickness: number,
	BrushRadius: number,
	BrushSpacing: number,
	BrushRandomYaw: boolean,
	BrushSizeMin: number,
	BrushSizeMax: number,
	GhostTransparency: number,
	DoorPanel: boolean,
	DoorFrame: boolean,
	FrameWidth: number,
	FrameDepth: number,
	DoorThickness: number,
	DoorTransparency: number,
	DoorCollide: boolean,
	PropScale: number,
	PropRandomRotation: boolean,
	PropRandomAmount: number,
	PropAutoCollapse: boolean,
	FieldStep: number,
	CameraLight: boolean,
	AllowUntagged: boolean,
	CameraLightRange: number,
	CameraLightBrightness: number,
	Roof: boolean,
	PillaredWalls: boolean,
	FloorTransparency: number,
	CutDepth: boolean,
	SnapToParts: boolean,
	AutoGrid: boolean,
	AutoPastel: boolean,
	SnapRadius: number,
	ConnectStructures: boolean,
	RoomJoin: string,
	StandardHeight: number,
	StandardThickness: number,
	StandardDoorWidth: number,
	StandardDoorHeight: number,
	HeightOverride: boolean,
	ThicknessOverride: boolean,
	DoorWidthOverride: boolean,
	DoorHeightOverride: boolean,
	RoofStyle: string,
	RoofRise: number,
	RoofOverhang: number,
	RoofThickness: number,
	FoundationHeight: number,
	FoundationMargin: number,
	PorchRailing: boolean,
	RailHeight: number,
	FenceHeight: number,
	FenceSpacing: number,
	BalusterSpacing: number,
	Pastel: boolean,
	Align: boolean,
	ShowGrid: boolean,
	Hotkeys: boolean,
	SoundEnabled: boolean,
	SoundVolume: number,
	Axis: string,
}

local Settings = {}

--[[ The door settings a save from before version 4 takes fresh, so it gets the standard door. ]]
local DOOR_KEYS =
	{ "DoorPanel", "DoorFrame", "FrameWidth", "FrameDepth", "DoorThickness", "DoorTransparency", "DoorCollide" }

--[[
	@return Settings -- a fresh table of the default values
]]
function Settings.Defaults(): Settings
	return {
		Version = 5,
		Grid = 4,
		FineGrid = 1,
		Elevation = 0,
		Height = 12,
		Thickness = 1,
		Width = 8,
		Floor = 1,
		Run = 1.5,
		Landing = 0,
		Extend = 8,
		OpenWidth = 6,
		OpenHeight = 10,
		PillarWidth = 2,
		DoorWidth = 4,
		DoorHeight = 7.75,
		WindowWidth = 5,
		WindowHeight = 4,
		WindowSill = 3,
		Offset = 0,
		Copies = 3,
		ArchHeight = 10,
		ArchDepth = 2,
		ArchSegments = 16,
		GridTextureSize = 13,
		GridColor = "FFFFFF",
		ColorTheme = "Pastel",
		StairHeight = 6,
		RampHeight = 6,
		DX = 12,
		DY = 0,
		DZ = 0,
		Yaw = 0,
		VentSize = 3,
		VentThickness = 0.2,
		BrushRadius = 6,
		BrushSpacing = 3,
		BrushRandomYaw = true,
		BrushSizeMin = 1,
		BrushSizeMax = 1,
		GhostTransparency = 0.82,
		DoorPanel = true,
		DoorFrame = true,
		FrameWidth = 0.25,
		FrameDepth = 1.1,
		DoorThickness = 0.2,
		DoorTransparency = 0.5,
		DoorCollide = false,
		PropScale = 1,
		PropRandomRotation = false,
		PropRandomAmount = 5,
		PropAutoCollapse = true,
		FieldStep = 0,
		CameraLight = false,
		AllowUntagged = false,
		CameraLightRange = 60,
		CameraLightBrightness = 0.5,
		Roof = false,
		PillaredWalls = false,
		FloorTransparency = 0,
		CutDepth = true,
		SnapToParts = true,
		AutoGrid = true,
		AutoPastel = true,
		SnapRadius = 5,
		ConnectStructures = true,
		RoomJoin = "Open",
		StandardHeight = 12,
		StandardThickness = 1,
		StandardDoorWidth = 4,
		StandardDoorHeight = 7.75,
		HeightOverride = false,
		ThicknessOverride = false,
		DoorWidthOverride = false,
		DoorHeightOverride = false,
		RoofStyle = "Gable",
		RoofRise = 5,
		RoofOverhang = 1,
		RoofThickness = 0.5,
		FoundationHeight = 2,
		FoundationMargin = 1,
		PorchRailing = true,
		RailHeight = 3,
		FenceHeight = 4,
		FenceSpacing = 4,
		BalusterSpacing = 1.2,
		Pastel = false,
		Align = false,
		ShowGrid = true,
		Hotkeys = true,
		SoundEnabled = true,
		SoundVolume = 0.5,
		Axis = "X",
	}
end

--[=[
	The values a tool field can override, as { field, standard, override flag }.

	@prop Standards { { string } }
	@within Settings
]=]
Settings.Standards = {
	{ "Height", "StandardHeight", "HeightOverride" },
	{ "Thickness", "StandardThickness", "ThicknessOverride" },
	{ "DoorWidth", "StandardDoorWidth", "DoorWidthOverride" },
	{ "DoorHeight", "StandardDoorHeight", "DoorHeightOverride" },
}

--[=[
	The color themes, in the order the panel shows them.

	@prop Themes { string }
	@within Settings
]=]
Settings.Themes = { "Pastel", "Unity", "Levels", "Structures", "Facing", "Size" }

--[=[
	The settings everyone working in one folder shares, as { Key, Name }. They are kept in
	attributes on the working folder, so the whole team sees the same viewport.

	@prop Shared { { Key: string, Name: string } }
	@within Settings
]=]
Settings.Shared = {
	{ Key = "ColorTheme", Name = "theme" },
	{ Key = "GhostTransparency", Name = "ghost transparency" },
	{ Key = "AutoPastel", Name = "pastel" },
	{ Key = "AutoGrid", Name = "grid" },
}

--[=[
	@param value any
	@return string? -- the theme the value names, ignoring case, or nil when it names none
]=]
function Settings.ThemeName(value: any): string?
	if type(value) == "string" then
		for _, name in Settings.Themes do
			if string.lower(name) == string.lower(value) then
				return name
			end
		end
	end

	return nil
end

--[=[
	@param key string -- a setting
	@return string? -- the override flag that remembers a tool field differs from its standard, if the key has one
]=]
function Settings.OverrideFlag(key: string): string?
	for _, row in Settings.Standards do
		if row[1] == key then
			return row[3]
		end
	end

	return nil
end

--[=[
	Writes one value the way the panel does: a tool field that has a standard remembers whether it
	now differs from it, and a changed standard flows into every field that is not overridden.

	@param settings Settings
	@param key string
	@param value any
]=]
function Settings.Apply(settings: Settings, key: string, value: any)
	local target = settings :: any
	local flag = Settings.OverrideFlag(key)

	target[key] = value

	if flag then
		target[flag] = value ~= target["Standard" .. key]
	elseif string.sub(key, 1, 8) == "Standard" then
		Settings.Sync(settings)
	end
end

--[=[
	@param settings Settings
	@param read (key: string) -> any -- the folder's stored value of a shared setting
	@return { string } -- the names of the shared settings the folder holds a different value for
]=]
function Settings.Differences(settings: Settings, read: (key: string) -> any): { string }
	local names: { string } = {}

	for _, entry in Settings.Shared do
		local theirs = read(entry.Key)
		local mine = (settings :: any)[entry.Key]

		if entry.Key == "ColorTheme" then
			theirs = Settings.ThemeName(theirs) or theirs
		end

		if theirs ~= nil and type(theirs) == type(mine) then
			local same = if type(mine) == "number" then math.abs((theirs :: number) - mine) < 1e-6 else theirs == mine

			if not same then
				table.insert(names, entry.Name)
			end
		end
	end

	return names
end

--[=[
	Gives every field that is not overridden the standard value, and clears an override that now
	matches its standard.

	@param settings Settings
]=]
function Settings.Sync(settings: Settings)
	local target = settings :: any

	for _, row in Settings.Standards do
		local field, standard, flag = row[1], row[2], row[3]

		if target[field] == target[standard] then
			target[flag] = false
		end

		if not target[flag] then
			target[field] = target[standard]
		end
	end
end

--[=[
	Copies every saved value whose type matches the default's type over the defaults. Unknown keys
	and values of the wrong type are dropped, so an old or damaged save cannot break the plugin.

	@param saved any -- whatever the plugin settings store returned
	@return Settings
]=]
function Settings.Load(saved: any): Settings
	local settings = Settings.Defaults()

	if type(saved) ~= "table" then
		return settings
	end

	local target = settings :: any
	local source = saved :: { [any]: any }

	for key, default in Settings.Defaults() :: any do
		if type(source[key]) == type(default) then
			target[key] = source[key]
		end
	end

	for _, row in Settings.Standards do
		local field, standard, flag = row[1], row[2], row[3]

		if source[flag] == nil and type(source[field]) == "number" and source[field] ~= target[standard] then
			target[flag] = true
		end
	end

	local version = if type(source.Version) == "number" then source.Version else 0
	local fresh = Settings.Defaults()

	-- The snap steps changed in version 2, so a save from before it takes the new ones.
	if version < 2 then
		settings.Grid, settings.FineGrid = fresh.Grid, fresh.FineGrid
		settings.SnapRadius = fresh.SnapRadius
	end

	-- The door defaults became the standard door and frame in version 4.
	if version < 4 then
		for _, key in DOOR_KEYS do
			target[key] = (fresh :: any)[key]
		end
	end

	-- The camera light became dimmer by default in version 5; a light left at the old default follows.
	if version < 5 and settings.CameraLightBrightness == 2 then
		settings.CameraLightBrightness = fresh.CameraLightBrightness
	end

	Settings.Sync(settings)

	return settings
end

return Settings
