--!strict

--[[
	Fills Workspace.StressTest with plugin-built rooms, corridors, walls with doorways, floors and
	stairs until it holds TARGET parts, for measuring the plugin on a big working folder. Paste the
	whole file into Studio's command bar while the plugin source is served into ServerStorage. It is
	not part of the plugin, and the build is not an undo step: delete the folder when done. Running
	it again replaces the folder. Set TARGET for other sizes, such as 10000 or 50000.
]]

local TARGET = 100000
local SPACING = 80
local YIELD_EVERY = 20

local root = game:GetService("ServerStorage"):WaitForChild("VluxyBuildingTools") :: any
local Areas = require(root.Core.Builders.Areas) :: any
local Geometry = require(root.Core.Geometry) :: any
local Openings = require(root.Core.Builders.Openings) :: any
local Paths = require(root.Core.Builders.Paths) :: any
local Settings = require(root.Pure.Settings) :: any
local Slopes = require(root.Core.Builders.Slopes) :: any

local settings = Settings.Defaults()
local old = workspace:FindFirstChild("StressTest")

if old then
	old:Destroy()
end

local folder = Instance.new("Folder")
folder.Name = "StressTest"
folder.Parent = workspace
Geometry.SetScope(folder)

local parts = 0
local failures = 0
local started = os.clock()

--[[ Builds one piece, counting its parts; a builder that errors is counted and skipped. ]]
local function build(make: () -> { any }, title: string): Instance?
	local ok, result = pcall(function()
		local specs = make()

		if #specs == 0 then
			return nil
		end

		parts += #specs

		return Geometry.Materialize(specs, title)
	end)

	if not ok then
		failures += 1

		return nil
	end

	return result
end

--[[ Cuts a doorway into the middle of a wall the way the Door tool does, from the +X side. ]]
local function doorway(wall: Instance, at: Vector3)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { wall }

	local hit = workspace:Raycast(at - Vector3.new(6, 0, 0), Vector3.new(12, 0, 0), params)

	if not hit then
		failures += 1

		return
	end

	local ok = pcall(function()
		local specs, _, target = Openings.Opening(settings, { Width = 4, Height = 8, Sill = 0 }, hit, "Rect")

		if #specs > 0 and target then
			Geometry.Materialize(specs, "Wall_Door")
			parts += #specs - 1
			target.Parent = nil
		end
	end)

	if not ok then
		failures += 1
	end
end

local cell = 0

while parts < TARGET do
	local side = 100
	local x = (cell % side) * SPACING
	local z = math.floor(cell / side) * SPACING

	build(function()
		return Areas.Room(settings, Vector3.new(x, 0, z), Vector3.new(x + 24, 0, z + 24))
	end, "Vlux_Room")
	build(function()
		return Areas.Floor(settings, Vector3.new(x + 30, 0, z), Vector3.new(x + 50, 0, z + 24))
	end, "Vlux_Floor")
	build(function()
		return Paths.Path(settings, Vector3.new(x, 0, z + 34), Vector3.new(x + 48, 0, z + 34), true)
	end, "Vlux_Corridor")
	build(function()
		return Slopes.Stairs(settings, Vector3.new(x + 30, 0, z + 50), Vector3.new(x + 46, 8, z + 58), false)
	end, "Vlux_Stairs")

	local wall = build(function()
		return Paths.Path(settings, Vector3.new(x + 60, 0, z), Vector3.new(x + 60, 0, z + 24), false)
	end, "Vlux_Wall")

	if wall then
		doorway(wall, Vector3.new(x + 60, 4, z + 12))
	end

	cell += 1

	if parts == 0 then
		error("[StressPlace] every builder failed; is the plugin source served into ServerStorage?")
	end

	if cell % YIELD_EVERY == 0 then
		print(string.format("[StressPlace] %d parts in %d cells", parts, cell))
		task.wait()
	end
end

Geometry.SetScope(nil)

local counted = 0

for _, object in folder:GetDescendants() do
	if object:IsA("BasePart") then
		counted += 1
	end
end

print(
	string.format(
		"[StressPlace] done: %d parts in %d cells, %d failed pieces, %.1f s",
		counted,
		cell,
		failures,
		os.clock() - started
	)
)
