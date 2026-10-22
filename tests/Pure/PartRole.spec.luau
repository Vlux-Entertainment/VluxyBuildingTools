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

	["every Additive tool piece counts as a wall"] = function(expect)
		for _, name in
			{ "Door_Frame", "Door_Panel", "Triangle_Frame", "Circle_Frame", "Circle_Upper", "Arch", "FaceExtension" }
		do
			expect.equal(PartRole.Of(name), "Wall", name)
		end
	end,

	["stairs and ramps are stairs"] = function(expect)
		for _, name in { "Stairs", "Ramp", "Landing", "Step_1", "Step_12" } do
			expect.equal(PartRole.Of(name), "Stairs", name)
		end
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
		expect.falsy(PartRole.Of("Prop_Seat"))
	end,
}
