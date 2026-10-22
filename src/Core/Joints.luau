--!strict

--[=[
	Joins rooms, corridors and arched corridors where they meet: the cursor snaps to the walls of
	the ones already built, and each new one cuts openings through the walls it passes through, and
	has its own walls cut by the others. The structures are never merged into one union; only the
	walls get holes, made with subtraction.

	@class Joints
]=]

local Geometry = require("./Geometry")

--[[ How many studs past a structure's space another structure's parts may sit and still be found: more than any wall is thick. ]]
local NEAR = 4
local STRUCTURES: { [string]: boolean } = {
	Vlux_Room = true,
	Vlux_Corridor = true,
	Vlux_ArchedCorridor = true,
}
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

type Cutter = { cf: CFrame, size: Vector3, cylinder: boolean, thickness: number? }

local PREFIX = "VluxyBT_"

--[[
	@return any -- the attribute under the plugin's prefix, else under the name older builds saved it as
]]
local function attribute(model: Instance, name: string): any
	local value = model:GetAttribute(PREFIX .. name)

	if value == nil then
		value = model:GetAttribute(name)
	end

	return value
end

local Joints = {}

--[[
	@param boxes { { cf: CFrame, size: Vector3 } } -- the space to look around
	@param margin number -- how many studs past the boxes still count
	@return { Instance } -- the built structures in the working folder (or Workspace without one) with a part in or near the boxes

	Asks the physics index for the parts nearby instead of going through the whole folder, so the
	cost does not grow with the size of the map. A structure that touches none of the space cannot
	be cut by it or cut into it.
]]
local function structuresNear(boxes: { { cf: CFrame, size: Vector3 } }, margin: number): { Instance }
	local out: { Instance } = {}

	if #boxes == 0 then
		return out
	end

	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low

	for _, box in boxes do
		local boxLow, boxHigh = Geometry.BoxOf(box.cf, box.size)

		low, high = low:Min(boxLow), high:Max(boxHigh)
	end

	low -= Vector3.one * margin
	high += Vector3.one * margin

	local holder = Geometry.GetScope() or workspace
	local params = OverlapParams.new()
	local seen: { [Instance]: boolean } = {}

	if holder ~= workspace then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { holder }
	end

	for _, part in workspace:GetPartBoundsInBox(CFrame.new((low + high) * 0.5), high - low, params) do
		local model = part.Parent

		if model and not seen[model] and model.Parent == holder and STRUCTURES[model.Name] then
			seen[model] = true
			table.insert(out, model)
		end
	end

	return out
end

--[[
	@param model Instance
	@return { { cf: CFrame, size: Vector3 } } -- the boxes of the model's own parts
]]
local function partBoxes(model: Instance): { { cf: CFrame, size: Vector3 } }
	local out: { { cf: CFrame, size: Vector3 } } = {}

	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(out, { cf = child.CFrame, size = child.Size })
		end
	end

	return out
end

--[[
	@param name string -- Vlux_Room, Vlux_Corridor or Vlux_ArchedCorridor
	@param find (string) -> (CFrame, Vector3)? -- the CFrame and size of the part with that name
	@return { Cutter } -- the clear space of a structure, made a wall thickness longer at both ends so a cut goes all the way through a wall
]]
local function measureWith(name: string, find: (string) -> (CFrame?, Vector3?)): { Cutter }
	local cutters: { Cutter } = {}
	local floorCF, floorSize = find("Floor")

	if not floorCF or not floorSize then
		return cutters
	end

	if name == "Vlux_Room" then
		local northCF, northSize = find("Wall_North")

		if northCF and northSize then
			local t, h = northSize.Z, northSize.Y
			local base = northCF.Position.Y - h / 2

			table.insert(cutters, {
				cf = CFrame.new(floorCF.Position.X, base + h / 2, floorCF.Position.Z),
				size = Vector3.new(floorSize.X - 2 * t, h, floorSize.Z - 2 * t),
				cylinder = false,
				thickness = t,
			})
		end

		return cutters
	end

	local _, wallSize = find("CorridorWall")

	if not wallSize then
		return cutters
	end

	local t, h = wallSize.X, wallSize.Y
	local length = floorSize.Z
	local width = floorSize.X - 2 * t
	local base = floorCF * CFrame.new(0, floorSize.Y / 2, 0)

	table.insert(cutters, {
		cf = base * CFrame.new(0, h / 2, 0),
		size = Vector3.new(width, h, length + 2 * t),
		cylinder = false,
	})

	if name == "Vlux_ArchedCorridor" then
		table.insert(cutters, {
			cf = base * CFrame.new(0, h, 0) * CFrame.Angles(0, math.pi / 2, 0),
			size = Vector3.new(length + 2 * t, width, width),
			cylinder = true,
		})
	end

	return cutters
