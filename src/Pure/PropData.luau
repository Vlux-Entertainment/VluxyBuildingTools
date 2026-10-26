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
	{ Id = "Lighting", Label = "Lighting" },
} :: { Category }

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
			glowing(S(0, 0.4, 0, 2.4), 0.94, 0.9, 0.8),
			lamp(0, -0.2, 0),
			lights(0, -0.2, 0, 0.6, 22),
		},
	},
	{
		Id = "DeskLamp",
		Label = "Desk lamp",
		Category = "Lighting",
		Mount = "floor",
		Parts = {
			C(0, 0.1, 0, 1.2, 0.2),
			C(0, 1.2, 0, 0.15, 2.2),
			glowing(C(0, 2.5, 0, 1.2, 0.8), 1, 0.85, 0.55),
			lamp(0, 2.5, 0),
			lights(0, 2.5, 0, 0.4, 12),
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
			lights(0, 2.1, 0, 0.4, 14),
		},
	},
	{
		Id = "Chandelier",
		Label = "Chandelier",
		Category = "Lighting",
		Mount = "ceiling",
		Parts = {
			C(0, -0.1, 0, 0.8, 0.2),
			C(0, -0.9, 0, 0.1, 1.4),
			S(0, -1.75, 0, 0.4),
			C(0, -2.1, 0, 0.2, 0.5),
			S(0, -2.5, 0, 0.25, true),
			B(0, -2.2, 0, 3.2, 0.08, 0.08, true),
			B(0, -2.21, 0, 0.08, 0.08, 3.2, true),
			C(1.6, -2.12, 0, 0.3, 0.08, true),
			C(1.6, -1.92, 0, 0.14, 0.32),
			glowing(S(1.6, -1.7, 0, 0.18), 1, 0.85, 0.55),
			C(-1.6, -2.12, 0, 0.3, 0.08, true),
			C(-1.6, -1.92, 0, 0.14, 0.32),
			glowing(S(-1.6, -1.7, 0, 0.18), 1, 0.85, 0.55),
			C(0, -2.12, 1.6, 0.3, 0.08, true),
			C(0, -1.92, 1.6, 0.14, 0.32),
			glowing(S(0, -1.7, 1.6, 0.18), 1, 0.85, 0.55),
			C(0, -2.12, -1.6, 0.3, 0.08, true),
			C(0, -1.92, -1.6, 0.14, 0.32),
			glowing(S(0, -1.7, -1.6, 0.18), 1, 0.85, 0.55),
			lamp(0, -1.9, 0),
			lights(0, -1.9, 0, 0.8, 26),
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
			lights(0, 6.4, 0, 0.5, 18),
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
		Id = "TallLamp",
		Label = "Tall lamp",
		Category = "Lighting",
		Mount = "floor",
		Parts = {
			C(0, 0.2, 0, 2, 0.4),
			C(0, 4.5, 0, 0.3, 8.6),
			C(0, 8.4, 0, 2.2, 1.6, true),
			glowing(S(0, 9.4, 0, 1.2), 1, 0.85, 0.55),
			lamp(0, 9.4, 0),
			lights(0, 9.4, 0, 0.5, 18),
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
			lights(0, 13.2, 0, 1, 40),
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

return PropData
