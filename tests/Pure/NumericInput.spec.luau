--!strict

local NumericInput = require("../../src/Pure/NumericInput")

local function type(input: NumericInput.NumericInput, ...: string)
	for _, key in { ... } do
		NumericInput.Press(input, key)
	end
end

return {
	["builds a decimal from key names"] = function(expect)
		local input = NumericInput.new()

		type(input, "One", "Two", "Period", "Five")
		expect.equal(NumericInput.Value(input), 12.5)
	end,

	["keypad digits count"] = function(expect)
		local input = NumericInput.new()

		type(input, "KeypadSeven", "KeypadPeriod", "KeypadTwo")
		expect.equal(NumericInput.Value(input), 7.2)
	end,

	["a second point is ignored"] = function(expect)
		local input = NumericInput.new()

		type(input, "One", "Period", "Period", "Five")
		expect.equal(input.Text, "1.5")
	end,

	["minus toggles the sign and backspace edits"] = function(expect)
		local input = NumericInput.new()

		type(input, "Three", "Minus")
		expect.equal(NumericInput.Value(input), -3)
		type(input, "Minus", "Four", "Backspace")
		expect.equal(NumericInput.Value(input), 3)
	end,

	["other keys are not number entry"] = function(expect)
		local input = NumericInput.new()

		expect.falsy(NumericInput.Press(input, "A"))
		expect.truthy(NumericInput.IsEmpty(input))
		expect.falsy(NumericInput.Value(input))
	end,
}
