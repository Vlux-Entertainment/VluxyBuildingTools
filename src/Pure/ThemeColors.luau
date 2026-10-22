--!strict

--[=[
	The color rules of the themes that read a part's place, direction or size, as plain numbers so
	they run under Lune. Each returns a color as { r, g, b } from 0 to 255.

	- Levels: one color per building level, from the part's height.
	- Structures: one bold color per structure (a room, a corridor, a loose part).
	- Facing: which way the part runs; along X, along Z, diagonal, flat, or tilted off level.
	- Size: how big the part is, from small detail to large mass.

	@class ThemeColors
]=]

export type Rgb = { number }

local ThemeColors = {}

--[=[
	The colors of the Levels theme, from the ground up; it starts over above the last.

	@prop LevelColors { Rgb }
	@within ThemeColors
]=]
ThemeColors.LevelColors = {
	{ 214, 92, 92 },
	{ 230, 160, 60 },
	{ 214, 204, 80 },
	{ 96, 186, 108 },
	{ 70, 170, 200 },
	{ 110, 120, 220 },
	{ 180, 100, 200 },
}

--[=[
	The bold colors the Structures theme picks from.

	@prop GroupColors { Rgb }
	@within ThemeColors
]=]
ThemeColors.GroupColors = {
	{ 230, 76, 60 },
	{ 241, 148, 38 },
	{ 241, 206, 46 },
	{ 120, 200, 64 },
	{ 38, 166, 120 },
	{ 40, 190, 200 },
	{ 52, 120, 220 },
	{ 110, 84, 210 },
	{ 180, 70, 200 },
	{ 226, 80, 150 },
	{ 150, 100, 60 },
	{ 120, 130, 140 },
}

--[[ The Facing theme's colors. ]]
local ALONG_X = { 70, 130, 220 }
local ALONG_Z = { 80, 190, 100 }
local DIAGONAL = { 240, 150, 40 }
local FLAT = { 210, 190, 150 }
local SQUARE = { 140, 145, 160 }
local TILTED = { 230, 50, 160 }

--[[ The Size theme's colors and the largest side each one goes up to, smallest first. ]]
local SIZES = {
	{ Below = 1, Color = { 245, 220, 70 } },
	{ Below = 4, Color = { 160, 210, 80 } },
	{ Below = 12, Color = { 60, 180, 170 } },
	{ Below = 32, Color = { 70, 120, 210 } },
	{ Below = math.huge, Color = { 120, 70, 170 } },
}

--[[ How close to straight an axis must be to count as straight: about 2.5 degrees, as a cosine and a sine. ]]
local STRAIGHT = 0.999
local ACROSS = 0.045

--[=[
	@param y number -- the height of the part's centre
	@param pitch number -- the height of one level, floor to floor
	@param below number -- how far a level's floor reaches below the level, so the floor counts with its level
	@return Rgb -- the color of the level the part is on
]=]
function ThemeColors.Level(y: number, pitch: number, below: number): Rgb
	local level = math.floor((y + below) / math.max(pitch, 0.1))
	local colors = ThemeColors.LevelColors

	return colors[level % #colors + 1]
end

--[=[
	@param index number -- any whole number, such as one saved on the structure
	@return Rgb -- that structure's color
]=]
function ThemeColors.Group(index: number): Rgb
	local colors = ThemeColors.GroupColors

	return colors[(math.floor(index) - 1) % #colors + 1]
end

--[=[
	@param size { number } -- the part's size along its own X, Y and Z
	@param ups { number } -- how much each of the part's own X, Y and Z axes points up in the world
	@param easts { number } -- how much each of them points along world X
	@return Rgb -- the color of the way the part runs
]=]
function ThemeColors.Facing(size: { number }, ups: { number }, easts: { number }): Rgb
	local up = 1

	for axis = 2, 3 do
		if math.abs(ups[axis]) > math.abs(ups[up]) then
			up = axis
		end
	end

	if math.abs(ups[up]) < STRAIGHT then
		return TILTED
	end

	local a, b = if up == 1 then 2 else 1, if up == 3 then 2 else 3
	local long, short = a, b

	if size[b] > size[a] then
		long, short = b, a
	end

	if size[up] * 2 <= size[short] then
		return FLAT
	elseif size[long] < size[short] * 1.25 then
		return SQUARE
	end

	local east = math.abs(easts[long])

	if east >= STRAIGHT then
		return ALONG_X
	elseif east <= ACROSS then
		return ALONG_Z
	end

	return DIAGONAL
end

--[=[
	@param size { number } -- the part's size along its own X, Y and Z
	@return Rgb -- the color of how big the part's largest side is
]=]
function ThemeColors.Size(size: { number }): Rgb
	local largest = math.max(size[1], size[2], size[3])

	for _, step in SIZES do
		if largest < step.Below then
			return step.Color
		end
	end

	return SIZES[#SIZES].Color
end

return ThemeColors
