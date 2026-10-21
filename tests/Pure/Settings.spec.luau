--!strict

local Settings = require("../../src/Pure/Settings")
local Snap = require("../../src/Pure/Snap")

return {
	["a bad save falls back to the defaults"] = function(expect)
		expect.equal(Settings.Load("nope").Grid, 4)
		expect.equal(Settings.Load("nope").FineGrid, 1)
		expect.equal(Settings.Load(nil).Height, 12)
	end,

	["saved values of the right type win, others are dropped"] = function(expect)
		local settings = Settings.Load({ Grid = 2, Height = "tall", Unknown = 9, Roof = true })

		expect.equal(settings.Grid, 2)
		expect.equal(settings.Height, 12)
		expect.equal(settings.Roof, true)
		expect.falsy((settings :: any).Unknown)
	end,

	["snap rounds to the grid and never below 0.05"] = function(expect)
		expect.equal(Snap.Round(7.4, 5), 5)
		expect.equal(Snap.Round(7.6, 5), 10)
		expect.near(Snap.Round(0.12, 0), 0.1, 1e-9)
	end,
}
