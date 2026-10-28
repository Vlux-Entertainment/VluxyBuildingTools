--!strict

--[=[
	Measure: a line, a square, a box, a circle or a ball, picked on the Build tab. Each shows its
	dimensions and its length, area or volume. A finished measurement stays in the viewport as a
	guide whose corners, edge middles and centres every tool snaps to, until Esc clears them.

	Line: two points. Square: two opposite corners, level with the first. Box: a square, then its
	height. Circle: the centre, then a point on the rim, level with it. Ball: the centre, then a
	point on its surface.

	Pressing on a part in the working folder and moving the mouse drags it instead: the part, or
	the model it belongs to, slides along the level, snapped to the grid and to the measuring
	guides, as one undo step. A press without moving still measures, on release.

	@class Measure
]=]

local Selection = game:GetService("Selection")
local UserInputService = game:GetService("UserInputService")

local AxisLock = require("../Pure/AxisLock")
local Common = require("./Common")
local Cursor = require("../Services/Cursor")
local Geometry = require("../Core/Geometry")
local Guides = require("../Core/Guides")
local MeasureText = require("../Pure/MeasureText")
local Overlay = require("../Core/Overlay")
local Transform = require("../Core/Transform")
local Types = require("./Types")

type Context = Types.Context
type Guide = Guides.Guide

--[=[
	@interface MeasureState
	@within Measure
	.First Vector3? -- the first point of the measurement being made
	.Second Vector3? -- a box's far corner, once picked, while its height is set
	.Current Vector3? -- the point under the cursor
	.Shown { Guide: Guide, Text: string, At: Vector3 }? -- what the preview would keep
	.Pressed { Mouse: Vector2, Root: Instance }? -- a press on a part that becomes a drag if the mouse moves
	.Drag Transform.Session? -- the drag under way
	.Lock AxisLock.Lock? -- the axis the line is held to, while a line is being measured
]=]
type MeasureState = {
	First: Vector3?,
	Second: Vector3?,
	Current: Vector3?,
	Shown: { Guide: Guide, Text: string, At: Vector3 }?,
	Pressed: { Mouse: Vector2, Root: Instance }?,
	Drag: Transform.Session?,
	Lock: AxisLock.Lock?,
}

local SEGMENTS = 48
local DRAG_PIXELS = 6

--[[
	@param part Instance
	@return Instance? -- what a press on the part drags: the outermost model it is in below the working folder, else the part; nil outside the working folder or for a locked part
]]
local function dragRoot(part: Instance): Instance?
	local scope = Geometry.GetScope()

	if not part:IsA("BasePart") or part:IsA("Terrain") or part.Locked or (scope and not part:IsDescendantOf(scope)) then
		return nil
	end

	local root: Instance = part
	local parent = part.Parent

	while parent and parent ~= scope and parent ~= workspace and parent:IsA("Model") do
		root = parent
		parent = parent.Parent
	end

	return root
end

--[[
	@param root Instance
	@return { BasePart } -- every Part that moves with it
]]
local function partsOf(root: Instance): { BasePart }
	if root:IsA("BasePart") then
		return { root }
	end

	local out: { BasePart } = {}

	for _, child in root:GetDescendants() do
		if child:IsA("BasePart") then
			table.insert(out, child)
		end
	end

	return out
end

--[[
	@param ctx Context
	@param drag Transform.Session
	Moves the dragged parts to follow the mouse, along the level, snapped to the grid and guides.
]]
local function follow(ctx: Context, drag: Transform.Session)
	local cursor = ctx.Cursor
	local snaps = ctx.Settings.SnapToParts and ctx.Settings.GrabGuides and not Cursor.Fine()
	local text, at = Transform.Update(
		drag,
		Cursor.Grid(cursor),
		Cursor.Screen(),
		Cursor.Ray(cursor),
		Cursor.Look(),
		if snaps then math.max(3, ctx.Settings.SnapRadius * 3) else nil
	)

	Overlay.Readout(ctx.Overlay, at, text)
end

