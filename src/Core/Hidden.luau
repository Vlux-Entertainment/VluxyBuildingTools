--!strict

--[=[
	Part hiding, shared with the whole team. A hidden part carries the `VluxyBT_Hidden` tag and is
	locked, both of which replicate; every client watches the tag and makes tagged parts invisible on
	its own screen through `LocalTransparencyModifier`. Showing hidden parts as ghosts stays local.

	@class Hidden
]=]

local CollectionService = game:GetService("CollectionService")

local Trove = require("../Packages/Trove")

export type Hidden = {
	View: boolean,
	Ghost: number,
	_parts: { [BasePart]: boolean },
}

local LOCK_ATTRIBUTE = "VluxyBT_HiddenLock"
local TAG = "VluxyBT_Hidden"
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

--[[
	@param self Hidden
	@param object Instance

	Hides a part a teammate, an undo or this user tagged.
]]
local function tagged(self: Hidden, object: Instance)
	if object:IsA("BasePart") and object:IsDescendantOf(workspace) then
		self._parts[object] = true
		apply(self, object)
	end
end

--[[
	@param self Hidden
	@param object Instance

	Shows a part whose tag was removed, by a teammate, an undo or this user.
]]
local function untagged(self: Hidden, object: Instance)
	if object:IsA("BasePart") and self._parts[object] then
		self._parts[object] = nil
		setLocal(object, 0)
	end
end

--[=[
	Watches the hidden tag, so parts hidden by anyone disappear here too. Unloading shows every part
	on this screen again without changing the place.

	@param trove Trove -- holds the connections and the clean-up
	@param changed (() -> ())? -- called when the hidden set changes from outside, such as a teammate hiding
	@return Hidden
]=]
function Hidden.new(trove: Trove.Trove, changed: (() -> ())?): Hidden
	local self: Hidden = { View = false, Ghost = 0.82, _parts = {} }

	for _, object in CollectionService:GetTagged(TAG) do
		tagged(self, object)
	end

	trove:Connect(CollectionService:GetInstanceAddedSignal(TAG), function(object)
		tagged(self, object)

		if changed then
			changed()
		end
	end)
	trove:Connect(CollectionService:GetInstanceRemovedSignal(TAG), function(object)
		untagged(self, object)

		if changed then
			changed()
		end
	end)
	trove:Add(function()
		for part in self._parts do
			setLocal(part, 0)
		end
	end)

	trove:Connect(workspace.DescendantRemoving, function(object)
		if not object:IsA("BasePart") then
			return
		end

		task.defer(function()
			if not object:IsDescendantOf(workspace) then
				self._parts[object] = nil
			end
		end)
	end)

	return self
end

--[=[
	Hides the parts for everyone: tags and locks them, remembering the lock they had. Run it inside
	an edit, so it is one undo step.

	@param self Hidden
	@param parts { BasePart }
]=]
function Hidden.Hide(self: Hidden, parts: { BasePart })
	for _, part in parts do
		if part:GetAttribute(LOCK_ATTRIBUTE) == nil then
			part:SetAttribute(LOCK_ATTRIBUTE, part.Locked)
		end

		part.Locked = true
		CollectionService:AddTag(part, TAG)
		self._parts[part] = true
		apply(self, part)
	end
end

--[[
	@param part BasePart

	Makes the part visible for everyone and gives it back the Locked state it had before it was hidden.
]]
local function reveal(part: BasePart)
	setLocal(part, 0)
	CollectionService:RemoveTag(part, TAG)

	local was = part:GetAttribute(LOCK_ATTRIBUTE)

	if type(was) == "boolean" then
		part.Locked = was
	end

	part:SetAttribute(LOCK_ATTRIBUTE, nil)
end

--[=[
	Brings back every hidden part for everyone, including parts hidden by an older version or
	replaced by a union since, which are found by the attribute that remembers their lock. Run it
	inside an edit when the user asks for it, so it is one undo step.

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

	for _, object in CollectionService:GetTagged(TAG) do
		if object:IsA("BasePart") then
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
	@return { Instance } -- every hidden part, by anyone, for rays to pass through
]=]
function Hidden.Parts(self: Hidden): { Instance }
	local parts: { Instance } = {}

	for part in self._parts do
		table.insert(parts, part)
	end

	return parts
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
