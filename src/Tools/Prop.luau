--!strict

--[=[
	Prop: places the built-in prop picked in the Props tab. Floor props stand on flat tops and turn
	with the rotation setting (R turns them 90 degrees); wall props hang flat against a wall; ceiling props
	hang from the underside of a ceiling.

	@class Prop
]=]

local Common = require("./Common")
local Cursor = require("../Services/Cursor")
local Geometry = require("../Core/Geometry")
local PropData = require("../Pure/PropData")
local Props = require("../Core/Props")
local Types = require("./Types")

type Context = Types.Context

--[=[
	@interface PropState
	@within Prop
	.Frame CFrame? -- where the last preview put the prop
]=]
type PropState = { Frame: CFrame? }

local MODEL_TURN = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 1, 0), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0))

--[[
	Copies the stored model of a prop that has one, exactly as it was saved, and puts it where the
	prop would stand. The stored models share one pivot turn; `Pivot` is where each pivot sits under the mount point.

	@param def PropData.Prop
	@param frame CFrame
	@param scale number
	@return Model? -- nil when the prop has no stored model
]]
local function cloneModel(def: PropData.Prop, frame: CFrame, scale: number): Model?
	local root = script.Parent and script.Parent.Parent
	local folder = if root then root:FindFirstChild("Models") else nil
	local stored = if folder and def.Model then folder:FindFirstChild(def.Model) else nil
	local pivot = def.Pivot

	if not stored or not stored:IsA("Model") or not pivot then
		return nil
	end

	local model = stored:Clone()
	local factor = math.max(0.1, scale)

	model.Name = "Vlux_Prop_" .. def.Id

	if factor ~= 1 then
		model:ScaleTo(model:GetScale() * factor)
	end

	model:PivotTo(frame * CFrame.new(pivot[1] * factor, pivot[2] * factor, pivot[3] * factor) * MODEL_TURN)
	model.Parent = Geometry.GetScope() or workspace

	return model
end

--[[
	@param ctx Context
	@param def PropData.Prop
	@param hit RaycastResult
	@return CFrame? -- where the prop goes on the surface, or nil when the surface does not suit it
]]
local function frameOn(ctx: Context, def: PropData.Prop, hit: RaycastResult): CFrame?
	local round = Common.RoundTo(Cursor.Grid(ctx.Cursor))
	local normal = hit.Normal

	if def.Mount == "wall" then
		if math.abs(normal.Y) >= 0.5 then
			return nil
		end

		local at = Common.SnapOnSurface(hit.Position, normal, round)

		return CFrame.lookAt(at, at + Vector3.new(normal.X, 0, normal.Z).Unit)
	end

	if def.Mount == "ceiling" then
		if normal.Y > -0.7 then
			return nil
		end

		local at = Vector3.new(round(hit.Position.X), hit.Position.Y, round(hit.Position.Z))

		return CFrame.new(at) * CFrame.Angles(0, math.rad(ctx.Settings.Yaw), 0)
	end

	if normal.Y < 0.7 then
		return nil
	end

	local at = Vector3.new(round(hit.Position.X), hit.Position.Y, round(hit.Position.Z))

	return CFrame.new(at) * CFrame.Angles(0, math.rad(ctx.Settings.Yaw), 0)
end

local tool: Types.Tool = {
	Id = "Prop",
	Turns = true,
	Begin = function(): PropState
		return { Frame = nil }
	end,
	Preview = function(ctx: Context, state: PropState): Types.Preview?
		local id = ctx.State.Prop()
		local def = if id then PropData.Find(id) else nil
		local hit = Cursor.Hit(ctx.Cursor)

		if not def or not hit then
			return Common.Empty("Pick a prop in the Props tab.")
		end

		local frame = frameOn(ctx, def, hit)

		state.Frame = frame

		if not frame then
			return Common.Empty(
				if def.Mount == "wall"
					then "Point at a wall."
					elseif def.Mount == "ceiling" then "Point at the underside of a ceiling."
					else "Point at a floor or other flat top."
			)
		end

		local specs = Props.Build(def, frame, ctx.Settings.PropScale)

		return {
			Specs = specs,
			Valid = #specs > 0,
			Message = `Click to place the {def.Label}; R turns it.`,
		}
	end,
	Click = function(ctx: Context, state: PropState, shown: Types.Preview?)
		local id = ctx.State.Prop()

		if not shown or not shown.Valid or not id then
			return
		end

		local settings = ctx.Settings
		local def, frame, specs = PropData.Find(id), state.Frame, shown.Specs

		if settings.PropRandomRotation and def and frame and def.Mount ~= "wall" then
			local turn = (math.random() * 2 - 1) * settings.PropRandomAmount

			specs = Props.Build(def, frame * CFrame.Angles(0, math.rad(turn), 0), settings.PropScale)
		end

		ctx.Edit("Place prop", function()
			if def and frame and cloneModel(def, frame, settings.PropScale) then
				return
			end

			Geometry.Materialize(specs, "Vlux_Prop_" .. id):SetAttribute("VluxyBT_Prop", id)
		end)
	end,
}

return { tool }
