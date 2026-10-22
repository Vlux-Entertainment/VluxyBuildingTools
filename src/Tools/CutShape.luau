--!strict

--[=[
	Cut Shape: click corners on one face of a part to outline any shape, then click the first
	corner again or press Enter to cut it out. The first click fixes the face; every later corner
	lies on it.

	@class CutShape
]=]

local Cursor = require("../Services/Cursor")
local Geometry = require("../Core/Geometry")
local Joints = require("../Core/Joints")
local Openings = require("../Core/Builders/Openings")
local Overlay = require("../Core/Overlay")
local Polygon = require("../Pure/Polygon")
local Tools = require("../Pure/Tools")
local Types = require("./Types")

type Context = Types.Context

--[=[
	One face of a part, with two axes lying in it.

	@interface Face
	@within CutShape
	.part BasePart
	.origin Vector3 -- the middle of the face
	.normal Vector3 -- out of the face
	.u Vector3
	.v Vector3
	.thickness number -- the part's size across the face
]=]
type Face = {
	part: BasePart,
	origin: Vector3,
	normal: Vector3,
	u: Vector3,
	v: Vector3,
	thickness: number,
}

type CutState = {
	--[=[ The face the corners lie on, fixed by the first click. ]=]
	Face: Face?,
	--[=[ The face under the cursor before the first click. ]=]
	Pending: Face?,
	Points: { Vector3 },
	--[=[ Where the next corner would go. ]=]
	Spot: Vector3?,
}

local CLOSE = 0.05

--[[
	@param part BasePart
	@param normal Vector3 -- the world normal of the face that was hit
	@return Face
]]
local function faceOf(part: BasePart, normal: Vector3): Face
	local axis, side = Openings.FaceAxis(part, normal)
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
	@param ctx Context
	@param face Face
	@param point Vector3 -- somewhere on the plane of the face
	@return Vector3 -- the point moved to a part corner nearby, else to the grid inside the face
]]
local function snapOnFace(ctx: Context, face: Face, point: Vector3): Vector3
	local corner = if ctx.Settings.SnapToParts then Cursor.Corner(point) else nil
	local offset = (corner or point) - face.origin
	local a, b = offset:Dot(face.u), offset:Dot(face.v)

	if not corner then
		a, b = Cursor.Snap(ctx.Cursor, a), Cursor.Snap(ctx.Cursor, b)
	end

	return face.origin + face.u * a + face.v * b
end

--[[
	@param ctx Context
	@param state CutState
]]
local function reset(ctx: Context, state: CutState)
	state.Face, state.Pending, state.Points, state.Spot = nil, nil, {}, nil
	Overlay.ClearGhosts(ctx.Overlay)
end

--[[
	@param ctx Context
	@param state CutState

	Cuts the outlined shape out of the part as one undo step, then clears the outline.
]]
local function finish(ctx: Context, state: CutState)
	local face, points = state.Face, state.Points

	if not face or #points < 3 then
		return ctx.Say("Click at least three corners first.")
	end

	local flat: { Polygon.Point } = {}

	for _, p in points do
		local offset = p - face.origin

		table.insert(flat, { offset:Dot(face.u), offset:Dot(face.v) })
	end

	local triangles = Polygon.Triangulate(flat)

	if not triangles then
		return ctx.Say("The outline crosses itself or has no area. Press Esc and try again.")
	end

	local specs = Openings.CutShape(points, triangles, face.thickness + 0.5, -face.normal * (face.thickness / 2))
	local part = face.part

	ctx.Edit("Cut shape", function()
		assert(part.Parent, "Wall no longer exists")

		if not Joints.CarveShape(part, specs) then
			ctx.Say("The wall could not be cut.")
		end
	end)
	reset(ctx, state)
	ctx.Say(Tools.Instruction("CutShape"))
end

--[[
	@param out { Geometry.Spec }
	@param a Vector3
	@param b Vector3

	Adds a thin bar from a to b, one edge of the outline.
]]
local function edge(out: { Geometry.Spec }, a: Vector3, b: Vector3)
	Geometry.Add(out, Vector3.new(0.2, 0.2, (b - a).Magnitude), CFrame.lookAt((a + b) * 0.5, b), "CutEdge")
end

local function preview(ctx: Context, state: CutState): Types.Preview
	local out: { Geometry.Spec } = {}
	local face = state.Face
	local spot: Vector3? = nil

	if face then
		spot = Cursor.OnPlane(ctx.Cursor, face.origin, face.normal)
	else
		local hit = Cursor.ScopedHit(ctx.Cursor)

		if hit and hit.Instance:IsA("BasePart") and not hit.Instance:IsA("Terrain") then
			face = faceOf(hit.Instance, hit.Normal)
			spot = hit.Position
		end

		state.Pending = face
	end

	if spot and face then
		spot = snapOnFace(ctx, face, spot)
	end

	state.Spot = spot

	local points = state.Points

	for i = 2, #points do
		edge(out, points[i - 1], points[i])
	end

	local previous = points[#points]

	if spot and previous then
		edge(out, previous, spot)
	end

	if spot then
		Geometry.Add(out, Vector3.new(0.4, 0.4, 0.4), CFrame.new(spot), "Start")
		ctx.Cursor.Mark = spot
	end

	local message = if #points == 0
		then "Click the first corner on the wall."
		elseif #points < 3 then "Click the next corner."
		else "Click the next corner. Click the first corner again or press Enter to cut the shape out."

	return { Specs = out, Valid = #out > 0, Message = message }
end

local function click(ctx: Context, state: CutState)
	local spot = state.Spot

	if not spot then
		return
	end

	if not state.Face then
		state.Face = state.Pending
	end

	local points = state.Points

	if #points >= 3 and (spot - points[1]).Magnitude < CLOSE then
		return finish(ctx, state)
	end

	local last = points[#points]

	if not last or (spot - last).Magnitude > CLOSE then
		table.insert(points, spot)
	end
end

local tool: Types.Tool = {
	Id = "CutShape",
	Begin = function(): CutState
		return { Face = nil, Pending = nil, Points = {}, Spot = nil }
	end,
	Preview = preview,
	Click = click,
	Confirm = function(ctx: Context, state: CutState): boolean
		if state.Face then
			finish(ctx, state)
		else
			reset(ctx, state)
			ctx.Say(Tools.Instruction("CutShape"))
		end

		return true
	end,
	Back = function(ctx: Context, state: CutState): string?
		if not state.Face then
			return nil
		end

		reset(ctx, state)

		return "Cut cancelled."
	end,
}

return { tool }
