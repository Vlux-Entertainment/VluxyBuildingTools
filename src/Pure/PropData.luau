--!strict

--[=[
	The built-in props, as plain data so the list can be tested under Lune. Each prop is a handful of
	simple shapes. A prop is drawn around a point on the floor: X is across, Y is up from the floor
	and Z is front (negative) to back (positive). A wall prop has its back on the wall at Z = 0 and
	its front toward negative Z. A ceiling prop hangs from the ceiling at Y = 0, so its Y values are
	negative.

	@class PropData
]=]

export type Part = {
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	shape: string,
	accent: boolean,
	glow: { number }?,
	lamp: boolean?,
	lights: { Brightness: number, Range: number }?,
	yaw: number?,
	lay: boolean?,
	half: boolean?,
	paint: { Color: { number }, Material: string, Transparency: number, Soft: boolean? }?,
}

export type Prop = {
	Id: string,
	Label: string,
	Category: string,
	Mount: string,
	Parts: { Part },
	Model: string?,
	Pivot: { number }?,
}

export type Category = {
	Id: string,
	Label: string,
}

local PropData = {}

--[[
	@return Part -- a box centred at x, y, z
]]
local function B(x: number, y: number, z: number, sx: number, sy: number, sz: number, accent: boolean?): Part
	return { x = x, y = y, z = z, sx = sx, sy = sy, sz = sz, shape = "Block", accent = accent == true }
end

--[[
	@return Part -- an upright cylinder centred at x, y, z
]]
local function C(x: number, y: number, z: number, diameter: number, height: number, accent: boolean?): Part
	return {
		x = x,
		y = y,
		z = z,
		sx = diameter,
		sy = height,
		sz = diameter,
		shape = "Cylinder",
		accent = accent == true,
	}
end

--[[
	@return Part -- a ball centred at x, y, z
]]
local function S(x: number, y: number, z: number, diameter: number, accent: boolean?): Part
	return {
		x = x,
		y = y,
		z = z,
		sx = diameter,
		sy = diameter,
		sz = diameter,
		shape = "Ball",
		accent = accent == true,
	}
end

--[[
	@param part Part
	@param r number -- the glow color, 0 to 1
	@param g number
	@param b number
	@return Part -- the same shape, made neon in that color
]]
local function glowing(part: Part, r: number, g: number, b: number): Part
	part.glow = { r, g, b }

	return part
end

--[[
	@param part Part
	@param degrees number
	@return Part -- the same shape, turned about the vertical through its own centre
]]
local function turned(part: Part, degrees: number): Part
	part.yaw = degrees

	return part
end

--[[
	@param part Part -- a cylinder
	@return Part -- the same cylinder lying along its X axis instead of standing
]]
local function laid(part: Part): Part
	part.lay = true

	return part
end

--[[
	@param part Part -- a ball
	@return Part -- the same ball cut in half, keeping the lower half, as one union
]]
local function halved(part: Part): Part
	part.half = true

	return part
end

--[[
	@param part Part
	@param r number -- 0 to 1
	@param g number
	@param b number
	@param material string -- an Enum.Material name
	@param transparency number?
	@return Part -- the same shape in a fixed color and material that the color themes leave alone
]]
local function painted(part: Part, r: number, g: number, b: number, material: string, transparency: number?): Part
	part.paint = { Color = { r, g, b }, Material = material, Transparency = transparency or 0 }

	return part
end

--[[
	@return Part -- a small hidden part with no lights, named PropLamp
]]
local function lamp(x: number, y: number, z: number): Part
	local part = S(x, y, z, 0.1)

	part.lamp = true

	return part
end

--[[
	@param brightness number -- of the point light; the spot light is a little weaker
	@param range number -- of the point light; the spot light reaches a little further
	@return Part -- a small hidden part, named Config, that holds the prop's point and spot lights
]]
local function lights(x: number, y: number, z: number, brightness: number, range: number): Part
	local part = S(x, y, z, 0.1)

	part.lights = { Brightness = brightness, Range = range }

	return part
end

--[[
	@param x number
	@param z number
	@param height number
	@param width number
	@return { Part } -- four legs in the corners of a rectangle centred on the origin
]]
local function legs(x: number, z: number, height: number, width: number): { Part }
	return {
		B(-x, height / 2, -z, width, height, width),
		B(x, height / 2, -z, width, height, width),
		B(-x, height / 2, z, width, height, width),
		B(x, height / 2, z, width, height, width),
	}
end

--[[
	@param ... { Part }
	@return { Part } -- every part of every list, in order
]]
local function join(...: { Part }): { Part }
	local out: { Part } = {}

	for _, list in { ... } do
		for _, part in list do
			table.insert(out, part)
		end
	end

	return out
end

--[[
	@param part Part
	@return Part -- the same shape in brushed steel that the color themes leave alone
]]
local function steel(part: Part): Part
	return painted(part, 0.72, 0.74, 0.77, "Metal")
end

--[[
	@param part Part
	@return Part -- the same shape in dark iron that the color themes leave alone
]]
local function iron(part: Part): Part
	return painted(part, 0.2, 0.2, 0.22, "Metal")
end

--[[
	@param x number
	@param z number
	@param height number
	@param width number
	@return { Part } -- four steel legs in the corners of a rectangle centred on the origin
]]
local function steelLegs(x: number, z: number, height: number, width: number): { Part }
	local out = legs(x, z, height, width)

	for _, part in out do
		steel(part)
	end

	return out
end

--[[
	@param width number
	@param height number
	@param z number -- where the case is centred front to back; a wall case sits at -0.8 so its back is on the wall
	@return { Part } -- a bookcase with shelves and a row of books on each
]]
local function bookcase(width: number, height: number, z: number): { Part }
	local parts: { Part } = {
		B(-width / 2 + 0.2, height / 2, z, 0.4, height, 1.6),
		B(width / 2 - 0.2, height / 2, z, 0.4, height, 1.6),
		B(0, height / 2, z + 0.7, width, height, 0.2),
		B(0, height - 0.15, z, width, 0.3, 1.6),
	}
	local rows = math.floor(height / 2.4)
	local gap = (height - 0.3) / rows

	for row = 0, rows - 1 do
		local shelf = 0.15 + row * gap

		table.insert(parts, B(0, shelf, z, width, 0.3, 1.6))

		local book = 0
		local x = -width / 2 + 0.8

		while x < width / 2 - 0.8 do
			local tall = 1.4 + (book % 3) * 0.25

			table.insert(parts, B(x, shelf + 0.15 + tall / 2, z - 0.1, 0.5, tall, 1.1, book % 2 == 0))

			book += 1
			x += 0.6
		end
	end

	return parts
end

--[[
	@return { Part } -- a floor cage of iron bars
]]
local function cage(): { Part }
	local parts: { Part } = {
		iron(B(0, 0.15, 0, 5, 0.3, 5)),
		iron(B(0, 5.85, 0, 5, 0.3, 5)),
	}

	for index = 0, 6 do
		local offset = -2.25 + index * 0.75

		table.insert(parts, iron(B(offset, 3, -2.35, 0.2, 5.4, 0.2)))
		table.insert(parts, iron(B(offset, 3, 2.35, 0.2, 5.4, 0.2)))

		if index > 0 and index < 6 then
			table.insert(parts, iron(B(-2.35, 3, offset, 0.2, 5.4, 0.2)))
			table.insert(parts, iron(B(2.35, 3, offset, 0.2, 5.4, 0.2)))
		end
	end

	return parts
end

--[[
	@return { Part } -- three iron chains hanging from a ceiling plate, each ending in a hook
]]
local function hangingChains(): { Part }
	local parts: { Part } = { iron(B(0, -0.1, 0, 6, 0.2, 1)) }

	for _, x in { -2, 0, 2 } do
		for link = 0, 7 do
			table.insert(parts, iron(S(x, -0.35 - link * 0.55, 0, 0.3)))
		end

		table.insert(parts, iron(S(x, -4.8, 0, 0.5)))
	end

	return parts
end

--[[
	@return { Part } -- a candle: a pale wax stick with a glowing flame, standing on y
]]
local function candle(x: number, y: number, z: number): { Part }
	return {
		painted(C(x, y + 0.45, z, 0.3, 0.9), 0.9, 0.85, 0.7, "SmoothPlastic"),
		glowing(S(x, y + 1.05, z, 0.25), 1, 0.7, 0.3),
	}
end

--[[
	@param width number
	@param height number
	@param y number -- where the bottom rail sits
	@param z number
	@return { Part } -- a panel of iron bars between a top and a bottom rail
]]
local function bars(width: number, height: number, y: number, z: number): { Part }
	local parts: { Part } = {
		iron(B(0, y + 0.15, z, width, 0.3, 0.4)),
		iron(B(0, y + height - 0.15, z, width, 0.3, 0.4)),
	}
	local count = math.floor(width / 0.7)

	for index = 0, count do
		local x = -width / 2 + 0.15 + index * (width - 0.3) / count

		table.insert(parts, iron(B(x, y + height / 2, z, 0.2, height - 0.4, 0.2)))
	end

	return parts
end

--[[
	@param width number
	@return { Part } -- a wall radiator: a row of white fins on a top and bottom rail, with a valve and two pipes down to the floor
]]
local function radiator(width: number): { Part }
	local white = { 0.93, 0.93, 0.92 }
	local function fin(part: Part): Part
		return painted(part, white[1], white[2], white[3], "SmoothPlastic")
	end

	local parts: { Part } = {
		fin(B(0, 3.1, -0.35, width, 0.25, 0.6)),
		fin(B(0, 1, -0.35, width, 0.25, 0.6)),
	}
	local count = math.floor(width / 0.6)

	for index = 0, count - 1 do
		local x = -width / 2 + 0.3 + index * (width - 0.6) / math.max(count - 1, 1)

		table.insert(parts, fin(B(x, 2.05, -0.35, 0.45, 2.0, 0.5)))
	end

	table.insert(parts, iron(B(-width / 2 + 0.15, 0.5, -0.2, 0.2, 1, 0.2)))
	table.insert(parts, iron(B(width / 2 - 0.15, 0.5, -0.2, 0.2, 1, 0.2)))
	table.insert(parts, iron(B(width / 2 - 0.15, 1.1, -0.5, 0.4, 0.3, 0.3)))
	table.insert(parts, iron(B(0, 1.9, -0.05, width - 0.8, 0.2, 0.1)))

	return parts
end

--[[
	@param part Part
	@return Part -- the same shape in dark walnut that the color themes leave alone
]]
local function walnut(part: Part): Part
	return painted(part, 0.33, 0.2, 0.11, "Wood")
end

--[[
	@param part Part
	@return Part -- the same shape in aged brass that the color themes leave alone
]]
local function brass(part: Part): Part
	return painted(part, 0.72, 0.55, 0.2, "Metal")
end

--[[
	@param part Part
	@return Part -- the same shape in worn brown leather that the color themes leave alone
]]
local function leather(part: Part): Part
	return painted(part, 0.28, 0.14, 0.08, "Leather")
end

--[[
	@param part Part
	@return Part -- the same shape in cream paper
]]
local function paper(part: Part): Part
	return painted(part, 0.92, 0.89, 0.78, "SmoothPlastic")
end

--[[
	@param cx number
	@param cz number
	@param turn number -- quarter turns; 0 puts the back on +Z and the seat facing -Z
	@param r number
	@param g number
	@param b number
	@return { Part } -- a child's chair in painted wood, centred at cx, cz
]]
local function kidsChair(cx: number, cz: number, turn: number, r: number, g: number, bl: number): { Part }
	local spec = {
		{ 0, 1.2, 0, 1.5, 0.15, 1.5 },
		{ -0.6, 0.55, -0.6, 0.18, 1.1, 0.18 },
		{ 0.6, 0.55, -0.6, 0.18, 1.1, 0.18 },
		{ -0.6, 0.55, 0.6, 0.18, 1.1, 0.18 },
		{ 0.6, 0.55, 0.6, 0.18, 1.1, 0.18 },
		{ -0.6, 2.1, 0.62, 0.18, 1.8, 0.18 },
		{ 0.6, 2.1, 0.62, 0.18, 1.8, 0.18 },
		{ 0, 2.5, 0.62, 1.1, 0.25, 0.12 },
		{ 0, 1.9, 0.62, 1.1, 0.25, 0.12 },
	}
	local parts: { Part } = {}

	for _, row in spec do
		local x, z, sx, sz = row[1], row[3], row[4], row[6]

		for _ = 1, turn % 4 do
			x, z = z, -x
			sx, sz = sz, sx
		end

		table.insert(parts, painted(B(cx + x, row[2], cz + z, sx, row[5], sz), r, g, bl, "Wood"))
	end

	return parts
end

--[[
	@return { Part } -- a child's low table: a top on four legs
]]
local function kidsTable(): { Part }
	return join(legs(1.9, 1.3, 2.1, 0.25), { B(0, 2.2, 0, 4.6, 0.2, 3.4) })
end

PropData.Categories = {
	{ Id = "Bathroom", Label = "Bathroom" },
	{ Id = "Bedroom", Label = "Bedroom" },
	{ Id = "Dining", Label = "Dining room" },
	{ Id = "Kitchen", Label = "Kitchen" },
	{ Id = "Living", Label = "Living room" },
	{ Id = "Hallway", Label = "Hallway" },
	{ Id = "Basement", Label = "Basement" },
	{ Id = "Attic", Label = "Attic" },
	{ Id = "Office", Label = "Office" },
	{ Id = "Outdoor", Label = "Outdoor" },
	{ Id = "Kids", Label = "Kids" },
	{ Id = "Shop", Label = "Shop and public" },
	{ Id = "Game", Label = "Game room" },
	{ Id = "Library", Label = "Library" },
	{ Id = "Dungeon", Label = "Jail and dungeon" },
	{ Id = "Electrical", Label = "Electrical room" },
	{ Id = "Art", Label = "Art room" },
	{ Id = "Lighting", Label = "Lighting" },
} :: { Category }

--[[
	@return { Part } -- a grand chandelier: a chain and stacked column, and two tiers of arms (four above, eight below) that each end in a candle with a glowing flame and a hanging crystal
]]
local function chandelier(): { Part }
	local parts: { Part } = {
		C(0, -0.12, 0, 1.3, 0.24, true),
		C(0, -0.32, 0, 0.5, 0.16),
		C(0, -1.3, 0, 0.1, 1.8),
		S(0, -2.3, 0, 0.8, true),
		C(0, -2.85, 0, 0.28, 0.5),
		S(0, -3.3, 0, 0.6, true),
		C(0, -3.7, 0, 0.2, 0.5),
		S(0, -4.1, 0, 0.5, true),
		C(0, -4.5, 0, 0.1, 0.4),
		S(0, -4.75, 0, 0.25),
	}

	--[[ One tier: `count` arms of length `reach` at height `y`, the first turned `phase` degrees. ]]
	local function tier(y: number, reach: number, count: number, phase: number)
		for index = 0, count - 1 do
			local degrees = phase + index * 360 / count
			local angle = math.rad(degrees)
			local ax, az = math.cos(angle), -math.sin(angle)
			local top = y + index * 0.012
			local ex, ez = ax * reach, az * reach

			table.insert(parts, turned(B(ax * reach / 2, top, az * reach / 2, reach, 0.1, 0.1, true), degrees))
			table.insert(parts, C(ex, top + 0.12, ez, 0.36, 0.14, true))
			table.insert(parts, C(ex, top + 0.38, ez, 0.18, 0.4))
			table.insert(parts, glowing(S(ex, top + 0.68, ez, 0.22), 1, 0.85, 0.55))
			table.insert(parts, S(ex, top - 0.3, ez, 0.22))
		end
	end

	tier(-2.9, 1.6, 4, 45)
	tier(-3.7, 2.8, 8, 0)
	table.insert(parts, lamp(0, -3.4, 0))
	table.insert(parts, lights(0, -3.4, 0, 0.4, 13))

	return parts
end

