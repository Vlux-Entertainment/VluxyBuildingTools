--!strict

--[=[
	Rounds numbers onto the snap grid, and lines offsets up with a direction.

	@class Snap
]=]

local MIN_GRID = 0.05

local Snap = {}

--[=[
	@param value number
	@param grid number -- the snap increment; never snaps finer than 0.05
	@return number
]=]
function Snap.Round(value: number, grid: number): number
	local step = math.max(MIN_GRID, grid)

	return math.round(value / step) * step
end

--[=[
	Lines a flat offset up with a direction: when it is within `tolerance` of running along the
	direction, or of crossing it at a right angle, it is pulled onto that line, keeping its reach
	along the line. Otherwise it is left as it is.

	@param dx number -- the offset to line up
	@param dz number
	@param ux number -- the direction to line up with; any length
	@param uz number
	@param tolerance number -- in radians
	@return number -- the lined-up offset
	@return number
	@return boolean -- whether it was moved onto a line
]=]
function Snap.Align(dx: number, dz: number, ux: number, uz: number, tolerance: number): (number, number, boolean)
	local length = math.sqrt(ux * ux + uz * uz)

	if length < 1e-6 or dx * dx + dz * dz < 1e-6 then
		return dx, dz, false
	end

	ux, uz = ux / length, uz / length

	local along = dx * ux + dz * uz
	local across = dz * ux - dx * uz
	local angle = math.atan2(math.abs(across), math.abs(along))

	if angle <= tolerance then
		return along * ux, along * uz, true
	elseif angle >= math.pi / 2 - tolerance then
		return -across * uz, across * ux, true
	end

	return dx, dz, false
end

--[=[
	Where a post goes on a level top, in the top's own frame (X and Z from its middle). The lines a
	post edge can follow are `inset` in from each edge; a cursor within `reach` of one snaps onto
	it, so near a corner it snaps onto the corner. Elsewhere the grid spot is kept, held inside the
	lines. A top too narrow for the inset puts the post on its middle.

	@param halfX number -- half the top's size across X
	@param halfZ number
	@param cursorX number -- where the cursor is on the top
	@param cursorZ number
	@param gridX number -- the grid-snapped spot
	@param gridZ number
	@param inset number -- how far a post's middle stays in from an edge
	@param reach number -- how close to a line snaps onto it
	@return number -- the post's X
	@return number -- its Z
	@return boolean -- whether it snapped onto an edge, a corner or the middle of a narrow top
]=]
function Snap.TopSpot(
	halfX: number,
	halfZ: number,
	cursorX: number,
	cursorZ: number,
	gridX: number,
	gridZ: number,
	inset: number,
	reach: number
): (number, number, boolean)
	local snapped = false

	--[[ One axis: onto the line near the cursor, else the grid spot kept inside the lines. ]]
	local function axis(half: number, cursor: number, grid: number): number
		local line = half - inset

		if line <= 0 then
			snapped = true

			return 0
		elseif math.abs(math.abs(cursor) - line) <= reach then
			snapped = true

			return if cursor >= 0 then line else -line
		end

		return math.clamp(grid, -line, line)
	end

	local x = axis(halfX, cursorX, gridX)
	local z = axis(halfZ, cursorZ, gridZ)

	return x, z, snapped
end

return Snap
