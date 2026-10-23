--!strict

--[=[
	Measure: click two surface points to see the distance between them. The last measurement stays
	in the viewport until Esc or the next one.

	@class Measure
]=]

local Common = require("./Common")
local Cursor = require("../Services/Cursor")
local Overlay = require("../Core/Overlay")
local Types = require("./Types")

type Context = Types.Context

--[=[
	@interface MeasureState
	@within Measure
	.First Vector3? -- the first point of the measurement being made
	.Current Vector3? -- the point under the cursor
	.Kept { a: Vector3, b: Vector3 }? -- the last finished measurement
]=]
type MeasureState = {
	First: Vector3?,
	Current: Vector3?,
	Kept: { a: Vector3, b: Vector3 }?,
}

local tool: Types.Tool = {
	Id = "Measure",
	Begin = function(): MeasureState
		return { First = nil, Current = nil, Kept = nil }
	end,
	Preview = function(ctx: Context, state: MeasureState): Types.Preview?
		local cursor = ctx.Cursor
		local hit = Cursor.Hit(cursor)
		local current = if hit then hit.Position else Cursor.Horizontal(cursor, ctx.Settings.Elevation)
		local corner = if current
				and ctx.Settings.SnapToParts
				and not Cursor.Fine()
			then Cursor.Corner(current)
			else nil

		if corner then
			current = corner
			cursor.Mark = corner
		elseif current then
			current = Common.SnapOnSurface(
				current,
				if hit then hit.Normal else Vector3.yAxis,
				Common.RoundTo(Cursor.Grid(cursor))
			)
		end

		state.Current = current

		local first, kept = state.First, state.Kept

		if current and first then
			Overlay.DrawMeasurement(ctx.Overlay, first, current)

			return Common.Empty("Click to keep this measurement.")
		elseif kept then
			Overlay.DrawMeasurement(ctx.Overlay, kept.a, kept.b)
		end

		return Common.Empty()
	end,
	Click = function(ctx: Context, state: MeasureState)
		local current, first = state.Current, state.First

		if not current then
			return
		end

		if not first then
			state.Kept = nil
			state.First = current
			Overlay.ClearMeasurement(ctx.Overlay)
			ctx.Say("Click the second point.")

			return
		end

		state.Kept = { a = first, b = current }
		state.First = nil
		Overlay.DrawMeasurement(ctx.Overlay, first, current)
		ctx.Say(string.format("%.2f studs; click to measure again, Esc clears it.", (current - first).Magnitude))
	end,
	Back = function(ctx: Context, state: MeasureState): string?
		if not state.First and not state.Kept then
			return nil
		end

		state.First, state.Kept = nil, nil
		Overlay.ClearMeasurement(ctx.Overlay)

		return "Point removed; Esc again leaves the tool."
	end,
	Finish = function(ctx: Context)
		Overlay.ClearMeasurement(ctx.Overlay)
	end,
}

return { tool }
