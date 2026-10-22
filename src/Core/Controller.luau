--!strict

--[=[
	The brain of the plugin: owns the active tool, turns mouse and key input into previews and
	builds, and runs the Blender-style modal actions (extrude, grab, rotate, scale) with their
	axis locks and typed numbers. Every connection goes into the Trove it is given.

	@class Controller
]=]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local UserInputService = game:GetService("UserInputService")

local Arrange = require("./Arrange")
local AxisLock = require("../Pure/AxisLock")
local Brushes = require("./Brushes")
local Builders = require("./Builders")
local Colors = require("./Colors")
local Geometry = require("./Geometry")
local Hidden = require("./Hidden")
local Joints = require("./Joints")
local Keymap = require("../Pure/Keymap")
local NumericInput = require("../Pure/NumericInput")
local Overlay = require("./Overlay")
local Panel = require("../Ui/Panel")
local Polygon = require("../Pure/Polygon")
local Settings = require("../Pure/Settings")
local Snap = require("../Pure/Snap")
local Snapper = require("./Snapper")
local SurfaceGrid = require("./SurfaceGrid")
local Tools = require("../Pure/Tools")
local Transform = require("./Transform")
local Trove = require("../Packages/Trove")

type Spec = Geometry.Spec

type BrushItem = { roots: { Instance }, source: Builders.Source }

type Face = {
	part: BasePart,
	origin: Vector3,
	normal: Vector3,
	u: Vector3,
	v: Vector3,
	thickness: number,
}

type ExtendDrag = { source: BasePart, normal: Vector3, length: number }

type Extrude = {
	part: BasePart,
	normal: Vector3,
	origin: Vector3,
	length: number,
	numeric: NumericInput.NumericInput,
}

export type Controller = {
	Stop: () -> (),
	Suspend: () -> (),
	Resume: () -> (),
	TogglePastel: () -> (),
	ToggleGrid: () -> (),
	PastelOn: () -> boolean,
	GridOn: () -> boolean,
	Destroy: () -> (),
}

local SETTINGS_KEY = "VluxBlockoutSettings_v2"
local UPDATE_INTERVAL = 0.05
local FOLDER_ATTRIBUTE = "VluxyBT_WorkingFolder"
local OLD_FOLDER_ATTRIBUTE = "VluxWorkingFolder"
local MAX_LENGTH = 2048
local MAX_STAMP_PARTS = 600
local VENT_TAG = "VluxyBT_Vent"
local PRESENCE_PREFIX = "VluxyBT_Active_"
local PRESENCE_TIMEOUT = 45
local PRESENCE_INTERVAL = 10

local INSTRUCTIONS: { [string]: string } = {
	PillaredWall = "Click start and end points. A pillar goes at the start and at the end of every section. Keep clicking to connect walls. Enter starts a new chain; Esc removes the point, Esc again exits.",
	Wall = "Click start and end points. Keep clicking to connect walls. Enter starts a new chain; Esc removes the point, Esc again exits. X / Y / Z locks the drag.",
	ArchedCorridor = "Click an arched corridor start and end. Continue clicking for connected segments. Width sets the arch span; Height is the total height at the centre, arch included.",
	Corridor = "Click a corridor start and end. Continue clicking for connected segments. Joints may overlap at bends.",
	Floor = "Click two opposite corners for a flat floor. Its transparency is in the options.",
	Room = "Click two opposite corners. Elevation is the finished floor height.",
	Foundation = "Click two opposite corners. The slab is a little bigger than the corners and stands on the surface you click.",
	Porch = "Click two opposite corners for the porch floor. Corner posts and a railing are added.",
	Railing = "Click points to draw a railing; keep clicking to connect it. Click points on stairs and it follows the slope. Enter starts a new chain.",
	HalfWall = "Click points to draw a half wall; keep clicking to connect it. Click points on stairs and it follows the slope. Enter starts a new chain.",
	Fence = "Click points to draw a fence. Keep clicking to connect it. Enter starts a new chain.",
	Roof = "Click two opposite corners over the top of the walls. Pick the roof style in the options.",
	Block = "Click two opposite footprint corners. Press Y to drag it up, or X / Z to drag it along that axis; type a number for an exact size.",
	Stairs = "Click the first step and the end of the stair run. Length is drawn; Height sets the total rise.",
	Ramp = "Click the bottom and top footprint point. Drag distance sets length; Height sets the rise.",
	Arch = "Click the two inner edges at ground level. Height is the arch clearance; Depth is the frame depth.",
	ArchOpening = "Hover over a plain wall and click to cut an archway. Adjust width/height below.",
	Vent = "Click points to draw a vent along the X or Z axis. Keep clicking to chain it; it turns only at right angles and cuts a hole where it meets a wall, floor or ceiling. Enter starts a new chain.",
	VentRamp = "Click the start and the end of the run, then move the mouse up or down to set how far the vent climbs or drops, and click.",
	VentShaft = "Click a floor, wall or ceiling, then move the mouse up or down to set the length of the vertical vent and click.",
	VentCover = "Click a vent opening or any surface to place a grate over it.",
	VentCap = "Click a vent opening or any surface to close it with a plain square plate.",
	VentFan = "Click a vent opening to block it with a fan.",
	VentPeek = "Click a wall or vent opening to place a small louvred cover for looking out.",
	Pillar = "Click to place a pillar. Width and height are in the options. Esc exits.",
	Door = "Click an undecorated rectangular wall. The doorway is centered on the cursor and starts at the bottom of the wall.",
	CircleWindow = "Click an undecorated rectangular wall. The round window is centered on the cursor; its size is the smaller of the window width and height.",
	CutShape = "Click corners on a wall to outline a shape. Click the first corner again or press Enter to cut it out; Esc cancels.",
	TriangleWindow = "Click an undecorated rectangular wall. The triangular window is centered on the cursor, point up.",
	Window = "Click an undecorated rectangular wall. The window is centered on the cursor; its height above the floor is in the options.",
	Extend = "Click a block to select it, then drag a green face handle OUTWARD. Release to add a connected block.",
	Place = "Select an object first. Click or drag over surfaces to paint copies of it. R rotates the copies 90 degrees.",
	Measure = "Click two surface points. A distance label stays in the viewport. Esc clears it.",
}

local HEIGHT_MODES: { [string]: boolean } = {
	Wall = true,
	PillaredWall = true,
	Corridor = true,
	Room = true,
}

local DRAW_MODES: { [string]: boolean } = {
	Wall = true,
	Floor = true,
	PillaredWall = true,
	Corridor = true,
	ArchedCorridor = true,
	Room = true,
	Block = true,
	Stairs = true,
	Ramp = true,
	Arch = true,
	Foundation = true,
	Porch = true,
	Fence = true,
	Roof = true,
	Railing = true,
	HalfWall = true,
	Vent = true,
	VentRamp = true,
	VentShaft = true,
}

-- Hotkeys that keep working when Blender hotkeys are switched off, as they did before.
local ALWAYS_ON: { [string]: boolean } = { Cancel = true, Confirm = true, HeightUp = true, HeightDown = true }

local Controller = {}

