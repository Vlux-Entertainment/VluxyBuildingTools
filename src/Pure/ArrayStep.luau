--!strict

--[=[
	The step between copies of an array, as Blender's Array modifier works it out: a relative
	offset in multiples of the object's own size plus a constant offset in studs, each switched on
	or off. Plain numbers, so it runs under Lune.

	@class ArrayStep
]=]

local ArrayStep = {}

--[=[
	The most objects an array makes, counting the original.

	@prop MaxCount number
	@within ArrayStep
]=]
ArrayStep.MaxCount = 50

--[=[
	@param size { number } -- the object's size along world X, Y and Z
	@param relative boolean -- whether the relative offset counts
	@param factor { number } -- the relative offset, in multiples of the size on each axis
	@param constant boolean -- whether the constant offset counts
	@param distance { number } -- the constant offset, in studs on each axis
	@return { number } -- how far each copy moves from the one before it, on X, Y and Z
]=]
function ArrayStep.Offset(
	size: { number },
	relative: boolean,
	factor: { number },
	constant: boolean,
	distance: { number }
): { number }
	local out = { 0, 0, 0 }

	for axis = 1, 3 do
		if relative then
			out[axis] += size[axis] * factor[axis]
		end

		if constant then
			out[axis] += distance[axis]
		end
	end

	return out
end

--[=[
	@param count number -- the Count field, which counts the original
	@return number -- how many copies to make, from 0 to `MaxCount - 1`
]=]
function ArrayStep.Copies(count: number): number
	return math.clamp(math.floor(count), 1, ArrayStep.MaxCount) - 1
end

return ArrayStep
