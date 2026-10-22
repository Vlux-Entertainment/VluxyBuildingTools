--!strict

local Harness = require("../Support/Harness")
local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local vec = Harness.Vec

return {
	["the array preview has one box per part per copy, each a step further on"] = function(expect)
		local context = Harness.new()
		local Arrange = context:Require("src/Core/Arrange")
		local Settings = context:Require("src/Pure/Settings")
		local settings = Settings.Defaults()
		local part = Harness.Part(Vector3.new(2, 1, 1), CFrame.new(0, 0, 0), context.Workspace)
		local other = Harness.Part(Vector3.new(2, 1, 1), CFrame.new(0, 4, 0), context.Workspace)

		settings.ArrayCount = 3

		local specs = Arrange.ArraySpecs(settings, { part, other })

		expect.equal(#specs, 4, "two copies of two parts")
		expect.equal(vec(specs[1].cf.Position), "2,0,0", "first copy, one width along X")
		expect.equal(vec(specs[4].cf.Position), "4,4,0", "second copy of the second part")
		expect.equal(vec(specs[1].size), "2,1,1")
	end,

	["the array preview is empty with no parts or no copies"] = function(expect)
		local context = Harness.new()
		local Arrange = context:Require("src/Core/Arrange")
		local Settings = context:Require("src/Pure/Settings")
		local settings = Settings.Defaults()
		local part = Harness.Part(Vector3.new(2, 1, 1), CFrame.new(), context.Workspace)

		expect.equal(#Arrange.ArraySpecs(settings, {}), 0, "no parts")

		settings.ArrayCount = 1

		expect.equal(#Arrange.ArraySpecs(settings, { part }), 0, "count of one makes no copies")
	end,
}
