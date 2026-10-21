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
	_bar: ScreenGui,
	_barGlyph: TextLabel,
	_barText: TextLabel,
	_barHints: Frame,
	_readoutPosition: Vector3?,
}

local ACCENT = Color3.fromRGB(60, 214, 120)
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
	label.BackgroundColor3 = Color3.fromRGB(28, 29, 33)
	label.BackgroundTransparency = 0.08
	label.BorderSizePixel = 0
	label.TextColor3 = Color3.fromRGB(240, 241, 244)
	label.TextSize = 15
	label.Font = Enum.Font.GothamMedium
	label.TextWrapped = true
	label.Parent = hud

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(96, 98, 106)
	stroke.Thickness = 1
	stroke.Parent = label

	local bar = Instance.new("ScreenGui")
	bar.Name = "VluxBlockout_StatusBar"
	bar.IgnoreGuiInset = true
	bar.ResetOnSpawn = false
	bar.DisplayOrder = 999
	bar.Enabled = false
	bar.Parent = CoreGui
	trove:Add(bar)

	local strip = Instance.new("Frame")
	strip.Size = UDim2.new(1, 0, 0, 46)
	strip.AnchorPoint = Vector2.new(0, 1)
	strip.Position = UDim2.fromScale(0, 1)
	strip.BackgroundColor3 = Color3.fromRGB(24, 25, 28)
	strip.BackgroundTransparency = 0.04
	strip.BorderSizePixel = 0
	strip.Parent = bar

	local glyphBox = Instance.new("Frame")
	glyphBox.Size = UDim2.fromOffset(34, 34)
	glyphBox.Position = UDim2.fromOffset(12, 6)
	glyphBox.BackgroundColor3 = Color3.fromRGB(34, 36, 41)
	glyphBox.BorderSizePixel = 0
	glyphBox.Parent = strip

	local glyphCorner = Instance.new("UICorner")
	glyphCorner.CornerRadius = UDim.new(0, 6)
	glyphCorner.Parent = glyphBox

	local glyphStroke = Instance.new("UIStroke")
	glyphStroke.Color = Color3.fromRGB(70, 72, 80)
	glyphStroke.Parent = glyphBox

	local barGlyph = Instance.new("TextLabel")
	barGlyph.Size = UDim2.fromScale(1, 1)
	barGlyph.BackgroundTransparency = 1
	barGlyph.TextColor3 = Color3.fromRGB(240, 241, 244)
	barGlyph.Font = Enum.Font.GothamMedium
	barGlyph.TextSize = 22
	barGlyph.Parent = glyphBox

	local barText = Instance.new("TextLabel")
	barText.Size = UDim2.new(0.55, -60, 1, 0)
	barText.Position = UDim2.fromOffset(56, 0)
	barText.BackgroundTransparency = 1
	barText.RichText = true
	barText.TextColor3 = Color3.fromRGB(160, 163, 171)
	barText.Font = Enum.Font.Gotham
	barText.TextSize = 13
	barText.TextXAlignment = Enum.TextXAlignment.Left
	barText.TextTruncate = Enum.TextTruncate.AtEnd
	barText.Parent = strip

	local barHints = Instance.new("Frame")
	barHints.Size = UDim2.new(0.45, -12, 1, 0)
	barHints.AnchorPoint = Vector2.new(1, 0)
	barHints.Position = UDim2.fromScale(1, 0)
	barHints.BackgroundTransparency = 1
	barHints.Parent = strip

	local hintLayout = Instance.new("UIListLayout")
	hintLayout.FillDirection = Enum.FillDirection.Horizontal
	hintLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	hintLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	hintLayout.Padding = UDim.new(0, 14)
	hintLayout.Parent = barHints

	return {
		FaceHandles = faceHandles,
		_ghosts = {},
		_folder = folder,
		_planeGrid = planeGrid,
		_previewWire = previewWire,
		_measureLine = measureLine,
		_hud = hud,
		_label = label,
		_bar = bar,
		_barGlyph = barGlyph,
		_barText = barText,
		_barHints = barHints,
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

--[=[
	Shows the bar along the bottom of the viewport: the active tool, what to do next, and the keys
	that matter right now.

	@param self Overlay
	@param glyph string -- the tool's icon character
	@param name string
	@param message string
	@param hints { { string } } -- pairs of { key, meaning }
]=]
function Overlay.SetBar(self: Overlay, glyph: string, name: string, message: string, hints: { { string } })
	self._barGlyph.Text = glyph
	self._barText.Text = '<font color="#F0F1F4"><b>' .. name .. "</b></font>   •   " .. message

	for _, child in self._barHints:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for index, hint in hints do
		local group = Instance.new("Frame")
		group.AutomaticSize = Enum.AutomaticSize.X
		group.Size = UDim2.fromOffset(0, 26)
		group.BackgroundTransparency = 1
		group.LayoutOrder = index
		group.Parent = self._barHints

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 6)
		layout.Parent = group

		local chip = Instance.new("TextLabel")
		chip.AutomaticSize = Enum.AutomaticSize.X
		chip.Size = UDim2.fromOffset(0, 24)
		chip.BackgroundColor3 = Color3.fromRGB(34, 36, 41)
		chip.BorderSizePixel = 0
		chip.Text = hint[1]
		chip.TextColor3 = Color3.fromRGB(240, 241, 244)
		chip.Font = Enum.Font.GothamMedium
		chip.TextSize = 12
		chip.LayoutOrder = 1
		chip.Parent = group

		local chipCorner = Instance.new("UICorner")
		chipCorner.CornerRadius = UDim.new(0, 5)
		chipCorner.Parent = chip

		local chipStroke = Instance.new("UIStroke")
		chipStroke.Color = Color3.fromRGB(70, 72, 80)
		chipStroke.Parent = chip

		local chipPadding = Instance.new("UIPadding")
		chipPadding.PaddingLeft = UDim.new(0, 8)
		chipPadding.PaddingRight = UDim.new(0, 8)
		chipPadding.Parent = chip

		local meaning = Instance.new("TextLabel")
		meaning.AutomaticSize = Enum.AutomaticSize.X
		meaning.Size = UDim2.fromOffset(0, 24)
		meaning.BackgroundTransparency = 1
		meaning.Text = hint[2]
		meaning.TextColor3 = Color3.fromRGB(160, 163, 171)
		meaning.Font = Enum.Font.Gotham
		meaning.TextSize = 12
		meaning.LayoutOrder = 2
		meaning.Parent = group
	end

	self._bar.Enabled = true
end

--[=[
	@param self Overlay
]=]
function Overlay.HideBar(self: Overlay)
	self._bar.Enabled = false
end

return Overlay
