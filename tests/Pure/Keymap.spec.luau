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

	["panel navigation keys"] = function(expect)
		expect.equal(Keymap.Resolve("Tab", false, false, false, false), "NextTab")
		expect.equal(Keymap.Resolve("Tab", true, false, false, false), "PrevTab")
		expect.equal(Keymap.Resolve("F1", false, false, false, false), "ShowHotkeys")
		expect.equal(Keymap.Resolve("P", false, false, false, false), "TogglePastel")
		expect.equal(Keymap.Resolve("P", true, false, false, false), "ToggleGrid")
		expect.equal(Keymap.Resolve("N", false, false, false, false), "TogglePanel")
	end,

	["hide, flip and quick-rotate keys"] = function(expect)
		expect.equal(Keymap.Resolve("H", false, false, false, false), "Hide")
		expect.equal(Keymap.Resolve("H", false, false, true, false), "Unhide")
		expect.equal(Keymap.Resolve("H", true, false, false, false), "ToggleHiddenView")
		expect.equal(Keymap.Resolve("M", false, true, false, false), "FlipArm")
		expect.equal(Keymap.Resolve("R", true, false, false, false), "Rotate90Arm")
		expect.falsy(Keymap.Resolve("M", false, false, false, false))
		expect.falsy(Keymap.Resolve("H", false, true, true, false))
	end,

	["every binding is described"] = function(expect)
		expect.truthy(#Keymap.Describe() >= 12)
	end,
}
