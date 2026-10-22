--!strict

local Harness = require("../Support/Harness")
local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3
local vec = Harness.Vec

return {
	["the patched lookAt faces the target the way Roblox does"] = function(expect)
		local CFrame = Harness.CFrame

		expect.equal(vec(CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -5)).LookVector), "0,0,-1", "toward -Z")
		expect.equal(vec(CFrame.lookAt(Vector3.zero, Vector3.new(3, 0, 3)).LookVector), "0.707,0,0.707", "oblique")
		expect.equal(vec(CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, 1)).RightVector), "-1,0,0", "right of +Z")
		expect.equal(vec(CFrame.new(Vector3.zero, Vector3.new(0, 0, 2)).LookVector), "0,0,1", "two-point new")
		expect.equal(vec(CFrame.new(1, 2, 3).Position), "1,2,3", "plain new still works")
	end,

	["modules that require a Wally package load, and contexts share nothing"] = function(expect)
		local first = Harness.new()
		local second = Harness.new()

		expect.truthy(first:Require("src/Core/Hidden"), "Hidden, which requires Trove")
		expect.equal(first:Require("src/Core/Geometry"), first:Require("src/Core/Geometry"), "cached in one context")
		expect.truthy(first:Require("src/Core/Geometry") ~= second:Require("src/Core/Geometry"), "fresh in another")
	end,

	["a missing module names the path it tried"] = function(expect)
		local thrown = expect.errors(function()
			Harness.Load("src/Core/Nothing")
		end)

		expect.truthy(string.find(thrown, "src/Core/Nothing", 1, true), thrown)
	end,
}
