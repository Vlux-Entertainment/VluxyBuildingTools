--!strict

local Keymap = require("../../src/Pure/Keymap")

return {
	["T extrudes"] = function(expect)
		expect.equal(Keymap.Resolve("T", false, false, false, false), "Extrude")
	end,

	["axis keys lock only while a drag is live"] = function(expect)
		expect.equal(Keymap.Resolve("Y", false, false, false, true), "Lock:Y")
		expect.equal(Keymap.Resolve("Y", false, false, true, true), "Plane:Y")
		expect.falsy(Keymap.Resolve("Y", false, false, false, false))
	end,

	["Ctrl and Alt are left to Studio"] = function(expect)
		expect.falsy(Keymap.Resolve("T", false, true, false, false))
		expect.falsy(Keymap.Resolve("G", false, false, true, false))
		expect.falsy(Keymap.Resolve("X", false, true, false, true))
	end,

	["Alt plus a digit picks the same tool"] = function(expect)
		expect.equal(Keymap.Resolve("One", false, false, true, false), "Tool:Wall")
		expect.equal(Keymap.Resolve("Eight", false, false, true, false), "Tool:Measure")
		expect.falsy(Keymap.Resolve("Nine", false, false, true, false))
	end,

	["digits pick tools"] = function(expect)
		expect.equal(Keymap.Resolve("One", false, false, false, false), "Tool:Wall")
		expect.equal(Keymap.Resolve("Eight", false, false, false, false), "Tool:Measure")
		expect.falsy(Keymap.Resolve("Zero", false, false, false, false))
	end,

	["V duplicates, Shift is never used"] = function(expect)
		expect.equal(Keymap.Resolve("V", false, false, false, false), "Duplicate")
		expect.falsy(Keymap.Resolve("V", true, false, false, false))
		expect.falsy(Keymap.Resolve("X", true, false, false, true))
	end,

	["W A S D Q E F are never taken, with or without Shift"] = function(expect)
		for _, key in { "W", "A", "S", "D", "Q", "E", "F" } do
			expect.falsy(Keymap.Resolve(key, false, false, false, false), key)
			expect.falsy(Keymap.Resolve(key, true, false, false, false), key)
			expect.falsy(Keymap.Resolve(key, false, false, false, true), key)
		end
	end,

	["panel navigation keys"] = function(expect)
		expect.equal(Keymap.Resolve("Tab", false, false, false, false), "NextTab")
		expect.equal(Keymap.Resolve("Backquote", false, false, false, false), "PrevTab")
		expect.equal(Keymap.Resolve("F1", false, false, false, false), "ShowHotkeys")
		expect.equal(Keymap.Resolve("P", false, false, false, false), "TogglePastel")
		expect.equal(Keymap.Resolve("L", false, false, false, false), "ToggleGrid")
		expect.equal(Keymap.Resolve("N", false, false, false, false), "TogglePanel")
	end,

	["hide, flip and quick-rotate keys"] = function(expect)
		expect.equal(Keymap.Resolve("H", false, false, false, false), "Hide")
		expect.equal(Keymap.Resolve("H", false, false, true, false), "Unhide")
		expect.equal(Keymap.Resolve("I", false, false, false, false), "ToggleHiddenView")
		expect.equal(Keymap.Resolve("M", false, true, false, false), "FlipArm")
		expect.equal(Keymap.Resolve("O", false, false, false, false), "Rotate90Arm")
		expect.falsy(Keymap.Resolve("M", false, false, false, false))
		expect.falsy(Keymap.Resolve("H", false, true, true, false))
	end,

	["every binding is described"] = function(expect)
		expect.truthy(#Keymap.Describe() >= 12)
	end,
}
