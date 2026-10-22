--!strict

--[=[
	The one-click vent pieces: a grate cover, a plain end cap, a fan, a small louvred peek cover, and
	the vent hole, which cuts a vent-sized hole through whatever it is clicked on. Covers, caps and
	fans snap onto an open vent end near the cursor.

	@class VentPieces
]=]

local Builders = require("../Core/Builders")
local Common = require("./Common")
local Cursor = require("../Services/Cursor")
local Geometry = require("../Core/Geometry")
local Settings = require("../Pure/Settings")
local Snapper = require("../Core/Snapper")
local Types = require("./Types")

type Context = Types.Context
type Cut = Builders.Cutter

--[=[
	A piece tool's state: the hole the last preview would cut, if any.

	@interface Piece
	@within VentPieces
	.Cut Cut?
]=]
type Piece = { Cut: Cut? }

local PEEK_WIDTH = 2.4

local BUILDERS: { [string]: (Settings.Settings, Vector3, Vector3) -> { Geometry.Spec } } = {
	VentCover = Builders.VentCover,
	VentCap = Builders.VentCap,
	VentFan = Builders.VentFan,
	VentPeek = Builders.VentPeek,
}

--[[
	@param ctx Context
	@param mode string -- VentCover, VentCap, VentFan or VentPeek
	@param state Piece
	@return Preview
]]
local function piecePreview(ctx: Context, mode: string, state: Piece): Types.Preview
	local hit = Cursor.Hit(ctx.Cursor)

	state.Cut = nil

	if not hit then
		return Common.Empty()
	end

	local center, normal = hit.Position, hit.Normal

	if mode == "VentPeek" then
		local part = hit.Instance :: BasePart
		local depth = math.max(0.4, math.min(part.Size.X, part.Size.Y, part.Size.Z) + 0.2)

		center = Common.SnapOnSurface(center, normal, Common.RoundTo(math.max(0.25, ctx.Settings.FineGrid)))
		state.Cut = {
			cf = Common.SurfaceFrame(center, normal) * CFrame.new(0, 0, 0.1 - depth / 2),
			size = Vector3.new(PEEK_WIDTH - 0.5, Builders.PEEK_HEIGHT - 0.4, depth),
			cylinder = false,
		}
	else
		local endPoint, outward = Snapper.VentEnd(hit.Position, math.max(ctx.Settings.VentSize, 3))

		if endPoint and outward then
			center, normal = endPoint, outward
		else
			center = Common.SnapOnSurface(center, normal, function(value)
				return Cursor.Snap(ctx.Cursor, value)
			end)
		end
	end

	local specs = BUILDERS[mode](ctx.Settings, center + normal * 0.075, normal)

	return { Specs = specs, Valid = #specs > 0, Message = "Click to place it." }
end

--[[
	@param mode string
	@return Tool -- a tool that places one vent piece per click
]]
local function piece(mode: string): Types.Tool
	return {
		Id = mode,
		Begin = function(): Piece
			return { Cut = nil }
		end,
		Preview = function(ctx: Context, state: Piece): Types.Preview?
			return piecePreview(ctx, mode, state)
		end,
		Click = function(ctx: Context, state: Piece, shown: Types.Preview?)
			if not shown or not shown.Valid then
				return
			end

			local cut, specs = state.Cut, shown.Specs

			ctx.Edit("Place vent piece", function()
				if cut then
					Common.CarveBox(cut)
				end

				Geometry.Materialize(specs, "Vlux_" .. mode)
			end)
		end,
	}
end

local hole: Types.Tool = {
	Id = "VentHole",
	Begin = function(): Piece
		return { Cut = nil }
	end,
	Preview = function(ctx: Context, state: Piece): Types.Preview?
		local hit = Cursor.Hit(ctx.Cursor)

		state.Cut = nil

		if not hit or not hit.Instance:IsA("BasePart") or hit.Instance:IsA("Terrain") then
			return Common.Empty("Point at a wall, floor, ceiling, stairs or vent.")
		end

		local part = hit.Instance :: BasePart
		local normal = hit.Normal
		local center = Common.SnapOnSurface(hit.Position, normal, Common.RoundTo(math.max(0.25, ctx.Settings.FineGrid)))
		local cf = part.CFrame
		local extent = math.abs(normal:Dot(cf.XVector)) * part.Size.X
			+ math.abs(normal:Dot(cf.YVector)) * part.Size.Y
			+ math.abs(normal:Dot(cf.ZVector)) * part.Size.Z
		local depth = extent + 0.2
		local inner = math.max(0.5, ctx.Settings.VentSize - 2 * ctx.Settings.VentThickness)

		state.Cut = {
			cf = Common.SurfaceFrame(center, normal) * CFrame.new(0, 0, 0.1 - depth / 2),
			size = Vector3.new(inner, inner, depth),
			cylinder = false,
		}

		local specs = Builders.VentHoleMark(center + normal * 0.05, normal, inner)

		return { Specs = specs, Valid = #specs > 0, Message = "Click to cut a vent hole." }
	end,
	Click = function(ctx: Context, state: Piece, shown: Types.Preview?)
		local cut = state.Cut

		if not shown or not shown.Valid or not cut then
			return
		end

		ctx.Edit("Cut vent hole", function()
			Common.CarveBox(cut)
		end)
	end,
}

return {
	piece("VentCover"),
	piece("VentCap"),
	piece("VentFan"),
	piece("VentPeek"),
	hole,
}
