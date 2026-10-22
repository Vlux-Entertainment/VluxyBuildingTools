--!strict

local ThemeColors = require("../../src/Pure/ThemeColors")

local UPS = { 0, 1, 0 }
local EASTS = { 1, 0, 0 }

--[[ Writes a color so tests compare plain strings. ]]
local function rgb(color: { number }): string
	return table.concat(color, ",")
end

return {
	["a room's floor, walls and ceiling share one level color"] = function(expect)
		local level = rgb(ThemeColors.Level(-0.5, 14, 1))

		expect.equal(rgb(ThemeColors.Level(6, 14, 1)), level)
		expect.equal(rgb(ThemeColors.Level(12.5, 14, 1)), level)
		expect.equal(rgb(ThemeColors.Level(13.5, 14, 1)) ~= level, true)
	end,

	["levels start over above the last color"] = function(expect)
		local count = #ThemeColors.LevelColors

		expect.equal(rgb(ThemeColors.Level(6 + 14 * count, 14, 1)), rgb(ThemeColors.Level(6, 14, 1)))
		expect.equal(rgb(ThemeColors.Level(-8, 14, 1)), rgb(ThemeColors.LevelColors[count]))
	end,

	["structure colors wrap around the palette"] = function(expect)
		local count = #ThemeColors.GroupColors

		expect.equal(rgb(ThemeColors.Group(count + 2)), rgb(ThemeColors.Group(2)))
	end,

	["facing tells walls along X from walls along Z"] = function(expect)
		local x = rgb(ThemeColors.Facing({ 24, 12, 1 }, UPS, EASTS))
		local z = rgb(ThemeColors.Facing({ 1, 12, 24 }, UPS, EASTS))
		local turned = rgb(ThemeColors.Facing({ 24, 12, 1 }, UPS, { 0, 0, 1 }))

		expect.equal(x ~= z, true)
		expect.equal(turned, z)
	end,

	["facing marks floors flat, diagonals and tilted parts apart"] = function(expect)
		local flat = rgb(ThemeColors.Facing({ 24, 1, 24 }, UPS, EASTS))
		local diagonal = rgb(ThemeColors.Facing({ 24, 12, 1 }, UPS, { 0.7071, 0, 0.7071 }))
		local tilted = rgb(ThemeColors.Facing({ 24, 12, 1 }, { 0, 0.9, 0.43 }, EASTS))
		local x = rgb(ThemeColors.Facing({ 24, 12, 1 }, UPS, EASTS))

		expect.equal(flat ~= x and diagonal ~= x and tilted ~= x, true)
		expect.equal(flat ~= diagonal and diagonal ~= tilted and flat ~= tilted, true)
	end,

	["size goes by the largest side"] = function(expect)
		local small = rgb(ThemeColors.Size({ 0.5, 0.5, 0.5 }))
		local big = rgb(ThemeColors.Size({ 1, 1, 40 }))

		expect.equal(small ~= big, true)
		expect.equal(rgb(ThemeColors.Size({ 40, 1, 1 })), big)
	end,
}
