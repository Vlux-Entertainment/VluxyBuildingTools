--!strict

--[=[
	Everything the tools draw into the viewport: the box previews, the construction grid, wedge
	outlines, the measuring line, the drag handles and the floating number. All of it lives in
	CoreGui, so only the person using the plugin sees it and nothing is saved in the place.

	@class Overlay
]=]

local CoreGui = game:GetService("CoreGui")

local Geometry = require("./Geometry")
local Trove = require("../Packages/Trove")

export type Overlay = {
	FaceHandles: Handles,
	_ghosts: { BoxHandleAdornment },
	_folder: Folder,
	_planeGrid: WireframeHandleAdornment,
	_previewWire: WireframeHandleAdornment,
	_measureLine: WireframeHandleAdornment,
	_hud: ScreenGui,
	_label: TextLabel,
	_readoutPosition: Vector3?,
}

local ACCENT = Color3.fromRGB(115, 188, 171)
local MAX_GHOSTS = 600
local WEDGE_EDGES = { { 1, 2 }, { 1, 3 }, { 2, 4 }, { 3, 4 }, { 3, 5 }, { 4, 6 }, { 5, 6 }, { 1, 5 }, { 2, 6 } }

local Overlay = {}

--[[
	@param parent Instance
	@param name string
	@param color Color3
	@param thickness number

	@return WireframeHandleAdornment -- one attached to Terrain, so its lines use world coordinates
]]
local function wire(parent: Instance, name: string, color: Color3, thickness: number): WireframeHandleAdornment
	local adornment = Instance.new("WireframeHandleAdornment")
	adornment.Name = name
	adornment.Adornee = workspace.Terrain
	adornment.Color3 = color
	adornment.Thickness = thickness
	adornment.AlwaysOnTop = false
	adornment.Parent = parent

	return adornment
end

--[=[
	@param trove Trove -- takes everything the overlay creates
	@return Overlay
]=]
function Overlay.new(trove: Trove.Trove): Overlay
	local folder = Instance.new("Folder")
	folder.Name = "VluxBlockout_LocalPreview"
	folder.Parent = CoreGui
	trove:Add(folder)

	local faceHandles = Instance.new("Handles")
	faceHandles.Name = "DragToExtend"
	faceHandles.Style = Enum.HandlesStyle.Resize
	faceHandles.Color3 = Color3.fromRGB(115, 220, 190)
	faceHandles.Visible = false
	faceHandles.Parent = folder

	local planeGrid = wire(folder, "ConstructionGrid", Color3.fromRGB(145, 165, 185), 1)
	planeGrid.Transparency = 0.65

	local previewWire = wire(folder, "ShapedPreviews", ACCENT, 2)
	local measureLine = wire(folder, "Measurement", ACCENT, 2)
	measureLine.AlwaysOnTop = true

	local hud = Instance.new("ScreenGui")
	hud.Name = "VluxBlockout_Readout"
	hud.IgnoreGuiInset = true
	hud.ResetOnSpawn = false
	hud.DisplayOrder = 1000
	hud.Enabled = false
	hud.Parent = CoreGui
	trove:Add(hud)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(210, 46)
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.BackgroundColor3 = Color3.fromRGB(23, 36, 40)
	label.BackgroundTransparency = 0.08
	label.BorderSizePixel = 0
	label.TextColor3 = Color3.fromRGB(187, 244, 224)
	label.TextSize = 16
	label.Font = Enum.Font.GothamBold
	label.TextWrapped = true
	label.Parent = hud

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = ACCENT
	stroke.Thickness = 1
	stroke.Parent = label

	return {
		FaceHandles = faceHandles,
		_ghosts = {},
		_folder = folder,
		_planeGrid = planeGrid,
		_previewWire = previewWire,
		_measureLine = measureLine,
		_hud = hud,
		_label = label,
		_readoutPosition = nil,
	}
end

--[=[
	Hides every box preview and clears the construction grid and wedge outlines.

	@param self Overlay
]=]
function Overlay.ClearGhosts(self: Overlay)
	for _, ghost in self._ghosts do
		ghost.Visible = false
	end

	self._planeGrid:Clear()
	self._previewWire:Clear()
end