end

--[[
	@return { Cutter } -- the clear space of a freshly built structure
]]
local function measure(model: Model): { Cutter }
	return measureWith(model.Name, function(partName)
		local part = model:FindFirstChild(partName)

		if part and part:IsA("BasePart") then
			return part.CFrame, part.Size
		end

		return nil, nil
	end)
end

--[[
	@return { Cutter } -- the cutters stored on a structure when it was built
]]
local function stored(model: Instance): { Cutter }
	local out: { Cutter } = {}

	for index = 1, (attribute(model, "Cuts") :: number?) or 0 do
		local cf = attribute(model, "Cut" .. index .. "_CF")
		local size = attribute(model, "Cut" .. index .. "_Size")

		if typeof(cf) == "CFrame" and typeof(size) == "Vector3" then
			local wall = attribute(model, "Cut" .. index .. "_Thickness")

			table.insert(out, {
				cf = cf,
				size = size,
				cylinder = attribute(model, "Cut" .. index .. "_Cylinder") == true,
				thickness = if type(wall) == "number" then wall else nil,
			})
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
	@return boolean -- whether the cutter's box contains every corner of the part
]]
local function swallows(cutter: Cutter, part: BasePart): boolean
	local half = cutter.size / 2 + Vector3.new(0.02, 0.02, 0.02)
	local reach = part.Size / 2

	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = cutter.cf:PointToObjectSpace(
					part.CFrame:PointToWorldSpace(Vector3.new(sx * reach.X, sy * reach.Y, sz * reach.Z))
				)

				if math.abs(corner.X) > half.X or math.abs(corner.Y) > half.Y or math.abs(corner.Z) > half.Z then
					return false
				end
			end
		end
	end

	return true
end

--[[
	Replaces the part with a copy that has the cutters taken out of it. The part leaves the model
	with its Parent set to nil, not destroyed, so undo can bring it back.
]]
local function carve(part: BasePart, cutters: { Cutter }): boolean
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
		return true
	end

	local ok, result = pcall(function()
		return part:SubtractAsync(tools)
	end)

	for _, tool in tools do
		tool:Destroy()
	end

	if not ok or not result then
		-- Subtracting leaves nothing when the cutter swallows the whole part, so the part just goes.
		for _, cutter in cutters do
			if swallows(cutter, part) then
				part.Parent = nil

				return true
			end
		end

		return false
	end

	local holder = part.Parent

	result.Name = part.Name
	result.Anchored = true
	result.Parent = holder
	part.Parent = nil

	return true
end

--[=[
	Cuts the cutters out of one part, leaving the original with its Parent set to nil so undo can
	bring it back.

	@param part BasePart
	@param cutters { { cf: CFrame, size: Vector3, cylinder: boolean } }
	@return boolean -- false when the cut failed
]=]
function Joints.Carve(part: BasePart, cutters: { Cutter }): boolean
	return carve(part, cutters)
end

