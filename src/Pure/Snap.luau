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

return Snap
