--!strict

--[=[
	Stepping through a list with wrap-around, as tabs, tool tiles and prop sections do.

	@class Cycle
]=]

local Cycle = {}

--[=[
	@param index number -- the current position, from 1
	@param delta number -- how far to step, negative to go back
	@param count number -- the length of the list
	@return number -- the new position, wrapped into 1 to count
]=]
function Cycle.Step(index: number, delta: number, count: number): number
	return (index - 1 + delta) % count + 1
end

--[=[
	@param list { T }
	@param current T? -- the selected item, or nil when none is
	@param delta number -- 1 or -1
	@return T? -- the next item after the current one, or the first (or last, stepping back) when none is selected
]=]
function Cycle.Next<T>(list: { T }, current: T?, delta: number): T?
	if #list == 0 then
		return nil
	end

	local found = if current ~= nil then table.find(list, current) else nil
	local at: number = found or (if delta < 0 then #list + 1 else 0)

	return list[Cycle.Step(at, delta, #list)]
end

return Cycle
