--!strict

--[=[
	Tells from a part's name what it is in a building, using the names the builders give their
	parts. A part the plugin did not make, or one with another name, has no role.

	@class PartRole
]=]

--[=[
	@type Role "Wall" | "Floor" | "Ceiling"
	@within PartRole
]=]
export type Role = "Wall" | "Floor" | "Ceiling"

--[[ What is left of a wall around a doorway, window or archway cut into it. ]]
local WALL_PIECES = { "opening_", "arch_header", "circle_upper", "circle_lower" }

local PartRole = {}

--[=[
	@param name string -- the part's name
	@return Role? -- what the part is: `Ceiling` for any name with "ceiling", `Floor` for "floor", `Wall`
		for "wall" (but not a wall's pillar) or a wall piece left by an opening; nil when it cannot tell
]=]
function PartRole.Of(name: string): Role?
	local lower = string.lower(name)

	if string.find(lower, "ceiling", 1, true) then
		return "Ceiling"
	elseif string.find(lower, "floor", 1, true) then
		return "Floor"
	elseif string.find(lower, "wall", 1, true) and not string.find(lower, "pillar", 1, true) then
		return "Wall"
	end

	for _, prefix in WALL_PIECES do
		if string.sub(lower, 1, #prefix) == prefix then
			return "Wall"
		end
	end

	return nil
end

return PartRole
