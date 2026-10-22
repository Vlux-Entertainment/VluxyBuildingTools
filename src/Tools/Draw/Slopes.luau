--!strict

--[=[
	Stairs, ramps and arches. Stairs and ramps take a third click: after the run is drawn, the mouse
	sets the rise.

	@class DrawSlopes
]=]

local Engine = require("./Engine")
local Geometry = require("../../Core/Geometry")
local Points = require("./Points")
local Slopes = require("../../Core/Builders/Slopes")
local Types = require("../Types")

type Context = Types.Context
type Draw = Engine.Draw

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

			return Slopes.Stairs(settings, a, b, ramp)
		end,
		Commit = function(ctx, _draw, built)
			local problem = if built.Model then Geometry.UnionAll(built.Model, id) else nil

			if problem then
				ctx.Say(problem)
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
