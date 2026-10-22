--!strict

--[=[
	Sorts a part's size into the kind of shape it is, for the Unity color theme: blocks are orange,
	thin planes and pipes are grey.

	@class ShapeClass
]=]

--[=[
	@type Kind "Block" | "Plane" | "Pipe"
	@within ShapeClass

	`Plane`: one side is much thinner than the others, such as a wall or a floor.
	`Pipe`: one side is much longer than the others, such as a beam, rail or post.
	`Block`: anything else, a cube or a chunky rectangular box.
]=]
export type Kind = "Block" | "Plane" | "Pipe"

local ShapeClass = {}

--[=[
	How much smaller a side must be than the next to count as thin: a quarter.

	@prop THIN number
	@within ShapeClass
]=]
ShapeClass.THIN = 0.25

--[=[
	@param x number
	@param y number
	@param z number
	@return Kind -- the kind of shape a box of that size is; a box with a side of zero or less counts as a plane
]=]
function ShapeClass.Of(x: number, y: number, z: number): Kind
	local sides = { x, y, z }

	table.sort(sides)

	local small, middle, large = sides[1], sides[2], sides[3]

	if small ~= small or small <= 0 then
		return "Plane"
	end

	if small <= middle * ShapeClass.THIN then
		return "Plane"
	end

	if middle <= large * ShapeClass.THIN then
		return "Pipe"
	end

	return "Block"
end

--[=[
	@param size { number } -- the part's size along its own X, Y and Z
	@param ups { number } -- how much each of the part's own X, Y and Z axes points up in the world
	@return boolean -- true when the part's thinnest side faces up or down, as a floor or ceiling does, rather than sideways as a wall does
]=]
function ShapeClass.LiesFlat(size: { number }, ups: { number }): boolean
	local thin = 1

	for axis = 2, 3 do
		if size[axis] < size[thin] then
			thin = axis
		end
	end

	return math.abs(ups[thin]) > 0.7
end

return ShapeClass
