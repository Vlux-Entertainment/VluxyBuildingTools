--!strict

--[=[
	The engine behind every point-to-point tool: walls, rooms, corridors, stairs, vents and the rest.

	The engine owns the drawing: the first point, the mouse point, axis locks, the Y height drag, the
	rise stage of stairs and sloped vents, typed lengths and chaining one segment onto the next. A
	shape (see `Shape`) only says what is different about it: where its points may land, what it
	builds between two points, and what to do after building. Turn a shape into a tool with
	`Engine.Tool(shape)`.

	The flow, with the state field that holds each step:

	1. Before the first click the cursor is shown where a build would start (`Current`).
	2. The first click fixes `First`. Moving the mouse previews the build from `First` to `Current`.
	3. A shape with `Rise` takes one more click: the next one fixes the run and starts the rise
	   (`Rise`), and the mouse then sets the height.
	4. The next click builds. A chaining shape keeps going from the end point (`Chained`); the last
	   segment is kept in `Previous` so the next one can join it.

	@class Engine
]=]

local AxisLock = require("../../Pure/AxisLock")
local Common = require("../Common")
local Cursor = require("../../Services/Cursor")
local Geometry = require("../../Core/Geometry")
local Joints = require("../../Core/Joints")
local NumericInput = require("../../Pure/NumericInput")
local Overlay = require("../../Core/Overlay")
local Settings = require("../../Pure/Settings")
local Shapes = require("../../Core/Builders/Shapes")
local Snapper = require("../../Core/Snapper")
local Tools = require("../../Pure/Tools")
local Types = require("../Types")

type Context = Types.Context
type Spec = Geometry.Spec

--[=[
	The last segment of a chain, kept so the next segment can join it at a bend.

	@interface Segment
	@within Engine
	.model Instance -- what the segment built
	.dir Vector3 -- its flat direction
	.strips { Shapes.Strip } -- the layers across it, which a bend lines up
]=]
export type Segment = { model: Instance, dir: Vector3, strips: { Shapes.Strip } }

--[=[
	The vent tools' extra drawing state. Vents start against surfaces and other vents, so they
	remember what they started on.

	@interface VentState
	@within Engine
	.Normal Vector3? -- the normal of the surface the run started on
	.Host Vector3? -- the direction of the vent the run started from
	.Shift Vector3 -- how far the run is pushed so it sits against its surface or host
	.HitNormal Vector3? -- the surface normal under the cursor before the first click
	.HitHost Vector3? -- the vent direction under the cursor before the first click
	.HitOwner Instance? -- the vent under the cursor before the first click
	.HitEnd Vector3? -- the way out of the open vent end under the cursor, before the first click
	.HitFace Vector3? -- the normal of the vent face under the cursor, before the first click
	.HitCorner boolean? -- whether the vent spot under the cursor is a corner, before the first click
	.Owner Instance? -- the vent the run started from
	.End Vector3? -- the way out of the open end the run started from
	.Corner boolean? -- whether the run started on a corner, so it may leave in any open direction
	.Target number? -- the floor height of the vent a slope vent is aimed at
	.TargetOwner Instance? -- that vent
	.TargetEnd Vector3? -- the way out of its open end, when the slope meets an end rather than a side
	.TargetAt Vector3? -- the middle of the vent hole a slope vent is aimed at, to check the two line up
	.Why string? -- why the aimed slope cannot be built
	.Ends { Vector3 }? -- the two duct ends of the previewed build, centered
]=]
export type VentState = {
	Normal: Vector3?,
	Host: Vector3?,
	Shift: Vector3,
	HitNormal: Vector3?,
	HitHost: Vector3?,
	HitOwner: Instance?,
	HitEnd: Vector3?,
	HitFace: Vector3?,
	HitCorner: boolean?,
	Owner: Instance?,
	End: Vector3?,
	Corner: boolean?,
	Target: number?,
	TargetOwner: Instance?,
	TargetEnd: Vector3?,
	TargetAt: Vector3?,
	Why: string?,
	Ends: { Vector3 }?,
}

