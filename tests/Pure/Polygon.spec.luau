--!strict

local Polygon = require("../../src/Pure/Polygon")

--[[
	@return number -- the combined area of the triangles a triangulation made
]]
local function covered(points: { Polygon.Point }, triangles: { { number } }): number
	local total = 0

	for _, t in triangles do
		total += Polygon.Area({ points[t[1]], points[t[2]], points[t[3]] })
	end

	return total
end

return {
	["a square becomes two triangles of the same area"] = function(expect)
		local square = { { 0, 0 }, { 4, 0 }, { 4, 4 }, { 0, 4 } }
		local triangles = Polygon.Triangulate(square) :: { { number } }

		expect.equal(#triangles, 2)
		expect.equal(covered(square, triangles), 16)
	end,

	["an L shape keeps its notch"] = function(expect)
		local shape = { { 0, 0 }, { 4, 0 }, { 4, 2 }, { 2, 2 }, { 2, 4 }, { 0, 4 } }
		local triangles = Polygon.Triangulate(shape) :: { { number } }

		expect.equal(#triangles, 4)
		expect.equal(covered(shape, triangles), 12)
	end,

	["either winding works"] = function(expect)
		local shape = { { 0, 4 }, { 2, 4 }, { 2, 2 }, { 4, 2 }, { 4, 0 }, { 0, 0 } }
		local triangles = Polygon.Triangulate(shape) :: { { number } }

		expect.equal(covered(shape, triangles), 12)
	end,

	["too few or flat points give nothing"] = function(expect)
		expect.falsy(Polygon.Triangulate({ { 0, 0 }, { 1, 1 } }))
		expect.falsy(Polygon.Triangulate({ { 0, 0 }, { 1, 1 }, { 2, 2 } }))
	end,

	["a bow tie that crosses itself is refused"] = function(expect)
		expect.falsy(Polygon.Triangulate({ { 0, 0 }, { 4, 4 }, { 4, 0 }, { 0, 4 } }))
	end,
}
