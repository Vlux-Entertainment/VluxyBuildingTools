--!strict

--[=[
	The dock widget. Only the settings that matter for the current tool are shown. The panel holds
	no tool logic: every button calls back into the `Actions` the controller hands it.

	@class Panel
]=]

local Colors = require("../Core/Colors")
local Keymap = require("../Pure/Keymap")
local Settings = require("../Pure/Settings")
local SurfaceGrid = require("../Core/SurfaceGrid")

type Settings = Settings.Settings

export type Actions = {
	Activate: (name: string) -> (),
	Stop: () -> (),
	ResetPoint: () -> (),
	UseSelectedFloor: () -> (),
	RepeatCopies: () -> (),
	MirrorCopy: () -> (),
	SnapSelection: () -> (),
	ShowDimensions: () -> (),
	AnchorSelection: () -> (),
	Instruction: (mode: string?) -> string,
}

export type Deps = {
	Widget: DockWidgetPluginGui,
	Settings: Settings,
	Save: () -> (),
	Colors: Colors.Colors,
	SurfaceGrid: SurfaceGrid.SurfaceGrid,
	Actions: Actions,
	GetMode: () -> string?,
}

export type Panel = {
	Say: (text: string) -> (),
	Refresh: () -> (),
	SetField: (key: string) -> (),
	Highlight: (name: string?) -> (),
}

type Row = {
	Frame: Frame,
	Page: string?,
	Modes: { [string]: boolean }?,
	Advanced: boolean,
	Condition: (() -> boolean)?,
}

type Scope = {
	Page: string?,
	Modes: { [string]: boolean }?,
	Advanced: boolean?,
	Condition: (() -> boolean)?,
}

local PANEL_COLOR = Color3.fromRGB(27, 30, 38)
local ACCENT = Color3.fromRGB(115, 188, 171)
local TEXT_COLOR = Color3.fromRGB(230, 233, 239)
local BUTTON_COLOR = Color3.fromRGB(46, 51, 64)
local ACTIVE_COLOR = Color3.fromRGB(65, 112, 105)
local FIELD_COLOR = Color3.fromRGB(39, 44, 55)

local Panel = {}

--[[
	@param class string
	@param props { [string]: any }
	@param parent Instance

	@return Instance -- a new instance with the properties set, then parented
]]
local function make(class: string, props: { [string]: any }, parent: Instance): any
	local object = Instance.new(class)

	for key, value in props do
		(object :: any)[key] = value
	end

	object.Parent = parent

	return object
end