--[=[
	The state of one drawing tool.

	@interface Draw
	@within Engine
]=]
export type Draw = {
	Shape: Shape,
	First: Vector3?,
	Current: Vector3?,
	Chained: boolean,
	Lock: AxisLock.Lock?,
	--[=[ Where the Y height drag started, while it runs. ]=]
	HeightEnd: Vector3?,
	--[=[ The mouse position the height drag started from. ]=]
	HeightMouse: Vector2?,
	--[=[ True during the rise stage of stairs, ramps and sloped or vertical vents. ]=]
	Rise: boolean,
	Numeric: NumericInput.NumericInput,
	Previous: Segment?,
	--[=[ The doorway under the cursor before the first click, which a corridor can start from. ]=]
	HoverDoor: Snapper.Doorway?,
	--[=[ The doorway the corridor started from. ]=]
	StartDoor: Snapper.Doorway?,
	Vent: VentState?,
	Specs: { Spec },
}

--[=[
	What the preview worked out, handed to a shape's `Build`.

	@interface Sized
	@within Engine
	.Live Settings -- the settings to build with: the fine grid while Shift is held, the dragged height, a doorway's size
	.Height number? -- the height from the Y drag or rise stage, when one runs
	.Signed number -- the same height with its sign, for parts that can go down
]=]
export type Sized = { Live: Settings.Settings, Height: number?, Signed: number }

--[=[
	What a shape's `Commit` gets after its build was placed, inside the undo step.

	@interface Built
	@within Engine
	.Placed Instance -- the Model (or loose Part) placed
	.Model Model? -- `Placed` when it is a Model
	.Segment Vector3 -- the flat vector from the first point to the end point
	.Joint Vector3 -- the first point, where the segment meets the one before it
	.Previous Segment? -- the segment before this one, if chained
]=]
export type Built = {
	Placed: Instance,
	Model: Model?,
	Segment: Vector3,
	Joint: Vector3,
	Previous: Segment?,
}

--[=[
	What makes one drawing tool different from the others. Only `Id`, `Start` and `Build` are
	required.

	@interface Shape
	@within Engine
	.Id string -- the tool mode
	.Start (ctx, draw) -> Vector3? -- the point under the cursor before the first click
	.Next ((ctx, draw, origin) -> Vector3?)? -- the point under the cursor after it; default the grid on the first point's level
	.Build (ctx, draw, a, b, sized) -> { Spec } -- what to build between two points
	.Readout ((draw, a, b, specs, sized) -> string)? -- the size label; default the length
	.Problem ((specs, draw) -> string?)? -- why nothing could be built, when `Build` returned nothing
	.Idle ((ctx, draw, point) -> { Spec }?)? -- the marker before the first click; default a small block
	.Constrain ((ctx, draw, a, b) -> (Vector3, Vector3))? -- bends the drawn points, such as a vent turning only at right angles
	.RiseOrigin ((draw, a) -> Vector3)? -- moves the first point during the rise stage
	.OnStart ((ctx, draw) -> ())? -- the first click was made
	.Commit ((ctx, draw, built) -> ())? -- runs inside the undo step after the build was placed
	.Built ((draw) -> ())? -- runs after a successful build, to clear what one segment kept
	.HeightDrag boolean? -- Y drags the height
	.Rise boolean? -- a click after the run starts a rise stage
	.Reached ((draw) -> boolean)? -- the run already has its height, so the click builds without the rise stage
	.Shaft boolean? -- the first click goes straight to the rise stage
	.Chain boolean? -- keep drawing from the end point after a build
	.Loose boolean? -- place loose Parts instead of one Model
	.Joins boolean? -- preview where the build joins rooms and corridors
	.Vents boolean? -- keeps a `VentState` in `draw.Vent`
]=]
export type Shape = {
	Id: string,
	Start: (ctx: Context, draw: Draw) -> Vector3?,
	Next: ((ctx: Context, draw: Draw, origin: Vector3) -> Vector3?)?,
	Build: (ctx: Context, draw: Draw, a: Vector3, b: Vector3, sized: Sized) -> { Spec },
	Readout: ((draw: Draw, a: Vector3, b: Vector3, specs: { Spec }, sized: Sized) -> string)?,
	Problem: ((specs: { Spec }, draw: Draw) -> string?)?,
	Idle: ((ctx: Context, draw: Draw, point: Vector3) -> { Spec }?)?,
	Constrain: ((ctx: Context, draw: Draw, a: Vector3, b: Vector3) -> (Vector3, Vector3))?,
	RiseOrigin: ((draw: Draw, a: Vector3) -> Vector3)?,
	OnStart: ((ctx: Context, draw: Draw) -> ())?,
	Commit: ((ctx: Context, draw: Draw, built: Built) -> ())?,
	Built: ((draw: Draw) -> ())?,
	HeightDrag: boolean?,
	Rise: boolean?,
	Reached: ((draw: Draw) -> boolean)?,
	Shaft: boolean?,
	Chain: boolean?,
	Loose: boolean?,
	Joins: boolean?,
	Vents: boolean?,
}