--[=[
	Cuts a shape built from specs out of one part. The part leaves with its Parent set to nil so
	undo can bring it back.

	@param part BasePart
	@param specs { Geometry.Spec } -- the pieces of the cutting tool
	@return boolean -- false when the cut failed
]=]
function Joints.CarveShape(part: BasePart, specs: { Geometry.Spec }): boolean
	local tools: { BasePart } = {}

	for _, spec in specs do
		local tool = Instance.new(spec.class) :: BasePart

		tool.Size = spec.size
		tool.CFrame = spec.cf
		table.insert(tools, tool)
	end

	if #tools == 0 then
		return false
	end

	local ok, result = pcall(function()
		return part:SubtractAsync(tools)
	end)

	if #tools > 1 then
		local joined, cutter = pcall(function()
			local rest = table.clone(tools)

			table.remove(rest, 1)

			return tools[1]:UnionAsync(rest)
		end)

		if joined and cutter then
			local again, smooth = pcall(function()
				return part:SubtractAsync({ cutter })
			end)

			if again and smooth then
				ok, result = again, smooth
			end

			cutter:Destroy()
		end
	end

	for _, tool in tools do
		tool:Destroy()
	end

	if not ok or not result then
		return false
	end

	local holder = part.Parent

	result.Name = part.Name
	result.Anchored = true
	result.Parent = holder
	part.Parent = nil

	return true
end

--[[
	@param model Instance
	@param cutters { Cutter }

	Cuts every cuttable wall in the model that the cutters pass through.
]]
local function carveModel(model: Instance, cutters: { Cutter }): number
	local failed = 0

	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and CUT_PARTS[child.Name] and not carve(child, cutters) then
			failed += 1
		end
	end

	return failed
end

--[[
	@return { cf: CFrame, size: Vector3 }? -- the box where the cutter passes through the part, in the part's own axes
]]
local function hole(partCF: CFrame, partSize: Vector3, cutter: Cutter): { cf: CFrame, size: Vector3 }?
	local half = cutter.size / 2
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo

	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = partCF:PointToObjectSpace(
					cutter.cf:PointToWorldSpace(Vector3.new(sx * half.X, sy * half.Y, sz * half.Z))
				)

				lo = lo:Min(corner)
				hi = hi:Max(corner)
			end
		end
	end

	local limit = partSize / 2
	local from = lo:Max(-limit)
	local to = hi:Min(limit)
	local size = to - from

	if size.X < 0.01 or size.Y < 0.01 or size.Z < 0.01 then
		return nil
	end

	return { cf = partCF * CFrame.new((from + to) / 2), size = size }
end

--[[
	@return Vector3 -- the low corner of the cutter's box, which is axis-aligned for rooms
	@return Vector3 -- the high corner
]]
local function corners(cutter: Cutter): (Vector3, Vector3)
	local half = cutter.size / 2

	return cutter.cf.Position - half, cutter.cf.Position + half
end

--[[
	@return Cutter? -- the box of wall between two rooms side by side, across the span where both face each other, or nil when they are not neighbours
]]
local function between(a: Cutter, b: Cutter): Cutter?
	local aLo, aHi = corners(a)
	local bLo, bHi = corners(b)
	local low = math.max(aLo.Y, bLo.Y)
	local high = math.min(aHi.Y, bHi.Y)

	if high - low < 0.5 then
		return nil
	end

	local reach = (a.thickness or 1) + (b.thickness or 1) + 0.1
	local gapX = math.max(aLo.X, bLo.X) - math.min(aHi.X, bHi.X)
	local gapZ = math.max(aLo.Z, bLo.Z) - math.min(aHi.Z, bHi.Z)
	local x0, x1, z0, z1

	if gapX > -0.05 and gapX <= reach and gapZ < -0.5 then
		x0, x1 = math.min(aHi.X, bHi.X), math.max(aLo.X, bLo.X)
		z0, z1 = math.max(aLo.Z, bLo.Z), math.min(aHi.Z, bHi.Z)
	elseif gapZ > -0.05 and gapZ <= reach and gapX < -0.5 then
		z0, z1 = math.min(aHi.Z, bHi.Z), math.max(aLo.Z, bLo.Z)
		x0, x1 = math.max(aLo.X, bLo.X), math.min(aHi.X, bHi.X)
	else
		return nil
	end

	local lo = Vector3.new(math.min(x0, x1) - 0.05, math.min(aLo.Y, bLo.Y) - 0.05, math.min(z0, z1) - 0.05)
	local hi = Vector3.new(math.max(x0, x1) + 0.05, math.max(aHi.Y, bHi.Y) + 0.05, math.max(z0, z1) + 0.05)

	return { cf = CFrame.new((lo + hi) / 2), size = hi - lo, cylinder = false }
