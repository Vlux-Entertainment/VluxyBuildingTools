--!strict

--[=[
	The vent holes cut through walls, remembered on the parts they were cut from so the vent tools
	can start from a hole or run to one. Each hole is kept relative to its part, so it follows the
	wall when the wall moves, and in attributes, which carry over when the part is cut again.

	@class VentHoles
]=]

local CollectionService = game:GetService("CollectionService")

local Geometry = require("./Geometry")

--[=[
	One face of a hole: the side it was cut from or the side it comes out of.

	@interface Hole
	@within VentHoles
	.Center Vector3 -- the middle of the hole on this face
	.Normal Vector3 -- the way this face looks, out of the wall
	.Size number -- the side of the square hole
]=]
export type Hole = { Center: Vector3, Normal: Vector3, Size: number }

local TAG = "VluxyBT_VentHoles"
local PREFIX = "VluxyBT_VentHole"

local VentHoles = {}

--[=[
	Records a hole on every part around it. Call right after the hole is cut.

	@param front CFrame -- the middle of the face the hole was cut from, Z looking out of it
	@param size number -- the side of the square hole
	@param depth number -- how far the hole goes through
]=]
function VentHoles.Remember(front: CFrame, size: number, depth: number)
	local params = OverlapParams.new()
	local scope = Geometry.GetScope()

	if scope then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { scope }
	end

	local box = front * CFrame.new(0, 0, -depth / 2)

	for _, part in workspace:GetPartBoundsInBox(box, Vector3.new(size, size, depth), params) do
		if not part:IsA("Terrain") then
			local index = ((part:GetAttribute(PREFIX .. "s") :: number?) or 0) + 1

			part:SetAttribute(PREFIX .. index .. "_Local", part.CFrame:ToObjectSpace(front))
			part:SetAttribute(PREFIX .. index .. "_Size", size)
			part:SetAttribute(PREFIX .. index .. "_Depth", depth)
			part:SetAttribute(PREFIX .. "s", index)
			part:AddTag(TAG)
		end
	end
end

--[=[
	Finds the remembered hole the ray points into, nearest first.

	@param ray Ray -- the mouse ray
	@param toward Vector3? -- pick the face that looks toward this point; default the ray's origin
	@param limit number? -- how far along the ray something already blocks the view; holes behind it are skipped
	@return Hole? -- the face of the hole on that side
]=]
function VentHoles.Find(ray: Ray, toward: Vector3?, limit: number?): Hole?
	local direction = ray.Direction.Unit
	local best: Hole? = nil
	local bestAlong = math.huge

	for _, part in CollectionService:GetTagged(TAG) do
		if part:IsA("BasePart") and part:IsDescendantOf(workspace) then
			for index = 1, (part:GetAttribute(PREFIX .. "s") :: number?) or 0 do
				local relative = part:GetAttribute(PREFIX .. index .. "_Local")
				local size = part:GetAttribute(PREFIX .. index .. "_Size")
				local depth = part:GetAttribute(PREFIX .. index .. "_Depth")

				if typeof(relative) == "CFrame" and type(size) == "number" and type(depth) == "number" then
					local front = part.CFrame * relative
					local back = front.Position - front.ZVector * depth
					local look = toward or ray.Origin
					local onFront = front.ZVector:Dot(look - front.Position) >= 0
					local center = if onFront then front.Position else back
					local normal = if onFront then front.ZVector else -front.ZVector
					local along = (center - ray.Origin):Dot(direction)
					local miss = (ray.Origin + direction * along - center).Magnitude

					if along > 0 and along < (limit or math.huge) + 1 and miss < size * 0.6 and along < bestAlong then
						best, bestAlong = { Center = center, Normal = normal, Size = size }, along
					end
				end
			end
		end
	end

	return best
end

return VentHoles