PropData.Props = {
	-- Lighting
	{
		Id = "CeilingLight",
		Label = "Ceiling light",
		Category = "Lighting",
		Mount = "ceiling",
		Model = "CeilingLight",
		Pivot = { 0, -0.12575912, 0 },
		Parts = {
			C(0, -0.0455, 0, 1.06, 0.091),
			glowing(C(0, -0.121, 0, 0.908, 0.061), 144 / 255, 135 / 255, 120 / 255),
			lamp(0, -0.068, 0),
			lights(0, 1.0501, 0, 0.3, 10),
		},
	},
	{
		Id = "GlobeLight",
		Label = "Globe light",
		Category = "Lighting",
		Mount = "ceiling",
		Parts = {
			C(0, -0.05, 0, 2.6, 0.1),
			halved(glowing(S(0, -0.1, 0, 2.4), 0.94, 0.9, 0.8)),
			S(0, -1.3, 0, 0.4, true),
			lamp(0, -0.5, 0),
			lights(0, -0.5, 0, 0.3, 11),
		},
	},
	{
		Id = "Chandelier",
		Label = "Chandelier",
		Category = "Lighting",
		Mount = "ceiling",
		Parts = chandelier(),
	},
	{
		Id = "DeskLamp",
		Label = "Desk lamp",
		Category = "Lighting",
		Mount = "floor",
		Parts = {
			painted(C(0, 0.12, 0, 1.5, 0.24), 0.72, 0.55, 0.2, "Metal"),
			painted(C(0, 0.3, 0, 0.9, 0.12), 0.72, 0.55, 0.2, "Metal"),
			painted(C(0, 0.95, 0, 0.16, 1.2), 0.72, 0.55, 0.2, "Metal"),
			painted(laid(C(0, 1.95, 0, 0.95, 2.2)), 0.1, 0.45, 0.22, "Glass", 0.35),
			painted(laid(C(-1.15, 1.95, 0, 0.7, 0.1)), 0.72, 0.55, 0.2, "Metal"),
			painted(laid(C(1.15, 1.95, 0, 0.7, 0.1)), 0.72, 0.55, 0.2, "Metal"),
			glowing(S(0, 1.85, 0, 0.45), 1, 0.85, 0.55),
			lamp(0, 1.85, 0),
			lights(0, 1.85, 0, 0.2, 7),
		},
	},
	{
		Id = "TableLamp",
		Label = "Table lamp",
		Category = "Lighting",
		Mount = "floor",
		Parts = {
			C(0, 0.6, 0, 1.2, 1.2),
			C(0, 1.5, 0, 0.2, 0.6),
			glowing(C(0, 2.1, 0, 1.8, 1.2), 1, 0.85, 0.55),
			lamp(0, 2.1, 0),
			lights(0, 2.1, 0, 0.2, 8),
		},
	},
	{
		Id = "CeilingFan",
		Label = "Ceiling fan",
		Category = "Lighting",
		Mount = "ceiling",
		Model = "CeilingFan",
		Pivot = { 0, -0.8615, 0 },
		Parts = {
			C(0, -0.1, 0, 1, 0.2),
			C(0, -0.55, 0, 0.18, 0.7),
			C(0, -1.175, 0, 1.5, 0.55),
			C(0, -1.437, 0, 0.9, 0.2),
			B(1.975, -1.175, 0, 2.45, 0.12, 0.8, true),
			B(-1.975, -1.175, 0, 2.45, 0.12, 0.8, true),
			B(0, -1.175, 1.975, 0.8, 0.12, 2.45, true),
			B(0, -1.175, -1.975, 0.8, 0.12, 2.45, true),
			glowing(S(0, -1.537, 0, 0.372), 1, 208 / 255, 128 / 255),
			lamp(0, -1.22, 0),
			lights(0, -1.4, 0, 0.3, 10),
		},
	},
	-- Bathroom
	{
		Id = "BathTub",
		Label = "Bath tub",
		Category = "Bathroom",
		Mount = "floor",
		Parts = {
			B(0, 0.2, 0, 7, 0.4, 3.2),
			B(0, 1.1, -1.4, 7, 1.8, 0.4),
			B(0, 1.1, 1.4, 7, 1.8, 0.4),
			B(-3.3, 1.1, 0, 0.4, 1.8, 2.4),
			B(3.3, 1.1, 0, 0.4, 1.8, 2.4),
			B(3.0, 2.3, 0, 0.4, 0.9, 0.4, true),
		},
	},
	{
		Id = "Sink",
		Label = "Sink and vanity",
		Category = "Bathroom",
		Mount = "floor",
		Parts = {
			B(0, 1.3, 0, 3.4, 2.6, 1.8),
			B(0, 2.7, 0, 3.7, 0.2, 2.1),
			B(0, 2.85, 0, 1.8, 0.1, 1.2, true),
			B(0, 3.3, 0.6, 0.25, 0.9, 0.25, true),
		},
	},
	{
		Id = "Toilet",
		Label = "Toilet",
		Category = "Bathroom",
		Mount = "floor",
		Parts = {
			B(0, 0.9, -0.3, 1.6, 1.8, 2.2),
			B(0, 2.2, 0.8, 1.9, 2.0, 0.8),
			B(0, 1.9, -0.3, 1.7, 0.2, 2.0, true),
		},
	},
	{
		Id = "MirrorCabinet",
		Label = "Mirror cabinet",
		Category = "Bathroom",
		Mount = "wall",
		Parts = {
			B(0, 1.6, -0.5, 2.8, 3.2, 1),
			B(0, 1.6, -1.05, 2.4, 2.8, 0.1, true),
		},
	},
	{
		Id = "LaundryBasket",
		Label = "Laundry basket",
		Category = "Bathroom",
		Mount = "floor",
		Parts = {
			C(0, 1.4, 0, 2.2, 2.8),
			C(0, 2.85, 0, 2.4, 0.2, true),
		},
	},

	-- Bedroom
	{
		Id = "Bed",
		Label = "Bed",
		Category = "Bedroom",
		Mount = "floor",
		Parts = join({
			B(0, 1, 0, 6, 1.4, 7.6),
			B(0, 2.1, -0.2, 5.6, 0.8, 7),
			B(-1.5, 2.8, 2.8, 2.2, 0.6, 1.4, true),
			B(1.5, 2.8, 2.8, 2.2, 0.6, 1.4, true),
			B(0, 3.2, 3.9, 6.2, 4.4, 0.4),
		}, legs(2.8, 3.6, 0.3, 0.4)),
	},
	{
		Id = "Nightstand",
		Label = "Nightstand",
		Category = "Bedroom",
		Mount = "floor",
		Parts = {
			B(0, 1.1, 0, 2, 2.2, 2),
			B(0, 2.3, 0, 2.2, 0.2, 2.2),
			B(0, 1.5, -1.05, 0.8, 0.15, 0.15, true),
		},
	},
	{
		Id = "Wardrobe",
		Label = "Wardrobe",
		Category = "Bedroom",
		Mount = "floor",
		Parts = {
			B(0, 4, 0, 5, 8, 2.2),
			B(-0.3, 4, -1.15, 0.15, 7.6, 0.15, true),
			B(0.3, 4, -1.15, 0.15, 7.6, 0.15, true),
			B(-0.6, 4, -1.2, 0.2, 1, 0.2, true),
			B(0.6, 4, -1.2, 0.2, 1, 0.2, true),
		},
	},
	{
		Id = "Dresser",
		Label = "Dresser",
		Category = "Bedroom",
		Mount = "floor",
		Parts = {
			B(0, 1.8, 0, 5, 3.6, 2.2),
			B(0, 3.7, 0, 5.2, 0.2, 2.4),
			B(-1.2, 2.6, -1.15, 1.2, 0.15, 0.15, true),
			B(1.2, 2.6, -1.15, 1.2, 0.15, 0.15, true),
			B(-1.2, 1.2, -1.15, 1.2, 0.15, 0.15, true),
			B(1.2, 1.2, -1.15, 1.2, 0.15, 0.15, true),
		},
	},

	-- Dining room
	{
		Id = "DiningTable",
		Label = "Dining table",
		Category = "Dining",
		Mount = "floor",
		Parts = join({ B(0, 3.0, 0, 8, 0.4, 4) }, legs(3.6, 1.6, 2.8, 0.5)),
	},
	{
		Id = "DiningChair",
		Label = "Dining chair",
		Category = "Dining",
		Mount = "floor",
		Parts = join({
			B(0, 1.9, 0, 1.8, 0.3, 1.8),
			B(0, 3.4, 0.8, 1.8, 2.8, 0.25),
			B(0, 1.9, 0, 1.4, 0.15, 1.4, true),
		}, legs(0.75, 0.75, 1.75, 0.25)),
	},
	{
		Id = "Sideboard",
		Label = "Sideboard",
		Category = "Dining",
		Mount = "floor",
		Parts = {
			B(0, 2, 0, 7, 4, 1.8),
			B(0, 4.1, 0, 7.2, 0.2, 2),
			B(-1.8, 2.2, -0.95, 0.2, 1, 0.2, true),
			B(1.8, 2.2, -0.95, 0.2, 1, 0.2, true),
		},
	},
	{
		Id = "ChinaCabinet",
		Label = "China cabinet",
		Category = "Dining",
		Mount = "floor",
		Parts = {
			B(0, 4.5, 0.2, 4, 9, 1.2),
			B(0, 1.6, -0.5, 4, 3.2, 0.6),
			B(0, 5.9, -0.45, 3.4, 5.4, 0.1, true),
			B(0, 9.1, 0, 4.4, 0.3, 2),
		},
	},

	-- Kitchen
	{
		Id = "Counter",
		Label = "Counter",
		Category = "Kitchen",
		Mount = "floor",
		Parts = {
			B(0, 1.8, 0, 6, 3.6, 2.4),
			B(0, 3.7, 0, 6.2, 0.2, 2.6, true),
		},
	},
	{
		Id = "Fridge",
		Label = "Fridge",
		Category = "Kitchen",
		Mount = "floor",
		Parts = {
			B(0, 3.5, 0, 3, 7, 3),
			B(-1.0, 4.8, -1.6, 0.2, 2, 0.2, true),
			B(-1.0, 2.2, -1.6, 0.2, 1.6, 0.2, true),
		},
	},
	{
		Id = "Stove",
		Label = "Stove",
		Category = "Kitchen",
		Mount = "floor",
		Parts = {
			B(0, 1.8, 0, 3, 3.6, 2.8),
			C(-0.7, 3.65, -0.6, 0.9, 0.1, true),
			C(0.7, 3.65, -0.6, 0.9, 0.1, true),
			C(-0.7, 3.65, 0.6, 0.9, 0.1, true),
			C(0.7, 3.65, 0.6, 0.9, 0.1, true),
			B(0, 3.8, 1.3, 3, 1.4, 0.2),
		},
	},
	{
		Id = "Island",
		Label = "Kitchen island",
		Category = "Kitchen",
		Mount = "floor",
		Parts = {
			B(0, 1.8, 0, 8, 3.6, 4),
			B(0, 3.7, 0, 8.4, 0.2, 4.4, true),
		},
	},

	-- Living room and general furniture
	{
		Id = "Sofa",
		Label = "Sofa",
		Category = "Living",
		Mount = "floor",
		Parts = {
			B(0, 1.0, 0, 8, 2, 3.4),
			B(0, 3.2, 1.45, 8, 2.6, 0.8),
			B(-2, 2.35, -0.3, 3.4, 0.7, 2.6, true),
			B(2, 2.35, -0.3, 3.4, 0.7, 2.6, true),
			B(-3.85, 2.4, 0, 0.5, 2.8, 3.4),
			B(3.85, 2.4, 0, 0.5, 2.8, 3.4),
		},
	},
	{
		Id = "Armchair",
		Label = "Armchair",
		Category = "Living",
		Mount = "floor",
		Parts = {
			B(0, 1.0, 0, 3.6, 2, 3.2),
			B(0, 3.2, 1.35, 3.6, 2.6, 0.5),
			B(0, 2.35, -0.3, 2.6, 0.7, 2.4, true),
			B(-1.75, 2.4, 0, 0.5, 2.8, 3.2),
			B(1.75, 2.4, 0, 0.5, 2.8, 3.2),
		},
	},
	{
		Id = "CoffeeTable",
		Label = "Coffee table",
		Category = "Living",
		Mount = "floor",
		Parts = join({ B(0, 1.6, 0, 4.2, 0.3, 2.4) }, legs(1.8, 0.9, 1.45, 0.3)),
	},
	{
		Id = "Bookshelf",
		Label = "Bookshelf",
		Category = "Living",
		Mount = "floor",
		Parts = {
			B(-2.1, 4, 0, 0.3, 8, 1.4),
			B(2.1, 4, 0, 0.3, 8, 1.4),
			B(0, 4, 0.65, 4.5, 8, 0.1),
			B(0, 0.15, 0, 4, 0.3, 1.4),
			B(0, 2.2, 0, 4, 0.2, 1.4),
			B(0, 4.2, 0, 4, 0.2, 1.4),
			B(0, 6.2, 0, 4, 0.2, 1.4),
			B(0, 8.1, 0, 4.5, 0.2, 1.5),
			B(-1.0, 3.2, 0, 1.4, 1.8, 0.9, true),
			B(1.0, 5.2, 0, 1.8, 1.8, 0.9, true),
			B(-0.6, 7.2, 0, 1.6, 1.8, 0.9, true),
		},
	},
	{
		Id = "TvStand",
		Label = "TV and stand",
		Category = "Living",
		Mount = "floor",
		Parts = {
			B(0, 1.2, 0, 6, 2.4, 1.8),
			B(0, 4.4, 0.3, 5, 3, 0.3, true),
			B(0, 2.7, 0.3, 0.8, 0.6, 0.6),
		},
	},
	{
		Id = "Desk",
		Label = "Desk",
		Category = "Living",
		Mount = "floor",
		Parts = join({
			B(0, 3, 0, 6, 0.3, 2.8),
			B(2.0, 1.9, 0, 1.8, 2.2, 2.4),
		}, legs(2.7, 1.2, 2.85, 0.3)),
	},
	{
		Id = "OfficeChair",
		Label = "Office chair",
		Category = "Living",
		Mount = "floor",
		Parts = {
			C(0, 0.25, 0, 2.4, 0.3),
			C(0, 1.1, 0, 0.4, 1.8),
			B(0, 2.1, 0, 2, 0.4, 2),
			B(0, 3.6, 0.9, 2, 2.6, 0.3, true),
		},
	},
	{
		Id = "Rug",
		Label = "Rug",
		Category = "Living",
		Mount = "floor",
		Parts = {
			B(0, 0.05, 0, 9, 0.1, 6, true),
		},
	},
	{
		Id = "FloorLamp",
		Label = "Floor lamp",
		Category = "Lighting",
		Mount = "floor",
		Parts = {
			C(0, 0.15, 0, 1.4, 0.3),
			C(0, 3.1, 0, 0.25, 6),
			glowing(C(0, 6.4, 0, 1.9, 1.4), 1, 0.85, 0.55),
			lamp(0, 6.4, 0),
			lights(0, 6.4, 0, 0.25, 10),
		},
	},

	-- Hallway
	{
		Id = "PottedPlant",
		Label = "Potted plant",
		Category = "Hallway",
		Mount = "floor",
		Parts = {
			C(0, 0.9, 0, 1.9, 1.8),
			S(0, 3.0, 0, 3.0, true),
			S(0.7, 4.0, 0.3, 1.8, true),
		},
	},
	{
		Id = "TallPlant",
		Label = "Tall plant",
		Category = "Hallway",
		Mount = "floor",
		Parts = {
			C(0, 1.1, 0, 2.2, 2.2),
			C(0, 3.6, 0, 0.3, 4.8),
			S(0, 6.2, 0, 3.2, true),
			S(-0.9, 5.0, 0.5, 1.8, true),
			S(0.9, 4.4, -0.5, 1.6, true),
		},
	},
	{
		Id = "ConsoleTable",
		Label = "Console table",
		Category = "Hallway",
		Mount = "floor",
		Parts = join({ B(0, 3, 0, 5, 0.3, 1.4) }, legs(2.2, 0.5, 2.85, 0.3)),
	},
	{
		Id = "CoatRack",
		Label = "Coat rack",
		Category = "Hallway",
		Mount = "floor",
		Parts = {
			C(0, 0.15, 0, 1.8, 0.3),
			C(0, 3.5, 0, 0.3, 7),
			B(0, 6.6, 0, 1.6, 0.2, 0.2, true),
			B(0, 6.6, 0, 0.2, 0.2, 1.6, true),
		},
	},
	{
		Id = "Bench",
		Label = "Hall bench",
		Category = "Hallway",
		Mount = "floor",
		Parts = join({
			B(0, 1.9, 0, 5, 0.4, 1.8),
			B(0, 2.15, 0, 4.4, 0.15, 1.4, true),
		}, legs(2.2, 0.6, 1.7, 0.3)),
	},

	-- Basement
	{
		Id = "Crate",
		Label = "Crate",
		Category = "Basement",
		Mount = "floor",
		Parts = {
			B(0, 1.25, 0, 2.5, 2.5, 2.5),
			B(0, 1.25, -1.3, 2.6, 0.3, 0.1, true),
			B(0, 0.4, -1.3, 2.6, 0.3, 0.1, true),
			B(0, 2.1, -1.3, 2.6, 0.3, 0.1, true),
		},
	},
	{
		Id = "CrateStack",
		Label = "Crate stack",
		Category = "Basement",
		Mount = "floor",
		Parts = {
			B(-1.4, 1.25, 0, 2.5, 2.5, 2.5),
			B(1.4, 1.25, 0.3, 2.5, 2.5, 2.5),
			B(-0.3, 3.75, 0.1, 2.5, 2.5, 2.5),
		},
	},
	{
		Id = "Barrel",
		Label = "Barrel",
		Category = "Basement",
		Mount = "floor",
		Parts = {
			C(0, 1.5, 0, 2.2, 3),
			C(0, 0.6, 0, 2.35, 0.2, true),
			C(0, 2.4, 0, 2.35, 0.2, true),
		},
	},
	{
		Id = "Shelving",
		Label = "Storage shelving",
		Category = "Basement",
		Mount = "floor",
		Parts = join({
			B(0, 1.2, 0, 6, 0.2, 1.8),
			B(0, 3.8, 0, 6, 0.2, 1.8),
			B(0, 6.4, 0, 6, 0.2, 1.8),
			B(-1.5, 2.0, 0, 1.6, 1.6, 1.2, true),
			B(1.4, 4.6, 0, 2.2, 1.6, 1.2, true),
		}, legs(2.9, 0.8, 7, 0.2)),
	},
	{
		Id = "WaterHeater",
		Label = "Water heater",
		Category = "Basement",
		Mount = "floor",
		Parts = {
			C(0, 3, 0, 2.6, 6),
			C(0, 6.1, 0, 2.7, 0.3, true),
			C(0.6, 7.2, 0, 0.4, 2),
		},
	},
	{
		Id = "Workbench",
		Label = "Workbench",
		Category = "Basement",
		Mount = "floor",
		Parts = join({
			B(0, 3.2, 0, 7, 0.4, 2.8),
			B(0, 1.6, 1.2, 6.6, 0.2, 0.4),
			B(-1.5, 3.7, 0, 1.2, 0.6, 1.2, true),
		}, legs(3.2, 1.2, 3.0, 0.4)),
	},

	-- Attic
	{
		Id = "Trunk",
		Label = "Trunk",
		Category = "Attic",
		Mount = "floor",
		Parts = {
			B(0, 1, 0, 3.5, 2, 2),
			B(0, 2.15, 0, 3.6, 0.3, 2.1, true),
			B(0, 1.2, -1.05, 0.5, 0.6, 0.1, true),
		},
	},
	{
		Id = "BoxStack",
		Label = "Box stack",
		Category = "Attic",
		Mount = "floor",
		Parts = {
			B(-1.2, 1, 0, 2.6, 2, 2.2),
			B(1.4, 0.8, 0.4, 2, 1.6, 2),
			B(-0.9, 2.6, 0.2, 2.2, 1.2, 1.8),
			B(1.3, 2.0, 0.3, 1.4, 0.8, 1.4, true),
		},
	},
	{
		Id = "StandingMirror",
		Label = "Standing mirror",
		Category = "Attic",
		Mount = "floor",
		Parts = {
			B(0, 3.5, 0, 3, 7, 0.4),
			B(0, 3.6, -0.25, 2.5, 6.2, 0.1, true),
			B(-1.4, 0.3, 0.5, 0.3, 0.6, 1.4),
			B(1.4, 0.3, 0.5, 0.3, 0.6, 1.4),
		},
	},
	{
		Id = "CoveredFurniture",
		Label = "Covered furniture",
		Category = "Attic",
		Mount = "floor",
		Parts = {
			B(0, 1.5, 0, 5, 3, 3.2, true),
			B(0, 3.1, 0.3, 4.4, 0.4, 2.6, true),
			B(0, 2.0, 1.2, 5, 4, 0.8, true),
		},
	},
	-- More bathroom
	{
		Id = "ShowerStall",
		Label = "Shower stall",
		Category = "Bathroom",
		Mount = "floor",
		Parts = {
			B(0, 0.2, 0, 3.6, 0.4, 3.6),
			B(0, 3.4, 1.7, 3.6, 6.2, 0.2),
			B(-1.7, 3.4, 0, 0.2, 6.2, 3.6),
			B(1.7, 3.4, 0, 0.2, 6.2, 3.6),
			B(0, 6.6, 0, 3.6, 0.2, 3.6),
			B(0, 5, 1.4, 0.5, 0.5, 0.5, true),
		},
	},
	{
		Id = "DoubleSink",
		Label = "Double sink",
		Category = "Bathroom",
		Mount = "floor",
		Parts = {
			B(0, 1.3, 0, 6.6, 2.6, 1.8),
			B(0, 2.7, 0, 6.9, 0.2, 2.1),
			B(-1.5, 2.85, 0, 1.8, 0.1, 1.2, true),
			B(1.5, 2.85, 0, 1.8, 0.1, 1.2, true),
			B(-1.5, 3.3, 0.6, 0.25, 0.9, 0.25, true),
			B(1.5, 3.3, 0.6, 0.25, 0.9, 0.25, true),
		},
	},
	{
		Id = "TowelRack",
		Label = "Towel rack",
		Category = "Bathroom",
		Mount = "wall",
		Parts = {
			B(-1.4, 2, -0.3, 0.2, 4, 0.6),
			B(1.4, 2, -0.3, 0.2, 4, 0.6),
			B(0, 3.6, -0.6, 3, 0.15, 0.15, true),
			B(0, 2.6, -0.6, 3, 0.15, 0.15, true),
			B(0, 3.0, -0.65, 2.6, 1.3, 0.2, true),
		},
	},
	{
		Id = "TowelBar",
		Label = "Towel bar",
		Category = "Bathroom",
		Mount = "wall",
		Parts = {
			B(-2.1, 4.6, -0.3, 0.25, 0.5, 0.6),
			B(2.1, 4.6, -0.3, 0.25, 0.5, 0.6),
			laid(C(0, 4.9, -0.6, 0.18, 4.4)),
			painted(B(0, 3.6, -0.7, 3.4, 2.6, 0.25), 0.9, 0.9, 0.86, "Fabric"),
			painted(B(0, 2.5, -0.7, 3.4, 0.2, 0.3), 0.3, 0.45, 0.65, "Fabric"),
		},
	},
	{
		Id = "TowelStand",
		Label = "Towel stand",
		Category = "Bathroom",
		Mount = "floor",
		Parts = {
			B(0, 0.15, 0, 3, 0.3, 1.6),
			B(-1.3, 2.9, 0, 0.2, 5.4, 0.2),
			B(1.3, 2.9, 0, 0.2, 5.4, 0.2),
			B(-1.3, 5.7, 0, 0.3, 0.3, 0.3),
			B(1.3, 5.7, 0, 0.3, 0.3, 0.3),
			B(0, 5.0, 0, 2.6, 0.16, 0.16),
			B(0, 3.8, 0, 2.6, 0.16, 0.16),
			B(0, 2.6, 0, 2.6, 0.16, 0.16),
			painted(B(0, 4.0, 0.1, 2.4, 2, 0.12), 0.88, 0.88, 0.84, "Fabric"),
			painted(B(0, 2.8, 0.1, 2.4, 1.4, 0.12), 0.35, 0.5, 0.7, "Fabric"),
		},
	},
	{
		Id = "ToiletRoll",
		Label = "Toilet roll holder",
		Category = "Bathroom",
		Mount = "wall",
		Parts = {
			B(0, 3.4, -0.15, 0.5, 1.2, 0.3),
			B(0, 3.7, -0.5, 0.2, 0.2, 0.7),
			painted(laid(C(0, 3.7, -0.6, 1.5, 1.6)), 0.95, 0.95, 0.93, "SmoothPlastic"),
			painted(laid(C(0, 3.7, -0.6, 0.6, 1.7)), 0.7, 0.6, 0.45, "SmoothPlastic"),
			painted(B(0, 3.05, -1.0, 1.4, 1.2, 0.04), 0.95, 0.95, 0.93, "SmoothPlastic"),
		},
	},
	{
		Id = "BathMat",
		Label = "Bath mat",
		Category = "Bathroom",
		Mount = "floor",
		Parts = {
			painted(B(0, 0.08, 0, 4.4, 0.16, 2.8), 0.3, 0.5, 0.65, "Fabric"),
			painted(B(0, 0.18, 0, 3.8, 0.12, 2.2), 0.45, 0.65, 0.8, "Fabric"),
		},
	},
	{
		Id = "ShowerCurtain",
		Label = "Shower curtain",
		Category = "Bathroom",
		Mount = "floor",
		Parts = {
			iron(laid(C(0, 7, 0, 0.2, 6.4))),
			iron(B(-3.2, 4.5, 0, 0.2, 5, 0.2)),
			iron(B(3.2, 4.5, 0, 0.2, 5, 0.2)),
			painted(B(0, 4, 0, 6, 6, 0.1), 0.75, 0.88, 0.92, "Fabric", 0.35),
			painted(B(0, 6.9, 0, 6, 0.3, 0.14), 0.6, 0.78, 0.85, "Fabric"),
			painted(B(0, 1.1, 0, 6, 0.2, 0.14), 0.6, 0.78, 0.85, "Fabric"),
		},
	},
	{
		Id = "ClawfootTub",
		Label = "Clawfoot tub",
		Category = "Bathroom",
		Mount = "floor",
		Parts = {
			B(-2.6, 0.4, -1, 0.5, 0.8, 0.5),
			B(2.6, 0.4, -1, 0.5, 0.8, 0.5),
			B(-2.6, 0.4, 1, 0.5, 0.8, 0.5),
			B(2.6, 0.4, 1, 0.5, 0.8, 0.5),
			B(0, 1.6, 0, 6.2, 1.6, 3),
			B(0, 2.45, 0, 5.4, 0.1, 2.2, true),
			B(2.9, 3.3, 0, 0.4, 1.7, 0.4, true),
		},
	},
	-- More bedroom
	{
		Id = "BunkBed",
		Label = "Bunk bed",
		Category = "Bedroom",
		Mount = "floor",
		Parts = join(legs(2.9, 1.9, 6.4, 0.4), {
			B(0, 1.8, 0, 5.8, 0.8, 3.6),
			B(0, 1.5, 0, 5.8, 0.2, 3.6, true),
			B(0, 4.4, 0, 5.8, 0.8, 3.6),
			B(0, 4.1, 0, 5.8, 0.2, 3.6, true),
			B(0, 5.6, -1.9, 5.8, 0.6, 0.15),
			B(3.1, 3, 0, 0.3, 6, 0.6),
		}),
	},
	{
		Id = "Crib",
		Label = "Crib",
		Category = "Bedroom",
		Mount = "floor",
		Parts = join(legs(2.3, 1.4, 4, 0.3), {
			B(0, 1.6, 0, 4.4, 0.3, 2.6),
			B(0, 1.9, 0, 4.2, 0.4, 2.4, true),
			B(0, 3.2, -1.4, 4.6, 2, 0.15),
			B(0, 3.2, 1.4, 4.6, 2, 0.15),
			B(-2.3, 3.2, 0, 0.15, 2, 2.8),
			B(2.3, 3.2, 0, 0.15, 2, 2.8),
		}),
	},
	{
		Id = "VanityTable",
		Label = "Vanity table",
		Category = "Bedroom",
		Mount = "floor",
		Parts = join(legs(1.7, 0.7, 2.6, 0.3), {
			B(0, 2.7, 0, 4, 0.2, 1.8),
			B(0, 1.9, 0, 3.4, 0.9, 1.5),
			B(0, 4.6, 0.8, 2.6, 3.4, 0.15, true),
			B(1.2, 3, -0.2, 0.5, 0.5, 0.5, true),
		}),
	},
	{
		Id = "HighCabinet",
		Label = "Wall cabinet",
		Category = "Bedroom",
		Mount = "wall",
		Parts = {
			B(0, 1.5, -0.8, 3.6, 3, 1.6),
			B(-0.9, 1.5, -1.65, 1.6, 2.6, 0.1, true),
			B(0.9, 1.5, -1.65, 1.6, 2.6, 0.1, true),
		},
	},
	-- More kitchen
	{
		Id = "RangeHood",
		Label = "Range with hood",
		Category = "Kitchen",
		Mount = "floor",
		Parts = {
			B(0, 1.5, 0, 3.6, 3, 2.8),
			B(0, 3.05, 0, 3.6, 0.1, 2.8, true),
			B(0, 1.6, -1.45, 3, 1.6, 0.1, true),
			B(0, 6.2, 0.7, 3.6, 1.4, 1.4),
			B(0, 8.1, 1.1, 1.2, 2.4, 0.8),
			B(0, 5.4, 0, 3.8, 0.3, 2.8),
		},
	},
	{
		Id = "Pantry",
		Label = "Pantry cabinet",
		Category = "Kitchen",
		Mount = "floor",
		Parts = {
			B(0, 3.6, 0, 4, 7.2, 2.2),
			B(-0.95, 3.6, -1.15, 1.8, 6.6, 0.1, true),
			B(0.95, 3.6, -1.15, 1.8, 6.6, 0.1, true),
		},
	},
	{
		Id = "BreakfastBar",
		Label = "Breakfast bar",
		Category = "Kitchen",
		Mount = "floor",
		Parts = join({
			B(0, 1.8, 0.8, 7, 3.6, 1.6),
			B(0, 3.7, 0.4, 7.4, 0.2, 2.6, true),
		}, {
			C(-2.2, 1.3, -2, 1.4, 0.2, true),
			C(-2.2, 0.6, -2, 0.3, 1.2),
			C(0, 1.3, -2, 1.4, 0.2, true),
			C(0, 0.6, -2, 0.3, 1.2),
			C(2.2, 1.3, -2, 1.4, 0.2, true),
			C(2.2, 0.6, -2, 0.3, 1.2),
		}),
	},
	{
		Id = "Dishwasher",
		Label = "Dishwasher",
		Category = "Kitchen",
		Mount = "floor",
		Parts = {
			B(0, 1.5, 0, 3, 3, 2.6),
			B(0, 1.5, -1.35, 2.7, 2.6, 0.1, true),
			B(0, 2.5, -1.5, 1.8, 0.2, 0.2),
		},
	},
	-- More living room
	{
		Id = "Fireplace",
		Label = "Fireplace",
		Category = "Living",
		Mount = "wall",
		Parts = {
			B(0, 0.5, -1.1, 7, 1, 2.2),
			B(0, 4.0, -0.9, 6, 6, 1.8),
			B(0, 2, -1.85, 3.4, 3, 0.2, true),
			B(0, 3.6, -1.7, 3.8, 0.5, 0.5),
			B(0, 7.6, -1.5, 7.4, 0.5, 2.8, true),
			B(0, 11, -0.6, 3.6, 7, 1.2),
		},
	},
	{
		Id = "Piano",
		Label = "Piano",
		Category = "Living",
		Mount = "floor",
		Parts = join({
			B(0, 3.2, 0.6, 5.6, 2.2, 2.2),
			B(0, 2.5, -0.9, 5.6, 0.4, 1),
			B(0, 2.75, -1.2, 5.2, 0.1, 0.8, true),
			B(0, 4.6, 0.9, 5.6, 0.6, 1.6),
			B(0, 6.2, 1.5, 5.6, 2.6, 0.4),
		}, legs(2.6, 0.5, 2.1, 0.5)),
	},
	{
		Id = "GrandfatherClock",
		Label = "Grandfather clock",
		Category = "Living",
		Mount = "floor",
		Parts = {
			B(0, 0.5, 0, 2.2, 1, 1.6),
			B(0, 3.5, 0, 1.8, 5, 1.2),
			B(0, 6.8, 0, 2.2, 2, 1.4),
			C(0, 6.8, -0.75, 1.5, 0.15, true),
			B(0, 3.6, -0.65, 1, 3.2, 0.1, true),
			B(0, 8, 0, 2.4, 0.4, 1.6),
		},
	},
	{
		Id = "Aquarium",
		Label = "Aquarium on stand",
		Category = "Living",
		Mount = "floor",
		Parts = {
			B(0, 1.6, 0, 5.4, 3.2, 2.2),
			B(0, 4.1, 0, 5.2, 1.8, 2),
			B(0, 5.2, 0, 5.4, 0.4, 2.2, true),
			B(0, 3.6, 0, 3, 0.5, 1.4, true),
		},
	},
	{
		Id = "RecordCabinet",
		Label = "Record cabinet",
		Category = "Living",
		Mount = "floor",
		Parts = join(legs(2, 0.8, 1, 0.3), {
			B(0, 2.2, 0, 4.6, 2.4, 2),
			B(0, 3.5, 0, 3.4, 0.3, 1.6, true),
			C(-0.6, 3.7, 0, 1.4, 0.1, true),
		}),
	},
	{
		Id = "Ottoman",
		Label = "Ottoman",
		Category = "Living",
		Mount = "floor",
		Parts = {
			B(0, 0.5, 0, 3, 1, 3),
			B(0, 1.1, 0, 3.2, 0.3, 3.2, true),
		},
	},
	{
		Id = "WindowSeat",
		Label = "Window seat",
		Category = "Living",
		Mount = "floor",
		Parts = {
			B(0, 0.9, 0, 6.4, 1.8, 2),
			B(0, 2, 0, 6.2, 0.4, 1.8, true),
			B(0, 3, 0.8, 6.2, 1.8, 0.4, true),
		},
	},
	{
		Id = "Radiator",
		Label = "Radiator",
		Category = "Living",
		Mount = "wall",
		Parts = radiator(4.2),
	},
	{
		Id = "WastepaperBasket",
		Label = "Wastepaper basket",
		Category = "Hallway",
		Mount = "floor",
		Parts = {
			painted(C(0, 0.9, 0, 1.4, 1.8), 0.7, 0.55, 0.32, "Fabric"),
			painted(C(0, 1.85, 0, 1.6, 0.15), 0.55, 0.42, 0.24, "Fabric"),
			painted(C(0, 0.1, 0, 1.5, 0.2), 0.55, 0.42, 0.24, "Fabric"),
			painted(B(0, 1.6, 0, 1.1, 0.5, 1.1), 0.9, 0.88, 0.8, "Fabric"),
		},
	},
	{
		Id = "GalvanizedBin",
		Label = "Galvanized bin",
		Category = "Hallway",
		Mount = "floor",
		Parts = {
			painted(C(0, 1.6, 0, 1.8, 3.2), 0.62, 0.65, 0.68, "Metal"),
			painted(C(0, 3.3, 0, 2, 0.2), 0.5, 0.53, 0.56, "Metal"),
			painted(C(0, 3.55, 0, 0.5, 0.3), 0.4, 0.42, 0.45, "Metal"),
			iron(B(-0.95, 2.4, 0, 0.15, 0.7, 0.4)),
			iron(B(0.95, 2.4, 0, 0.15, 0.7, 0.4)),
			painted(C(0, 1.1, 0, 1.9, 0.12), 0.5, 0.53, 0.56, "Metal"),
			painted(C(0, 2.2, 0, 1.9, 0.12), 0.5, 0.53, 0.56, "Metal"),
		},
	},
	{
		Id = "PedalBin",
		Label = "Enamel pedal bin",
		Category = "Hallway",
		Mount = "floor",
		Parts = {
			painted(C(0, 1.3, 0, 1.5, 2.6), 0.92, 0.92, 0.88, "SmoothPlastic"),
			painted(C(0, 2.7, 0, 1.6, 0.25), 0.15, 0.2, 0.45, "SmoothPlastic"),
			painted(C(0, 2.9, 0, 0.3, 0.2), 0.15, 0.2, 0.45, "SmoothPlastic"),
			painted(C(0, 0.1, 0, 1.6, 0.2), 0.15, 0.2, 0.45, "SmoothPlastic"),
			iron(B(0, 0.4, -0.95, 0.5, 0.15, 0.5)),
		},
	},
	{
		Id = "HallDresser",
		Label = "Hall dresser",
		Category = "Hallway",
		Mount = "floor",
		Parts = join(legs(2.6, 1, 0.7, 0.35), {
			B(0, 2.4, 0, 6.4, 3.4, 2.2),
			B(0, 4.25, 0, 6.8, 0.3, 2.5, true),
			B(-1.6, 3.4, -1.12, 3, 1, 0.08, true),
			B(1.6, 3.4, -1.12, 3, 1, 0.08, true),
			B(-1.6, 2.2, -1.12, 3, 1, 0.08, true),
			B(1.6, 2.2, -1.12, 3, 1, 0.08, true),
			B(0, 1.1, -1.12, 6, 0.9, 0.08, true),
			brass(S(-1.6, 3.4, -1.22, 0.3)),
			brass(S(1.6, 3.4, -1.22, 0.3)),
			brass(S(-1.6, 2.2, -1.22, 0.3)),
			brass(S(1.6, 2.2, -1.22, 0.3)),
			brass(B(0, 1.1, -1.22, 0.8, 0.15, 0.1)),
		}),
	},
	{
		Id = "TallboyDresser",
		Label = "Tallboy chest",
		Category = "Hallway",
		Mount = "floor",
		Parts = join(legs(1.5, 0.8, 0.7, 0.35), {
			B(0, 4.2, 0, 4.2, 6.8, 2),
			B(0, 7.75, 0, 4.6, 0.3, 2.3, true),
			B(0, 6.6, -1.02, 3.6, 1.1, 0.08, true),
			B(0, 5.3, -1.02, 3.6, 1.1, 0.08, true),
			B(0, 4, -1.02, 3.6, 1.1, 0.08, true),
			B(0, 2.7, -1.02, 3.6, 1.1, 0.08, true),
			B(0, 1.5, -1.02, 3.6, 0.9, 0.08, true),
			brass(B(0, 6.6, -1.12, 0.8, 0.15, 0.1)),
			brass(B(0, 5.3, -1.12, 0.8, 0.15, 0.1)),
			brass(B(0, 4, -1.12, 0.8, 0.15, 0.1)),
			brass(B(0, 2.7, -1.12, 0.8, 0.15, 0.1)),
		}),
	},
	{
		Id = "Hallstand",
		Label = "Hall stand",
		Category = "Hallway",
		Mount = "floor",
		Parts = {
			B(0, 0.5, 0, 4.4, 1, 1.2),
			B(0, 4.5, 0.4, 4, 6, 0.3),
			B(0, 4.6, 0.2, 2.6, 4.2, 0.1, true),
			B(0, 7.9, 0.4, 4.6, 0.8, 0.7),
			B(0, 8.5, 0.4, 2.4, 0.6, 0.4),
			B(0, 1.1, 0, 4.4, 0.25, 1.4),
			brass(B(-1.7, 5.2, -0.1, 0.2, 0.2, 0.6)),
			brass(B(1.7, 5.2, -0.1, 0.2, 0.2, 0.6)),
			brass(B(-1.7, 3.6, -0.1, 0.2, 0.2, 0.6)),
			brass(B(1.7, 3.6, -0.1, 0.2, 0.2, 0.6)),
			iron(B(-1.2, 0.6, -0.65, 0.9, 0.5, 0.1)),
			iron(B(1.2, 0.6, -0.65, 0.9, 0.5, 0.1)),
		},
	},
	{
		Id = "TelephoneTable",
		Label = "Telephone table",
		Category = "Hallway",
		Mount = "floor",
		Parts = join(legs(1.5, 1, 2.4, 0.3), {
			B(0, 2.6, 0, 4, 0.25, 2.6),
			B(0, 1.2, 0, 3.4, 0.2, 2.2, true),
			B(1.4, 1.7, 0.8, 1, 0.8, 0.3, true),
			iron(C(-0.8, 3.1, 0, 0.8, 0.8)),
			iron(C(-0.8, 3.7, 0, 0.2, 0.7)),
			iron(S(-0.8, 4.15, 0, 0.4)),
			iron(B(0.5, 3, 0, 0.8, 0.3, 0.3)),
			painted(B(0.6, 3.3, 0, 0.3, 0.3, 0.3), 0.15, 0.15, 0.15, "SmoothPlastic"),
		}),
	},
	{
		Id = "CurioCabinet",
		Label = "Curio cabinet",
		Category = "Hallway",
		Mount = "floor",
		Parts = {
			B(0, 0.8, 0, 4.6, 1.6, 1.6),
			B(-2.1, 4.8, 0, 0.4, 6.8, 1.6),
			B(2.1, 4.8, 0, 0.4, 6.8, 1.6),
			B(0, 8.4, 0, 4.8, 0.5, 1.8),
			B(0, 4.8, 0.7, 4, 6.8, 0.2, true),
			B(0, 3.4, 0, 3.8, 0.2, 1.4, true),
			B(0, 5.6, 0, 3.8, 0.2, 1.4, true),
			painted(B(0, 4.8, -0.78, 3.8, 6.6, 0.06), 0.7, 0.82, 0.88, "SmoothPlastic", 0.6),
			painted(S(-0.9, 4.2, 0, 0.8), 0.85, 0.8, 0.65, "SmoothPlastic"),
			painted(C(1, 4.15, 0, 0.7, 0.9), 0.4, 0.5, 0.65, "SmoothPlastic"),
			painted(B(0, 6.1, 0, 1.4, 0.7, 0.8), 0.6, 0.45, 0.2, "SmoothPlastic"),
		},
	},
	{
		Id = "BustPedestal",
		Label = "Bust on pedestal",
		Category = "Hallway",
		Mount = "floor",
		Parts = {
			painted(B(0, 0.25, 0, 2, 0.5, 2), 0.78, 0.76, 0.72, "SmoothPlastic"),
			painted(B(0, 2.4, 0, 1.4, 3.9, 1.4), 0.85, 0.83, 0.78, "SmoothPlastic"),
			painted(B(0, 4.5, 0, 1.9, 0.3, 1.9), 0.78, 0.76, 0.72, "SmoothPlastic"),
			painted(B(0, 5.4, 0, 1.4, 1.5, 0.9), 0.9, 0.88, 0.82, "SmoothPlastic"),
			painted(S(0, 6.5, 0, 1.1), 0.9, 0.88, 0.82, "SmoothPlastic"),
		},
	},
	{
		Id = "SuitOfArmor",
		Label = "Suit of armor",
		Category = "Hallway",
		Mount = "floor",
		Parts = {
			painted(B(0, 0.2, 0, 2.6, 0.4, 2), 0.3, 0.2, 0.12, "SmoothPlastic"),
			steel(B(-0.5, 1.8, 0, 0.6, 3, 0.6)),
			steel(B(0.5, 1.8, 0, 0.6, 3, 0.6)),
			steel(B(0, 4.5, 0, 1.8, 2.6, 1.1)),
			steel(B(-1.2, 4.6, 0, 0.6, 2.2, 0.6)),
			steel(B(1.2, 4.6, 0, 0.6, 2.2, 0.6)),
			steel(S(0, 6.3, 0, 1.2)),
			iron(B(0, 6.3, -0.55, 0.8, 0.12, 0.1)),
			iron(B(1.7, 4.5, 0, 0.12, 5.6, 0.12)),
			steel(B(1.7, 7.4, 0, 0.5, 0.9, 0.12)),
		},
	},
	{
		Id = "PortraitRow",
		Label = "Portrait row",
		Category = "Hallway",
		Mount = "wall",
		Parts = {
			brass(B(-4, 6, -0.15, 2.7, 3.5, 0.3)),
			painted(B(-4, 6, -0.35, 2.2, 3, 0.06), 0.35, 0.28, 0.2, "SmoothPlastic"),
			painted(B(-4, 6.4, -0.4, 1.1, 1.5, 0.04), 0.62, 0.5, 0.38, "SmoothPlastic"),
			brass(B(0, 6, -0.15, 3.1, 4.1, 0.3)),
			painted(B(0, 6, -0.35, 2.6, 3.6, 0.06), 0.35, 0.28, 0.2, "SmoothPlastic"),
			painted(B(0, 6.4, -0.4, 1.3, 1.8, 0.04), 0.62, 0.5, 0.38, "SmoothPlastic"),
			brass(B(4, 6, -0.15, 2.7, 3.5, 0.3)),
			painted(B(4, 6, -0.35, 2.2, 3, 0.06), 0.35, 0.28, 0.2, "SmoothPlastic"),
			painted(B(4, 6.4, -0.4, 1.1, 1.5, 0.04), 0.62, 0.5, 0.38, "SmoothPlastic"),
		},
	},
	{
		Id = "HallRunner",
		Label = "Hall runner",
		Category = "Hallway",
		Mount = "floor",
		Parts = {
			painted(B(0, 0.05, 0, 3.4, 0.1, 14), 0.45, 0.14, 0.14, "Fabric"),
			painted(B(0, 0.1, 0, 2.8, 0.1, 13.4), 0.12, 0.15, 0.3, "Fabric"),
			painted(B(0, 0.15, 0, 2.4, 0.1, 13), 0.78, 0.68, 0.48, "Fabric"),
			painted(B(0, 0.2, 0, 1.8, 0.1, 12.4), 0.45, 0.14, 0.14, "Fabric"),
		},
	},
	{
		Id = "HallChairs",
		Label = "Hall chairs",
		Category = "Hallway",
		Mount = "floor",
		Parts = join(legs(1.6, 1, 1.8, 0.25), {
			B(0, 1.9, 0, 4, 0.3, 2.6),
			B(0, 4.6, 1.15, 4, 5.2, 0.3),
			B(0, 4.7, 1.15, 3.2, 4, 0.1, true),
			B(0, 2.15, 0, 3.4, 0.2, 2.2, true),
		}),
	},
	-- More hallway
	{
		Id = "WallMirror",
		Label = "Wall mirror",
		Category = "Hallway",
		Mount = "wall",
		Parts = {
			B(0, 3.5, -0.2, 3.6, 6.6, 0.4),
			B(0, 3.5, -0.45, 3, 6, 0.1, true),
		},
	},
	{
		Id = "ShoeBench",
		Label = "Shoe bench",
		Category = "Hallway",
		Mount = "floor",
		Parts = {
			B(0, 0.3, 0, 5, 0.6, 1.8),
			B(0, 0.8, 0, 5, 0.3, 1.8, true),
			B(-1.6, 1.3, 0.2, 1.2, 0.7, 1.2),
			B(1.6, 1.3, 0.2, 1.2, 0.7, 1.2),
			B(0, 1.8, 0.7, 5, 1.2, 0.3),
		},
	},
	{
		Id = "UmbrellaStand",
		Label = "Umbrella stand",
		Category = "Hallway",
		Mount = "floor",
		Parts = {
			C(0, 1.1, 0, 1.4, 2.2),
			C(0, 3, 0.1, 0.2, 2.2, true),
			C(0.3, 3.3, -0.1, 0.2, 2.6, true),
		},
	},
	-- Office
	{
		Id = "FilingCabinet",
		Label = "Filing cabinet",
		Category = "Office",
		Mount = "floor",
		Parts = {
			B(0, 2, 0, 2.2, 4, 2.4),
			B(0, 0.9, -1.25, 1.9, 1.2, 0.1, true),
			B(0, 2.3, -1.25, 1.9, 1.2, 0.1, true),
			B(0, 3.5, -1.25, 1.9, 0.9, 0.1, true),
		},
	},
	{
		Id = "ExecDesk",
		Label = "Executive desk",
		Category = "Office",
		Mount = "floor",
		Parts = {
			B(0, 3, 0, 8, 0.4, 3.6),
			B(-3.2, 1.4, 0, 1.4, 2.8, 3.2),
			B(3.2, 1.4, 0, 1.4, 2.8, 3.2),
			B(0, 2.2, 1.4, 5, 1.2, 0.3),
			B(0, 3.3, 0, 3, 0.1, 1.6, true),
		},
	},
	{
		Id = "DraftingTable",
		Label = "Drafting table",
		Category = "Office",
		Mount = "floor",
		Parts = join(legs(2.4, 1.3, 3.4, 0.3), {
			B(0, 3.6, 0, 5.4, 0.3, 3.2),
			B(0, 3.9, 0.8, 5.4, 0.5, 1.4, true),
		}),
	},
	{
		Id = "GlobeStand",
		Label = "Globe stand",
		Category = "Office",
		Mount = "floor",
		Parts = {
			C(0, 0.15, 0, 2, 0.3),
			C(0, 1.6, 0, 0.3, 2.6),
			S(0, 3.4, 0, 2.6, true),
		},
	},
	{
		Id = "Whiteboard",
		Label = "Whiteboard",
		Category = "Office",
		Mount = "wall",
		Parts = {
			B(0, 4.5, -0.15, 7.4, 4.2, 0.3),
			B(0, 4.5, -0.35, 7, 3.8, 0.1, true),
		},
	},
	-- Study (office)
	{
		Id = "Typewriter",
		Label = "Typewriter",
		Category = "Office",
		Mount = "floor",
		Parts = {
			iron(B(0, 0.3, 0, 1.7, 0.6, 1.6)),
			iron(B(0, 0.7, 0.3, 1.5, 0.4, 0.9)),
			paper(B(0, 0.62, -0.55, 1.4, 0.1, 0.35)),
			paper(B(0, 0.75, -0.2, 1.4, 0.1, 0.35)),
			iron(laid(C(0, 1.0, 0.5, 0.3, 1.9))),
			brass(S(-1.0, 1.0, 0.5, 0.3)),
			brass(S(1.0, 1.0, 0.5, 0.3)),
			paper(B(0, 1.5, 0.62, 1.1, 1, 0.03)),
			iron(B(0, 1.12, 0.2, 1.6, 0.08, 0.1)),
		},
	},
	{
		Id = "WritingDesk",
		Label = "Writing desk",
		Category = "Office",
		Mount = "floor",
		Parts = {
			walnut(B(0, 3, 0, 7.4, 0.3, 3.4)),
			walnut(B(-2.75, 1.4, 0, 1.7, 2.8, 3)),
			walnut(B(2.75, 1.4, 0, 1.7, 2.8, 3)),
			walnut(B(0, 1.8, 1.35, 3.8, 2, 0.2)),
			B(-2.75, 2.35, -1.55, 1.5, 0.75, 0.08, true),
			B(-2.75, 1.4, -1.55, 1.5, 0.75, 0.08, true),
			B(-2.75, 0.45, -1.55, 1.5, 0.75, 0.08, true),
			B(2.75, 2.35, -1.55, 1.5, 0.75, 0.08, true),
			B(2.75, 1.4, -1.55, 1.5, 0.75, 0.08, true),
			B(2.75, 0.45, -1.55, 1.5, 0.75, 0.08, true),
			B(0, 2.6, -1.5, 3.4, 0.45, 0.08, true),
			brass(B(-2.75, 2.35, -1.65, 0.5, 0.1, 0.1)),
			brass(B(-2.75, 1.4, -1.65, 0.5, 0.1, 0.1)),
			brass(B(-2.75, 0.45, -1.65, 0.5, 0.1, 0.1)),
			brass(B(2.75, 2.35, -1.65, 0.5, 0.1, 0.1)),
			brass(B(2.75, 1.4, -1.65, 0.5, 0.1, 0.1)),
			brass(B(2.75, 0.45, -1.65, 0.5, 0.1, 0.1)),
			brass(B(0, 2.6, -1.6, 0.6, 0.1, 0.1)),
			painted(B(0, 3.17, 0, 4.4, 0.04, 2.4), 0.12, 0.2, 0.14, "Fabric"),
		},
	},
	{
		Id = "LeatherChair",
		Label = "Leather swivel chair",
		Category = "Office",
		Mount = "floor",
		Parts = {
			iron(C(0, 0.95, 0, 0.3, 1.5)),
			iron(turned(B(0, 0.3, 0, 2.2, 0.15, 0.3), 0)),
			iron(turned(B(0, 0.3, 0, 2.2, 0.15, 0.3), 60)),
			iron(turned(B(0, 0.3, 0, 2.2, 0.15, 0.3), 120)),
			iron(S(-1.1, 0.15, 0, 0.3)),
			iron(S(1.1, 0.15, 0, 0.3)),
			iron(S(-0.55, 0.15, 0.95, 0.3)),
			iron(S(0.55, 0.15, 0.95, 0.3)),
			iron(S(-0.55, 0.15, -0.95, 0.3)),
			iron(S(0.55, 0.15, -0.95, 0.3)),
			leather(B(0, 1.9, 0, 2.4, 0.55, 2.4)),
			leather(B(0, 3.4, 1.0, 2.3, 2.6, 0.55)),
			walnut(B(-1.3, 2.55, 0, 0.3, 0.2, 2)),
			walnut(B(1.3, 2.55, 0, 0.3, 0.2, 2)),
			walnut(B(-1.3, 2.2, -0.7, 0.2, 0.7, 0.2)),
			walnut(B(1.3, 2.2, -0.7, 0.2, 0.7, 0.2)),
			brass(B(0, 4.6, 0.7, 1.4, 0.1, 0.1)),
		},
	},
	{
		Id = "BrassLamp",
		Label = "Brass desk lamp",
		Category = "Office",
		Mount = "floor",
		Parts = {
			brass(C(0, 0.1, 0.4, 1.2, 0.2)),
			brass(B(0, 1.3, 0.4, 0.12, 2.2, 0.12)),
			brass(B(0, 2.4, -0.2, 0.1, 0.1, 1.3)),
			painted(C(0, 2.15, -0.85, 1.1, 0.5), 0.1, 0.35, 0.2, "Metal"),
			glowing(S(0, 1.95, -0.85, 0.4), 1, 0.85, 0.55),
			lamp(0, 1.95, -0.85),
			lights(0, 1.95, -0.85, 0.25, 8),
		},
	},
	{
		Id = "PaperStack",
		Label = "Paper stack",
		Category = "Office",
		Mount = "floor",
		Parts = {
			paper(B(0, 0.1, 0, 1.8, 0.2, 2.4)),
			painted(B(0.1, 0.3, 0.05, 1.7, 0.2, 2.3), 0.9, 0.82, 0.55, "SmoothPlastic"),
			paper(B(-0.1, 0.5, -0.05, 1.7, 0.2, 2.3)),
			paper(B(0.05, 0.65, 0.1, 1.6, 0.1, 2.2)),
		},
	},
	{
		Id = "PencilCup",
		Label = "Pencil cup",
		Category = "Office",
		Mount = "floor",
		Parts = {
			painted(C(0, 0.4, 0, 0.7, 0.8), 0.15, 0.15, 0.17, "Metal"),
			painted(C(-0.1, 0.9, 0, 0.1, 0.9), 0.85, 0.7, 0.15, "SmoothPlastic"),
			painted(C(0.12, 0.85, 0.05, 0.1, 0.8), 0.7, 0.15, 0.15, "SmoothPlastic"),
			painted(C(0, 0.8, -0.12, 0.1, 0.7), 0.15, 0.2, 0.6, "SmoothPlastic"),
		},
	},
	{
		Id = "DeskPhoto",
		Label = "Framed desk photo",
		Category = "Office",
		Mount = "floor",
		Parts = {
			brass(B(0, 0.6, 0, 1, 1.2, 0.1)),
			painted(B(0, 0.6, -0.06, 0.8, 1, 0.04), 0.5, 0.48, 0.45, "SmoothPlastic"),
			brass(B(0, 0.4, 0.2, 0.1, 0.8, 0.1)),
		},
	},
	{
		Id = "InTray",
		Label = "Letter tray",
		Category = "Office",
		Mount = "floor",
		Parts = {
			walnut(B(0, 0.1, 0, 2, 0.2, 2.6)),
			walnut(B(0, 0.5, 0, 2, 0.1, 2.6)),
			walnut(B(-0.95, 0.35, 0, 0.1, 0.7, 2.6)),
			walnut(B(0.95, 0.35, 0, 0.1, 0.7, 2.6)),
			paper(B(0, 0.25, 0, 1.7, 0.1, 2.2)),
			paper(B(0, 0.6, 0, 1.7, 0.1, 2.2)),
		},
	},
	{
		Id = "RotaryPhone",
		Label = "Rotary phone",
		Category = "Office",
		Mount = "floor",
		Parts = {
			iron(B(0, 0.3, 0, 1.3, 0.6, 1.3)),
			painted(C(0, 0.65, -0.1, 0.7, 0.1), 0.85, 0.82, 0.7, "SmoothPlastic"),
			iron(B(0, 0.85, 0.35, 1.5, 0.2, 0.3)),
			iron(B(-0.65, 0.7, 0.35, 0.3, 0.4, 0.3)),
			iron(B(0.65, 0.7, 0.35, 0.3, 0.4, 0.3)),
		},
	},
	{
		Id = "ArchiveBoxes",
		Label = "Archive boxes",
		Category = "Office",
		Mount = "floor",
		Parts = {
			painted(B(0, 0.7, 0, 2.4, 1.4, 3.2), 0.65, 0.52, 0.34, "Wood"),
			painted(B(0, 0.1, 0, 2.5, 0.1, 3.3), 0.55, 0.43, 0.27, "Wood"),
			painted(B(0.1, 1.9, 0, 2.4, 1, 3.2), 0.68, 0.55, 0.36, "Wood"),
			paper(B(0, 1.0, -1.62, 1.2, 0.5, 0.03)),
			paper(B(0.1, 1.95, -1.62, 1.2, 0.4, 0.03)),
			painted(B(-0.1, 2.55, 0.1, 2.2, 0.3, 3), 0.62, 0.5, 0.32, "Wood"),
		},
	},
	{
		Id = "GreenFileCabinet",
		Label = "Green filing cabinet",
		Category = "Office",
		Mount = "floor",
		Parts = {
			painted(B(0, 2.6, 0, 2.4, 5.2, 2.6), 0.42, 0.52, 0.45, "Metal"),
			painted(B(0, 0.95, -1.33, 2.1, 1, 0.08), 0.46, 0.56, 0.49, "Metal"),
			painted(B(0, 2.05, -1.33, 2.1, 1, 0.08), 0.46, 0.56, 0.49, "Metal"),
			painted(B(0, 3.15, -1.33, 2.1, 1, 0.08), 0.46, 0.56, 0.49, "Metal"),
			painted(B(0, 4.25, -1.33, 2.1, 1, 0.08), 0.46, 0.56, 0.49, "Metal"),
			brass(B(0, 0.95, -1.42, 0.8, 0.12, 0.1)),
			brass(B(0, 2.05, -1.42, 0.8, 0.12, 0.1)),
			brass(B(0, 3.15, -1.42, 0.8, 0.12, 0.1)),
			brass(B(0, 4.25, -1.42, 0.8, 0.12, 0.1)),
			paper(B(0, 1.25, -1.4, 0.7, 0.25, 0.03)),
			paper(B(0, 2.35, -1.4, 0.7, 0.25, 0.03)),
			paper(B(0, 3.45, -1.4, 0.7, 0.25, 0.03)),
			paper(B(0, 4.55, -1.4, 0.7, 0.25, 0.03)),
		},
	},
	{
		Id = "CorkBoard",
		Label = "Cork board",
		Category = "Office",
		Mount = "wall",
		Parts = {
			walnut(B(0, 5.5, -0.15, 4.4, 3.2, 0.3)),
			painted(B(0, 5.5, -0.32, 4, 2.8, 0.06), 0.72, 0.52, 0.3, "Wood"),
			paper(B(-1.3, 6.0, -0.38, 0.9, 1, 0.03)),
			paper(B(0, 5.1, -0.38, 1.1, 0.8, 0.03)),
			painted(B(1.25, 6.0, -0.38, 0.9, 1.1, 0.03), 0.45, 0.45, 0.42, "SmoothPlastic"),
			painted(B(-1.2, 4.8, -0.38, 0.8, 0.6, 0.03), 0.9, 0.82, 0.55, "SmoothPlastic"),
			painted(S(-1.3, 6.4, -0.42, 0.18), 0.75, 0.1, 0.1, "SmoothPlastic"),
			painted(S(0, 5.4, -0.42, 0.18), 0.1, 0.3, 0.7, "SmoothPlastic"),
			painted(S(1.25, 6.45, -0.42, 0.18), 0.75, 0.1, 0.1, "SmoothPlastic"),
		},
	},
	{
		Id = "StudyBookcase",
		Label = "Study bookcase",
		Category = "Office",
		Mount = "wall",
		Parts = join(bookcase(8, 10, -0.8), {
			walnut(B(0, 1.5, -1.65, 7.6, 2.6, 0.1)),
			B(-1.3, 1.5, -1.72, 0.1, 2.4, 0.05, true),
			B(1.3, 1.5, -1.72, 0.1, 2.4, 0.05, true),
			brass(B(-0.5, 1.5, -1.8, 0.15, 0.5, 0.1)),
			brass(B(0.5, 1.5, -1.8, 0.15, 0.5, 0.1)),
			walnut(B(0, 10.3, -0.9, 8.6, 0.5, 2)),
		}),
	},
	{
		Id = "ReadingArmchair",
		Label = "Reading armchair",
		Category = "Office",
		Mount = "floor",
		Parts = {
			painted(B(0, 1.0, 0, 3.6, 2, 3.2), 0.3, 0.38, 0.22, "Fabric"),
			painted(B(0, 3.4, 1.3, 3.6, 3, 0.6), 0.3, 0.38, 0.22, "Fabric"),
			painted(B(0, 2.3, -0.3, 2.6, 0.6, 2.4), 0.34, 0.42, 0.25, "Fabric"),
			painted(B(-1.75, 2.4, 0, 0.5, 2.8, 3.2), 0.3, 0.38, 0.22, "Fabric"),
			painted(B(1.75, 2.4, 0, 0.5, 2.8, 3.2), 0.3, 0.38, 0.22, "Fabric"),
			painted(B(-0.9, 3.9, 0.95, 1.7, 2.2, 0.15), 0.55, 0.15, 0.12, "Fabric"),
			painted(B(0.8, 3.0, 0.7, 1.1, 1.1, 0.4), 0.78, 0.68, 0.5, "Fabric"),
			walnut(B(-1.5, 0.1, -1.4, 0.3, 0.2, 0.3)),
			walnut(B(1.5, 0.1, -1.4, 0.3, 0.2, 0.3)),
		},
	},
	{
		Id = "SideTable",
		Label = "Round side table",
		Category = "Office",
		Mount = "floor",
		Parts = {
			walnut(C(0, 2.3, 0, 2, 0.2)),
			walnut(C(0, 1.1, 0, 0.3, 2.2)),
			walnut(turned(B(0, 0.1, 0, 1.8, 0.2, 0.3), 0)),
			walnut(turned(B(0, 0.1, 0, 1.8, 0.2, 0.3), 60)),
			walnut(turned(B(0, 0.1, 0, 1.8, 0.2, 0.3), 120)),
		},
	},
	{
		Id = "WallClock",
		Label = "Wall clock",
		Category = "Office",
		Mount = "wall",
		Parts = {
			walnut(B(0, 8, -0.2, 2.2, 2.2, 0.4)),
			paper(B(0, 8, -0.45, 1.8, 1.8, 0.06)),
			iron(B(0, 8.3, -0.5, 0.1, 0.7, 0.04)),
			iron(B(0.3, 8, -0.5, 0.6, 0.1, 0.04)),
			iron(S(0, 8, -0.52, 0.2)),
		},
	},
	{
		Id = "Curtains",
		Label = "Curtains",
		Category = "Office",
		Mount = "wall",
		Parts = {
			brass(laid(C(0, 9.5, -0.6, 0.15, 6.4))),
			brass(S(-3.3, 9.5, -0.6, 0.3)),
			brass(S(3.3, 9.5, -0.6, 0.3)),
			painted(B(-2.1, 4.9, -0.5, 1.8, 9, 0.5), 0.5, 0.38, 0.32, "Fabric"),
			painted(B(2.1, 4.9, -0.5, 1.8, 9, 0.5), 0.5, 0.38, 0.32, "Fabric"),
			painted(B(-2.1, 4.9, -0.78, 0.5, 8.8, 0.1), 0.3, 0.38, 0.4, "Fabric"),
			painted(B(2.1, 4.9, -0.78, 0.5, 8.8, 0.1), 0.3, 0.38, 0.4, "Fabric"),
			painted(B(-1.5, 4.5, -0.78, 0.3, 0.3, 0.1), 0.72, 0.55, 0.2, "Fabric"),
			painted(B(1.5, 4.5, -0.78, 0.3, 0.3, 0.1), 0.72, 0.55, 0.2, "Fabric"),
		},
	},
	{
		Id = "FramedLandscape",
		Label = "Framed landscape",
		Category = "Office",
		Mount = "wall",
		Parts = {
			walnut(B(0, 6, -0.12, 3.6, 2.8, 0.24)),
			painted(B(0, 6.45, -0.27, 3.1, 1.2, 0.05), 0.62, 0.68, 0.72, "SmoothPlastic"),
			painted(B(0, 5.55, -0.27, 3.1, 1.0, 0.05), 0.3, 0.42, 0.25, "SmoothPlastic"),
			painted(B(0.6, 5.95, -0.29, 1.1, 0.5, 0.05), 0.2, 0.3, 0.2, "SmoothPlastic"),
			brass(B(0, 4.7, -0.27, 0.8, 0.1, 0.05)),
		},
	},
	{
		Id = "PersianRug",
		Label = "Persian rug",
		Category = "Office",
		Mount = "floor",
		Parts = {
			painted(B(0, 0.05, 0, 10, 0.1, 7), 0.45, 0.14, 0.14, "Fabric"),
			painted(B(0, 0.07, 0, 9.2, 0.1, 6.2), 0.12, 0.15, 0.3, "Fabric"),
			painted(B(0, 0.09, 0, 8.6, 0.1, 5.6), 0.78, 0.68, 0.48, "Fabric"),
			painted(B(0, 0.11, 0, 8, 0.1, 5), 0.45, 0.14, 0.14, "Fabric"),
			painted(B(0, 0.13, 0, 5, 0.1, 2.8), 0.12, 0.15, 0.3, "Fabric"),
			painted(B(0, 0.15, 0, 3.2, 0.1, 1.6), 0.78, 0.68, 0.48, "Fabric"),
		},
	},
	-- More basement
	{
		Id = "Furnace",
		Label = "Furnace",
		Category = "Basement",
		Mount = "floor",
		Parts = {
			B(0, 3, 0, 4, 6, 3),
			B(0, 2.4, -1.55, 3, 2.6, 0.1, true),
			C(-1, 7.6, 0, 1, 3.2),
			C(1, 7.6, 0, 1, 3.2),
			B(0, 9.6, 0, 3.2, 0.8, 1),
		},
	},
	{
		Id = "WasherDryer",
		Label = "Washer and dryer",
		Category = "Basement",
		Mount = "floor",
		Parts = {
			B(-1.7, 1.8, 0, 3.2, 3.6, 3),
			B(1.7, 1.8, 0, 3.2, 3.6, 3),
			C(-1.7, 2, -1.55, 1.8, 0.2, true),
			C(1.7, 2, -1.55, 1.8, 0.2, true),
			B(0, 3.7, 0.9, 6.8, 0.8, 0.8),
		},
	},
	{
		Id = "ToolChest",
		Label = "Tool chest",
		Category = "Basement",
		Mount = "floor",
		Parts = {
			B(0, 2.4, 0, 4.4, 4.8, 2.2),
			B(0, 5.1, 0, 4.6, 0.6, 2.4, true),
			B(0, 1, -1.15, 4, 0.8, 0.1, true),
			B(0, 2.4, -1.15, 4, 0.8, 0.1, true),
			B(0, 3.8, -1.15, 4, 0.8, 0.1, true),
		},
	},
	{
		Id = "Pegboard",
		Label = "Pegboard wall",
		Category = "Basement",
		Mount = "wall",
		Parts = {
			B(0, 4, -0.1, 8, 5.4, 0.2),
			B(-2.4, 4.6, -0.4, 2, 0.15, 0.6, true),
			B(0.6, 3.6, -0.4, 3, 0.15, 0.6, true),
			B(2.6, 5.2, -0.4, 1.2, 1.2, 0.6, true),
		},
	},
	{
		Id = "PaintShelf",
		Label = "Paint shelf",
		Category = "Basement",
		Mount = "floor",
		Parts = {
			B(-2.9, 3, 0, 0.3, 6, 1.6),
			B(2.9, 3, 0, 0.3, 6, 1.6),
			B(0, 0.3, 0, 6, 0.3, 1.6),
			B(0, 2.3, 0, 6, 0.3, 1.6),
			B(0, 4.3, 0, 6, 0.3, 1.6),
			B(0, 5.9, 0, 6, 0.3, 1.6),
			C(-1.8, 3, 0, 1, 1.4, true),
			C(0, 3, 0, 1, 1.4, true),
			C(1.8, 5, 0, 1, 1.4, true),
		},
	},
	-- More attic
	{
		Id = "DressForm",
		Label = "Dress form",
		Category = "Attic",
		Mount = "floor",
		Parts = {
			C(0, 0.1, 0, 2, 0.2),
			C(0, 2, 0, 0.3, 3.6),
			C(0, 4.4, 0, 1.8, 2.6, true),
			S(0, 5.9, 0, 0.8, true),
		},
	},
	{
		Id = "RockingChair",
		Label = "Rocking chair",
		Category = "Attic",
		Mount = "floor",
		Parts = {
			B(-1.3, 0.15, 0, 0.3, 0.3, 3.2),
			B(1.3, 0.15, 0, 0.3, 0.3, 3.2),
			B(0, 1.6, 0, 2.6, 0.3, 2.4),
			B(0, 3.2, 1.1, 2.6, 3.2, 0.3),
			B(-1.3, 0.9, 0, 0.2, 1.4, 0.2),
			B(1.3, 0.9, 0, 0.2, 1.4, 0.2),
		},
	},
	{
		Id = "RolledRugs",
		Label = "Rolled rugs",
		Category = "Attic",
		Mount = "floor",
		Parts = {
			B(-0.7, 0.7, 0, 1.4, 1.4, 5),
			B(0.7, 0.7, 0, 1.4, 1.4, 5, true),
			B(0, 2.1, 0, 1.4, 1.4, 5, true),
		},
	},
	{
		Id = "ClothRail",
		Label = "Cloth rail",
		Category = "Attic",
		Mount = "floor",
		Parts = {
			B(-2.8, 2.8, 0, 0.3, 5.6, 0.3),
			B(2.8, 2.8, 0, 0.3, 5.6, 0.3),
			B(0, 5.5, 0, 5.8, 0.2, 0.2),
			B(-1.6, 3.4, 0, 0.3, 4, 1.2, true),
			B(0, 3.4, 0, 0.3, 4, 1.2),
			B(1.6, 3.4, 0, 0.3, 4, 1.2, true),
		},
	},
	-- Kids
	{
		Id = "ToyChest",
		Label = "Toy chest",
		Category = "Kids",
		Mount = "floor",
		Parts = {
			B(0, 1.2, 0, 4, 2.4, 2.2),
			B(0, 2.6, 0, 4.2, 0.4, 2.4, true),
			B(0, 1.4, -1.15, 0.6, 0.6, 0.1, true),
		},
	},
	{
		Id = "Slide",
		Label = "Slide",
		Category = "Kids",
		Mount = "floor",
		Parts = {
			B(-1.2, 2.5, 0, 0.3, 5, 3),
			B(1.2, 2.5, 0, 0.3, 5, 3),
			B(0, 4.7, 1.2, 2.4, 0.4, 1.2, true),
			B(0, 3.9, 0, 2.1, 0.3, 1, true),
			B(0, 3.1, -1, 2.1, 0.3, 1, true),
			B(0, 2.3, -2, 2.1, 0.3, 1, true),
			B(0, 1.5, -3, 2.1, 0.3, 1, true),
			B(0, 0.7, -4, 2.1, 0.3, 1, true),
		},
	},
	{
		Id = "PlayTent",
		Label = "Play tent",
		Category = "Kids",
		Mount = "floor",
		Parts = {
			B(0, 0.8, 0, 6, 1.6, 6, true),
			B(0, 2.2, 0, 4.6, 1.2, 4.6),
			B(0, 3.2, 0, 3.2, 0.8, 3.2, true),
			B(0, 3.9, 0, 1.6, 0.6, 1.6),
		},
	},
	{
		Id = "Dollhouse",
		Label = "Dollhouse",
		Category = "Kids",
		Mount = "floor",
		Parts = {
			B(0, 2.4, 0, 5, 4.8, 3),
			B(0, 5.4, 0, 5.6, 1.2, 3.4, true),
			B(0, 6.4, 0, 3.4, 0.8, 3, true),
			B(0, 1, -1.55, 1.2, 2, 0.1),
			B(-1.4, 3, -1.55, 1, 1, 0.1),
			B(1.4, 3, -1.55, 1, 1, 0.1),
		},
	},
	{
		Id = "BeanBag",
		Label = "Bean bag",
		Category = "Kids",
		Mount = "floor",
		Parts = {
			B(0, 0.8, 0, 3.2, 1.6, 3.2, true),
			B(0, 2.0, 0.6, 2.6, 1.6, 2),
			B(0, 2.9, 0.9, 1.8, 0.8, 1.4, true),
		},
	},
	{
		Id = "KidsTableSet",
		Label = "Kids table set",
		Category = "Kids",
		Mount = "floor",
		Parts = join(
			kidsTable(),
			kidsChair(0, 2.6, 0, 0.2, 0.35, 0.7),
			kidsChair(0, -2.6, 2, 0.75, 0.15, 0.12),
			kidsChair(-3.4, 0, 3, 0.9, 0.7, 0.15),
			kidsChair(3.4, 0, 1, 0.9, 0.45, 0.12)
		),
	},
	{
		Id = "KidsTable",
		Label = "Kids table",
		Category = "Kids",
		Mount = "floor",
		Parts = kidsTable(),
	},
	{
		Id = "KidsChair",
		Label = "Kids chair",
		Category = "Kids",
		Mount = "floor",
		Parts = kidsChair(0, 0, 0, 0.2, 0.35, 0.7),
	},
	{
		Id = "ToyShelf",
		Label = "Toy shelf",
		Category = "Kids",
		Mount = "floor",
		Parts = {
			B(-3.9, 1.8, 0, 0.2, 3.6, 1.6),
			B(3.9, 1.8, 0, 0.2, 3.6, 1.6),
			B(-1.3, 1.8, 0, 0.2, 3.6, 1.6),
			B(1.3, 1.8, 0, 0.2, 3.6, 1.6),
			B(0, 1.8, 0.7, 8, 3.6, 0.2),
			B(0, 0.1, 0, 8, 0.2, 1.6, true),
			B(0, 1.8, 0, 8, 0.2, 1.6, true),
			B(0, 3.5, 0, 8, 0.2, 1.6, true),
		},
	},
	{
		Id = "RockingHorse",
		Label = "Rocking horse",
		Category = "Kids",
		Mount = "floor",
		Parts = {
			B(-0.7, 0.2, 0, 0.15, 0.4, 4.2),
			B(0.7, 0.2, 0, 0.15, 0.4, 4.2),
			B(-0.45, 1.0, -0.9, 0.25, 1.2, 0.25),
			B(0.45, 1.0, -0.9, 0.25, 1.2, 0.25),
			B(-0.45, 1.0, 0.9, 0.25, 1.2, 0.25),
			B(0.45, 1.0, 0.9, 0.25, 1.2, 0.25),
			B(0, 2.1, 0, 1.2, 1.0, 2.6),
			B(0, 3.1, -1.0, 0.7, 1.6, 0.8),
			B(0, 3.8, -1.5, 0.6, 0.7, 1.2),
			B(0, 3.5, -0.75, 0.2, 1.3, 0.3, true),
			B(0, 2.3, 1.5, 0.2, 1.0, 0.2, true),
			B(0, 2.7, 0, 1.3, 0.2, 1.0, true),
		},
	},
	{
		Id = "RoadMat",
		Label = "Road play mat",
		Category = "Kids",
		Mount = "floor",
		Parts = {
			painted(B(0, 0.05, 0, 10, 0.1, 7), 0.35, 0.55, 0.3, "Fabric"),
			painted(B(0, 0.1, -2.2, 7.6, 0.1, 1), 0.3, 0.3, 0.32, "Fabric"),
			painted(B(0, 0.1, 2.2, 7.6, 0.1, 1), 0.3, 0.3, 0.32, "Fabric"),
			painted(B(-3.6, 0.1, 0, 1, 0.1, 4.4), 0.3, 0.3, 0.32, "Fabric"),
			painted(B(3.6, 0.1, 0, 1, 0.1, 4.4), 0.3, 0.3, 0.32, "Fabric"),
			painted(B(0, 0.1, 0, 1, 0.1, 4.4), 0.3, 0.3, 0.32, "Fabric"),
			painted(B(-1.8, 0.1, -0.9, 1.4, 0.12, 1.2), 0.8, 0.25, 0.2, "Fabric"),
			painted(B(1.8, 0.1, 0.9, 1.4, 0.12, 1.2), 0.9, 0.75, 0.2, "Fabric"),
			painted(B(1.8, 0.1, -1.1, 1.4, 0.12, 1.2), 0.25, 0.4, 0.75, "Fabric"),
			painted(B(-1.8, 0.1, 1.1, 1.4, 0.12, 1.2), 0.85, 0.85, 0.8, "Fabric"),
		},
	},
	{
		Id = "BraidedRug",
		Label = "Braided round rug",
		Category = "Kids",
		Mount = "floor",
		Parts = {
			painted(C(0, 0.05, 0, 9, 0.1), 0.6, 0.3, 0.25, "Fabric"),
			painted(C(0, 0.07, 0, 7.8, 0.1), 0.85, 0.78, 0.6, "Fabric"),
			painted(C(0, 0.09, 0, 6.6, 0.1), 0.25, 0.35, 0.55, "Fabric"),
			painted(C(0, 0.11, 0, 5.2, 0.1), 0.7, 0.45, 0.3, "Fabric"),
			painted(C(0, 0.13, 0, 3.6, 0.1), 0.85, 0.78, 0.6, "Fabric"),
			painted(C(0, 0.15, 0, 2, 0.1), 0.25, 0.35, 0.55, "Fabric"),
		},
	},
	{
		Id = "KidsBed",
		Label = "Kids bed",
		Category = "Kids",
		Mount = "floor",
		Parts = {
			B(0, 1.2, 0, 3.4, 0.5, 6.6),
			B(-1.6, 0.5, -3.1, 0.25, 1, 0.25),
			B(1.6, 0.5, -3.1, 0.25, 1, 0.25),
			B(-1.6, 0.5, 3.1, 0.25, 1, 0.25),
			B(1.6, 0.5, 3.1, 0.25, 1, 0.25),
			B(0, 3, 3.2, 3.4, 2.6, 0.3),
			B(0, 2, -3.2, 3.4, 1.2, 0.3),
			B(0, 1.75, -0.2, 3, 0.6, 6, true),
			painted(B(0, 2.2, 2.4, 2, 0.3, 1.2), 0.95, 0.95, 0.93, "Fabric"),
		},
	},
	{
		Id = "BigKidBed",
		Label = "Big kid bed",
		Category = "Kids",
		Mount = "floor",
		Parts = {
			B(0, 0.9, 0, 3.4, 0.5, 6),
			B(-1.6, 0.35, -2.8, 0.3, 0.7, 0.3),
			B(1.6, 0.35, -2.8, 0.3, 0.7, 0.3),
			B(-1.6, 0.35, 2.8, 0.3, 0.7, 0.3),
			B(1.6, 0.35, 2.8, 0.3, 0.7, 0.3),
			B(0, 2.3, 3.1, 3.4, 2.8, 0.3, true),
			B(0, 1.9, -3.1, 3.4, 1.8, 0.3, true),
			B(0, 1.5, -0.1, 3, 0.7, 5.6, true),
			B(1.65, 2.3, 0.4, 0.15, 0.8, 3.6),
			B(1.65, 2.0, -1.3, 0.15, 0.2, 0.2),
			B(1.65, 2.0, 2.1, 0.15, 0.2, 0.2),
			painted(B(-0.2, 1.95, 0.9, 2.6, 0.25, 3.8), 0.3, 0.55, 0.85, "Fabric"),
			painted(B(0, 2.0, 2.4, 1.8, 0.4, 1.1), 0.95, 0.95, 0.93, "Fabric"),
			painted(B(-0.8, 2.25, -1.8, 1, 0.7, 1), 0.65, 0.45, 0.25, "Fabric"),
		},
	},
	{
		Id = "KidsDresser",
		Label = "Kids dresser",
		Category = "Kids",
		Mount = "floor",
		Parts = {
			B(0, 2.1, 0, 4.4, 4.2, 2.2),
			B(0, 0.65, -1.15, 4, 0.85, 0.1, true),
			B(0, 1.65, -1.15, 4, 0.85, 0.1, true),
			B(0, 2.65, -1.15, 4, 0.85, 0.1, true),
			B(0, 3.65, -1.15, 4, 0.85, 0.1, true),
			brass(B(0, 0.65, -1.25, 0.5, 0.1, 0.1)),
			brass(B(0, 1.65, -1.25, 0.5, 0.1, 0.1)),
			brass(B(0, 2.65, -1.25, 0.5, 0.1, 0.1)),
			brass(B(0, 3.65, -1.25, 0.5, 0.1, 0.1)),
		},
	},
	{
		Id = "PlayKitchen",
		Label = "Play kitchen",
		Category = "Kids",
		Mount = "floor",
		Parts = {
			B(0, 1.5, 0, 5, 3, 1.8),
			B(0, 3.05, 0, 5.2, 0.1, 2),
			B(0, 4.4, 0.8, 5, 2.6, 0.2),
			B(0, 4.7, 0.3, 4, 0.1, 0.8),
			B(-1.2, 1.5, -0.95, 2.2, 1.8, 0.1, true),
			B(1.2, 1.5, -0.95, 2.2, 1.8, 0.1, true),
			steel(B(1.4, 3.15, -0.1, 1.6, 0.1, 1.1)),
			painted(S(-1.5, 3.7, 0.65, 0.3), 0.8, 0.15, 0.15, "SmoothPlastic"),
			painted(S(-0.8, 3.7, 0.65, 0.3), 0.15, 0.4, 0.8, "SmoothPlastic"),
		},
	},
	{
		Id = "Chalkboard",
		Label = "Chalkboard",
		Category = "Kids",
		Mount = "wall",
		Parts = {
			B(0, 5.5, -0.15, 6.4, 3.8, 0.3),
			B(0, 5.5, -0.32, 5.8, 3.2, 0.06, true),
			B(0, 3.55, -0.4, 5.6, 0.15, 0.5),
		},
	},
	{
		Id = "PuppetTheater",
		Label = "Puppet theater",
		Category = "Kids",
		Mount = "floor",
		Parts = {
			B(-2, 3, 0, 0.3, 6, 1.4),
			B(2, 3, 0, 0.3, 6, 1.4),
			B(0, 5.7, 0, 4.3, 0.6, 1.4),
			B(0, 3, 0.6, 4, 6, 0.15),
			B(0, 1.6, -0.6, 4, 3.2, 0.2),
			B(-1.5, 4.3, -0.7, 1, 2.2, 0.1, true),
			B(1.5, 4.3, -0.7, 1, 2.2, 0.1, true),
			B(0, 5.1, -0.7, 4, 0.5, 0.1, true),
		},
	},
	{
		Id = "GiantTeddy",
		Label = "Giant teddy bear",
		Category = "Kids",
		Mount = "floor",
		Parts = {
			S(0, 1.7, 0, 3.4),
			S(0, 4.0, -0.1, 2.3),
			S(-0.95, 4.95, -0.1, 0.9),
			S(0.95, 4.95, -0.1, 0.9),
			S(-1.1, 0.75, -1.4, 1.5),
			S(1.1, 0.75, -1.4, 1.5),
			S(-1.9, 2.2, -0.6, 1.3),
			S(1.9, 2.2, -0.6, 1.3),
			S(0, 1.7, -1.35, 2, true),
			S(0, 3.75, -1.0, 1, true),
			iron(S(0, 3.95, -1.5, 0.35)),
		},
	},
	{
		Id = "FloralCurtains",
		Label = "Floral curtains",
		Category = "Kids",
		Mount = "wall",
		Parts = {
			brass(laid(C(0, 9.5, -0.6, 0.15, 6.4))),
			brass(S(-3.3, 9.5, -0.6, 0.3)),
			brass(S(3.3, 9.5, -0.6, 0.3)),
			B(-2.1, 4.9, -0.5, 1.8, 9, 0.5),
			B(2.1, 4.9, -0.5, 1.8, 9, 0.5),
			B(-2.1, 4.9, -0.78, 0.5, 8.8, 0.1, true),
			B(2.1, 4.9, -0.78, 0.5, 8.8, 0.1, true),
		},
	},
	-- Outdoor
	{
		Id = "PicnicTable",
		Label = "Picnic table",
		Category = "Outdoor",
		Mount = "floor",
		Parts = {
			B(0, 2.6, 0, 6.4, 0.3, 3),
			B(0, 1.5, -2.4, 6.4, 0.3, 1.2),
			B(0, 1.5, 2.4, 6.4, 0.3, 1.2),
			B(-2.4, 1.2, 0, 0.4, 2.4, 5.6),
			B(2.4, 1.2, 0, 0.4, 2.4, 5.6),
		},
	},
	{
		Id = "GardenBench",
		Label = "Garden bench",
		Category = "Outdoor",
		Mount = "floor",
		Parts = {
			B(0, 1.5, 0, 5.4, 0.3, 1.8),
			B(0, 2.9, 0.8, 5.4, 2.2, 0.25),
			B(-2.4, 0.7, 0, 0.4, 1.4, 1.6),
			B(2.4, 0.7, 0, 0.4, 1.4, 1.6),
		},
	},
	{
		Id = "Fountain",
		Label = "Fountain",
		Category = "Outdoor",
		Mount = "floor",
		Parts = {
			C(0, 0.6, 0, 8, 1.2),
			C(0, 1.25, 0, 7, 0.1, true),
			C(0, 2.4, 0, 1.2, 2.6),
			C(0, 3.8, 0, 3.6, 0.5),
			C(0, 5.4, 0, 0.6, 2.8),
			S(0, 7, 0, 1.2, true),
		},
	},
	{
		Id = "Mailbox",
		Label = "Mailbox",
		Category = "Outdoor",
		Mount = "floor",
		Parts = {
			B(0, 2, 0, 0.4, 4, 0.4),
			B(0, 4.4, 0, 1.4, 1.2, 2.2, true),
			B(0.8, 5, 0.3, 0.1, 1, 0.1),
		},
	},
	{
		Id = "FencePanel",
		Label = "Fence panel",
		Category = "Outdoor",
		Mount = "floor",
		Parts = join({
			B(-3.6, 2.5, 0, 0.5, 5, 0.5),
			B(3.6, 2.5, 0, 0.5, 5, 0.5),
			B(0, 1.2, 0, 7, 0.4, 0.3),
			B(0, 3.8, 0, 7, 0.4, 0.3),
		}, {
			B(-2.6, 2.5, -0.2, 0.9, 4.6, 0.2, true),
			B(-1.3, 2.5, -0.2, 0.9, 4.6, 0.2, true),
			B(0, 2.5, -0.2, 0.9, 4.6, 0.2, true),
			B(1.3, 2.5, -0.2, 0.9, 4.6, 0.2, true),
			B(2.6, 2.5, -0.2, 0.9, 4.6, 0.2, true),
		}),
	},
	{
		Id = "Grill",
		Label = "Barbecue grill",
		Category = "Outdoor",
		Mount = "floor",
		Parts = join(legs(1.3, 0.8, 2.6, 0.2), {
			B(0, 3.2, 0, 3.4, 1.4, 2.2),
			B(0, 4.1, 0, 3.6, 0.4, 2.4, true),
			B(1.9, 3.6, 0, 0.3, 0.3, 2, true),
		}),
	},
	{
		Id = "Hedge",
		Label = "Hedge",
		Category = "Outdoor",
		Mount = "floor",
		Parts = {
			B(0, 2, 0, 7, 4, 2.4, true),
			S(-2.3, 4.2, 0, 2.6, true),
			S(0, 4.4, 0, 2.8, true),
			S(2.3, 4.2, 0, 2.6, true),
		},
	},
	{
		Id = "Boulder",
		Label = "Boulder",
		Category = "Outdoor",
		Mount = "floor",
		Parts = {
			S(0, 1.8, 0, 3.6),
			S(1.8, 1.1, 0.6, 2.2),
			S(-1.6, 0.9, -0.6, 1.8),
		},
	},
	{
		Id = "Well",
		Label = "Well",
		Category = "Outdoor",
		Mount = "floor",
		Parts = {
			C(0, 1.2, 0, 4.6, 2.4),
			C(0, 2.45, 0, 3.6, 0.1, true),
			B(-2, 4.4, 0, 0.3, 4, 0.3),
			B(2, 4.4, 0, 0.3, 4, 0.3),
			B(0, 6.5, 0, 5, 0.6, 3.4, true),
			B(0, 4.6, 0, 0.2, 0.2, 4),
		},
	},
	{
		Id = "Planter",
		Label = "Planter box",
		Category = "Outdoor",
		Mount = "floor",
		Parts = {
			B(0, 1, 0, 5, 2, 1.8),
			S(-1.5, 2.6, 0, 1.8, true),
			S(0, 2.8, 0, 2.2, true),
			S(1.5, 2.6, 0, 1.8, true),
		},
	},
	{
		Id = "Streetlamp",
		Label = "Streetlamp",
		Category = "Lighting",
		Mount = "floor",
		Parts = {
			C(0, 0.4, 0, 1.4, 0.8),
			C(0, 6, 0, 0.4, 12),
			B(0, 12.4, 0, 1.4, 0.5, 1.4),
			glowing(B(0, 13.2, 0, 1.2, 1.2, 1.2), 1, 0.85, 0.55),
			B(0, 14.1, 0, 1.6, 0.4, 1.6),
			lamp(0, 13.2, 0),
			lights(0, 13.2, 0, 0.4, 16),
		},
	},
	{
		Id = "Tree",
		Label = "Tree",
		Category = "Outdoor",
		Mount = "floor",
		Parts = {
			C(0, 4, 0, 1.6, 8),
			S(0, 10, 0, 7, true),
			S(2.6, 8.4, 1, 4.4, true),
			S(-2.6, 8.8, -1, 4.6, true),
			S(0.4, 12.4, 0.4, 4.4, true),
		},
	},
	{
		Id = "Statue",
		Label = "Statue",
		Category = "Outdoor",
		Mount = "floor",
		Parts = {
			B(0, 0.5, 0, 4, 1, 4, true),
			B(0, 1.6, 0, 3, 1.2, 3),
			B(0, 3.8, 0, 1.6, 3.2, 1),
			B(-1.1, 4, 0, 0.5, 2.6, 0.6),
			B(1.1, 4, 0, 0.5, 2.6, 0.6),
			S(0, 5.9, 0, 1.2),
		},
	},
	-- Shop and public
	{
		Id = "ShopCounter",
		Label = "Shop counter",
		Category = "Shop",
		Mount = "floor",
		Parts = {
			B(0, 1.8, 0, 8, 3.6, 2.4),
			B(0, 3.7, 0, 8.4, 0.2, 2.8, true),
			B(2.4, 4.2, 0, 1.6, 0.8, 1.2),
		},
	},
	{
		Id = "ShelvingAisle",
		Label = "Shelving aisle",
		Category = "Shop",
		Mount = "floor",
		Parts = {
			B(0, 3.2, 0, 8, 6.4, 1.2),
			B(0, 1.2, -0.7, 7.6, 0.2, 0.4, true),
			B(0, 2.8, -0.7, 7.6, 0.2, 0.4, true),
			B(0, 4.4, -0.7, 7.6, 0.2, 0.4, true),
			B(0, 6, -0.7, 7.6, 0.2, 0.4, true),
		},
	},
	{
		Id = "BarCounter",
		Label = "Bar with stools",
		Category = "Shop",
		Mount = "floor",
		Parts = join({
			B(0, 1.7, 0.8, 9, 3.4, 1.6),
			B(0, 3.5, 0.2, 9.4, 0.2, 2.8, true),
		}, {
			C(-3, 2.4, -2, 1.4, 0.2, true),
			C(-3, 1.15, -2, 0.3, 2.3),
			C(0, 2.4, -2, 1.4, 0.2, true),
			C(0, 1.15, -2, 0.3, 2.3),
			C(3, 2.4, -2, 1.4, 0.2, true),
			C(3, 1.15, -2, 0.3, 2.3),
		}),
	},
	{
		Id = "Pew",
		Label = "Pew",
		Category = "Shop",
		Mount = "floor",
		Parts = {
			B(0, 1.5, 0, 7, 0.3, 1.6),
			B(0, 3, 0.7, 7, 3, 0.3),
			B(-3.4, 0.7, 0, 0.3, 1.4, 1.6),
			B(3.4, 0.7, 0, 0.3, 1.4, 1.6),
			B(0, 0.5, -0.9, 7, 0.4, 0.4, true),
		},
	},
	{
		Id = "ReceptionDesk",
		Label = "Reception desk",
		Category = "Shop",
		Mount = "floor",
		Parts = {
			B(0, 1.8, 0, 7, 3.6, 2),
			B(-3, 1.8, 2, 1, 3.6, 2.4),
			B(0, 3.7, 0, 7.4, 0.2, 2.4, true),
			B(-3, 3.7, 2, 1.4, 0.2, 2.8, true),
		},
	},
	-- Game room
	{
		Id = "PoolTable",
		Label = "Billiard table",
		Category = "Game",
		Mount = "floor",
		Parts = {
			B(0, 2.9, 0, 4.4, 0.6, 8.4),
			B(0, 3.25, 0, 3.6, 0.1, 7.6, true),
			B(0, 3.45, -4.1, 4.4, 0.5, 0.4),
			B(0, 3.45, 4.1, 4.4, 0.5, 0.4),
			B(-2, 3.45, 0, 0.4, 0.5, 7.8),
			B(2, 3.45, 0, 0.4, 0.5, 7.8),
			C(-1.7, 1.3, -3.2, 0.7, 2.6),
			C(1.7, 1.3, -3.2, 0.7, 2.6),
			C(-1.7, 1.3, 3.2, 0.7, 2.6),
			C(1.7, 1.3, 3.2, 0.7, 2.6),
			C(-1.7, 0.5, -3.2, 1.1, 1),
			C(1.7, 0.5, -3.2, 1.1, 1),
			C(-1.7, 0.5, 3.2, 1.1, 1),
			C(1.7, 0.5, 3.2, 1.1, 1),
			C(-1.7, 2.4, -3.2, 0.95, 0.5),
			C(1.7, 2.4, -3.2, 0.95, 0.5),
			C(-1.7, 2.4, 3.2, 0.95, 0.5),
			C(1.7, 2.4, 3.2, 0.95, 0.5),
			iron(S(-1.85, 3.5, -3.9, 0.55)),
			iron(S(1.85, 3.5, -3.9, 0.55)),
			iron(S(-1.85, 3.5, 3.9, 0.55)),
			iron(S(1.85, 3.5, 3.9, 0.55)),
			iron(S(-2.05, 3.5, 0, 0.5)),
			iron(S(2.05, 3.5, 0, 0.5)),
			painted(S(0.3, 3.45, 1, 0.3), 0.95, 0.95, 0.95, "SmoothPlastic"),
			painted(S(-0.4, 3.45, -1.6, 0.3), 0.8, 0.1, 0.1, "SmoothPlastic"),
			painted(S(0.5, 3.45, -2, 0.3), 0.1, 0.1, 0.1, "SmoothPlastic"),
			painted(S(-0.6, 3.45, 0.2, 0.3), 0.9, 0.75, 0.1, "SmoothPlastic"),
			painted(B(0.7, 3.5, 1.4, 0.1, 0.1, 5), 0.85, 0.7, 0.45, "SmoothPlastic"),
		},
	},
	{
		Id = "ArcadeCabinet",
		Label = "Arcade cabinet",
		Category = "Game",
		Mount = "floor",
		Parts = {
			B(0, 1.6, 0.2, 2.4, 3.2, 2.6),
			B(0, 3.4, -1.5, 2.4, 0.3, 1, true),
			B(0, 5, 0.4, 2.4, 3.2, 2),
			glowing(B(0, 5.1, -0.65, 1.9, 1.8, 0.1), 0.3, 0.6, 1),
			B(0, 6.9, 0.4, 2.4, 0.9, 2, true),
			iron(C(-0.5, 3.8, -1.5, 0.18, 0.6)),
			painted(S(-0.5, 4.15, -1.5, 0.4), 0.85, 0.1, 0.1, "SmoothPlastic"),
			painted(S(0.3, 3.62, -1.5, 0.3), 0.9, 0.8, 0.1, "SmoothPlastic"),
			painted(S(0.9, 3.62, -1.5, 0.3), 0.2, 0.5, 0.9, "SmoothPlastic"),
		},
	},
	{
		Id = "Dartboard",
		Label = "Dartboard",
		Category = "Game",
		Mount = "wall",
		Parts = {
			B(0, 5.5, -0.15, 4.6, 5.4, 0.3),
			B(0, 5.5, -0.33, 4.2, 5, 0.06, true),
			painted(turned(laid(C(0, 5.5, -0.4, 3, 0.1)), 90), 0.1, 0.1, 0.1, "SmoothPlastic"),
			painted(turned(laid(C(0, 5.5, -0.46, 2.5, 0.1)), 90), 0.9, 0.85, 0.7, "SmoothPlastic"),
			painted(turned(laid(C(0, 5.5, -0.52, 1.5, 0.1)), 90), 0.1, 0.5, 0.25, "SmoothPlastic"),
			painted(turned(laid(C(0, 5.5, -0.58, 0.8, 0.1)), 90), 0.85, 0.1, 0.1, "SmoothPlastic"),
			iron(B(0, 8.5, -0.5, 0.25, 0.15, 0.9)),
			painted(B(0, 8.35, -1.0, 1, 0.4, 0.8), 0.1, 0.4, 0.22, "SmoothPlastic"),
			lamp(0, 8.1, -1.0),
			lights(0, 8.1, -1.0, 0.2, 7),
		},
	},
	{
		Id = "Foosball",
		Label = "Foosball table",
		Category = "Game",
		Mount = "floor",
		Parts = join(legs(2, 1.2, 2.6, 0.4), {
			B(0, 2.8, 0, 5.2, 0.5, 3.2),
			B(0, 3.1, 0, 4.6, 0.15, 2.6, true),
			B(0, 3.4, -1.65, 5.2, 0.5, 0.15),
			B(0, 3.4, 1.65, 5.2, 0.5, 0.15),
			B(-2.5, 3.4, 0, 0.15, 0.5, 3.2),
			B(2.5, 3.4, 0, 0.15, 0.5, 3.2),
			steel(B(0, 3.7, -0.9, 6, 0.12, 0.12)),
			steel(B(0, 3.7, 0, 6, 0.12, 0.12)),
			steel(B(0, 3.7, 0.9, 6, 0.12, 0.12)),
			B(-3.1, 3.7, -0.9, 0.4, 0.3, 0.3, true),
			B(3.1, 3.7, 0, 0.4, 0.3, 0.3, true),
			B(-3.1, 3.7, 0.9, 0.4, 0.3, 0.3, true),
		}),
	},
	{
		Id = "PingPong",
		Label = "Ping pong table",
		Category = "Game",
		Mount = "floor",
		Parts = join(legs(2.2, 3.8, 2.8, 0.3), {
			B(0, 2.9, 0, 5, 0.2, 9, true),
			painted(B(0, 3.03, 0, 0.08, 0.05, 9), 0.95, 0.95, 0.95, "SmoothPlastic"),
			B(0, 3.4, 0, 5.4, 0.6, 0.1),
			iron(B(-2.6, 3.4, 0, 0.15, 0.8, 0.15)),
			iron(B(2.6, 3.4, 0, 0.15, 0.8, 0.15)),
		}),
	},
	{
		Id = "BilliardLight",
		Label = "Billiard light",
		Category = "Game",
		Mount = "ceiling",
		Parts = {
			iron(B(0, -1.1, -2.8, 0.1, 2.2, 0.1)),
			painted(C(0, -2.4, -2.8, 1.8, 0.5), 0.1, 0.38, 0.2, "SmoothPlastic"),
			painted(C(0, -2.1, -2.8, 0.8, 0.3), 0.1, 0.38, 0.2, "SmoothPlastic"),
			glowing(C(0, -2.7, -2.8, 1.2, 0.1), 1, 0.85, 0.55),
			lamp(0, -2.8, -2.8),
			lights(0, -2.8, -2.8, 0.4, 12),
			iron(B(0, -1.1, 0, 0.1, 2.2, 0.1)),
			painted(C(0, -2.4, 0, 1.8, 0.5), 0.1, 0.38, 0.2, "SmoothPlastic"),
			painted(C(0, -2.1, 0, 0.8, 0.3), 0.1, 0.38, 0.2, "SmoothPlastic"),
			glowing(C(0, -2.7, 0, 1.2, 0.1), 1, 0.85, 0.55),
			lamp(0, -2.8, 0),
			lights(0, -2.8, 0, 0.4, 12),
			iron(B(0, -1.1, 2.8, 0.1, 2.2, 0.1)),
			painted(C(0, -2.4, 2.8, 1.8, 0.5), 0.1, 0.38, 0.2, "SmoothPlastic"),
			painted(C(0, -2.1, 2.8, 0.8, 0.3), 0.1, 0.38, 0.2, "SmoothPlastic"),
			glowing(C(0, -2.7, 2.8, 1.2, 0.1), 1, 0.85, 0.55),
			lamp(0, -2.8, 2.8),
			lights(0, -2.8, 2.8, 0.4, 12),
		},
	},
	{
		Id = "LeatherSofa",
		Label = "Leather sofa",
		Category = "Game",
		Mount = "floor",
		Parts = {
			B(0, 1.0, 0, 7.6, 2, 3.2),
			B(0, 3.2, 1.3, 7.6, 2.6, 0.6),
			B(-3.5, 2.4, 0, 0.6, 2.8, 3.2),
			B(3.5, 2.4, 0, 0.6, 2.8, 3.2),
			B(-1.7, 2.3, -0.3, 3.2, 0.6, 2.4, true),
			B(1.7, 2.3, -0.3, 3.2, 0.6, 2.4, true),
			painted(B(-2.4, 3.2, 0.7, 1.4, 1.4, 0.5), 0.55, 0.2, 0.18, "SmoothPlastic"),
		},
	},
	{
		Id = "LeatherArmchair",
		Label = "Leather armchair",
		Category = "Game",
		Mount = "floor",
		Parts = {
			B(0, 1.0, 0, 3.8, 2, 3.2),
			B(0, 3.2, 1.3, 3.8, 2.6, 0.6),
			B(-1.65, 2.4, 0, 0.5, 2.8, 3.2),
			B(1.65, 2.4, 0, 0.5, 2.8, 3.2),
			B(0, 2.3, -0.3, 2.8, 0.6, 2.4, true),
		},
	},
	{
		Id = "CueRack",
		Label = "Cue rack",
		Category = "Game",
		Mount = "wall",
		Parts = {
			B(0, 5.5, -0.1, 3.6, 6.2, 0.2),
			B(0, 8.2, -0.35, 3.6, 0.25, 0.3),
			B(0, 3.4, -0.35, 3.6, 0.25, 0.3),
			B(-1.2, 5.8, -0.3, 0.15, 5.8, 0.15, true),
			B(-0.6, 5.8, -0.3, 0.15, 5.8, 0.15, true),
			B(0, 5.8, -0.3, 0.15, 5.8, 0.15, true),
			B(0.6, 5.8, -0.3, 0.15, 5.8, 0.15, true),
			B(1.2, 5.8, -0.3, 0.15, 5.8, 0.15, true),
		},
	},
	-- Library
	{
		Id = "LibraryShelf",
		Label = "Library shelf",
		Category = "Library",
		Mount = "floor",
		Parts = bookcase(6, 12, 0),
	},
	{
		Id = "LibraryLadder",
		Label = "Library ladder",
		Category = "Library",
		Mount = "floor",
		Parts = {
			B(-1, 4, 0, 0.2, 8, 0.2),
			B(1, 4, 0, 0.2, 8, 0.2),
			B(0, 1.5, 0, 2, 0.2, 0.3),
			B(0, 3, 0, 2, 0.2, 0.3),
			B(0, 4.5, 0, 2, 0.2, 0.3),
			B(0, 6, 0, 2, 0.2, 0.3),
			B(0, 7.5, 0, 2, 0.2, 0.3),
			B(0, 8.1, 0, 2.4, 0.2, 0.8, true),
			iron(C(-1, 0.25, 0, 0.5, 0.2)),
			iron(C(1, 0.25, 0, 0.5, 0.2)),
		},
	},
	{
		Id = "Lectern",
		Label = "Reading lectern",
		Category = "Library",
		Mount = "floor",
		Parts = {
			B(0, 0.2, 0, 2, 0.4, 2),
			C(0, 2.2, 0, 0.7, 3.6),
			B(0, 4.3, 0, 2.2, 0.2, 1.6, true),
			B(0, 4.5, -0.1, 1.6, 0.2, 1.2),
			B(0, 4.55, 0.7, 2.2, 0.5, 0.15, true),
		},
	},
	{
		Id = "CardCatalog",
		Label = "Card catalog",
		Category = "Library",
		Mount = "floor",
		Parts = {
			B(0, 2.2, 0, 3.8, 4.4, 1.8),
			B(0, 4.5, 0, 4, 0.2, 2),
			B(-1.2, 0.9, -0.95, 1.1, 1, 0.1, true),
			B(0, 0.9, -0.95, 1.1, 1, 0.1, true),
			B(1.2, 0.9, -0.95, 1.1, 1, 0.1, true),
			B(-1.2, 2.2, -0.95, 1.1, 1, 0.1, true),
			B(0, 2.2, -0.95, 1.1, 1, 0.1, true),
			B(1.2, 2.2, -0.95, 1.1, 1, 0.1, true),
			B(-1.2, 3.5, -0.95, 1.1, 1, 0.1, true),
			B(0, 3.5, -0.95, 1.1, 1, 0.1, true),
			B(1.2, 3.5, -0.95, 1.1, 1, 0.1, true),
			painted(S(-1.2, 0.9, -1.05, 0.2), 0.8, 0.65, 0.2, "Metal"),
			painted(S(0, 0.9, -1.05, 0.2), 0.8, 0.65, 0.2, "Metal"),
			painted(S(1.2, 0.9, -1.05, 0.2), 0.8, 0.65, 0.2, "Metal"),
			painted(S(-1.2, 2.2, -1.05, 0.2), 0.8, 0.65, 0.2, "Metal"),
			painted(S(0, 2.2, -1.05, 0.2), 0.8, 0.65, 0.2, "Metal"),
			painted(S(1.2, 2.2, -1.05, 0.2), 0.8, 0.65, 0.2, "Metal"),
			painted(S(-1.2, 3.5, -1.05, 0.2), 0.8, 0.65, 0.2, "Metal"),
			painted(S(0, 3.5, -1.05, 0.2), 0.8, 0.65, 0.2, "Metal"),
			painted(S(1.2, 3.5, -1.05, 0.2), 0.8, 0.65, 0.2, "Metal"),
		},
	},
	{
		Id = "ReadingTable",
		Label = "Reading table",
		Category = "Library",
		Mount = "floor",
		Parts = join(legs(2.6, 1.2, 2.8, 0.4), {
			B(0, 3, 0, 6.2, 0.4, 3.2, true),
			B(0, 0.8, 0, 5, 0.2, 0.2),
			B(-1.5, 3.3, 0, 1.2, 0.2, 0.9),
			B(1.4, 3.3, 0.2, 1, 0.2, 0.8),
		}),
	},
	-- Closet (bedroom)
	{
		Id = "ClosetRod",
		Label = "Clothes rod",
		Category = "Bedroom",
		Mount = "wall",
		Parts = {
			B(0, 6.4, -0.6, 6, 0.2, 1.2),
			steel(laid(C(0, 5.8, -0.6, 0.15, 6))),
			B(-2.4, 4.6, -0.6, 0.5, 2.4, 1, true),
			B(-1.6, 4.5, -0.6, 0.5, 2.6, 1),
			B(-0.8, 4.7, -0.6, 0.5, 2.2, 1, true),
			B(0, 4.5, -0.6, 0.5, 2.6, 1),
			B(0.8, 4.6, -0.6, 0.5, 2.4, 1, true),
			B(1.6, 4.5, -0.6, 0.5, 2.6, 1),
			B(2.4, 4.7, -0.6, 0.5, 2.2, 1, true),
		},
	},
	{
		Id = "ShoeRack",
		Label = "Shoe rack",
		Category = "Bedroom",
		Mount = "floor",
		Parts = {
			B(-2, 1.5, 0, 0.2, 3, 1.4),
			B(2, 1.5, 0, 0.2, 3, 1.4),
			B(0, 0.1, 0, 4.2, 0.2, 1.4),
			B(0, 1, 0, 4, 0.15, 1.4),
			B(0, 2, 0, 4, 0.15, 1.4),
			B(0, 2.95, 0, 4.2, 0.2, 1.4),
			B(-1.2, 0.4, 0, 0.8, 0.4, 0.5, true),
			B(0, 0.4, 0, 0.8, 0.4, 0.5),
			B(1.2, 0.4, 0, 0.8, 0.4, 0.5, true),
			B(-1.2, 1.4, 0, 0.8, 0.4, 0.5),
			B(0, 1.4, 0, 0.8, 0.4, 0.5, true),
			B(1.2, 1.4, 0, 0.8, 0.4, 0.5),
			B(-0.6, 2.4, 0, 0.8, 0.4, 0.5, true),
			B(0.7, 2.4, 0, 0.8, 0.4, 0.5),
		},
	},
	{
		Id = "ClosetShelves",
		Label = "Closet shelves",
		Category = "Bedroom",
		Mount = "floor",
		Parts = {
			B(-3, 3.5, 0, 0.3, 7, 1.6),
			B(0, 3.5, 0, 0.3, 7, 1.6),
			B(3, 3.5, 0, 0.3, 7, 1.6),
			B(0, 0.1, 0, 6.3, 0.2, 1.6),
			B(0, 1.9, 0, 6, 0.15, 1.6),
			B(0, 3.7, 0, 6, 0.15, 1.6),
			B(0, 5.5, 0, 6, 0.15, 1.6),
			B(0, 6.9, 0, 6.3, 0.2, 1.6),
			B(-1.5, 2.4, 0, 2.4, 0.8, 1.2, true),
			B(1.5, 2.3, 0, 2.4, 0.6, 1.2),
			B(-1.5, 4.2, 0, 2.4, 0.8, 1.2),
			B(1.5, 4.3, 0, 2.4, 1, 1.2, true),
			B(-1.5, 6.1, 0, 2.4, 0.8, 1.2, true),
			B(1.5, 6, 0, 2.4, 0.6, 1.2),
		},
	},
	{
		Id = "Hamper",
		Label = "Hamper",
		Category = "Bedroom",
		Mount = "floor",
		Parts = {
			C(0, 1.6, 0, 2, 3.2, true),
			C(0, 3.3, 0, 2.2, 0.2),
			S(0, 3.5, 0, 0.35),
		},
	},
	-- Butchery (kitchen)
	{
		Id = "ChestFreezer",
		Label = "Chest freezer",
		Category = "Kitchen",
		Mount = "floor",
		Parts = {
			B(0, 1.7, 0, 5, 3.4, 2.6),
			B(0, 3.5, 0, 5.2, 0.3, 2.8, true),
			iron(B(0, 3.4, -1.5, 2, 0.2, 0.2)),
			iron(B(-2.2, 0.15, -1, 0.5, 0.3, 0.5)),
			iron(B(2.2, 0.15, -1, 0.5, 0.3, 0.5)),
		},
	},
	{
		Id = "ButcherBlock",
		Label = "Butcher block",
		Category = "Kitchen",
		Mount = "floor",
		Parts = {
			B(0, 1.8, 0, 3.2, 3.6, 3.2),
			B(0, 3.75, 0, 3.4, 0.3, 3.4, true),
			steel(B(0.6, 4.1, -0.3, 1, 0.5, 0.12)),
			iron(B(-0.2, 4.1, -0.3, 0.7, 0.2, 0.2)),
		},
	},
	{
		Id = "HookRail",
		Label = "Meat hook rail",
		Category = "Kitchen",
		Mount = "ceiling",
		Parts = {
			steel(B(0, -0.15, 0, 8, 0.3, 0.4)),
			steel(C(-3, -0.9, 0, 0.12, 1.2)),
			steel(C(-1.5, -0.9, 0, 0.12, 1.2)),
			steel(C(0, -0.9, 0, 0.12, 1.2)),
			steel(C(1.5, -0.9, 0, 0.12, 1.2)),
			steel(C(3, -0.9, 0, 0.12, 1.2)),
			steel(S(-3, -1.7, 0, 0.35)),
			steel(S(-1.5, -1.7, 0, 0.35)),
			steel(S(0, -1.7, 0, 0.35)),
			steel(S(1.5, -1.7, 0, 0.35)),
			steel(S(3, -1.7, 0, 0.35)),
		},
	},
	{
		Id = "StainlessTable",
		Label = "Stainless table",
		Category = "Kitchen",
		Mount = "floor",
		Parts = join(steelLegs(3, 1.2, 3, 0.3), {
			steel(B(0, 3.1, 0, 7, 0.2, 3.2)),
			steel(B(0, 1, 0, 6.6, 0.15, 2.8)),
		}),
	},
	{
		Id = "SteelRack",
		Label = "Steel rack",
		Category = "Kitchen",
		Mount = "floor",
		Parts = join(steelLegs(2.5, 1, 7, 0.3), {
			steel(B(0, 0.4, 0, 5.3, 0.15, 2.3)),
			steel(B(0, 2.5, 0, 5.3, 0.15, 2.3)),
			steel(B(0, 4.6, 0, 5.3, 0.15, 2.3)),
			steel(B(0, 6.7, 0, 5.3, 0.15, 2.3)),
			B(-1.4, 1.2, 0, 1.8, 1.4, 1.6, true),
			B(1.2, 1.1, 0, 2, 1.2, 1.6),
			B(-1, 3.3, 0, 2.2, 1.2, 1.6),
			B(1.4, 3.4, 0, 1.4, 1.4, 1.6, true),
			B(0, 5.4, 0, 3, 1.2, 1.6, true),
		}),
	},
	{
		Id = "FreezerDoor",
		Label = "Freezer door",
		Category = "Kitchen",
		Mount = "wall",
		Parts = {
			steel(B(0, 3.6, -0.4, 5, 7.2, 0.8)),
			B(0, 3.5, -0.95, 4, 7, 0.2, true),
			iron(B(1.4, 3.5, -1.2, 0.2, 1.4, 0.3)),
			iron(B(-1.8, 5.5, -1.1, 0.15, 0.6, 0.2)),
			iron(B(-1.8, 1.5, -1.1, 0.15, 0.6, 0.2)),
			glowing(B(0, 5.4, -1.07, 1, 0.8, 0.05), 0.7, 0.85, 1),
		},
	},
	{
		Id = "HangingMeat",
		Label = "Hanging meat rail",
		Category = "Kitchen",
		Mount = "ceiling",
		Parts = {
			iron(B(0, -0.2, 0, 8.4, 0.3, 0.4)),
			iron(B(-3, -0.8, 0, 0.2, 1, 0.2)),
			iron(B(-1, -0.8, 0, 0.2, 1, 0.2)),
			iron(B(1, -0.8, 0, 0.2, 1, 0.2)),
			iron(B(3, -0.8, 0, 0.2, 1, 0.2)),
			painted(B(-3, -2.0, 0, 0.9, 1.4, 0.7), 0.6, 0.12, 0.12, "SmoothPlastic"),
			painted(B(-3, -3.8, 0, 1.5, 2.2, 1), 0.6, 0.12, 0.12, "SmoothPlastic"),
			painted(B(-3, -5.5, 0, 1.2, 1.2, 0.9), 0.6, 0.12, 0.12, "SmoothPlastic"),
			painted(B(-3, -3.8, -0.52, 0.5, 2, 0.1), 0.88, 0.78, 0.7, "SmoothPlastic"),
			painted(B(-1, -2.0, 0, 0.9, 1.4, 0.7), 0.6, 0.12, 0.12, "SmoothPlastic"),
			painted(B(-1, -3.8, 0, 1.5, 2.2, 1), 0.6, 0.12, 0.12, "SmoothPlastic"),
			painted(B(-1, -5.5, 0, 1.2, 1.2, 0.9), 0.6, 0.12, 0.12, "SmoothPlastic"),
			painted(B(-1, -3.8, -0.52, 0.5, 2, 0.1), 0.88, 0.78, 0.7, "SmoothPlastic"),
			painted(B(1, -2.0, 0, 0.9, 1.4, 0.7), 0.6, 0.12, 0.12, "SmoothPlastic"),
			painted(B(1, -3.8, 0, 1.5, 2.2, 1), 0.6, 0.12, 0.12, "SmoothPlastic"),
			painted(B(1, -5.5, 0, 1.2, 1.2, 0.9), 0.6, 0.12, 0.12, "SmoothPlastic"),
			painted(B(1, -3.8, -0.52, 0.5, 2, 0.1), 0.88, 0.78, 0.7, "SmoothPlastic"),
			painted(B(3, -2.0, 0, 0.9, 1.4, 0.7), 0.6, 0.12, 0.12, "SmoothPlastic"),
			painted(B(3, -3.8, 0, 1.5, 2.2, 1), 0.6, 0.12, 0.12, "SmoothPlastic"),
			painted(B(3, -5.5, 0, 1.2, 1.2, 0.9), 0.6, 0.12, 0.12, "SmoothPlastic"),
			painted(B(3, -3.8, -0.52, 0.5, 2, 0.1), 0.88, 0.78, 0.7, "SmoothPlastic"),
		},
	},
	{
		Id = "EvaporatorFan",
		Label = "Cooler fan unit",
		Category = "Kitchen",
		Mount = "ceiling",
		Parts = {
			painted(B(0, -0.9, 0, 6, 1.8, 2.4), 0.85, 0.87, 0.88, "SmoothPlastic"),
			iron(C(-1.5, -1.85, 0, 2, 0.15)),
			iron(C(1.5, -1.85, 0, 2, 0.15)),
			steel(B(0, -1.9, 0, 0.2, 0.1, 2.2)),
			iron(B(-2.6, -0.4, 1.4, 0.3, 0.3, 0.5)),
		},
	},
	{
		Id = "MeatCrates",
		Label = "Meat crates",
		Category = "Kitchen",
		Mount = "floor",
		Parts = {
			painted(B(-1.5, 0.8, 0, 2.8, 1.6, 2), 0.9, 0.9, 0.88, "SmoothPlastic"),
			painted(B(-1.5, 2.4, 0, 2.8, 1.6, 2), 0.9, 0.9, 0.88, "SmoothPlastic"),
			painted(B(-1.5, 3.3, 0, 2.4, 0.2, 1.6), 0.6, 0.12, 0.12, "SmoothPlastic"),
			painted(B(1.6, 0.8, 0, 2.8, 1.6, 2), 0.65, 0.15, 0.12, "SmoothPlastic"),
			painted(B(1.6, 2.4, 0, 2.8, 1.6, 2), 0.65, 0.15, 0.12, "SmoothPlastic"),
			painted(B(1.6, 3.3, 0, 2.4, 0.2, 1.6), 0.55, 0.1, 0.1, "SmoothPlastic"),
		},
	},
	{
		Id = "MeatCart",
		Label = "Meat cart",
		Category = "Kitchen",
		Mount = "floor",
		Parts = join(steelLegs(2, 1, 2.6, 0.2), {
			steel(B(0, 0.9, 0, 4.4, 0.15, 2.4)),
			steel(B(0, 1.8, 0, 4.4, 0.15, 2.4)),
			steel(B(0, 2.7, 0, 4.4, 0.15, 2.4)),
			steel(B(0, 2.95, -1.15, 4.4, 0.4, 0.1)),
			steel(B(0, 2.95, 1.15, 4.4, 0.4, 0.1)),
			painted(B(-1, 3.0, 0, 1.6, 0.4, 1.4), 0.6, 0.12, 0.12, "SmoothPlastic"),
			painted(B(1.1, 3.0, 0, 1.4, 0.35, 1.3), 0.7, 0.18, 0.15, "SmoothPlastic"),
			iron(B(2.35, 3.5, -1.1, 0.15, 1.6, 0.15)),
			iron(B(2.35, 3.5, 1.1, 0.15, 1.6, 0.15)),
			iron(B(2.35, 4.3, 0, 0.15, 0.15, 2.4)),
			iron(S(-1.9, 0.2, -0.9, 0.4)),
			iron(S(1.9, 0.2, -0.9, 0.4)),
			iron(S(-1.9, 0.2, 0.9, 0.4)),
			iron(S(1.9, 0.2, 0.9, 0.4)),
		}),
	},
	-- Dungeon and cellar
	{
		Id = "RestraintChair",
		Label = "Restraint chair",
		Category = "Dungeon",
		Mount = "floor",
		Parts = join(legs(0.9, 0.9, 1.8, 0.3), {
			B(0, 1.9, 0, 2.2, 0.3, 2.2),
			B(0, 3.7, 0.95, 2.2, 3.5, 0.3),
			B(-1.05, 2.6, 0, 0.2, 0.3, 2.1),
			B(1.05, 2.6, 0, 0.2, 0.3, 2.1),
			B(-1.05, 2.8, -0.2, 0.35, 0.15, 0.5, true),
			B(1.05, 2.8, -0.2, 0.35, 0.15, 0.5, true),
			B(0, 3.8, 0.75, 2.3, 0.4, 0.1, true),
			B(0, 0.7, -0.9, 2, 0.15, 0.1, true),
		}),
	},
	{
		Id = "IronCage",
		Label = "Iron cage",
		Category = "Dungeon",
		Mount = "floor",
		Parts = cage(),
	},
	{
		Id = "WallShackles",
		Label = "Wall shackles",
		Category = "Dungeon",
		Mount = "wall",
		Parts = {
			iron(B(0, 7, -0.2, 4, 0.6, 0.4)),
			iron(S(-1.2, 6.4, -0.4, 0.3)),
			iron(S(-1.2, 5.8, -0.4, 0.3)),
			iron(S(-1.2, 5.2, -0.4, 0.3)),
			iron(S(-1.2, 4.6, -0.4, 0.3)),
			iron(S(1.2, 6.4, -0.4, 0.3)),
			iron(S(1.2, 5.8, -0.4, 0.3)),
			iron(S(1.2, 5.2, -0.4, 0.3)),
			iron(S(1.2, 4.6, -0.4, 0.3)),
			iron(B(-1.2, 4.1, -0.5, 0.7, 0.5, 0.5)),
			iron(B(1.2, 4.1, -0.5, 0.7, 0.5, 0.5)),
		},
	},
	{
		Id = "ToolTable",
		Label = "Tool table",
		Category = "Dungeon",
		Mount = "floor",
		Parts = join(legs(2.4, 1.1, 2.8, 0.4), {
			B(0, 3, 0, 5.6, 0.3, 2.8, true),
			steel(B(-1.6, 3.2, -0.2, 1.6, 0.1, 0.25)),
			steel(B(0.2, 3.2, 0.2, 0.3, 0.1, 1.4)),
			iron(B(1.5, 3.2, -0.3, 0.9, 0.1, 0.9)),
		}),
	},
	{
		Id = "Bucket",
		Label = "Bucket",
		Category = "Dungeon",
		Mount = "floor",
		Parts = {
			steel(C(0, 0.9, 0, 1.4, 1.8)),
			painted(C(0, 1.7, 0, 1.2, 0.1), 0.2, 0.3, 0.35, "SmoothPlastic"),
			steel(B(0, 2.2, 0, 1.5, 0.1, 0.1)),
		},
	},
	{
		Id = "FloorDrain",
		Label = "Floor drain",
		Category = "Dungeon",
		Mount = "floor",
		Parts = {
			iron(B(0, 0.05, 0, 1.8, 0.1, 1.8)),
			steel(B(0, 0.12, 0, 1.4, 0.05, 0.1)),
			steel(B(0, 0.12, -0.35, 1.4, 0.05, 0.1)),
			steel(B(0, 0.12, 0.35, 1.4, 0.05, 0.1)),
		},
	},
	{
		Id = "Stocks",
		Label = "Stocks",
		Category = "Dungeon",
		Mount = "floor",
		Parts = {
			B(-2.5, 3, 0, 0.5, 6, 0.5),
			B(2.5, 3, 0, 0.5, 6, 0.5),
			B(-2.5, 0.2, 0, 0.6, 0.4, 2),
			B(2.5, 0.2, 0, 0.6, 0.4, 2),
			B(0, 2.6, 0, 4.6, 0.8, 0.4),
			B(0, 3.6, 0, 4.6, 0.8, 0.4, true),
		},
	},
	{
		Id = "HangingChains",
		Label = "Hanging chains",
		Category = "Dungeon",
		Mount = "ceiling",
		Parts = hangingChains(),
	},
	-- Jail
	{
		Id = "JailBars",
		Label = "Jail bars",
		Category = "Dungeon",
		Mount = "floor",
		Parts = bars(8, 9, 0, 0),
	},
	{
		Id = "JailDoor",
		Label = "Cell door",
		Category = "Dungeon",
		Mount = "floor",
		Parts = join(bars(4.6, 8.4, 0, 0), {
			iron(B(-2.5, 4.2, 0, 0.4, 8.4, 0.5)),
			iron(B(2.5, 4.2, 0, 0.4, 8.4, 0.5)),
			iron(B(0, 8.6, 0, 5.4, 0.4, 0.5)),
			iron(B(0, 4.2, -0.3, 0.2, 8, 0.1)),
			steel(B(1.9, 4, -0.35, 0.6, 0.9, 0.3)),
			iron(S(1.9, 4, -0.55, 0.3)),
			iron(B(-2.3, 1.5, -0.3, 0.3, 0.5, 0.3)),
			iron(B(-2.3, 6.5, -0.3, 0.3, 0.5, 0.3)),
		}),
	},
	{
		Id = "BarredWindow",
		Label = "Barred window",
		Category = "Dungeon",
		Mount = "wall",
		Parts = {
			iron(B(0, 7, -0.2, 3.4, 0.4, 0.4)),
			iron(B(0, 4.6, -0.2, 3.4, 0.4, 0.4)),
			iron(B(-1.5, 5.8, -0.2, 0.4, 2.4, 0.4)),
			iron(B(1.5, 5.8, -0.2, 0.4, 2.4, 0.4)),
			iron(B(-0.75, 5.8, -0.25, 0.2, 2.2, 0.2)),
			iron(B(0, 5.8, -0.25, 0.2, 2.2, 0.2)),
			iron(B(0.75, 5.8, -0.25, 0.2, 2.2, 0.2)),
		},
	},
	{
		Id = "JailBunk",
		Label = "Jail bunk bed",
		Category = "Dungeon",
		Mount = "floor",
		Parts = join(steelLegs(1.4, 2.9, 6.5, 0.3), {
			steel(B(0, 1.6, 0, 3, 0.2, 6.2)),
			steel(B(0, 4.4, 0, 3, 0.2, 6.2)),
			painted(B(0, 1.95, 0, 2.8, 0.5, 6), 0.45, 0.47, 0.5, "Fabric"),
			painted(B(0, 4.75, 0, 2.8, 0.5, 6), 0.45, 0.47, 0.5, "Fabric"),
			painted(B(0, 2.3, 2.5, 2, 0.3, 1), 0.8, 0.8, 0.78, "Fabric"),
			painted(B(0, 5.1, 2.5, 2, 0.3, 1), 0.8, 0.8, 0.78, "Fabric"),
			steel(B(1.4, 6.2, 0, 0.15, 0.15, 6)),
		}),
	},
	{
		Id = "StrawBed",
		Label = "Straw bed",
		Category = "Dungeon",
		Mount = "floor",
		Parts = {
			painted(B(0, 0.25, 0, 3.6, 0.5, 6), 0.78, 0.65, 0.3, "Fabric"),
			painted(B(-0.5, 0.65, -0.5, 2.4, 0.3, 4.6), 0.85, 0.72, 0.35, "Fabric"),
			painted(B(0.7, 0.8, 2, 1.4, 0.3, 1.2), 0.7, 0.58, 0.3, "Fabric"),
		},
	},
	{
		Id = "CellToilet",
		Label = "Cell toilet",
		Category = "Dungeon",
		Mount = "floor",
		Parts = {
			steel(C(0, 1, -0.1, 1.5, 2)),
			steel(B(0, 2.1, 0.5, 1.6, 0.3, 1.2)),
			steel(B(0, 2.9, 0.85, 1.6, 1.6, 0.5)),
			iron(S(0.5, 3.4, 0.55, 0.25)),
		},
	},
	{
		Id = "CellSink",
		Label = "Cell sink",
		Category = "Dungeon",
		Mount = "wall",
		Parts = {
			steel(B(0, 3.2, -0.6, 2.2, 0.2, 1.2)),
			steel(B(-1.0, 3.5, -0.6, 0.2, 0.4, 1.2)),
			steel(B(1.0, 3.5, -0.6, 0.2, 0.4, 1.2)),
			steel(B(0, 3.5, -1.1, 2.2, 0.4, 0.2)),
			steel(B(0, 3.8, -0.2, 2.2, 0.4, 0.4)),
			iron(C(0, 4.3, -0.3, 0.2, 0.6)),
		},
	},
	{
		Id = "KeyBoard",
		Label = "Key board",
		Category = "Dungeon",
		Mount = "wall",
		Parts = {
			B(0, 5, -0.15, 2.6, 3, 0.3),
			iron(B(0, 6.2, -0.35, 2.2, 0.15, 0.1)),
			iron(B(0, 4.6, -0.35, 2.2, 0.15, 0.1)),
			painted(B(-0.8, 5.6, -0.45, 0.15, 0.7, 0.1), 0.8, 0.65, 0.2, "Metal"),
			painted(B(0, 5.6, -0.45, 0.15, 0.7, 0.1), 0.8, 0.65, 0.2, "Metal"),
			painted(B(0.8, 5.6, -0.45, 0.15, 0.7, 0.1), 0.8, 0.65, 0.2, "Metal"),
			painted(B(-0.4, 4.0, -0.45, 0.15, 0.7, 0.1), 0.8, 0.65, 0.2, "Metal"),
			painted(B(0.4, 4.0, -0.45, 0.15, 0.7, 0.1), 0.8, 0.65, 0.2, "Metal"),
		},
	},
	{
		Id = "GuardDesk",
		Label = "Guard desk",
		Category = "Dungeon",
		Mount = "floor",
		Parts = join(legs(2.8, 1.1, 2.6, 0.4), {
			B(0, 2.8, 0, 6.4, 0.3, 3),
			B(-1.8, 1.2, 0.1, 2, 2.2, 2.4, true),
			iron(B(-1.8, 1.9, -1.15, 0.8, 0.12, 0.1)),
			iron(B(-1.8, 0.9, -1.15, 0.8, 0.12, 0.1)),
			painted(B(1.4, 3.0, 0, 1.6, 0.1, 1.2), 0.85, 0.82, 0.7, "Fabric"),
		}),
	},
	{
		Id = "BallAndChain",
		Label = "Ball and chain",
		Category = "Dungeon",
		Mount = "floor",
		Parts = {
			iron(S(0, 1, 0, 2)),
			iron(S(1.3, 0.2, 0, 0.4)),
			iron(S(1.8, 0.2, 0, 0.4)),
			iron(S(2.3, 0.2, 0, 0.4)),
			iron(S(2.8, 0.2, 0.2, 0.4)),
			iron(B(3.4, 0.15, 0.3, 0.8, 0.3, 0.8)),
		},
	},
	{
		Id = "BonePile",
		Label = "Bone pile",
		Category = "Dungeon",
		Mount = "floor",
		Parts = {
			painted(S(0, 0.55, 0, 1.1), 0.9, 0.88, 0.8, "SmoothPlastic"),
			painted(B(0, 0.15, 0.4, 0.5, 0.3, 0.3), 0.9, 0.88, 0.8, "SmoothPlastic"),
			turned(painted(B(1.1, 0.15, 0.2, 2.2, 0.3, 0.3), 0.9, 0.88, 0.8, "SmoothPlastic"), 20),
			turned(painted(B(-1.2, 0.15, -0.3, 2, 0.3, 0.3), 0.9, 0.88, 0.8, "SmoothPlastic"), 35),
			turned(painted(B(0.2, 0.15, -1, 1.8, 0.3, 0.3), 0.9, 0.88, 0.8, "SmoothPlastic"), -20),
			painted(B(-0.4, 0.45, -0.7, 1.4, 0.2, 0.9), 0.85, 0.82, 0.74, "SmoothPlastic"),
		},
	},
	{
		Id = "IronMaiden",
		Label = "Iron maiden",
		Category = "Dungeon",
		Mount = "floor",
		Parts = {
			iron(B(0, 3.5, 0, 3, 7, 2.2)),
			iron(B(-0.8, 3.5, -1.15, 1.4, 6.4, 0.2)),
			iron(B(0.8, 3.5, -1.15, 1.4, 6.4, 0.2)),
			painted(B(0, 6.2, -1.3, 1.2, 0.8, 0.1), 0.85, 0.82, 0.7, "SmoothPlastic"),
			painted(B(0, 5.3, -1.3, 0.3, 0.8, 0.1), 0.7, 0.1, 0.1, "SmoothPlastic"),
			iron(B(0, 0.2, -0.2, 3.4, 0.4, 2.6)),
		},
	},
	{
		Id = "StretchingRack",
		Label = "Stretching rack",
		Category = "Dungeon",
		Mount = "floor",
		Parts = join(legs(1.4, 3.6, 1.6, 0.4), {
			B(0, 1.8, 0, 3.2, 0.3, 8.4),
			B(0, 2.2, 0, 2.8, 0.15, 7.6, true),
			laid(C(0, 2.4, 4.2, 0.7, 3.4)),
			laid(C(0, 2.4, -4.2, 0.7, 3.4)),
			iron(B(-1.6, 2.4, 4.2, 0.2, 1.8, 0.2)),
			iron(B(1.6, 2.4, -4.2, 0.2, 1.8, 0.2)),
			iron(S(0, 2.5, 3.4, 0.4)),
			iron(S(0, 2.5, -3.4, 0.4)),
		}),
	},
	-- Secret room
	{
		Id = "BookshelfDoor",
		Label = "Secret bookshelf",
		Category = "Dungeon",
		Mount = "wall",
		Parts = join(bookcase(6.4, 10, -0.8), {
			B(1.4, 4.5, -1.7, 0.3, 0.3, 0.3, true),
		}),
	},
	{
		Id = "Safe",
		Label = "Safe",
		Category = "Dungeon",
		Mount = "floor",
		Parts = {
			steel(B(0, 2, 0, 3, 4, 2.6)),
			B(0, 2, -1.35, 2.6, 3.6, 0.15, true),
			iron(S(0, 2.3, -1.45, 0.8)),
			iron(B(0.8, 1.6, -1.5, 0.6, 0.15, 0.15)),
			iron(B(-1.2, 0.15, -1, 0.5, 0.3, 0.5)),
			iron(B(1.2, 0.15, -1, 0.5, 0.3, 0.5)),
		},
	},
	{
		Id = "Altar",
		Label = "Altar",
		Category = "Dungeon",
		Mount = "floor",
		Parts = join({
			B(0, 1.5, 0, 5, 3, 2.6),
			B(0, 3.05, 0, 5.2, 0.1, 2.8, true),
			B(0, 3.25, 0, 1.4, 0.3, 1, true),
		}, candle(-1.8, 3.1, 0), candle(1.8, 3.1, 0)),
	},
	{
		Id = "MapTable",
		Label = "Map table",
		Category = "Dungeon",
		Mount = "floor",
		Parts = join(legs(3, 1.6, 3, 0.4), {
			B(0, 3.15, 0, 7.2, 0.3, 4, false),
			painted(B(0, 3.33, 0, 6, 0.05, 3.2), 0.85, 0.78, 0.6, "Fabric"),
			painted(S(1, 3.5, 0.4, 0.25), 0.85, 0.1, 0.1, "SmoothPlastic"),
			painted(S(-1.5, 3.5, -0.6, 0.25), 0.2, 0.4, 0.9, "SmoothPlastic"),
			painted(S(0, 3.5, -0.2, 0.25), 0.2, 0.7, 0.3, "SmoothPlastic"),
		}),
	},
	{
		Id = "LockedChest",
		Label = "Locked chest",
		Category = "Dungeon",
		Mount = "floor",
		Parts = {
			B(0, 1, 0, 3.4, 2, 2.2),
			B(0, 2.3, 0, 3.4, 0.6, 2.2, true),
			painted(B(-1.2, 1.3, 0, 0.3, 2.6, 2.3), 0.8, 0.65, 0.2, "Metal"),
			painted(B(1.2, 1.3, 0, 0.3, 2.6, 2.3), 0.8, 0.65, 0.2, "Metal"),
			painted(B(0, 1.5, -1.15, 0.5, 0.6, 0.1), 0.8, 0.65, 0.2, "Metal"),
		},
	},
	-- Electrical room
	{
		Id = "BreakerPanel",
		Label = "Breaker panel",
		Category = "Electrical",
		Mount = "wall",
		Parts = {
			steel(B(0, 4.5, -0.4, 3, 4, 0.8)),
			B(0, 4.5, -0.85, 2.6, 3.6, 0.1, true),
			iron(B(-0.5, 5.6, -0.95, 0.5, 0.3, 0.1)),
			iron(B(0.5, 5.6, -0.95, 0.5, 0.3, 0.1)),
			iron(B(-0.5, 4.8, -0.95, 0.5, 0.3, 0.1)),
			iron(B(0.5, 4.8, -0.95, 0.5, 0.3, 0.1)),
			iron(B(-0.5, 4, -0.95, 0.5, 0.3, 0.1)),
			iron(B(0.5, 4, -0.95, 0.5, 0.3, 0.1)),
			glowing(S(0, 3.3, -0.95, 0.25), 1, 0.15, 0.1),
		},
	},
	{
		Id = "Generator",
		Label = "Generator",
		Category = "Electrical",
		Mount = "floor",
		Parts = {
			painted(B(0, 2, 0, 6, 3.4, 3.4), 0.85, 0.45, 0.1, "Metal"),
			iron(B(-2.5, 0.15, 0, 0.5, 0.3, 3.4)),
			iron(B(2.5, 0.15, 0, 0.5, 0.3, 3.4)),
			steel(laid(C(0, 4.2, 0, 1.8, 4.5))),
			iron(C(2.3, 4.6, 0.8, 0.5, 2)),
			iron(B(0, 2.4, -1.75, 3, 1.2, 0.1)),
			glowing(B(-1, 2.4, -1.82, 0.3, 0.2, 0.05), 0.2, 1, 0.3),
			glowing(B(0, 2.4, -1.82, 0.3, 0.2, 0.05), 1, 0.2, 0.1),
		},
	},
	{
		Id = "Transformer",
		Label = "Transformer",
		Category = "Electrical",
		Mount = "floor",
		Parts = {
			painted(B(0, 0.4, 0, 4.4, 0.8, 4.4), 0.55, 0.55, 0.55, "Concrete"),
			painted(C(0, 3.2, 0, 3.4, 4.8), 0.5, 0.55, 0.5, "Metal"),
			painted(B(-2, 3.2, 0, 0.3, 4, 2.2), 0.5, 0.55, 0.5, "Metal"),
			painted(B(2, 3.2, 0, 0.3, 4, 2.2), 0.5, 0.55, 0.5, "Metal"),
			painted(C(-1, 6.2, 0, 0.5, 1.2), 0.9, 0.88, 0.8, "SmoothPlastic"),
			painted(C(0, 6.2, 0, 0.5, 1.2), 0.9, 0.88, 0.8, "SmoothPlastic"),
			painted(C(1, 6.2, 0, 0.5, 1.2), 0.9, 0.88, 0.8, "SmoothPlastic"),
			iron(S(-1, 6.9, 0, 0.5)),
			iron(S(0, 6.9, 0, 0.5)),
			iron(S(1, 6.9, 0, 0.5)),
		},
	},
	{
		Id = "CableTray",
		Label = "Cable tray",
		Category = "Electrical",
		Mount = "ceiling",
		Parts = {
			steel(B(0, -0.55, 0, 10, 0.1, 1.6)),
			steel(B(0, -0.35, -0.75, 10, 0.4, 0.1)),
			steel(B(0, -0.35, 0.75, 10, 0.4, 0.1)),
			steel(B(-4, -0.2, 0, 0.15, 0.4, 1.8)),
			steel(B(0, -0.2, 0, 0.15, 0.4, 1.8)),
			steel(B(4, -0.2, 0, 0.15, 0.4, 1.8)),
			painted(B(0, -0.4, -0.3, 10, 0.2, 0.3), 0.1, 0.1, 0.1, "SmoothPlastic"),
			painted(B(0, -0.4, 0.2, 10, 0.2, 0.3), 0.8, 0.1, 0.1, "SmoothPlastic"),
		},
	},
	{
		Id = "ElectricalCabinet",
		Label = "Electrical cabinet",
		Category = "Electrical",
		Mount = "floor",
		Parts = {
			steel(B(0, 4, 0, 3.2, 8, 1.6)),
			B(-0.8, 4, -0.85, 1.5, 7.4, 0.1, true),
			B(0.8, 4, -0.85, 1.5, 7.4, 0.1, true),
			iron(B(-0.15, 4, -0.95, 0.1, 1, 0.1)),
			iron(B(0.15, 4, -0.95, 0.1, 1, 0.1)),
			painted(B(0.8, 5.5, -0.93, 0.8, 0.8, 0.05), 0.95, 0.8, 0.1, "SmoothPlastic"),
		},
	},
	{
		Id = "CableReel",
		Label = "Cable reel",
		Category = "Electrical",
		Mount = "floor",
		Parts = {
			C(0, 0.1, 0, 3, 0.2, true),
			C(0, 1.6, 0, 1.2, 2.8),
			C(0, 3, 0, 3, 0.2, true),
			painted(C(0, 1.6, 0, 2.2, 2.6), 0.1, 0.1, 0.1, "SmoothPlastic"),
		},
	},
	-- Art room
	{
		Id = "Easel",
		Label = "Easel",
		Category = "Art",
		Mount = "floor",
		Parts = {
			B(-1.4, 3.5, 0, 0.2, 7, 0.2),
			B(1.4, 3.5, 0, 0.2, 7, 0.2),
			B(0, 3, 0.8, 0.2, 6, 0.2),
			B(0, 5.5, 0, 3, 0.2, 0.2),
			B(0, 2.4, -0.3, 3, 0.15, 0.6),
			B(0, 4.2, -0.2, 2.6, 3.4, 0.15, true),
			painted(B(-0.5, 4.5, -0.3, 0.6, 0.5, 0.05), 0.8, 0.2, 0.2, "SmoothPlastic"),
			painted(B(0.5, 3.8, -0.3, 0.8, 0.4, 0.05), 0.2, 0.4, 0.8, "SmoothPlastic"),
		},
	},
	{
		Id = "ArtTable",
		Label = "Art table",
		Category = "Art",
		Mount = "floor",
		Parts = join(legs(3, 1.4, 3, 0.4), {
			B(0, 3.1, 0, 7.4, 0.3, 3.6, true),
			painted(C(-2.4, 3.55, 0, 0.5, 0.6), 0.8, 0.2, 0.2, "Glass", 0.3),
			painted(C(-1.6, 3.55, 0.4, 0.5, 0.6), 0.2, 0.4, 0.8, "Glass", 0.3),
			painted(C(-0.8, 3.55, -0.3, 0.5, 0.6), 0.9, 0.8, 0.2, "Glass", 0.3),
			B(1.5, 3.4, 0, 1.4, 0.3, 1),
		}),
	},
	{
		Id = "PaintCart",
		Label = "Paint cart",
		Category = "Art",
		Mount = "floor",
		Parts = join(legs(1.7, 0.9, 3.4, 0.2), {
			B(0, 0.7, 0, 3.8, 0.15, 2.2, true),
			B(0, 1.9, 0, 3.8, 0.15, 2.2),
			B(0, 3.1, 0, 3.8, 0.15, 2.2, true),
			iron(C(-1.5, 0.2, -0.9, 0.4, 0.4)),
			iron(C(1.5, 0.2, -0.9, 0.4, 0.4)),
			painted(C(-1.2, 2.25, 0, 0.7, 0.6), 0.8, 0.2, 0.2, "Metal"),
			painted(C(0, 2.25, 0, 0.7, 0.6), 0.2, 0.4, 0.8, "Metal"),
			painted(C(1.2, 2.25, 0, 0.7, 0.6), 0.9, 0.8, 0.2, "Metal"),
			painted(C(-0.6, 3.45, 0, 0.7, 0.6), 0.2, 0.7, 0.3, "Metal"),
			painted(C(0.6, 3.45, 0, 0.7, 0.6), 0.9, 0.9, 0.9, "Metal"),
		}),
	},
	{
		Id = "CanvasRack",
		Label = "Canvas rack",
		Category = "Art",
		Mount = "floor",
		Parts = {
			B(-2.5, 3, 0, 0.3, 6, 2),
			B(2.5, 3, 0, 0.3, 6, 2),
			B(0, 0.1, 0, 5.3, 0.2, 2),
			B(0, 5.9, 0, 5.3, 0.2, 2),
			B(-1.5, 2.8, -0.4, 0.15, 5.2, 0.9, true),
			B(-0.5, 2.8, -0.2, 0.15, 5.2, 0.9),
			B(0.5, 2.8, 0, 0.15, 5.2, 0.9, true),
			B(1.5, 2.8, -0.3, 0.15, 5.2, 0.9),
		},
	},
	{
		Id = "PotteryWheel",
		Label = "Pottery wheel",
		Category = "Art",
		Mount = "floor",
		Parts = {
			C(0, 1, 0, 2, 2),
			C(0, 2.1, 0, 2.4, 0.2, true),
			painted(S(0, 2.5, 0, 0.9), 0.6, 0.38, 0.25, "Slate"),
			C(0, 0.1, 0, 3, 0.2),
			C(-3, 1.2, 0, 1.6, 0.2),
			C(-3, 0.6, 0, 0.2, 1.2),
		},
	},
	{
		Id = "Sculpture",
		Label = "Sculpture",
		Category = "Art",
		Mount = "floor",
		Parts = {
			B(0, 2, 0, 2, 4, 2),
			painted(B(0, 5.2, 0, 1.2, 2, 1), 0.9, 0.9, 0.88, "Marble"),
			painted(S(0, 6.6, 0, 0.9), 0.9, 0.9, 0.88, "Marble"),
			painted(B(-0.85, 5.2, 0, 0.3, 1.8, 0.4), 0.9, 0.9, 0.88, "Marble"),
			painted(B(0.85, 5.2, 0, 0.3, 1.8, 0.4), 0.9, 0.9, 0.88, "Marble"),
		},
	},
	-- Storage and attic
	{
		Id = "AtticLadder",
		Label = "Attic ladder",
		Category = "Attic",
		Mount = "ceiling",
		Parts = {
			B(0, -0.2, 0, 3, 0.4, 4.4, true),
			B(-1, -4.9, 0, 0.25, 9, 0.3),
			B(1, -4.9, 0, 0.25, 9, 0.3),
			B(0, -1, 0, 1.8, 0.2, 0.3),
			B(0, -2.4, 0, 1.8, 0.2, 0.3),
			B(0, -3.8, 0, 1.8, 0.2, 0.3),
			B(0, -5.2, 0, 1.8, 0.2, 0.3),
			B(0, -6.6, 0, 1.8, 0.2, 0.3),
			B(0, -8, 0, 1.8, 0.2, 0.3),
			iron(B(0, -0.45, -1.6, 0.4, 0.1, 0.5)),
		},
	},
	{
		Id = "PalletLoad",
		Label = "Pallet load",
		Category = "Basement",
		Mount = "floor",
		Parts = {
			B(-1.6, 0.25, -1.6, 0.6, 0.3, 0.6),
			B(0, 0.25, -1.6, 0.6, 0.3, 0.6),
			B(1.6, 0.25, -1.6, 0.6, 0.3, 0.6),
			B(-1.6, 0.25, 0, 0.6, 0.3, 0.6),
			B(0, 0.25, 0, 0.6, 0.3, 0.6),
			B(1.6, 0.25, 0, 0.6, 0.3, 0.6),
			B(-1.6, 0.25, 1.6, 0.6, 0.3, 0.6),
			B(0, 0.25, 1.6, 0.6, 0.3, 0.6),
			B(1.6, 0.25, 1.6, 0.6, 0.3, 0.6),
			B(0, 0.5, -1.6, 4, 0.2, 0.7),
			B(0, 0.5, 0, 4, 0.2, 0.7),
			B(0, 0.5, 1.6, 4, 0.2, 0.7),
			B(-0.7, 1.5, 0, 2.2, 1.8, 3, true),
			B(1.1, 1.3, 0, 1.4, 1.4, 3),
			B(0.3, 2.9, 0, 2, 1, 2.4, true),
		},
	},
	{
		Id = "Lockers",
		Label = "Lockers",
		Category = "Basement",
		Mount = "floor",
		Parts = {
			steel(B(-1.7, 3.5, 0, 1.6, 7, 1.6)),
			steel(B(0, 3.5, 0, 1.6, 7, 1.6)),
			steel(B(1.7, 3.5, 0, 1.6, 7, 1.6)),
			B(-1.7, 3.5, -0.85, 1.4, 6.6, 0.1, true),
			B(0, 3.5, -0.85, 1.4, 6.6, 0.1, true),
			B(1.7, 3.5, -0.85, 1.4, 6.6, 0.1, true),
			iron(B(-1.3, 3.5, -0.95, 0.1, 0.8, 0.1)),
			iron(B(0.4, 3.5, -0.95, 0.1, 0.8, 0.1)),
			iron(B(2.1, 3.5, -0.95, 0.1, 0.8, 0.1)),
		},
	},
	{
		Id = "HeavyRack",
		Label = "Heavy rack",
		Category = "Basement",
		Mount = "floor",
		Parts = {
			painted(B(-4, 5, -1.2, 0.4, 10, 0.4), 0.2, 0.35, 0.7, "Metal"),
			painted(B(4, 5, -1.2, 0.4, 10, 0.4), 0.2, 0.35, 0.7, "Metal"),
			painted(B(-4, 5, 1.2, 0.4, 10, 0.4), 0.2, 0.35, 0.7, "Metal"),
			painted(B(4, 5, 1.2, 0.4, 10, 0.4), 0.2, 0.35, 0.7, "Metal"),
			painted(B(0, 0.4, 0, 8.4, 0.3, 2.8), 0.85, 0.45, 0.1, "Metal"),
			painted(B(0, 3.6, 0, 8.4, 0.3, 2.8), 0.85, 0.45, 0.1, "Metal"),
			painted(B(0, 6.8, 0, 8.4, 0.3, 2.8), 0.85, 0.45, 0.1, "Metal"),
			B(-2.5, 1.5, 0, 2.6, 1.8, 2.2, true),
			B(1.5, 1.4, 0, 3.4, 1.6, 2.2),
			B(-1, 4.7, 0, 3, 1.8, 2.2),
			B(2.6, 4.6, 0, 2, 1.6, 2.2, true),
			B(0, 7.9, 0, 5, 1.8, 2.2, true),
		},
	},
	-- More lighting
	{
		Id = "BareBulb",
		Label = "Bare bulb",
		Category = "Lighting",
		Mount = "ceiling",
		Parts = {
			C(0, -0.15, 0, 0.6, 0.3, true),
			iron(C(0, -1.2, 0, 0.08, 1.8)),
			iron(C(0, -2.2, 0, 0.4, 0.4)),
			glowing(S(0, -2.7, 0, 0.8), 1, 0.9, 0.6),
			lamp(0, -2.7, 0),
			lights(0, -2.7, 0, 0.3, 10),
		},
	},
	{
		Id = "FluorescentLight",
		Label = "Fluorescent light",
		Category = "Lighting",
		Mount = "ceiling",
		Parts = {
			B(0, -0.2, 0, 6, 0.4, 1.2, true),
			glowing(B(0, -0.45, 0, 5.6, 0.12, 0.7), 0.9, 0.95, 1),
			lamp(0, -0.6, 0),
			lights(0, -0.6, 0, 0.3, 12),
		},
	},
	{
		Id = "WallSconce",
		Label = "Wall sconce",
		Category = "Lighting",
		Mount = "wall",
		Parts = {
			B(0, 5.5, -0.1, 1, 1.6, 0.2),
			B(0, 5.3, -0.6, 0.3, 0.3, 0.8, true),
			glowing(S(0, 5.5, -1, 0.6), 1, 0.85, 0.55),
			lamp(0, 5.5, -1),
			lights(0, 5.5, -1, 0.2, 8),
		},
	},
	{
		Id = "WallTorch",
		Label = "Wall torch",
		Category = "Lighting",
		Mount = "wall",
		Parts = {
			iron(B(0, 5, -0.15, 0.8, 1.6, 0.3)),
			iron(C(0, 5.2, -0.7, 0.5, 1.4)),
			B(0, 6.2, -0.7, 0.3, 1.2, 0.3),
			glowing(S(0, 6.9, -0.7, 0.9), 1, 0.55, 0.15),
			lamp(0, 6.9, -0.7),
			lights(0, 6.9, -0.7, 0.3, 10),
		},
	},
	{
		Id = "CandleStand",
		Label = "Candle stand",
		Category = "Lighting",
		Mount = "floor",
		Parts = join(
			{
				iron(C(0, 0.15, 0, 1.8, 0.3)),
				iron(C(0, 2.5, 0, 0.2, 4.6)),
				iron(B(-1, 4.55, 0, 2, 0.12, 0.12)),
				iron(B(1, 4.55, 0, 2, 0.12, 0.12)),
			},
			candle(-2, 4.61, 0),
			candle(0, 4.61, 0),
			candle(2, 4.61, 0),
			{
				lamp(0, 5.7, 0),
				lights(0, 5.7, 0, 0.2, 8),
			}
		),
	},
	{
		Id = "OrbPedestal",
		Label = "Orb pedestal",
		Category = "Lighting",
		Mount = "floor",
		Parts = {
			C(0, 0.3, 0, 2.2, 0.6),
			C(0, 2, 0, 1.2, 3),
			C(0, 3.7, 0, 2, 0.4, true),
			glowing(S(0, 4.7, 0, 1.4), 0.5, 0.7, 1),
			lamp(0, 4.7, 0),
			lights(0, 4.7, 0, 0.2, 8),
		},
	},
	{
		Id = "CagedWallLight",
		Label = "Caged wall light",
		Category = "Lighting",
		Mount = "wall",
		Parts = {
			iron(B(0, 6, -0.15, 1.2, 1.2, 0.3)),
			iron(B(0, 6, -0.7, 0.3, 0.3, 0.8)),
			glowing(S(0, 6, -1.1, 0.6), 1, 0.9, 0.65),
			iron(B(-0.45, 6, -1.1, 0.08, 1, 0.08)),
			iron(B(0.45, 6, -1.1, 0.08, 1, 0.08)),
			iron(B(0, 6.5, -1.1, 1, 0.08, 0.08)),
			iron(B(0, 5.5, -1.1, 1, 0.08, 0.08)),
			lamp(0, 6, -1.1),
			lights(0, 6, -1.1, 0.3, 11),
		},
	},
	{
		Id = "WallLantern",
		Label = "Wall lantern",
		Category = "Lighting",
		Mount = "wall",
		Parts = {
			iron(B(0, 6.2, -0.1, 0.6, 1.4, 0.2)),
			iron(B(0, 6.7, -0.6, 0.15, 0.15, 1)),
			iron(C(0, 6.2, -1.1, 0.12, 0.8)),
			iron(C(0, 5.5, -1.1, 0.9, 0.15)),
			painted(B(0, 5.05, -1.1, 0.7, 0.9, 0.7), 1, 0.85, 0.55, "Glass", 0.5),
			glowing(S(0, 5.05, -1.1, 0.4), 1, 0.8, 0.4),
			iron(C(0, 4.5, -1.1, 0.8, 0.15)),
			lamp(0, 5.05, -1.1),
			lights(0, 5.05, -1.1, 0.25, 9),
		},
	},
	{
		Id = "UplightSconce",
		Label = "Uplight sconce",
		Category = "Lighting",
		Mount = "wall",
		Parts = {
			B(0, 5.5, -0.1, 0.8, 2.2, 0.2),
			B(0, 5, -0.5, 1.6, 0.2, 0.8, true),
			glowing(B(0, 5.15, -0.5, 1.2, 0.1, 0.5), 1, 0.85, 0.55),
			B(0, 4.4, -0.5, 1, 0.8, 0.5, true),
			lamp(0, 5.4, -0.5),
			lights(0, 5.4, -0.5, 0.2, 8),
		},
	},
	{
		Id = "PictureLight",
		Label = "Picture light",
		Category = "Lighting",
		Mount = "wall",
		Parts = {
			painted(B(0, 6.4, -0.15, 3, 0.3, 0.3), 0.8, 0.65, 0.2, "Metal"),
			painted(B(0, 6.6, -0.5, 3, 0.2, 0.7), 0.8, 0.65, 0.2, "Metal"),
			glowing(B(0, 6.45, -0.6, 2.6, 0.08, 0.3), 1, 0.9, 0.65),
			lamp(0, 6.3, -0.6),
			lights(0, 6.3, -0.6, 0.2, 8),
		},
	},
} :: { Prop }

