--!strict

--[=[
	The Blender-style grab, rotate and scale. A session moves the real Parts live while the user
	drags; the caller wraps it in an undo recording and decides whether to keep or cancel it.

	@class Transform
]=]

local AxisLock = require("../Pure/AxisLock")
local Geometry = require("./Geometry")
local Guides = require("./Guides")
local NumericInput = require("../Pure/NumericInput")
local Snap = require("../Pure/Snap")

export type Kind = "Grab" | "Rotate" | "Scale"

type Original = { Cf: CFrame, Size: Vector3 }

export type Session = {
	Kind: Kind,
	Parts: { BasePart },
	Lock: AxisLock.Lock?,
	Numeric: NumericInput.NumericInput,
	_original: { [BasePart]: Original },
	_pivots: { [Model]: CFrame },
	_center: Vector3,
	_startMouse: Vector2,
	_base: Vector3?,
	_anchors: { Vector3 },
	_delta: Vector3,
}

local DEGREES_PER_PIXEL = 0.5
local ROTATE_STEP = 5
local SCALE_PER_PIXEL = 0.01
local SCALE_STEP = 0.05
local MAX_SIZE = 2048
local MIN_SIZE = 0.05

local Transform = {}

--[[
	@param self Session
	@param ray Ray -- the mouse ray
	@param look Vector3 -- the camera's look direction

	@return Vector3? -- where the mouse points in the space the lock allows
]]
local function reading(self: Session, ray: Ray, look: Vector3): Vector3?
	local center = Geometry.ToVec(self._center)
	local origin, direction = Geometry.ToVec(ray.Origin), Geometry.ToVec(ray.Direction)
	local lock = self.Lock

	if lock and not lock.Plane then
		local along = AxisLock.ClosestOnLine(center, AxisLock.Unit(lock.Axis), origin, direction)

		if not along then
			return nil
		end

		return self._center + Geometry.FromVec(AxisLock.Unit(lock.Axis)) * along
	elseif lock then
		local hit = AxisLock.RayPlane(center, lock.Axis, origin, direction)

		return if hit then Geometry.FromVec(hit) else nil
	end

	-- No lock: move in the plane facing the camera, through the selection's centre.
	local facing = ray.Direction:Dot(look)

	if math.abs(facing) < 1e-6 then
		return nil
	end

	local t = (self._center - ray.Origin):Dot(look) / facing

	return if t > 0 then ray.Origin + ray.Direction * t else nil
end

--[[
	@param self Session
	@param delta Vector3 -- the move so far
	@param reach number
	@return Vector3? -- the extra move that puts the selection point nearest a measuring guide point onto it, kept to the axis or plane locked; nil when none is within reach
]]
local function toGuide(self: Session, delta: Vector3, reach: number): Vector3?
	local best: Vector3? = nil
	local bestDistance = reach

	for _, anchor in self._anchors do
		local moved = anchor + delta
		local guide = Guides.Near(moved, reach)

		if guide and (guide - moved).Magnitude < bestDistance then
			best, bestDistance = guide - moved, (guide - moved).Magnitude
		end
	end

	local lock = self.Lock

	if not best or not lock then
		return best
	end

	local axis = Geometry.FromVec(AxisLock.Unit(lock.Axis))

	return if lock.Plane then best - axis * best:Dot(axis) else axis * best:Dot(axis)
end

--[=[
	@param kind Kind
	@param parts { BasePart } -- every Part that moves
	@param mouse Vector2 -- the mouse position on screen
	@param ray Ray -- the mouse ray
	@param look Vector3 -- the camera's look direction
	@return Session
]=]
function Transform.Begin(kind: Kind, parts: { BasePart }, mouse: Vector2, ray: Ray, look: Vector3): Session
	local original: { [BasePart]: Original } = {}

	for _, part in parts do
		original[part] = { Cf = part.CFrame, Size = part.Size }
	end

	local box, size = Geometry.Bounds(parts)
	local center = box.Position
	local anchors: { Vector3 } = {}

	for _, x in { -1, 0, 1 } do
		for _, y in { -1, 0, 1 } do
			for _, z in { -1, 0, 1 } do
				table.insert(anchors, center + size * Vector3.new(x, y, z) * 0.5)
			end
		end
	end

	local self: Session = {
		Kind = kind,
		Parts = parts,
		Lock = nil,
		Numeric = NumericInput.new(),
		_original = original,
		_pivots = Geometry.WholeModels(parts),
		_center = center,
		_startMouse = mouse,
		_base = nil,
		_anchors = anchors,
		_delta = Vector3.zero,
	}

	self._base = reading(self, ray, look)

	return self
end

--[=[
	Puts every Part back where it started.

	@param self Session
]=]
function Transform.Restore(self: Session)
	for part, original in self._original do
		if part.Parent then
			part.CFrame = original.Cf
			part.Size = original.Size
		end
	end

	Geometry.MovePivots(self._pivots, function(pivot)
		return pivot
	end)
