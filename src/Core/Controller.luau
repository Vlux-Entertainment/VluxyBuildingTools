--!strict

--[=[
	The brain of the plugin: owns the active tool, turns mouse and key input into previews and
	builds, and runs the Blender-style modal actions (extrude, grab, rotate, scale) with their
	axis locks and typed numbers. Every connection goes into the Trove it is given.

	@class Controller
]=]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local UserInputService = game:GetService("UserInputService")

local Arrange = require("./Arrange")
local AxisLock = require("../Pure/AxisLock")
local Builders = require("./Builders")
local Colors = require("./Colors")
local Geometry = require("./Geometry")
local Hidden = require("./Hidden")
local Keymap = require("../Pure/Keymap")
local NumericInput = require("../Pure/NumericInput")
local Overlay = require("./Overlay")
local Panel = require("../Ui/Panel")
local Settings = require("../Pure/Settings")
local Snap = require("../Pure/Snap")
local SurfaceGrid = require("./SurfaceGrid")
local Tools = require("../Pure/Tools")
local Transform = require("./Transform")
local Trove = require("../Packages/Trove")

type Spec = Geometry.Spec

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
	TogglePastel: () -> (),
	ToggleGrid: () -> (),
	PastelOn: () -> boolean,
	GridOn: () -> boolean,
	Destroy: () -> (),
}

local SETTINGS_KEY = "VluxBlockoutSettings_v2"
local UPDATE_INTERVAL = 0.05
local MAX_LENGTH = 2048
local MAX_STAMP_PARTS = 600

local INSTRUCTIONS: { [string]: string } = {
	Wall = "Click start and end points. Keep clicking to connect walls. Enter starts a new chain; Esc exits. X / Y / Z locks the drag.",
	Corridor = "Click a corridor start and end. Continue clicking for connected segments. Joints may overlap at bends.",
	Room = "Click two opposite corners. Elevation is the finished floor height.",
	Block = "Click two opposite footprint corners. Press Y to drag it up, or X / Z to drag it along that axis; type a number for an exact size.",
	Stairs = "Click the first step and the end of the stair run. Length is drawn; Height sets the total rise.",
	Ramp = "Click the bottom and top footprint point. Drag distance sets length; Height sets the rise.",
	Arch = "Click the two inner edges at ground level. Height is the arch clearance; Depth is the frame depth.",
	ArchOpening = "Hover over a plain wall and click to cut an arched doorway. Adjust width/height below.",
	Opening = "Click an undecorated rectangular wall. Opening is centered on the cursor horizontally; sill sets its height.",
	Extend = "Click a block to select it, then drag a green face handle OUTWARD. Release to add a connected block.",
	Place = "Select an object first. Click surfaces to stamp copies. R rotates the preview 90 degrees.",
	Measure = "Click two surface points. A distance label stays in the viewport. Esc clears it.",
}

local HEIGHT_MODES: { [string]: boolean } = {
	Wall = true,
	Corridor = true,
	Room = true,
}