--[[
	@param ctx Context
	@param state MeasureState
	Ends the drag: puts the parts back and moves them again as one undo step.
]]
local function drop(ctx: Context, state: MeasureState)
	local drag = state.Drag

	state.Drag, state.Pressed = nil, nil

	if not drag then
		return
	end

	local delta = Transform.Delta(drag)

	Transform.Restore(drag)
	Overlay.HideReadout(ctx.Overlay)

	if delta.Magnitude > 1e-4 then
		ctx.Edit("Drag", function()
			Transform.Apply(drag, delta)
		end)
		ctx.Sound("StudioDrag")
	end
end

--[[
	@param ctx Context
	@return Vector3? -- the point under the cursor: a guide point or part corner when one is close, else the grid point on the surface
]]
local function pick(ctx: Context): Vector3?
	local cursor = ctx.Cursor
	local hit = Cursor.Hit(cursor)
	local current = if hit then hit.Position else Cursor.Horizontal(cursor, ctx.Settings.Elevation)
	local corner = if current and ctx.Settings.SnapToParts and not Cursor.Fine() then Cursor.Corner(current) else nil

	if corner then
		cursor.Mark = corner

		return corner
	elseif current then
		return Common.SnapOnSurface(
			current,
			if hit then hit.Normal else Vector3.yAxis,
			Common.RoundTo(Cursor.Grid(cursor))
		)
	end

	return nil
end

--[[
	@param ctx Context
	@param level number
	@return Vector3? -- the point under the cursor on the level plane, snapped to guides, corners or the grid
]]
local function onLevel(ctx: Context, level: number): Vector3?
	local point = pick(ctx)

	if point and math.abs(point.Y - level) < 0.05 then
		return point
	end

	local flat = Cursor.Horizontal(ctx.Cursor, level)

	return if flat then Vector3.new(flat.X, level, flat.Z) else nil
end

--[[
	@param low Vector3 -- one corner of a level box
	@param high Vector3 -- the opposite corner
	@return Guide -- the box's twelve edges, with its corners, edge middles and centre as points; a flat box draws only its outline
]]
local function boxGuide(low: Vector3, high: Vector3): Guide
	local lo, hi = low:Min(high), low:Max(high)
	local flat = hi.Y - lo.Y < 1e-3
	local corners: { Vector3 } = {}
	local lines: { { Vector3 } } = {}
	local points: { Vector3 } = {}

	for _, y in (if flat then { lo.Y } else { lo.Y, hi.Y }) :: { number } do
		local ring = {
			Vector3.new(lo.X, y, lo.Z),
			Vector3.new(hi.X, y, lo.Z),
			Vector3.new(hi.X, y, hi.Z),
			Vector3.new(lo.X, y, hi.Z),
		}

		for index, corner in ring do
			local nextCorner = ring[index % 4 + 1]

			table.insert(corners, corner)
			table.insert(lines, { corner, nextCorner })
			table.insert(points, corner)
			table.insert(points, (corner + nextCorner) / 2)
		end
	end

	if not flat then
		for index = 1, 4 do
			table.insert(lines, { corners[index], corners[index + 4] })
			table.insert(points, (corners[index] + corners[index + 4]) / 2)
		end
	end

	table.insert(points, (lo + hi) / 2)

	local size = hi - lo

	return {
		Lines = lines,
		Points = points,
		Fill = {
			Shape = "Box",
			CFrame = CFrame.new((lo + hi) / 2),
			Size = Vector3.new(size.X, math.max(size.Y, 0.05), size.Z),
		},
	}
end

--[[
	@param center Vector3
	@param radius number
	@param u Vector3 -- one direction in the circle's plane
	@param v Vector3 -- the other
	@return { { Vector3 } } -- the circle as short lines
]]
local function ring(center: Vector3, radius: number, u: Vector3, v: Vector3): { { Vector3 } }
	local out: { { Vector3 } } = {}

	for i = 0, SEGMENTS - 1 do
		local a, b = i / SEGMENTS * 2 * math.pi, (i + 1) / SEGMENTS * 2 * math.pi

		table.insert(out, {
			center + (u * math.cos(a) + v * math.sin(a)) * radius,
			center + (u * math.cos(b) + v * math.sin(b)) * radius,
		})
	end

	return out
end