--[=[
	Builds the whole panel inside the widget.

	@param deps Deps
	@return Panel
]=]
function Panel.new(deps: Deps): Panel
	local settings, actions = deps.Settings, deps.Actions
	local scroll = make("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = PANEL_COLOR,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, deps.Widget)

	make("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 16),
	}, scroll)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)

	local order = 0
	local page = "Build"
	local advanced = false
	local rows: { Row } = {}
	local fieldBoxes: { [string]: TextBox } = {}
	local toolButtons: { [string]: TextButton } = {}
	local tabButtons: { [string]: TextButton } = {}

	local function newRow(height: number): Frame
		order += 1

		return make(
			"Frame",
			{ Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1, LayoutOrder = order },
			scroll
		)
	end

	local function register(frame: Frame, scope: Scope?)
		local s: Scope = scope or {}

		table.insert(rows, {
			Frame = frame,
			Page = s.Page,
			Modes = s.Modes,
			Advanced = s.Advanced == true,
			Condition = s.Condition,
		})
	end

	local function label(text: string, height: number?, color: Color3?, scope: Scope?): TextLabel
		local frame = newRow(height or 22)

		register(frame, scope)

		return make("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = text,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = color or TEXT_COLOR,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, frame)
	end

	label("VLUX  /  BLOCKOUT TOOLS", 26, ACCENT)
	label("2.1  •  Draw it. Drag it. Build it.", 20)

	local status = label("Choose a tool below. All dimensions are in studs.", 60, ACCENT)

	local function say(text: string)
		status.Text = text
	end

	local function refreshRows()
		local mode = deps.GetMode()

		for _, entry in rows do
			local visible = entry.Page == nil or entry.Page == page

			if entry.Modes then
				visible = visible and entry.Modes[mode or "None"] == true
			end

			if entry.Advanced then
				visible = visible and advanced
			end

			if entry.Condition then
				visible = visible and entry.Condition()
			end

			entry.Frame.Visible = visible
		end

		for title, button in tabButtons do
			button.BackgroundColor3 = if title == page then ACTIVE_COLOR else BUTTON_COLOR
		end
	end

	local function actionRow(items: { { Text: string, Run: () -> (), Tool: string? } }, scope: Scope?): { TextButton }
		local frame = newRow(34)
		local count = #items
		local result: { TextButton } = {}

		register(frame, scope)

		for i, item in items do
			local button = make("TextButton", {
				Size = UDim2.new(1 / count, -4, 1, 0),
				Position = UDim2.fromScale((i - 1) / count, 0),
				BackgroundColor3 = BUTTON_COLOR,
				BorderSizePixel = 0,
				Text = item.Text,
				TextWrapped = true,
				TextColor3 = TEXT_COLOR,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				AutoButtonColor = true,
			}, frame)

			make("UICorner", { CornerRadius = UDim.new(0, 5) }, button)
			button.MouseButton1Click:Connect(function()
				local ok, err = pcall(item.Run :: any)

				if not ok then
					say("Action stopped: " .. tostring(err))
					warn(err)
				end
			end)

			if item.Tool then
				toolButtons[item.Tool] = button
			end

			table.insert(result, button)
		end

		return result
	end

	local function section(text: string, scope: Scope?)
		label(text, 24, ACCENT, scope)
	end

	local function hint(text: string, height: number?, scope: Scope?)
		label(text, height or 44, nil, scope)
	end

	local function numeric(key: string, title: string, min: number, max: number, step: number?, scope: Scope?)
		local frame = newRow(30)
		local values = settings :: any

		register(frame, scope)
		make("TextLabel", {
			Size = UDim2.fromScale(0.49, 1),
			BackgroundTransparency = 1,
			Text = title,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = TEXT_COLOR,
		}, frame)

		local box = make("TextBox", {
			Size = UDim2.new(0.27, -4, 1, 0),
			Position = UDim2.fromScale(0.59, 0),
			BackgroundColor3 = FIELD_COLOR,
			BorderSizePixel = 0,
			Text = tostring(values[key]),
			TextColor3 = TEXT_COLOR,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			ClearTextOnFocus = false,
		}, frame)

		fieldBoxes[key] = box

		local function apply(value: number?)
			if value and value == value and math.abs(value) < math.huge then
				values[key] = math.clamp(value, min, max)

				if key == "Copies" or key == "ArchSegments" then
					values[key] = math.floor(values[key])
				end

				deps.Save()

				if key == "SurfaceGridSize" then
					SurfaceGrid.MarkDirty(deps.SurfaceGrid)
				end
			end

			box.Text = tostring(values[key])
		end

		box.FocusLost:Connect(function()
			apply(tonumber(box.Text))
		end)

		local steps: { { Direction: number, X: number, Text: string } } = {
			{ Direction = -1, X = 0.49, Text = "−" },
			{ Direction = 1, X = 0.86, Text = "+" },
		}

		for _, entry in steps do
			local button = make("TextButton", {
				Size = UDim2.new(0.10, -2, 1, 0),
				Position = UDim2.fromScale(entry.X, 0),
				BackgroundColor3 = BUTTON_COLOR,
				BorderSizePixel = 0,
				Text = entry.Text,
				TextColor3 = ACCENT,
				Font = Enum.Font.GothamBold,
				TextSize = 18,
			}, frame)

			button.MouseButton1Click:Connect(function()
				apply(values[key] + entry.Direction * (step or settings.Grid))
			end)
		end
	end

	local function tools(items: { { string } })
		local entries = {}

		for _, pair in items do
			local name = pair[1]

			table.insert(entries, {
				Text = pair[2],
				Run = function()
					actions.Activate(name)
				end,
				Tool = name,
			})
		end

		actionRow(entries, { Page = "Build" })
	end

	local displayButtons: { TextButton }
	local ceilingButton: TextButton
	local alignButton: TextButton
	local hotkeyButton: TextButton
	local axisButton: TextButton

	local function refresh()
		displayButtons[1].Text = "Pastel colors: " .. (if deps.Colors.On then "ON" else "OFF")
		displayButtons[2].Text = "Surface grid: " .. (if deps.SurfaceGrid.On then "ON" else "OFF")

		for i, on in { deps.Colors.On, deps.SurfaceGrid.On } do
			displayButtons[i].BackgroundColor3 = if on then ACTIVE_COLOR else BUTTON_COLOR
		end

		ceilingButton.Text = "Ceiling: " .. (if settings.Roof then "ON" else "OFF")
		alignButton.Text = "Tilt copy to surface: " .. (if settings.Align then "ON" else "OFF")
		hotkeyButton.Text = "Blender hotkeys: " .. (if settings.Hotkeys then "ON" else "OFF")
		hotkeyButton.BackgroundColor3 = if settings.Hotkeys then ACTIVE_COLOR else BUTTON_COLOR
		refreshRows()
	end

	displayButtons = actionRow({
		{
			Text = "Pastel colors: OFF",
			Run = function()
				Colors.Set(deps.Colors, not deps.Colors.On)
			end,
		},
		{
			Text = "Surface grid: OFF",
			Run = function()
				SurfaceGrid.SetOn(deps.SurfaceGrid, not deps.SurfaceGrid.On)
				refresh()
				say(
					if deps.SurfaceGrid.On
						then "Surface grid ON: world-aligned lines on nearby block and wedge Parts. Only you see this overlay."
						else "Surface grid OFF. No materials were changed."
				)
			end,
		},
	})

	numeric("SurfaceGridSize", "Surface grid size", 0.5, 128, 1, {
		Condition = function()
			return deps.SurfaceGrid.On
		end,
	})

	local tabs = actionRow({
		{
			Text = "Build",
			Run = function()
				actions.Stop()
				page = "Build"
				refresh()
				say("Choose a building tool.")
			end,
		},
		{
			Text = "Arrange",
			Run = function()
				actions.Stop()
				page = "Arrange"
				refresh()
				say("Select objects, then choose a layout action.")
			end,
		},
		{
			Text = "Help",
			Run = function()
				actions.Stop()
				page = "Help"
				refresh()
			end,
		},
	})

	tabButtons = { Build = tabs[1], Arrange = tabs[2], Help = tabs[3] }

	tools({ { "Wall", "Draw walls (1)" }, { "Corridor", "Draw corridor (2)" } })
	tools({ { "Room", "Draw room (3)" }, { "Block", "Draw block (4)" } })
	tools({ { "Stairs", "Draw stairs (5)" }, { "Ramp", "Draw ramp (6)" } })
	tools({ { "Arch", "Arch frame (7)" }, { "ArchOpening", "Arched doorway" } })
	tools({ { "Opening", "Door / window (8)" }, { "Extend", "Drag face extend" } })
	tools({ { "Place", "Stamp copies (9)" }, { "Measure", "Measure distance (0)" } })

	local hasMode = function()
		return deps.GetMode() ~= nil
	end

	actionRow({
		{
			Text = "Stop tool (Esc)",
			Run = function()
				actions.Stop()
				say("Tool stopped. Choose another tool whenever you are ready.")
			end,
		},
	}, { Page = "Build", Condition = hasMode })
	actionRow({
		{
			Text = "Start new chain",
			Run = function()
				actions.ResetPoint()
				say(actions.Instruction(deps.GetMode()))
			end,
		},
	}, { Page = "Build", Modes = { Wall = true, Corridor = true } })

	section("TOOL SETTINGS", { Page = "Build", Condition = hasMode })

	local drawModes =
		{ Wall = true, Corridor = true, Room = true, Block = true, Stairs = true, Ramp = true, Arch = true }
	local heightModes = { Wall = true, Corridor = true, Room = true, Block = true }
	local build = function(modes: { [string]: boolean }?, isAdvanced: boolean?): Scope
		return { Page = "Build", Modes = modes, Advanced = isAdvanced }
	end

	numeric("Grid", "Snap increment", 0.05, 128, 0.5, build(drawModes))
	numeric("Elevation", "Floor level (Y)", -10000, 10000, nil, build(drawModes))
	actionRow({
		{ Text = "Use selected floor height", Run = actions.UseSelectedFloor },
	}, build(drawModes))
	numeric("Height", "Height", 0.1, 2048, nil, build(heightModes))
	numeric(
		"Thickness",
		"Wall / frame thickness",
		0.05,
		128,
		nil,
		build({ Wall = true, Corridor = true, Room = true, Arch = true })
	)
	numeric("Width", "Clear width", 0.1, 1024, nil, build({ Corridor = true, Stairs = true, Ramp = true }))
	numeric("StairHeight", "Total stair rise", 0.1, 1024, nil, build({ Stairs = true }))
	numeric("RampHeight", "Ramp rise", 0.1, 1024, nil, build({ Ramp = true }))
	numeric("ArchHeight", "Clearance at arch top", 0.1, 1024, nil, build({ Arch = true }))
	numeric("ArchDepth", "Frame depth", 0.1, 256, nil, build({ Arch = true }))
	numeric("OpenWidth", "Opening width", 0.1, 1024, nil, build({ Opening = true, ArchOpening = true }))
	numeric("OpenHeight", "Opening height", 0.1, 1024, nil, build({ Opening = true, ArchOpening = true }))
	numeric("Sill", "Bottom above floor", 0, 1024, nil, build({ Opening = true }))

	local function preset(width: number, height: number, sill: number, text: string)
		settings.OpenWidth, settings.OpenHeight, settings.Sill = width, height, sill

		for _, key in { "OpenWidth", "OpenHeight", "Sill" } do
			fieldBoxes[key].Text = tostring((settings :: any)[key])
		end

		deps.Save()
		say(text)
	end

	actionRow({
		{
			Text = "Door preset",
			Run = function()
				preset(4, 8, 0, "Door: 4 studs wide, 8 high, starts at the wall bottom.")
			end,
		},
		{
			Text = "Window preset",
			Run = function()
				preset(5, 4, 3, "Window: 5 studs wide, 4 high, 3 studs above the wall bottom.")
			end,
		},
	}, build({ Opening = true }))

	numeric("Yaw", "Copy rotation", -360, 360, 90, build({ Place = true }))
	hint(
		"Select a source object before Stamp copies. Click a surface to place copies; R rotates by 90°. The original stays where it is.",
		60,
		build({ Place = true })
	)
	hint(
		"Click a block, then drag a GREEN HANDLE outward. Release to build. The next block is selected automatically so you can keep extending.",
		60,
		build({ Extend = true })
	)
	hint(
		"Click two surface points. A line and a STUD DISTANCE stay in the viewport. Click again for a new reading. Esc clears it.",
		60,
		build({ Measure = true })
	)
	hint(
		"X / Y / Z locks the drag to that axis (Shift = the plane). Type a number for an exact length. E extrudes the selected block.",
		60,
		build(drawModes)
	)

	actionRow({
		{
			Text = "More options ▾",
			Run = function()
				advanced = not advanced
				refreshRows()
			end,
		},
	}, { Page = "Build", Condition = hasMode })

	numeric("Run", "Approx. step depth", 0.1, 64, 0.25, build({ Stairs = true }, true))
	numeric("Landing", "Top landing depth", 0, 256, nil, build({ Stairs = true, Ramp = true }, true))
	numeric("Floor", "Floor / ceiling thickness", 0.05, 128, 0.25, build({ Room = true, Corridor = true }, true))
	numeric("ArchSegments", "Arch smoothness", 4, 48, 4, build({ Arch = true, ArchOpening = true }, true))
	numeric("Offset", "Surface gap", -256, 256, 0.25, build({ Place = true }, true))

	ceilingButton = actionRow({
		{
			Text = "Ceiling",
			Run = function()
				settings.Roof = not settings.Roof
				deps.Save()
				refresh()
			end,
		},
	}, build({ Room = true, Corridor = true }))[1]
	alignButton = actionRow({
		{
			Text = "Align copy to surface",
			Run = function()
				settings.Align = not settings.Align
				deps.Save()
				refresh()
			end,
		},
	}, build({ Place = true }, true))[1]

	section("REPEAT SELECTED OBJECTS", { Page = "Arrange" })
	numeric("Copies", "Extra copies", 1, 100, 1, { Page = "Arrange" })
	numeric("DX", "X spacing", -2048, 2048, nil, { Page = "Arrange" })
	numeric("DY", "Y spacing", -2048, 2048, nil, { Page = "Arrange" })
	numeric("DZ", "Z spacing", -2048, 2048, nil, { Page = "Arrange" })
	actionRow({ { Text = "Make repeated copies", Run = actions.RepeatCopies } }, { Page = "Arrange" })

	section("MIRROR SELECTED LAYOUT", { Page = "Arrange" })
	hint(
		"Reflects positions across world X=0, Y=0, or Z=0. Asymmetric mesh geometry keeps its original shape.",
		48,
		{ Page = "Arrange" }
	)

	local mirrorButtons = actionRow({
		{
			Text = "Axis: " .. settings.Axis,
			Run = function()
				settings.Axis = if settings.Axis == "X" then "Y" elseif settings.Axis == "Y" then "Z" else "X"
				axisButton.Text = "Axis: " .. settings.Axis
				deps.Save()
			end,
		},
		{ Text = "Make mirror copy", Run = actions.MirrorCopy },
	}, { Page = "Arrange" })

	axisButton = mirrorButtons[1]

	section("QUICK ACTIONS", { Page = "Arrange" })
	actionRow({
		{ Text = "Snap selection", Run = actions.SnapSelection },
		{ Text = "Show dimensions", Run = actions.ShowDimensions },
	}, { Page = "Arrange" })
	actionRow({ { Text = "Anchor selection", Run = actions.AnchorSelection } }, { Page = "Arrange" })

	section("QUICK GUIDE", { Page = "Help" })

	hotkeyButton = actionRow({
		{
			Text = "Blender hotkeys",
			Run = function()
				settings.Hotkeys = not settings.Hotkeys
				deps.Save()
				refresh()
			end,
		},
	}, { Page = "Help" })[1]

	section("HOTKEYS", { Page = "Help" })

	for _, binding in Keymap.Describe() do
		hint(`{binding[1]}  —  {binding[2]}`, 34, { Page = "Help" })
	end

	section("TIPS", { Page = "Help" })
	hint(
		"Draw tools: click the first point, move the mouse, then click again. The preview shows dimensions before you build.",
		58,
		{ Page = "Help" }
	)
	hint(
		"Walls and corridors continue from the last point. Start new chain begins somewhere else. Stop tool returns to normal Studio selection.",
		62,
		{ Page = "Help" }
	)
	hint(
		"Arch frame: draw the inside span across the ground. Arched doorway: click an existing plain wall to cut a curved opening.",
		62,
		{ Page = "Help" }
	)
	hint(
		"Pastel colors is a reversible whole-map toggle. It changes actual colors, visible to your team; switch it OFF before publishing.",
		62,
		{ Page = "Help" }
	)
	hint(
		"Surface grid is a local, world-aligned overlay on nearby rectangular Parts and WedgeParts. Up to 180 nearby Parts are shown at once.",
		62,
		{ Page = "Help" }
	)
	hint(
		"Door and arch openings replace a childless rectangular wall with separate Parts. Undo restores the original.",
		48,
		{ Page = "Help" }
	)
	hint(
		"All completed builds support Studio Undo/Redo. The plugin contains no runtime scripts for your game.",
		48,
		{ Page = "Help" }
	)

	refresh()

	return {
		Say = say,
		Refresh = refresh,
		SetField = function(key: string)
			local box = fieldBoxes[key]

			if box then
				box.Text = tostring((settings :: any)[key])
			end
		end,
		Highlight = function(name: string?)
			for toolName, button in toolButtons do
				button.BackgroundColor3 = if toolName == name then ACTIVE_COLOR else BUTTON_COLOR
			end
		end,
	}
end

return Panel