--[=[
	@param plugin Plugin
	@param widget DockWidgetPluginGui
	@param trove Trove -- takes every connection and overlay the controller makes
	@return Controller
]=]
function Controller.new(plugin: Plugin, widget: DockWidgetPluginGui, trove: Trove.Trove): Controller
	local settings = Settings.Load(select(
		2,
		pcall(function()
			return plugin:GetSetting(SETTINGS_KEY)
		end)
	))
	local mouse = plugin:GetMouse()
	local overlay = Overlay.new(trove)
	local surfaceGrid: SurfaceGrid.SurfaceGrid

	local mode: string? = nil
	local first: Vector3? = nil
	local chained = false
	local current: Vector3? = nil
	local heightEnd: Vector3? = nil
	local riseStage = false
	local heightMouse: Vector2? = nil
	local lock: AxisLock.Lock? = nil
	local numeric = NumericInput.new()
	local source: Builders.Source? = nil
	local sourceRoots: { Instance } = {}
	local previewSpecs: { Spec } = {}
	local previewValid = false
	local measurement: { a: Vector3, b: Vector3 }? = nil
	local openingTarget: BasePart? = nil
	local openingCuts: { Builders.Cutter }? = nil
	local cutFace: Face? = nil
	local cutPending: Face? = nil
	local cutPoints: { Vector3 } = {}
	local cutSpot: Vector3? = nil
	local brushing = false
	local brushLast: Vector3? = nil
	local brushTargets: { { cf: CFrame, item: BrushItem, scale: number } } = {}
	local brushPool: { BrushItem } = {}
	local brushItem: BrushItem? = nil
	local brushScale = 1
	local ventEnds: { Vector3 }? = nil
	local ventHitNormal: Vector3? = nil
	local peekCut: Builders.Cutter? = nil
	local ventHitHost: Vector3? = nil
	local ventHost: Vector3? = nil
	local ventNormal: Vector3? = nil
	local ventShift = Vector3.zero
	local ventMarks: { Vector3 } = {}
	local brushSpecs: { Spec } = {}
	local quiet = false
	local lockedHit: RaycastResult? = nil
	local cutDepth: number? = nil
	local snapMark: Vector3? = nil
	local prevWall: { model: Instance, dir: Vector3, strips: { Builders.Strip } }? = nil
	local hoverDoor: Snapper.Doorway? = nil
	local startDoor: Snapper.Doorway? = nil
	local snapPart: BasePart? = nil
	local extendDrag: ExtendDrag? = nil
	local extendHover = false
	local extrude: Extrude? = nil
	local session: Transform.Session? = nil
	local sessionRecording: string? = nil
	local armed: string? = nil
	local folder: Instance? = nil
	local pendingFolder: Instance? = nil
	local picking = false
	local cancelPicking: () -> ()
	local hoverFolder: Instance? = nil
	local boxClock = 0
	local hidden = Hidden.new(trove)
	local arrange: Arrange.Actions

	local panel: Panel.Panel
	local colors: Colors.Colors
	local stop: (keepActive: boolean?) -> ()

	local function showBar(message: string)
		local hints: { { string } }
		local glyph, name = "◆", ""

		if session then
			glyph, name = "✥", session.Kind
			hints = { { "X Y Z", "Axis" }, { "0-9", "Type value" }, { "Enter", "Confirm" }, { "Esc", "Cancel" } }

			if session.Kind == "Rotate" then
				table.insert(hints, 2, { "←↑↓→", "±90°" })
			end
		elseif extrude then
			glyph, name = "⧉", "Extrude"
			hints = { { "0-9", "Type length" }, { "Enter", "Confirm" }, { "Esc", "Cancel" } }
		elseif mode then
			local tool = Tools.Find(mode)

			if tool then
				glyph, name = tool.Glyph, tool.Label
			end

			hints = if DRAW_MODES[mode]
				then { { "Alt", "Straight line" }, { "X Y Z", "Axis lock" }, { "Esc", "Exit tool" } }
				else { { "Esc", "Exit tool" } }
		else
			Overlay.HideBar(overlay)

			return
		end

		Overlay.SetBar(overlay, glyph, name, message, hints)
	end

	local function say(text: string)
		panel.Say(text)
		showBar(text)
	end

	--[[
		@return boolean -- true when a working folder is set and still in the place; says so when not
	]]
	local function requireFolder(): boolean
		if folder and folder:IsDescendantOf(workspace) then
			return true
		end

		say("Pick a working folder in the panel first. The plugin only works inside it.")

		return false
	end

	local function save()
		pcall(function()
			plugin:SetSetting(SETTINGS_KEY, settings)
		end)
	end

	--[[
		@param action string -- the undo step's name
		@param callback () -> ()

		@return boolean -- true when the callback ran without error and was committed
	]]
	local function edit(action: string, callback: () -> ()): boolean
		if not RunService:IsEdit() then
			say("Stop the playtest before building.")

			return false
		end

		local id = ChangeHistoryService:TryBeginRecording("Vlux_" .. action, action)

		if not id then
			say("Cannot begin an edit right now. Finish the other tool action first.")

			return false
		end

		local added: { BasePart } = {}
		local watch = workspace.DescendantAdded:Connect(function(object)
			if object:IsA("BasePart") then
				table.insert(added, object)
			end
		end)
		local ok, err = pcall(callback :: any)

		watch:Disconnect()

		for _, part in added do
			if part:IsDescendantOf(workspace) then
				SurfaceGrid.Adopt(surfaceGrid, part)
				Colors.Adopt(colors, part)
			end
		end

		ChangeHistoryService:FinishRecording(
			id,
			if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
		)

		if not ok then
			say("Action cancelled: " .. tostring(err))
			warn("VluxyBuildingTools: " .. tostring(err))
		end

		return ok
	end

	--[[
		@return number -- the snap step in force: the fine step while Shift is held, else the normal one
	]]
	local function gridNow(): number
		local fine = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

		return if fine then settings.FineGrid else settings.Grid
	end

	--[[
		@param point Vector3 -- a grid-snapped point
		@return Vector3 -- the point moved onto a nearby corner or edge, unless Shift is held or the setting is off
	]]
	local function partSnap(point: Vector3): Vector3
		local fine = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

		if fine or not settings.SnapToParts then
			return point
		end

		local snapped, found, part = Snapper.Find(point, settings.SnapRadius)

		if found then
			snapMark = snapped
			snapPart = part
		end

		return snapped
	end

	--[[
		@param point Vector3
		@return Vector3? -- the middle of a doorway made by the Additive tools on the face of its wall, when the point is near one, so a corridor can start exactly there
	]]
	local function doorSnap(point: Vector3): Vector3?
		local fine = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

		hoverDoor = nil

		if first or fine or not settings.SnapToParts then
			return nil
		end

		local found = Snapper.Doorway(point, settings.SnapRadius)

		if not found then
			return nil
		end

		hoverDoor = found
		snapMark = found.point

		return found.point
	end

	local function snap(value: number): number
		return Snap.Round(value, gridNow())
	end

	local function resetPoint()
		first, current = nil, nil
		cutFace, cutPending, cutPoints, cutSpot = nil, nil, {}, nil
		ventEnds = nil
		ventNormal, ventShift, ventHost = nil, Vector3.zero, nil
		brushing, brushLast, brushTargets, brushSpecs = false, nil, {}, {}
		lockedHit, cutDepth = nil, nil
		prevWall = nil
		startDoor = nil
		chained = false
		previewSpecs, previewValid = {}, false
		lock = nil
		heightEnd = nil
		heightMouse = nil
		riseStage = false
		measurement = nil
		NumericInput.Clear(numeric)
		Overlay.ClearGhosts(overlay)
		Overlay.ClearMeasurement(overlay)
		Overlay.HideReadout(overlay)
	end

	--[[
		@param y number

		@return Vector3? -- where the mouse ray meets the horizontal plane at y, snapped
	]]
	local function horizontalPoint(y: number): Vector3?
		local ray = mouse.UnitRay

		if math.abs(ray.Direction.Y) < 0.00001 then
			return nil
		end

		local t = (y - ray.Origin.Y) / ray.Direction.Y

		if t <= 0 or t > 100000 then
			return nil
		end

		local point = ray.Origin + ray.Direction * t

		return partSnap(Vector3.new(snap(point.X), y, snap(point.Z)))
	end

	--[[
		@param origin Vector3 -- where the drag began
		@param active AxisLock.Lock

		@return Vector3? -- the mouse point pulled onto the lock, snapped, or the typed length along an axis
	]]
	local function lockedPoint(origin: Vector3, active: AxisLock.Lock): Vector3?
		local ray = mouse.UnitRay
		local from, direction = Geometry.ToVec(ray.Origin), Geometry.ToVec(ray.Direction)
		local start = Geometry.ToVec(origin)

		if active.Plane then
			local hit = AxisLock.RayPlane(start, active.Axis, from, direction)

			if not hit then
				return nil
			end

			local point = AxisLock.Constrain(start, hit, active)

			return Vector3.new(snap(point.X), snap(point.Y), snap(point.Z))
		end

		local unit = AxisLock.Unit(active.Axis)
		local along = AxisLock.ClosestOnLine(start, unit, from, direction)
		local typed = NumericInput.Value(numeric)

		if typed then
			along = typed
		elseif along then
			along = snap(along)
		else
			return nil
		end

		return origin + Geometry.FromVec(unit) * (along :: number)
	end

	local function hitSurface(): RaycastResult?
		local ray = mouse.UnitRay
		local params = RaycastParams.new()

		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = if mode == "Place" then sourceRoots else {}

		return workspace:Raycast(ray.Origin, ray.Direction * 100000, params)
	end

	--[[
		@return RaycastResult? -- what the cursor is over, only when it is inside the working folder
	]]
	local function scopedHit(): RaycastResult?
		local hit = hitSurface()

		return if hit and Geometry.InScope(hit.Instance) then hit else nil
	end

	--[[
		@param part BasePart
		@param normal Vector3 -- the world normal of the face that was hit
		@return Face -- the face of the part with two axes lying in it, for the Cut Shape tool
	]]
	local function faceOf(part: BasePart, normal: Vector3): Face
		local axis, side = Builders.FaceAxis(part, normal)
		local cf = part.CFrame
		local axes = { cf.RightVector, cf.UpVector, cf.LookVector }
		local sizes = { part.Size.X, part.Size.Y, part.Size.Z }
		local along = axes[axis] * side
		local others: { Vector3 } = {}

		for index, vector in axes do
			if index ~= axis then
				table.insert(others, vector)
			end
		end

		return {
			part = part,
			origin = cf.Position + along * (sizes[axis] / 2),
			normal = along,
			u = others[1],
			v = others[2],
			thickness = sizes[axis],
		}
	end

	--[[
		@return string? -- why the brush has nothing to paint with, or nil when the pool is ready

		Fills the pool from the brushes that are switched on, or from the selection when there are none.
	]]
	local function buildBrushPool(): string?
		local sets: { { Instance } } = {}

		for _, entry in Brushes.Enabled() do
			table.insert(sets, { entry })
		end

		if #sets == 0 then
			local roots = Geometry.SelectedRoots()

			if #roots > 0 then
				table.insert(sets, roots)
			end
		end

		if #sets == 0 then
			return "Add something to the brushes first: select it, then press Add selected to brushes."
		end

		local pool: { BrushItem } = {}

		for _, roots in sets do
			local parts = Geometry.PartsOf(roots)

			if #parts > MAX_STAMP_PARTS then
				return "A brush supports up to 600 Parts."
			end

			for _, root in roots do
				if not root.Archivable then
					return "Enable Archivable on each brush object before painting."
				end
			end

			if #parts > 0 then
				local pivot, size = Geometry.Bounds(parts)

				table.insert(pool, { roots = roots, source = { Parts = parts, Pivot = pivot, Size = size } })
			end
		end

		if #pool == 0 then
			return "Those objects have no Parts to paint with."
		end

		brushPool = pool

		return nil
	end

	--[[
		Chooses which brush and what size the next copy will be, so the preview shows it.
	]]
	local function rollBrush()
		local item = brushPool[math.random(1, math.max(1, #brushPool))]

		if not item then
			return
		end

		local low = math.max(0.05, math.min(settings.BrushSizeMin, settings.BrushSizeMax))
		local high = math.max(low, settings.BrushSizeMax)

		brushItem = item
		source = item.source
		sourceRoots = item.roots
		brushScale = low + math.random() * (high - low)
	end

	--[[
		@param hit RaycastResult -- the surface the brush is over

		Adds one copy to the stroke: the first right under the cursor, the rest scattered within the brush radius.
	]]
	local function brushStep(hit: RaycastResult)
		local pivot, item = source, brushItem
		local spot, normal = hit.Position, hit.Normal

		if not pivot or not item then
			return
		end

		if #brushTargets > 0 and settings.BrushRadius > 0 then
			local angle = math.random() * math.pi * 2
			local reach = math.sqrt(math.random()) * settings.BrushRadius
			local across = (if math.abs(normal.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis):Cross(normal).Unit
			local along = normal:Cross(across)
			local from = hit.Position + across * (math.cos(angle) * reach) + along * (math.sin(angle) * reach)
			local params = RaycastParams.new()

			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = sourceRoots

			local found = workspace:Raycast(from + normal * 8, -normal * 16, params)

			if not found then
				return
			end

			spot, normal = found.Position, found.Normal
		end

		brushLast = hit.Position

		local yaw = if settings.BrushRandomYaw then math.random() * 360 else settings.Yaw
		local specs, target = Builders.PlaceAt(settings, spot, normal, pivot, yaw, brushScale)

		table.insert(brushTargets, { cf = target, item = item, scale = brushScale })

		for _, spec in specs do
			table.insert(brushSpecs, spec)
		end

		rollBrush()
	end

	--[[
		Makes every copy of the stroke as one undo step and clears the stroke.
	]]
	local function finishBrush()
		local targets = brushTargets

		brushing, brushLast, brushTargets, brushSpecs = false, nil, {}, {}
		Overlay.ClearGhosts(overlay)

		if #targets == 0 then
			return
		end

		edit("Brush copies", function()
			local parent = Geometry.GetScope() or workspace

			for _, stamp in targets do
				local pivot = stamp.item.source.Pivot

				for _, root in stamp.item.roots do
					local copy = root:Clone()

					if copy then
						if stamp.scale ~= 1 then
							if copy:IsA("Model") then
								copy:ScaleTo(stamp.scale)
							elseif copy:IsA("BasePart") then
								copy.Size *= stamp.scale
							end
						end

						local relative = pivot:ToObjectSpace((root :: any):GetPivot())
						local scaled = CFrame.new(relative.Position * stamp.scale) * (relative - relative.Position)

						copy.Parent = parent;
						(copy :: any):PivotTo(stamp.cf * scaled)
					end
				end
			end
		end)
	end

	--[[
		@param face Face
		@param point Vector3 -- somewhere on the plane of the face
		@return Vector3 -- the point moved to a part corner nearby, else to the grid inside the face
	]]
	local function faceSnap(face: Face, point: Vector3): Vector3
		local target = point

		if settings.SnapToParts then
			local corner, found = Snapper.VertexNear(point, UserInputService:GetMouseLocation(), 14)

			if found then
				target = corner
			end
		end

		local offset = target - face.origin
		local a, b = offset:Dot(face.u), offset:Dot(face.v)

		if target == point then
			a, b = snap(a), snap(b)
		end

		return face.origin + face.u * a + face.v * b
	end

	--[[
		@param model Model -- the vent that was just built
		@param a Vector3 -- one end of the duct, on its middle line
		@param b Vector3 -- the other end
		@param skip Instance? -- the vent this one continues, left uncut

		Records the vent's two open ends so later vents and covers can find them, then cuts the duct and its openings out of every other part the vent passes through.
	]]
	local function finishVent(model: Model, a: Vector3, b: Vector3, skip: Instance?)
		if (b - a).Magnitude < 0.05 then
			return
		end

		local dir = (b - a).Unit

		model:SetAttribute("VluxyBT_VentStart", a)
		model:SetAttribute("VluxyBT_VentStartDir", -dir)
		model:SetAttribute("VluxyBT_VentEnd", b)
		model:SetAttribute("VluxyBT_VentEndDir", dir)
		CollectionService:AddTag(model, VENT_TAG)

		local cutters = Builders.VentCutters(settings, a, b)
		local params = OverlapParams.new()
		local scope = Geometry.GetScope()

		if scope then
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { scope }
		end

		local targets: { [BasePart]: boolean } = {}

		for _, cutter in cutters do
			for _, part in workspace:GetPartBoundsInBox(cutter.cf, cutter.size, params) do
				local vent = false

				for _, ancestor in { part.Parent, part.Parent and part.Parent.Parent } do
					if ancestor and CollectionService:HasTag(ancestor, VENT_TAG) then
						vent = true
					end
				end

				if not vent and not part:IsA("Terrain") then
					targets[part] = true
				end
			end
		end

		local failed = 0

		for part in targets do
			if not Joints.Carve(part, cutters) then
				failed += 1
			end
		end

		local joins = Builders.VentJoinCutters(settings, a, b)
		local others: { [BasePart]: boolean } = {}

		for _, cutter in joins do
			for _, part in workspace:GetPartBoundsInBox(cutter.cf, cutter.size, params) do
				local owner = part.Parent

				if
					owner
					and owner ~= model
					and owner ~= skip
					and owner:IsA("Model")
					and CollectionService:HasTag(owner, VENT_TAG)
				then
					others[part] = true
				end
			end
		end

		for part in others do
			if not Joints.Carve(part, joins) then
				failed += 1
			end
		end

		if failed > 0 then
			say(string.format("%d part(s) could not be cut for the vent.", failed))
		end
	end

	--[[
		Cuts the outlined shape out of the wall as one undo step, then clears the outline.
	]]
	local function finishCut()
		local face, points = cutFace, cutPoints

		if not face or #points < 3 then
			return say("Click at least three corners first.")
		end

		local flat: { Polygon.Point } = {}

		for _, p in points do
			local offset = p - face.origin

			table.insert(flat, { offset:Dot(face.u), offset:Dot(face.v) })
		end

		local triangles = Polygon.Triangulate(flat)

		if not triangles then
			return say("The outline crosses itself or has no area. Press Esc and try again.")
		end

		local specs = Builders.CutShape(points, triangles, face.thickness + 0.5, -face.normal * (face.thickness / 2))
		local part = face.part

		edit("Cut shape", function()
			assert(part.Parent, "Wall no longer exists")

			if not Joints.CarveShape(part, specs) then
				say("The wall could not be cut.")
			end
		end)
		resetPoint()
		say(INSTRUCTIONS.CutShape)
	end

	--[[
		@return Vector3? -- for rooms and corridors, the snapped spot on the top of whatever the cursor
			is over, raised by the floor thickness so the floor rests on top of it

		A floor drawn from this point sits on the object instead of sinking into it.
	]]
	--[[
		@param point Vector3
		@param level boolean -- true to also take the floor height of the room or corridor snapped to
		@return Vector3 -- the point snapped to nearby parts, standing at the floor of the structure it snapped to, so a new room lines up with the old one
	]]
	local function partSnapLevel(point: Vector3, level: boolean): Vector3
		snapPart = nil

		local snapped = partSnap(point)

		if level and snapPart then
			local floorTop = Joints.FloorLevel(snapPart)

			if floorTop then
				return Vector3.new(snapped.X, floorTop, snapped.Z)
			end
		end

		return snapped
	end

	--[[
		@param level number? -- the height the point must stay at, or nil to take the height of what it lands on
		@return Vector3? -- the nearest part corner under the cursor, else the grid point on the surface, so a wall starts on the geometry itself instead of on a fixed Y level
	]]
	local function vertexPoint(level: number?): Vector3?
		local hit = hitSurface()

		if not hit then
			return nil
		end

		local fine = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

		if settings.SnapToParts and not fine then
			local part = hit.Instance

			if
				hit.Normal.Y >= 0.7
				and part:IsA("BasePart")
				and (not level or math.abs(hit.Position.Y - level) < 0.05)
			then
				local top = Snapper.TopCenter(part, hit.Position, settings.Grid, 1)

				if top then
					snapMark = top

					return top
				end
			end

			local corner, found = Snapper.VertexNear(hit.Position, UserInputService:GetMouseLocation(), 14)

			if found then
				snapMark = corner

				return if level then Vector3.new(corner.X, level, corner.Z) else corner
			end
		end

		if level then
			return nil
		end

		local height = if hit.Normal.Y >= 0.7 then hit.Position.Y else snap(hit.Position.Y)

		return Vector3.new(snap(hit.Position.X), height, snap(hit.Position.Z))
	end

	--[[
		@param shaft boolean -- true for a vertical vent, whose point is on the surface itself
		@return Vector3? -- where a vent starts: on an open vent end, else against the surface under the cursor so the duct sits beside it, on top of it or under it
	]]
	local function ventPoint(shaft: boolean): Vector3?
		local hit = hitSurface()

		if not hit then
			return nil
		end

		local size = settings.VentSize
		local step = math.max(0.5, settings.FineGrid)
		local endPoint, openEnd, owner = Snapper.VentConnect(hit.Position, size * 1.1, step)

		ventHitNormal = nil
		ventHitHost = nil
		table.clear(ventMarks)

		if endPoint and owner then
			local a = owner:GetAttribute("VluxyBT_VentStart")
			local b = owner:GetAttribute("VluxyBT_VentEnd")

			if typeof(a) == "Vector3" and typeof(b) == "Vector3" and (b - a).Magnitude > 0.05 then
				local length = (b - a).Magnitude

				for along = 0, length, step do
					table.insert(ventMarks, a + (b - a).Unit * along)
				end

				table.insert(ventMarks, b)

				if not openEnd then
					ventHitHost = (b - a).Unit
				end
			end

			snapMark = endPoint

			return if shaft then endPoint else endPoint - Vector3.new(0, size / 2, 0)
		end

		local normal = hit.Normal
		local onWall = math.abs(normal.Y) < 0.5
		local y = hit.Position.Y

		if onWall then
			local part = hit.Instance :: BasePart
			local reach = (
				math.abs(part.CFrame.RightVector.Y) * part.Size.X
				+ math.abs(part.CFrame.UpVector.Y) * part.Size.Y
				+ math.abs(part.CFrame.LookVector.Y) * part.Size.Z
			) / 2
			local bottom, top = part.Position.Y - reach, part.Position.Y + reach
			local floorTop = Joints.FloorLevel(part) or bottom
			local heights = {
				floorTop + size / 2,
				bottom + size / 2,
				(bottom + top) / 2,
				top - size / 2,
			}
			local best = math.huge

			y = snap(hit.Position.Y)

			for _, height in heights do
				if height >= bottom + size / 2 - 0.01 and height <= top - size / 2 + 0.01 then
					local gap = math.abs(height - hit.Position.Y)

					if gap < size * 0.75 and gap < best then
						best, y = gap, height
					end

					table.insert(
						ventMarks,
						Vector3.new(
							if math.abs(normal.X) < 0.5 then snap(hit.Position.X) else hit.Position.X,
							height,
							if math.abs(normal.Z) < 0.5 then snap(hit.Position.Z) else hit.Position.Z
						)
					)
				end
			end
		end

		local x = if math.abs(normal.X) < 0.5 then snap(hit.Position.X) else hit.Position.X
		local z = if math.abs(normal.Z) < 0.5 then snap(hit.Position.Z) else hit.Position.Z
		local centre = Vector3.new(x, y, z)

		ventHitNormal = normal
		snapMark = centre

		return if shaft then centre else centre - Vector3.new(0, size / 2, 0)
	end

	local function floorPoint(): Vector3?
		local joins = mode == "Room" or mode == "Corridor" or mode == "ArchedCorridor"
		local doorModes = mode == "Corridor" or mode == "ArchedCorridor"
		local raised = mode == "Room"
			or mode == "Corridor"
			or mode == "ArchedCorridor"
			or mode == "Porch"
			or mode == "Floor"

		if
			not raised
			and mode ~= "Foundation"
			and mode ~= "Roof"
			and mode ~= "Fence"
			and mode ~= "Railing"
			and mode ~= "HalfWall"
		then
			return nil
		end

		local hit = hitSurface()

		if not hit then
			return nil
		end

		if doorModes then
			local door = doorSnap(hit.Position)

			if door then
				return door
			end
		end

		if joins and hit.Normal.Y < 0.7 then
			local level = Joints.FloorLevel(hit.Instance)

			if level then
				return partSnapLevel(Vector3.new(snap(hit.Position.X), level, snap(hit.Position.Z)), true)
			end
		end

		if hit.Normal.Y < 0.7 then
			return nil
		end

		local point = Vector3.new(
			snap(hit.Position.X),
			hit.Position.Y + (if raised then settings.Floor else 0),
			snap(hit.Position.Z)
		)

		return partSnapLevel(point, joins)
	end

	--[[
		@return Vector3? -- the snapped spot on the top of whatever the cursor is over, height included,
			so a railing can be placed on the steps of a stair

		The height is not snapped, so the point stays on the surface.
	]]
	local function surfaceTop(): Vector3?
		local hit = hitSurface()

		if not hit or hit.Normal.Y < 0.7 then
			return nil
		end

		return partSnap(Vector3.new(snap(hit.Position.X), hit.Position.Y, snap(hit.Position.Z)))
	end

	--[[
		@return number? -- how far into the locked wall the mouse points, in studs, measured along the wall's normal

		It intersects the mouse ray with the vertical plane through the clicked spot that contains the
		wall normal, and keeps the last value when the camera looks along that plane.
	]]
	local function cutDepthFrom(hit: RaycastResult): number?
		local plane = hit.Normal:Cross(Vector3.yAxis)

		if plane.Magnitude < 0.1 then
			return cutDepth
		end

		plane = plane.Unit

		local ray = mouse.UnitRay
		local den = ray.Direction:Dot(plane)

		if math.abs(den) < 0.05 then
			return cutDepth
		end

		local t = (hit.Position - ray.Origin):Dot(plane) / den
		local point = ray.Origin + ray.Direction * t
		local step = math.max(0.05, settings.FineGrid)
		local depth = Snap.Round((point - hit.Position):Dot(-hit.Normal), step)

		cutDepth = math.max(step, depth)

		return cutDepth
	end

	--[[
		@param from Vector3 -- the point the height is measured from
		@return number -- a height taken from how far the mouse moved up the screen since Y was pressed

		Looking straight down, the mouse cannot be projected onto a vertical line, so the height follows the mouse on screen instead.
	]]
	local function screenHeight(from: Vector3, signed: boolean?): number
		local camera = workspace.CurrentCamera

		if not camera or not heightMouse then
			return gridNow()
		end

		local distance = (camera.CFrame.Position - from).Magnitude
		local perPixel = 2 * distance * math.tan(math.rad(camera.FieldOfView) / 2) / math.max(1, camera.ViewportSize.Y)

		local raw = snap((heightMouse.Y - UserInputService:GetMouseLocation().Y) * perPixel)

		return if signed then raw else math.max(gridNow(), raw)
	end

	local function lookVector(): Vector3
		local camera = workspace.CurrentCamera

		return if camera then camera.CFrame.LookVector else Vector3.zAxis
	end

	local function mouseLocation(): Vector2
		return UserInputService:GetMouseLocation()
	end

	--
	-- Previews
	--

	--[[
		Recomputes the preview of the active tool for the current mouse position.
	]]
	local function update()
		if not mode or not RunService:IsEdit() then
			Overlay.ClearGhosts(overlay)
			previewValid = false

			return
		end

		if extendDrag or extrude or session then
			return
		end

		local out: { Spec } = {}
		local cutVolume: { cf: CFrame, size: Vector3 }? = nil

		openingCuts = nil
		snapMark = nil
		local live = settings
		local gridStep = gridNow()

		if gridStep ~= settings.Grid then
			live = table.clone(settings)
			live.Grid = gridStep
		end
		local message: string? = nil

		Overlay.ClearPlaneGrid(overlay)
		Overlay.ResetWireColor(overlay)

		if mode == "Extend" then
			Overlay.ClearGhosts(overlay)

			local handled = overlay.FaceHandles.Adornee

			if handled and not handled:IsDescendantOf(workspace) then
				overlay.FaceHandles.Adornee = nil
				overlay.FaceHandles.Visible = false
			end

			return
		elseif mode == "CutShape" then
			local face = cutFace
			local spot: Vector3? = nil

			if face then
				local ray = mouse.UnitRay
				local denom = ray.Direction:Dot(face.normal)

				if math.abs(denom) > 1e-4 then
					local t = (face.origin - ray.Origin):Dot(face.normal) / denom

					if t > 0 then
						spot = ray.Origin + ray.Direction * t
					end
				end
			else
				local hit = scopedHit()

				if hit and hit.Instance:IsA("BasePart") and not hit.Instance:IsA("Terrain") then
					face = faceOf(hit.Instance, hit.Normal)
					spot = hit.Position
				end

				cutPending = face
			end

			if spot and face then
				spot = faceSnap(face, spot)
			end

			cutSpot = spot

			local previous = cutPoints[#cutPoints]

			for i = 2, #cutPoints do
				local a, b = cutPoints[i - 1], cutPoints[i]

				Geometry.Add(out, Vector3.new(0.2, 0.2, (b - a).Magnitude), CFrame.lookAt((a + b) * 0.5, b), "CutEdge")
			end

			if spot and previous then
				Geometry.Add(
					out,
					Vector3.new(0.2, 0.2, (spot - previous).Magnitude),
					CFrame.lookAt((spot + previous) * 0.5, spot),
					"CutEdge"
				)
			end

			if spot then
				Geometry.Add(out, Vector3.new(0.4, 0.4, 0.4), CFrame.new(spot), "Start")
				snapMark = spot
			end

			if #cutPoints == 0 then
				message = "Click the first corner on the wall."
			elseif #cutPoints < 3 then
				message = "Click the next corner."
			else
				message = "Click the next corner. Click the first corner again or press Enter to cut the shape out."
			end
		elseif
			mode == "Door"
			or mode == "Window"
			or mode == "CircleWindow"
			or mode == "TriangleWindow"
			or mode == "ArchOpening"
		then
			local opening = if mode == "Door"
				then { Width = settings.DoorWidth, Height = settings.DoorHeight, Sill = 0 }
				elseif mode == "Window" or mode == "TriangleWindow" then {
					Width = settings.WindowWidth,
					Height = settings.WindowHeight,
					Sill = settings.WindowSill,
				}
				else { Width = settings.OpenWidth, Height = settings.OpenHeight, Sill = 0 }

			if mode == "CircleWindow" then
				local diameter = math.min(settings.WindowWidth, settings.WindowHeight)

				opening = { Width = diameter, Height = diameter, Sill = settings.WindowSill }
			end

			local shape = if mode == "ArchOpening"
				then "Arch"
				elseif mode == "CircleWindow" then "Circle"
				elseif mode == "TriangleWindow" then "Triangle"
				else "Rect"
			local locked = first ~= nil and lockedHit ~= nil
			local depth: number? = nil

			if locked and lockedHit then
				depth = cutDepthFrom(lockedHit)
			end

			out, message, openingTarget, cutVolume, openingCuts =
				Builders.Opening(live, opening, if locked then lockedHit else scopedHit(), shape, depth)

			if locked and (#out > 0 or openingCuts) then
				message = if depth
					then string.format(
						"Cut depth %.2f. Move the mouse to change it; past the far side it cuts all the way through. Click to confirm.",
						depth
					)
					else "Move the mouse to set the cut depth. Click to confirm."
			end
		elseif mode == "VentCover" or mode == "VentCap" or mode == "VentFan" or mode == "VentPeek" then
			local hit = hitSurface()

			if hit then
				local endPoint, outward = nil, nil

				if mode ~= "VentPeek" then
					endPoint, outward = Snapper.VentEnd(hit.Position, math.max(settings.VentSize, 3))
				end

				local center = hit.Position
				local normal = hit.Normal

				peekCut = nil

				if mode == "VentPeek" then
					local fine = math.max(0.25, settings.FineGrid)
					local part = hit.Instance :: BasePart
					local depth = math.max(0.4, math.min(part.Size.X, part.Size.Y, part.Size.Z) + 0.2)

					center = Vector3.new(
						if math.abs(normal.X) < 0.5 then math.round(center.X / fine) * fine else center.X,
						if math.abs(normal.Y) < 0.5 then math.round(center.Y / fine) * fine else center.Y,
						if math.abs(normal.Z) < 0.5 then math.round(center.Z / fine) * fine else center.Z
					)

					local u = (if math.abs(normal.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis):Cross(normal).Unit
					local frame = CFrame.fromMatrix(center, u, normal:Cross(u), normal)

					peekCut = {
						cf = frame * CFrame.new(0, 0, 0.1 - depth / 2),
						size = Vector3.new(2.4 - 0.5, 0.9 - 0.4, depth),
						cylinder = false,
					}
				elseif endPoint and outward then
					center, normal = endPoint, outward
				else
					center = Vector3.new(
						if math.abs(normal.X) < 0.5 then snap(center.X) else center.X,
						if math.abs(normal.Y) < 0.5 then snap(center.Y) else center.Y,
						if math.abs(normal.Z) < 0.5 then snap(center.Z) else center.Z
					)
				end

				local build: (typeof(settings), Vector3, Vector3) -> { Geometry.Spec } = if mode == "VentCap"
					then Builders.VentCap
					elseif mode == "VentFan" then Builders.VentFan
					elseif mode == "VentPeek" then Builders.VentPeek
					else Builders.VentCover

				out = build(settings, center + normal * 0.075, normal)
				message = "Click to place it."
			end
		elseif mode == "Pillar" then
			local hit = hitSurface()
			local base: Vector3? = nil

			if hit and hit.Normal.Y >= 0.7 then
				base = partSnap(Vector3.new(snap(hit.Position.X), hit.Position.Y, snap(hit.Position.Z)))
			else
				base = horizontalPoint(settings.Elevation)
			end

			if base then
				out = Builders.Pillar(settings, base)
				message = "Click to place the pillar."
			end
		elseif mode == "Place" then
			local hit = hitSurface()

			out, message = Builders.Place(settings, hit, source, brushScale)

			if brushing then
				if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
					finishBrush()
				elseif hit then
					local last = brushLast

					if not last or (hit.Position - last).Magnitude >= settings.BrushSpacing then
						brushStep(hit)
					end
				end
			end

			for _, spec in brushSpecs do
				table.insert(out, spec)
			end
		elseif mode == "Measure" then
			local hit = hitSurface()

			current = if hit then hit.Position else horizontalPoint(settings.Elevation)

			if current and settings.SnapToParts then
				local corner, found = Snapper.VertexNear(current, UserInputService:GetMouseLocation(), 14)

				if found then
					current = corner
					snapMark = corner
				end
			end

			if current and first then
				Overlay.DrawMeasurement(overlay, first, current)
				message = "Click to keep this measurement. The number stays in the viewport."
			elseif measurement then
				Overlay.DrawMeasurement(overlay, measurement.a, measurement.b)
			end
		else
			local origin = first
			local height: number? = nil

			if origin and riseStage and (mode == "Vent" or mode == "VentRamp") then
				origin = origin + ventShift
			end
			local signedHeight = 0

			if origin and lock and heightEnd and lock.Axis == "Y" and not lock.Plane then
				local camera = workspace.CurrentCamera

				if camera and heightMouse and math.abs(camera.CFrame.LookVector.Y) > 0.8 then
					height = screenHeight(origin)
					signedHeight = screenHeight(origin, true)
				else
					local top = lockedPoint(heightEnd, lock)

					if top then
						height = math.max(gridNow(), math.abs(top.Y - origin.Y))
						signedHeight = top.Y - origin.Y
					end
				end

				current = heightEnd
			elseif origin and lock then
				current = lockedPoint(origin, lock)
			elseif origin then
				if mode == "Railing" or mode == "HalfWall" then
					current = surfaceTop() or horizontalPoint(origin.Y)
				elseif mode == "Wall" or mode == "PillaredWall" or mode == "Stairs" or mode == "Ramp" then
					current = vertexPoint(origin.Y) or horizontalPoint(origin.Y)
				else
					current = horizontalPoint(origin.Y)
				end
			else
				if mode == "Vent" or mode == "VentRamp" or mode == "VentShaft" then
					current = ventPoint(mode == "VentShaft") or horizontalPoint(settings.Elevation)
				elseif mode == "Wall" or mode == "PillaredWall" or mode == "Stairs" or mode == "Ramp" then
					current = vertexPoint(nil) or horizontalPoint(settings.Elevation)
				else
					current = floorPoint() or horizontalPoint(settings.Elevation)
				end
			end

			if startDoor and origin and current and not lock then
				local n = startDoor.normal
				local along = math.max(0, snap((current.X - origin.X) * n.X + (current.Z - origin.Z) * n.Z))

				current = Vector3.new(origin.X + n.X * along, origin.Y, origin.Z + n.Z * along)
			end

			local point = current

			if point and settings.ShowGrid and not lock then
				Overlay.DrawPlaneGrid(
					overlay,
					Vector3.new(snap(point.X), point.Y, snap(point.Z)),
					math.max(0.05, gridNow())
				)
			end

			if point and origin then
				local b = point

				if
					not lock
					and (
						UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
						or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
					)
				then
					local d = b - origin

					b = if math.abs(d.X) >= math.abs(d.Z)
						then Vector3.new(b.X, origin.Y, origin.Z)
						else Vector3.new(origin.X, origin.Y, b.Z)
					current = b
				end

				if chained and prevWall and (mode == "Corridor" or mode == "ArchedCorridor") then
					local straight = prevWall.dir
					local sideways = straight:Cross(Vector3.yAxis)
					local flat = Vector3.new(b.X - origin.X, 0, b.Z - origin.Z)
					local best, bestDot = straight, -math.huge

					for _, option in { straight, sideways, -sideways } do
						local dot = flat:Dot(option)

						if dot > bestDot then
							best, bestDot = option, dot
						end
					end

					b = origin + best * math.max(0, snap(bestDot)) + Vector3.new(0, b.Y - origin.Y, 0)
					current = b
				end

				if (mode == "Vent" or mode == "VentRamp") and not riseStage then
					local d = b - origin
					local alongX = math.abs(d.X) >= math.abs(d.Z)
					local sign = if alongX then (if d.X >= 0 then 1 else -1) else (if d.Z >= 0 then 1 else -1)
					local axis = if alongX then Vector3.xAxis else Vector3.zAxis

					if chained and prevWall and (axis * sign):Dot(prevWall.dir) < -0.5 then
						alongX = not alongX
						axis = if alongX then Vector3.xAxis else Vector3.zAxis
						sign = if alongX then (if d.X >= 0 then 1 else -1) else (if d.Z >= 0 then 1 else -1)
					end

					b = origin + axis * sign * (if alongX then math.abs(d.X) else math.abs(d.Z))

					if not chained and ventNormal then
						local sideways = math.abs((axis * sign):Dot(ventNormal)) < 0.5

						ventShift = if sideways then ventNormal * (settings.VentSize / 2) else Vector3.zero
					end

					if not chained and ventHost then
						local along = axis * sign
						local into = math.abs(along:Dot(ventHost)) < 0.5

						ventShift = if into then along * (settings.VentSize / 2) else Vector3.zero
						origin = origin + ventShift
					else
						origin, b = origin + ventShift, b + ventShift
						current = b
					end
				end

				local drawn = live

				if height then
					drawn = table.clone(live)
					drawn.Height = height
				end

				if startDoor and (mode == "Corridor" or mode == "ArchedCorridor") then
					drawn = table.clone(drawn)
					drawn.Width = startDoor.width
					drawn.Height = startDoor.height or drawn.Height
				end

				if mode == "Room" then
					out = Builders.Room(drawn, origin, b)
				elseif mode == "Block" then
					out = Builders.Block(settings, origin, b, lock)
				elseif mode == "Floor" then
					out = Builders.Floor(drawn, origin, b)
				elseif mode == "Foundation" then
					out = Builders.Foundation(drawn, origin, b)
				elseif mode == "Porch" then
					out = Builders.Porch(drawn, origin, b)
				elseif mode == "Roof" then
					out = Builders.Roof(drawn, origin, b)
				elseif mode == "Railing" then
					out = Builders.Railing(drawn, origin, b, not chained)
				elseif mode == "HalfWall" then
					out = Builders.HalfWall(drawn, origin, b, not chained)
				elseif mode == "Fence" then
					out = Builders.Fence(drawn, origin, b, not chained)
				elseif mode == "ArchedCorridor" then
					local joinDir = if chained and prevWall then prevWall.dir else nil

					out = Builders.ArchedCorridor(drawn, origin, b, joinDir)
				elseif mode == "Vent" then
					local joinDir = if chained and prevWall then prevWall.dir else nil
					local lift = Vector3.new(0, settings.VentSize / 2, 0)

					out = Builders.VentRun(settings, origin, b, joinDir)
					ventEnds = { origin + lift, b + lift }
				elseif mode == "VentRamp" then
					local lift = Vector3.new(0, settings.VentSize / 2, 0)

					if riseStage then
						local top = b + Vector3.new(0, signedHeight, 0)

						out = Builders.VentDuct(settings, origin + lift, top + lift)
						ventEnds = { origin + lift, top + lift }
					else
						out = Builders.VentRun(settings, origin, b, nil)
					end
				elseif mode == "VentShaft" then
					local top = origin + Vector3.new(0, signedHeight, 0)
					local start = origin

					if
						ventHost
						and math.abs(ventHost.Y) < 0.5
						and math.abs(signedHeight) > settings.VentSize / 2 + 0.1
					then
						start = origin + Vector3.new(0, math.sign(signedHeight) * settings.VentSize / 2, 0)
					end

					out = Builders.VentDuct(settings, start, top)
					ventEnds = { start, top }
				elseif mode == "Wall" or mode == "PillaredWall" or mode == "Corridor" then
					local path = table.clone(drawn)

					path.PillaredWalls = mode == "PillaredWall"
					local joinDir = if chained
							and (mode == "Wall" or mode == "Corridor")
							and prevWall
						then prevWall.dir
						else nil

					out = Builders.Path(path, origin, b, mode == "Corridor", not chained, joinDir)
				elseif mode == "Stairs" or mode == "Ramp" then
					local sized = settings

					if riseStage and height then
						sized = table.clone(settings)
						sized.StairHeight = height
						sized.RampHeight = height
					end

					out = Builders.Stairs(sized, origin, b, mode == "Ramp")
				elseif mode == "Arch" then
					out = Builders.Arch(settings, origin, b)
				end

				local d = b - origin

				if mode == "Arch" and #out == 0 then
					message =
						"Arch height must be at least half the drawn span. Increase clearance height or draw a narrower arch."
				else
					message = "Click to build. Hold Alt for a straight direction; Esc cancels."

					local text

					if mode == "Room" or mode == "Block" then
						text = if #out > 0
							then string.format(
								"%.1f × %.1f × %.1f studs",
								out[1].size.X,
								out[1].size.Y,
								out[1].size.Z
							)
							else string.format("%.1f × %.1f studs", math.abs(d.X), math.abs(d.Z))
					elseif mode == "Floor" or mode == "Foundation" or mode == "Porch" or mode == "Roof" then
						text = string.format("%.1f × %.1f studs", math.abs(d.X), math.abs(d.Z))
					elseif mode == "Arch" then
						text = string.format("Span %.1f  |  Height %.1f", d.Magnitude, settings.ArchHeight)
					elseif mode == "Stairs" then
						text = string.format("Run %.1f  |  Rise %.1f", d.Magnitude, height or settings.StairHeight)
					elseif mode == "Ramp" then
						text = string.format("Run %.1f  |  Rise %.1f", d.Magnitude, height or settings.RampHeight)
					elseif height then
						text = string.format("%.1f studs  |  Height %.1f", d.Magnitude, height)
					else
						text = string.format("%.1f studs", d.Magnitude)
					end

					if lock then
						text ..= `  [{if lock.Plane then "plane " else ""}{lock.Axis}]`
					end

					if not NumericInput.IsEmpty(numeric) then
						text ..= `  = {numeric.Text}`
					end

					Overlay.Readout(overlay, (origin + b) * 0.5, text)
				end
			elseif point then
				Geometry.Add(out, Vector3.new(0.25, 0.15, 0.25), CFrame.new(point), "Start")
			end
		end

		previewSpecs = out
		previewValid = #out > 0
			or openingCuts ~= nil
				and (first ~= nil or mode == "Door" or mode == "Window" or mode == "CircleWindow" or mode == "TriangleWindow" or mode == "ArchOpening" or mode == "Pillar" or mode == "Place")
		Overlay.DrawGhosts(overlay, out)
		Overlay.DrawCut(overlay, cutVolume)
		Overlay.DrawSnap(overlay, snapMark)

		local holes: { { cf: CFrame, size: Vector3 } } = {}

		if settings.ConnectStructures and #out > 0 and first then
			if mode == "Room" or mode == "Corridor" or mode == "ArchedCorridor" then
				holes =
					Joints.Preview("Vlux_" .. mode, out, settings.RoomJoin, if prevWall then prevWall.model else nil)
			end
		end

		if #holes == 0 and not first and #ventMarks > 0 and mode and string.sub(mode, 1, 4) == "Vent" then
			for _, mark in ventMarks do
				table.insert(holes, { cf = CFrame.new(mark), size = Vector3.new(0.45, 0.45, 0.45) })
			end
		end

		Overlay.DrawHoles(overlay, holes)

		if lock and not lock.Plane and first and mode and DRAW_MODES[mode] then
			Overlay.DrawAxisLine(overlay, heightEnd or first, lock.Axis)
		end

		if message then
			say(message)
		end
	end

	--
	-- Extrude (T)
	--

	--[[
		@return BasePart? -- the block to extrude: the one under the cursor, else the selected one
		@return Vector3 -- the world-space normal of the face to grow from
	]]
	local function pickFace(): (BasePart?, Vector3)
		local hit = hitSurface()

		if hit and Geometry.IsPlainBlock(hit.Instance) and Geometry.InScope(hit.Instance) then
			return hit.Instance :: BasePart, hit.Normal
		end

		local selected = Selection:Get()
		local chosen = selected[1]

		if #selected == 1 and chosen and Geometry.IsPlainBlock(chosen) and Geometry.InScope(chosen) then
			-- Nothing under the cursor, so grow from the face that looks most toward the camera.
			local part = chosen :: BasePart
			local toward = -lookVector()
			local best, bestDot = Vector3.yAxis, -math.huge

			for _, local_ in
				{ Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis }
			do
				local world = part.CFrame:VectorToWorldSpace(local_)
				local dot = world:Dot(toward)

				if dot > bestDot then
					best, bestDot = world, dot
				end
			end

			return part, best
		end

		return nil, Vector3.yAxis
	end

	local function cancelExtrude()
		if not extrude then
			return
		end

		extrude = nil
		Overlay.ClearGhosts(overlay)
		Overlay.HideReadout(overlay)

		if not mode then
			Overlay.HideBar(overlay)
			plugin:Deactivate()
		end
	end

	local function startExtrude()
		if not RunService:IsEdit() then
			return say("Stop the playtest before building.")
		end

		stop(true)

		if not requireFolder() then
			return
		end

		local part, normal = pickFace()

		if not part then
			return say("Point at a rectangular block, or select one, then press T to extrude a face.")
		end

		local axis, side = Builders.FaceAxis(part, normal)
		local localUnit = if axis == 1 then Vector3.xAxis elseif axis == 2 then Vector3.yAxis else Vector3.zAxis
		local half = (if axis == 1 then part.Size.X elseif axis == 2 then part.Size.Y else part.Size.Z) / 2
		local worldNormal = part.CFrame:VectorToWorldSpace(localUnit * side)

		extrude = {
			part = part,
			normal = worldNormal,
			origin = part.Position + worldNormal * half,
			length = 0,
			numeric = NumericInput.new(),
		}
		plugin:Activate(true)
		say(
			"Extrude: move the mouse to pull the face out. Type a number for an exact length. Click or Enter builds; Esc cancels."
		)
	end

	local function updateExtrude()
		local state = extrude

		if not state then
			return
		end

		if not state.part:IsDescendantOf(workspace) then
			cancelExtrude()

			return
		end

		local typed = NumericInput.Value(state.numeric)
		local length

		if typed then
			length = typed
		else
			local ray = mouse.UnitRay
			local along = AxisLock.ClosestOnLine(
				Geometry.ToVec(state.origin),
				Geometry.ToVec(state.normal),
				Geometry.ToVec(ray.Origin),
				Geometry.ToVec(ray.Direction)
			)

			length = if along then snap(along) else 0
		end

		state.length = math.clamp(length, 0, MAX_LENGTH)

		if state.length > 0.001 then
			local out = Builders.Extend(settings, state.part, state.normal, state.length)

			Overlay.DrawGhosts(overlay, out)

			if out[1] then
				Overlay.Readout(overlay, out[1].cf.Position, string.format("Extrude %.2f studs", state.length))
			end
		else
			Overlay.ClearGhosts(overlay)
			Overlay.HideReadout(overlay)
		end
	end

	local function confirmExtrude()
		local state = extrude

		if not state then
			return
		end

		if state.length < math.max(0.05, settings.Grid * 0.5) then
			return say("Move the mouse away from the face, or type a length, then click.")
		end

		extrude = nil

		local out = Builders.Extend(settings, state.part, state.normal, state.length)

		edit("Extrude face", function()
			Geometry.Materialize(out, "Face_Extension")
		end)

		Overlay.ClearGhosts(overlay)
		Overlay.HideReadout(overlay)
		say(string.format("Extruded %.2f studs. Press T again to keep going.", state.length))

		if not mode then
			Overlay.HideBar(overlay)
			plugin:Deactivate()
		end
	end

	--
	-- Grab, rotate, scale (G, R, C, V)
	--

	local function finishSession(commit: boolean)
		local active = session
		local id = sessionRecording

		if not active then
			return
		end

		session, sessionRecording = nil, nil

		if not commit then
			Transform.Restore(active)
		end

		if id then
			ChangeHistoryService:FinishRecording(
				id,
				if commit then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
			)
		end

		Overlay.HideReadout(overlay)

		if not mode then
			Overlay.HideBar(overlay)
			plugin:Deactivate()
		end

		say(if commit then "Done. Ctrl+Z undoes it." else "Cancelled.")
	end

	local function startSession(kind: Transform.Kind, duplicate: boolean)
		if not RunService:IsEdit() then
			return say("Stop the playtest before building.")
		end

		stop(true)

		if not requireFolder() then
			return
		end

		local roots = Geometry.SelectedRoots()
		local parts = Geometry.PartsOf(roots)

		if #parts == 0 then
			return say("Select Parts or Models first.")
		end

		if not workspace.CurrentCamera then
			return say("No camera to work from.")
		end

		for _, root in roots do
			if duplicate and not root.Archivable then
				return say("Enable Archivable on selected objects first.")
			end
		end

		plugin:Activate(true)

		local id = ChangeHistoryService:TryBeginRecording("Vlux_" .. kind, kind)

		if not id then
			plugin:Deactivate()

			return say("Cannot begin an edit right now. Finish the other tool action first.")
		end

		if duplicate then
			local copies = Arrange.CloneRoots(roots, function(cf)
				return cf
			end)

			Selection:Set(copies)
			parts = Geometry.PartsOf(copies)
		end

		session = Transform.Begin(kind, parts, mouseLocation(), mouse.UnitRay, lookVector())
		sessionRecording = id
		say(
			(if duplicate then "Duplicate, then move. " else "")
				.. `{kind}: move the mouse. X / Y / Z locks an axis, Alt+X / Y / Z a plane; type a number for an exact value. Click or Enter confirms; Esc cancels.`
		)
	end

	local function updateSession()
		local active = session

		if not active then
			return
		end

		for _, part in active.Parts do
			if not part:IsDescendantOf(workspace) then
				finishSession(false)

				return
			end
		end

		local text, position = Transform.Update(active, gridNow(), mouseLocation(), mouse.UnitRay, lookVector())

		Overlay.Readout(overlay, position, text)
	end

	--
	-- Tools
	--

	local function activateMode(name: string)
		stop(true)

		if not requireFolder() then
			return
		end

		if not RunService:IsEdit() then
			return say("Stop the playtest before using tools.")
		end

		if name == "Place" then
			local problem = buildBrushPool()

			if problem then
				return say(problem)
			end

			rollBrush()
		end

		mode = name
		plugin:Activate(true)

		if name == "Extend" then
			local chosen = Selection:Get()

			if #chosen == 1 and Geometry.IsPlainBlock(chosen[1]) and Geometry.InScope(chosen[1]) then
				overlay.FaceHandles.Adornee = chosen[1] :: BasePart
				overlay.FaceHandles.Visible = true
			end
		end

		panel.Refresh()
		say(INSTRUCTIONS[name])
	end

	local lastVariant: { [string]: string } = {}
	local lastMode: string? = nil

	--[[
		@param name string -- a mode of a tile, such as Room

		Switches to that mode and remembers it as the one its tile starts with.
	]]
	local function setMode(name: string)
		if mode == name then
			return
		end

		activateMode(name)

		local tile = Tools.TileOf(name)

		if tile and mode == name then
			lastVariant[tile.Id] = name
		end

		if mode == name then
			lastMode = name
		end
	end

	--[[
		@param id string -- a tile id

		Picking a tile starts the mode it used last. Picking the tile that is already active turns it off.
	]]
	local function activate(id: string)
		local tile = Tools.FindTile(id)

		if not tile then
			return setMode(id)
		end

		if mode and table.find(tile.Modes, mode) then
			stop()

			return say("Tool off.")
		end

		setMode(lastVariant[tile.Id] or tile.Modes[1])
	end

	stop = function(keepActive: boolean?)
		finishSession(false)
		cancelExtrude()
		mode = nil
		extendDrag = nil
		overlay.FaceHandles.Adornee = nil
		overlay.FaceHandles.Visible = false
		resetPoint()

		if not keepActive then
			Overlay.HideBar(overlay)
			plugin:Deactivate()
		end

		panel.Refresh()
	end

	--[[
		@param axis AxisLock.Axis
		@param plane boolean

		Turns an axis lock on, or off when it is already on, for the draw tool or the modal action.
	]]
	local function setLock(axis: AxisLock.Axis, plane: boolean)
		local active = session

		if extrude then
			return say("Extrude follows the face direction. Type a number for an exact length.")
		end

		if
			not active
			and mode
			and DRAW_MODES[mode]
			and axis == "Y"
			and not plane
			and mode ~= "Block"
			and not HEIGHT_MODES[mode]
		then
			return say(
				"Y sets the height of walls, corridors, rooms and blocks. For this tool use X or Z, or Alt+Y to stay on the floor."
			)
		end

		local updated = AxisLock.Toggle(if active then active.Lock else lock, axis, plane)

		if not active then
			if updated and updated.Axis == "Y" and not updated.Plane and mode and HEIGHT_MODES[mode] then
				if not first or not current then
					return say("Click the start point first, then press Y to drag the height.")
				end

				heightEnd = current
				heightMouse = mouseLocation()
			else
				heightEnd = nil
				heightMouse = nil
			end
		end

		if active then
			Transform.SetLock(active, updated, mouse.UnitRay, lookVector())
			NumericInput.Clear(active.Numeric)
		else
			lock = updated
			NumericInput.Clear(numeric)
		end

		say(
			if updated
				then `Locked to the {if updated.Plane then "plane without " else ""}{updated.Axis} axis. Press {if plane
					then "Alt+"
					else ""}{axis} again to unlock.`
				else "Axis lock off."
		)
	end

	local function changeHeight(direction: number)
		local key = if mode == "Arch"
			then "ArchHeight"
			elseif mode == "Stairs" then "StairHeight"
			elseif mode == "Ramp" then "RampHeight"
			else "Height"
		local values = settings :: any

		values[key] = math.clamp(values[key] + direction * settings.Grid, 0.1, MAX_LENGTH)
		panel.SetField(key)
		save()
	end

	--[[
		@param action Keymap.Action

		Carries out a resolved hotkey.
	]]
	local function perform(action: Keymap.Action)
		if action == "Cancel" then
			if picking then
				cancelPicking()
				say("Folder pick cancelled.")
			elseif armed then
				armed = nil
				say("Cancelled.")
			elseif session then
				finishSession(false)
			elseif extrude then
				cancelExtrude()
				say("Extrude cancelled.")
			elseif lockedHit or cutFace then
				resetPoint()
				say("Cut cancelled.")
			elseif mode and (first ~= nil or chained or measurement ~= nil) then
				resetPoint()
				say("Point removed. Click to start again, or press Esc again to leave the tool.")
			elseif mode then
				stop()
				say("Tool stopped. Your completed builds stay in the map. Press Enter to bring it back.")
			end
		elseif action == "Confirm" then
			if session then
				finishSession(true)
			elseif extrude then
				confirmExtrude()
			elseif mode == "CutShape" and cutFace then
				finishCut()
			elseif mode then
				resetPoint()
				say(INSTRUCTIONS[mode])
			end
		elseif action == "Extrude" then
			startExtrude()
		elseif action == "Rotate" and mode == "Place" then
			settings.Yaw = (settings.Yaw + 90) % 360
			panel.SetField("Yaw")
			save()
		elseif action == "Grab" or action == "Rotate" or action == "Scale" then
			startSession(action :: Transform.Kind, false)
		elseif action == "Duplicate" then
			startSession("Grab", true)
		elseif action == "Hide" then
			local parts = Geometry.PartsOf(Geometry.SelectedRoots(true))

			if #parts == 0 then
				say("Select something to hide first.")
			else
				Hidden.Hide(hidden, parts)
				Selection:Set({})
				panel.Refresh()
				say(`Hid {#parts} part(s). Alt+H unhides them, I shows them as ghosts.`)
			end
		elseif action == "Unhide" then
			local count = Hidden.UnhideAll(hidden)

			panel.Refresh()
			say(if count > 0 then `Unhid {count} part(s).` else "Nothing was hidden.")
		elseif action == "ToggleHiddenView" then
			Hidden.ToggleView(hidden)
			panel.Refresh()
			say(if hidden.View then "Hidden parts are shown as ghosts." else "Hidden parts are fully hidden.")
		elseif action == "FlipArm" then
			if requireFolder() then
				stop(true)
				armed = "Flip"
				say("Flip: press X, Y or Z to mirror the selection across that axis. Esc cancels.")
			end
		elseif action == "Rotate90Arm" then
			if requireFolder() then
				stop(true)
				armed = "Rotate90"
				say("Rotate 90°: press X, Y or Z (hold Alt for -90°). Esc cancels.")
			end
		elseif action == "NextTab" or action == "PrevTab" then
			panel.CycleTab(if action == "NextTab" then 1 else -1)
		elseif action == "ShowHotkeys" then
			panel.ShowTab("Hotkeys")
		elseif action == "TogglePastel" then
			Colors.Set(colors, not colors.On)
		elseif action == "ToggleGrid" then
			SurfaceGrid.Set(surfaceGrid, not surfaceGrid.On)
		elseif action == "TogglePanel" then
			widget.Enabled = not widget.Enabled
		elseif action == "HeightUp" or action == "HeightDown" then
			if mode then
				changeHeight(if action == "HeightUp" then 1 else -1)
			end
		elseif string.sub(action, 1, 5) == "Tool:" then
			activate(string.sub(action, 6))
		elseif string.sub(action, 1, 7) == "Option:" then
			local tile = if mode then Tools.TileOf(mode) else nil

			if not tile then
				return say("Pick a tool first, then Alt plus a number picks an option inside it.")
			end

			local target = tile.Modes[tonumber(string.sub(action, 8)) :: number]

			if #tile.Modes < 2 then
				say(`{tile.Label} has no options.`)
			elseif target then
				setMode(target)
			else
				say(`{tile.Label} only has {#tile.Modes} options.`)
			end
		else
			local kind, axis = string.match(action, "^(%a+):([XYZ])$")

			if (kind == "Lock" or kind == "Plane") and armed then
				local pending = armed

				armed = nil

				if requireFolder() then
					if pending == "Flip" then
						arrange.Flip(axis :: string)
					else
						arrange.RotateBy(axis :: string, if kind == "Plane" then -90 else 90)
					end
				end
			elseif kind == "Lock" or kind == "Plane" then
				setLock(axis :: AxisLock.Axis, kind == "Plane")
			end
		end
	end

	--
	-- Panel
	--

	colors = Colors.new({
		Remember = function(value)
			if not quiet then
				settings.AutoPastel = value
				save()
			end
		end,
		GetScope = function()
			return folder
		end,
		Edit = edit,
		Say = say,
		Refresh = function()
			panel.Refresh()
		end,
		Stop = function()
			stop()
		end,
	}, trove)

	--[[
		@param instance Instance?

		@return Instance? -- the closest Folder above the instance, if it is inside Workspace
	]]
	local function folderOf(instance: Instance?): Instance?
		local ancestor = instance

		while ancestor and ancestor ~= workspace do
			if ancestor:IsA("Folder") then
				return ancestor
			end

			ancestor = ancestor.Parent
		end

		return nil
	end

	--[[
		@param which string -- Working, Pending or Hover
		@param target Instance?

		Outlines every Part inside the folder, or clears the outline when there is none to draw.
	]]
	local function drawBox(which: string, target: Instance?)
		local parts: { BasePart } = {}

		if target and target:IsDescendantOf(workspace) then
			for _, object in target:GetDescendants() do
				if object:IsA("BasePart") then
					table.insert(parts, object)
				end
			end
		end

		if #parts == 0 then
			return Overlay.ClearBox(overlay, which)
		end

		local cframe, size = Geometry.Bounds(parts)

		Overlay.DrawBox(overlay, which, cframe, size)
	end

	--[[
		Redraws the outlines of the working folder (only while it is selected), the folder waiting for a
		yes, and the one under the cursor.
	]]
	local function redrawBoxes()
		local selectedNow = Selection:Get()

		drawBox("Working", if folder and table.find(selectedNow, folder) then folder else nil)
		drawBox("Pending", pendingFolder)
		drawBox(
			"Hover",
			if picking and hoverFolder ~= pendingFolder and hoverFolder ~= folder then hoverFolder else nil
		)
	end

	--[[
		@param target Instance

		Marks the folder as the one to confirm.
	]]
	local function proposeFolder(target: Instance)
		pendingFolder = target
		redrawBoxes()
		panel.Refresh()
		say(`Picked "{target:GetFullName()}". Press Yes to confirm, or click another Folder.`)
	end

	--[[
		Starts picking a folder. A Folder in Workspace that is already selected becomes the pick right
		away; otherwise click one in the viewport or select one now.
	]]
	local function startPicking()
		stop()
		picking = true
		pendingFolder = nil
		hoverFolder = nil

		local selected = Selection:Get()
		local only = if #selected == 1 then selected[1] else nil

		if only and only:IsA("Folder") and only:IsDescendantOf(workspace) then
			return proposeFolder(only)
		end

		redrawBoxes()
		panel.Refresh()
		say("Click a Folder in the viewport, or select one in the Explorer.")
	end

	--[[
		Gives up picking and clears the outlines that picking drew.
	]]
	cancelPicking = function()
		picking = false
		pendingFolder = nil
		hoverFolder = nil
		redrawBoxes()
		panel.Refresh()
	end

	--[[
		@param chosen Instance? -- the confirmed folder

		Makes the folder the only place the plugin works in. Pastel colors is switched off first so
		the old folder is not left recolored.
	]]
	local function setFolder(chosen: Instance?)
		if colors.On and chosen ~= folder then
			quiet = true
			Colors.Set(colors, false)
			quiet = false
		end

		stop()

		local previous = folder

		folder = chosen
		Geometry.SetScope(chosen)
		redrawBoxes()
		panel.Refresh()

		if previous ~= chosen then
			edit("Set working folder", function()
				if previous and previous:IsDescendantOf(workspace) then
					previous:SetAttribute(FOLDER_ATTRIBUTE, nil)
					previous:SetAttribute(OLD_FOLDER_ATTRIBUTE, nil)
				end

				if chosen then
					chosen:SetAttribute(FOLDER_ATTRIBUTE, true)
				end
			end)
		end

		if chosen then
			if settings.AutoPastel and not colors.On then
				Colors.Set(colors, true)
			end

			if settings.AutoGrid and not surfaceGrid.On then
				SurfaceGrid.Set(surfaceGrid, true)
			end

			say(`Working in {chosen:GetFullName()}. Builds go in this folder and nothing outside it is changed.`)
		end
	end

	--[[
		Makes the picked folder the working folder.
	]]
	local function confirmPicking()
		local chosen = pendingFolder

		if not chosen then
			return say("Click a Folder in the viewport first.")
		end

		picking = false
		pendingFolder = nil
		hoverFolder = nil
		setFolder(chosen)
	end

	--[[
		@param run () -> ()

		@return () -> () -- the same action, but it only runs once a working folder is set
	]]
	local function guarded(run: () -> ()): () -> ()
		return function()
			if requireFolder() then
				run()
			end
		end
	end

	surfaceGrid = SurfaceGrid.new({
		Remember = function(value)
			if not quiet then
				settings.AutoGrid = value
				save()
			end
		end,
		GetScope = function()
			return folder
		end,
		GetSize = function()
			return settings.GridTextureSize
		end,
		GetColor = function()
			return SurfaceGrid.ColorOf(settings.GridColor)
		end,
		Edit = edit,
		Say = say,
		Refresh = function()
			panel.Refresh()
		end,
		Stop = function()
			stop()
		end,
	}, trove)

	arrange = Arrange.new({
		Settings = settings,
		Save = save,
		Edit = edit,
		Say = say,
		Stop = function()
			stop()
		end,
		Readout = function(position, text)
			Overlay.Readout(overlay, position, text)
		end,
		FloorField = function()
			panel.SetField("Elevation")
			resetPoint()
		end,
	})

	panel = Panel.new({
		Widget = widget,
		Settings = settings,
		Save = save,
		Colors = colors,
		SurfaceGrid = surfaceGrid,
		Hidden = hidden,
		GetFolder = function()
			return folder
		end,
		GetPending = function()
			return pendingFolder
		end,
		GetPicking = function()
			return picking
		end,
		GetMode = function()
			return mode
		end,
		Actions = {
			Activate = activate,
			SetMode = setMode,
			Stop = function()
				stop()
			end,
			ResetPoint = resetPoint,
			BrushesChanged = function()
				if mode == "Place" and buildBrushPool() == nil then
					rollBrush()
				end
			end,
			UseSelectedFloor = guarded(arrange.UseSelectedFloor),
			RepeatCopies = guarded(arrange.RepeatCopies),
			SnapSelection = guarded(arrange.SnapSelection),
			ShowDimensions = guarded(arrange.ShowDimensions),
			AnchorSelection = guarded(arrange.AnchorSelection),
			Flip = function(axis)
				if requireFolder() then
					arrange.Flip(axis :: string)
				end
			end,
			RotateBy = function(axis, degrees)
				if requireFolder() then
					arrange.RotateBy(axis, degrees)
				end
			end,
			StartPick = startPicking,
			CancelPick = cancelPicking,
			ConfirmPick = confirmPicking,
			UnhideAll = function()
				perform("Unhide")
			end,
			ToggleHiddenView = function()
				perform("ToggleHiddenView")
			end,
			Instruction = function(active)
				return (active and INSTRUCTIONS[active]) or "Choose a drawing tool first."
			end,
		},
	})

	--
	-- Extend tool handles
	--

	local function finishExtension()
		local drag = extendDrag

		if not drag then
			return
		end

		extendDrag = nil

		if drag.length >= math.max(0.05, settings.Grid) and drag.source.Parent then
			local out = Builders.Extend(settings, drag.source, drag.normal, drag.length)
			local built: Model?

			if
				edit("Drag face extension", function()
					built = Geometry.Materialize(out, "Face_Extension")
				end)
			then
				local part = built and built:FindFirstChildWhichIsA("BasePart")

				overlay.FaceHandles.Adornee = part
				overlay.FaceHandles.Visible = part ~= nil
				say("Added " .. drag.length .. " studs. Drag another handle to keep building.")
			end
		else
			say("Drag a green face handle outward to create an extension.")
		end

		Overlay.ClearGhosts(overlay)
		Overlay.HideReadout(overlay)
	end

	trove:Connect(overlay.FaceHandles.MouseEnter, function()
		extendHover = true
	end)
	trove:Connect(overlay.FaceHandles.MouseLeave, function()
		extendHover = false
	end)
	trove:Connect(overlay.FaceHandles.MouseButton1Down, function(face)
		local part = overlay.FaceHandles.Adornee

		if mode ~= "Extend" or not part or not RunService:IsEdit() then
			return
		end

		local block = part :: BasePart

		extendDrag = {
			source = block,
			normal = block.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face)),
			length = 0,
		}
	end)
	trove:Connect(overlay.FaceHandles.MouseDrag, function(_face, distance)
		local drag = extendDrag

		if not drag then
			return
		end

		drag.length = math.clamp(snap(distance), 0, MAX_LENGTH)

		if drag.length > 0.001 then
			local out = Builders.Extend(settings, drag.source, drag.normal, drag.length)

			Overlay.DrawGhosts(overlay, out)
			Overlay.Readout(overlay, out[1].cf.Position, string.format("Extend %.2f studs", drag.length))
			say(`Release to add {drag.length} studs. Esc cancels this extension.`)
		else
			Overlay.ClearGhosts(overlay)
			Overlay.HideReadout(overlay)
		end
	end)
	trove:Connect(overlay.FaceHandles.MouseButton1Up, finishExtension)

	--
	-- Clicks
	--

	trove:Connect(widget:GetPropertyChangedSignal("Enabled"), function()
		if not widget.Enabled and picking then
			cancelPicking()
		end
	end)

	trove:Connect(Selection.SelectionChanged, function()
		if not picking then
			if folder then
				redrawBoxes()
			end

			return
		end

		local selected = Selection:Get()
		local candidate = selected[1]

		if #selected == 1 and candidate and candidate:IsA("Folder") and candidate:IsDescendantOf(workspace) then
			return proposeFolder(candidate)
		end

		for _, object in selected do
			if object:IsDescendantOf(workspace) then
				return
			end
		end

		if #selected > 0 and pendingFolder then
			pendingFolder = nil
			redrawBoxes()
			panel.Refresh()
			say("That is not a Folder inside Workspace. Click or select a Folder in Workspace.")
		end
	end)

	trove:Connect(mouse.Button1Up, function()
		if brushing then
			finishBrush()
		end
	end)

	trove:Connect(mouse.Button1Down, function()
		if picking then
			local hit = hitSurface()
			local target = if hit then folderOf(hit.Instance) else nil

			if target then
				proposeFolder(target)
			else
				say("That is not inside a Folder. Click a Part that sits in a Folder.")
			end

			return
		end

		if session then
			return finishSession(true)
		elseif extrude then
			return confirmExtrude()
		end

		local active = mode

		if not active or not RunService:IsEdit() or extendDrag or (extendHover and active == "Extend") then
			return
		end

		if active == "Extend" then
			local hit = hitSurface()

			if
				hit
				and Geometry.IsPlainBlock(hit.Instance)
				and not hit.Instance.Locked
				and Geometry.InScope(hit.Instance)
			then
				overlay.FaceHandles.Adornee = hit.Instance :: BasePart
				overlay.FaceHandles.Visible = true
				say("Drag a green face handle outward. Release to add the new block.")
			else
				say("Click an unlocked rectangular block, then drag one of its green handles.")
			end

			return
		end

		local ok, err = pcall(update :: any)

		if not ok then
			return say(tostring(err))
		end

		if active == "CutShape" then
			local spot = cutSpot

			if not spot then
				return
			end

			if not cutFace then
				cutFace = cutPending
			end

			local points = cutPoints

			if #points >= 3 and (spot - points[1]).Magnitude < 0.05 then
				return finishCut()
			end

			local last = points[#points]

			if not last or (spot - last).Magnitude > 0.05 then
				table.insert(points, spot)
			end

			return
		end

		if
			active == "Door"
			or active == "Window"
			or active == "CircleWindow"
			or active == "TriangleWindow"
			or active == "ArchOpening"
		then
			if not previewValid then
				return
			end

			if settings.CutDepth and not first then
				local hit = scopedHit()

				if hit then
					lockedHit = hit
					cutDepth = nil
					first = hit.Position
					say("Move the mouse to set the cut depth. Click to confirm.")
				end

				return
			end

			local target = openingTarget
			local specs = previewSpecs
			local carving = openingCuts

			edit(if active == "ArchOpening" then "Create archway" else "Create " .. string.lower(active), function()
				if carving then
					assert(target and target.Parent, "Wall no longer exists")

					if not Joints.Carve(target, carving) then
						say("The wall could not be cut.")
					end

					return
				end

				local model =
					Geometry.Materialize(specs, if active == "ArchOpening" then "Archway" else "Wall_" .. active)

				if active == "ArchOpening" then
					local problem = Geometry.UnionSides(model, "Arch_Header", "Arch")

					if problem then
						say(problem)
					end
				end

				if active == "CircleWindow" then
					local problem = Geometry.UnionNamed(model, "Circle_Upper", "Circle_Frame")
						or Geometry.UnionNamed(model, "Circle_Lower", "Circle_Frame")

					if problem then
						say(problem)
					end
				end
				assert(target and target.Parent, "Wall no longer exists")

				local holder = target.Parent

				target.Parent = nil

				if holder and holder:IsA("Model") and #holder:GetChildren() == 0 then
					holder.Parent = nil
				end
			end)
			resetPoint()
		elseif active == "VentCover" or active == "VentCap" or active == "VentFan" or active == "VentPeek" then
			if not previewValid then
				return
			end

			local specs = previewSpecs

			local cut = if active == "VentPeek" then peekCut else nil

			edit("Place vent piece", function()
				if cut then
					local params = OverlapParams.new()
					local scope = Geometry.GetScope()

					if scope then
						params.FilterType = Enum.RaycastFilterType.Include
						params.FilterDescendantsInstances = { scope }
					end

					for _, part in workspace:GetPartBoundsInBox(cut.cf, cut.size, params) do
						if not part:IsA("Terrain") then
							Joints.Carve(part, { cut })
						end
					end
				end

				Geometry.Materialize(specs, "Vlux_" .. active)
			end)
		elseif active == "Pillar" then
			if not previewValid then
				return
			end

			local specs = previewSpecs

			edit("Build pillar", function()
				Geometry.Place(specs, "Pillar")
			end)
		elseif active == "Place" then
			local hit = hitSurface()

			if not previewValid or not hit or not source then
				return
			end

			brushing = true
			brushTargets, brushSpecs, brushLast = {}, {}, nil
			brushStep(hit)
		elseif active == "Measure" and current then
			if not first then
				measurement = nil
				first = current
				Overlay.ClearMeasurement(overlay)
				say("Now click the second surface point. Distance is shown beside the line.")
			else
				measurement = { a = first, b = current }
				Overlay.DrawMeasurement(overlay, first, current)
				say(
					string.format(
						"%.2f studs. Click to start another measurement; Esc clears it.",
						(current - first).Magnitude
					)
				)
				first = nil
			end
		elseif current then
			if not first then
				first = current
				ventNormal = if active == "Vent" or active == "VentRamp" then ventHitNormal else nil
				ventHost = if active == "Vent"
						or active == "VentRamp"
						or active == "VentShaft"
					then ventHitHost
					else nil
				ventShift = Vector3.zero
				startDoor = if active == "Corridor" or active == "ArchedCorridor" then hoverDoor else nil
				NumericInput.Clear(numeric)

				if active == "VentShaft" then
					riseStage = true
					heightEnd = current
					heightMouse = mouseLocation()
					lock = AxisLock.Toggle(nil, "Y", false)
					say("Move the mouse up or down to set the length of the vent. Click to place.")
				else
					say("Move to the other point. Click to build. Press X, Y or Z to lock an axis.")
				end
			elseif
				previewValid
				and (active == "Stairs" or active == "Ramp" or active == "VentRamp")
				and not riseStage
			then
				riseStage = true
				heightEnd = current
				heightMouse = mouseLocation()
				lock = AxisLock.Toggle(nil, "Y", false)
				say("Move the mouse up or down to set the height. Click to place.")
			elseif previewValid then
				local chain = active == "Wall"
					or active == "PillaredWall"
					or active == "Corridor"
					or active == "Fence"
					or active == "Railing"
					or active == "HalfWall"
					or active == "ArchedCorridor"
					or active == "Vent"
				local nextPoint = current
				local ends = ventEnds
				local specs = previewSpecs
				local segment = Vector3.new(current.X - first.X, 0, current.Z - first.Z)
				local joint = first

				if
					edit("Build " .. active, function()
						local loose = active == "Wall"
							or active == "Block"
							or active == "Floor"
							or active == "Foundation"
							or active == "HalfWall"
						local placed: Instance = if loose
							then Geometry.Place(specs, active)
							else Geometry.Materialize(specs, "Vlux_" .. active)
						local model: Model? = if placed:IsA("Model") then placed else nil
						local previousModel = if prevWall and prevWall.model:IsA("Model") then prevWall.model else nil
						local archCut: { Builders.Cutter } = {}
						local archBefore: Model? = nil

						if
							active == "Wall"
							or active == "Corridor"
							or active == "ArchedCorridor"
							or active == "Vent"
						then
							local before = prevWall
							local strips = if active == "Wall"
								then Builders.WallStrips(settings)
								elseif active == "Corridor" then Builders.CorridorStrips(settings)
								elseif active == "Vent" then Builders.VentStrips(settings)
								else Builders.ArchedStrips(settings)

							if before and before.model.Parent and segment.Magnitude > 0.001 then
								local bend = Builders.Bend(joint, before.dir, segment, before.strips, strips)
								local floor = before.model:FindFirstChild("Floor")
									or before.model:FindFirstChild("VentFloor")
								local across = before.dir:Cross(Vector3.yAxis)

								local pieces: { Instance } = if before.model:IsA("BasePart")
									then { before.model }
									else before.model:GetChildren()

								for _, child in pieces do
									if child:IsA("Part") then
										local key = if child.Name == "VentFloor"
											then "Floor"
											elseif child.Name == "VentCeiling" then "Ceiling"
											else child.Name

										if key == "CorridorWall" or key == "VentWall" then
											local lateral = if floor and floor:IsA("BasePart")
												then (child.Position - floor.Position):Dot(across)
												else 0

											key = if lateral > 0 then "Right" else "Left"
										end

										local delta = bend.finish[key]

										if delta and delta ~= 0 then
											child.Size += Vector3.new(0, 0, delta)
											child.CFrame *= CFrame.new(0, 0, -delta / 2)
										end
									end
								end

								if #bend.ending > 0 then
									Geometry.Materialize(bend.ending, "Vlux_Bend")
								end

								if active == "ArchedCorridor" then
									local corner = Geometry.Materialize({}, "Vlux_BendArch")

									for index, wedge in Builders.ArchedBend(settings, joint, before.dir, segment) do
										if
											not Geometry.AddCut(
												corner,
												wedge.specs,
												wedge.cutter,
												wedge.cutterSize,
												"ArchedCeiling"
											)
										then
											say("Part of the arched corner roof could not be built.")
										end

										archCut[index] =
											{ cf = wedge.cutter, size = wedge.cutterSize, cylinder = false }
									end

									archBefore = if before.model:IsA("Model") then before.model else nil
								end
							end

							prevWall = if segment.Magnitude > 0.001
								then { model = placed, dir = segment.Unit, strips = strips }
								else nil
						end

						if (active == "Vent" or active == "VentRamp" or active == "VentShaft") and ends and model then
							finishVent(model, ends[1], ends[2], previousModel)
						end

						if active == "Floor" and settings.FloorTransparency > 0 then
							local pieces: { Instance } = if placed:IsA("BasePart")
								then { placed }
								else placed:GetChildren()

							for _, child in pieces do
								if child:IsA("BasePart") then
									child.Transparency = math.clamp(settings.FloorTransparency, 0, 1)
								end
							end
						end

						if
							model
							and (
								active == "Arch"
								or active == "ArchedCorridor"
								or active == "Stairs"
								or active == "Ramp"
							)
						then
							local problem = if active == "Arch"
								then Geometry.UnionArchHalves(model)
								elseif active == "ArchedCorridor" then Geometry.UnionSides(
									model,
									"ArchedCeiling",
									"Ceiling"
								)
								else Geometry.UnionAll(model, active)

							if problem then
								say(problem)
							end

							if archBefore and #archCut == 2 then
								for index, owner in { archBefore, model } do
									for _, child in owner:GetChildren() do
										if
											child:IsA("BasePart")
											and (child.Name == "Ceiling_Left" or child.Name == "Ceiling_Right")
										then
											Joints.Carve(child, { archCut[index] })
										end
									end
								end
							end
						end

						if
							model
							and settings.ConnectStructures
							and (active == "Room" or active == "Corridor" or active == "ArchedCorridor")
						then
							local failed = Joints.Connect(model, settings.RoomJoin, previousModel)

							if failed > 0 then
								say(string.format("%d wall(s) could not be cut where the structures meet.", failed))
							end
						end
					end)
				then
					first = if chain then nextPoint else nil
					ventNormal, ventShift, ventHost = nil, Vector3.zero, nil
					chained = chain
					lock = nil
					heightEnd = nil
					heightMouse = nil
					riseStage = false
					NumericInput.Clear(numeric)
					Overlay.ClearGhosts(overlay)
					Overlay.HideReadout(overlay)
					say(
						if chain
							then "Click the next endpoint, or Start new chain to begin elsewhere."
							else INSTRUCTIONS[active]
					)
				end
			end
		end
	end)

	--
	-- Keys
	--

	trove:Connect(UserInputService.InputBegan, function(input, processed)
		if UserInputService:GetFocusedTextBox() or not RunService:IsEdit() then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			if session or extrude then
				perform("Cancel")
			end

			return
		end

		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			return
		end

		local key = input.KeyCode.Name
		local modal = session ~= nil or extrude ~= nil

		if session and session.Kind == "Rotate" then
			local step = if key == "Up" or key == "Right" then 90 elseif key == "Down" or key == "Left" then -90 else 0

			if step ~= 0 then
				local typed = NumericInput.Value(session.Numeric) or 0

				session.Numeric.Text = tostring(typed + step)

				return
			end
		end

		-- Typed numbers: while a modal action runs, or while a draw tool has its first point.
		if (modal or (mode ~= nil and first ~= nil)) and settings.Hotkeys then
			local entry = if session then session.Numeric elseif extrude then extrude.numeric else numeric

			if NumericInput.Press(entry, key) then
				return
			end
		end

		local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
			or UserInputService:IsKeyDown(Enum.KeyCode.LeftMeta)
		local alt = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
		local action: string? = Keymap.Resolve(key, shift, ctrl, alt, modal or mode ~= nil or armed ~= nil)

		if not action then
			return
		end

		local starts = action == "Extrude"
			or action == "Grab"
			or action == "Rotate"
			or action == "Scale"
			or action == "Duplicate"
			or action == "NextTab"
			or action == "PrevTab"
			or action == "ShowHotkeys"
			or action == "TogglePastel"
			or action == "ToggleGrid"
			or action == "TogglePanel"
			or action == "Hide"
			or action == "Unhide"
			or action == "ToggleHiddenView"
			or action == "FlipArm"
			or action == "Rotate90Arm"
			or string.sub(action, 1, 5) == "Tool:"
			or string.sub(action, 1, 7) == "Option:"

		local turnsStamp = action == "Rotate" and mode == "Place"

		if starts and (processed or modal) and not turnsStamp then
			if string.sub(action, 1, 5) == "Tool:" then
				say(
					`Key {key} is {action}, but it was ignored: Studio took the key = {processed}, a tool action is running = {modal}.`
				)
			end

			return
		end

		if not settings.Hotkeys and not ALWAYS_ON[action] and not turnsStamp then
			if string.sub(action, 1, 5) == "Tool:" then
				say(`Key {key} is {action}, but Blender hotkeys are switched off in Settings.`)
			end

			return
		end

		if not modal and not mode and not armed and not picking and (action == "Cancel" or action == "Confirm") then
			if action == "Confirm" and lastMode and not processed then
				setMode(lastMode)
			end

			return
		end

		perform(action)
	end)

	trove:Connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and extendDrag then
			task.defer(finishExtension)
		end
	end)

	trove:Connect(plugin.Deactivation, function()
		Overlay.HideBar(overlay)
		finishSession(false)
		cancelExtrude()
		mode = nil
		extendDrag = nil
		extendHover = false
		overlay.FaceHandles.Visible = false
		overlay.FaceHandles.Adornee = nil
		resetPoint()
		panel.Refresh()
	end)

	local elapsed = 0

	local cameraLight: Part? = nil
	local suspended = false
	local myId = (function(): number
		local ok, id = pcall(function()
			return game:GetService("StudioService"):GetUserId()
		end)

		return if ok and type(id) == "number" then id else 0
	end)()

	trove:Add(function()
		if cameraLight then
			cameraLight:Destroy()
		end
	end)

	--[[
		Keeps a point light on the editor camera while Camera light is on. It lives under the camera, so it is never saved into the place.
	]]
	local function syncCameraLight()
		local camera = workspace.CurrentCamera

		if suspended or not settings.CameraLight or not camera or not RunService:IsEdit() then
			if cameraLight then
				cameraLight:Destroy()
				cameraLight = nil
			end

			return
		end

		if not cameraLight or not cameraLight.Parent then
			local holder = Instance.new("Part")

			holder.Name = "VluxyBT_CameraLight"
			holder.Size = Vector3.one * 0.2
			holder.Transparency = 1
			holder.Anchored = true
			holder.CanCollide = false
			holder.CanQuery = false
			holder.CanTouch = false
			holder.Locked = true
			holder.Parent = camera

			local light = Instance.new("PointLight")

			light.Shadows = false
			light.Parent = holder
			cameraLight = holder
		end

		local holder = cameraLight :: Part
		local light = holder:FindFirstChildOfClass("PointLight")

		holder.CFrame = camera.CFrame

		if light then
			light.Range = settings.CameraLightRange
			light.Brightness = settings.CameraLightBrightness
		end
	end

	trove:Connect(RunService.Heartbeat, function(dt)
		Overlay.PositionReadout(overlay)
		syncCameraLight()

		if session or extrude then
			local ok, err = pcall((if session then updateSession else updateExtrude) :: any)

			if not ok then
				stop()
				say("Stopped: " .. tostring(err))
				warn(err)
			end
		end

		if picking then
			local hit = hitSurface()
			local target = if hit then folderOf(hit.Instance) else nil

			if target ~= hoverFolder then
				hoverFolder = target
				redrawBoxes()
			end
		end

		boxClock += dt

		if boxClock >= 1 then
			boxClock = 0

			if folder or pendingFolder or hoverFolder then
				redrawBoxes()
			else
				Overlay.ClearBox(overlay, "Working")
				Overlay.ClearBox(overlay, "Pending")
				Overlay.ClearBox(overlay, "Hover")
			end
		end

		elapsed += dt

		if elapsed < UPDATE_INTERVAL then
			return
		end

		elapsed = 0

		if folder and not folder:IsDescendantOf(workspace) then
			folder = nil
			Geometry.SetScope(nil)
			stop()
			redrawBoxes()
			panel.Refresh()
			say("The working folder is gone. Pick another one to keep working.")
		end

		if not RunService:IsEdit() then
			if mode or session or extrude then
				stop()
			end

			return
		end

		if mode then
			local ok, err = pcall(update :: any)

			if not ok then
				stop()
				say("Preview stopped: " .. tostring(err))
				warn(err)
			end
		end
	end)

	for _, object in workspace:GetDescendants() do
		if
			object:IsA("Folder")
			and (object:GetAttribute(FOLDER_ATTRIBUTE) == true or object:GetAttribute(OLD_FOLDER_ATTRIBUTE) == true)
		then
			setFolder(object)

			break
		end
	end

	--[[
		@param on boolean

		Records in a Workspace attribute that this user has the plugin open, with the time, so other users can tell the plugin is in use.
	]]
	local function markPresent(on: boolean)
		if RunService:IsEdit() then
			workspace:SetAttribute(PRESENCE_PREFIX .. myId, if on then os.time() else nil)
		end
	end

	--[[
		@return boolean -- whether another user has had the plugin open within the last minute
	]]
	local function othersPresent(): boolean
		local mine = PRESENCE_PREFIX .. myId

		for name, stamp in workspace:GetAttributes() do
			if
				string.sub(name, 1, #PRESENCE_PREFIX) == PRESENCE_PREFIX
				and name ~= mine
				and type(stamp) == "number"
				and math.abs(os.time() - stamp) < PRESENCE_TIMEOUT
			then
				return true
			end
		end

		return false
	end

	--[[
		Puts the place back to normal while the plugin is not in use: the surface grid and pastel colors come off, hidden parts are shown again and the camera light goes out. The choices are remembered, so Resume brings them back.
	]]
	local function suspend()
		stop()
		suspended = true
		syncCameraLight()
		markPresent(false)

		if othersPresent() then
			return
		end

		Hidden.UnhideAll(hidden)

		quiet = true

		if colors.On then
			Colors.Set(colors, false)
		end

		if surfaceGrid.On then
			SurfaceGrid.Set(surfaceGrid, false)
		end

		quiet = false
	end

	--[[
		Puts back the pastel colors and the surface grid that Suspend took off, if they were on.
	]]
	local function resume()
		suspended = false
		markPresent(true)

		if folder then
			if settings.AutoPastel and not colors.On then
				Colors.Set(colors, true)
			end

			if settings.AutoGrid and not surfaceGrid.On then
				SurfaceGrid.Set(surfaceGrid, true)
			end
		end
	end

	local alive = true

	trove:Add(function()
		alive = false
	end)

	task.spawn(function()
		while alive do
			if widget.Enabled then
				markPresent(true)
			end

			task.wait(PRESENCE_INTERVAL)
		end
	end)

	return {
		Stop = function()
			stop()
		end,
		Suspend = suspend,
		Resume = resume,
		TogglePastel = function()
			perform("TogglePastel")
		end,
		ToggleGrid = function()
			perform("ToggleGrid")
		end,
		PastelOn = function()
			return colors.On
		end,
		GridOn = function()
			return surfaceGrid.On
		end,
		Destroy = function()
			save()
			suspend()

			if not othersPresent() then
				Colors.RestoreOnUnload(colors)
			end
		end,
	}
end

return Controller
