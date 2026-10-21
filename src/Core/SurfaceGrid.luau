--!strict

--[=[
	A local, world-aligned grid drawn over nearby block and wedge Parts. Lines are the intersections of
	each face with world X, Y and Z planes, so the spacing stays fixed as Parts are scaled. Only the
	person using the plugin sees it.

	@class SurfaceGrid
]=]

local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

local Geometry = require("./Geometry")
local Trove = require("../Packages/Trove")

type Record = {
	obj: WireframeHandleAdornment,
	cf: CFrame?,
	size: Vector3?,
	spacing: number?,
}

export type SurfaceGrid = {
	On: boolean,
	_candidates: { [BasePart]: boolean },
	_records: { [BasePart]: Record },
	_dirty: boolean,
	_lastCamera: Vector3?,
	_folder: Folder,
}

type Line = { Vector3 }

local MAX_NEARBY = 180
local MAX_DISTANCE = 512
local MAX_LINES = 360
local PLANES_EACH_SIDE = 48
local REBUILDS_PER_UPDATE = 8
local CAMERA_MOVE = 16
local AXES = { "X", "Y", "Z" }

local SurfaceGrid = {}

--[[
	@param part BasePart

	@return boolean -- true for a visible block or wedge
]]
local function eligible(part: BasePart): boolean
	return (Geometry.IsPlainBlock(part) or part:IsA("WedgePart")) and part.Transparency < 1
end

--[[
	@param part BasePart

	@return { { Vector3 } } -- the part's faces as local-space corner loops
]]
local function partFaces(part: BasePart): { { Vector3 } }
	local h = part.Size / 2

	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x * h.X, y * h.Y, z * h.Z)
	end

	if part:IsA("WedgePart") then
		local a, b, c, d, e, f = v(-1, -1, -1), v(1, -1, -1), v(-1, -1, 1), v(1, -1, 1), v(-1, 1, 1), v(1, 1, 1)

		return { { a, b, d, c }, { c, d, f, e }, { a, c, e }, { b, f, d }, { a, e, f, b } }
	end

	return {
		{ v(-1, 1, -1), v(-1, 1, 1), v(1, 1, 1), v(1, 1, -1) },
		{ v(-1, -1, -1), v(1, -1, -1), v(1, -1, 1), v(-1, -1, 1) },
		{ v(-1, -1, -1), v(-1, -1, 1), v(-1, 1, 1), v(-1, 1, -1) },
		{ v(1, -1, -1), v(1, 1, -1), v(1, 1, 1), v(1, -1, 1) },
		{ v(-1, -1, 1), v(1, -1, 1), v(1, 1, 1), v(-1, 1, 1) },
		{ v(-1, -1, -1), v(-1, 1, -1), v(1, 1, -1), v(1, -1, -1) },
	}
end

