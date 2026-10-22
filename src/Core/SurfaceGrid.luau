--!strict

--[=[
	The surface grid. It puts a grid Texture on every face of the Parts in the working folder, so the
	grid shows in the viewport and in play. Each Texture has a fixed name, and a flag on Workspace
	remembers that the grid is on, so the grid can be switched off later even after Studio was closed
	and reopened, and it stays until you do.

	@class SurfaceGrid
]=]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

local Trove = require("../Packages/Trove")

export type SurfaceGrid = {
	On: boolean,
	_edit: (string, () -> ()) -> boolean,
	_remember: ((boolean) -> ())?,
	_say: (string) -> (),
	_refresh: () -> (),
	_stop: () -> (),
	_scope: () -> Instance?,
	_size: () -> number,
	_color: () -> Color3,
	_switching: boolean,
}

local TEXTURE_NAME = "VluxGridTexture"
local ACTIVE = "VluxGrid_Enabled_v1"
local ASSET = "rbxassetid://123614831873662"
local FACES = {
	Enum.NormalId.Top,
	Enum.NormalId.Bottom,
	Enum.NormalId.Left,
	Enum.NormalId.Right,
	Enum.NormalId.Front,
	Enum.NormalId.Back,
}

local SurfaceGrid = {}

--[[
	@param object Instance

	@return boolean -- true for the kinds of Part a Texture draws on, unions included
]]
local function eligible(object: Instance): boolean
	return object:IsA("Part")
		or object:IsA("WedgePart")
		or object:IsA("CornerWedgePart")
		or object:IsA("UnionOperation")
end

--[[
	@param part BasePart
	@param studs number -- the size of one grid tile

	Gives each face of the part a grid Texture, reusing any it already has.
]]
local function apply(part: BasePart, studs: number, color: Color3)
	for _, face in FACES do
		local texture: Texture? = nil

		for _, child in part:GetChildren() do
			if child:IsA("Texture") and child.Name == TEXTURE_NAME and child.Face == face then
				texture = child

				break
			end
		end

		local grid = texture or Instance.new("Texture")

		grid.Name = TEXTURE_NAME
		grid.Face = face
		grid.Texture = ASSET
		grid.StudsPerTileU = studs
		grid.StudsPerTileV = studs
		grid.Color3 = color
		grid.LocalTransparencyModifier = part.LocalTransparencyModifier
		grid.Parent = part
	end
end

--[[
	@param part Instance

	Removes the grid Textures from a part.
]]
local function strip(part: Instance)
	for _, child in part:GetChildren() do
		if child:IsA("Texture") and child.Name == TEXTURE_NAME then
			child:Destroy()
		end
	end
end

--[=[
	Builds the grid and wires it to Workspace so new Parts follow the switch and undo re-reads it.

	@param deps { Edit: (string, () -> ()) -> boolean, Say: (string) -> (), Refresh: () -> (), Stop: () -> (), GetScope: () -> Instance?, GetSize: () -> number }
	@param trove Trove -- holds the connections
	@return SurfaceGrid
]=]
function SurfaceGrid.new(
	deps: {
		Edit: (string, () -> ()) -> boolean,
		Say: (string) -> (),
		Refresh: () -> (),
		Stop: () -> (),
		GetScope: () -> Instance?,
		GetSize: () -> number,
		GetColor: () -> Color3,
		Remember: ((boolean) -> ())?,
	},
	trove: Trove.Trove
): SurfaceGrid
	local self: SurfaceGrid = {
		On = workspace:GetAttribute(ACTIVE) == true,
		_edit = deps.Edit,
		_remember = deps.Remember,
		_say = deps.Say,
		_refresh = deps.Refresh,
		_stop = deps.Stop,
		_scope = deps.GetScope,
		_size = deps.GetSize,
		_color = deps.GetColor,
		_switching = false,
	}

	if not self.On then
		for _, object in workspace:GetDescendants() do
			if object:IsA("Texture") and object.Name == TEXTURE_NAME then
				self.On = true

				break
			end
		end
	end

	trove:Connect(workspace.DescendantAdded, function(object)
		if not object:IsA("BasePart") or not eligible(object) then
			return
		end

		task.defer(function()
			if not RunService:IsEdit() or not object:IsDescendantOf(workspace) then
				return
			end

			local scope = self._scope()

			if workspace:GetAttribute(ACTIVE) == true then
				if scope and object:IsDescendantOf(scope) and not object:FindFirstChild(TEXTURE_NAME) then
					apply(object, self._size(), self._color())
				end
			else
				strip(object)
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
	Puts the grid on the parts an edit added or changed, so a part made by a cut, a union, a copy
	or any other path is never left plain and the grid belongs to the same undo step. With no list
	it goes through the whole working folder, which is only done when a folder is picked.

	@param self SurfaceGrid
	@param parts { BasePart }? -- the parts to grid; nil for every part in the working folder
]=]
function SurfaceGrid.Sweep(self: SurfaceGrid, parts: { BasePart }?)
	local scope = self._scope()

	if workspace:GetAttribute(ACTIVE) ~= true or self._switching or not scope then
		return
	end

	if parts then
		for _, part in parts do
			if eligible(part) and part:IsDescendantOf(scope) then
				apply(part, self._size(), self._color())
			end
		end

		return
	end

	for _, object in scope:GetDescendants() do
		if object:IsA("BasePart") and eligible(object) and not object:FindFirstChild(TEXTURE_NAME) then
			apply(object, self._size(), self._color())
		end
	end
