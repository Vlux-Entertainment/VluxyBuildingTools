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

--[[ Name starts that count as walls: what is left of a wall around a doorway, window or archway cut into it, and the pieces of an arch. ]]
local WALL_PIECES = { "opening_", "arch_", "circle_upper", "circle_lower" }

--[[ Whole names that count as walls: the Block tool's part. ]]
local WALL_NAMES: { [string]: boolean } = { block = true }

local PartRole = {}

--[=[
	@param name string -- the part's name
	@return Role? -- what the part is: `Ceiling` for any name with "ceiling", `Floor` for "floor", `Wall`
		for "wall" or "pillar", a wall piece left by an opening, an arch piece or a Block tool part, so
		everything the Basic tools make but floors is grey; nil when it cannot tell
]=]
function PartRole.Of(name: string): Role?
	local lower = string.lower(name)

	if string.find(lower, "ceiling", 1, true) then
		return "Ceiling"
	elseif string.find(lower, "floor", 1, true) then
		return "Floor"
	elseif WALL_NAMES[lower] or string.find(lower, "wall", 1, true) or string.find(lower, "pillar", 1, true) then
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
