--!strict

--[=[
	The viewport aids that change how the map looks: pastel colors, the surface grid and locally
	hidden parts. It owns the three Core modules, mirrors their state into `AppState` for the
	panel, and remembers whether pastel and grid should come back on by themselves.

	Settings that restyle what is already in the map (theme, grid color and tile size, ghost
	transparency) are watched here, so changing them anywhere restyles the map.

	@class Display
]=]

local Colors = require("../Core/Colors")
local Geometry = require("../Core/Geometry")
local Hidden = require("../Core/Hidden")
local Profile = require("../Core/Profile")
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
		Hidden = Hidden.new(trove),
		_deps = deps,
		_quiet = false,
	}

	Hidden.SetGhost(self.Hidden, settings.GhostTransparency)
	trove:Add(Store.Watch(store, "GhostTransparency", function(value)
		Hidden.SetGhost(self.Hidden, value)
	end))
	trove:Add(Store.Watch(store, "GridTextureSize", function()
		SurfaceGrid.Resize(self.Grid)
	end))
	trove:Add(Store.Watch(store, "GridColor", function()
		SurfaceGrid.Recolor(self.Grid)
	end))
	trove:Add(Store.Watch(store, "ColorTheme", function()
		Display.Retheme(self)
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
	Profile.Run("Pastel", Colors.Set, self.Colors, on)
end

--[=[
	@param self Display
	@param on boolean
]=]
function Display.SetGrid(self: Display, on: boolean)
	Profile.Run("Grid", SurfaceGrid.Set, self.Grid, on)
end

--[=[
	Recolors the working folder with the theme in force, when pastel colors are on.

	@param self Display
]=]
function Display.Retheme(self: Display)
	Profile.Run("Pastel", Colors.Retheme, self.Colors)
end

--[=[
	Turns pastel colors and the grid back on if the user left them on.

	@param self Display
]=]
function Display.RestoreAuto(self: Display)
	local settings = self._deps.Store.Values

	if settings.AutoPastel and not self.Colors.On then
		Colors.Set(self.Colors, true)
	end

	if settings.AutoGrid and not self.Grid.On then
		SurfaceGrid.Set(self.Grid, true)
	end
end

--[=[
	Puts the map back to how it looks without the plugin, without forgetting the user's choices.

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
	@param self Display
	@param parts { BasePart }
]=]
function Display.Hide(self: Display, parts: { BasePart })
	Hidden.Hide(self.Hidden, parts)
	mirror(self)
end

--[=[
	@param self Display
	@return number -- how many parts were shown again
]=]
function Display.UnhideAll(self: Display): number
	local count = Hidden.UnhideAll(self.Hidden)

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
