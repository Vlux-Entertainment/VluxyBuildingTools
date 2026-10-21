--!strict

--[=[
	Part specs and the selection helpers the tools share. A spec describes a Part to build; it
	becomes a real Part only when `Materialize` runs inside an undo recording.

	@class Geometry
]=]

local Selection = game:GetService("Selection")

local AxisLock = require("../Pure/AxisLock")

export type Spec = {
	size: Vector3,
	cf: CFrame,
	name: string,
	source: BasePart?,
	class: string,
}

local MAX_PART_SIZE = 2048
local ORIGINAL_COLOR = "VluxGreybox_OriginalColor_v1"
local COPIED_PROPERTIES = {
	"Color",
	"Material",
	"MaterialVariant",
	"Transparency",
	"Reflectance",
	"CanCollide",
	"CanTouch",
	"CanQuery",
	"CastShadow",
	"CollisionGroup",
	"Locked",
}

local scope: Instance? = nil

local Geometry = {}

--[=[
	Sets the working folder. Selection helpers only return things inside it, and new builds go in it.

	@param folder Instance? -- nil clears the scope
]=]
function Geometry.SetScope(folder: Instance?)
	scope = folder
end

--[=[
	@return Instance? -- the working folder, if one is set
]=]
function Geometry.GetScope(): Instance?
	return scope
end

--[=[
	@param object Instance
	@return boolean -- true when the working folder is set and holds the object
]=]
function Geometry.InScope(object: Instance): boolean
	return scope ~= nil and object:IsDescendantOf(scope)
end

--[[
	@param out { Spec } -- added to
	@param size Vector3
	@param cf CFrame
	@param name string?
	@param source BasePart? -- a Part whose look the new Part copies
	@param class string? -- "Part" unless given

	Adds a spec unless one side is flat. Throws when a side would pass Studio's size limit.
]]
function Geometry.Add(out: { Spec }, size: Vector3, cf: CFrame, name: string?, source: BasePart?, class: string?)
	if size.X > 0.001 and size.Y > 0.001 and size.Z > 0.001 then
		assert(
			math.max(size.X, size.Y, size.Z) <= MAX_PART_SIZE,
			"A generated Part exceeds Studio's 2048-stud size limit. Reduce dimensions."
		)
		table.insert(out, { size = size, cf = cf, name = name or "Block", source = source, class = class or "Part" })
	end
end

--[=[
	@param specs { Spec }
	@param title string -- the Model's name
	@return Model -- parented to Workspace and selected
]=]
function Geometry.Materialize(specs: { Spec }, title: string): Model
	local model = Instance.new("Model")
	model.Name = title
	model.Parent = scope or workspace

	for _, spec in specs do
		local part = Instance.new(spec.class) :: BasePart
		part.Name = spec.name
		part.Size = spec.size
		part.CFrame = spec.cf
		part.Anchored = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.fromRGB(163, 162, 165)

		local source = spec.source

		if source then
			local copyFrom = source :: any
			local copyTo = part :: any

			for _, key in COPIED_PROPERTIES do
				copyTo[key] = copyFrom[key]
			end

			-- Keep the intended color while the pastel toggle is showing.
			local original = source:GetAttribute(ORIGINAL_COLOR)

			if typeof(original) == "Color3" then
				part.Color = original
			end
		end

		part.Parent = model
	end

	Selection:Set({ model })

	return model
end

--[=[
	@param anywhere boolean? -- true to ignore the working folder
	@return { Instance } -- the selected Parts and Models in the working folder, leaving out any whose ancestor is also selected
]=]
function Geometry.SelectedRoots(anywhere: boolean?): { Instance }
	local all = Selection:Get()
	local result = {}

	for _, object in all do
		local allowed = object:IsDescendantOf(workspace) and (anywhere == true or Geometry.InScope(object))

		if (object:IsA("BasePart") or object:IsA("Model")) and allowed then
			local nested = false

			for _, other in all do
				if other ~= object and object:IsDescendantOf(other) then
					nested = true
					break
				end
			end

			if not nested then
				table.insert(result, object)
			end
		end
	end

	return result
end

--[=[
	@param roots { Instance }
	@return { BasePart } -- every Part in the roots and below them, once each
]=]
function Geometry.PartsOf(roots: { Instance }): { BasePart }
	local out: { BasePart } = {}
	local seen: { [Instance]: boolean } = {}

	for _, object in roots do
		if object:IsA("BasePart") and not seen[object] then
			table.insert(out, object)
			seen[object] = true
		end

		for _, part in object:GetDescendants() do
			if part:IsA("BasePart") and not seen[part] then
				table.insert(out, part)
				seen[part] = true
			end
		end
	end

	return out
end

--[=[
	@param parts { BasePart }
	@return CFrame -- the centre of the world-aligned box around the parts
	@return Vector3 -- that box's size
]=]
function Geometry.Bounds(parts: { BasePart }): (CFrame, Vector3)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low

	for _, part in parts do
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local corner = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)

					low = Vector3.new(math.min(low.X, corner.X), math.min(low.Y, corner.Y), math.min(low.Z, corner.Z))
					high =
						Vector3.new(math.max(high.X, corner.X), math.max(high.Y, corner.Y), math.max(high.Z, corner.Z))
				end
			end
		end
	end

	return CFrame.new((low + high) * 0.5), high - low
end

--[=[
	@param part Instance?
	@return boolean -- true for an ordinary block Part, not a mesh, union, wedge or ball
]=]
function Geometry.IsPlainBlock(part: Instance?): boolean
	return part ~= nil and part.ClassName == "Part" and (part :: Part).Shape == Enum.PartType.Block
end

--[=[
	@param v Vector3
	@return AxisLock.Vec
]=]
function Geometry.ToVec(v: Vector3): AxisLock.Vec
	return { X = v.X, Y = v.Y, Z = v.Z }
end

--[=[
	@param v AxisLock.Vec
	@return Vector3
]=]
function Geometry.FromVec(v: AxisLock.Vec): Vector3
	return Vector3.new(v.X, v.Y, v.Z)
end

return Geometry
