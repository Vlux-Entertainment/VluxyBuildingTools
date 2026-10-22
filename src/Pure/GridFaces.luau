--!strict

--[=[
	Picks which faces of a part get the surface grid, so a big folder does not carry six Textures on
	every part. Floors and stairs get the face that looks up, ceilings the one that looks down, thin
	parts such as walls their two wide sides, long parts such as posts their four long sides, and
	anything else every face.

	Face names are those of `Enum.NormalId`: Right and Left are the part's own +X and -X, Top and
	Bottom +Y and -Y, Back and Front +Z and -Z.

	@class GridFaces
]=]

local PartRole = require("./PartRole")
local ShapeClass = require("./ShapeClass")

local GridFaces = {}

--[[ The faces at the two ends of each of the part's own axes, plus end first. ]]
local AXIS_FACES = {
	{ "Right", "Left" },
	{ "Top", "Bottom" },
	{ "Back", "Front" },
}

--[=[
	Every face, for parts the rules leave whole.

	@prop All { string }
	@within GridFaces
]=]
GridFaces.All = { "Top", "Bottom", "Left", "Right", "Front", "Back" }

--[[
	@param ups { number } -- how much each of the part's own +X, +Y and +Z axes points up in the world
	@param down boolean -- true for the face that looks down instead
	@return string -- the face that looks most up, or most down
]]
local function facing(ups: { number }, down: boolean): string
	local best, axis = -1, 2

	for index, up in ups do
		if math.abs(up) > best then
			best, axis = math.abs(up), index
		end
	end

	local positive = ups[axis] >= 0

	if down then
		positive = not positive
	end

	return AXIS_FACES[axis][if positive then 1 else 2]
end

--[=[
	@param name string -- the part's name, for its role in the building (see `PartRole`)
	@param size { number } -- the part's size along its own X, Y and Z
	@param ups { number } -- how much the part's own +X, +Y and +Z axes point up in the world (the Y of its RightVector, UpVector and -LookVector)
	@return { string } -- the faces to grid
]=]
function GridFaces.For(name: string, size: { number }, ups: { number }): { string }
	local role = PartRole.Of(name)

	if role == "Floor" or role == "Stairs" then
		return { facing(ups, false) }
	elseif role == "Ceiling" then
		return { facing(ups, true) }
	end

	local kind = ShapeClass.Of(size[1], size[2], size[3])
	local thin, long = 1, 1

	for axis = 2, 3 do
		if size[axis] < size[thin] then
			thin = axis
		end

		if size[axis] > size[long] then
			long = axis
		end
	end

	if kind == "Plane" then
		return { AXIS_FACES[thin][1], AXIS_FACES[thin][2] }
	elseif kind == "Pipe" then
		local out = {}

		for axis = 1, 3 do
			if axis ~= long then
				table.insert(out, AXIS_FACES[axis][1])
				table.insert(out, AXIS_FACES[axis][2])
			end
		end

		return out
	end

	return GridFaces.All
end

return GridFaces
