--!strict

--[=[
	Flat polygon maths for the Cut Shape tool. It works on plain `{ x, y }` pairs, so it runs under
	Lune.

	@class Polygon
]=]

export type Point = { number }

local Polygon = {}

--[[
	@return number -- twice the signed area of the triangle, positive when a to b to c turns left
]]
local function cross(a: Point, b: Point, c: Point): number
	return (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
end

--[[
	@return boolean -- whether p lies inside or on the triangle a, b, c given in counter-clockwise order
]]
local function inside(p: Point, a: Point, b: Point, c: Point): boolean
	return cross(a, b, p) >= -1e-9 and cross(b, c, p) >= -1e-9 and cross(c, a, p) >= -1e-9
end

--[=[
	@param points { Point } -- the corners in order, either winding
	@return number -- the area, always positive
]=]
function Polygon.Area(points: { Point }): number
	local sum = 0

	for i, a in points do
		local b = points[i % #points + 1]

		sum += a[1] * b[2] - b[1] * a[2]
	end

	return math.abs(sum) / 2
end

--[=[
	Cuts a simple polygon into triangles by clipping its ears.

	@param points { Point } -- three or more corners in order, either winding
	@return { { number } }? -- triples of indexes into points, or nil when the polygon is too small or crosses itself
]=]
function Polygon.Triangulate(points: { Point }): { { number } }?
	if #points < 3 or Polygon.Area(points) < 1e-6 then
		return nil
	end

	local order: { number } = {}
	local sum = 0

	for i, a in points do
		local b = points[i % #points + 1]

		sum += a[1] * b[2] - b[1] * a[2]
		table.insert(order, i)
	end

	if sum < 0 then
		local flipped: { number } = {}

		for i = #order, 1, -1 do
			table.insert(flipped, order[i])
		end

		order = flipped
	end

	local out: { { number } } = {}

	while #order > 3 do
		local clipped = false

		for i = 1, #order do
			local prev = order[(i - 2) % #order + 1]
			local this = order[i]
			local following = order[i % #order + 1]
			local a, b, c = points[prev], points[this], points[following]

			if cross(a, b, c) > 1e-9 then
				local empty = true

				for _, other in order do
					if other ~= prev and other ~= this and other ~= following and inside(points[other], a, b, c) then
						empty = false

						break
					end
				end

				if empty then
					table.insert(out, { prev, this, following })
					table.remove(order, i)

					clipped = true

					break
				end
			end
		end

		if not clipped then
			return nil
		end
	end

	table.insert(out, { order[1], order[2], order[3] })

	return out
end

return Polygon