type Paint = { any } -- r, g, b, material, then transparency when it is not solid

--[[
	The natural colors of props that are not painted part by part. Each id gets a body paint for
	its plain parts and an accent paint for its accent parts, so a toilet is white porcelain and
	chrome, not a box in the theme color. Props or parts painted in their own data are left as they are. A solid palette paint is soft: it shows in the picture list and a color theme may replace it on placement.
]]
local WOOD: Paint = { 0.45, 0.3, 0.17, "Wood" }
local WOODL: Paint = { 0.68, 0.52, 0.33, "WoodPlanks" }
local WOODD: Paint = { 0.33, 0.2, 0.11, "Wood" }
local CARD: Paint = { 0.65, 0.52, 0.34, "Wood" }
local WHITE: Paint = { 0.95, 0.95, 0.93, "SmoothPlastic" }
local CHROME: Paint = { 0.78, 0.8, 0.82, "Metal" }
local STEELC: Paint = { 0.72, 0.74, 0.77, "Metal" }
local IRONC: Paint = { 0.2, 0.2, 0.22, "Metal" }
local BRASSC: Paint = { 0.72, 0.55, 0.2, "Metal" }
local CREAM: Paint = { 0.9, 0.85, 0.7, "SmoothPlastic" }
local GRAN: Paint = { 0.35, 0.35, 0.37, "Granite" }
local STONE: Paint = { 0.58, 0.58, 0.6, "Slate" }
local ROCK: Paint = { 0.5, 0.5, 0.52, "Rock" }
local LEAF: Paint = { 0.2, 0.5, 0.2, "Grass" }
local HEDGE: Paint = { 0.15, 0.4, 0.15, "Grass" }
local CLAY: Paint = { 0.7, 0.4, 0.25, "Concrete" }
local FABRIC: Paint = { 0.42, 0.4, 0.45, "Fabric" }
local CUSHION: Paint = { 0.55, 0.5, 0.45, "Fabric" }
local LINEN: Paint = { 0.85, 0.85, 0.9, "Fabric" }
local WICKER: Paint = { 0.72, 0.55, 0.32, "Fabric" }
local RED: Paint = { 0.6, 0.15, 0.15, "Fabric" }
local GLASSC: Paint = { 0.75, 0.88, 0.92, "Glass", 0.5 }
local WATER: Paint = { 0.45, 0.7, 0.9, "Glass", 0.4 }
local MIRROR: Paint = { 0.85, 0.88, 0.9, "Metal" }
local BRICK: Paint = { 0.55, 0.3, 0.25, "Brick" }
local FELT: Paint = { 0.1, 0.45, 0.25, "Fabric" }
local ENAMEL: Paint = { 0.9, 0.88, 0.82, "Wood" }
local SHEET: Paint = { 0.85, 0.85, 0.82, "Fabric" }
local LOCKER: Paint = { 0.35, 0.45, 0.55, "Metal" }
local DRAWER: Paint = { 0.52, 0.36, 0.2, "Wood" }

