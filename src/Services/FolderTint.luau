--!strict

--[=[
	Tints the Explorer icon of folders and configurations by name, using the rules in
	`Pure/FolderTint`. Turned on, it sweeps the place once, then follows new instances and renames
	so they tint themselves. Each batch is one undo step. Turned off, it stops; tints already set
	stay, as they are ordinary properties of the place.

	@class FolderTint
]=]

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Pure = require("../Pure/FolderTint")
local Store = require("../State/Store")
local Trove = require("../Packages/Trove")

export type Deps = {
	Store: Store.Store,
}

type Run = { Connections: { RBXScriptConnection } }

export type FolderTint = {
	_deps: Deps,
	_on: boolean,
	_run: Run?,
	_trove: Trove.Trove,
	_pending: { [Instance]: boolean },
	_queued: boolean,
	_broken: boolean,
}

local SWEEP_CHUNK = 5000

local FolderTint = {}

--[[
	@param instance Instance
	@return boolean -- whether the plugin tints this class
]]
local function tintable(instance: Instance): boolean
	for _, class in Pure.Classes do
		if instance.ClassName == class then
			return true
		end
	end

	return false
end

--[[
	@param self FolderTint
	@param instance Instance
	@return boolean -- whether the tint was changed
	Sets the tint the rules give the instance's name; a name no rule matches is left alone. If the
	property cannot be read as a Color3, the service gives up instead of warning on every folder.
]]
local function apply(self: FolderTint, instance: Instance): boolean
	local hex = Pure.Match(instance.Name)

	if not hex then
		return false
	end

	local color = Color3.fromHex(hex)
	local read, current = pcall(function()
		return (instance :: any).IconTint
	end)

	if not read or typeof(current) ~= "Color3" then
		self._broken = true
		warn("VluxyBuildingTools: this Studio has no Color3 IconTint on folders, so folder tint is off.")

		return false
	end

	if current == color then
		return false
	end

	(instance :: any).IconTint = color

	return true
end

--[[
	@param self FolderTint
	Tints everything queued as one undo step.
]]
local function flush(self: FolderTint)
	self._queued = false

	local batch = self._pending
	self._pending = {}

	local recording = ChangeHistoryService:TryBeginRecording("Tint folders")
	local changed = false

	for instance in batch do
		if not self._broken and instance.Parent and apply(self, instance) then
			changed = true
		end
	end

	if recording then
		ChangeHistoryService:FinishRecording(
			recording,
			changed and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel
		)
	end
end

--[[
	@param self FolderTint
	@param instance Instance
	Queues an instance to be tinted at the end of this frame, so a burst of changes is one step.
]]
local function queue(self: FolderTint, instance: Instance)
	self._pending[instance] = true

	if not self._queued then
		self._queued = true
		task.defer(flush, self)
	end
end

--[[
	@param self FolderTint
	@param instance Instance
	@param run Run
	Starts following an instance's name so a rename retints it.
]]
local function follow(self: FolderTint, instance: Instance, run: Run)
	if not tintable(instance) then
		return
	end

	local connection = instance:GetPropertyChangedSignal("Name"):Connect(function()
		queue(self, instance)
	end)

	table.insert(run.Connections, connection)
	instance.Destroying:Once(function()
		connection:Disconnect()
	end)
	queue(self, instance)
end

--[[
	@param self FolderTint
	Follows every folder in the place, and every one added later.
]]
local function start(self: FolderTint)
	if self._run then
		return
	end

	local run: Run = { Connections = {} }
	self._run = run
	self._broken = false

	table.insert(
		run.Connections,
		game.DescendantAdded:Connect(function(instance)
			follow(self, instance, run)
		end)
	)

	task.spawn(function()
		local count = 0

		for _, instance in game:GetDescendants() do
			if run ~= self._run then
				return
			end

			follow(self, instance, run)
			count += 1

			if count % SWEEP_CHUNK == 0 then
				task.wait()
			end
		end
	end)
end

--[[
	@param self FolderTint
	Stops following the place.
]]
local function stop(self: FolderTint)
	local run = self._run

	if run then
		for _, connection in run.Connections do
			connection:Disconnect()
		end

		self._run = nil
		self._pending = {}
	end
end

--[=[
	@param deps Deps
	@param trove Trove -- holds the watcher on the setting
	@return FolderTint
]=]
function FolderTint.new(deps: Deps, trove: Trove.Trove): FolderTint
	local self: FolderTint = {
		_deps = deps,
		_on = false,
		_run = nil,
		_trove = trove,
		_pending = {},
		_queued = false,
		_broken = false,
	}

	local function set(value: any)
		self._on = value == true

		if self._on then
			start(self)
		else
			stop(self)
		end
	end

	set(Store.Get(deps.Store, "FolderTint"))
	trove:Add(Store.Watch(deps.Store, "FolderTint", set))
	trove:Add(function()
		stop(self)
	end)

	return self
end

--[=[
	Retints every folder from the rules again, for after the rules or a name changed behind the
	service's back.

	@param self FolderTint
]=]
function FolderTint.Reapply(self: FolderTint)
	if self._run then
		stop(self)
		start(self)
	end
end

return FolderTint
