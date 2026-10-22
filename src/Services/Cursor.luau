--!strict

--[=[
	Everything the tools ask about the mouse: where it points, which modifier keys are held, and how
	a point snaps to the grid and to nearby parts.

	`Mark` is the snap marker of the preview being drawn. The tool runner clears it before each
	preview, the snapping helpers set it when they snap, and the runner draws it afterwards.

	@class Cursor
]=]

local UserInputService = game:GetService("UserInputService")

local AxisLock = require("../Pure/AxisLock")
local Geometry = require("../Core/Geometry")
local NumericInput = require("../Pure/NumericInput")
local Settings = require("../Pure/Settings")
local Snap = require("../Pure/Snap")
local Snapper = require("../Core/Snapper")

export type Cursor = {
	Mouse: PluginMouse,
	--[=[ The snap marker of the preview being drawn, or nil. ]=]
	Mark: Vector3?,
	--[=[ The part the last `PartSnap` snapped to, or nil. ]=]
	SnapPart: BasePart?,
	_settings: Settings.Settings,
	_hidden: () -> { Instance },
}

local FAR = 100000
local CORNER_PIXELS = 14

local Cursor = {}

--[=[
	@param mouse PluginMouse
	@param settings Settings -- the live settings, read for the grid and snapping options
	@param hidden () -> { Instance } -- the hidden parts, which the mouse ray passes through
	@return Cursor
]=]
function Cursor.new(mouse: PluginMouse, settings: Settings.Settings, hidden: () -> { Instance }): Cursor
	return { Mouse = mouse, Mark = nil, SnapPart = nil, _settings = settings, _hidden = hidden }
end