local Palette: { [string]: { Paint } } = {
	CeilingLight = { WHITE, CHROME },
	CeilingFan = { WOOD, BRASSC },
	FloorLamp = { BRASSC, CREAM },
	Streetlamp = { IRONC, IRONC },
	FluorescentLight = { WHITE, STEELC },
	WallTorch = { WOODD, IRONC },
	CandleStand = { IRONC, CREAM },
	OrbPedestal = { STONE, STONE },
	CagedWallLight = { IRONC, STEELC },
	PictureLight = { BRASSC, BRASSC },
	BathTub = { WHITE, CHROME },
	Sink = { WHITE, CHROME },
	Toilet = { WHITE, CHROME },
	MirrorCabinet = { WHITE, MIRROR },
	LaundryBasket = { WICKER, WICKER },
	ShowerStall = { CHROME, GLASSC },
	DoubleSink = { WHITE, CHROME },
	TowelRack = { CHROME, LINEN },
	TowelBar = { CHROME, LINEN },
	TowelStand = { CHROME, LINEN },
	ToiletRoll = { CHROME, LINEN },
	ClawfootTub = { WHITE, BRASSC },
	Bed = { WOOD, LINEN },
	Nightstand = { WOOD, DRAWER },
	Wardrobe = { WOOD, DRAWER },
	Dresser = { WOOD, DRAWER },
	BunkBed = { WOOD, { 0.3, 0.5, 0.8, "Fabric" } },
	Crib = { { 0.9, 0.85, 0.75, "Wood" }, LINEN },
	VanityTable = { WOODL, MIRROR },
	HighCabinet = { WOOD, DRAWER },
	ClosetRod = { CHROME, WOOD },
	ShoeRack = { WOOD, IRONC },
	ClosetShelves = { WOODL, WOOD },
	Hamper = { WICKER, WICKER },
	DiningTable = { WOOD, WOODD },
	DiningChair = { WOOD, RED },
	Sideboard = { WOOD, WOODD },
	ChinaCabinet = { WOODD, GLASSC },
	Counter = { ENAMEL, GRAN },
	Fridge = { STEELC, IRONC },
	Stove = { STEELC, IRONC },
	Island = { WOOD, GRAN },
	RangeHood = { STEELC, IRONC },
	Pantry = { WOOD, WOODD },
	BreakfastBar = { WOOD, GRAN },
	Dishwasher = { STEELC, IRONC },
	ChestFreezer = { WHITE, CHROME },
	ButcherBlock = { { 0.75, 0.6, 0.4, "Wood" }, WOODD },
	HookRail = { STEELC, IRONC },
	StainlessTable = { STEELC, STEELC },
	SteelRack = { STEELC, STEELC },
	FreezerDoor = { STEELC, IRONC },
	Sofa = { FABRIC, CUSHION },
	Armchair = { FABRIC, CUSHION },
	CoffeeTable = { WOOD, WOODD },
	Bookshelf = { WOOD, WOODD },
	TvStand = { WOODD, IRONC },
	Desk = { WOOD, WOODD },
	OfficeChair = { IRONC, { 0.28, 0.14, 0.08, "Leather" } },
	Rug = { RED, CREAM },
	Fireplace = { BRICK, { 0.3, 0.3, 0.32, "Slate" } },
	Piano = { { 0.1, 0.1, 0.11, "SmoothPlastic" }, { 0.92, 0.9, 0.85, "SmoothPlastic" } },
	GrandfatherClock = { WOODD, BRASSC },
	Aquarium = { WOODD, WATER },
	RecordCabinet = { WOOD, WOODD },
	Ottoman = { FABRIC, CUSHION },
	WindowSeat = { WOOD, CUSHION },
	PottedPlant = { CLAY, LEAF },
	TallPlant = { CLAY, LEAF },
	ConsoleTable = { WOOD, WOODD },
	CoatRack = { WOODD, BRASSC },
	Bench = { WOOD, WOODD },
	WallMirror = { WOODD, MIRROR },
	ShoeBench = { WOOD, FABRIC },
	UmbrellaStand = { IRONC, BRASSC },
	Crate = { WOODL, WOOD },
	CrateStack = { WOODL, WOOD },
	Barrel = { WOOD, IRONC },
	Shelving = { STEELC, WOODL },
	WaterHeater = { WHITE, STEELC },
	Workbench = { WOOD, IRONC },
	Furnace = { STEELC, IRONC },
	WasherDryer = { WHITE, CHROME },
	ToolChest = { { 0.7, 0.12, 0.1, "Metal" }, STEELC },
	Pegboard = { WOODL, IRONC },
	PaintShelf = { WOOD, { 0.7, 0.7, 0.75, "Metal" } },
	PalletLoad = { WOODL, CARD },
	Lockers = { LOCKER, STEELC },
	HeavyRack = { { 0.2, 0.3, 0.55, "Metal" }, { 0.85, 0.45, 0.1, "Metal" } },
	Trunk = { WOODD, BRASSC },
	BoxStack = { CARD, { 0.7, 0.58, 0.38, "Wood" } },
	StandingMirror = { WOODD, MIRROR },
	CoveredFurniture = { SHEET, SHEET },
	DressForm = { { 0.85, 0.78, 0.65, "Fabric" }, WOODD },
	RockingChair = { WOOD, WOODD },
	RolledRugs = { RED, { 0.2, 0.3, 0.5, "Fabric" } },
	ClothRail = { IRONC, FABRIC },
	AtticLadder = { WOOD, WOODD },
	ToyChest = { { 0.2, 0.45, 0.8, "SmoothPlastic" }, { 0.95, 0.8, 0.15, "SmoothPlastic" } },
	Slide = { { 0.85, 0.2, 0.2, "SmoothPlastic" }, { 0.2, 0.45, 0.85, "SmoothPlastic" } },
	PlayTent = { { 0.85, 0.25, 0.25, "Fabric" }, { 0.95, 0.8, 0.2, "Fabric" } },
	Dollhouse = { { 0.9, 0.85, 0.7, "SmoothPlastic" }, { 0.3, 0.45, 0.4, "SmoothPlastic" } },
	KidsTableSet = { WOOD, WOOD },
	KidsTable = { WOOD, WOOD },
	ToyShelf = { WOOD, WOODD },
	RockingHorse = { WOODL, { 0.35, 0.22, 0.12, "Wood" } },
	BigKidBed = { WOODL, { 0.9, 0.75, 0.3, "Fabric" } },
	HallDresser = { WOODD, BRASSC },
	TallboyDresser = { WOODD, BRASSC },
	Hallstand = { WOODD, BRASSC },
	TelephoneTable = { WOODD, WOODD },
	CurioCabinet = { WOODD, WOODD },
	HallChairs = { WOODD, { 0.45, 0.14, 0.14, "Fabric" } },
	KidsBed = { WOODL, { 0.9, 0.6, 0.65, "Fabric" } },
	KidsDresser = { WOODD, DRAWER },
	PlayKitchen = { { 0.6, 0.8, 0.85, "SmoothPlastic" }, WHITE },
	Chalkboard = { WOOD, { 0.12, 0.22, 0.16, "SmoothPlastic" } },
	PuppetTheater = { WOODL, RED },
	GiantTeddy = { { 0.55, 0.35, 0.2, "Fabric" }, { 0.75, 0.58, 0.38, "Fabric" } },
	FloralCurtains = { { 0.85, 0.6, 0.58, "Fabric" }, { 0.7, 0.45, 0.45, "Fabric" } },
	BeanBag = { { 0.3, 0.5, 0.85, "Fabric" }, { 0.4, 0.6, 0.9, "Fabric" } },
	PicnicTable = { WOOD, WOODL },
	GardenBench = { WOOD, IRONC },
	Fountain = { STONE, WATER },
	Mailbox = { WOOD, { 0.2, 0.3, 0.6, "Metal" } },
	FencePanel = { { 0.92, 0.9, 0.85, "Wood" }, { 0.92, 0.9, 0.85, "Wood" } },
	Grill = { IRONC, STEELC },
	Hedge = { HEDGE, HEDGE },
	Boulder = { ROCK, ROCK },
	Well = { STONE, WOOD },
	Planter = { WOOD, LEAF },
	Tree = { { 0.4, 0.28, 0.17, "Wood" }, LEAF },
	Statue = { STONE, ROCK },
	ShopCounter = { WOODD, GRAN },
	ShelvingAisle = { STEELC, WOODL },
	BarCounter = { WOODD, GRAN },
	Pew = { WOODD, WOOD },
	ReceptionDesk = { WOOD, GRAN },
	PoolTable = { WOODD, FELT },
	ArcadeCabinet = { { 0.12, 0.12, 0.15, "SmoothPlastic" }, { 0.8, 0.15, 0.55, "SmoothPlastic" } },
	Dartboard = { WOODD, WOOD },
	Foosball = { WOOD, FELT },
	LeatherSofa = { { 0.33, 0.16, 0.09, "Leather" }, { 0.42, 0.22, 0.12, "Leather" } },
	LeatherArmchair = { { 0.33, 0.16, 0.09, "Leather" }, { 0.42, 0.22, 0.12, "Leather" } },
	CueRack = { WOODD, { 0.85, 0.7, 0.45, "Wood" } },
	PingPong = { { 0.1, 0.2, 0.5, "SmoothPlastic" }, WHITE },
	LibraryShelf = { WOODD, WOOD },
	LibraryLadder = { WOOD, BRASSC },
	Lectern = { WOODD, BRASSC },
	CardCatalog = { WOOD, BRASSC },
	ReadingTable = { WOODD, { 0.12, 0.3, 0.18, "Fabric" } },
	BreakerPanel = { STEELC, IRONC },
	Generator = { { 0.85, 0.65, 0.1, "Metal" }, IRONC },
	Transformer = { { 0.45, 0.5, 0.45, "Metal" }, IRONC },
	CableTray = { STEELC, STEELC },
	ElectricalCabinet = { { 0.55, 0.58, 0.6, "Metal" }, IRONC },
	CableReel = { WOODL, { 0.9, 0.55, 0.1, "Plastic" } },
	Easel = { WOOD, { 0.9, 0.9, 0.88, "Fabric" } },
	ArtTable = { WOODL, WOOD },
	PaintCart = { WOODL, { 0.7, 0.7, 0.72, "Metal" } },
	CanvasRack = { WOOD, { 0.9, 0.9, 0.88, "Fabric" } },
	PotteryWheel = { { 0.5, 0.5, 0.52, "Metal" }, CLAY },
	Sculpture = { STONE, STONE },
}

