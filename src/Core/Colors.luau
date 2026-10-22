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
	_remember: ((boolean) -> ())?,
	_say: (string) -> (),
	_refresh: () -> (),
	_stop: () -> (),
	_scope: () -> Instance?,
	_theme: () -> string,
	_switching: boolean,
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

local ORANGE = Color3.fromRGB(255, 138, 36)
local ORANGE_DARK = Color3.fromRGB(214, 108, 20)
local GREY = Color3.fromRGB(52, 54, 60)
local GREY_LIGHT = Color3.fromRGB(80, 83, 90)
local PURPLE = Color3.fromRGB(150, 110, 205)

local Colors = {}

--[=[
	The color themes that can be picked.

	@prop Themes { string }
	@within Colors
]=]
Colors.Themes = { "Pastel", "Unity" }

--[[
	@param name string -- a part's name
	@param words { string }
	@return boolean -- whether the lowercase name contains any of the words
]]
local function named(name: string, words: { string }): boolean
	local lower = string.lower(name)

	for _, word in words do
		if string.find(lower, word, 1, true) then
			return true
		end
	end

	return false
end

--[[
	@param part BasePart
	@return Color3 -- dark grey for a part whose longest side is at least about 6.5 times its thinnest or that cannot be judged, orange for anything chunkier or shorter than 2 studs
]]
local function shapeColor(part: BasePart): Color3
	local size = part.Size
	local volume = size.X * size.Y * size.Z

	if volume ~= volume or volume == math.huge or math.min(size.X, size.Y, size.Z) <= 0 then
		return GREY
	end

	local thinnest = math.min(size.X, size.Y, size.Z)
	local longest = math.max(size.X, size.Y, size.Z)

	if longest < 2 then
		return ORANGE
	end

	return if longest >= thinnest * 6.5 then GREY else ORANGE
end

--[[
	@param part BasePart
	@return Color3 -- the Unity theme color: shape decides it, a prop's accent parts take the opposite color so they stand out, ceilings and roofs are lighter grey, vents have their own colors
]]
local function unityColor(part: BasePart): Color3
	local name = part.Name

	if named(name, { "prop" }) then
		local base = shapeColor(part)

		if named(name, { "propaccent" }) then
			return if base == ORANGE then GREY else ORANGE
		end

		return base
	elseif named(name, { "ventwall" }) then
		return GREY
	elseif named(name, { "ventceiling" }) then
		return GREY_LIGHT
	elseif named(name, { "vent" }) then
		return if named(name, { "floor", "duct" }) then ORANGE_DARK else ORANGE
	elseif named(name, { "ceiling", "roof", "arched" }) then
		return GREY_LIGHT
	end

	return shapeColor(part)
end

--[[
	@param color Color3
	@return boolean -- whether the color is one the Unity theme paints with
]]
local function isUnityColor(color: Color3): boolean
	return color == ORANGE or color == ORANGE_DARK or color == GREY or color == GREY_LIGHT
end

--[[
	@param self Colors
	@param part BasePart
	@return Color3 -- the color the current theme gives the part; a part that is partly see-through is purple in every theme
]]
local function themed(self: Colors, part: BasePart): Color3
	if part.Transparency > 0.001 and part.Transparency < 0.999 then
		return PURPLE
	end

	if self._theme() == "Unity" then
		return unityColor(part)
	end

	local holder = part.Parent

	if holder and holder:IsA("Model") and holder:GetAttribute("VluxyBT_Prop") ~= nil then
		local index = holder:GetAttribute("VluxyBT_PropColor")

		if type(index) ~= "number" then
			index = self._random:NextInteger(1, #PALETTE)
			holder:SetAttribute("VluxyBT_PropColor", index)
		end

		return PALETTE[index :: number]
	end

	return PALETTE[self._random:NextInteger(1, #PALETTE)]
end

--[[
	@param part BasePart

	Gives the part a themed color, saving its original color first.
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

	part.Color = themed(self, part)
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
		Remember: ((boolean) -> ())?,
		GetTheme: () -> string,
	},
	trove: Trove.Trove
): Colors
	local self: Colors = {
		On = false,
		_colored = {},
		_random = Random.new(),
		_edit = deps.Edit,
		_remember = deps.Remember,
		_say = deps.Say,
		_refresh = deps.Refresh,
		_stop = deps.Stop,
		_scope = deps.GetScope,
		_theme = deps.GetTheme,
		_switching = false,
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

			if workspace:GetAttribute(ACTIVE) == true then
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
		self._refresh()
	end

	trove:Connect(ChangeHistoryService.OnUndo, sync)
	trove:Connect(ChangeHistoryService.OnRedo, sync)
	trove:Connect(workspace:GetAttributeChangedSignal(ACTIVE), sync)

	return self
end

--[=[
	@param self Colors
	@param part BasePart
	@return Color3 -- the color a part would get under the theme picked now, without changing anything; used to draw prop pictures
]=]
function Colors.Preview(self: Colors, part: BasePart): Color3
	return themed(self, part)
end

--[=[
	Colors a part that was just built, now, so the color belongs to the same undo step as the part.

	@param self Colors
	@param part BasePart
]=]
function Colors.Adopt(self: Colors, part: BasePart)
	local scope = self._scope()

	if
		workspace:GetAttribute(ACTIVE) == true
		and scope
		and part:IsDescendantOf(scope)
		and typeof(part:GetAttribute(ORIGINAL)) ~= "Color3"
	then
		apply(self, part)
	end
end

--[=[
	Gives every part in the working folder that missed its color one, so a part made by a cut, a
	union or any other path is never left plain. It runs at the end of each plugin edit.

	@param self Colors
]=]
function Colors.Sweep(self: Colors)
	local scope = self._scope()

	if workspace:GetAttribute(ACTIVE) ~= true or self._switching or not scope then
		return
	end

	local unity = self._theme() == "Unity"

	for _, part in scope:GetDescendants() do
		if part:IsA("BasePart") then
			if typeof(part:GetAttribute(ORIGINAL)) ~= "Color3" then
				apply(self, part)
			elseif unity then
				local want = themed(self, part)

				if part.Color ~= want then
					part.Color = want
				end
			elseif isUnityColor(part.Color) then
				part.Color = themed(self, part)
			end
		end
	end
end

--[=[
	Repaints every part that already has a theme color with the theme now picked, as one undo step.

	@param self Colors
]=]
function Colors.Retheme(self: Colors)
	local scope = self._scope()

	if not self.On or not scope then
		return
	end

	self._edit("Change color theme", function()
		for _, part in scope:GetDescendants() do
			if part:IsA("BasePart") and typeof(part:GetAttribute(ORIGINAL)) == "Color3" then
				part.Color = themed(self, part)
			end
		end
	end)
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
	self._switching = true

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

	self._switching = false

	if ok then
		self.On = value

		if self._remember then
			self._remember(value)
		end

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
