--!strict

local ArrayStep = require("../../src/Pure/ArrayStep")

local SIZE = { 4, 2, 8 }

return {
	["the relative offset steps by the object's own size"] = function(expect)
		local step = ArrayStep.Offset(SIZE, true, { 1, 0, 0.5 }, false, { 9, 9, 9 })

		expect.equal(table.concat(step, ","), "4,0,4")
	end,

	["the constant offset adds studs"] = function(expect)
		local step = ArrayStep.Offset(SIZE, false, { 1, 0, 0 }, true, { 0, 3, -2 })

		expect.equal(table.concat(step, ","), "0,3,-2")
	end,

	["both offsets add together, and neither gives no step"] = function(expect)
		expect.equal(table.concat(ArrayStep.Offset(SIZE, true, { 1, 0, 0 }, true, { 1, 0, 0 }), ","), "5,0,0")
		expect.equal(table.concat(ArrayStep.Offset(SIZE, false, { 1, 0, 0 }, false, { 1, 0, 0 }), ","), "0,0,0")
	end,

	["the count includes the original and is kept in range"] = function(expect)
		expect.equal(ArrayStep.Copies(2), 1)
		expect.equal(ArrayStep.Copies(0), 0)
		expect.equal(ArrayStep.Copies(3.7), 2)
		expect.equal(ArrayStep.Copies(1000), ArrayStep.MaxCount - 1)
	end,
}