for _, prop in PropData.Props do
	local paints = Palette[prop.Id]

	if paints then
		for _, part in prop.Parts do
			if not part.paint and not part.lamp and not part.lights and not part.glow then
				local paint = if part.accent then paints[2] else paints[1]

				part.paint = {
					Color = { paint[1], paint[2], paint[3] },
					Material = paint[4],
					Transparency = paint[5] or 0,
					Soft = paint[5] == nil,
				}
			end
		end
	end
end

--[=[
	@param id string
	@return Prop? -- the prop with that id, or nil
]=]
function PropData.Find(id: string): Prop?
	for _, prop in PropData.Props do
		if prop.Id == id then
			return prop
		end
	end

	return nil
end

--[=[
	@param category string -- a category id
	@return { Prop } -- the props of that category, in the order they are listed
]=]
function PropData.InCategory(category: string): { Prop }
	local out: { Prop } = {}

	for _, prop in PropData.Props do
		if prop.Category == category then
			table.insert(out, prop)
		end
	end

	return out
end

--[=[
	The sections of the Props tab: All, then every category.

	@prop Sections { Category }
	@within PropData
]=]
PropData.Sections = { { Id = "All", Label = "All" } :: Category }

for _, category in PropData.Categories do
	table.insert(PropData.Sections, category)