local Engine = {}

--[[
	@param shape Shape
	@return Draw -- a drawing with nothing clicked yet
]]
local function fresh(shape: Shape): Draw
	return {
		Shape = shape,
		First = nil,
		Current = nil,
		Chained = false,
		Lock = nil,
		HeightEnd = nil,
		HeightMouse = nil,
		Rise = false,
		Numeric = NumericInput.new(),
		Previous = nil,
		HoverDoor = nil,
		StartDoor = nil,
		Vent = if shape.Vents then { Shift = Vector3.zero } :: VentState else nil,
		Specs = {},
	}
end

--[[
	@param ctx Context
	@param draw Draw

	Drops every point and lock, so the next click starts a new drawing.
]]
local function reset(ctx: Context, draw: Draw)
	local blank = fresh(draw.Shape)

	draw.First, draw.Current, draw.Chained = nil, nil, false
	draw.Lock, draw.HeightEnd, draw.HeightMouse, draw.Rise = nil, nil, nil, false
	draw.Numeric = blank.Numeric
	draw.Previous, draw.HoverDoor, draw.StartDoor = nil, nil, nil
	draw.Vent = blank.Vent
	draw.Specs = {}

	Overlay.ClearGhosts(ctx.Overlay)
	Overlay.HideReadout(ctx.Overlay)
end

--[[
	@param draw Draw
	@param current Vector3

	Starts the stage where the mouse sets the height, as if Y were pressed.
]]
local function startRise(draw: Draw, current: Vector3)
	draw.Rise = true
	draw.HeightEnd = current
	draw.HeightMouse = Cursor.Screen()
	draw.Lock = AxisLock.Toggle(nil, "Y", false)
end

--[[
	@param ctx Context
	@param draw Draw
	@param origin Vector3
	@return number? -- the height from the Y drag, never below one grid step
	@return number -- the same height with its sign
]]
local function dragHeight(ctx: Context, draw: Draw, origin: Vector3): (number?, number)
	local cursor = ctx.Cursor
	local camera = workspace.CurrentCamera
	local start = draw.HeightMouse

	if camera and start and math.abs(camera.CFrame.LookVector.Y) > 0.8 then
		return Cursor.ScreenHeight(cursor, origin, start), Cursor.ScreenHeight(cursor, origin, start, true)
	end

	local top = Cursor.Locked(cursor, draw.HeightEnd :: Vector3, draw.Lock :: AxisLock.Lock, draw.Numeric)

	if top then
		return math.max(Cursor.Grid(cursor), math.abs(top.Y - origin.Y)), top.Y - origin.Y
	end

	return nil, 0
end

--[[
	@param draw Draw
	@param a Vector3
	@param b Vector3
	@param sized Sized
	@return string -- the default size label: the length, and the height while one is dragged
]]
local function lengthReadout(_draw: Draw, a: Vector3, b: Vector3, _specs: { Spec }, sized: Sized): string
	local length = (b - a).Magnitude

	return if sized.Height
		then string.format("%.1f studs  |  Height %.1f", length, sized.Height)
		else string.format("%.1f studs", length)
end

