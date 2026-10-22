--!strict

--[=[
	The user's settings: loaded from and saved to the plugin settings, readable as plain values by
	the tools and reactively by the panel.

	Tools read `store.Values.Grid` every frame; the panel reads `Store.Get(store, "Grid")` inside vide
	so it redraws when the value changes. Every write goes through `Set` or `Mutate`, which is what
	keeps the two in step. Never assign into `Values` directly.

	@class Store
]=]

local Settings = require("../Pure/Settings")
local vide = require("../Packages/vide")

export type Store = {
	Values: Settings.Settings,
	_plugin: Plugin,
	_sources: { [string]: vide.Source<any> },
	_saved: { (Settings.Settings) -> () },
}

local SETTINGS_KEY = "VluxBlockoutSettings_v2"

local Store = {}

--[=[
	@param plugin Plugin
	@return Store -- the saved settings, or the defaults when nothing usable was saved
]=]
function Store.new(plugin: Plugin): Store
	local ok, saved = pcall(function()
		return plugin:GetSetting(SETTINGS_KEY)
	end)

	return {
		Values = Settings.Load(if ok then saved else nil),
		_plugin = plugin,
		_sources = {},
		_saved = {},
	}
end

--[[
	@param self Store
	@param key string
	@return vide.Source<any> -- the source that mirrors one setting, made the first time it is asked for
]]
local function sourceOf(self: Store, key: string): vide.Source<any>
	local found = self._sources[key]

	if found then
		return found
	end

	local made = vide.source((self.Values :: any)[key])

	self._sources[key] = made

	return made
end

--[=[
	Reads a setting so that a vide effect or reactive property re-runs when it changes.

	@param self Store
	@param key string
	@return any
]=]
function Store.Get(self: Store, key: string): any
	return sourceOf(self, key)()
end

--[=[
	Saves the settings and tells every listener added with `OnSaved`.

	@param self Store
]=]
function Store.Save(self: Store)
	pcall(function()
		self._plugin:SetSetting(SETTINGS_KEY, self.Values)
	end)

	for _, listener in self._saved do
		listener(self.Values)
	end
end

--[=[
	Runs a change that may touch many settings, saves once, then updates every reader of each
	setting that changed. Saving comes first so readers see the shared folder values already written.

	@param self Store
	@param change (values: Settings.Settings) -> ()
]=]
function Store.Mutate(self: Store, change: (values: Settings.Settings) -> ())
	local before = table.clone(self.Values :: any)

	change(self.Values)
	Store.Save(self)

	for key, value in self.Values :: any do
		if before[key] ~= value then
			local source = self._sources[key]

			if source then
				source(value)
			end
		end
	end
end

--[=[
	Calls `listener` every time the setting changes, but not for the value it has now.

	@param self Store
	@param key string
	@param listener (value: any) -> ()
	@return () -> () -- stops watching
]=]
function Store.Watch(self: Store, key: string, listener: (value: any) -> ()): () -> ()
	local unset = {}

	return (
		vide.root(function()
			vide.effect(function(previous: any): any
				local value = Store.Get(self, key)

				if previous ~= unset and previous ~= value then
					vide.untrack(function()
						listener(value)
					end)
				end

				return value
			end, unset)
		end)
	)
end

--[=[
	Writes one setting the way the panel does (see `Settings.Apply`) and saves.

	@param self Store
	@param key string
	@param value any
]=]
function Store.Set(self: Store, key: string, value: any)
	Store.Mutate(self, function(values)
		Settings.Apply(values, key, value)
	end)
end

--[=[
	Writes one setting and updates its readers without saving, for a value that changes many times a
	second, such as a slider being dragged. Call `Save` when it settles.

	@param self Store
	@param key string
	@param value any
]=]
function Store.Hold(self: Store, key: string, value: any)
	(self.Values :: any)[key] = value
	sourceOf(self, key)(value)
end

--[=[
	Puts every setting back to its default and saves.

	@param self Store
]=]
function Store.Reset(self: Store)
	Store.Mutate(self, function(values)
		for key, default in Settings.Defaults() :: any do
			(values :: any)[key] = default
		end
	end)
end

--[=[
	@param self Store
	@param listener (values: Settings.Settings) -> () -- called after every save
]=]
function Store.OnSaved(self: Store, listener: (values: Settings.Settings) -> ())
	table.insert(self._saved, listener)
end

return Store