end

--[=[
	Turns the grid on or off as one undoable edit. Off removes every grid Texture in Workspace, not
	only the working folder's, so nothing is left behind.

	@param self SurfaceGrid
	@param value boolean
]=]
function SurfaceGrid.Set(self: SurfaceGrid, value: boolean)
	local scope = self._scope()

	if value and not scope then
		return self._say("Pick a working folder first. The surface grid only goes on Parts inside it.")
	end

	self._stop()
	self._switching = true

	local ok = self._edit(if value then "Show surface grid" else "Remove surface grid", function()
		if value then
			workspace:SetAttribute(ACTIVE, true)

			for _, object in (scope :: Instance):GetDescendants() do
				if object:IsA("BasePart") and eligible(object) then
					apply(object, self._size(), self._color())
				end
			end
		else
			for _, object in workspace:GetDescendants() do
				if object:IsA("Texture") and object.Name == TEXTURE_NAME then
					object:Destroy()
				end
			end

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
				then "Surface grid ON. The grid is on the Parts in your folder. It stays until you switch it off, even if you close Studio."
				else "Surface grid OFF. The grid Textures are removed."
		)
	end
end

--[=[
	Tints every grid Texture already placed with the grid colour.

	@param self SurfaceGrid
]=]
function SurfaceGrid.Recolor(self: SurfaceGrid)
	if not self.On then
		return
	end

	local color = self._color()

	self._edit("Color surface grid", function()
		for _, object in workspace:GetDescendants() do
			if object:IsA("Texture") and object.Name == TEXTURE_NAME then
				object.Color3 = color
			end
		end
	end)
end

--[=[
	Re-sizes the tiles of every grid Texture already placed.

	@param self SurfaceGrid
]=]
function SurfaceGrid.Resize(self: SurfaceGrid)
	if not self.On then
		return
	end

	local studs = self._size()

	self._edit("Resize surface grid", function()
		for _, object in workspace:GetDescendants() do
			if object:IsA("Texture") and object.Name == TEXTURE_NAME then
				object.StudsPerTileU = studs
				object.StudsPerTileV = studs
			end
		end
	end)
end

--[=[
	Reads a six digit hex string such as "FF8A24" into a colour, white when it is not one.

	@param hex string
	@return Color3
]=]
function SurfaceGrid.ColorOf(hex: string): Color3
	local digits = string.match(hex, "^#?(%x%x%x%x%x%x)$")

	if not digits then
		return Color3.new(1, 1, 1)
	end

	local value = tonumber(digits, 16) :: number

	return Color3.fromRGB(bit32.rshift(value, 16), bit32.band(bit32.rshift(value, 8), 255), bit32.band(value, 255))
end

return SurfaceGrid