--[[
	@param ctx Context
	@param state MeasureState
	@return { Guide: Guide, Text: string, At: Vector3 }? -- the measurement from the first point to the cursor, for the shape picked
	@return string -- what to do next
]]
local function measure(ctx: Context, state: MeasureState): ({ Guide: Guide, Text: string, At: Vector3 }?, string)
	local shape = ctx.Settings.MeasureShape
	local first = state.First :: Vector3

	if shape == "Square" or shape == "Box" then
		local second = state.Second

		if shape == "Box" and second then
			local along = Cursor.AlongLine(ctx.Cursor, second, Vector3.yAxis) or 0
			local height = Cursor.Snap(ctx.Cursor, along)
			local top = second + Vector3.new(0, height, 0)
			local size = (top - first)

			return {
				Guide = boxGuide(first, top),
				Text = MeasureText.Box(math.abs(size.X), math.abs(size.Z), math.abs(size.Y)),
				At = (first + top) / 2,
			},
				"Move up or down for the height, then click."
		end

		local corner = onLevel(ctx, first.Y)

		if not corner then
			return nil, "Point at the level of the first corner."
		end

		return {
			Guide = boxGuide(first, corner),
			Text = MeasureText.Square(math.abs(corner.X - first.X), math.abs(corner.Z - first.Z)),
			At = (first + corner) / 2,
		},
			if shape == "Box" then "Click the far corner, then set the height." else "Click to keep this square."
	elseif shape == "Circle" then
		local rim = onLevel(ctx, first.Y)

		if not rim then
			return nil, "Point at the level of the centre."
		end

		local radius = Vector3.new(rim.X - first.X, 0, rim.Z - first.Z).Magnitude
		local points = { first }

		for _, offset in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
			table.insert(points, first + offset * radius)
		end

		return {
			Guide = {
				Lines = ring(first, radius, Vector3.xAxis, Vector3.zAxis),
				Points = points,
				Fill = { Shape = "Disc", CFrame = CFrame.new(first), Size = Vector3.one * radius * 2 },
			},
			Text = MeasureText.Circle(radius),
			At = first,
		},
			"Click to keep this circle."
	elseif shape == "Ball" then
		local surface = state.Current

		if not surface then
			return nil, "Point at the ball's surface."
		end

		local radius = (surface - first).Magnitude
		local lines: { { Vector3 } } = {}
		local points = { first }

		for _, plane in
			{ { Vector3.xAxis, Vector3.zAxis }, { Vector3.xAxis, Vector3.yAxis }, { Vector3.yAxis, Vector3.zAxis } }
		do
			for _, line in ring(first, radius, plane[1], plane[2]) do
				table.insert(lines, line)
			end
		end

		for _, offset in { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis } do
			table.insert(points, first + offset * radius)
			table.insert(points, first - offset * radius)
		end

		return {
			Guide = {
				Lines = lines,
				Points = points,
				Fill = { Shape = "Ball", CFrame = CFrame.new(first), Size = Vector3.one * radius * 2 },
			},
			Text = MeasureText.Ball(radius),
			At = first,
		},
			"Click to keep this ball."
	end

	local current = state.Current

	if not current then
		return nil, "Point at the second point."
	end

	local d = current - first

	return {
		Guide = { Lines = { { first, current } }, Points = { first, current, (first + current) / 2 } },
		Text = MeasureText.Line(d.X, d.Y, d.Z),
		At = (first + current) / 2,
	},
		"Click to keep this measurement."
end

--[[
	@param ctx Context
	Redraws the kept guides.
]]
local function redraw(ctx: Context)
	Overlay.DrawGuides(ctx.Overlay, Guides.All())
end

--[[
	@param ctx Context
	@param state MeasureState
	A measuring click: starts a measurement, picks a box's far corner, or keeps the measurement.
]]
local function measureClick(ctx: Context, state: MeasureState)
	local current = state.Current

	if not state.First then
		if current then
			state.First = current
			ctx.Say(
				if ctx.Settings.MeasureShape == "Circle" or ctx.Settings.MeasureShape == "Ball"
					then "Click the rim."
					else "Click the second point."
			)
		end

		return
	end

	local shown = state.Shown

	if not shown then
		return
	end

	if ctx.Settings.MeasureShape == "Box" and not state.Second then
		local corner = onLevel(ctx, (state.First :: Vector3).Y)

		state.Second = corner

		return
	end

	Guides.Add(shown.Guide)
	redraw(ctx)
	state.First, state.Second, state.Lock = nil, nil, nil
	Overlay.ClearMeasurement(ctx.Overlay)
	ctx.Say((string.gsub(shown.Text, "\n", "; ")) .. ". Kept as a guide; Esc clears guides.")
