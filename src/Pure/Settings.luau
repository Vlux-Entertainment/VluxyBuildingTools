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
	StairHeight: number,
	RampHeight: number,
	DX: number,
	DY: number,
	DZ: number,
	Yaw: number,
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
	Axis: string,
}

local Settings = {}

--[[
	@return Settings -- a fresh table of the default values
]]
function Settings.Defaults(): Settings
	return {
		Version = 3,
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
		DoorHeight = 8,
		WindowWidth = 5,
		WindowHeight = 4,
		WindowSill = 3,
		Offset = 0,
		Copies = 3,
		ArchHeight = 10,
		ArchDepth = 2,
		ArchSegments = 16,
		GridTextureSize = 13,
		StairHeight = 6,
		RampHeight = 6,
		DX = 12,
		DY = 0,
		DZ = 0,
		Yaw = 0,
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
		StandardDoorHeight = 8,
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
		Axis = "X",
	}
end

--[=[
	Copies every saved value whose type matches the default's type over the defaults. Unknown keys
	and values of the wrong type are dropped, so an old or damaged save cannot break the plugin.

	@param saved any -- whatever the plugin settings store returned
	@return Settings
]=]
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

	-- The snap steps changed in version 2, so a save from before it takes the new ones.
	if source.Version ~= settings.Version then
		local fresh = Settings.Defaults()

		settings.Grid, settings.FineGrid = fresh.Grid, fresh.FineGrid
		settings.SnapRadius = fresh.SnapRadius
	end

	Settings.Sync(settings)

	return settings
end

return Settings