end

--[=[
	Moves every Part, and the pivots of the models that move whole, by a delta from where they
	started.

	@param self Session
	@param delta Vector3
]=]
function Transform.Apply(self: Session, delta: Vector3)
	self._delta = delta

	for part, original in self._original do
		part.CFrame = original.Cf + delta
	end

	Geometry.MovePivots(self._pivots, function(pivot)
		return pivot + delta
	end)
end

--[=[
	@param self Session
	@return Vector3 -- how far the last grab update moved the selection
]=]
function Transform.Delta(self: Session): Vector3
	return self._delta
end

--[=[
	Changes the axis lock. The motion so far is dropped, as in Blender, and measured again from
	the current mouse position.

	@param self Session
	@param lock AxisLock.Lock?
	@param ray Ray
	@param look Vector3
]=]
function Transform.SetLock(self: Session, lock: AxisLock.Lock?, ray: Ray, look: Vector3)
	Transform.Restore(self)
	self.Lock = lock
	self._base = reading(self, ray, look)
end

--[=[
	Re-applies the transform for the current mouse position and typed number.

	@param self Session
	@param grid number -- the snap increment
	@param mouse Vector2
	@param ray Ray
	@param look Vector3
	@param guideReach number? -- how close a corner, side centre or the centre of the selection must come to a measuring guide point to snap onto it; nil turns guide snapping off
	@return string -- the text for the floating readout
	@return Vector3 -- where to show it
]=]
function Transform.Update(
	self: Session,
	grid: number,
	mouse: Vector2,
	ray: Ray,
	look: Vector3,
	guideReach: number?
): (string, Vector3)
	local typed = NumericInput.Value(self.Numeric)
	local lock = self.Lock
	local suffix = if lock then `  [{if lock.Plane then "plane " else ""}{lock.Axis}]` else ""
	local typedSuffix = if NumericInput.IsEmpty(self.Numeric) then "" else `  = {self.Numeric.Text}`

	if self.Kind == "Grab" then
		local delta = Vector3.zero

		if typed and lock and not lock.Plane then
			delta = Geometry.FromVec(AxisLock.Unit(lock.Axis)) * typed
		else
			local point, base = reading(self, ray, look), self._base

			if point and base then
				local move = point - base

				delta = Vector3.new(Snap.Round(move.X, grid), Snap.Round(move.Y, grid), Snap.Round(move.Z, grid))
			end

			local pull = if guideReach then toGuide(self, delta, guideReach) else nil

			if pull then
				delta += pull
				suffix ..= "  [guide]"
			end
		end

		Transform.Apply(self, delta)

		return string.format("Move  X %.2f  Y %.2f  Z %.2f", delta.X, delta.Y, delta.Z) .. suffix .. typedSuffix,
			self._center + delta
	elseif self.Kind == "Rotate" then
		local degrees = typed or Snap.Round((mouse.X - self._startMouse.X) * DEGREES_PER_PIXEL, ROTATE_STEP)
		local axis = Geometry.FromVec(AxisLock.Unit(if lock then lock.Axis else "Y"))
		local turn = CFrame.fromAxisAngle(axis, math.rad(degrees))

		--[[ Turns a frame about the selection's centre. ]]
		local function turned(cf: CFrame): CFrame
			return CFrame.new(self._center + turn:VectorToWorldSpace(cf.Position - self._center)) * turn * cf.Rotation
		end

		for part, original in self._original do
			part.CFrame = turned(original.Cf)
		end

		Geometry.MovePivots(self._pivots, turned)

		return string.format("Rotate  %.1f°", degrees) .. suffix .. typedSuffix, self._center
	end

	local factor =
		math.max(MIN_SIZE, typed or Snap.Round(1 + (mouse.X - self._startMouse.X) * SCALE_PER_PIXEL, SCALE_STEP))
	local f = Vector3.one * factor

	if lock then
		local axisUnit = Geometry.FromVec(AxisLock.Unit(lock.Axis))

		f = if lock.Plane then Vector3.one * factor - axisUnit * (factor - 1) else Vector3.one + axisUnit * (factor - 1)
	end

	for part, original in self._original do
		local rotation = original.Cf.Rotation
		local position = self._center + (original.Cf.Position - self._center) * f
		local stretch = Vector3.new(
			(original.Cf.RightVector * f).Magnitude,
			(original.Cf.UpVector * f).Magnitude,
			(original.Cf.LookVector * f).Magnitude
		)
		local size = original.Size * stretch

		part.Size = Vector3.new(
			math.clamp(size.X, MIN_SIZE, MAX_SIZE),
			math.clamp(size.Y, MIN_SIZE, MAX_SIZE),
			math.clamp(size.Z, MIN_SIZE, MAX_SIZE)
		)
		part.CFrame = CFrame.new(position) * rotation
	end

	return string.format("Scale  %.2f×", factor) .. suffix .. typedSuffix, self._center
end

return Transform
