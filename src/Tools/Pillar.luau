--!strict

--[=[
	Pillar: click to stand a square pillar on a floor, or on the floor level setting when there is
	no floor under the cursor.

	@class Pillar
]=]

local Builders = require("../Core/Builders")
local Common = require("./Common")
local Cursor = require("../Services/Cursor")
local Geometry = require("../Core/Geometry")
local Types = require("./Types")

type Context = Types.Context

local tool: Types.Tool = {
	Id = "Pillar",
	Begin = function(): {}
		return {}
	end,
	Preview = function(ctx: Context): Types.Preview?
		local cursor = ctx.Cursor
		local hit = Cursor.Hit(cursor)
		local base = if hit and hit.Normal.Y >= 0.7
			then Cursor.PartSnap(
				cursor,
				Vector3.new(Cursor.Snap(cursor, hit.Position.X), hit.Position.Y, Cursor.Snap(cursor, hit.Position.Z))
			)
			else Cursor.Horizontal(cursor, ctx.Settings.Elevation)

		if not base then
			return Common.Empty()
		end

		local specs = Builders.Pillar(ctx.Settings, base)

		return { Specs = specs, Valid = #specs > 0, Message = "Click to place the pillar." }
	end,
	Click = function(ctx: Context, _state: {}, shown: Types.Preview?)
		if not shown or not shown.Valid then
			return
		end

		local specs = shown.Specs

		ctx.Edit("Build pillar", function()
			Geometry.Place(specs, "Pillar")
		end)
	end,
}

return { tool }
