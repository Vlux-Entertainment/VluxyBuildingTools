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
	shape: string?,
	transparency: number?,
	collide: boolean?,
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
			"A part would pass Studio's 2048-stud limit; make it smaller."
		)
		table.insert(out, { size = size, cf = cf, name = name or "Block", source = source, class = class or "Part" })
	end
end

--[=[
	@param specs { Spec }
	@param title string -- the Model's name
	@return Model -- parented to the working folder or Workspace, and left unselected so hotkeys keep working
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

		if spec.shape == "Cylinder" then
			(part :: Part).Shape = Enum.PartType.Cylinder
		elseif spec.shape == "Ball" then
			(part :: Part).Shape = Enum.PartType.Ball
		end

		if spec.name == "Door_Panel" then
			part.Transparency = spec.transparency or 0.5
			part.CanCollide = spec.collide == true
			part.CanTouch = spec.collide == true
		end

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

	return model
end

--[=[
	Like Materialize, but a build of a single piece goes straight into the folder as a Part, with no
	Model around it. Builds of several pieces still get a Model.

	@param specs { Spec }
	@param title string -- the Model's name, or the Part's when there is only one piece
	@return Instance -- the Part, or the Model holding the pieces
]=]
function Geometry.Place(specs: { Spec }, title: string): Instance
	local model = Geometry.Materialize(specs, title)
	local parts = model:GetChildren()

	if #parts ~= 1 then
		return model
	end

	local part = parts[1]

	part.Name = title
	part.Parent = model.Parent
	model:Destroy()

	return part
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
	Joins the curved pieces of a built arch into two crescents, a left half and a right half. The posts
	that stand below the curve are left as they are. The joined pieces are taken out of the model with
	their Parent set to nil, not destroyed, so undo can bring them back.

	@param model Model -- the model an arch was built into
	@return string? -- why it could not join the pieces, or nil when it did
]=]
function Geometry.UnionArchHalves(model: Model): string?
	local posts: { BasePart } = {}
	local curves: { BasePart } = {}

	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			if child.Name == "Arch_Post" then
				table.insert(posts, child)
			elseif child.Name == "Arch_Curve" then
				table.insert(curves, child)
			end
		end
	end

	if #posts ~= 2 or #curves < 2 then
		return "This arch has too few pieces to join."
	end

	local center = (posts[1].Position + posts[2].Position) * 0.5
	local across = (posts[2].Position - posts[1].Position)

	if across.Magnitude < 0.001 then
		return "This arch has no width to split."
	end

	across = across.Unit

	local halves: { [string]: { BasePart } } = { Arch_Left = {}, Arch_Right = {} }

	for _, curve in curves do
		local side = if (curve.Position - center):Dot(across) < 0 then "Arch_Left" else "Arch_Right"

		table.insert(halves[side], curve)
	end

	local failed: string? = nil

	for name, group in halves do
		if #group >= 2 then
			local base = group[1]
			local rest = table.clone(group)

			table.remove(rest, 1)

			local ok, result = pcall(function()
				return base:UnionAsync(rest)
			end)

			if ok and result then
				result.Name = name
				result.Anchored = true
				result.Parent = model

				for _, piece in group do
					piece.Parent = nil
				end
			else
				failed = "Roblox could not join the arch pieces: " .. tostring(result)
			end
		end
	end

	return failed
end

--[=[
	Joins the curved pieces of a built arch into a left and a right half, for arches that have no
	posts to split by. The two pieces farthest apart sideways give the centre and the span, and the
	joined pieces leave the model with their Parent set to nil so undo can bring them back.

	@param model Model
	@param pieceName string -- the name shared by the curved pieces
	@param prefix string -- the halves are named prefix .. "_Left" and prefix .. "_Right"
	@return string? -- why it could not join them, or nil when it did
]=]
function Geometry.UnionSides(model: Model, pieceName: string, prefix: string): string?
	local curves: { BasePart } = {}

	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name == pieceName then
			table.insert(curves, child)
		end
	end

	if #curves < 2 then
		return nil
	end

	local first, last = curves[1], curves[1]
	local widest = -1

	for _, a in curves do
		for _, b in curves do
			local flat = Vector3.new(a.Position.X - b.Position.X, 0, a.Position.Z - b.Position.Z).Magnitude

			if flat > widest then
				widest, first, last = flat, a, b
			end
		end
	end

	if widest < 0.001 then
		return nil
	end

	local center = (first.Position + last.Position) * 0.5
	local across = Vector3.new(last.Position.X - first.Position.X, 0, last.Position.Z - first.Position.Z).Unit
	local halves: { [string]: { BasePart } } = { [prefix .. "_Left"] = {}, [prefix .. "_Right"] = {} }

	for _, curve in curves do
		local side = if (curve.Position - center):Dot(across) < 0 then "_Left" else "_Right"

		table.insert(halves[prefix .. side], curve)
	end

	local failed: string? = nil

	for name, group in halves do
		if #group >= 2 then
			local base = group[1]
			local rest = table.clone(group)

			table.remove(rest, 1)

			local ok, result = pcall(function()
				return base:UnionAsync(rest)
			end)

			if ok and result then
				result.Name = name
				result.Anchored = true
				result.Parent = model

				for _, piece in group do
					piece.Parent = nil
				end
			else
				failed = "Roblox could not join the arch pieces: " .. tostring(result)
			end
		end
	end

	return failed