end

--[[
	@return { Cutter } -- the cutters applied to the room beside it
	@return { Cutter } -- the cutters applied to the new room. Open cuts both; Shared cuts only the new room's wall and keeps the existing room's
]]
local function roomCuts(mine: Cutter, theirs: Cutter, join: string): ({ Cutter }, { Cutter })
	if join == "Open" then
		local gap = between(mine, theirs)

		if gap then
			return { gap }, { gap }
		end
	elseif join == "Shared" then
		local gap = between(mine, theirs)

		if gap then
			return {}, { gap }
		end
	end

	return {}, {}
end

--[[
	@param rooms { Cutter } -- the interior boxes of every room
	@param point Vector3
	@return boolean -- whether the point is inside one of the rooms' clear space, looking from above
]]
local function insideRoom(rooms: { Cutter }, point: Vector3): boolean
	for _, room in rooms do
		local lo, hi = corners(room)

		if point.X > lo.X and point.X < hi.X and point.Z > lo.Z and point.Z < hi.Z then
			return true
		end
	end

	return false
end

--[[
	Where the gaps cut between a new room and two of its neighbours cross, the corner of the walls
	between all three is left standing. This finds those corners and lists what to cut away: the whole
	post when a room sits in every quarter around it, else the post except the small corner that
	faces the open outside, which stays as the outside wall's corner.

	@param gaps { Cutter } -- the gaps between the new room and each room beside it
	@param rooms { Cutter } -- every room's interior box, the new one included
	@return { Cutter }
]]
local function junctions(gaps: { Cutter }, rooms: { Cutter }): { Cutter }
	local out: { Cutter } = {}

	for i, first in gaps do
		for j = i + 1, #gaps do
			local second = gaps[j]
			local across, along = first, second

			if across.size.X > across.size.Z then
				across, along = second, first
			end

			if across.size.X < across.size.Z and along.size.Z < along.size.X then
				local aLo, aHi = corners(across)
				local bLo, bHi = corners(along)
				local wx, wz = across.size.X, along.size.Z
				local x0, x1 = math.max(aLo.X, bLo.X - wx), math.min(aHi.X, bHi.X + wx)
				local z0, z1 = math.max(bLo.Z, aLo.Z - wz), math.min(bHi.Z, aHi.Z + wz)

				if x1 - x0 > 0.2 and z1 - z0 > 0.2 then
					local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
					local y0, y1 = math.max(aLo.Y, bLo.Y), math.min(aHi.Y, bHi.Y)
					local mid = (y0 + y1) / 2
					local rise = y1 - y0
					local open: { { number } } = {}

					for _, sx in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local sample =
								Vector3.new(cx + sx * ((x1 - x0) / 2 + 0.4), mid, cz + sz * ((z1 - z0) / 2 + 0.4))

							if not insideRoom(rooms, sample) then
								table.insert(open, { sx, sz })
							end
						end
					end

					local function box(x: number, z: number, sizeX: number, sizeZ: number)
						table.insert(out, {
							cf = CFrame.new(x, mid, z),
							size = Vector3.new(sizeX, rise + 0.1, sizeZ),
							cylinder = false,
						})
					end

					if #open == 0 then
						box(cx, cz, x1 - x0 + 0.1, z1 - z0 + 0.1)
					elseif #open == 1 then
						local ex, ez = open[1][1], open[1][2]
						local hx, hz = (x1 - x0) / 2, (z1 - z0) / 2

						box(cx, cz - ez * hz / 2, x1 - x0 + 0.1, hz + 0.1)
						box(cx - ex * hx / 2, cz + ez * hz / 2, hx + 0.1, hz + 0.1)
					end
				end
			end
		end
	end

	return out