end

--[=[
	@param section string -- `All` or a category id
	@return { Prop } -- the props the Props tab shows for that section
]=]
function PropData.Shown(section: string): { Prop }
	return if section == "All" then table.clone(PropData.Props) else PropData.InCategory(section)
end

--[=[
	@param query string -- words to look for; every word must be in the prop's name, id or category
	@return { Prop } -- the props that match, in the order they are listed; all of them for an empty query
]=]
function PropData.Search(query: string): { Prop }
	local words: { string } = {}

	for word in string.gmatch(string.lower(query), "%S+") do
		table.insert(words, word)
	end

	local labels: { [string]: string } = {}

	for _, category in PropData.Categories do
		labels[category.Id] = string.lower(category.Label)
	end

	local out: { Prop } = {}

	for _, prop in PropData.Props do
		local text = string.lower(prop.Label .. " " .. prop.Id .. " " .. (labels[prop.Category] or ""))
		local all = true

		for _, word in words do
			if not string.find(text, word, 1, true) then
				all = false

				break
			end
		end

		if all then
			table.insert(out, prop)
		end
	end

	return out
end

--[=[
	Wall props that hang high, like a light or a whiteboard, are drawn at the height they hang. The
	cursor holds the middle of such a prop, so the preview sits where the cursor points; a prop that
	stands on the floor keeps its bottom at the cursor.

	@param prop Prop
	@return number -- how far above the cursor the prop is drawn, to take off its height when placing it
]=]
function PropData.WallLift(prop: Prop): number
	if prop.Mount ~= "wall" then
		return 0
	end

	local low, high = math.huge, -math.huge

	for _, part in prop.Parts do
		low = math.min(low, part.y - part.sy / 2)
		high = math.max(high, part.y + part.sy / 2)
	end

	return if low > 1.5 then (low + high) / 2 else 0
end

return PropData