--[=[
	@return boolean -- true while either Shift key is held, which switches to the fine grid and turns part snapping off
]=]
function Cursor.Fine(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

--[=[
	@return boolean -- true while either Alt key is held
]=]
function Cursor.Alt(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
end

--[=[
	@return boolean -- true while either Ctrl key, or the left Command key on a Mac, is held
]=]
function Cursor.Ctrl(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.LeftMeta)
end

--[=[
	@return Vector2 -- the mouse position in screen pixels
]=]
function Cursor.Screen(): Vector2
	return UserInputService:GetMouseLocation()
end

--[=[
	@return Vector3 -- the direction the camera looks
]=]
function Cursor.Look(): Vector3
	local camera = workspace.CurrentCamera

	return if camera then camera.CFrame.LookVector else Vector3.zAxis
end

--[=[
	@param self Cursor
	@return Ray -- the ray from the camera through the mouse
]=]
function Cursor.Ray(self: Cursor): Ray
	return self.Mouse.UnitRay
end

--[=[
	@param self Cursor
	@param exclude { Instance }? -- objects the ray passes through, besides the hidden parts
	@return RaycastResult? -- the first visible surface under the mouse, anywhere in Workspace
]=]
function Cursor.Hit(self: Cursor, exclude: { Instance }?): RaycastResult?
	local ray = self.Mouse.UnitRay
	local params = RaycastParams.new()
	local ignored = self._hidden()

	if exclude then
		table.move(exclude, 1, #exclude, #ignored + 1, ignored)
	end

	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignored

	return workspace:Raycast(ray.Origin, ray.Direction * FAR, params)
end

--[=[
	@param self Cursor
	@return RaycastResult? -- the surface under the mouse, only when it is inside the working folder
]=]
function Cursor.ScopedHit(self: Cursor): RaycastResult?
	local hit = Cursor.Hit(self)

	return if hit and Geometry.InScope(hit.Instance) then hit else nil
end

--[=[
	@param self Cursor
	@return number -- the snap step in force: the fine step while Shift is held, else the normal one
]=]
function Cursor.Grid(self: Cursor): number
	return if Cursor.Fine() then self._settings.FineGrid else self._settings.Grid
end

--[=[
	@param self Cursor
	@param value number
	@return number -- the value rounded to the snap step in force
]=]
function Cursor.Snap(self: Cursor, value: number): number
	return Snap.Round(value, Cursor.Grid(self))
end

--[=[
	@param self Cursor
	@param point Vector3 -- a grid-snapped point
	@return Vector3 -- the point moved onto a nearby corner or edge, unless Shift is held or part snapping is off

	When it snaps, it sets `Mark` and `SnapPart`.
]=]
function Cursor.PartSnap(self: Cursor, point: Vector3): Vector3
	if Cursor.Fine() or not self._settings.SnapToParts then
		return point
	end

	local snapped, found, part = Snapper.Find(point, self._settings.SnapRadius)

	if found then
		self.Mark = snapped
		self.SnapPart = part
	end

	return snapped
end

--[=[
	@param point Vector3
	@return Vector3? -- the nearest part corner within a few pixels of the mouse, or nil
]=]
function Cursor.Corner(point: Vector3): Vector3?
	local corner, found = Snapper.VertexNear(point, Cursor.Screen(), CORNER_PIXELS)

	return if found then corner else nil
end

--[=[
	@param self Cursor
	@param y number
	@return Vector3? -- where the mouse ray meets the horizontal plane at y, snapped to the grid and to parts
]=]
function Cursor.Horizontal(self: Cursor, y: number): Vector3?
	local ray = self.Mouse.UnitRay

	if math.abs(ray.Direction.Y) < 0.00001 then
		return nil
	end

	local t = (y - ray.Origin.Y) / ray.Direction.Y

	if t <= 0 or t > FAR then
		return nil
	end

	local point = ray.Origin + ray.Direction * t

	return Cursor.PartSnap(self, Vector3.new(Cursor.Snap(self, point.X), y, Cursor.Snap(self, point.Z)))
end

--[=[
	@param self Cursor
	@param origin Vector3 -- a point on the plane
	@param normal Vector3 -- the plane's normal
	@return Vector3? -- where the mouse ray meets the plane in front of the camera, or nil
]=]
function Cursor.OnPlane(self: Cursor, origin: Vector3, normal: Vector3): Vector3?
	local ray = self.Mouse.UnitRay
	local denominator = ray.Direction:Dot(normal)

	if math.abs(denominator) <= 1e-4 then
		return nil
	end

	local t = (origin - ray.Origin):Dot(normal) / denominator

	return if t > 0 then ray.Origin + ray.Direction * t else nil
end

--[=[
	@param self Cursor
	@param origin Vector3 -- where the drag began
	@param lock AxisLock.Lock
	@param typed NumericInput? -- a typed length, used instead of the mouse along a single axis
	@return Vector3? -- the mouse point pulled onto the lock and snapped
]=]
function Cursor.Locked(self: Cursor, origin: Vector3, lock: AxisLock.Lock, typed: NumericInput.NumericInput?): Vector3?
	local ray = self.Mouse.UnitRay
	local from, direction = Geometry.ToVec(ray.Origin), Geometry.ToVec(ray.Direction)
	local start = Geometry.ToVec(origin)

	if lock.Plane then
		local hit = AxisLock.RayPlane(start, lock.Axis, from, direction)

		if not hit then
			return nil
		end

		local point = AxisLock.Constrain(start, hit, lock)

		return Vector3.new(Cursor.Snap(self, point.X), Cursor.Snap(self, point.Y), Cursor.Snap(self, point.Z))
	end

	local unit = AxisLock.Unit(lock.Axis)
	local along = AxisLock.ClosestOnLine(start, unit, from, direction)
	local value = if typed then NumericInput.Value(typed) else nil

	if value then
		along = value
	elseif along then
		along = Cursor.Snap(self, along)
	else
		return nil
	end

	return origin + Geometry.FromVec(unit) * (along :: number)
end

--[=[
	@param self Cursor
	@param origin Vector3 -- a point on the line
	@param direction Vector3 -- the line's direction
	@return number? -- how far along the line the mouse points, or nil when the ray runs along it
]=]
function Cursor.AlongLine(self: Cursor, origin: Vector3, direction: Vector3): number?
	local ray = self.Mouse.UnitRay

	return AxisLock.ClosestOnLine(
		Geometry.ToVec(origin),
		Geometry.ToVec(direction),
		Geometry.ToVec(ray.Origin),
		Geometry.ToVec(ray.Direction)
	)
end

--[=[
	@param self Cursor
	@param from Vector3 -- the point the height is measured from
	@param startMouse Vector2 -- where the mouse was when the height drag began
	@param signed boolean? -- true to allow a negative height
	@return number -- a height from how far the mouse moved up the screen since the drag began

	Looking straight down, the mouse cannot be projected onto a vertical line, so the height follows
	the mouse on screen instead.
]=]
function Cursor.ScreenHeight(self: Cursor, from: Vector3, startMouse: Vector2, signed: boolean?): number
	local camera = workspace.CurrentCamera

	if not camera then
		return Cursor.Grid(self)
	end

	local distance = (camera.CFrame.Position - from).Magnitude
	local perPixel = 2 * distance * math.tan(math.rad(camera.FieldOfView) / 2) / math.max(1, camera.ViewportSize.Y)
	local raw = Cursor.Snap(self, (startMouse.Y - Cursor.Screen().Y) * perPixel)

	return if signed then raw else math.max(Cursor.Grid(self), raw)
end

return Cursor