end

--[=[
	Joins every piece of the model with the given name into one union, named `result`. The joined
	pieces leave the model with their Parent set to nil so undo can bring them back.

	@param model Model
	@param pieceName string
	@param result string
	@return string? -- why it could not join them, or nil when it did
]=]
function Geometry.UnionNamed(model: Model, pieceName: string, result: string): string?
	local group: { BasePart } = {}

	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name == pieceName then
			table.insert(group, child)
		end
	end

	if #group < 2 then
		for _, piece in group do
			piece.Name = result
		end

		return nil
	end

	local rest = table.clone(group)

	table.remove(rest, 1)

	local ok, joined = pcall(function()
		return group[1]:UnionAsync(rest)
	end)

	if not ok or not joined then
		return "Roblox could not join the circle frame: " .. tostring(joined)
	end

	joined.Name = result
	joined.Anchored = true
	joined.Parent = model

	for _, piece in group do
		piece.Parent = nil
	end

	return nil
end

--[=[
	Joins every Part in a built model into one union, such as the steps and landing of a stair. The
	joined pieces leave the model with their Parent set to nil, not destroyed, so undo can bring them
	back.

	@param model Model
	@param name string -- the name of the union
	@return string? -- why it could not join the pieces, or nil when it did
]=]
function Geometry.UnionAll(model: Model, name: string): string?
	local pieces: { BasePart } = {}

	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(pieces, child)
		end
	end

	if #pieces < 2 then
		return nil
	end

	local base = pieces[1]
	local rest = table.clone(pieces)

	table.remove(rest, 1)

	local ok, result = pcall(function()
		return base:UnionAsync(rest)
	end)

	if not ok or not result then
		return "Roblox could not join the pieces: " .. tostring(result)
	end

	result.Name = name
	result.Anchored = true
	result.Parent = model

	for _, piece in pieces do
		piece.Parent = nil
	end

	return nil
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

--[=[
	Joins the specs into one solid, cuts a box out of it and parents the result to the model. The
	pieces it started from never enter the model, so undo only has the result to remove.

	@param model Model
	@param specs { Spec }
	@param cutter CFrame -- where the box that is cut away sits
	@param cutterSize Vector3
	@param name string
	@return boolean -- false when nothing was left or the cut failed
]=]
function Geometry.AddCut(model: Model, specs: { Spec }, cutter: CFrame, cutterSize: Vector3, name: string): boolean
	local holder = Geometry.Materialize(specs, "Vlux_Temp")
	local parts: { BasePart } = {}

	for _, child in holder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end

	if #parts == 0 then
		holder:Destroy()

		return false
	end

	local tool = Instance.new("Part")

	tool.Size = cutterSize
	tool.CFrame = cutter
	tool.Anchored = true

	local ok, result = pcall(function()
		local base = parts[1]
		local rest = table.clone(parts)

		table.remove(rest, 1)

		local joined = if #rest > 0 then base:UnionAsync(rest) else base

		return joined:SubtractAsync({ tool })
	end)

	if not ok or not result then
		-- The joined cut failed, so cut each piece on its own, then join what is left into one piece.
		local kept: { BasePart } = {}

		for _, piece in parts do
			local cutOk, cut = pcall(function()
				return piece:SubtractAsync({ tool })
			end)

			if cutOk and cut then
				cut.Anchored = true
				cut.Parent = model
				table.insert(kept, cut)
			end
		end

		tool:Destroy()
		holder:Destroy()

		if #kept > 1 then
			local rest = table.clone(kept)

			table.remove(rest, 1)

			local joinOk, joined = pcall(function()
				return kept[1]:UnionAsync(rest)
			end)

			if joinOk and joined then
				joined.Name = name
				joined.Anchored = true
				joined.Parent = model

				for _, piece in kept do
					piece:Destroy()
				end

				return true
			end
		end

		for _, piece in kept do
			piece.Name = name
		end

		return #kept > 0
	end

	tool:Destroy()
	holder:Destroy()

	result.Name = name
	result.Anchored = true
	result.Parent = model

	return true
end

return Geometry
