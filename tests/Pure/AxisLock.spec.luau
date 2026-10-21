--!strict

local AxisLock = require("../../src/Pure/AxisLock")

local ORIGIN = { X = 0, Y = 0, Z = 0 }

return {
	["pressing the active lock clears it"] = function(expect)
		local lock = AxisLock.Toggle(nil, "Y", false)

		expect.truthy(lock)
		expect.equal((lock :: AxisLock.Lock).Axis, "Y")
		expect.falsy(AxisLock.Toggle(lock, "Y", false))
		expect.equal((AxisLock.Toggle(lock, "X", false) :: AxisLock.Lock).Axis, "X")
		expect.truthy((AxisLock.Toggle(lock, "Y", true) :: AxisLock.Lock).Plane)
	end,

	["axis lock keeps only the locked component"] = function(expect)
		local point = AxisLock.Constrain(ORIGIN, { X = 4, Y = 5, Z = 6 }, { Axis = "Y", Plane = false })

		expect.equal(point.X, 0)
		expect.equal(point.Y, 5)
		expect.equal(point.Z, 0)
	end,

	["plane lock freezes only the locked component"] = function(expect)
		local point = AxisLock.Constrain({ X = 1, Y = 2, Z = 3 }, { X = 4, Y = 5, Z = 6 }, { Axis = "Y", Plane = true })

		expect.equal(point.X, 4)
		expect.equal(point.Y, 2)
		expect.equal(point.Z, 6)
	end,

	["closest point on a vertical line follows the ray's height"] = function(expect)
		-- A ray from (10, 3, 0) looking along -X passes the Y axis at height 3.
		local along = AxisLock.ClosestOnLine(
			ORIGIN,
			{ X = 0, Y = 1, Z = 0 },
			{ X = 10, Y = 3, Z = 0 },
			{ X = -1, Y = 0, Z = 0 }
		)

		expect.near(along :: number, 3)
	end,

	["a ray parallel to the line has no closest point"] = function(expect)
		local along = AxisLock.ClosestOnLine(
			ORIGIN,
			{ X = 0, Y = 1, Z = 0 },
			{ X = 5, Y = 0, Z = 0 },
			{ X = 0, Y = 2, Z = 0 }
		)

		expect.falsy(along)
	end,

	["a ray meets a horizontal plane"] = function(expect)
		local hit = AxisLock.RayPlane({ X = 0, Y = 2, Z = 0 }, "Y", { X = 0, Y = 10, Z = 0 }, { X = 1, Y = -1, Z = 0 })

		expect.near((hit :: AxisLock.Vec).X, 8)
		expect.near((hit :: AxisLock.Vec).Y, 2)
	end,

	["a plane behind the ray is a miss"] = function(expect)
		expect.falsy(
			AxisLock.RayPlane({ X = 0, Y = 20, Z = 0 }, "Y", { X = 0, Y = 10, Z = 0 }, { X = 1, Y = -1, Z = 0 })
		)
	end,
}
