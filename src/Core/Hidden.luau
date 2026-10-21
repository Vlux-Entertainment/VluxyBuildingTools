--!strict

--[=[
	Local part hiding. A hidden part is made invisible through `LocalTransparencyModifier`, which is
	never saved and never reaches teammates, so hiding changes nothing in the place. The list lives in
	memory only.

	@class Hidden
]=]

local Trove = require("../Packages/Trove")

export type Hidden = {
	View: boolean,
	_parts: { [BasePart]: boolean },
}

local INVISIBLE = 1
local GHOST = 0.82

local Hidden = {}

--[[
	@param self Hidden
	@param part BasePart

	Shows or ghosts the part, depending on whether hidden parts are being viewed.
]]
local function apply(self: Hidden, part: BasePart)
	part.LocalTransparencyModifier = if self.View then GHOST else INVISIBLE
end

--[=[
	@param trove Trove -- holds the clean-up connection
	@return Hidden
]=]
function Hidden.new(trove: Trove.Trove): Hidden
	local self: Hidden = { View = false, _parts = {} }

	trove:Connect(workspace.DescendantRemoving, function(object)
		if object:IsA("BasePart") then
			self._parts[object] = nil
		end
	end)

	return self
end

--[=[
	@param self Hidden
	@param parts { BasePart }
]=]
function Hidden.Hide(self: Hidden, parts: { BasePart })
	for _, part in parts do
		self._parts[part] = true
		apply(self, part)
	end
end

--[=[
	Brings back every part this plugin hid.

	@param self Hidden
	@return number -- how many were hidden
]=]
function Hidden.UnhideAll(self: Hidden): number
	local count = 0

	for part in self._parts do
		count += 1

		if part.Parent then
			part.LocalTransparencyModifier = 0
		end
	end

	self._parts = {}

	return count
end

--[=[
	Switches between hiding parts completely and showing them as faint ghosts.

	@param self Hidden
]=]
function Hidden.ToggleView(self: Hidden)
	self.View = not self.View

	for part in self._parts do
		apply(self, part)
	end
end

--[=[
	@param self Hidden
	@return number
]=]
function Hidden.Count(self: Hidden): number
	local count = 0

	for _ in self._parts do
		count += 1
	end

	return count
end

return Hidden
