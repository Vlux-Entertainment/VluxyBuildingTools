--!strict

--[=[
	Rounds numbers onto the snap grid.

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

return Snap
