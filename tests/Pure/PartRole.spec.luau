--!strict

local PartRole = require("../../src/Pure/PartRole")

return {
	["the builders' wall names are walls"] = function(expect)
		for _, name in
			{
				"Wall",
				"Wall_North",
				"CorridorWall",
				"VentWall",
				"HalfWall",
				"Opening_Header",
				"Arch_Header",
				"Circle_Lower",
			}
		do
			expect.equal(PartRole.Of(name), "Wall", name)
		end
	end,

	["Block tool parts and arch pieces count as walls"] = function(expect)
		for _, name in
			{
				"Block",
				"Arch_Post",
				"Arch_Curve",
				"Arch_Left",
				"Arch_Right",
				"Pillar",
				"HalfWallPillar",
				"RailingPillar",
			}
		do
			expect.equal(PartRole.Of(name), "Wall", name)
		end

		expect.falsy(PartRole.Of("BlockOfWood"))
		expect.equal(PartRole.Of("ArchedCeiling"), "Ceiling")
	end,

	["floors and ceilings are found by name"] = function(expect)
		expect.equal(PartRole.Of("Floor"), "Floor")
		expect.equal(PartRole.Of("VentFloor"), "Floor")
		expect.equal(PartRole.Of("Ceiling_Left"), "Ceiling")
		expect.equal(PartRole.Of("ArchedCeiling"), "Ceiling")
		expect.equal(PartRole.Of("VentCeiling"), "Ceiling")
	end,

	["unknown parts have no role"] = function(expect)
		expect.falsy(PartRole.Of("Part"))
		expect.falsy(PartRole.Of("Roof"))
		expect.falsy(PartRole.Of("Door_Frame"))
	end,
}
