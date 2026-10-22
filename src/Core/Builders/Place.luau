--!strict

--[=[
	Copies of an object seated on a surface, for the brush.

	Part of the builders: each takes the clicked points and the settings and returns Part specs.
	Nothing here changes the place; the specs are previewed, then built by `Geometry`.

	@class Place
]=]

local Geometry = require("../Geometry")
local Settings = require("../../Pure/Settings")
local Shapes = require("./Shapes")

type Settings = Settings.Settings
type Spec = Geometry.Spec
type Source = Shapes.Source

local Place = {}

local add = Geometry.Add

--[=[
	Copies of the source selection, seated flush on the surface under the cursor.

	@param settings Settings
	@param hit RaycastResult? -- what the cursor is over
	@param source Source? -- the selection being stamped
	@return { Spec }
	@return string -- what to tell the user
	@return CFrame? -- where the source's pivot lands
]=]
function Place.Place(
	settings: Settings,
	hit: RaycastResult?,
	source: Source?,
	scale: number?
): ({ Spec }, string, CFrame?)
	local out: { Spec } = {}

	if not hit or not source then
		return out, "Select an object, then choose Brush.", nil
	end

	for _, part in source.Parts do
		if not part:IsDescendantOf(game) then
			return out, "Selection changed; choose Brush again.", nil
		end
	end

	local specs, target = Place.PlaceAt(settings, hit.Position, hit.Normal, source, settings.Yaw, scale)

	return specs, "Click or drag to paint copies onto surfaces.", target
end

--[=[
	One copy of the source seated flush on a surface point.

	@param settings Settings
	@param position Vector3 -- where the surface is
	@param normal Vector3 -- which way the surface faces
	@param source Source
	@param yaw number -- turn about the surface normal, in degrees
	@param scale number? -- how much bigger or smaller than the original, 1 when left out
	@return { Spec }
	@return CFrame -- where the source's pivot lands
]=]
function Place.PlaceAt(
	settings: Settings,
	position: Vector3,
	normal: Vector3,
	source: Source,
	yaw: number,
	scale: number?
): ({ Spec }, CFrame)
	local out: { Spec } = {}
	local grow = scale or 1
	local rot = CFrame.Angles(0, math.rad(yaw), 0)

	if settings.Align then
		local reference = if math.abs(normal.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
		local right = reference:Cross(normal).Unit

		rot = CFrame.fromMatrix(Vector3.zero, right, normal, right:Cross(normal)) * rot
	end

	-- Project the rotated bounding box onto the hit normal to seat it flush.
	local radius = (
		math.abs(normal:Dot(rot.RightVector)) * source.Size.X
		+ math.abs(normal:Dot(rot.UpVector)) * source.Size.Y
		+ math.abs(normal:Dot(rot.LookVector)) * source.Size.Z
	)
		/ 2
		* grow
	local target = CFrame.new(position + normal * (radius + settings.Offset)) * rot

	for _, part in source.Parts do
		local relative = source.Pivot:ToObjectSpace(part.CFrame)
		local scaled = CFrame.new(relative.Position * grow) * (relative - relative.Position)

		add(out, part.Size * grow, target * scaled, part.Name)
	end

	return out, target
end

return Place
