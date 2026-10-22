--!strict

local GridFaces = require("../../src/Pure/GridFaces")

local UPRIGHT = { 0, 1, 0 }

--[[ Sorts a face list so tests do not depend on order. ]]
local function sorted(faces: { string }): string
	local copy = table.clone(faces)

	table.sort(copy)

	return table.concat(copy, ",")
end

return {
	["a floor gets only the face that looks up"] = function(expect)
		expect.equal(sorted(GridFaces.For("Floor", { 24, 1, 24 }, UPRIGHT)), "Top")
		expect.equal(sorted(GridFaces.For("Floor", { 24, 1, 24 }, { 0, -1, 0 })), "Bottom")
		expect.equal(sorted(GridFaces.For("Floor", { 1, 24, 24 }, { 1, 0, 0 })), "Right")
	end,

	["a ceiling gets only the face that looks down"] = function(expect)
		expect.equal(sorted(GridFaces.For("Ceiling", { 24, 1, 24 }, UPRIGHT)), "Bottom")
	end,

	["stairs get the face that looks up"] = function(expect)
		expect.equal(sorted(GridFaces.For("Step_3", { 4, 1, 1 }, UPRIGHT)), "Top")
	end,

	["a wall gets its two wide sides, whichever way it is thin"] = function(expect)
		expect.equal(sorted(GridFaces.For("Wall_North", { 24, 12, 1 }, UPRIGHT)), "Back,Front")
		expect.equal(sorted(GridFaces.For("CorridorWall", { 1, 12, 24 }, UPRIGHT)), "Left,Right")
	end,

	["a post gets its four long sides"] = function(expect)
		expect.equal(sorted(GridFaces.For("Pillar", { 1, 12, 1 }, UPRIGHT)), "Back,Front,Left,Right")
	end,

	["a chunky block gets every face"] = function(expect)
		expect.equal(#GridFaces.For("Block", { 4, 4, 4 }, UPRIGHT), 6)
		expect.equal(#GridFaces.For("Part", { 4, 3, 5 }, UPRIGHT), 6)
	end,
}
