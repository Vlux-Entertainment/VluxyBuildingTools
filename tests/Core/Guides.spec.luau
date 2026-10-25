--!strict

local Harness = require("../Support/Harness")
local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3
local vec = Harness.Vec

return {
	["a dragged box's nearest corner or centre is pulled onto a guide point within reach"] = function(expect)
		local Guides = Harness.Load("src/Core/Guides")
		local anchors = Guides.BoxAnchors(Vector3.new(0, 1, 0), Vector3.new(4, 2, 4))

		expect.equal(#anchors, 27)
		expect.equal(
			vec(Guides.Pull(anchors, Vector3.new(2.5, 0, 2.2), 3)),
			"0.5,0,0.2",
			"the bottom corner moves onto it"
		)
		expect.equal(vec(Guides.Pull(anchors, Vector3.new(0.4, 1, 0), 3)), "0.4,0,0", "the centre when that is nearest")
		expect.equal(Guides.Pull(anchors, Vector3.new(9, 0, 9), 3), nil, "too far away")
	end,
}