--[[
	@param part BasePart
	@param spacing number
	@param camera Vector3

	@return { Line } -- local-space line ends, slightly lifted off the faces
]]
local function surfaceSegments(part: BasePart, spacing: number, camera: Vector3): { Line }
	local lines: { Line } = {}

	for _, face in partFaces(part) do
		local points: { Vector3 } = {}

		for _, corner in face do
			table.insert(points, part.CFrame:PointToWorldSpace(corner))
		end

		local normal = (points[2] - points[1]):Cross(points[3] - points[1]).Unit
		local center = Vector3.zero

		for _, point in points do
			center += point / #points
		end

		-- Wedge faces wind both ways, so pick the outward normal from the part's centre.
		if normal:Dot(center - part.Position) < 0 then
			normal = -normal
		end

		for _, axis in AXES do
			local low, high = math.huge, -math.huge

			for _, point in points do
				local value = (point :: any)[axis] :: number

				low = math.min(low, value)
				high = math.max(high, value)
			end

			if high - low > 0.001 then
				local near = math.round((camera :: any)[axis] / spacing)
				local firstPlane = math.max(math.ceil(low / spacing), near - PLANES_EACH_SIDE)
				local lastPlane = math.min(math.floor(high / spacing), near + PLANES_EACH_SIDE)

				for plane = firstPlane, lastPlane do
					local planeValue = plane * spacing
					local hits: { Vector3 } = {}

					local function addHit(hit: Vector3)
						for _, existing in hits do
							if (existing - hit).Magnitude < 0.0001 then
								return
							end
						end

						table.insert(hits, hit)
					end

					for i = 1, #points do
						local a = points[i]
						local b = points[i % #points + 1]
						local da = (a :: any)[axis] - planeValue
						local db = (b :: any)[axis] - planeValue

						if math.abs(da) < 0.00001 then
							addHit(a)
						end

						if da * db < 0 then
							addHit(a + (b - a) * (da / (da - db)))
						end
					end

					if #hits >= 2 and (hits[2] - hits[1]).Magnitude > 0.002 then
						table.insert(lines, {
							part.CFrame:PointToObjectSpace(hits[1] + normal * 0.012),
							part.CFrame:PointToObjectSpace(hits[2] + normal * 0.012),
						})

						if #lines >= MAX_LINES then
							return lines
						end
					end
				end
			end
		end
	end

	return lines
end

--[=[
	@param trove Trove -- holds the overlay folder and the connections
	@return SurfaceGrid
]=]
function SurfaceGrid.new(trove: Trove.Trove): SurfaceGrid
	local folder = Instance.new("Folder")
	folder.Name = "SurfaceGrid_LocalOnly"
	folder.Parent = CoreGui
	trove:Add(folder)

	local self: SurfaceGrid = {
		On = false,
		_candidates = {},
		_records = {},
		_dirty = true,
		_lastCamera = nil,
		_folder = folder,
	}

	for _, part in workspace:GetDescendants() do
		if part:IsA("BasePart") then
			self._candidates[part] = true
		end
	end

	trove:Connect(workspace.DescendantAdded, function(object)
		if object:IsA("BasePart") then
			self._candidates[object] = true
			self._dirty = true
		end
	end)
	trove:Connect(workspace.DescendantRemoving, function(object)
		if object:IsA("BasePart") and self._candidates[object] then
			self._candidates[object] = nil
			self._dirty = true
		end
	end)

	return self
end

--[=[
	Removes every grid overlay.

	@param self SurfaceGrid
]=]
function SurfaceGrid.Clear(self: SurfaceGrid)
	for _, record in self._records do
		record.obj:Destroy()
	end

	self._records = {}
	self._lastCamera = nil
	self._dirty = true
end

--[=[
	@param self SurfaceGrid
]=]
function SurfaceGrid.MarkDirty(self: SurfaceGrid)
	self._dirty = true
end

--[=[
	@param self SurfaceGrid
	@param value boolean
]=]
function SurfaceGrid.SetOn(self: SurfaceGrid, value: boolean)
	self.On = value

	if value then
		self._dirty = true
	else
		SurfaceGrid.Clear(self)
	end
end

--[=[
	Brings the overlays up to date with the camera and the Parts, rebuilding a few per call so a
	big scene does not stall a frame.

	@param self SurfaceGrid
	@param spacing number -- the grid size in studs
]=]
function SurfaceGrid.Update(self: SurfaceGrid, spacing: number)
	if not self.On or not RunService:IsEdit() then
		if next(self._records) then
			SurfaceGrid.Clear(self)
		end

		return
	end

	local camera = workspace.CurrentCamera

	if not camera then
		return
	end

	local position = camera.CFrame.Position
	local last = self._lastCamera

	if not last or (last - position).Magnitude > CAMERA_MOVE then
		self._dirty = true
	end

	if self._dirty then
		local nearby: { { part: BasePart, distance: number } } = {}

		for part in self._candidates do
			if part:IsDescendantOf(workspace) and eligible(part) then
				local distance = (part.Position - position).Magnitude - part.Size.Magnitude / 2

				if distance < MAX_DISTANCE then
					table.insert(nearby, { part = part, distance = distance })
				end
			end
		end

		table.sort(nearby, function(a, b)
			return a.distance < b.distance
		end)

		local keep: { [BasePart]: boolean } = {}

		for i = 1, math.min(#nearby, MAX_NEARBY) do
			keep[nearby[i].part] = true
		end

		for part, record in self._records do
			if not keep[part] then
				record.obj:Destroy()
				self._records[part] = nil
			end
		end

		for part in keep do
			local record = self._records[part]

			if not record then
				local obj = Instance.new("WireframeHandleAdornment")
				obj.Name = "WorldSurfaceGrid"
				obj.Adornee = part
				obj.Color3 = Color3.fromRGB(52, 62, 75)
				obj.Transparency = 0.22
				obj.Thickness = 1
				obj.AlwaysOnTop = false
				obj.Parent = self._folder
				self._records[part] = { obj = obj }
			else
				record.cf = nil
			end
		end

		self._lastCamera = position
		self._dirty = false
	end

	local budget = REBUILDS_PER_UPDATE

	for part, record in self._records do
		if not part:IsDescendantOf(workspace) or not eligible(part) then
			record.obj:Destroy()
			self._records[part] = nil
			self._dirty = true
		elseif record.cf ~= part.CFrame or record.size ~= part.Size or record.spacing ~= spacing then
			record.obj:Clear()

			for _, line in surfaceSegments(part, spacing, position) do
				record.obj:AddLine(line[1], line[2])
			end

			record.cf, record.size, record.spacing = part.CFrame, part.Size, spacing
			budget -= 1

			if budget <= 0 then
				break
			end
		end
	end
end

return SurfaceGrid
