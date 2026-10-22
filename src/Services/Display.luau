--!strict

--[=[
	The viewport aids that change how the map looks: pastel colors, the surface grid and hidden
	parts. It owns the three Core modules, mirrors their state into `AppState` for the panel, and
	remembers whether pastel and grid should come back on by themselves.

	Settings that restyle what is already in the map (theme, grid color and tile size, ghost
	transparency) are watched here, so changing them anywhere restyles the map. Only the folder's
	admin restyles it; everyone else sees the admin's changes, which replicate.

	@class Display
]=]

local Colors = require("../Core/Colors")
local Geometry = require("../Core/Geometry")
local Hidden = require("../Core/Hidden")
local Settings = require("../Pure/Settings")
local Store = require("../State/Store")
local SurfaceGrid = require("../Core/SurfaceGrid")
local Trove = require("../Packages/Trove")

local AppState = require("../State/AppState")
local Edit = require("./Edit")

export type Deps = {
	Store: Store.Store,
	State: AppState.AppState,
	Edit: Edit.Edit,
	Say: (text: string) -> (),
	--[=[ Stops the active tool before the map is restyled. ]=]
	StopTools: () -> (),
	--[=[ True when this user is the working folder's admin, who alone restyles the shared map. ]=]
	IsAdmin: () -> boolean,
}

export type Display = {
	Colors: Colors.Colors,
	Grid: SurfaceGrid.SurfaceGrid,
	Hidden: Hidden.Hidden,
	_deps: Deps,
	_quiet: boolean,
}

local THEME_ATTRIBUTE = "VluxyBT_ColorTheme"

local Display = {}

--[[
	@param self Display
	Copies the on/off state of each aid into AppState, so the panel and toolbar follow it.
]]
local function mirror(self: Display)
	local state = self._deps.State

	state.PastelOn(self.Colors.On)
	state.GridOn(self.Grid.On)
	state.HiddenView(self.Hidden.View)
	state.HiddenCount(Hidden.Count(self.Hidden))
end

--[=[
	@param deps Deps
	@param trove Trove -- holds the connections and watchers
	@return Display
]=]
function Display.new(deps: Deps, trove: Trove.Trove): Display
	local store, settings = deps.Store, deps.Store.Values
	local self: Display

	local function remember(key: string): (boolean) -> ()
		return function(value: boolean)
			if not self._quiet then
				Store.Set(store, key, value)
			end
		end
	end

	self = {
		Colors = Colors.new({
			GetTheme = function()
				return Display.Theme(self)
			end,
			GetLevel = function()
				return settings.StandardHeight + 2 * settings.Floor, settings.Floor
			end,
			Remember = remember("AutoPastel"),
			GetScope = Geometry.GetScope,
			Edit = deps.Edit,
			Say = deps.Say,
			Refresh = function()
				mirror(self)
			end,
			Stop = deps.StopTools,
		}, trove),
		Grid = SurfaceGrid.new({
			Remember = remember("AutoGrid"),
			GetScope = Geometry.GetScope,
			GetSize = function()
				return settings.GridTextureSize
			end,
			GetColor = function()
				return SurfaceGrid.ColorOf(settings.GridColor)
			end,
			Edit = deps.Edit,
			Say = deps.Say,
			Refresh = function()
				mirror(self)
			end,
			Stop = deps.StopTools,
		}, trove),
		Hidden = Hidden.new(trove, function()
			mirror(self)
		end),
		_deps = deps,
		_quiet = false,
	}

	Hidden.SetGhost(self.Hidden, settings.GhostTransparency)
	trove:Add(Store.Watch(store, "GhostTransparency", function(value)
		Hidden.SetGhost(self.Hidden, value)
	end))
	trove:Add(Store.Watch(store, "GridTextureSize", function()
		if deps.IsAdmin() then
			SurfaceGrid.Resize(self.Grid)
		end
	end))
	trove:Add(Store.Watch(store, "GridColor", function()
		if deps.IsAdmin() then
			SurfaceGrid.Recolor(self.Grid)
		end
	end))
	trove:Add(Store.Watch(store, "ColorTheme", function()
		if deps.IsAdmin() then
			Colors.Retheme(self.Colors)
		end
	end))

	local recount = false

	--[[ A deleted hidden part leaves the hidden list, so the panel's count is redone once per frame of deletions. ]]
	trove:Connect(workspace.DescendantRemoving, function(object)
		if recount or not object:IsA("BasePart") then
			return
		end

		recount = true
		task.defer(function()
			recount = false
			mirror(self)
		end)
	end)
	mirror(self)

	return self
end

--[=[
	@param self Display
	@return string -- the color theme in force: the working folder's shared theme, else the user's own
]=]
function Display.Theme(self: Display): string
	local folder = Geometry.GetScope()
	local shared = if folder then Settings.ThemeName(folder:GetAttribute(THEME_ATTRIBUTE)) else nil

	return shared or self._deps.Store.Values.ColorTheme
end

--[=[
	Runs `change` without remembering the pastel and grid switches it flips, for switches the
	plugin makes on its own (changing folder, suspending) rather than the user.

	@param self Display
	@param change () -> ()
]=]
function Display.Quietly(self: Display, change: () -> ())
	self._quiet = true

	local ok, err = pcall(change :: any)

	self._quiet = false

	if not ok then
		error(err, 0)
	end
end

--[=[
	@param self Display
	@param on boolean
]=]
function Display.SetPastel(self: Display, on: boolean)
	Colors.Set(self.Colors, on)
end

--[=[
	@param self Display
	@param on boolean
]=]
function Display.SetGrid(self: Display, on: boolean)
	SurfaceGrid.Set(self.Grid, on)
end

--[=[
	Recolors the working folder with the theme in force, when pastel colors are on.

	@param self Display
]=]
function Display.Retheme(self: Display)
	Colors.Retheme(self.Colors)
end

--[=[
	Turns pastel colors and the grid back on if they were left on. Only the admin switches them,
	since everyone sees the change.

	@param self Display
]=]
function Display.RestoreAuto(self: Display)
	local settings = self._deps.Store.Values

	if not self._deps.IsAdmin() then
		return
	end

	if settings.AutoPastel and not self.Colors.On then
		Colors.Set(self.Colors, true)
	end

	if settings.AutoGrid and not self.Grid.On then
		SurfaceGrid.Set(self.Grid, true)
	end
end

--[=[
	Puts the map back to how it looks without the plugin, without forgetting the user's choices.
	Hidden parts are shown again for everyone; this is not an undo step.

	@param self Display
]=]
function Display.Suspend(self: Display)
	Hidden.UnhideAll(self.Hidden)
	Display.Quietly(self, function()
		if self.Colors.On then
			Colors.Set(self.Colors, false)
		end

		if self.Grid.On then
			SurfaceGrid.Set(self.Grid, false)
		end
	end)
	mirror(self)
end

--[=[
	Gives a Part a plugin edit just made its pastel color and grid.

	@param self Display
	@param part BasePart
]=]
function Display.Adopt(self: Display, part: BasePart)
	SurfaceGrid.Adopt(self.Grid, part)
	Colors.Adopt(self.Colors, part)
end

--[=[
	Tidies the colors and grid after every plugin edit.

	@param self Display
]=]
function Display.Sweep(self: Display)
	SurfaceGrid.Sweep(self.Grid)
	Colors.Sweep(self.Colors)
end

--[=[
	Hides the parts for everyone, as one undo step.

	@param self Display
	@param parts { BasePart }
	@return boolean -- whether the edit went through
]=]
function Display.Hide(self: Display, parts: { BasePart }): boolean
	local ok = self._deps.Edit("Hide parts", function()
		Hidden.Hide(self.Hidden, parts)
	end)

	mirror(self)

	return ok
end

--[=[
	Shows every hidden part again for everyone, as one undo step.

	@param self Display
	@return number -- how many parts were shown again
]=]
function Display.UnhideAll(self: Display): number
	local count = 0

	self._deps.Edit("Unhide all", function()
		count = Hidden.UnhideAll(self.Hidden)
	end)
	mirror(self)

	return count
end

--[=[
	Switches hidden parts between fully hidden and ghosted.

	@param self Display
]=]
function Display.ToggleHiddenView(self: Display)
	Hidden.ToggleView(self.Hidden)
	mirror(self)
end

--[=[
	Restores the original colors as the plugin unloads, as one undo step.

	@param self Display
]=]
function Display.Unload(self: Display)
	Colors.RestoreOnUnload(self.Colors)
end

return Display
