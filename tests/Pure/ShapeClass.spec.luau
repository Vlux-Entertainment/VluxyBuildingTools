--!strict

local ShapeClass = require("../../src/Pure/ShapeClass")

return {
	["a slab lying flat is a floor, a standing one a wall"] = function(expect)
		expect.truthy(ShapeClass.LiesFlat({ 24, 1, 24 }, { 0, 1, 0 }), "floor")
		expect.truthy(ShapeClass.LiesFlat({ 1, 24, 24 }, { 1, 0, 0 }), "floor lying on its side")
		expect.falsy(ShapeClass.LiesFlat({ 24, 12, 1 }, { 0, 1, 0 }), "wall along X")
		expect.falsy(ShapeClass.LiesFlat({ 1, 12, 24 }, { 0, 1, 0 }), "wall along Z")
	end,

	["cubes and chunky boxes are blocks"] = function(expect)
		expect.equal(ShapeClass.Of(4, 4, 4), "Block")
		expect.equal(ShapeClass.Of(4, 2, 8), "Block")
		expect.equal(ShapeClass.Of(1, 1, 1), "Block")
	end,

	["walls and floors are planes, whichever way they lie"] = function(expect)
		expect.equal(ShapeClass.Of(12, 16, 1), "Plane")
		expect.equal(ShapeClass.Of(20, 1, 20), "Plane")
		expect.equal(ShapeClass.Of(0.2, 2, 2), "Plane")
	end,

	["beams, rails and posts are pipes"] = function(expect)
		expect.equal(ShapeClass.Of(1, 1, 10), "Pipe")
		expect.equal(ShapeClass.Of(1, 12, 1), "Pipe")
		expect.equal(ShapeClass.Of(0.5, 0.6, 8), "Pipe")
	end,

	["a flat strip counts as a plane before a pipe"] = function(expect)
		expect.equal(ShapeClass.Of(0.1, 1, 20), "Plane")
	end,

	["a broken size counts as a plane"] = function(expect)
		expect.equal(ShapeClass.Of(0, 4, 4), "Plane")
		expect.equal(ShapeClass.Of(0 / 0, 4, 4), "Plane")
	end,
}