end

local tool: Types.Tool = {
	Id = "Measure",
	Locks = true,
	Begin = function(ctx: Context): MeasureState
		redraw(ctx)

		return { First = nil, Second = nil, Current = nil, Shown = nil, Lock = nil }
	end,
	Preview = function(ctx: Context, state: MeasureState): Types.Preview?
		local held = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		local pressed, drag = state.Pressed, state.Drag

		if drag and not held then
			drop(ctx, state)
		elseif drag then
			follow(ctx, drag)

			return Common.Empty("Release to drop it; Shift moves freely.")
		elseif pressed and held and (Cursor.Screen() - pressed.Mouse).Magnitude > DRAG_PIXELS then
			local cursor = ctx.Cursor
			local parts = partsOf(pressed.Root)

			if #parts > 0 then
				local session = Transform.Begin("Grab", parts, pressed.Mouse, Cursor.Ray(cursor), Cursor.Look())

				Transform.SetLock(session, { Axis = "Y", Plane = true }, Cursor.Ray(cursor), Cursor.Look())
				state.Drag = session
				Selection:Set({ pressed.Root })
				Overlay.ClearMeasurement(ctx.Overlay)
				follow(ctx, session)

				return Common.Empty("Release to drop it; Shift moves freely.")
			end
		end

		state.Current = pick(ctx)
		state.Shown = nil

		local lock, first = state.Lock, state.First

		if lock and first then
			state.Current = Cursor.Locked(ctx.Cursor, first, lock, nil) or state.Current
		end

		if not state.First then
			Overlay.ClearMeasurement(ctx.Overlay)
			Overlay.HideReadout(ctx.Overlay)

			return Common.Empty()
		end

		local shown, message = measure(ctx, state)

		state.Shown = shown

		if shown then
			Overlay.DrawMeasureShape(ctx.Overlay, shown.Guide.Lines, shown.Guide.Points)
			Overlay.Readout(ctx.Overlay, shown.At, shown.Text)
		end

		return Common.Empty(message)
	end,
	Click = function(ctx: Context, state: MeasureState)
		local hit = if state.First then nil else Cursor.Hit(ctx.Cursor)
		local root = if hit then dragRoot(hit.Instance) else nil

		if root then
			state.Pressed = { Mouse = Cursor.Screen(), Root = root }

			return
		end

		measureClick(ctx, state)
	end,
	Release = function(ctx: Context, state: MeasureState)
		if state.Drag then
			drop(ctx, state)
		elseif state.Pressed then
			state.Pressed = nil
			measureClick(ctx, state)
		end
	end,
	Lock = function(ctx: Context, state: MeasureState, axis: AxisLock.Axis, plane: boolean)
		if not state.First then
			return ctx.Say("Click the first point, then press X, Y or Z to hold the line to that axis.")
		end

		if ctx.Settings.MeasureShape ~= "Line" then
			return ctx.Say("Axis lock works with the line shape.")
		end

		state.Lock = AxisLock.Toggle(state.Lock, axis, plane)
		ctx.Say(Common.LockMessage(state.Lock, axis, plane))
	end,
	Back = function(ctx: Context, state: MeasureState): string?
		local drag = state.Drag

		if drag then
			state.Drag, state.Pressed = nil, nil
			Transform.Restore(drag)
			Overlay.HideReadout(ctx.Overlay)

			return "Drag cancelled."
		elseif state.First then
			state.First, state.Second, state.Lock = nil, nil, nil
			Overlay.ClearMeasurement(ctx.Overlay)
			Overlay.HideReadout(ctx.Overlay)

			return "Measurement cancelled."
		elseif Guides.Count() > 0 then
			Guides.Clear()
			redraw(ctx)
			Overlay.HideReadout(ctx.Overlay)

			return "Guides cleared; Esc again leaves the tool."
		end

		return nil
	end,
	Finish = function(ctx: Context, state: MeasureState)
		local drag = state.Drag

		if drag then
			state.Drag = nil
			Transform.Restore(drag)
		end

		Overlay.ClearMeasurement(ctx.Overlay)
		Overlay.HideReadout(ctx.Overlay)
	end,
}

return { tool }