end

--[=[
	Lists the openings a structure about to be built would cut, so the preview can light them up:
	where its clear space passes through the walls already built, and where theirs passes through its walls.

	@param name string -- Vlux_Room, Vlux_Corridor or Vlux_ArchedCorridor
	@param specs { Geometry.Spec } -- the parts of the structure about to be built
	@param roomJoin string -- Open, Shared or Separate
	@param skip Instance? -- a structure to leave alone, such as the previous one in a chain
	@return { { cf: CFrame, size: Vector3 } }
]=]
function Joints.Preview(
	name: string,
	specs: { Geometry.Spec },
	roomJoin: string,
	skip: Instance?
): { { cf: CFrame, size: Vector3 } }
	local out: { { cf: CFrame, size: Vector3 } } = {}
	local mine = measureWith(name, function(partName)
		for _, spec in specs do
			if spec.name == partName then
				return spec.cf, spec.size
			end
		end

		return nil, nil
	end)

	if #mine == 0 then
		return out
	end

	local space: { { cf: CFrame, size: Vector3 } } = {}

	for _, box in mine do
		table.insert(space, { cf = box.cf, size = box.size })
	end

	for _, spec in specs do
		table.insert(space, { cf = spec.cf, size = spec.size })
	end

	for _, other in structuresNear(space, NEAR) do
		if other ~= skip then
			local theirs = stored(other)
			local fromMine: { Cutter } = mine
			local fromTheirs: { Cutter } = theirs

			if name == "Vlux_Room" and other.Name == "Vlux_Room" and mine[1] and theirs[1] then
				fromMine, fromTheirs = roomCuts(mine[1], theirs[1], roomJoin)
			end

			for _, child in other:GetChildren() do
				if child:IsA("BasePart") and CUT_PARTS[child.Name] then
					for _, cutter in fromMine do
						local found = hole(child.CFrame, child.Size, cutter)

						if found then
							table.insert(out, found)
						end
					end
				end
			end

			for _, cutter in fromTheirs do
				for _, spec in specs do
					if CUT_PARTS[spec.name] then
						local found = hole(spec.cf, spec.size, cutter)

						if found then
							table.insert(out, found)
						end
					end
				end
			end
		end
	end

	return out
end

--[=[
	@param instance Instance
	@return number? -- the height of the floor top of the room or corridor the instance belongs to, if it belongs to one
]=]
function Joints.FloorLevel(instance: Instance): number?
	local model = instance.Parent

	while model and model ~= workspace do
		if STRUCTURES[model.Name] then
			local floor = model:FindFirstChild("Floor")

			if floor and floor:IsA("BasePart") then
				return floor.Position.Y + floor.Size.Y / 2
			end

			return nil
		end

		model = model.Parent
	end

	return nil
end

--[[
	@return number -- the highest point of any part of the model
]]
local function topOf(model: Instance): number
	local top = -math.huge

	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			local cf, size = child.CFrame, child.Size
			local reach = (
				math.abs(cf.RightVector.Y) * size.X
				+ math.abs(cf.UpVector.Y) * size.Y
				+ math.abs(cf.LookVector.Y) * size.Z
			) / 2

			top = math.max(top, cf.Position.Y + reach)
		end
	end

	return top
end

