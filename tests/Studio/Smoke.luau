--!strict

--[[
	In-Studio smoke checks for what Lune cannot run: real Parts, raycasts, spatial queries and the
	color sweep. Paste the whole file into the Studio command bar with the place open (Rojo serving
	default.project.json). It requires a fresh clone of ServerStorage.VluxyBuildingTools, builds
	into a temporary folder under Workspace, prints one line per check and removes what it made.
]]

task.spawn(function()
	local ServerStorage = game:GetService("ServerStorage")
	local clone = ServerStorage:WaitForChild("VluxyBuildingTools"):Clone()
	local folder = Instance.new("Folder")
	local passed, failed = 0, 0
	local ACTIVE = "VluxGreybox_Enabled_v1"
	local wasActive = workspace:GetAttribute(ACTIVE)

	clone.Name = "VluxyTest_Clone"
	clone.Parent = ServerStorage
	folder.Name = "VluxyTest_Smoke"
	folder.Parent = workspace

	--[[
		Requires a module from the fresh clone, such as "Core/Geometry".
	]]
	local function load(path: string): any
		local node: Instance = clone

		for name in string.gmatch(path, "[^/]+") do
			node = node:WaitForChild(name)
		end

		return (require :: any)(node)
	end

	--[[
		Runs one named check and prints PASS or FAIL with the error.
	]]
	local function check(name: string, body: () -> ())
		local ok, problem = pcall(body)

		if ok then
			passed += 1
			print(`[VluxyTest] PASS {name}`)
		else
			failed += 1
			warn(`[VluxyTest] FAIL {name}: {problem}`)
		end
	end

	local Settings = load("Pure/Settings")
	local Geometry = load("Core/Geometry")
	local Areas = load("Core/Builders/Areas")
	local Openings = load("Core/Builders/Openings")
	local Snapper = load("Core/Snapper")
	local Colors = load("Core/Colors")
	local Trove = load("Packages/Trove")
	local settings = Settings.Defaults()
	local origin = Vector3.new(0, 500, 0)

	Geometry.SetScope(folder)

	check("a room materializes with a floor, four walls and a ceiling", function()
		settings.Roof = true

		local room = Geometry.Materialize(Areas.Room(settings, origin, origin + Vector3.new(20, 0, 16)), "Room")

		assert(#room:GetChildren() == 6, `{#room:GetChildren()} parts`)

		for _, name in { "Floor", "Wall_North", "Wall_South", "Wall_East", "Wall_West", "Ceiling" } do
			assert(room:FindFirstChild(name), `no {name}`)
		end
	end)

	check("Snapper.Find pulls a point near the room's corner onto it", function()
		local point, moved = Snapper.Find(origin + Vector3.new(0.4, 0, -0.3), 1)

		assert(moved, "did not snap")
		assert((point - origin).Magnitude < 0.01, `snapped to {point}`)
	end)

	check("a door cut into a raycast wall gives the frame and panel", function()
		local wall = Instance.new("Part")

		wall.Size, wall.Anchored = Vector3.new(20, 12, 1), true
		wall.CFrame = CFrame.new(origin + Vector3.new(0, 6, 40))
		wall.Parent = folder

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { wall }
		local hit = workspace:Raycast(origin + Vector3.new(0, 3, 50), Vector3.new(0, 0, -20), params)

		assert(hit and hit.Instance == wall, "the ray missed the wall")

		local dims = { Width = 4, Height = 7.75, Sill = 0, Panel = true, Frame = true, DoorTransparency = 0.5 }
		local specs, message, replaced = Openings.Opening(settings, dims, hit, "Rect")

		assert(replaced == wall, message)
		wall:Destroy()

		local door = Geometry.Materialize(specs, "Door")
		local frames, panel = 0, door:FindFirstChild("Door_Panel") :: BasePart?

		for _, child in door:GetChildren() do
			frames += if child.Name == "Door_Frame" then 1 else 0
		end

		assert(frames == 3, `{frames} frame pieces`)
		assert(panel and math.abs(panel.Transparency - 0.5) < 1e-3 and not panel.CanCollide, "panel")
		assert(math.abs(panel.Size.X - 4) < 1e-3 and math.abs(panel.Size.Y - 7.75) < 1e-3, `panel {panel.Size}`)
	end)

	check("Snapper.Doorway finds the door just built", function()
		local doorway = Snapper.Doorway(origin + Vector3.new(1, 0, 44), 4)

		assert(doorway, "no doorway")
		assert(math.abs(doorway.width - 4.5) < 1e-3, `width {doorway.width}`)
		assert(doorway.normal:Dot(Vector3.zAxis) > 0.99, `normal {doorway.normal}`)
	end)

	check("the color sweep gives a new part in the folder its theme color", function()
		local trove = Trove.new()
		local part = Instance.new("Part")

		part.Size, part.Anchored, part.Parent = Vector3.new(8, 1, 8), true, folder
		workspace:SetAttribute(ACTIVE, true)

		local none = function() end
		local colors = Colors.new({
			Edit = function(_, body)
				body()
				return true
			end,
			Say = none,
			Refresh = none,
			Stop = none,
			GetScope = function()
				return folder
			end,
			GetTheme = function()
				return "Structures"
			end,
			GetLevel = function()
				return 14, 1
			end,
		}, trove)

		Colors.Sweep(colors)
		trove:Destroy()
		assert(typeof(part:GetAttribute("VluxGreybox_OriginalColor_v1")) == "Color3", "no saved original color")
	end)

	workspace:SetAttribute(ACTIVE, wasActive)
	folder:Destroy()
	clone:Destroy()
	print(`[VluxyTest] {passed} passed, {failed} failed`)
end)
