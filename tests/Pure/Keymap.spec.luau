--!strict

local Keymap = require("../../src/Pure/Keymap")

return {
	["E extrudes"] = function(expect)
		expect.equal(Keymap.Resolve("E", false, false, false, false), "Extrude")
	end,

	["axis keys lock only while a drag is live"] = function(expect)
		expect.equal(Keymap.Resolve("Y", false, false, false, true), "Lock:Y")
		expect.equal(Keymap.Resolve("Y", true, false, false, true), "Plane:Y")
		expect.falsy(Keymap.Resolve("Y", false, false, false, false))
	end,

	["Ctrl and Alt are left to Studio"] = function(expect)
		expect.falsy(Keymap.Resolve("E", false, true, false, false))
		expect.falsy(Keymap.Resolve("G", false, false, true, false))
		expect.falsy(Keymap.Resolve("X", false, true, false, true))
	end,

	["digits pick tools"] = function(expect)
		expect.equal(Keymap.Resolve("One", false, false, false, false), "Tool:Wall")
		expect.equal(Keymap.Resolve("Zero", false, false, false, false), "Tool:Measure")
	end,

	["Shift+D duplicates, other Shift keys do nothing"] = function(expect)
		expect.equal(Keymap.Resolve("D", true, false, false, false), "Duplicate")
		expect.falsy(Keymap.Resolve("E", true, false, false, false))
	end,

	["every binding is described"] = function(expect)
		expect.truthy(#Keymap.Describe() >= 8)
	end,
}
