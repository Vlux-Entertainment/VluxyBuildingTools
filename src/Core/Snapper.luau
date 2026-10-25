--!strict

--[=[
	Snaps a point to the corners and edges of the parts already built nearby, like Roblox's own
	building tools do. It works on the outline of each part seen from above, so the height of the
	point is never changed.

	@class Snapper
]=]

local Geometry = require("./Geometry")

local CollectionService = game:GetService("CollectionService")

local VENT_TAG = "VluxyBT_Vent"
local MAX_PARTS = 120
local MIN_SIZE = 0.05
local EDGE_REACH = 0.9

export type Doorway = {
	point: Vector3,
	normal: Vector3,
	width: number,
	height: number?,
}

local Snapper = {}

--[[
	@param part BasePart
	@return { Vector3 } -- the four corners of the part's outline from above, in order around it
]]
local function outline(part: BasePart): { Vector3 }
	local cf, size = part.CFrame, part.Size

	if math.abs(cf.UpVector.Y) < 0.98 then
		local half = size / 2
		local x, y, z = cf.RightVector, cf.UpVector, cf.LookVector
		local reach = Vector3.new(
			math.abs(x.X) * half.X + math.abs(y.X) * half.Y + math.abs(z.X) * half.Z,
			0,
			math.abs(x.Z) * half.X + math.abs(y.Z) * half.Y + math.abs(z.Z) * half.Z
		)
		local c = cf.Position

		return {
			c + Vector3.new(-reach.X, 0, -reach.Z),
			c + Vector3.new(reach.X, 0, -reach.Z),
			c + Vector3.new(reach.X, 0, reach.Z),
			c + Vector3.new(-reach.X, 0, reach.Z),
		}
	end

	local hx, hz = size.X / 2, size.Z / 2

	return {
		cf:PointToWorldSpace(Vector3.new(-hx, 0, -hz)),
		cf:PointToWorldSpace(Vector3.new(hx, 0, -hz)),
		cf:PointToWorldSpace(Vector3.new(hx, 0, hz)),
		cf:PointToWorldSpace(Vector3.new(-hx, 0, hz)),
	}
end

--[[
	@return Vector3 -- the point on the segment a to b nearest to p, looking from above
]]
local function onSegment(p: Vector3, a: Vector3, b: Vector3): Vector3
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local length = ab:Dot(ab)

	if length < 1e-6 then
		return a
	end

	local t = math.clamp(Vector3.new(p.X - a.X, 0, p.Z - a.Z):Dot(ab) / length, 0, 1)

	return Vector3.new(a.X + ab.X * t, 0, a.Z + ab.Z * t)
end