--[[
	@param model Model -- a structure that was just built
	@param roomJoin string -- Open, Shared or Separate
	@return number -- how many parts could not be cut

	Handles a structure whose floor sits on the top of another one. Separate leaves both slabs, Shared takes the lower ceiling away so one slab is left, and Open also cuts the floor away so the two levels are one space.
]]
local function stackOver(model: Model, roomJoin: string): number
	local floor = model:FindFirstChild("Floor")

	if roomJoin == "Separate" or not floor or not floor:IsA("BasePart") then
		return 0
	end

	local thick = floor.Size.Y
	local bottom = floor.Position.Y - thick / 2
	local failed = 0

	--[[ Only structures under the new floor: its footprint, a little inside the edges so a neighbour beside it is left alone. ]]
	local under = { cf = floor.CFrame, size = floor.Size + Vector3.new(-0.2, 0.5, -0.2) }

	for _, lower in structuresNear({ under }, 0) do
		if lower ~= model and math.abs(topOf(lower) - bottom) < 0.25 then
			local wall = lower:FindFirstChild("CorridorWall") or lower:FindFirstChild("Wall_North")
			local cut: { Cutter } = {}

			for _, clear in stored(lower) do
				if not clear.cylinder then
					local trim = 0

					if wall and wall:IsA("BasePart") and lower.Name ~= "Vlux_Room" then
						trim = wall.Size.X
					end

					local yaw = clear.cf - clear.cf.Position

					table.insert(cut, {
						cf = CFrame.new(clear.cf.Position.X, bottom + thick / 2, clear.cf.Position.Z) * yaw,
						size = Vector3.new(clear.size.X, thick * 2 + 2, math.max(0.1, clear.size.Z - 2 * trim)),
						cylinder = false,
					})
				end
			end

			if #cut > 0 then
				failed += carveModel(lower, cut)

				if roomJoin == "Open" and not Joints.Carve(floor, cut) then
					failed += 1
				end
			end
		end
	end

	return failed
end

--[=[
	Remembers the clear space of a freshly built structure on the model, and cuts openings between
	it and the structures already built. Call it inside the undo recording, right after the build.

	@param model Model -- a Vlux_Room, Vlux_Corridor or Vlux_ArchedCorridor
	@param roomJoin string -- Open, Shared or Separate, for a room built beside another room
	@param skip Instance? -- a structure to leave alone, such as the previous one in a chain
	@return number -- how many walls could not be cut
]=]
function Joints.Connect(model: Model, roomJoin: string, skip: Instance?): number
	local mine = measure(model)

	for index, cutter in mine do
		model:SetAttribute(PREFIX .. "Cut" .. index .. "_CF", cutter.cf)
		model:SetAttribute(PREFIX .. "Cut" .. index .. "_Size", cutter.size)
		model:SetAttribute(PREFIX .. "Cut" .. index .. "_Cylinder", cutter.cylinder)
		model:SetAttribute(PREFIX .. "Cut" .. index .. "_Thickness", cutter.thickness)
	end

	model:SetAttribute(PREFIX .. "Cuts", #mine)

	if #mine == 0 then
		return 0
	end

	local failed = 0
	local gaps: { Cutter } = {}
	local roomBoxes: { Cutter } = {}
	local rooms: { Instance } = {}

	if model.Name == "Vlux_Room" and roomJoin == "Open" and mine[1] then
		table.insert(roomBoxes, mine[1])
	end

	local space = partBoxes(model)

	for _, box in mine do
		table.insert(space, { cf = box.cf, size = box.size })
	end

	for _, other in structuresNear(space, NEAR) do
		if other ~= model and other ~= skip then
			local theirs = stored(other)

			if model.Name == "Vlux_Room" and other.Name == "Vlux_Room" and mine[1] and theirs[1] then
				local fromMine, fromTheirs = roomCuts(mine[1], theirs[1], roomJoin)

				failed += carveModel(other, fromMine)
				failed += carveModel(model, fromTheirs)

				if roomJoin == "Open" then
					local gap = between(mine[1], theirs[1])

					table.insert(roomBoxes, theirs[1])
					table.insert(rooms, other)

					if gap then
						table.insert(gaps, gap)
					end
				end
			else
				failed += carveModel(other, mine)
				failed += carveModel(model, theirs)
			end
		end
	end

	if #gaps >= 2 then
		local posts = junctions(gaps, roomBoxes)

		if #posts > 0 then
			failed += carveModel(model, posts)

			for _, room in rooms do
				failed += carveModel(room, posts)
			end
		end
	end

	failed += stackOver(model, roomJoin)

	return failed
end

return Joints
