--!strict

--[=[
	Openings cut into a wall (doorways, windows, archways, any outlined shape) and the face
	extension of a block.

	Part of the builders: each takes the clicked points and the settings and returns Part specs.
	Nothing here changes the place; the specs are previewed, then built by `Geometry`.

	@class Openings
]=]

local Geometry = require("../Geometry")
local Settings = require("../../Pure/Settings")
local Shapes = require("./Shapes")
local Snap = require("../../Pure/Snap")

type Settings = Settings.Settings
type Spec = Geometry.Spec
type Cutter = Shapes.Cutter

local Openings = {}

local add = Geometry.Add
local trianglePrism = Shapes.TrianglePrism
local quadPrism = Shapes.QuadPrism

--[=[
	Cuts a door, window or arched doorway into the plain wall under the cursor, by rebuilding the
	wall as separate Parts around the hole.

	@param settings Settings
	@param dims { Width: number, Height: number, Sill: number } -- the opening to cut
	@param hit RaycastResult? -- what the cursor is over
	@param shape string -- which opening to cut
	@param depth number? -- how far the opening goes into the wall
	@return { Spec }
	@return string -- what to tell the user
	@return BasePart? -- the wall to delete when the opening is built
]=]
function Openings.Opening(
	settings: Settings,
	dims: {
		Width: number,
		Height: number,
		Sill: number,
		Panel: boolean?,
		Frame: boolean?,
		FrameWidth: number?,
		FrameDepth: number?,
		DoorThickness: number?,
		DoorTransparency: number?,
		DoorCollide: boolean?,
	},
	hit: RaycastResult?,
	shape: string,
	depth: number?
): ({ Spec }, string, BasePart?, { cf: CFrame, size: Vector3 }?, { Cutter }?)
	local out: { Spec } = {}
	local wall = hit and hit.Instance
	local plain = Geometry.IsPlainBlock(wall)
	local carvable = wall ~= nil
		and wall:IsA("BasePart")
		and not wall:IsA("Terrain")
		and (wall.ClassName == "UnionOperation" or wall.ClassName == "Part")

	if not hit or not wall or not (plain or carvable) then
		return out, "Click a Part or union wall (not a mesh, wedge or terrain).", nil
	end

	local carve = not plain

	local p = wall :: Part

	for _, child in p:GetChildren() do
		if not (child:IsA("Texture") and child.Name == "VluxGridTexture") then
			return out, "Use a plain wall with no openings yet.", nil
		end
	end

	if p.Locked then
		return out, "Unlock the wall before creating an opening.", nil
	end

	local cf = p.CFrame
	local size = p.Size

	if size.Z > size.X then
		cf = cf * CFrame.Angles(0, math.pi / 2, 0)
		size = Vector3.new(size.Z, size.Y, size.X)
	end

	local arched = shape == "Arch"
	local w, h = dims.Width, dims.Height
	local sill = if arched then 0 else dims.Sill
	local framed = dims.Frame == true and shape == "Rect" and not (depth and depth < size.Z - 0.01)
	local bar = if framed then math.min(dims.FrameWidth or 0.25, w / 4, h / 4) else 0

	if framed then
		w += 2 * bar
		h += bar
	end

	if arched and h < w / 2 then
		return out, "Arch height must be at least half the opening width.", nil
	end

	if carve and shape == "Triangle" then
		return out, "The triangle window needs a plain Part wall.", nil
	end

	local localHit = cf:PointToObjectSpace(hit.Position)
	local x = Snap.Round(localHit.X, settings.Grid)
	local bottom = -size.Y / 2 + sill
	local top = bottom + h
	local left, right = x - w / 2, x + w / 2

	if left <= -size.X / 2 + 0.01 or right >= size.X / 2 - 0.01 or sill < 0 or top > size.Y / 2 + 0.001 then
		return out, "Opening must fit inside the wall, with wall remaining on both sides.", nil
	end

	if (framed or dims.Panel) and shape == "Rect" and not (depth and depth < size.Z - 0.01) then
		local reach = dims.FrameDepth or 1.1
		local doorHeight = h - bar

		if framed then
			local sideX = w / 2 - bar / 2

			add(
				out,
				Vector3.new(bar, doorHeight, reach),
				cf * CFrame.new(x - sideX, bottom + doorHeight / 2, 0),
				"Door_Frame"
			)
			add(
				out,
				Vector3.new(bar, doorHeight, reach),
				cf * CFrame.new(x + sideX, bottom + doorHeight / 2, 0),
				"Door_Frame"
			)
			add(out, Vector3.new(w, bar, reach), cf * CFrame.new(x, bottom + h - bar / 2, 0), "Door_Frame")
		end

		if dims.Panel then
			add(
				out,
				Vector3.new(w - 2 * bar, doorHeight, math.min(size.Z, dims.DoorThickness or 0.2)),
				cf * CFrame.new(x, bottom + doorHeight / 2, 0),
				"Door_Panel"
			)

			out[#out].transparency = dims.DoorTransparency
			out[#out].collide = dims.DoorCollide
		end
	end

	if carve then
		local reach = if depth and depth < size.Z - 0.01 then depth else size.Z + 0.2
		local near = if localHit.Z >= 0 then 1 else -1
		local zMid = if depth and depth < size.Z - 0.01 then near * (size.Z / 2 - reach / 2) else 0
		local cutters: { Cutter } = {}

		if shape == "Circle" then
			local diameter = math.min(w, h)

			table.insert(cutters, {
				cf = cf * CFrame.new(x, bottom + diameter / 2, zMid) * CFrame.Angles(0, math.pi / 2, 0),
				size = Vector3.new(reach, diameter, diameter),
				cylinder = true,
			})
		else
			local boxHeight = if arched then h - w / 2 else h

			table.insert(cutters, {
				cf = cf * CFrame.new(x, bottom + boxHeight / 2, zMid),
				size = Vector3.new(w, boxHeight, reach),
				cylinder = false,
			})

			if arched then
				table.insert(cutters, {
					cf = cf * CFrame.new(x, bottom + h - w / 2, zMid) * CFrame.Angles(0, math.pi / 2, 0),
					size = Vector3.new(reach, w, w),
					cylinder = true,
				})
			end
		end

		local openHeight = if shape == "Circle" then math.min(w, h) else h
		local openWidth = if shape == "Circle" then math.min(w, h) else w
		local shown = {
			cf = cf * CFrame.new(x, bottom + openHeight / 2, near * (size.Z / 2 - math.min(reach, size.Z) / 2)),
			size = Vector3.new(openWidth, openHeight, math.min(reach, size.Z)),
		}

		return out, "Click to cut this wall.", p, shown, cutters
	end

	add(
		out,
		Vector3.new(left + size.X / 2, size.Y, size.Z),
		cf * CFrame.new((-size.X / 2 + left) / 2, 0, 0),
		"Opening_Left",
		p
	)
	add(
		out,
		Vector3.new(size.X / 2 - right, size.Y, size.Z),
		cf * CFrame.new((right + size.X / 2) / 2, 0, 0),
		"Opening_Right",
		p
	)

	if shape == "Circle" then
		local radius = math.min(w, h) / 2
		local cy = bottom + radius
		local count = math.max(8, math.floor(settings.ArchSegments) * 2)
		local wallTop, wallBottom = size.Y / 2, -size.Y / 2

		for i = 0, count - 1 do
			local from = math.pi - i * math.pi / count
			local to = math.pi - (i + 1) * math.pi / count

			for _, side in { 1, -1 } do
				local x1, y1 = x + radius * math.cos(from), cy + side * radius * math.sin(from)
				local x2, y2 = x + radius * math.cos(to), cy + side * radius * math.sin(to)
				local edge = if side == 1 then wallTop else wallBottom

				quadPrism(
					out,
					cf:PointToWorldSpace(Vector3.new(x1, y1, 0)),
					cf:PointToWorldSpace(Vector3.new(x2, y2, 0)),
					cf:PointToWorldSpace(Vector3.new(x2, edge, 0)),
					cf:PointToWorldSpace(Vector3.new(x1, edge, 0)),
					size.Z,
					if side == 1 then "Circle_Upper" else "Circle_Lower",
					p
				)
			end
		end
	elseif shape == "Triangle" then
		local apex = Vector3.new(x, top, 0)
		local wallTop = size.Y / 2

		for _, side in { -1, 1 } do
			local corner = Vector3.new(x + side * w / 2, bottom, 0)
			local a = if side == -1 then corner else apex
			local b = if side == -1 then apex else corner

			quadPrism(
				out,
				cf:PointToWorldSpace(a),
				cf:PointToWorldSpace(b),
				cf:PointToWorldSpace(Vector3.new(b.X, wallTop, 0)),
				cf:PointToWorldSpace(Vector3.new(a.X, wallTop, 0)),
				size.Z,
				"Triangle_Frame",
				p
			)
		end
	elseif arched then
		local radius = w / 2
		local spring = bottom + h - radius
		local count = math.floor(settings.ArchSegments)

		for i = 0, count - 1 do
			local from = math.pi - i * math.pi / count
			local to = math.pi - (i + 1) * math.pi / count
			local x1, y1 = x + radius * math.cos(from), spring + radius * math.sin(from)
			local x2, y2 = x + radius * math.cos(to), spring + radius * math.sin(to)

			quadPrism(
				out,
				cf:PointToWorldSpace(Vector3.new(x1, y1, 0)),
				cf:PointToWorldSpace(Vector3.new(x2, y2, 0)),
				cf:PointToWorldSpace(Vector3.new(x2, size.Y / 2, 0)),
				cf:PointToWorldSpace(Vector3.new(x1, size.Y / 2, 0)),
				size.Z,
				"Arch_Header",
				p
			)
		end
	else
		add(
			out,
			Vector3.new(w, size.Y / 2 - top, size.Z),
			cf * CFrame.new(x, (top + size.Y / 2) / 2, 0),
			"Opening_Header",
			p
		)
	end

	if sill > 0 then
		add(out, Vector3.new(w, sill, size.Z), cf * CFrame.new(x, -size.Y / 2 + sill / 2, 0), "Opening_Sill", p)
	end

	if depth and depth < size.Z - 0.01 then
		local back = size.Z - depth
		local side = if localHit.Z >= 0 then -1 else 1
		local z = side * (size.Z / 2 - back / 2)

		local function at(px: number, py: number): Vector3
			return cf:PointToWorldSpace(Vector3.new(px, py, z))
		end

		if shape == "Circle" then
			local radius = math.min(w, h) / 2
			local cy = bottom + radius
			local count = math.max(8, math.floor(settings.ArchSegments) * 2)

			for i = 0, count - 1 do
				local from = math.pi - i * math.pi / count
				local to = math.pi - (i + 1) * math.pi / count
				local x1, x2 = x + radius * math.cos(from), x + radius * math.cos(to)
				local s1, s2 = radius * math.sin(from), radius * math.sin(to)

				quadPrism(
					out,
					at(x1, cy + s1),
					at(x2, cy + s2),
					at(x2, cy - s2),
					at(x1, cy - s1),
					back,
					"Opening_Back",
					p
				)
			end
		elseif shape == "Triangle" then
			trianglePrism(out, at(x - w / 2, bottom), at(x, top), at(x + w / 2, bottom), back, "Opening_Back", p)
		elseif arched then
			local radius = w / 2
			local spring = bottom + h - radius
			local count = math.floor(settings.ArchSegments)

			add(
				out,
				Vector3.new(w, spring - bottom, back),
				cf * CFrame.new(x, (bottom + spring) / 2, z),
				"Opening_Back",
				p
			)

			for i = 0, count - 1 do
				local from = math.pi - i * math.pi / count
				local to = math.pi - (i + 1) * math.pi / count
				local x1, y1 = x + radius * math.cos(from), spring + radius * math.sin(from)
				local x2, y2 = x + radius * math.cos(to), spring + radius * math.sin(to)

				quadPrism(out, at(x1, y1), at(x2, y2), at(x2, spring), at(x1, spring), back, "Opening_Back", p)
			end
		else
			add(out, Vector3.new(w, h, back), cf * CFrame.new(x, (bottom + top) / 2, z), "Opening_Back", p)
		end
	end

	local reach = if depth and depth < size.Z - 0.01 then depth else size.Z
	local openHeight = if shape == "Circle" then math.min(w, h) else h
	local openWidth = if shape == "Circle" then math.min(w, h) else w
	local near = if localHit.Z >= 0 then 1 else -1
	local cut = {
		cf = cf * CFrame.new(x, bottom + openHeight / 2, near * (size.Z / 2 - reach / 2)),
		size = Vector3.new(openWidth, openHeight, reach),
	}

	return out, "Click to cut an opening in this wall.", p, cut
end

--[=[
	The tool that cuts a polygon out of a wall: each triangle of the polygon is extruded through
	the wall as a pair of wedges, to be subtracted from it.

	@param corners { Vector3 } -- the polygon's corners, on the face of the wall
	@param triangles { { number } } -- triples of indexes into corners
	@param depth number -- how far the cut reaches, centred on the corners moved by `shift`
	@param shift Vector3 -- where the corners move to, into the middle of the wall
	@return { Spec }
]=]
function Openings.CutShape(corners: { Vector3 }, triangles: { { number } }, depth: number, shift: Vector3): { Spec }
	local out: { Spec } = {}

	for _, t in triangles do
		local a, b, c = corners[t[1]] + shift, corners[t[2]] + shift, corners[t[3]] + shift
		local middle = (a + b + c) / 3

		--[[ Each triangle is a hair bigger so neighbours overlap and no sliver is left between them. ]]
		local function grow(p: Vector3): Vector3
			local away = p - middle

			return if away.Magnitude > 0.001 then p + away.Unit * 0.03 else p
		end

		trianglePrism(out, grow(a), grow(b), grow(c), depth, "Cut", nil, 0.03)
	end

	return out
end

--[=[
	Works out which local axis a face normal points along. Used to grow a block out of that face.

	@param part BasePart
	@param normal Vector3 -- world-space face normal
	@return number -- 1, 2 or 3 for the part's X, Y or Z axis
	@return number -- 1 or -1, the side of that axis
]=]
function Openings.FaceAxis(part: BasePart, normal: Vector3): (number, number)
	local n = part.CFrame:VectorToObjectSpace(normal)
	local axis = 1

	if math.abs(n.Y) > math.abs(n.X) then
		axis = 2
	end

	if math.abs(n.Z) > math.abs(if axis == 1 then n.X else n.Y) then
		axis = 3
	end

	local component = if axis == 1 then n.X elseif axis == 2 then n.Y else n.Z

	return axis, if component >= 0 then 1 else -1
end

--[=[
	A block of the same size as a face, grown outward from that face.

	@param settings Settings
	@param part BasePart -- the block being extended
	@param normal Vector3 -- world-space normal of the face
	@param distance number? -- how far to grow; the panel's Extend setting when left out
	@return { Spec }
]=]
function Openings.Extend(settings: Settings, part: BasePart, normal: Vector3, distance: number?): { Spec }
	local out: { Spec } = {}
	local axis, side = Openings.FaceAxis(part, normal)
	local unit = if axis == 1 then Vector3.xAxis elseif axis == 2 then Vector3.yAxis else Vector3.zAxis
	local old = if axis == 1 then part.Size.X elseif axis == 2 then part.Size.Y else part.Size.Z
	local length = distance or settings.Extend
	local size = if axis == 1
		then Vector3.new(length, part.Size.Y, part.Size.Z)
		elseif axis == 2 then Vector3.new(part.Size.X, length, part.Size.Z)
		else Vector3.new(part.Size.X, part.Size.Y, length)

	add(out, size, part.CFrame * CFrame.new(unit * side * (old + length) / 2), "FaceExtension", part)

	return out
end

return Openings
