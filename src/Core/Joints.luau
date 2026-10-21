--!strict

--[=[
	Joins rooms, corridors and arched corridors where they meet: the cursor snaps to the walls of
	the ones already built, and each new one cuts openings through the walls it passes through, and
	has its own walls cut by the others. The structures are never merged into one union; only the
	walls get holes, made with subtraction.

	@class Joints
]=]

local Geometry = require("./Geometry")

local STRUCTURES: { [string]: boolean } = {
	Vlux_Room = true,
	Vlux_Corridor = true,
	Vlux_ArchedCorridor = true,
}
local SNAP_RADIUS = 3
local CUT_PARTS: { [string]: boolean } = {
	Wall_North = true,
	Wall_South = true,
	Wall_East = true,
	Wall_West = true,
	CorridorWall = true,
	Ceiling = true,
	ArchedCeiling = true,
	Ceiling_Left = true,
	Ceiling_Right = true,
}

type Cutter = { cf: CFrame, size: Vector3, cylinder: boolean }

local Joints = {}

--[[
	@return { Instance } -- the built structures in the working folder, or in Workspace without one
]]
local function structures(): { Instance }
	local out: { Instance } = {}

	for _, child in (Geometry.GetScope() or workspace):GetChildren() do
		if STRUCTURES[child.Name] then
			table.insert(out, child)
		end
	end

	return out
end

--[[
	@return { Cutter } -- the clear space of a freshly built structure, made a wall thickness longer at both ends so a cut goes all the way through a wall
]]
local function measure(model: Model): { Cutter }
	local cutters: { Cutter } = {}
	local floor = model:FindFirstChild("Floor")

	if not floor or not floor:IsA("BasePart") then
		return cutters
	end

	if model.Name == "Vlux_Room" then
		local north = model:FindFirstChild("Wall_North")

		if north and north:IsA("BasePart") then
			local t, h = north.Size.Z, north.Size.Y
			local base = north.Position.Y - h / 2
			local size = Vector3.new(floor.Size.X - 2 * t, h, floor.Size.Z - 2 * t)

			table.insert(cutters, {
				cf = CFrame.new(floor.Position.X, base + h / 2, floor.Position.Z),
				size = size,
				cylinder = false,
			})
		end

		return cutters
	end

	local wall = model:FindFirstChild("CorridorWall")

	if not wall or not wall:IsA("BasePart") then
		return cutters
	end

	local t, h = wall.Size.X, wall.Size.Y
	local length = floor.Size.Z
	local width = floor.Size.X - 2 * t
	local base = floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0)

	table.insert(cutters, {
		cf = base * CFrame.new(0, h / 2, 0),
		size = Vector3.new(width, h, length + 2 * t),
		cylinder = false,
	})

	if model.Name == "Vlux_ArchedCorridor" then
		table.insert(cutters, {
			cf = base * CFrame.new(0, h, 0) * CFrame.Angles(0, math.pi / 2, 0),
			size = Vector3.new(length + 2 * t, width, width),
			cylinder = true,
		})
	end

	return cutters
end

--[[
	@return { Cutter } -- the cutters stored on a structure when it was built
]]
local function stored(model: Instance): { Cutter }
	local out: { Cutter } = {}

	for index = 1, (model:GetAttribute("Cuts") :: number?) or 0 do
		local cf = model:GetAttribute("Cut" .. index .. "_CF")
		local size = model:GetAttribute("Cut" .. index .. "_Size")

		if typeof(cf) == "CFrame" and typeof(size) == "Vector3" then
			table.insert(
				out,
				{ cf = cf, size = size, cylinder = model:GetAttribute("Cut" .. index .. "_Cylinder") == true }
			)
		end
	end

	return out
end

