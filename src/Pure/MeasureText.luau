--!strict

--[=[
	The readouts of the Measure tool's shapes: their dimensions and their length, area or volume,
	one fact per line, in studs.

	@class MeasureText
]=]

local MeasureText = {}

MeasureText.SHAPES = { "Line", "Square", "Box", "Circle", "Ball" }

--[[
	@param value number
	@return string -- the value with two decimals
]]
local function n(value: number): string
	return string.format("%.2f", value)
end

--[=[
	@param dx number
	@param dy number
	@param dz number
	@return string
]=]
function MeasureText.Line(dx: number, dy: number, dz: number): string
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)

	return `Length {n(length)}\nX {n(math.abs(dx))}  Y {n(math.abs(dy))}  Z {n(math.abs(dz))}`
end

--[=[
	@param width number
	@param depth number
	@return string
]=]
function MeasureText.Square(width: number, depth: number): string
	return `{n(width)} × {n(depth)}\nArea {n(width * depth)}`
end

--[=[
	@param width number
	@param depth number
	@param height number
	@return string
]=]
function MeasureText.Box(width: number, depth: number, height: number): string
	local surface = 2 * (width * depth + width * height + depth * height)

	return `{n(width)} × {n(depth)} × {n(height)}\nVolume {n(width * depth * height)}\nSurface {n(surface)}`
end

--[=[
	@param radius number
	@return string
]=]
function MeasureText.Circle(radius: number): string
	return `Radius {n(radius)}  Diameter {n(2 * radius)}\nCircumference {n(2 * math.pi * radius)}\nArea {n(
		math.pi * radius * radius
	)}`
end

--[=[
	@param radius number
	@return string
]=]
function MeasureText.Ball(radius: number): string
	return `Radius {n(radius)}  Diameter {n(2 * radius)}\nSurface {n(4 * math.pi * radius * radius)}\nVolume {n(
		4 / 3 * math.pi * radius ^ 3
	)}`
end

return MeasureText
