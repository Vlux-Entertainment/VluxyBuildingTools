--!strict

local Harness = require("../Support/Harness")
local roblox = require("@lune/roblox")

local Settings = require("../../src/Pure/Settings")

local Vector3 = roblox.Vector3

--[[
	@param specs any -- Part specs
	@param axis any -- a unit direction
	@return number -- how far back along axis the rearmost face of all the specs lies
	@return number -- how far forward the foremost face lies
]]
local function extent(specs: any, axis: any): (number, number)
	local low, high = math.huge, -math.huge

	for _, spec in specs do
		local half = (
			math.abs(axis:Dot(spec.cf.RightVector)) * spec.size.X
			+ math.abs(axis:Dot(spec.cf.UpVector)) * spec.size.Y
			+ math.abs(axis:Dot(spec.cf.LookVector)) * spec.size.Z
		) / 2
		local centre = axis:Dot(spec.cf.Position)

		low, high = math.min(low, centre - half), math.max(high, centre + half)
	end

	return low, high
end

return {
	["a fan sits fully outside the vent end and a cap fits flush against its front"] = function(expect)
		local context = Harness.new()
		local Vents = context:Require("src/Core/Builders/Vents")
		local settings = Settings.Defaults()
		local out = Vector3.xAxis
		local origin = Vector3.new(10, 5, 2)
		local fanBack, fanFront = extent(Vents.VentFan(settings, origin + out * (Vents.FAN_DEPTH / 2), out), out)
		local capBack = extent(Vents.VentPlug(settings, origin + out * Vents.FAN_DEPTH, out), out)

		expect.equal(math.abs(fanBack - out:Dot(origin)) < 1e-3, true, "flush")
		expect.equal(math.abs(capBack - fanFront) < 1e-3, true, "flush")
	end,
	["a cap on a bare vent end has its back face on the end"] = function(expect)
		local context = Harness.new()
		local Vents = context:Require("src/Core/Builders/Vents")
		local out = Vector3.xAxis
		local origin = Vector3.new(10, 5, 2)
		local back = extent(Vents.VentCap(Settings.Defaults(), origin + out * 0.075, out), out)

		expect.equal(math.abs(back - out:Dot(origin)) < 1e-3, true, "flush")
	end,
}