--[=[
	Finds the nearest corner of a nearby part within the radius, else the nearest edge within most
	of it. Only the working folder is searched when one is set.

	@param point Vector3 -- the point to move, already snapped to the grid
	@param radius number -- how far away a corner or edge can be and still attract the point
	@return Vector3 -- the snapped point, or the same point when nothing was near
	@return boolean -- whether it moved to a part
	@return BasePart? -- the part it moved to
]=]
function Snapper.Find(point: Vector3, radius: number): (Vector3, boolean, BasePart?)
	local params = OverlapParams.new()
	local scope = Geometry.GetScope()

	params.MaxParts = MAX_PARTS

	if scope then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { scope }
	end

	local bestCorner: Vector3? = nil
	local cornerPart: BasePart? = nil
	local edgePart: BasePart? = nil
	local cornerDistance = radius
	local bestEdge: Vector3? = nil
	local edgeDistance = radius * EDGE_REACH

	for _, part in workspace:GetPartBoundsInRadius(point, radius, params) do
		if part.Size.X > MIN_SIZE and part.Size.Z > MIN_SIZE and not part:IsA("Terrain") then
			local corners = outline(part)

			for index, corner in corners do
				local flat = Vector3.new(corner.X - point.X, 0, corner.Z - point.Z).Magnitude

				if flat < cornerDistance then
					cornerDistance, bestCorner = flat, Vector3.new(corner.X, point.Y, corner.Z)
					cornerPart = part
				end

				local nextCorner = corners[index % #corners + 1]
				local nearest = onSegment(point, corner, nextCorner)
				local distance = Vector3.new(nearest.X - point.X, 0, nearest.Z - point.Z).Magnitude

				if distance < edgeDistance then
					edgeDistance, bestEdge = distance, Vector3.new(nearest.X, point.Y, nearest.Z)
					edgePart = part
				end
			end
		end
	end

	local found = bestCorner or bestEdge

	if found then
		return found, true, if bestCorner then cornerPart else edgePart
	end

	return point, false, nil
end

--[=[
	Finds the nearest of the eight corners of any part within the radius, in all three dimensions.
	The Measure tool uses it so a distance starts and ends exactly on a vertex.

	@param point Vector3 -- where the cursor hit
	@param radius number
	@return Vector3 -- the corner, or the same point when none is near
	@return boolean -- whether it moved to a corner
]=]
function Snapper.Vertex(point: Vector3, radius: number): (Vector3, boolean)
	local params = OverlapParams.new()

	params.MaxParts = MAX_PARTS

	local best: Vector3? = nil
	local bestDistance = radius

	for _, part in workspace:GetPartBoundsInRadius(point, radius, params) do
		if not part:IsA("Terrain") then
			local half = part.Size / 2

			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local corner = part.CFrame:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
						local distance = (corner - point).Magnitude

						if distance < bestDistance then
							bestDistance, best = distance, corner
						end
					end
				end
			end
		end
	end

	if best then
		return best, true
	end

	return point, false
end

--[=[
	Finds the open end of a vent built by this plugin near the point. Each vent model records its
	two ends in attributes so a new vent, or a cover, can start exactly on one.

	@param point Vector3
	@param radius number
	@return Vector3? -- the middle of the opening
	@return Vector3? -- the direction pointing out of the vent
]=]
function Snapper.VentEnd(point: Vector3, radius: number): (Vector3?, Vector3?)
	local best: Vector3? = nil
	local bestDirection: Vector3? = nil
	local bestDistance = radius

	for _, model in CollectionService:GetTagged(VENT_TAG) do
		local ends = Snapper.VentEnds(model)

		if ends then
			for _, side in { { ends.Start, ends.StartDir }, { ends.End, ends.EndDir } } do
				local distance = (side[1] - point).Magnitude

				if distance < bestDistance and Snapper.VentEndOpen(model, side[1]) then
					bestDistance, best, bestDirection = distance, side[1], Snapper.VentFacing(side[2])
				end
			end
		end
	end

	return best, bestDirection
end

--[=[
	The two ends of a vent, where the openings are and which way each looks out.

	@interface VentEnds
	@within Snapper
	.Start Vector3 -- the first end, on the middle line
	.StartDir Vector3 -- the way out of the first end
	.End Vector3 -- the other end
	.EndDir Vector3 -- the way out of it
]=]
export type VentEnds = { Start: Vector3, StartDir: Vector3, End: Vector3, EndDir: Vector3 }

local END_KEYS = { "Start", "StartDir", "End", "EndDir" }

--[=[
	Records a vent's ends on its model. They are kept relative to the model's pivot, so they stay on
	the openings when the vent is moved or turned, and in world space too for older readers.

	@param model Instance -- the vent
	@param ends VentEnds
	@param pivot CFrame -- the model's pivot now
]=]
function Snapper.RememberVentEnds(model: Instance, ends: VentEnds, pivot: CFrame)
	for _, key in END_KEYS do
		local value = (ends :: any)[key] :: Vector3
		local isDirection = string.sub(key, -3) == "Dir"

		model:SetAttribute("VluxyBT_Vent" .. key, value)
		model:SetAttribute(
			"VluxyBT_Vent" .. key .. "Local",
			if isDirection then pivot:VectorToObjectSpace(value) else pivot:PointToObjectSpace(value)
		)
	end
end

--[=[
	Reads a vent's ends through a getter, so it works on any attribute source.

	@param get (name: string) -> any -- reads one attribute
	@param pivot CFrame -- the vent's pivot now
	@return VentEnds? -- in world space; nil when the vent has no ends recorded
]=]
function Snapper.ReadVentEnds(get: (name: string) -> any, pivot: CFrame): VentEnds?
	local out: { [string]: Vector3 } = {}
	local relative = true

	for _, key in END_KEYS do
		if typeof(get("VluxyBT_Vent" .. key .. "Local")) ~= "Vector3" then
			relative = false
		end
	end

	for _, key in END_KEYS do
		local value = get("VluxyBT_Vent" .. key .. (if relative then "Local" else ""))

		if typeof(value) ~= "Vector3" then
			return nil
		elseif not relative then
			out[key] = value
		elseif string.sub(key, -3) == "Dir" then
			out[key] = pivot:VectorToWorldSpace(value)
		else
			out[key] = pivot:PointToWorldSpace(value)
		end
	end

	if (out.End - out.Start).Magnitude <= 0.05 then
		return nil
	end

	return { Start = out.Start, StartDir = out.StartDir, End = out.End, EndDir = out.EndDir }
end

--[=[
	@param model Instance -- a vent model
	@return VentEnds? -- its ends where they are now, following the vent if it was moved or turned
]=]
function Snapper.VentEnds(model: Instance): VentEnds?
	local pivot = if model:IsA("PVInstance") then model:GetPivot() else CFrame.identity

	return Snapper.ReadVentEnds(function(name)
		return model:GetAttribute(name)
	end, pivot)
end

--[=[
	Picks the opening a ray aims into: the one whose middle passes closest to the ray, within a
	little over half the vent size, and not hidden behind what the ray hits first.

	@param origin Vector3
	@param direction Vector3
	@param openings { { At: Vector3, Dir: Vector3 } }
	@param size number -- the outside size of the vents
	@param limit number? -- how far the ray goes before it hits something
	@return number? -- the index of the opening aimed at
]=]
function Snapper.AimedOpening(
	origin: Vector3,
	direction: Vector3,
	openings: { { At: Vector3, Dir: Vector3 } },
	size: number,
	limit: number?
): number?
	local unit = direction.Unit
	local best: number? = nil
	local bestMiss = size * 0.6

	for index, opening in openings do
		local along = (opening.At - origin):Dot(unit)
		local miss = (origin + unit * along - opening.At).Magnitude

		if along > 0 and along < (limit or math.huge) + size / 2 and miss < bestMiss then
			best, bestMiss = index, miss
		end
	end

	return best
end

--[=[
	Finds the open vent end the mouse ray aims into. Unlike a hit point, which lands deep inside a
	duct when the mouse looks into it, this works from any angle and from either side of a wall.

	@param ray Ray
	@param size number -- the outside size of the vents
	@param limit number? -- how far the ray goes before it hits something
	@return Vector3? -- the middle of the opening
	@return Vector3? -- the way the opening faces
	@return Instance? -- the vent
]=]
function Snapper.VentEndOnRay(ray: Ray, size: number, limit: number?): (Vector3?, Vector3?, Instance?)
	local openings: { { At: Vector3, Dir: Vector3 } } = {}
	local owners: { Instance } = {}

	for _, model in CollectionService:GetTagged(VENT_TAG) do
		local ends = Snapper.VentEnds(model)

		if ends then
			for _, side in { { ends.Start, ends.StartDir }, { ends.End, ends.EndDir } } do
				if Snapper.VentEndOpen(model, side[1]) then
					table.insert(openings, { At = side[1], Dir = Snapper.VentFacing(side[2]) })
					table.insert(owners, model)
				end
			end
		end
	end

	local index = Snapper.AimedOpening(ray.Origin, ray.Direction, openings, size, limit)

	if not index then
		return nil, nil, nil
	end

	return openings[index].At, openings[index].Dir, owners[index]
end

--[=[
	A sloped vent's ends are cut upright, so the way out of one is level even though the duct tilts.

	@param direction Vector3 -- the recorded way out of a vent end
	@return Vector3 -- the way the opening faces: level unless the vent is a vertical shaft
]=]
function Snapper.VentFacing(direction: Vector3): Vector3
	local flat = Vector3.new(direction.X, 0, direction.Z)

	return if math.abs(direction.Unit.Y) > 0.99 or flat.Magnitude < 1e-3 then direction.Unit else flat.Unit
end

--[=[
	@param model Instance -- the vent the end belongs to
	@param at Vector3 -- the end, on the vent's middle line
	@return boolean -- false when another vent starts or ends there, so the end is already joined
]=]
function Snapper.VentEndOpen(model: Instance, at: Vector3): boolean
	for _, other in CollectionService:GetTagged(VENT_TAG) do
		local ends = if other ~= model then Snapper.VentEnds(other) else nil

		if ends and ((ends.Start - at).Magnitude < 0.15 or (ends.End - at).Magnitude < 0.15) then
			return false
		end
	end

	return true
end

--[=[
	Finds a connection point on a vent built by this plugin: an open end, or a spot along its middle
	line snapped to the step. Spots along the side stay `margin` from the ends, so a vent started
	there sits wholly against the side and never runs into a corner.

	@param point Vector3 -- where the cursor hit
	@param radius number -- how far from the middle line still counts
	@param step number -- the spacing of the points along a vent
	@param margin number? -- how far side spots keep from the ends; half the vent size
	@return Vector3? -- the point on the middle line
	@return Vector3? -- the way out of the vent when the point is an open end, else nil
	@return Instance? -- the vent model the point is on
	@return boolean -- whether the point is a corner: an end another vent already continues
]=]
function Snapper.VentConnect(
	point: Vector3,
	radius: number,
	step: number,
	margin: number?
): (Vector3?, Vector3?, Instance?, boolean)
	local bestModel: Instance? = nil
	local bestDistance = radius
	local bestA, bestD, bestAlong = Vector3.zero, Vector3.zero, 0
	local bestEnds: VentEnds? = nil

	for _, model in CollectionService:GetTagged(VENT_TAG) do
		local ends = Snapper.VentEnds(model)

		if ends then
			local a = ends.Start
			local d = ends.End - a
			local along = math.clamp((point - a):Dot(d) / d.Magnitude, 0, d.Magnitude)
			local distance = (a + d.Unit * along - point).Magnitude

			if distance < bestDistance then
				bestDistance, bestModel, bestEnds = distance, model, ends
				bestA, bestD, bestAlong = a, d, along
			end
		end
	end

	if not bestModel or not bestEnds then
		return nil, nil, nil, false
	end

	local length = bestD.Magnitude
	local b = bestA + bestD
	local reach = math.max(step * 0.75, (margin or 0) * 0.6)

	for _, name in { "Start", "End" } do
		local at = if name == "Start" then bestA else b
		local near = if name == "Start" then bestAlong < reach else length - bestAlong < reach

		if near and Snapper.VentEndOpen(bestModel, at) then
			local out = if name == "Start" then bestEnds.StartDir else bestEnds.EndDir

			return at, Snapper.VentFacing(out), bestModel, false
		elseif near then
			return at, nil, bestModel, true
		end
	end

	local keep = math.min(margin or 0, length / 2)
	local snapped = math.clamp(math.round(bestAlong / step) * step, keep, length - keep)

	return bestA + bestD.Unit * snapped, nil, bestModel, false
end

--[=[
	Whether a straight level duct would run into a vent already built. Ends that meet flush, and the
	vents named in `skip`, do not count.

	@param a Vector3 -- one end of the new duct, on its middle line
	@param b Vector3 -- the other end
	@param size number -- the outside size of the ducts
	@param skip { Instance } -- vents the new one is allowed to touch: the one it starts from
	@return boolean
]=]
function Snapper.VentBlocked(a: Vector3, b: Vector3, size: number, skip: { Instance }): boolean
	local half = size / 2 - 0.1
	local low = a:Min(b) - Vector3.one * half
	local high = a:Max(b) + Vector3.one * half
	local along = (b - a).Unit

	low += Vector3.new(math.abs(along.X), math.abs(along.Y), math.abs(along.Z)) * (half + 0.05)
	high -= Vector3.new(math.abs(along.X), math.abs(along.Y), math.abs(along.Z)) * (half + 0.05)

	for _, model in CollectionService:GetTagged(VENT_TAG) do
		local ends = if table.find(skip, model) then nil else Snapper.VentEnds(model)

		if ends then
			local s, e = ends.Start, ends.End
			local d = e - s
			local level = math.abs(d.Y) < 0.05
			local upright = Vector3.new(d.X, 0, d.Z).Magnitude < 0.05

			if level or upright then
				local reach = size / 2 - 0.1
				local otherLow, otherHigh = s:Min(e) - Vector3.one * reach, s:Max(e) + Vector3.one * reach

				if
					low.X < otherHigh.X
					and high.X > otherLow.X
					and low.Y < otherHigh.Y
					and high.Y > otherLow.Y
					and low.Z < otherHigh.Z
					and high.Z > otherLow.Z
				then
					return true
				end
			end
		end
	end

	return false
end

--[=[
	Finds the corner of a nearby part that sits closest to the mouse on the screen, within a few
	pixels. Unlike a distance in studs, this only grabs a corner when the cursor is really on it.

	@param point Vector3 -- where the cursor hit
	@param mouse Vector2 -- the mouse in screen coordinates
	@param pixels number -- how close on screen counts
	@return Vector3 -- the corner, or the same point when none is near
	@return boolean -- whether it moved to a corner
]=]
function Snapper.VertexNear(point: Vector3, mouse: Vector2, pixels: number): (Vector3, boolean)
	local camera = workspace.CurrentCamera

	if not camera then
		return point, false
	end

	local params = OverlapParams.new()

	params.MaxParts = MAX_PARTS

	local best: Vector3? = nil
	local bestDistance = pixels

	for _, part in workspace:GetPartBoundsInRadius(point, 30, params) do
		if not part:IsA("Terrain") then
			local half = part.Size / 2

			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local corner = part.CFrame:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
						local screen = camera:WorldToScreenPoint(corner)

						if screen.Z > 0 then
							local distance = (Vector2.new(screen.X, screen.Y) - mouse).Magnitude

							if distance < bestDistance then
								bestDistance, best = distance, corner
							end
						end
					end
				end
			end
		end
	end

	if best then
		return best, true
	end

	return point, false
end

--[=[
	Moves a point on the top of a thin part, such as a wall, onto its centre line, so a wall built
	on top of a wall sits on it instead of beside it. Along the part it snaps to its ends, else to
	the grid measured from one end.

	@param part BasePart
	@param point Vector3 -- where the cursor hit the top
	@param grid number
	@param endReach number -- how close to an end counts as the end
	@return Vector3? -- the point on the centre line, or nil when the part is not thin
]=]
function Snapper.TopCenter(part: BasePart, point: Vector3, grid: number, endReach: number): Vector3?
	local size = part.Size
	local thinIsX = size.X <= size.Z
	local thin, long = if thinIsX then size.X else size.Z, if thinIsX then size.Z else size.X

	if thin >= long * 0.5 or part.CFrame.UpVector.Y < 0.98 then
		return nil
	end

	local localPoint = part.CFrame:PointToObjectSpace(point)
	local along = if thinIsX then localPoint.Z else localPoint.X
	local half = long / 2

	if half - math.abs(along) <= endReach then
		along = if along >= 0 then half else -half
	elseif grid > 0 then
		along = math.clamp(math.round((along + half) / grid) * grid - half, -half, half)
	end

	local top = size.Y / 2
	local result = if thinIsX then Vector3.new(0, top, along) else Vector3.new(along, top, 0)

	return part.CFrame:PointToWorldSpace(result)
end

--[=[
	Finds a doorway made by the Additive tools near the point: a rectangular or arched opening
	that reaches the floor. The result is the middle of the opening on the face of the wall the point is
	on, with the direction pointing away from that face, so a corridor can start there.

	@param point Vector3
	@param radius number -- how far from the middle of the opening still counts
	@return Doorway?
]=]
function Snapper.Doorway(point: Vector3, radius: number): Doorway?
	local best: Doorway? = nil
	local bestDistance = math.huge

	for _, model in (Geometry.GetScope() or workspace):GetChildren() do
		local left = model:FindFirstChild("Opening_Left")
		local right = model:FindFirstChild("Opening_Right")

		if
			left
			and right
			and left:IsA("BasePart")
			and right:IsA("BasePart")
			and not model:FindFirstChild("Opening_Sill")
			and not model:FindFirstChild("Circle_Frame")
			and not model:FindFirstChild("Triangle_Frame")
		then
			local axis = left.CFrame.RightVector
			local leftEdge = left.Position + axis * (left.Size.X / 2)
			local rightEdge = right.Position - axis * (right.Size.X / 2)
			local width = (rightEdge - leftEdge):Dot(axis)

			if width > 0.1 then
				local center = leftEdge + axis * (width / 2)
				local normal = left.CFrame.LookVector
				local flat = Vector3.new(normal.X, 0, normal.Z)

				if flat.Magnitude > 0.5 then
					normal = flat.Unit

					local distance = Vector3.new(point.X - center.X, 0, point.Z - center.Z).Magnitude

					if distance <= radius + width / 2 and distance < bestDistance then
						local side = if (point - center):Dot(normal) >= 0 then 1 else -1
						local header = model:FindFirstChild("Opening_Header")
						local height = if header and header:IsA("BasePart") then left.Size.Y - header.Size.Y else nil
						local bottom = left.Position.Y - left.Size.Y / 2

						bestDistance = distance
						best = {
							point = Vector3.new(center.X, bottom, center.Z) + normal * side * (left.Size.Z / 2),
							normal = normal * side,
							width = width,
							height = height,
						}
					end
				end
			end
		end
	end

	return best
end

return Snapper
