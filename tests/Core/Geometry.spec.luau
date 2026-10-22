--!strict

local Harness = require("../Support/Harness")
local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local vec = Harness.Vec

return {
	["Add skips flat pieces and refuses pieces past Studio's size limit"] = function(expect)
		local Geometry = Harness.Load("src/Core/Geometry")
		local out = {}

		Geometry.Add(out, Vector3.new(4, 0, 4), CFrame.new(), "Flat")
		Geometry.Add(out, Vector3.new(4, 1, 4), CFrame.new(), nil, nil, "WedgePart")

		expect.equal(#out, 1)
		expect.equal(out[1].name, "Block", "the default name")
		expect.equal(out[1].class, "WedgePart")
		expect.errors(function()
			Geometry.Add(out, Vector3.new(4000, 1, 1), CFrame.new())
		end, "a part longer than 2048 studs")
	end,

	["Bounds covers every part, rotated ones by their corners"] = function(expect)
		local Geometry = Harness.Load("src/Core/Geometry")
		local a = Harness.Part(Vector3.new(2, 2, 2), CFrame.new(0, 0, 0))
		local b = Harness.Part(Vector3.new(2, 2, 2), CFrame.new(10, 0, 0))
		local center, size = Geometry.Bounds({ a, b })

		expect.equal(vec(center.Position), "5,0,0")
		expect.equal(vec(size), "12,2,2")

		local turned = Harness.Part(Vector3.new(4, 1, 2), CFrame.Angles(0, math.pi / 2, 0))
		local _, turnedSize = Geometry.Bounds({ turned })

		expect.equal(vec(turnedSize), "2,1,4")
	end,

	["IsPlainBlock is true only for a block-shaped Part"] = function(expect)
		local Geometry = Harness.Load("src/Core/Geometry")
		local ball = roblox.Instance.new("Part")

		ball.Shape = roblox.Enum.PartType.Ball

		expect.truthy(Geometry.IsPlainBlock(roblox.Instance.new("Part")), "block")
		expect.falsy(Geometry.IsPlainBlock(ball), "ball")
		expect.falsy(Geometry.IsPlainBlock(roblox.Instance.new("WedgePart")), "wedge")
		expect.falsy(Geometry.IsPlainBlock(nil), "nothing")
	end,

	["Materialize builds anchored parts in the working folder, copying a source part's look"] = function(expect)
		local context = Harness.new()
		local Geometry = context:Require("src/Core/Geometry")
		local folder = roblox.Instance.new("Folder")
		local source = Harness.Part(Vector3.one, CFrame.new())

		folder.Parent = context.Workspace
		source.Material = roblox.Enum.Material.Brick
		Geometry.SetScope(folder)

		local out = {}

		Geometry.Add(out, Vector3.new(4, 1, 4), CFrame.new(0, 3, 0), "Floor", source)

		local model = Geometry.Materialize(out, "Room")
		local floor = model:FindFirstChild("Floor")

		expect.equal(model.Parent, folder, "built in the working folder")
		expect.equal(floor.Anchored, true)
		expect.equal(floor.Material, roblox.Enum.Material.Brick, "the source's material")
		expect.equal(vec(floor.Size), "4,1,4")
	end,

	["Place unwraps a build of one piece"] = function(expect)
		local context = Harness.new()
		local Geometry = context:Require("src/Core/Geometry")
		local out = {}

		Geometry.Add(out, Vector3.new(2, 2, 2), CFrame.new(), "Block")

		local placed = Geometry.Place(out, "Crate")

		expect.equal(placed.ClassName, "Part")
		expect.equal(placed.Name, "Crate")
		expect.equal(placed.Parent, context.Workspace)
	end,
}
