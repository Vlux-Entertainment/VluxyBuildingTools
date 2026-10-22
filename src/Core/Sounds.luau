--!strict

--[=[
	Plays the plugin's sounds. Every id lives in `Pure/SoundIds`; this module only plays them, quietly,
	and never more than a few times a second per sound so held keys do not buzz.

	@class Sounds
]=]

local SoundService = game:GetService("SoundService")

local SoundIds = require("../Pure/SoundIds")
local Trove = require("../Packages/Trove")

export type Sounds = {
	_parent: Instance,
	_enabled: () -> boolean,
	_volume: () -> number,
	_made: { [string]: Sound },
	_last: { [string]: number },
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
		_made = {},
		_last = {},
	}

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
	local made: Sound = found or Instance.new("Sound")

	if not found then
		made.Name = "VluxyBT_" .. name
		made.SoundId = entry.Id
		made.Parent = self._parent
		self._made[name] = made
	end

	made.Volume = entry.Volume * math.clamp(self._volume(), 0, 1)

	local ok = pcall(function()
		SoundService:PlayLocalSound(made)
	end)

	if not ok then
		made:Play()
	end
end

return Sounds