--[=[
	Shows a translucent preview of each spec. Boxes use adornments; wedges are drawn as outlines.

	@param self Overlay
	@param specs { Geometry.Spec }
]=]
function Overlay.DrawGhosts(self: Overlay, specs: { Geometry.Spec })
	self._previewWire:Clear()

	local terrain = workspace.Terrain.CFrame
	local count = math.min(#specs, MAX_GHOSTS)

	for i = 1, count do
		local existing: BoxHandleAdornment? = self._ghosts[i]
		local ghost: BoxHandleAdornment

		if existing then
			ghost = existing
		else
			ghost = Instance.new("BoxHandleAdornment")
			ghost.Name = "Preview"
			ghost.Adornee = workspace.Terrain
			ghost.AlwaysOnTop = false
			ghost.ZIndex = 0
			ghost.Transparency = 0.55
			ghost.Color3 = ACCENT
			ghost.Parent = self._folder
			self._ghosts[i] = ghost
		end

		local spec = specs[i]

		ghost.Size = spec.size
		ghost.CFrame = terrain:ToObjectSpace(spec.cf)
		ghost.Visible = spec.class ~= "WedgePart"

		if spec.class == "WedgePart" then
			local h = spec.size / 2
			local vertices = {
				Vector3.new(-h.X, -h.Y, -h.Z),
				Vector3.new(h.X, -h.Y, -h.Z),
				Vector3.new(-h.X, -h.Y, h.Z),
				Vector3.new(h.X, -h.Y, h.Z),
				Vector3.new(-h.X, h.Y, h.Z),
				Vector3.new(h.X, h.Y, h.Z),
			}

			for _, edge in WEDGE_EDGES do
				self._previewWire:AddLine(
					terrain:PointToObjectSpace(spec.cf:PointToWorldSpace(vertices[edge[1]])),
					terrain:PointToObjectSpace(spec.cf:PointToWorldSpace(vertices[edge[2]]))
				)
			end
		end
	end

	for i = count + 1, #self._ghosts do
		self._ghosts[i].Visible = false
	end
end

--[=[
	Draws the snap grid on the plane around a point.

	@param self Overlay
	@param center Vector3 -- the snapped cursor point
	@param grid number -- the snap increment
]=]
function Overlay.DrawPlaneGrid(self: Overlay, center: Vector3, grid: number)
	local origin = Vector3.new(center.X, center.Y + 0.02, center.Z)
	local radius = grid * 15

	for i = -15, 15 do
		local x = origin.X + i * grid
		local z = origin.Z + i * grid

		self._planeGrid:AddLine(
			Vector3.new(x, origin.Y, origin.Z - radius),
			Vector3.new(x, origin.Y, origin.Z + radius)
		)
		self._planeGrid:AddLine(
			Vector3.new(origin.X - radius, origin.Y, z),
			Vector3.new(origin.X + radius, origin.Y, z)
		)
	end
end

--[=[
	Clears only the construction grid, leaving the previews.

	@param self Overlay
]=]
function Overlay.ClearPlaneGrid(self: Overlay)
	self._planeGrid:Clear()
end

--[=[
	Draws a coloured line along one world axis through a point, to show an axis lock.

	@param self Overlay
	@param origin Vector3
	@param axis "X" | "Y" | "Z"
]=]
function Overlay.DrawAxisLine(self: Overlay, origin: Vector3, axis: "X" | "Y" | "Z")
	local direction = if axis == "X" then Vector3.xAxis elseif axis == "Y" then Vector3.yAxis else Vector3.zAxis
	local colors =
		{ X = Color3.fromRGB(235, 90, 90), Y = Color3.fromRGB(110, 210, 110), Z = Color3.fromRGB(100, 140, 240) }

	self._previewWire.Color3 = colors[axis]
	self._previewWire:AddLine(origin - direction * 2000, origin + direction * 2000)
end

--[=[
	Puts the preview wire back to its normal colour; call after drawing axis lines.

	@param self Overlay
]=]
function Overlay.ResetWireColor(self: Overlay)
	self._previewWire.Color3 = ACCENT
end

--[=[
	Draws a measuring line with small crosses at both ends and shows its length.

	@param self Overlay
	@param a Vector3
	@param b Vector3
]=]
function Overlay.DrawMeasurement(self: Overlay, a: Vector3, b: Vector3)
	self._measureLine:Clear()

	local base = workspace.Terrain.CFrame

	self._measureLine:AddLine(base:PointToObjectSpace(a), base:PointToObjectSpace(b))

	for _, point in { a, b } do
		for _, axis in { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis } do
			self._measureLine:AddLine(
				base:PointToObjectSpace(point - axis * 0.18),
				base:PointToObjectSpace(point + axis * 0.18)
			)
		end
	end

	Overlay.Readout(self, (a + b) * 0.5, string.format("%.2f studs", (b - a).Magnitude))
end

--[=[
	@param self Overlay
]=]
function Overlay.ClearMeasurement(self: Overlay)
	self._measureLine:Clear()
end

--[=[
	Shows a floating label that follows a point in the world.

	@param self Overlay
	@param position Vector3
	@param text string
]=]
function Overlay.Readout(self: Overlay, position: Vector3, text: string)
	self._readoutPosition = position
	self._label.Text = text
	self._hud.Enabled = true
end

--[=[
	@param self Overlay
]=]
function Overlay.HideReadout(self: Overlay)
	self._hud.Enabled = false
end

--[=[
	Moves the floating label to follow its world point; call every frame.

	@param self Overlay
]=]
function Overlay.PositionReadout(self: Overlay)
	local position = self._readoutPosition
	local camera = workspace.CurrentCamera

	if not self._hud.Enabled or not position or not camera then
		return
	end

	local point, onScreen = camera:WorldToViewportPoint(position)

	self._label.Visible = onScreen and point.Z > 0
	self._label.Position = UDim2.fromOffset(point.X, point.Y - 16)
end

return Overlay
