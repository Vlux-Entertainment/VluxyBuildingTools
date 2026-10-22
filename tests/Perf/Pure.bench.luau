--!strict

--[[
	Benchmarks for the Pure layer: the per-part rules the color themes and part roles run over a
	whole place, settings loading, outline triangulation and array steps.
]]

local ArrayStep = require("../../src/Pure/ArrayStep")
local PartRole = require("../../src/Pure/PartRole")
local Polygon = require("../../src/Pure/Polygon")
local Settings = require("../../src/Pure/Settings")
local ShapeClass = require("../../src/Pure/ShapeClass")
local ThemeColors = require("../../src/Pure/ThemeColors")

local PARTS = 100000
local NAMES = { "Wall_North", "Floor", "Ceiling", "Step_4", "Opening_Left", "Door_Frame", "Pillar", "Crate" }
local UPS = { 0, 1, 0 }
local EASTS = { 1, 0, 0 }

--[[
	@param count number -- how many points
	@return { Polygon.Point } -- a star outline, concave at every other point
]]
local function star(count: number): { Polygon.Point }
	local points = {}

	for i = 1, count do
		local angle = (i / count) * 2 * math.pi
		local radius = if i % 2 == 0 then 10 else 6

		table.insert(points, { math.cos(angle) * radius, math.sin(angle) * radius })
	end

	return points
end

local OUTLINE = star(50)
local FULL_SAVE = Settings.Defaults()

return {
	["ThemeColors: Facing, Size and Level x100k parts"] = {
		Budget = 50,
		Run = function()
			for i = 1, PARTS do
				local size = { 1 + i % 7, 1 + i % 13, 1 + i % 5 }

				ThemeColors.Facing(size, UPS, EASTS)
				ThemeColors.Size(size)
				ThemeColors.Level(i % 200, 14, 1)
			end
		end,
	},

	["PartRole.Of x100k names"] = {
		Budget = 80,
		Run = function()
			for i = 1, PARTS do
				PartRole.Of(NAMES[i % #NAMES + 1])
			end
		end,
	},

	["ShapeClass.Of x100k sizes"] = {
		Budget = 30,
		Run = function()
			for i = 1, PARTS do
				ShapeClass.Of(1 + i % 7, 1 + i % 13, 1 + i % 5)
			end
		end,
	},

	["Settings.Load of a full save x1000"] = {
		Budget = 35,
		Run = function()
			for _ = 1, 1000 do
				Settings.Load(FULL_SAVE)
			end
		end,
	},

	["Polygon.Triangulate of a 50-point outline x100"] = {
		Budget = 30,
		Run = function()
			for _ = 1, 100 do
				assert(Polygon.Triangulate(OUTLINE), "the outline did not triangulate")
			end
		end,
	},

	["ArrayStep Offset and Copies x100k"] = {
		Budget = 30,
		Run = function()
			local size = { 4, 2, 8 }
			local relative = { 1, 0, 0.5 }
			local constant = { 0, 3, -2 }

			for i = 1, PARTS do
				ArrayStep.Offset(size, true, relative, i % 2 == 0, constant)
				ArrayStep.Copies(i % 300)
			end
		end,
	},
}
