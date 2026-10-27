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
	paint: { Color: { number }, Material: string, Transparency: number }?,
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
	{ Id = "Dungeon", Label = "Dungeon and secret room" },
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
		Label = "Pool table",
		Category = "Game",
		Mount = "floor",
		Parts = join(legs(1.7, 3.2, 2.6, 0.6), {
			B(0, 2.9, 0, 4.4, 0.6, 8.4),
			B(0, 3.25, 0, 3.6, 0.1, 7.6, true),
			B(0, 3.45, -4.1, 4.4, 0.5, 0.4),
			B(0, 3.45, 4.1, 4.4, 0.5, 0.4),
			B(-2, 3.45, 0, 0.4, 0.5, 7.8),
			B(2, 3.45, 0, 0.4, 0.5, 7.8),
			painted(S(0.3, 3.45, 1, 0.3), 0.95, 0.95, 0.95, "SmoothPlastic"),
			painted(S(-0.4, 3.45, -1.6, 0.3), 0.8, 0.1, 0.1, "SmoothPlastic"),
			painted(S(0.5, 3.45, -2, 0.3), 0.1, 0.1, 0.1, "SmoothPlastic"),
		}),
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
			B(0, 5.5, -0.2, 2.6, 2.6, 0.4),
			B(0, 5.5, -0.45, 2, 2, 0.1, true),
			painted(S(0, 5.5, -0.55, 0.4), 0.85, 0.1, 0.1, "SmoothPlastic"),
			iron(B(0.5, 5.8, -0.75, 0.06, 0.06, 0.5)),
			iron(B(-0.6, 5.2, -0.75, 0.06, 0.06, 0.5)),
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