--[[
	@return boolean -- whether the world-aligned boxes around the two oriented boxes overlap
]]
local function overlaps(cfA: CFrame, sizeA: Vector3, cfB: CFrame, sizeB: Vector3): boolean
	local function extent(cf: CFrame, size: Vector3): Vector3
		local half = size / 2
		local x, y, z = cf.RightVector, cf.UpVector, cf.LookVector

		return Vector3.new(
			math.abs(x.X) * half.X + math.abs(y.X) * half.Y + math.abs(z.X) * half.Z,
			math.abs(x.Y) * half.X + math.abs(y.Y) * half.Y + math.abs(z.Y) * half.Z,
			math.abs(x.Z) * half.X + math.abs(y.Z) * half.Y + math.abs(z.Z) * half.Z
		)
	end

	local reach = extent(cfA, sizeA) + extent(cfB, sizeB)
	local gap = cfA.Position - cfB.Position

	return math.abs(gap.X) < reach.X and math.abs(gap.Y) < reach.Y and math.abs(gap.Z) < reach.Z
end

--[[
	Replaces the part with a copy that has the cutters taken out of it. The part leaves the model
	with its Parent set to nil, not destroyed, so undo can bring it back.
]]
local function carve(part: BasePart, cutters: { Cutter })
	local tools: { BasePart } = {}

	for _, cutter in cutters do
		if overlaps(part.CFrame, part.Size, cutter.cf, cutter.size) then
			local tool = Instance.new("Part")

			tool.Shape = if cutter.cylinder then Enum.PartType.Cylinder else Enum.PartType.Block
			tool.Size = cutter.size
			tool.CFrame = cutter.cf
			table.insert(tools, tool)
		end
	end

	if #tools == 0 then
		return
	end

	local ok, result = pcall(function()
		return part:SubtractAsync(tools)
	end)

	for _, tool in tools do
		tool:Destroy()
	end

	if not ok or not result then
		return
	end

	local holder = part.Parent

	result.Name = part.Name
	result.Anchored = true
	result.Parent = holder
	part.Parent = nil
end

--[[
	@param model Instance
	@param cutters { Cutter }

	Cuts every cuttable wall in the model that the cutters pass through.
]]
local function carveModel(model: Instance, cutters: { Cutter })
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and CUT_PARTS[child.Name] then
			carve(child, cutters)
		end
	end
end

--[=[
	Remembers the clear space of a freshly built structure on the model, and cuts openings between
	it and the structures already built. Call it inside the undo recording, right after the build.

	@param model Model -- a Vlux_Room, Vlux_Corridor or Vlux_ArchedCorridor
]=]
function Joints.Connect(model: Model)
	local mine = measure(model)

	for index, cutter in mine do
		model:SetAttribute("Cut" .. index .. "_CF", cutter.cf)
		model:SetAttribute("Cut" .. index .. "_Size", cutter.size)
		model:SetAttribute("Cut" .. index .. "_Cylinder", cutter.cylinder)
	end

	model:SetAttribute("Cuts", #mine)

	if #mine == 0 then
		return
	end

	for _, other in structures() do
		if other ~= model then
			local theirs = stored(other)

			carveModel(other, mine)
			carveModel(model, theirs)
		end
	end
end

--[=[
	Moves a point to the nearest wall of a built room or corridor within a few studs. Only the
	directions it had to move change, so along the wall it keeps its own snapped value.

	@param point Vector3 -- the already grid-snapped point
	@return Vector3
]=]
function Joints.Snap(point: Vector3): Vector3
	local best: Vector3? = nil
	local bestDistance = SNAP_RADIUS

	for _, model in structures() do
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") and CUT_PARTS[part.Name] and part.Name ~= "Ceiling" then
				local relative = part.CFrame:PointToObjectSpace(point)
				local half = part.Size / 2
				local nearest = Vector3.new(
					math.clamp(relative.X, -half.X, half.X),
					relative.Y,
					math.clamp(relative.Z, -half.Z, half.Z)
				)
				local world = part.CFrame:PointToWorldSpace(nearest)
				local distance = Vector3.new(world.X - point.X, 0, world.Z - point.Z).Magnitude

				if distance < bestDistance then
					bestDistance, best = distance, world
				end
			end
		end
	end

	if not best then
		return point
	end

	local x = if math.abs(best.X - point.X) > 0.001 then best.X else point.X
	local z = if math.abs(best.Z - point.Z) > 0.001 then best.Z else point.Z

	return Vector3.new(x, point.Y, z)
end

return Joints
