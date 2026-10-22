--!strict

local Settings = require("../../src/Pure/Settings")
local Snap = require("../../src/Pure/Snap")

return {
	["a bad save falls back to the defaults"] = function(expect)
		expect.equal(Settings.Load("nope").Grid, 4)
		expect.equal(Settings.Load("nope").FineGrid, 1)
		expect.equal(Settings.Load(nil).Height, 12)
	end,

	["a save from before the new snap steps takes the new defaults"] = function(expect)
		local settings = Settings.Load({ Grid = 1, FineGrid = 0.25, Height = 20 })

		expect.equal(settings.Grid, 4)
		expect.equal(settings.FineGrid, 1)
		expect.equal(settings.Height, 20)
	end,

	["saved values of the right type win, others are dropped"] = function(expect)
		local settings = Settings.Load({ Version = 3, Grid = 2, Height = "tall", Unknown = 9, Roof = true })

		expect.equal(settings.Grid, 2)
		expect.equal(settings.Height, 12)
		expect.equal(settings.Roof, true)
		expect.falsy((settings :: any).Unknown)
	end,

	["a tool field that differs from its standard is marked overridden"] = function(expect)
		local settings = Settings.Defaults()

		Settings.Apply(settings, "Height", 20)
		expect.equal(settings.Height, 20)
		expect.equal(settings.HeightOverride, true)

		Settings.Apply(settings, "Height", settings.StandardHeight)
		expect.equal(settings.HeightOverride, false)
	end,

	["a new standard flows into fields that are not overridden"] = function(expect)
		local settings = Settings.Defaults()

		Settings.Apply(settings, "Thickness", 3)
		Settings.Apply(settings, "StandardHeight", 16)
		Settings.Apply(settings, "StandardThickness", 2)

		expect.equal(settings.Height, 16)
		expect.equal(settings.Thickness, 3)
	end,

	["shared differences name only settings the folder holds a different value for"] = function(expect)
		local settings = Settings.Defaults()
		local folder: { [string]: any } = { ColorTheme = "unity", GhostTransparency = 0.82, AutoGrid = "yes" }
		local names = Settings.Differences(settings, function(key)
			return folder[key]
		end)

		expect.equal(#names, 1)
		expect.equal(names[1], "theme")
	end,

	["theme names match ignoring case"] = function(expect)
		expect.equal(Settings.ThemeName("UNITY"), "Unity")
		expect.equal(Settings.ThemeName("Pastel"), "Pastel")
		expect.falsy(Settings.ThemeName("Neon"))
		expect.falsy(Settings.ThemeName(5))
	end,

	["snap rounds to the grid and never below 0.05"] = function(expect)
		expect.equal(Snap.Round(7.4, 5), 5)
		expect.equal(Snap.Round(7.6, 5), 10)
		expect.near(Snap.Round(0.12, 0), 0.1, 1e-9)
	end,
}
