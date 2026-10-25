--!strict

local MeasureText = require("../../src/Pure/MeasureText")

return {
	["each shape reads out its sizes and its length, area or volume"] = function(expect)
		expect.truthy(string.find(MeasureText.Line(3, 0, 4), "Length 5.00", 1, true))
		expect.truthy(string.find(MeasureText.Square(4, 2.5), "Area 10.00", 1, true))
		expect.truthy(string.find(MeasureText.Box(2, 3, 4), "Volume 24.00", 1, true))
		expect.truthy(string.find(MeasureText.Box(2, 3, 4), "Surface 52.00", 1, true))
		expect.truthy(string.find(MeasureText.Circle(1), "Area 3.14", 1, true))
		expect.truthy(string.find(MeasureText.Circle(1), "Diameter 2.00", 1, true))
		expect.truthy(string.find(MeasureText.Ball(3), "Volume 113.10", 1, true))
		expect.truthy(string.find(MeasureText.Ball(3), "Surface 113.10", 1, true))
	end,
}
