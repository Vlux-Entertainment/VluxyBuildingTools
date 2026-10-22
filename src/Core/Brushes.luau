--!strict

--[=[
	The brush list. Each brush is a copy of something the user selected, kept in a folder in
	ServerStorage so it stays with the place. A brush can be switched off without being removed.

	@class Brushes
]=]

local Geometry = require("./Geometry")
local ServerStorage = game:GetService("ServerStorage")

local FOLDER = "VluxyBT_Brushes"
local ENABLED = "VluxyBT_BrushOn"

local Brushes = {}

--[[
	@param create boolean -- make the folder when it is missing
	@return Folder?
]]
local function folder(create: boolean): Folder?
	local found = ServerStorage:FindFirstChild(FOLDER)

	if found and found:IsA("Folder") then
		return found
	end

	if not create then
		return nil
	end

	local made = Instance.new("Folder")

	made.Name = FOLDER
	made.Parent = ServerStorage

	return made
end

--[=[
	@return { Instance } -- every brush, in the order they were added
]=]
function Brushes.List(): { Instance }
	local holder = folder(false)

	return if holder then holder:GetChildren() else {}
end

--[=[
	@param entry Instance
	@return boolean -- whether the brush is switched on
]=]
function Brushes.IsOn(entry: Instance): boolean
	return entry:GetAttribute(ENABLED) ~= false
end

--[=[
	@return { Instance } -- the brushes that are switched on
]=]
function Brushes.Enabled(): { Instance }
	local out: { Instance } = {}

	for _, entry in Brushes.List() do
		if Brushes.IsOn(entry) then
			table.insert(out, entry)
		end
	end

	return out
end

--[=[
	@param entry Instance
]=]
function Brushes.Toggle(entry: Instance)
	entry:SetAttribute(ENABLED, not Brushes.IsOn(entry))
end

--[=[
	@param entry Instance
]=]
function Brushes.Remove(entry: Instance)
	entry:Destroy()
end

--[=[
	Copies the selected objects into the brush list as one brush.

	@return number -- 1 when a brush was added, else 0
	@return string -- what to tell the user
]=]
function Brushes.AddSelected(): (number, string)
	local roots = Geometry.SelectedRoots(true)

	if #roots == 0 then
		return 0, "Select the object you want to paint with first, then add it."
	end

	for _, root in roots do
		if not root.Archivable then
			return 0, "Enable Archivable on the selected object first."
		end
	end

	local entry: Instance

	if #roots == 1 then
		entry = roots[1]:Clone() :: Instance
	else
		local group = Instance.new("Model")

		group.Name = roots[1].Name .. " group"

		for _, root in roots do
			local copy = root:Clone()

			if copy then
				copy.Parent = group
			end
		end

		entry = group
	end

	entry:SetAttribute(ENABLED, true)
	entry.Parent = folder(true)

	return 1, `Added {entry.Name} to the brushes.`
end

return Brushes
