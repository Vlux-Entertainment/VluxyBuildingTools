--!strict

--[=[
	Blender-style axis locking for a drag. A lock keeps the dragged point on one world axis, or, with
	the plane flag, on the plane that axis is perpendicular to. The ray maths uses plain tables so
	it runs under Lune.

	@class AxisLock
]=]

export type Axis = "X" | "Y" | "Z"
export type Lock = { Axis: Axis, Plane: boolean }
export type Vec = { X: number, Y: number, Z: number }

local PARALLEL = 1e-6
local AXES: { Axis } = { "X", "Y", "Z" }

local AxisLock = {}

--[=[
	Pressing the key of the active lock clears it; any other press replaces it.

	@param current Lock? -- the lock in force, if any
	@param axis Axis -- the key pressed
	@param plane boolean -- true when Shift was held
	@return Lock?
]=]
function AxisLock.Toggle(current: Lock?, axis: Axis, plane: boolean): Lock?
	if current and current.Axis == axis and current.Plane == plane then
		return nil
	end

	return { Axis = axis, Plane = plane }
end

--[=[
	@param axis Axis
	@return Vec -- the unit vector of that world axis
]=]
function AxisLock.Unit(axis: Axis): Vec
	return { X = if axis == "X" then 1 else 0, Y = if axis == "Y" then 1 else 0, Z = if axis == "Z" then 1 else 0 }
end

--[=[
	Finds where along a line the mouse ray passes closest to it, in units of the line's direction.
	Returns nil when the ray runs parallel to the line, since there is no single answer then.

	@param lineOrigin Vec
	@param lineDirection Vec -- a unit vector
	@param rayOrigin Vec
	@param rayDirection Vec
	@return number?
]=]
function AxisLock.ClosestOnLine(lineOrigin: Vec, lineDirection: Vec, rayOrigin: Vec, rayDirection: Vec): number?
	local u, v = lineDirection, rayDirection
	local wx, wy, wz = lineOrigin.X - rayOrigin.X, lineOrigin.Y - rayOrigin.Y, lineOrigin.Z - rayOrigin.Z
	local a = u.X * u.X + u.Y * u.Y + u.Z * u.Z
	local b = u.X * v.X + u.Y * v.Y + u.Z * v.Z
	local c = v.X * v.X + v.Y * v.Y + v.Z * v.Z
	local d = u.X * wx + u.Y * wy + u.Z * wz
	local e = v.X * wx + v.Y * wy + v.Z * wz
	local denominator = a * c - b * b

	if math.abs(denominator) < PARALLEL * a * c then
		return nil
	end

	return (b * e - c * d) / denominator
end

--[=[
	Finds where a ray meets the plane through a point, perpendicular to a world axis.

	@param planePoint Vec
	@param axis Axis -- the plane's normal
	@param rayOrigin Vec
	@param rayDirection Vec
	@return Vec? -- nil when the ray is parallel to the plane or the plane is behind it
]=]
function AxisLock.RayPlane(planePoint: Vec, axis: Axis, rayOrigin: Vec, rayDirection: Vec): Vec?
	local along = rayDirection[axis]

	if math.abs(along) < PARALLEL then
		return nil
	end

	local t = (planePoint[axis] - rayOrigin[axis]) / along

	if t <= 0 then
		return nil
	end

	return {
		X = rayOrigin.X + rayDirection.X * t,
		Y = rayOrigin.Y + rayDirection.Y * t,
		Z = rayOrigin.Z + rayDirection.Z * t,
	}
end

--[=[
	Moves a point onto a lock. Axis lock: only the locked component follows `raw`. Plane lock: the
	locked component stays at `origin` and the other two follow `raw`.

	@param origin Vec -- where the drag began
	@param raw Vec -- where the mouse wants the point
	@param lock Lock
	@return Vec
]=]
function AxisLock.Constrain(origin: Vec, raw: Vec, lock: Lock): Vec
	local out = { X = origin.X, Y = origin.Y, Z = origin.Z }

	for _, name in AXES do
		if (name == lock.Axis) ~= lock.Plane then
			out[name] = raw[name]
		end
	end

	return out
end

return AxisLock
