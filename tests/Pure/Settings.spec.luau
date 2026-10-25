--!strict

local Settings = require("../../src/Pure/Settings")
local Snap = require("../../src/Pure/Snap")

return {
	["the vent size is the inside; the sheets go outside it"] = function(expect)
		local settings = Settings.Defaults()

		settings.VentSize, settings.VentThickness = 3, 0.2

		expect.near(Settings.VentOuter(settings), 3.4, 1e-6)
		expect.equal(Settings.VentHole(settings), 3)

		settings.VentHoleFit = "Outside"

		expect.near(Settings.VentHole(settings), 3.4, 1e-6)
	end,

	["a vent size left at the old default takes the new one"] = function(expect)
		expect.equal(Settings.Defaults().VentSize, 3.5)
		expect.equal(Settings.Load({ Version = 6, VentSize = 3 }).VentSize, 3.5)
		expect.equal(Settings.Load({ Version = 6, VentSize = 4 }).VentSize, 4)
		expect.equal(Settings.Load({ Version = 7, VentSize = 3 }).VentSize, 3)
	end,

	["a default vent is 4 studs outside, and a thickness left at the old default follows"] = function(expect)
		expect.equal(Settings.VentOuter(Settings.Defaults()), 4)
		expect.equal(Settings.Load({ Version = 7, VentThickness = 0.2 }).VentThickness, 0.25)
		expect.equal(Settings.Load({ Version = 7, VentThickness = 0.3 }).VentThickness, 0.3)
		expect.equal(Settings.Load({ Version = 8, VentThickness = 0.2 }).VentThickness, 0.2)
	end,

	["stairs drawn from an edge move half their width to the side"] = function(expect)
		local settings = Settings.Defaults()

		settings.Width = 6
		expect.equal(Settings.StairOffset(settings), 0)

		settings.StairLine = "Left"
		expect.equal(Settings.StairOffset(settings), 3)

		settings.StairLine = "Right"
		expect.equal(Settings.StairOffset(settings), -3)
	end,

	["a bad save falls back to the defaults"] = function(expect)
		expect.equal(Settings.Load("nope").Grid, 4)
		expect.equal(Settings.Load("nope").FineGrid, 0.25)
		expect.equal(Settings.Load(nil).Height, 12)
	end,

	["a save from before the new snap steps takes the new defaults"] = function(expect)
		local settings = Settings.Load({ Grid = 1, FineGrid = 0.25, Height = 20 })

		expect.equal(settings.Grid, 4)
		expect.equal(settings.FineGrid, 0.25)
		expect.equal(settings.Height, 20)
	end,

	["snap values left at the old defaults take the new ones, and the floor level is the ground"] = function(expect)
		local old = Settings.Load({ Version = 5, Grid = 2, FineGrid = 1, SnapRadius = 5, Elevation = 40 })

		expect.equal(old.Grid, 2)
		expect.equal(old.FineGrid, 0.25)
		expect.equal(old.SnapRadius, 1)
		expect.equal(old.Elevation, 0)

		local chosen = Settings.Load({ Version = 5, FineGrid = 0.5, SnapRadius = 3 })

		expect.equal(chosen.FineGrid, 0.5)
		expect.equal(chosen.SnapRadius, 3)
		expect.equal(Settings.Load({ Version = 6, FineGrid = 1 }).FineGrid, 1)
	end,

	["a save from before the standard door takes the door defaults once"] = function(expect)
		local old = Settings.Load({ Version = 3, Grid = 2, DoorPanel = false, FrameDepth = 1.095, DoorCollide = true })

		expect.equal(old.Grid, 2)
		expect.equal(old.DoorPanel, true)
		expect.equal(old.DoorFrame, true)
		expect.equal(old.FrameDepth, 1.1)
		expect.equal(old.DoorThickness, 0.2)
		expect.equal(old.DoorTransparency, 0.5)
		expect.equal(old.DoorCollide, false)

		local current = Settings.Load({ Version = 4, DoorPanel = false, DoorCollide = true })

		expect.equal(current.DoorPanel, false)
		expect.equal(current.DoorCollide, true)
	end,

	["a camera light left at the old default takes the new one"] = function(expect)
		expect.equal(Settings.Load({ Version = 4, CameraLightBrightness = 2 }).CameraLightBrightness, 0.5)
		expect.equal(Settings.Load({ Version = 4, CameraLightBrightness = 3 }).CameraLightBrightness, 3)
		expect.equal(Settings.Load({ Version = 5, CameraLightBrightness = 2 }).CameraLightBrightness, 2)
	end,

	["the Settings tab's reset list names real settings, and no tool, display or hotkey ones"] = function(expect)
		local defaults = Settings.Defaults() :: any

		for _, key in Settings.Page do
			expect.truthy(defaults[key] ~= nil, key)
		end

		for _, other in { "Height", "ColorTheme", "Hotkeys", "CameraLight", "DoorPanel" } do
			expect.falsy(table.find(Settings.Page, other))
		end
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

	["an offset close to a direction, or square to it, lines up with it"] = function(expect)
		local tolerance = math.rad(12)
		local x, z, lined = Snap.Align(10, 1, 1, 0, tolerance)

		expect.truthy(lined)
		expect.near(x, 10, 1e-9, "runs on along the direction")
		expect.near(z, 0, 1e-9)

		x, z, lined = Snap.Align(0.8, -6, 1, 0, tolerance)
		expect.truthy(lined)
		expect.near(x, 0, 1e-9, "turns square")
		expect.near(z, -6, 1e-9)

		x, z, lined = Snap.Align(5, 5, 1, 0, tolerance)
		expect.falsy(lined, "a diagonal is left alone")
		expect.near(x, 5, 1e-9)

		local diagonal = math.sqrt(0.5)

		x, z = Snap.Align(7, 6, diagonal, diagonal, tolerance)
		expect.near(x, z, 1e-9, "a turned direction works too")
	end,

	["snap rounds to the grid and never below 0.05"] = function(expect)
		expect.equal(Snap.Round(7.4, 5), 5)
		expect.equal(Snap.Round(7.6, 5), 10)
		expect.near(Snap.Round(0.12, 0), 0.1, 1e-9)
	end,
}
