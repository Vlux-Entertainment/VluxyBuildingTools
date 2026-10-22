--!strict

--[=[
	The working folder: the one Folder in Workspace the plugin builds in and changes. Nothing outside
	it is edited.

	Picking one is a small flow: start picking, click or select a Folder (it is outlined and waits),
	then confirm. A folder must carry the `VluxyBT_Map` tag unless the user allowed untagged folders.
	When the folder already holds shared settings (see `Settings.Shared`) that differ from the user's,
	the user chooses whose to keep before it becomes the working folder. While it is the working
	folder, the shared settings flow both ways: the user's changes are written to it, and changes
	written to it by teammates are taken over.

	@class WorkingFolder
]=]

local CollectionService = game:GetService("CollectionService")
local Selection = game:GetService("Selection")

local AppState = require("../State/AppState")
local Cursor = require("./Cursor")
local Display = require("./Display")
local Edit = require("./Edit")
local Geometry = require("../Core/Geometry")
local Overlay = require("../Core/Overlay")
local Settings = require("../Pure/Settings")
local Store = require("../State/Store")
local Trove = require("../Packages/Trove")

export type Deps = {
	Store: Store.Store,
	State: AppState.AppState,
	Overlay: Overlay.Overlay,
	Display: Display.Display,
	Cursor: Cursor.Cursor,
	Edit: Edit.Edit,
	Say: (text: string) -> (),
	Warn: (text: string) -> (),
	StopTools: () -> (),
}

type Conflict = { Folder: Instance, Names: string }

