--!strict

--[=[
	Snaps a point to the corners and edges of the parts already built nearby, like Roblox's own
	building tools do. It works on the outline of each part seen from above, so the height of the
	point is never changed.

	@class Snapper
]=]

local Geometry = require("./Geometry")

local MAX_PARTS = 120
local MIN_SIZE = 0.05
local EDGE_REACH = 0.8

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
]=]
function Snapper.Find(point: Vector3, radius: number): (Vector3, boolean)
	local params = OverlapParams.new()
	local scope = Geometry.GetScope()

	params.MaxParts = MAX_PARTS

	if scope then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { scope }
	end

	local bestCorner: Vector3? = nil
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
				end

				local nextCorner = corners[index % #corners + 1]
				local nearest = onSegment(point, corner, nextCorner)
				local distance = Vector3.new(nearest.X - point.X, 0, nearest.Z - point.Z).Magnitude

				if distance < edgeDistance then
					edgeDistance, bestEdge = distance, Vector3.new(nearest.X, point.Y, nearest.Z)
				end
			end
		end
	end

	local found = bestCorner or bestEdge

	if found then
		return found, true
	end

	return point, false
end

return Snapper
