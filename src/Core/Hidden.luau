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
	Ghost: number,
	_parts: { [BasePart]: boolean },
}

local LOCK_ATTRIBUTE = "VluxyBT_HiddenLock"
local INVISIBLE = 1

local Hidden = {}

--[[
	@param part BasePart
	@param value number

	Sets the local transparency of the part and of the grid textures and decals drawn on it.
]]
local function setLocal(part: BasePart, value: number)
	part.LocalTransparencyModifier = value

	for _, child in part:GetChildren() do
		if child:IsA("Decal") then
			child.LocalTransparencyModifier = value
		end
	end
end

--[[
	@param self Hidden
	@param part BasePart

	Shows or ghosts the part, depending on whether hidden parts are being viewed.
]]
local function apply(self: Hidden, part: BasePart)
	setLocal(part, if self.View then self.Ghost else INVISIBLE)
end

--[=[
	@param trove Trove -- holds the clean-up connection
	@return Hidden
]=]
function Hidden.new(trove: Trove.Trove): Hidden
	local self: Hidden = { View = false, Ghost = 0.82, _parts = {} }

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
		if part:GetAttribute(LOCK_ATTRIBUTE) == nil then
			part:SetAttribute(LOCK_ATTRIBUTE, part.Locked)
		end

		part.Locked = true
		self._parts[part] = true
		apply(self, part)
	end
end

--[[
	@param part BasePart

	Makes the part visible and gives it back the Locked state it had before it was hidden.
]]
local function reveal(part: BasePart)
	setLocal(part, 0)

	local was = part:GetAttribute(LOCK_ATTRIBUTE)

	if type(was) == "boolean" then
		part.Locked = was
	end

	part:SetAttribute(LOCK_ATTRIBUTE, nil)
end

--[=[
	Brings back every part this plugin hid, including parts hidden in an earlier session or replaced
	by a union since, which are found by the attribute that remembers their lock.

	@param self Hidden
	@return number -- how many were hidden
]=]
function Hidden.UnhideAll(self: Hidden): number
	local seen: { [BasePart]: boolean } = {}

	for part in self._parts do
		if part.Parent then
			seen[part] = true
		end
	end

	for _, object in workspace:GetDescendants() do
		if object:IsA("BasePart") and object:GetAttribute(LOCK_ATTRIBUTE) ~= nil then
			seen[object] = true
		end
	end

	local count = 0

	for part in seen do
		count += 1
		reveal(part)
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
	Sets how see-through the ghosted hidden parts are, and redraws them if they are shown.

	@param self Hidden
	@param value number -- 0 solid, 1 clear
]=]
function Hidden.SetGhost(self: Hidden, value: number)
	self.Ghost = value

	if self.View then
		for part in self._parts do
			apply(self, part)
		end
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
