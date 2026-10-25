--!strict

--[=[
	Stairs, ramps and arches. Stairs and ramps take a third click: after the run is drawn, the mouse
	sets the rise.

	@class DrawSlopes
]=]

local Engine = require("./Engine")
local Geometry = require("../../Core/Geometry")
local Points = require("./Points")
local Settings = require("../../Pure/Settings")
local Slopes = require("../../Core/Builders/Slopes")
local StairSnap = require("../../Pure/StairSnap")
local Types = require("../Types")

type Context = Types.Context
type Draw = Engine.Draw

--[[ The layout of the stairs each drawing last previewed, recorded on the stairs when built. ]]
type Shown = { layout: StairSnap.Layout, frame: CFrame }

local layouts: { [Draw]: Shown? } = setmetatable({}, { __mode = "k" }) :: any

--[[
	@param stairs Instance -- the built stairs: their union, or the model when joining failed
	@param layout StairSnap.Layout
	@param frame CFrame -- the stairs' frame in the world

	Records the step layout on the stairs, relative to them, so railings snap to the steps even
	after the stairs are moved.
]]
local function remember(stairs: Instance, layout: StairSnap.Layout, frame: CFrame)
	local pivot = if stairs:IsA("PVInstance") then stairs:GetPivot() else CFrame.identity

	if stairs:IsA("Model") then
		stairs.WorldPivot = pivot
	end

	stairs:SetAttribute("VluxyBT_StairFrame", pivot:ToObjectSpace(frame))
	stairs:SetAttribute("VluxyBT_StairRun", layout.Run)
	stairs:SetAttribute("VluxyBT_StairRise", layout.Rise)
	stairs:SetAttribute("VluxyBT_StairCount", layout.Count)
	stairs:SetAttribute("VluxyBT_StairWidth", layout.Width)
	stairs:SetAttribute("VluxyBT_StairLanding", layout.Landing)
	stairs:SetAttribute("VluxyBT_StairRamp", layout.Ramp)
end

local function startOnVertex(ctx: Context, _draw: Draw): Vector3?
	return Points.Vertex(ctx, nil)
end

local function nextOnVertex(ctx: Context, _draw: Draw, origin: Vector3): Vector3?
	return Points.Vertex(ctx, origin.Y)
end

--[[
	@param ramp boolean
	@return Engine.Shape -- stairs or a ramp
]]
local function slope(ramp: boolean): Engine.Shape
	local id = if ramp then "Ramp" else "Stairs"

	return {
		Id = id,
		Start = startOnVertex,
		Next = nextOnVertex,
		Rise = true,
		Readout = function(_draw, a, b, _specs, sized)
			local rise = sized.Height or (if ramp then sized.Live.RampHeight else sized.Live.StairHeight)

			return string.format("Run %.1f  |  Rise %.1f", (b - a).Magnitude, rise)
		end,
		Build = function(ctx, draw, a, b, sized)
			local settings = ctx.Settings

			if draw.Rise and sized.Height then
				settings = table.clone(settings)
				settings.StairHeight = sized.Height
				settings.RampHeight = sized.Height
			end

			local offset = Settings.StairOffset(settings)
			local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)

			if offset ~= 0 and flat.Magnitude > 0.05 then
				local right = flat.Unit:Cross(Vector3.yAxis)

				a += right * offset
				b += right * offset
			end

			local layout, frame = Slopes.StairLayout(settings, a, b, ramp)

			local shown: Shown? = if layout and frame then { layout = layout, frame = frame } else nil

			layouts[draw] = shown

			return Slopes.Stairs(settings, a, b, ramp)
		end,
		Commit = function(ctx, draw, built)
			local model = built.Model
			local problem = if model then Geometry.UnionAll(model, id) else nil
			local shown = layouts[draw]

			if problem then
				ctx.Say(problem)
			end

			if model and shown then
				local union = model:FindFirstChild(id)

				for _, stairs in { union or model, model } do
					remember(stairs, shown.layout, shown.frame)
				end
			end
		end,
	}
end

local arch: Engine.Shape = {
	Id = "Arch",
	Start = function()
		return nil
	end,
	Readout = function(_draw, a, b, _specs, sized)
		return string.format("Span %.1f  |  Height %.1f", (b - a).Magnitude, sized.Live.ArchHeight)
	end,
	Problem = function()
		return "The arch is too low for this span; raise it or draw a narrower one."
	end,
	Build = function(ctx, _draw, a, b)
		return Slopes.Arch(ctx.Settings, a, b)
	end,
	Commit = function(ctx, _draw, built)
		local problem = if built.Model then Geometry.UnionArchHalves(built.Model) else nil

		if problem then
			ctx.Say(problem)
		end
	end,
}

return {
	Engine.Tool(slope(false)),
	Engine.Tool(slope(true)),
	Engine.Tool(arch),
}
