--!strict

--[=[
	Small helpers several tools share. Each one used to be written out again in every tool that
	needed it.

	@class ToolCommon
]=]

local AxisLock = require("../Pure/AxisLock")
local Cursor = require("../Services/Cursor")
local Geometry = require("../Core/Geometry")
local Joints = require("../Core/Joints")
local Settings = require("../Pure/Settings")
local Shapes = require("../Core/Builders/Shapes")
local Types = require("./Types")

type Context = Types.Context

local Common = {}

--[=[
	@param ctx Context
	@return Settings -- the settings with `Grid` set to the snap step in force, a copy only while Shift changes it
]=]
function Common.Live(ctx: Context): Settings.Settings
	local step = Cursor.Grid(ctx.Cursor)

	if step == ctx.Settings.Grid then
		return ctx.Settings
	end

	local live = table.clone(ctx.Settings)

	live.Grid = step

	return live
end

--[=[
	@param point Vector3
	@param normal Vector3 -- the surface normal
	@param round (number) -> number
	@return Vector3 -- the point with each axis that lies along the surface rounded, and the axis across it left alone
]=]
function Common.SnapOnSurface(point: Vector3, normal: Vector3, round: (number) -> number): Vector3
	return Vector3.new(
		if math.abs(normal.X) < 0.5 then round(point.X) else point.X,
		if math.abs(normal.Y) < 0.5 then round(point.Y) else point.Y,
		if math.abs(normal.Z) < 0.5 then round(point.Z) else point.Z
	)
end

--[=[
	@param step number
	@return (number) -> number -- rounds a number to the step
]=]
function Common.RoundTo(step: number): (number) -> number
	return function(value: number): number
		return math.round(value / step) * step
	end
end

--[=[
	@param center Vector3
	@param normal Vector3
	@return CFrame -- a frame at the center whose look vector is the normal, upright where it can be
]=]
function Common.SurfaceFrame(center: Vector3, normal: Vector3): CFrame
	local u = (if math.abs(normal.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis):Cross(normal).Unit

	return CFrame.fromMatrix(center, u, normal:Cross(u), normal)
end

--[=[
	Cuts a box out of every Part inside the working folder that it touches.

	@param cut Shapes.Cutter
	@return number -- how many parts could not be cut
]=]
function Common.CarveBox(cut: Shapes.Cutter): number
	local params = OverlapParams.new()
	local scope = Geometry.GetScope()
	local failed = 0

	if scope then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { scope }
	end

	for _, part in workspace:GetPartBoundsInBox(cut.cf, cut.size, params) do
		if not part:IsA("Terrain") and not Joints.Carve(part, { cut }) then
			failed += 1
		end
	end

	return failed
end

--[=[
	@param updated AxisLock.Lock? -- the lock after the key press
	@param axis AxisLock.Axis -- the key pressed
	@param plane boolean -- whether Alt was held
	@return string -- what the key press did to the axis lock
]=]
function Common.LockMessage(updated: AxisLock.Lock?, axis: AxisLock.Axis, plane: boolean): string
	if not updated then
		return "Axis lock off."
	end

	return `Locked to the {if updated.Plane then "plane without " else ""}{updated.Axis} axis. Press {if plane
		then "Alt+"
		else ""}{axis} again to unlock.`
end

--[=[
	@return Types.Preview -- a preview that draws nothing and builds nothing
]=]
function Common.Empty(message: string?): Types.Preview
	return { Specs = {}, Valid = false, Message = message }
end

return Common
