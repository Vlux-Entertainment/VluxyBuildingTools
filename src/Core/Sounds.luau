--!strict

--[=[
	Plays the plugin's sounds for this Studio user only, through `SoundService:PlayLocalSound`. The
	Sound objects are never put in the place, so Team Create does not hand them to anyone else. Every
	id lives in `Pure/SoundIds`; this module only plays them, quietly, and never more than a few
	times a second per sound so held keys do not buzz.

	@class Sounds
]=]

local SoundService = game:GetService("SoundService")

local SoundIds = require("../Pure/SoundIds")
local Trove = require("../Packages/Trove")

export type Sounds = {
	_enabled: () -> boolean,
	_volume: () -> number,
	_made: { [string]: Sound },
	_last: { [string]: number },
	_other: number,
}

local MIN_GAP = 0.05

local Sounds = {}

--[=[
	@param enabled () -> boolean
	@param volume () -> number -- a multiplier from 0 to 1
	@param trove Trove
	@return Sounds
]=]
function Sounds.new(enabled: () -> boolean, volume: () -> number, trove: Trove.Trove): Sounds
	local self: Sounds = {
		_enabled = enabled,
		_volume = volume,
		_made = {},
		_last = {},
		_other = 0,
	}

	--[[ Older versions put audio players in SoundService, where Team Create shares them; remove any. ]]
	local function sweep(object: Instance)
		if
			(object:IsA("AudioPlayer") or object:IsA("AudioDeviceOutput"))
			and string.sub(object.Name, 1, 8) == "VluxyBT_"
		then
			task.defer(object.Destroy, object)
		end
	end

	for _, child in SoundService:GetChildren() do
		sweep(child)
	end

	trove:Connect(SoundService.ChildAdded, sweep)
	trove:Add(function()
		for _, sound in self._made do
			sound:Destroy()
		end

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
	if SoundService:GetAttribute("VluxyBT_SoundDebug") == true then
		print(`[VluxyBuildingTools] sound {name} {tostring(self):sub(-8)} at {os.clock()}`)
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
	local sound: Sound = found or Instance.new("Sound")

	if not found then
		sound.Name = "VluxyBT_" .. name
		sound.SoundId = entry.Id
		self._made[name] = sound
	end

	sound.Volume = entry.Volume * math.clamp(self._volume(), 0, 1)
	SoundService:PlayLocalSound(sound)
end

return Sounds
