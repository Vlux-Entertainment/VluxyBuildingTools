--!strict

local Harness = require("../Support/Harness")
local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3
local CFrame = Harness.CFrame
local vec = Harness.Vec

return {
	["stored cuts follow the structure's pivot when it moves and turns"] = function(expect)
		local Joints = Harness.Load("src/Core/Joints")
		local model = roblox.Instance.new("Model")
		local pivot = CFrame.new(10, 0, 0)
		local cut = { cf = CFrame.new(12, 3, 0), size = Vector3.new(4, 6, 8), cylinder = false, thickness = 1 }

		Joints.RememberCuts(model, { cut }, pivot)

		local moved = CFrame.new(10, 0, 20) * CFrame.Angles(0, math.pi / 2, 0)
		local cuts = Joints.StoredCuts(model, moved)

		expect.equal(#cuts, 1)
		expect.equal(vec(cuts[1].cf.Position), "10,3,18", "two studs along the turned X axis")
		expect.equal(vec(cuts[1].size), "4,6,8")
		expect.equal(cuts[1].thickness, 1)
	end,

	["cuts saved in world space by older builds are still read"] = function(expect)
		local Joints = Harness.Load("src/Core/Joints")
		local model = roblox.Instance.new("Model")

		model:SetAttribute("VluxyBT_Cuts", 1)
		model:SetAttribute("VluxyBT_Cut1_CF", CFrame.new(5, 1, 2))
		model:SetAttribute("VluxyBT_Cut1_Size", Vector3.new(2, 2, 2))

		local cuts = Joints.StoredCuts(model, CFrame.new(100, 0, 0))

		expect.equal(#cuts, 1)
		expect.equal(vec(cuts[1].cf.Position), "5,1,2", "world space, untouched by the pivot")
	end,
}
