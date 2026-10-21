--!strict

--[=[
	The reversible pastel toggle. It gives every Part a pastel color and remembers the original in an
	attribute, so the colors survive a crash and can always be restored. The attribute names match
	the old standalone Greybox plugin on purpose.

	@class Colors
]=]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

local Trove = require("../Packages/Trove")

export type Colors = {
	On: boolean,
	_colored: { [BasePart]: boolean },
	_random: Random,
	_edit: (string, () -> ()) -> boolean,
	_say: (string) -> (),
	_refresh: () -> (),
	_stop: () -> (),
	_scope: () -> Instance?,
}

local ORIGINAL = "VluxGreybox_OriginalColor_v1"
local UNION = "VluxGreybox_OriginalUsePartColor_v1"
local ACTIVE = "VluxGreybox_Enabled_v1"

local PALETTE = {
	Color3.fromRGB(188, 148, 158),
	Color3.fromRGB(187, 158, 142),
	Color3.fromRGB(184, 184, 138),
	Color3.fromRGB(151, 178, 146),
	Color3.fromRGB(137, 181, 166),
	Color3.fromRGB(139, 176, 187),
	Color3.fromRGB(145, 161, 190),
	Color3.fromRGB(165, 149, 190),
	Color3.fromRGB(185, 145, 181),
	Color3.fromRGB(187, 153, 167),
}

local Colors = {}

--[[
	@param part BasePart

	Gives the part a pastel color, saving its original color first.
]]
local function apply(self: Colors, part: BasePart)
	if typeof(part:GetAttribute(ORIGINAL)) ~= "Color3" then
		part:SetAttribute(ORIGINAL, part.Color)
	end

	if part:IsA("PartOperation") then
		if typeof(part:GetAttribute(UNION)) ~= "boolean" then
			part:SetAttribute(UNION, part.UsePartColor)
		end

		part.UsePartColor = true
	end

	part.Color = PALETTE[self._random:NextInteger(1, #PALETTE)]
	self._colored[part] = true
end

--[[
	@param part BasePart

	Puts the saved original color back and clears the saved attributes.
]]
local function restore(part: BasePart)
	local color = part:GetAttribute(ORIGINAL)

	if typeof(color) == "Color3" then
		part.Color = color
		part:SetAttribute(ORIGINAL, nil)
	end

	local union = part:GetAttribute(UNION)

	if part:IsA("PartOperation") and typeof(union) == "boolean" then
		part.UsePartColor = union
		part:SetAttribute(UNION, nil)
	end
end

--[=[
	Builds the toggle and wires it to Workspace so new Parts follow the toggle and undo re-reads it.

	@param deps { Edit: (string, () -> ()) -> boolean, Say: (string) -> (), Refresh: () -> (), Stop: () -> () }
	@param trove Trove -- holds the connections
	@return Colors
]=]
function Colors.new(
	deps: {
		Edit: (string, () -> ()) -> boolean,
		Say: (string) -> (),
		Refresh: () -> (),
		Stop: () -> (),
		GetScope: () -> Instance?,
	},
	trove: Trove.Trove
): Colors
	local self: Colors = {
		On = false,
		_colored = {},
		_random = Random.new(),
		_edit = deps.Edit,
		_say = deps.Say,
		_refresh = deps.Refresh,
		_stop = deps.Stop,
		_scope = deps.GetScope,
	}

	for _, part in workspace:GetDescendants() do
		if part:IsA("BasePart") and typeof(part:GetAttribute(ORIGINAL)) == "Color3" then
			self.On = true
			self._colored[part] = true
		end
	end

	if workspace:GetAttribute(ACTIVE) == true then
		self.On = true
	end

	trove:Connect(workspace.DescendantAdded, function(object)
		if not object:IsA("BasePart") then
			return
		end

		task.defer(function()
			if not RunService:IsEdit() or not object:IsDescendantOf(workspace) then
				return
			end

			local scope = self._scope()

			if self.On then
				if scope and object:IsDescendantOf(scope) and typeof(object:GetAttribute(ORIGINAL)) ~= "Color3" then
					apply(self, object)
				end
			else
				restore(object)
			end
		end)
	end)

	local function sync()
		self.On = workspace:GetAttribute(ACTIVE) == true

		if not self.On then
			for _, part in workspace:GetDescendants() do
				if part:IsA("BasePart") and typeof(part:GetAttribute(ORIGINAL)) == "Color3" then
					self.On = true
					break
				end
			end
		end

		self._refresh()
	end

	trove:Connect(ChangeHistoryService.OnUndo, sync)
	trove:Connect(ChangeHistoryService.OnRedo, sync)

	return self
end

--[=[
	Colors a part that was just built, now, so the color belongs to the same undo step as the part.

	@param self Colors
	@param part BasePart
]=]
function Colors.Adopt(self: Colors, part: BasePart)
	local scope = self._scope()

	if self.On and scope and part:IsDescendantOf(scope) and typeof(part:GetAttribute(ORIGINAL)) ~= "Color3" then
		apply(self, part)
	end
end

--[=[
	Turns the pastel colors on or off as one undoable edit.

	@param self Colors
	@param value boolean
]=]
function Colors.Set(self: Colors, value: boolean)
	local scope = self._scope()

	if value and not scope then
		return self._say("Pick a working folder first. Pastel colors only recolors Parts inside it.")
	end

	self._stop()

	local ok = self._edit(if value then "Show pastel colors" else "Restore original colors", function()
		if value then
			workspace:SetAttribute(ACTIVE, true)

			for _, part in (scope :: Instance):GetDescendants() do
				if part:IsA("BasePart") then
					apply(self, part)
				end
			end
		else
			for _, part in game:GetDescendants() do
				if part:IsA("BasePart") then
					restore(part)
				end
			end

			for part in self._colored do
				pcall(restore, part)
			end

			self._colored = {}
			workspace:SetAttribute(ACTIVE, nil)
		end
	end)

	if ok then
		self.On = value
		self._refresh()
		self._say(
			if value
				then "Pastel colors ON. Click again to restore originals. Your teammates see these colors too."
				else "Pastel colors OFF. Original colors restored."
		)
	end
end

--[=[
	Restores the original colors when the plugin unloads, as one undo step. A crash skips this;
	the saved attributes cover that case.

	@param self Colors
]=]
function Colors.RestoreOnUnload(self: Colors)
	if not RunService:IsEdit() or not self.On then
		return
	end

	local id = ChangeHistoryService:TryBeginRecording("VluxRestoreColors", "Restore original colors")

	if not id then
		return
	end

	local ok = pcall(function()
		for _, part in game:GetDescendants() do
			if part:IsA("BasePart") then
				restore(part)
			end
		end

		workspace:SetAttribute(ACTIVE, nil)
	end)

	ChangeHistoryService:FinishRecording(
		id,
		if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
	)
end

return Colors
