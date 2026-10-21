--!strict

--[=[
	Typed numbers for a modal tool, as in Blender: type 5 to move exactly 5 studs. It holds the
	characters typed so far and turns them into a number on request.

	@class NumericInput
]=]

export type NumericInput = {
	Text: string,
}

local DIGITS: { [string]: string } = {
	Zero = "0",
	One = "1",
	Two = "2",
	Three = "3",
	Four = "4",
	Five = "5",
	Six = "6",
	Seven = "7",
	Eight = "8",
	Nine = "9",
}

local NumericInput = {}

--[=[
	@return NumericInput -- an empty entry
]=]
function NumericInput.new(): NumericInput
	return { Text = "" }
end

--[=[
	Feeds one key name, as `Enum.KeyCode.Name` spells it. Digits (main row or keypad), the point
	and the minus sign are taken, Backspace removes one character, and anything else is ignored.

	@param input NumericInput
	@param keyName string
	@return boolean -- true when the key was part of number entry
]=]
function NumericInput.Press(input: NumericInput, keyName: string): boolean
	local bare = string.gsub(keyName, "^Keypad", "")
	local digit = DIGITS[bare]

	if digit then
		input.Text ..= digit
	elseif bare == "Period" then
		if not string.find(input.Text, ".", 1, true) then
			input.Text ..= "."
		end
	elseif bare == "Minus" then
		input.Text = if string.sub(input.Text, 1, 1) == "-" then string.sub(input.Text, 2) else "-" .. input.Text
	elseif keyName == "Backspace" then
		input.Text = string.sub(input.Text, 1, -2)
	else
		return false
	end

	return true
end

--[=[
	@param input NumericInput
	@return number? -- the typed value, or nil while nothing usable is typed
]=]
function NumericInput.Value(input: NumericInput): number?
	return tonumber(input.Text)
end

--[=[
	@param input NumericInput
	@return boolean
]=]
function NumericInput.IsEmpty(input: NumericInput): boolean
	return input.Text == ""
end

--[=[
	@param input NumericInput
]=]
function NumericInput.Clear(input: NumericInput)
	input.Text = ""
end

return NumericInput
