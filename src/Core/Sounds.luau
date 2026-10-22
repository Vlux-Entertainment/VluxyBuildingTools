--!strict

--[=[
	Plays the plugin's sounds through AudioPlayers wired to a device output. Every id lives in `Pure/SoundIds`; this module only plays them, quietly,
	and never more than a few times a second per sound so held keys do not buzz.

	@class Sounds
]=]

local SoundIds = require("../Pure/SoundIds")
local Trove = require("../Packages/Trove")

export type Sounds = {
	_parent: Instance,
	_enabled: () -> boolean,
	_volume: () -> number,
	_output: AudioDeviceOutput,
	_made: { [string]: AudioPlayer },
	_last: { [string]: number },
	_other: number,
}

local MIN_GAP = 0.05

local Sounds = {}

--[=[
	@param parent Instance -- where the Sound objects live; they are not saved into the place
	@param enabled () -> boolean
	@param volume () -> number -- a multiplier from 0 to 1
	@param trove Trove
	@return Sounds
]=]
function Sounds.new(parent: Instance, enabled: () -> boolean, volume: () -> number, trove: Trove.Trove): Sounds
	local self: Sounds = {
		_parent = parent,
		_enabled = enabled,
		_volume = volume,
		_output = Instance.new("AudioDeviceOutput"),
		_made = {},
		_last = {},
		_other = 0,
	}

	self._output.Name = "VluxyBT_SoundOutput"
	self._output.Archivable = false
	self._output.Parent = parent

	trove:Add(function()
		for _, player in self._made do
			player:Destroy()
		end

		self._output:Destroy()

		table.clear(self._made)
	end)

	return self
end

--[=[
	@param self Sounds
	@param name string -- a key of `SoundIds`

	Plays the sound once. An unknown name or a switched-off setting does nothing.
]=]
function Sounds.Play(self: Sounds, name: string)
	if name == "Click" or name == "Tab" or name == "Hotkey" then
		local asked = os.clock()

		task.delay(0.05, function()
			if self._other < asked - 0.1 then
				Sounds.Sound(self, name)
			end
		end)

		return
	end

	self._other = os.clock()
	Sounds.Sound(self, name)
end

--[[
	@param self Sounds
	@param name string

	Starts the sound now. Clicks go through `Play` first so a click that also does something plays only what it did.
]]
function Sounds.Sound(self: Sounds, name: string)
	if game:GetService("SoundService"):GetAttribute("VluxyBT_SoundDebug") == true then
		print(
			`[VluxyBuildingTools] sound {name} from {tostring(self._output)} {tostring(self):sub(-8)} at {os.clock()}`
		)
	end

	local entry = SoundIds[name]

	if not entry or not self._enabled() then
		return
	end

	local now = os.clock()

	if now - (self._last[name] or 0) < MIN_GAP then
		return
	end

	self._last[name] = now

	local found = self._made[name]
	local made: AudioPlayer = found or Instance.new("AudioPlayer")

	if not found then
		made.Name = "VluxyBT_" .. name
		made.Archivable = false
		made.Asset = entry.Id
		made.Parent = self._parent

		local wire = Instance.new("Wire")

		wire.Archivable = false
		wire.SourceInstance = made
		wire.TargetInstance = self._output
		wire.Parent = made
		self._made[name] = made
	end

	made.Volume = entry.Volume * math.clamp(self._volume(), 0, 1)
	made.TimePosition = 0
	made:Play()
end

return Sounds
