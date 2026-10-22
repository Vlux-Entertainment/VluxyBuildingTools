--!strict

--[[
	Benchmarks for the builders, run through the harness: the specs a big room, a long wall chain
	and tall stairs produce. The preview rebuilds these every frame the mouse moves.
]]

local Harness = require("../Support/Harness")
local roblox = require("@lune/roblox")

local Settings = require("../../src/Pure/Settings")

local Vector3 = roblox.Vector3

local context = Harness.new()
local Areas = context:Require("src/Core/Builders/Areas")
local Paths = context:Require("src/Core/Builders/Paths")
local Slopes = context:Require("src/Core/Builders/Slopes")
local Openings = context:Require("src/Core/Builders/Openings")

local SETTINGS = Settings.Defaults()
local ROOFED = Settings.Defaults()

ROOFED.Roof = true

local CHAIN = {}

for i = 0, 200 do
	table.insert(CHAIN, Vector3.new(i * 12, 0, if i % 2 == 0 then 0 else 9))
end

local WALL = Harness.Part(Vector3.new(400, 12, 1), roblox.CFrame.new(0, 6, 0), context.Workspace)
local DOOR = { Width = 4, Height = 7.75, Sill = 0, Panel = true, Frame = true }

return {
	["Areas.Room 200x200 with a roof x1000"] = {
		Budget = 60,
		Run = function()
			for _ = 1, 1000 do
				Areas.Room(ROOFED, Vector3.zero, Vector3.new(200, 0, 200))
			end
		end,
	},

	["Paths.Path wall chain of 200 bends x2"] = {
		Budget = 65,
		Run = function()
			for _ = 1, 2 do
				for i = 2, #CHAIN do
					local before = if i > 2 then CHAIN[i - 1] - CHAIN[i - 2] else nil

					Paths.Path(SETTINGS, CHAIN[i - 1], CHAIN[i], false, nil, before)
				end
			end
		end,
	},

	["Paths.Path corridor chain of 200 bends"] = {
		Budget = 120,
		Run = function()
			for i = 2, #CHAIN do
				local before = if i > 2 then CHAIN[i - 1] - CHAIN[i - 2] else nil

				Paths.Path(ROOFED, CHAIN[i - 1], CHAIN[i], true, nil, before)
			end
		end,
	},

	["Slopes.Stairs of 200 steps x100"] = {
		Budget = 170,
		Run = function()
			for _ = 1, 100 do
				Slopes.Stairs(SETTINGS, Vector3.zero, Vector3.new(0, 0, -300), false)
			end
		end,
	},

	["Openings.Opening framed door x1000"] = {
		Budget = 120,
		Run = function()
			for i = 1, 1000 do
				Openings.Opening(SETTINGS, DOOR, Harness.Hit(WALL, Vector3.new(i % 100, 3, 0.5)), "Rect")
			end
		end,
	},
}