local DRAW_MODES: { [string]: boolean } = {
	Wall = true,
	Corridor = true,
	Room = true,
	Block = true,
	Stairs = true,
	Ramp = true,
	Arch = true,
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
	local current: Vector3? = nil
	local heightEnd: Vector3? = nil
	local lock: AxisLock.Lock? = nil
	local numeric = NumericInput.new()
	local source: Builders.Source? = nil
	local sourceRoots: { Instance } = {}
	local previewSpecs: { Spec } = {}
	local previewValid = false
	local measurement: { a: Vector3, b: Vector3 }? = nil
	local openingTarget: BasePart? = nil
	local placementCF: CFrame? = nil
	local extendDrag: ExtendDrag? = nil
	local extendHover = false
	local extrude: Extrude? = nil
	local session: Transform.Session? = nil
	local sessionRecording: string? = nil
	local armed: string? = nil
	local folder: Instance? = nil
	local pendingFolder: Instance? = nil
	local picking = false
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

		local ok, err = pcall(callback :: any)

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

	local function snap(value: number): number
		return Snap.Round(value, settings.Grid)
	end

	local function resetPoint()
		first, current = nil, nil
		previewSpecs, previewValid = {}, false
		lock = nil
		heightEnd = nil
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

		return Vector3.new(snap(point.X), y, snap(point.Z))
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
		@return Vector3? -- for rooms and corridors, the snapped spot on the top of whatever the cursor
			is over, raised by the floor thickness so the floor rests on top of it

		A floor drawn from this point sits on the object instead of sinking into it.
	]]
	local function floorPoint(): Vector3?
		if mode ~= "Room" and mode ~= "Corridor" then
			return nil
		end

		local hit = hitSurface()

		if not hit or hit.Normal.Y < 0.7 then
			return nil
		end

		return Vector3.new(snap(hit.Position.X), hit.Position.Y + settings.Floor, snap(hit.Position.Z))
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
		elseif mode == "Opening" or mode == "ArchOpening" then
			out, message, openingTarget = Builders.Opening(settings, scopedHit(), mode == "ArchOpening")
		elseif mode == "Place" then
			out, message, placementCF = Builders.Place(settings, hitSurface(), source)
		elseif mode == "Measure" then
			local hit = hitSurface()

			current = if hit then hit.Position else horizontalPoint(settings.Elevation)

			if current and first then
				Overlay.DrawMeasurement(overlay, first, current)
				message = "Click to keep this measurement. The number stays in the viewport."
			elseif measurement then
				Overlay.DrawMeasurement(overlay, measurement.a, measurement.b)
			end
		else
			local origin = first
			local height: number? = nil

			if origin and lock and heightEnd and lock.Axis == "Y" and not lock.Plane then
				local top = lockedPoint(heightEnd, lock)

				if top then
					height = math.max(settings.Grid, math.abs(top.Y - origin.Y))
				end

				current = heightEnd
			elseif origin and lock then
				current = lockedPoint(origin, lock)
			elseif origin then
				current = horizontalPoint(origin.Y)
			else
				current = floorPoint() or horizontalPoint(settings.Elevation)
			end

			local point = current

			if point and settings.ShowGrid and not lock then
				Overlay.DrawPlaneGrid(
					overlay,
					Vector3.new(snap(point.X), point.Y, snap(point.Z)),
					math.max(0.05, settings.Grid)
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

				local drawn = settings

				if height then
					drawn = table.clone(settings)
					drawn.Height = height
				end

				if mode == "Room" then
					out = Builders.Room(drawn, origin, b)
				elseif mode == "Block" then
					out = Builders.Block(settings, origin, b, lock)
				elseif mode == "Wall" or mode == "Corridor" then
					out = Builders.Path(drawn, origin, b, mode == "Corridor")
				elseif mode == "Stairs" or mode == "Ramp" then
					out = Builders.Stairs(settings, origin, b, mode == "Ramp")
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
					elseif mode == "Arch" then
						text = string.format("Span %.1f  |  Height %.1f", d.Magnitude, settings.ArchHeight)
					elseif mode == "Stairs" then
						text = string.format("Run %.1f  |  Rise %.1f", d.Magnitude, settings.StairHeight)
					elseif mode == "Ramp" then
						text = string.format("Run %.1f  |  Rise %.1f", d.Magnitude, settings.RampHeight)
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
		previewValid = #out > 0 and (first ~= nil or mode == "Opening" or mode == "ArchOpening" or mode == "Place")
		Overlay.DrawGhosts(overlay, out)

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

		local text, position = Transform.Update(active, settings.Grid, mouseLocation(), mouse.UnitRay, lookVector())

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
			local roots = Geometry.SelectedRoots()
			local parts = Geometry.PartsOf(roots)

			if #parts == 0 then
				return say("Select an object first, then choose Stamp copies.")
			elseif #parts > MAX_STAMP_PARTS then
				return say("Stamp copies supports up to 600 Parts in the source selection.")
			end

			for _, root in roots do
				if not root.Archivable then
					return say("Enable Archivable on each selected root before copying.")
				end
			end

			local pivot, size = Geometry.Bounds(parts)

			sourceRoots = roots
			source = { Parts = parts, Pivot = pivot, Size = size }
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
			else
				heightEnd = nil
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
			if armed then
				armed = nil
				say("Cancelled.")
			elseif session then
				finishSession(false)
			elseif extrude then
				cancelExtrude()
				say("Extrude cancelled.")
			elseif mode then
				stop()
				say("Tool stopped. Your completed builds stay in the map.")
			end
		elseif action == "Confirm" then
			if session then
				finishSession(true)
			elseif extrude then
				confirmExtrude()
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
		Starts picking a folder. A Folder selected before this is ignored; click one in the viewport or select one now.
	]]
	local function startPicking()
		stop()
		picking = true
		pendingFolder = nil
		hoverFolder = nil

		redrawBoxes()
		panel.Refresh()
		say("Click a Folder in the viewport, or select one in the Explorer.")
	end

	--[[
		Gives up picking and clears the outlines that picking drew.
	]]
	local function cancelPicking()
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
			Colors.Set(colors, false)
		end

		stop()
		folder = chosen
		Geometry.SetScope(chosen)
		redrawBoxes()
		panel.Refresh()

		if chosen then
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
		GetScope = function()
			return folder
		end,
		GetSize = function()
			return settings.GridTextureSize
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
			UseSelectedFloor = guarded(arrange.UseSelectedFloor),
			RepeatCopies = guarded(arrange.RepeatCopies),
			MirrorCopy = guarded(arrange.MirrorCopy),
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

		if active == "Opening" or active == "ArchOpening" then
			if not previewValid then
				return
			end

			local target = openingTarget
			local specs = previewSpecs

			edit(if active == "ArchOpening" then "Create arched doorway" else "Create opening", function()
				Geometry.Materialize(specs, if active == "ArchOpening" then "Arched_Doorway" else "Wall_Opening")
				assert(target and target.Parent, "Wall no longer exists")
				target:Destroy()
			end)
		elseif active == "Place" then
			local target = placementCF
			local pivot = source and source.Pivot

			if not previewValid or not target or not pivot then
				return
			end

			edit("Stamp copy", function()
				Selection:Set(Arrange.CloneRoots(sourceRoots, function(cf)
					return target * pivot:ToObjectSpace(cf)
				end))
			end)
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
				NumericInput.Clear(numeric)
				say("Move to the other point. Click to build. Press X, Y or Z to lock an axis.")
			elseif previewValid then
				local chain = active == "Wall" or active == "Corridor"
				local nextPoint = current
				local specs = previewSpecs

				if edit("Build " .. active, function()
					Geometry.Materialize(specs, "Vlux_" .. active)
				end) then
					first = if chain then nextPoint else nil
					lock = nil
					heightEnd = nil
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

		local turnsStamp = action == "Rotate" and mode == "Place"

		if starts and (processed or modal) and not turnsStamp then
			return
		end

		if not settings.Hotkeys and not ALWAYS_ON[action] and not turnsStamp then
			return
		end

		if not modal and not mode and not armed and (action == "Cancel" or action == "Confirm") then
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

	trove:Connect(RunService.Heartbeat, function(dt)
		Overlay.PositionReadout(overlay)

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

	return {
		Stop = function()
			stop()
		end,
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
			stop()
			save()
			Hidden.UnhideAll(hidden)
			Colors.RestoreOnUnload(colors)
		end,
	}
end

return Controller
