--!strict

local StairSnap = require("../../src/Pure/StairSnap")

local STAIRS: StairSnap.Layout = { Run = 1.5, Rise = 0.75, Count = 8, Width = 8, Landing = 4, Ramp = false }

return {
	["a post on a step stands at its lip, on the side edge nearest the point"] = function(expect)
		local x, y, z = StairSnap.Spot(STAIRS, 2.9, -4, 0.35)

		expect.near(x :: number, 3.65, 1e-9, "the right edge, moved in half a post")
		expect.near(y, 2.25, 1e-9, "on top of the third step")
		expect.near(z, -3.35, 1e-9, "at the third step's lip, moved in half a post")

		local left = StairSnap.Spot(STAIRS, -0.1, -4, 0.35)

		expect.near(left :: number, -3.65, 1e-9, "the left edge")
	end,

	["the back of a step snaps to the same lip as its front"] = function(expect)
		local _, frontY, frontZ = StairSnap.Spot(STAIRS, 1, -3.05, 0.35)
		local _, backY, backZ = StairSnap.Spot(STAIRS, 1, -4.45, 0.35)

		expect.near(frontZ, backZ, 1e-9)
		expect.near(frontY, backY, 1e-9)
	end,

	["the top and the landing"] = function(expect)
		local _, topY, topZ = StairSnap.Spot(STAIRS, 1, -11.9, 0.35)
		local _, landingY, landingZ = StairSnap.Spot(STAIRS, 1, -14, 0.35)

		expect.near(topY, 6, 1e-9, "the last step")
		expect.near(topZ, -10.85, 1e-9)
		expect.near(landingY, 6, 1e-9, "the landing is level with the last step")
		expect.near(landingZ, -12.35, 1e-9, "at the landing's front edge")
	end,

	["a ramp keeps the point's place along the slope"] = function(expect)
		local ramp = table.clone(STAIRS)

		ramp.Ramp = true

		local _, y, z = StairSnap.Spot(ramp, 1, -6, 0.35)

		expect.near(y, 3, 1e-9, "halfway up")
		expect.near(z, -6, 1e-9)
	end,

	["off the stairs is nothing"] = function(expect)
		expect.equal(StairSnap.Spot(STAIRS, 1, 2, 0.35), nil)
		expect.equal(StairSnap.Spot(STAIRS, 1, -30, 0.35), nil)
	end,
}