export type WorkingFolder = {
	_deps: Deps,
	_hover: Instance?,
	_conflict: Conflict?,
	_seen: { [string]: any },
	_watch: RBXScriptConnection?,
	_boxClock: number,
	--[=[ True while taking a new folder's settings, so they are not written onto the old folder. ]=]
	_adopting: boolean,
}

local MAP_TAG = "VluxyBT_Map"
local FOLDER_ATTRIBUTE = "VluxyBT_WorkingFolder"
local OLD_FOLDER_ATTRIBUTE = "VluxWorkingFolder"
local SHARED_PREFIX = "VluxyBT_"
local BOX_INTERVAL = 1

local WorkingFolder = {}

--[[
	@param instance Instance?
	@return Instance? -- the closest Folder above the instance, if it is inside Workspace
]]
local function folderOf(instance: Instance?): Instance?
	local ancestor = instance

	while ancestor and ancestor ~= workspace do
		if ancestor:IsA("Folder") then
			return ancestor
		end

		ancestor = ancestor.Parent
	end

	return nil
end

--[[
	@param self WorkingFolder
	@param target Instance
	@return boolean -- whether the plugin may work in the folder: it carries the map tag, or untagged folders are allowed
]]
local function allowed(self: WorkingFolder, target: Instance): boolean
	return self._deps.Store.Values.AllowUntagged or CollectionService:HasTag(target, MAP_TAG)
end

--[[
	@param self WorkingFolder
	@param which string -- Working, Pending or Hover
	@param target Instance?

	Outlines every Part inside the folder, or clears the outline when there is none to draw.
]]
local function drawBox(self: WorkingFolder, which: string, target: Instance?)
	local overlay = self._deps.Overlay
	local parts: { BasePart } = {}

	if target and target:IsDescendantOf(workspace) then
		for _, object in target:GetDescendants() do
			if object:IsA("BasePart") then
				table.insert(parts, object)
			end
		end
	end

	if #parts == 0 then
		return Overlay.ClearBox(overlay, which)
	end

	local cframe, size = Geometry.Bounds(parts)

	Overlay.DrawBox(overlay, which, cframe, size)
end

--[[
	@param self WorkingFolder

	Redraws the outlines of the working folder (only while it is selected), the folder waiting for a
	yes, and the one under the cursor while picking.
]]
local function redrawBoxes(self: WorkingFolder)
	local state = self._deps.State
	local folder, pending = state.Folder(), state.Pending()

	drawBox(self, "Working", if folder and table.find(Selection:Get(), folder) then folder else nil)
	drawBox(self, "Pending", pending)
	drawBox(
		self,
		"Hover",
		if state.Picking() and self._hover ~= pending and self._hover ~= folder then self._hover else nil
	)
end

--[[
	@param self WorkingFolder
	@param target Instance
	@param force boolean? -- true to overwrite every value the folder holds

	Writes the user's shared settings onto the folder. A value is written when the folder has none,
	when forced, or when the user changed it since it was last seen, so a stale local value never
	overwrites a teammate's newer one.
]]
local function publish(self: WorkingFolder, target: Instance, force: boolean?)
	local settings = self._deps.Store.Values :: any

	for _, entry in Settings.Shared do
		local value = settings[entry.Key]
		local stored = target:GetAttribute(SHARED_PREFIX .. entry.Key)

		if
			stored == nil
			or (force == true and stored ~= value)
			or (self._seen[entry.Key] ~= value and stored ~= value)
		then
			target:SetAttribute(SHARED_PREFIX .. entry.Key, value)
		end

		self._seen[entry.Key] = value
	end
end

--[[
	@param self WorkingFolder
	@param target Instance
	@param key string -- a shared setting

	Takes a value somebody changed on the folder, by hand or from another user, as this user's own.
]]
local function adopt(self: WorkingFolder, target: Instance, key: string)
	local store = self._deps.Store
	local value = target:GetAttribute(SHARED_PREFIX .. key)

	if key == "ColorTheme" then
		value = Settings.ThemeName(value)
	end

	local mine = (store.Values :: any)[key]

	if value == nil or type(value) ~= type(mine) or mine == value then
		return
	end

	self._seen[key] = value
	Store.Set(store, key, value)
end

--[[
	@param self WorkingFolder
	@param chosen Instance?

	Makes the folder the only place the plugin works in. Pastel colors are switched off first, so the
	old folder is not left recolored.
]]
local function setFolder(self: WorkingFolder, chosen: Instance?)
	local deps = self._deps
	local state = deps.State
	local display = deps.Display

	if chosen and not allowed(self, chosen) then
		return deps.Warn(
			`"{chosen.Name}" cannot be the working folder: select it, open View > Tag Editor and add the tag {MAP_TAG}.`
		)
	end

	local previous = state.Folder()

	if display.Colors.On and chosen ~= previous then
		Display.Quietly(display, function()
			Display.SetPastel(display, false)
		end)
	end

	deps.StopTools()

	if self._watch then
		self._watch:Disconnect()
		self._watch = nil
	end

	Geometry.SetScope(chosen)
	state.Folder(chosen)
	redrawBoxes(self)

	if previous ~= chosen then
		deps.Edit("Set working folder", function()
			if previous and previous:IsDescendantOf(workspace) then
				previous:SetAttribute(FOLDER_ATTRIBUTE, nil)
				previous:SetAttribute(OLD_FOLDER_ATTRIBUTE, nil)
			end

			if chosen then
				chosen:SetAttribute(FOLDER_ATTRIBUTE, true)
			end
		end)
	end

	if not chosen then
		return
	end

	if chosen:IsDescendantOf(workspace) then
		for _, entry in Settings.Shared do
			self._seen[entry.Key] = (deps.Store.Values :: any)[entry.Key]
		end

		publish(self, chosen)
		self._watch = chosen.AttributeChanged:Connect(function(name)
			for _, entry in Settings.Shared do
				if name == SHARED_PREFIX .. entry.Key then
					adopt(self, chosen, entry.Key)
				end
			end
		end)
	end

	Display.RestoreAuto(display)
	Display.Sweep(display)
	deps.Say(`Working in {chosen:GetFullName()}.`)
end

--[[
	@param self WorkingFolder
	@param chosen Instance

	Asks whose settings to keep when the folder's shared settings differ from the user's;
	otherwise makes it the working folder straight away.
]]
local function offer(self: WorkingFolder, chosen: Instance)
	local names = table.concat(
		Settings.Differences(self._deps.Store.Values, function(key)
			return chosen:GetAttribute(SHARED_PREFIX .. key)
		end),
		", "
	)

	if names ~= "" then
		self._conflict = { Folder = chosen, Names = names }
		self._deps.State.Conflict(names)
		self._deps.Say(`"{chosen.Name}" has different settings ({names}); use the folder's, overwrite or cancel.`)

		return
	end

	setFolder(self, chosen)
end

--[[
	@param self WorkingFolder
	@param target Instance

	Marks the folder as the one waiting for a yes.
]]
local function propose(self: WorkingFolder, target: Instance)
	if not allowed(self, target) then
		return self._deps.Warn(`"{target.Name}" needs the {MAP_TAG} tag first (View > Tag Editor).`)
	end

	self._deps.State.Pending(target)
	redrawBoxes(self)
	self._deps.Say(`Picked "{target:GetFullName()}"; press Yes to confirm.`)
end

--[=[
	@param deps Deps
	@param trove Trove -- holds the connections
	@return WorkingFolder
]=]
function WorkingFolder.new(deps: Deps, trove: Trove.Trove): WorkingFolder
	local self: WorkingFolder = {
		_deps = deps,
		_hover = nil,
		_conflict = nil,
		_seen = {},
		_watch = nil,
		_boxClock = 0,
		_adopting = false,
	}

	Store.OnSaved(deps.Store, function()
		local folder = deps.State.Folder()

		if folder and folder:IsDescendantOf(workspace) and not self._adopting then
			publish(self, folder)
		end
	end)

	trove:Connect(Selection.SelectionChanged, function()
		WorkingFolder._selectionChanged(self)
	end)
	trove:Add(function()
		if self._watch then
			self._watch:Disconnect()
		end
	end)

	return self
end

--[=[
	Offers the folder this place last worked in, found by the attribute the plugin left on it.

	@param self WorkingFolder
]=]
function WorkingFolder.Detect(self: WorkingFolder)
	for _, object in workspace:GetDescendants() do
		if
			object:IsA("Folder")
			and (object:GetAttribute(FOLDER_ATTRIBUTE) == true or object:GetAttribute(OLD_FOLDER_ATTRIBUTE) == true)
		then
			offer(self, object)

			return
		end
	end
end

--[=[
	@param self WorkingFolder
	@return Instance? -- the working folder, or nil
]=]
function WorkingFolder.Get(self: WorkingFolder): Instance?
	return self._deps.State.Folder()
end

--[=[
	@param self WorkingFolder
	@return boolean -- true when a usable working folder is set; says why when it is not
]=]
function WorkingFolder.Require(self: WorkingFolder): boolean
	local folder = self._deps.State.Folder()

	if folder and folder:IsDescendantOf(workspace) then
		if allowed(self, folder) then
			return true
		end

		self._deps.Warn(`"{folder.Name}" needs the {MAP_TAG} tag (View > Tag Editor).`)

		return false
	end

	self._deps.Say("Pick a working folder in the panel first.")

	return false
end

--[=[
	@param self WorkingFolder
	@return boolean -- true while the user is picking a folder
]=]
function WorkingFolder.IsPicking(self: WorkingFolder): boolean
	return self._deps.State.Picking()
end

--[=[
	Starts picking a folder. A Folder in Workspace that is already selected becomes the pick right
	away; otherwise the user clicks one in the viewport or selects one.

	@param self WorkingFolder
]=]
function WorkingFolder.StartPicking(self: WorkingFolder)
	local state = self._deps.State

	self._deps.StopTools()
	state.Picking(true)
	state.Pending(nil)
	self._hover = nil

	local selected = Selection:Get()
	local only = if #selected == 1 then selected[1] else nil

	if only and only:IsA("Folder") and only:IsDescendantOf(workspace) then
		return propose(self, only)
	end

	redrawBoxes(self)
	self._deps.Say("Click a Folder in the viewport, or select one in the Explorer.")
end

--[=[
	Gives up picking and clears the outlines picking drew.

	@param self WorkingFolder
]=]
function WorkingFolder.CancelPicking(self: WorkingFolder)
	local state = self._deps.State

	state.Picking(false)
	state.Pending(nil)
	self._hover = nil
	redrawBoxes(self)
end

--[=[
	Makes the picked folder the working folder, asking about differing settings first.

	@param self WorkingFolder
]=]
function WorkingFolder.ConfirmPicking(self: WorkingFolder)
	local state = self._deps.State
	local chosen = state.Pending()

	if not chosen then
		return self._deps.Say("Click a Folder in the viewport first.")
	end

	state.Picking(false)
	state.Pending(nil)
	self._hover = nil
	offer(self, chosen)
end

--[=[
	Settles whose shared settings the folder takes.

	@param self WorkingFolder
	@param choice string -- "Use" takes the folder's, "Overwrite" writes the user's, "Cancel" keeps the old folder
]=]
function WorkingFolder.Resolve(self: WorkingFolder, choice: string)
	local pending = self._conflict
	local store = self._deps.Store

	self._conflict = nil
	self._deps.State.Conflict(nil)

	if not pending then
		return
	end

	if choice == "Use" then
		self._adopting = true
		Store.Mutate(store, function(values)
			for _, entry in Settings.Shared do
				local theirs = pending.Folder:GetAttribute(SHARED_PREFIX .. entry.Key)

				if entry.Key == "ColorTheme" then
					theirs = Settings.ThemeName(theirs) or theirs
				end

				if theirs ~= nil and type(theirs) == type((values :: any)[entry.Key]) then
					(values :: any)[entry.Key] = theirs
				end
			end
		end)
		self._adopting = false
		setFolder(self, pending.Folder)
	elseif choice == "Overwrite" then
		setFolder(self, pending.Folder)

		if self._deps.State.Folder() == pending.Folder then
			publish(self, pending.Folder, true)
			Display.Retheme(self._deps.Display)
		end
	end
end

--[=[
	Handles a viewport click while picking: the Folder holding what was clicked becomes the pick.

	@param self WorkingFolder
	@return boolean -- true when the click was used for picking
]=]
function WorkingFolder.Click(self: WorkingFolder): boolean
	if not self._deps.State.Picking() then
		return false
	end

	local hit = Cursor.Hit(self._deps.Cursor)
	local target = if hit then folderOf(hit.Instance) else nil

	if target then
		propose(self, target)
	else
		self._deps.Say("Click a Part that sits in a Folder.")
	end

	return true
end

--[=[
	Runs every frame: follows the folder under the cursor while picking, refreshes the outlines once a
	second, and lets go of a working folder that was deleted.

	@param self WorkingFolder
	@param dt number
]=]
function WorkingFolder.Step(self: WorkingFolder, dt: number)
	local state = self._deps.State

	if state.Picking() then
		local hit = Cursor.Hit(self._deps.Cursor)
		local target = if hit then folderOf(hit.Instance) else nil

		if target ~= self._hover then
			self._hover = target
			redrawBoxes(self)
		end
	end

	self._boxClock += dt

	if self._boxClock >= BOX_INTERVAL then
		self._boxClock = 0
		redrawBoxes(self)
	end

	local folder = state.Folder()

	if folder and not folder:IsDescendantOf(workspace) then
		Geometry.SetScope(nil)
		state.Folder(nil)
		self._deps.StopTools()
		redrawBoxes(self)
		self._deps.Say("The working folder is gone; pick another one.")
	end
end

--[[
	@param self WorkingFolder

	While picking, a Folder selected in the Explorer becomes the pick; anything else selected drops
	the pick. Otherwise the selection only decides whether the working folder is outlined.
]]
function WorkingFolder._selectionChanged(self: WorkingFolder)
	local state = self._deps.State

	if not state.Picking() then
		if state.Folder() then
			redrawBoxes(self)
		end

		return
	end

	local selected = Selection:Get()
	local candidate = selected[1]

	if #selected == 1 and candidate and candidate:IsA("Folder") and candidate:IsDescendantOf(workspace) then
		return propose(self, candidate)
	end

	for _, object in selected do
		if object:IsDescendantOf(workspace) then
			return
		end
	end

	if #selected > 0 and state.Pending() then
		state.Pending(nil)
		redrawBoxes(self)
		self._deps.Say("Click or select a Folder in Workspace.")
	end
end

return WorkingFolder
