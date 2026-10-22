--!strict

--[=[
	Tells teammates in Team Create that this user has the plugin open, through a Workspace attribute
	holding the time it was last seen. While a teammate has it open, closing the plugin leaves the
	shared viewport aids (pastel colors, grid) alone for them.

	@class Presence
]=]

local RunService = game:GetService("RunService")

local Trove = require("../Packages/Trove")

export type Presence = {
	_name: string,
}

local PREFIX = "VluxyBT_Active_"
local TIMEOUT = 45
local INTERVAL = 10

local Presence = {}

--[[
	@return number -- the Studio user id, or 0 when it cannot be read
]]
local function userId(): number
	local ok, id = pcall(function()
		return game:GetService("StudioService"):GetUserId()
	end)

	return if ok and type(id) == "number" then id else 0
end

--[=[
	@param isOpen () -> boolean -- whether the plugin's panel is open now
	@param trove Trove -- stops the heartbeat when the plugin unloads
	@return Presence
]=]
function Presence.new(isOpen: () -> boolean, trove: Trove.Trove): Presence
	local self: Presence = { _name = PREFIX .. userId() }
	local alive = true

	trove:Add(function()
		alive = false
	end)

	task.spawn(function()
		while alive do
			if isOpen() then
				Presence.Mark(self, true)
			end

			task.wait(INTERVAL)
		end
	end)

	return self
end

--[=[
	Records, or clears, that this user has the plugin open.

	@param self Presence
	@param on boolean
]=]
function Presence.Mark(self: Presence, on: boolean)
	if RunService:IsEdit() then
		workspace:SetAttribute(self._name, if on then os.time() else nil)
	end
end

--[=[
	@param self Presence
	@return boolean -- whether another user has had the plugin open within the timeout
]=]
function Presence.OthersHere(self: Presence): boolean
	for name, stamp in workspace:GetAttributes() do
		if
			string.sub(name, 1, #PREFIX) == PREFIX
			and name ~= self._name
			and type(stamp) == "number"
			and math.abs(os.time() - stamp) < TIMEOUT
		then
			return true
		end
	end

	return false
end

return Presence