--[=[
	@param ctx Context
	@param draw Draw
	@return Preview -- the build from the first point to the mouse, or the start marker before the first click
]=]
function Engine.Preview(ctx: Context, draw: Draw): Types.Preview
	local shape = draw.Shape
	local cursor = ctx.Cursor
	local settings = ctx.Settings
	local live = Common.Live(ctx)
	local out: { Spec } = {}
	local message: string? = nil
	local origin = draw.First
	local lock = draw.Lock
	local height: number? = nil
	local signed = 0

	if origin and draw.Rise and shape.RiseOrigin then
		origin = shape.RiseOrigin(draw, origin)
	end

	if origin and lock and draw.HeightEnd and lock.Axis == "Y" and not lock.Plane then
		height, signed = dragHeight(ctx, draw, origin)
		draw.Current = draw.HeightEnd
	elseif origin and lock then
		draw.Current = Cursor.Locked(cursor, origin, lock, draw.Numeric)
	elseif origin then
		draw.Current = if shape.Next then shape.Next(ctx, draw, origin) else nil
		draw.Current = draw.Current or Cursor.Horizontal(cursor, origin.Y)
	else
		draw.Current = shape.Start(ctx, draw) or Cursor.Horizontal(cursor, settings.Elevation)
	end

	local door = draw.StartDoor
	local current = draw.Current

	if door and origin and current and not lock then
		local n = door.normal
		local along = math.max(0, Cursor.Snap(cursor, (current.X - origin.X) * n.X + (current.Z - origin.Z) * n.Z))

		current = Vector3.new(origin.X + n.X * along, origin.Y, origin.Z + n.Z * along)
		draw.Current = current
	end

	if current and ctx.State.GridOn() and not lock then
		Overlay.DrawPlaneGrid(
			ctx.Overlay,
			Vector3.new(Cursor.Snap(cursor, current.X), current.Y, Cursor.Snap(cursor, current.Z)),
			math.max(0.05, Cursor.Grid(cursor))
		)
	elseif not ctx.State.GridOn() then
		Overlay.ClearPlaneGrid(ctx.Overlay)
	end

	if current and origin then
		local a, b = origin, current

		if not lock and Cursor.Alt() then
			local d = b - a

			b = if math.abs(d.X) >= math.abs(d.Z) then Vector3.new(b.X, a.Y, a.Z) else Vector3.new(a.X, a.Y, b.Z)
		end

		if shape.Constrain then
			a, b = shape.Constrain(ctx, draw, a, b)
		end

		draw.Current = b

		local sized: Sized = { Live = live, Height = height, Signed = signed }

		if height then
			sized.Live = table.clone(live)
			sized.Live.Height = height
		end

		if door then
			sized.Live = table.clone(sized.Live)
			sized.Live.Width = door.width
			sized.Live.Height = door.height or sized.Live.Height
		end

		out = shape.Build(ctx, draw, a, b, sized)

		local problem = if #out == 0 and shape.Problem then shape.Problem(out, draw) else nil

		if problem then
			message = problem
		else
			local readout: (Draw, Vector3, Vector3, { Spec }, Sized) -> string = shape.Readout or lengthReadout
			local text = readout(draw, a, b, out, sized)

			if lock then
				text ..= `  [{if lock.Plane then "plane " else ""}{lock.Axis}]`
			end

			if not NumericInput.IsEmpty(draw.Numeric) then
				text ..= `  = {draw.Numeric.Text}`
			end

			message = "Click to build; hold Alt for a straight line."
			Overlay.Readout(ctx.Overlay, (a + b) * 0.5, text)
		end
	elseif current then
		local marker = if shape.Idle then shape.Idle(ctx, draw, current) else nil

		if marker then
			out = marker
		else
			Geometry.Add(out, Vector3.new(0.25, 0.15, 0.25), CFrame.new(current), "Start")
		end
	end

	draw.Specs = out

	local holes: { { cf: CFrame, size: Vector3 } } = {}

	if shape.Joins and settings.ConnectStructures and #out > 0 and draw.First then
		holes = Joints.Preview("Vlux_" .. shape.Id, out, settings.RoomJoin, draw.Previous and draw.Previous.model)
	end

	if lock and not lock.Plane and draw.First then
		Overlay.DrawAxisLine(ctx.Overlay, draw.HeightEnd or draw.First, lock.Axis)
	end

	return { Specs = out, Valid = #out > 0, Message = message, Holes = holes }
end

--[[
	@param ctx Context
	@param draw Draw
	@param current Vector3

	Builds the previewed segment as one undo step, then gets ready for the next one.
]]
local function build(ctx: Context, draw: Draw, current: Vector3)
	local shape = draw.Shape
	local first = draw.First :: Vector3
	local specs = draw.Specs
	local previous = draw.Previous
	local segment = Vector3.new(current.X - first.X, 0, current.Z - first.Z)

	local ok = ctx.Edit("Build " .. shape.Id, function()
		local placed: Instance = if shape.Loose
			then Geometry.Place(specs, shape.Id)
			else Geometry.Materialize(specs, "Vlux_" .. shape.Id)

		if shape.Commit then
			shape.Commit(ctx, draw, {
				Placed = placed,
				Model = if placed:IsA("Model") then placed else nil,
				Segment = segment,
				Joint = first,
				Previous = previous,
			})
		end
	end)

	if not ok then
		return
	end

	local chain = shape.Chain == true

	draw.First = if chain then current else nil
	draw.Chained = chain
	draw.Lock = nil
	draw.HeightEnd = nil
	draw.HeightMouse = nil
	draw.Rise = false
	NumericInput.Clear(draw.Numeric)

	if shape.Built then
		shape.Built(draw)
	end

	Overlay.ClearGhosts(ctx.Overlay)
	Overlay.HideReadout(ctx.Overlay)
	ctx.Say(
		if chain then "Click the next endpoint, or press Enter to begin elsewhere." else Tools.Instruction(shape.Id)
	)
end

--[=[
	@param ctx Context
	@param draw Draw
	@param preview Preview?

	The first click fixes the start; later clicks start the rise stage or build.
]=]
function Engine.Click(ctx: Context, draw: Draw, preview: Types.Preview?)
	local shape = draw.Shape
	local current = draw.Current
	local valid = preview ~= nil and preview.Valid

	if not current then
		return
	end

	if not draw.First then
		draw.First = current
		NumericInput.Clear(draw.Numeric)

		if shape.OnStart then
			shape.OnStart(ctx, draw)
		end

		if shape.Shaft then
			startRise(draw, current)
			ctx.Say("Move up or down to set the vent length, then click.")
		else
			ctx.Say("Click the other point; X, Y or Z locks an axis.")
		end

		ctx.Sound("Point")
	elseif valid and shape.Rise and not draw.Rise and not (shape.Reached and shape.Reached(draw)) then
		startRise(draw, current)
		ctx.Say("Move up or down to set the height, then click.")
		ctx.Sound("Point")
	elseif valid then
		build(ctx, draw, current)
	end
end

--[=[
	Turns an axis lock on or off. Y drags the height of shapes with `HeightDrag`; other shapes only
	take Y as a plane lock (Alt+Y), except the block, which grows up along it.

	@param ctx Context
	@param draw Draw
	@param axis AxisLock.Axis
	@param plane boolean
]=]
function Engine.Lock(ctx: Context, draw: Draw, axis: AxisLock.Axis, plane: boolean)
	local shape = draw.Shape

	if axis == "Y" and not plane and shape.Id ~= "Block" and not shape.HeightDrag then
		return ctx.Say("Y is for height; use X, Z or Alt+Y with this tool.")
	end

	local updated = AxisLock.Toggle(draw.Lock, axis, plane)

	if updated and updated.Axis == "Y" and not updated.Plane and shape.HeightDrag then
		if not draw.First or not draw.Current then
			return ctx.Say("Click the start point first, then press Y to drag the height.")
		end

		draw.HeightEnd = draw.Current
		draw.HeightMouse = Cursor.Screen()
	else
		draw.HeightEnd = nil
		draw.HeightMouse = nil
	end

	draw.Lock = updated
	NumericInput.Clear(draw.Numeric)
	ctx.Say(Common.LockMessage(updated, axis, plane))
end

--[=[
	@param shape Shape
	@return Tool -- the drawing tool for the shape
]=]
function Engine.Tool(shape: Shape): Types.Tool
	return {
		Id = shape.Id,
		Draws = true,
		Begin = function(_ctx: Context): Draw
			return fresh(shape)
		end,
		Preview = function(ctx: Context, draw: Draw): Types.Preview?
			return Engine.Preview(ctx, draw)
		end,
		Click = function(ctx: Context, draw: Draw, preview: Types.Preview?)
			Engine.Click(ctx, draw, preview)
		end,
		Confirm = function(ctx: Context, draw: Draw): boolean
			if draw.First or draw.Chained then
				ctx.Sound("Confirm")
			end

			reset(ctx, draw)
			ctx.Say(Tools.Instruction(shape.Id))

			return true
		end,
		Back = function(ctx: Context, draw: Draw): string?
			if draw.First == nil and not draw.Chained then
				return nil
			end

			reset(ctx, draw)

			return "Point removed; Esc again leaves the tool."
		end,
		Lock = function(ctx: Context, draw: Draw, axis: AxisLock.Axis, plane: boolean)
			Engine.Lock(ctx, draw, axis, plane)
		end,
		Typing = function(draw: Draw): NumericInput.NumericInput?
			return if draw.First then draw.Numeric else nil
		end,
	}
end

--[=[
	Starts a new chain: forgets every point, as Enter does.

	@param ctx Context
	@param draw Draw
]=]
function Engine.Reset(ctx: Context, draw: Draw)
	reset(ctx, draw)
end

return Engine
