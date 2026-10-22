--!strict

--[=[
	Tells from a part's name what it is in a building, using the names the builders give their
	parts. A part the plugin did not make, or one with another name, has no role.

	@class PartRole
]=]

--[=[
	@type Role "Wall" | "Floor" | "Ceiling" | "Stairs"
	@within PartRole

	`Wall` covers everything the Basic and Additive tools make except floors: walls, pillars,
	blocks, arches, and the frames, doors and wall pieces of openings.
]=]
export type Role = "Wall" | "Floor" | "Ceiling" | "Stairs"

--[[ Name starts of wall pieces: what is left of a wall around an opening, arches, opening frames and doors, and face extensions. ]]
local WALL_PIECES = { "opening_", "arch", "circle_", "triangle_", "door_", "faceextension" }

--[[ Whole names of wall pieces: the Block tool's part. ]]
local WALL_NAMES: { [string]: boolean } = { block = true }

--[[ Whole names of stair pieces: stairs and ramps after their union, and the top landing. ]]
local STAIR_NAMES: { [string]: boolean } = { stairs = true, ramp = true, landing = true }

local PartRole = {}

--[[
	@param lower string -- a lowercase name
	@param prefixes { string }
	@return boolean -- whether the name starts with any of the prefixes
]]
local function startsWith(lower: string, prefixes: { string }): boolean
	for _, prefix in prefixes do
		if string.sub(lower, 1, #prefix) == prefix then
			return true
		end
	end

	return false
end

--[=[
	@param name string -- the part's name
	@return Role? -- what the part is, or nil when it cannot tell. Checked in this order: "ceiling" in
		the name is a ceiling, "floor" a floor, a stair or ramp piece is stairs, and "wall", "pillar", a
		Block tool part or an arch or opening piece is a wall.
]=]
function PartRole.Of(name: string): Role?
	local lower = string.lower(name)

	if string.find(lower, "ceiling", 1, true) then
		return "Ceiling"
	elseif string.find(lower, "floor", 1, true) then
		return "Floor"
	elseif STAIR_NAMES[lower] or startsWith(lower, { "step_" }) then
		return "Stairs"
	elseif
		WALL_NAMES[lower]
		or string.find(lower, "wall", 1, true)
		or string.find(lower, "pillar", 1, true)
		or startsWith(lower, WALL_PIECES)
	then
		return "Wall"
	end

	return nil
end

return PartRole
