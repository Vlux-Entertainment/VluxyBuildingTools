--!strict

--[=[
	Turns a built-in prop from `PropData` into the Parts to place: each shape is scaled, moved to
	the frame the prop stands in and given a name the color themes can read.

	@class Props
]=]

local Geometry = require("./Geometry")
local PropData = require("../Pure/PropData")

local Props = {}

--[=[
	@param prop PropData.Prop
	@param frame CFrame -- where the prop stands: on the floor, or against the wall for a wall prop, front toward the frame's look direction
	@param scale number
	@return { Geometry.Spec }
]=]
function Props.Build(prop: PropData.Prop, frame: CFrame, scale: number): { Geometry.Spec }
	local out: { Geometry.Spec } = {}
	local factor = math.max(0.1, scale)

	for _, part in prop.Parts do
		local at = frame * CFrame.new(part.x * factor, part.y * factor, part.z * factor)

		if part.yaw then
			at *= CFrame.Angles(0, math.rad(part.yaw), 0)
		end

		local name = if part.lamp
			then "PropLamp"
			elseif part.lights then "Config"
			elseif part.glow then "PropGlow"
			elseif part.accent then "PropAccent"
			else "Prop"

		if part.shape == "Cylinder" then
			Geometry.Add(
				out,
				Vector3.new(part.sy, part.sx, part.sz) * factor,
				if part.lay then at else at * CFrame.Angles(0, 0, math.pi / 2),
				name,
				nil,
				"Part"
			)
			out[#out].shape = "Cylinder"
		elseif part.shape == "Ball" then
			Geometry.Add(out, Vector3.new(part.sx, part.sy, part.sz) * factor, at, name, nil, "Part")
			out[#out].shape = "Ball"
		else
			Geometry.Add(out, Vector3.new(part.sx, part.sy, part.sz) * factor, at, name, nil, "Part")
		end

		out[#out].glow, out[#out].lamp, out[#out].lights = part.glow, part.lamp, part.lights
		out[#out].paint, out[#out].half = part.paint, part.half

		if part.lights then
			out[#out].cf = CFrame.new(at.Position)
		end
	end

	return out
end

--[=[
	Switches the lights of a placed prop on or off: its point and spot lights, and the glow of its bulbs.

	@param model Instance -- a placed prop
	@param lit boolean
]=]
function Props.SetLit(model: Instance, lit: boolean)
	for _, object in model:GetDescendants() do
		if object:IsA("Light") then
			object.Enabled = lit
		elseif object:IsA("BasePart") and object.Name == "PropGlow" then
			object.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
end

return Props
