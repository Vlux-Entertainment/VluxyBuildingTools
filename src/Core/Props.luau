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
		local name = if part.glow then "PropGlow" elseif part.accent then "PropAccent" else "Prop"

		if part.shape == "Cylinder" then
			Geometry.Add(
				out,
				Vector3.new(part.sy, part.sx, part.sz) * factor,
				at * CFrame.Angles(0, 0, math.pi / 2),
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
	end

	return out
end

return Props
