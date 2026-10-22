--!strict

--[=[
	The dock widget: a header, five tabs (Build, Arrange, Display, Settings, Hotkeys) and the cards in
	each. Only the settings that matter for the active tool are shown. The panel holds no tool logic;
	every button calls back into the `Actions` the controller hands it.

	@class Panel
]=]

local Brushes = require("../Core/Brushes")
local Colors = require("../Core/Colors")
local Hidden = require("../Core/Hidden")
local Keymap = require("../Pure/Keymap")
local PluginInfo = require("../Pure/PluginInfo")
local PropData = require("../Pure/PropData")
local Props = require("../Core/Props")
local Settings = require("../Pure/Settings")
local SurfaceGrid = require("../Core/SurfaceGrid")
local Tips = require("../Pure/Tips")
local Tools = require("../Pure/Tools")

type Settings = Settings.Settings

export type Actions = {
	Activate: (name: string) -> (),
	SetMode: (name: string) -> (),
	PickProp: (id: string) -> (),
	Stop: () -> (),
	ResetPoint: () -> (),
	BrushesChanged: () -> (),
	UseSelectedFloor: () -> (),
	RepeatCopies: () -> (),
	SnapSelection: () -> (),
	ShowDimensions: () -> (),
	AnchorSelection: () -> (),
	Instruction: (mode: string?) -> string,
	Flip: (axis: string) -> (),
	RotateBy: (axis: string, degrees: number) -> (),
	StartPick: () -> (),
	CancelPick: () -> (),
	ConfirmPick: () -> (),
	ResolveTheme: (choice: string) -> (),
	UnhideAll: () -> (),
	ToggleHiddenView: () -> (),
}

export type Deps = {
	Widget: DockWidgetPluginGui,
	Settings: Settings,
	Save: () -> (),
	Colors: Colors.Colors,
	GetTheme: () -> string,
	SetTheme: (string) -> (),
	SurfaceGrid: SurfaceGrid.SurfaceGrid,
	Actions: Actions,
	GetMode: () -> string?,
	GetProp: () -> string?,
	GetConflict: () -> string?,
	GetFolder: () -> Instance?,
	GetPending: () -> Instance?,
	GetPicking: () -> boolean,
	Hidden: Hidden.Hidden,
}

export type Panel = {
	Say: (text: string) -> (),
	Refresh: () -> (),
	SetField: (key: string) -> (),
	CycleTab: (delta: number) -> (),
	ShowTab: (name: string) -> (),
	StepSection: (delta: number) -> (),
	StepProp: (delta: number) -> (),
	OnPropsTab: () -> boolean,
}

type Entry = {
	Frame: GuiObject,
	Modes: { [string]: boolean }?,
	Advanced: boolean,
	Condition: (() -> boolean)?,
}

type Scope = {
	Modes: { [string]: boolean }?,
	Advanced: boolean?,
	Condition: (() -> boolean)?,
}

local BACKGROUND = Color3.fromRGB(21, 22, 25)
local CARD = Color3.fromRGB(28, 30, 34)
local CARD_STROKE = Color3.fromRGB(44, 46, 52)
local TILE = Color3.fromRGB(24, 25, 29)
local FIELD = Color3.fromRGB(21, 22, 26)
local TEXT = Color3.fromRGB(236, 237, 240)
local MUTED = Color3.fromRGB(139, 142, 150)
local ACCENT = Color3.fromRGB(255, 138, 36)
local DANGER = Color3.fromRGB(235, 64, 64)
local ACCENT_DIM = Color3.fromRGB(62, 40, 22)
local SWITCH_OFF = Color3.fromRGB(66, 69, 76)
local TABS = { "Build", "Arrange", "Props", "Display", "Hotkeys", "Settings" }
local LOCKED: { [string]: boolean } = { Build = true, Arrange = true, Props = true, Display = true }

--[[ The setting each switch changes, by its title, so a switch can offer a reset to the default. ]]
local SWITCH_KEYS: { [string]: string } = {
	["Railing"] = "PorchRailing",
	["Random rotation"] = "BrushRandomYaw",
	["Randomize prop rotation"] = "PropRandomRotation",
	["Collapse props after picking one"] = "PropAutoCollapse",
	["Ceiling"] = "Roof",
	["Snap to parts"] = "SnapToParts",
	["Join rooms and corridors"] = "ConnectStructures",
	["Set cut depth with mouse"] = "CutDepth",
	["Tilt copy to surface"] = "Align",
	["Camera light"] = "CameraLight",
	["Construction grid while drawing"] = "ShowGrid",
	["Allow untagged folders (not recommended)"] = "AllowUntagged",
	["Blender hotkeys"] = "Hotkeys",
	["Door"] = "DoorPanel",
	["Door frame"] = "DoorFrame",
	["Door blocks movement"] = "DoorCollide",
}

local Panel = {}

--[[
	@param class string
	@param props { [string]: any }
	@param parent Instance?

	@return any -- a new instance with the properties set, then parented
]]
local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(class)

	for key, value in props do
		(object :: any)[key] = value
	end

	object.Parent = parent

	return object
end

--[[
	@param parent Instance
	@param radius number
	@param strokeColor Color3?

	Rounds a frame's corners and, when given a colour, outlines it.
]]
local function style(parent: Instance, radius: number, strokeColor: Color3?)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)

	if strokeColor then
		make("UIStroke", { Color = strokeColor, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
	end
end

--[=[
	Builds the whole panel inside the widget.

	@param deps Deps
	@return Panel
]=]
function Panel.new(deps: Deps): Panel
	local settings, actions = deps.Settings, deps.Actions
	local values = settings :: any

	local root = make("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BACKGROUND,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, deps.Widget)

	make("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 14),
	}, root)
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, root)

	local order = 0
	local page = "Build"
	local advanced = false
	local toolOpen = true
	local entries: { Entry } = {}
	local fieldBoxes: { [string]: TextBox } = {}
	local refreshers: { () -> () } = {}
	local tabButtons: { [string]: TextButton } = {}
	local pages: { [string]: Frame } = {}
	local tiles: { [string]: { Button: TextButton, Stroke: UIStroke } } = {}

	local function nextOrder(): number
		order += 1

		return order
	end

	local function register(frame: GuiObject, scope: Scope?)
		local s: Scope = scope or {}

		table.insert(entries, {
			Frame = frame,
			Modes = s.Modes,
			Advanced = s.Advanced == true,
			Condition = s.Condition,
		})
	end

	--
	-- Header, tabs and status line
	--

	local header =
		make("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, LayoutOrder = nextOrder() }, root)
	local logo = make("TextLabel", {
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.fromOffset(2, 3),
		BackgroundColor3 = ACCENT,
		Text = "V",
		TextColor3 = BACKGROUND,
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
	}, header)

	style(logo, 7)
	make("TextLabel", {
		Size = UDim2.new(1, -120, 1, 0),
		Position = UDim2.fromOffset(44, 0),
		BackgroundTransparency = 1,
		Text = PluginInfo.Name,
		TextColor3 = TEXT,
		Font = Enum.Font.GothamBlack,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, header)
	make("TextLabel", {
		Size = UDim2.fromOffset(40, 38),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		Text = PluginInfo.Version,
		TextColor3 = MUTED,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, header)

	local tabBar = make("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = CARD,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(),
	}, root)

	style(tabBar, 7, CARD_STROKE)

	local status = make("TextLabel", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = "Pick a tool, or press a number key. Everything is in studs.",
		TextColor3 = MUTED,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = nextOrder(),
	}, root)

	local function say(message: string)
		status.Text = message
	end

	--
	-- Hover tooltips
	--

	local tooltip = make("Frame", {
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Color3.fromRGB(34, 36, 41),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 100,
	}, deps.Widget)

	style(tooltip, 6, Color3.fromRGB(80, 83, 91))
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 9),
		PaddingRight = UDim.new(0, 9),
		PaddingTop = UDim.new(0, 7),
		PaddingBottom = UDim.new(0, 7),
	}, tooltip)
	make("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, tooltip)

	local tooltipText = make("TextLabel", {
		Size = UDim2.fromOffset(220, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		TextColor3 = TEXT,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 101,
		LayoutOrder = 1,
	}, tooltip)
	local tooltipKey = make("TextLabel", {
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = TILE,
		BorderSizePixel = 0,
		TextColor3 = ACCENT,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		ZIndex = 101,
		LayoutOrder = 2,
	}, tooltip)

	style(tooltipKey, 4, CARD_STROKE)
	make("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }, tooltipKey)

	local hoverToken = 0

	local function moveTooltip(x: number, y: number)
		local space = deps.Widget.AbsoluteSize
		local size = tooltip.AbsoluteSize

		tooltip.Position = UDim2.fromOffset(
			math.max(4, math.min(x + 14, space.X - size.X - 6)),
			math.max(4, math.min(y + 18, space.Y - size.Y - 6))
		)
	end

	local function hideTooltip()
		hoverToken += 1
		tooltip.Visible = false
	end

	--[[
		@param object GuiObject
		@param tip Tips.Tip?

		Shows the description, and the hotkey when there is one, after the cursor rests on the object.
	]]
	local function attachTip(object: GuiObject, tip: Tips.Tip?)
		if not tip then
			return
		end

		object.Active = true
		object.MouseEnter:Connect(function(x, y)
			hoverToken += 1

			local mine = hoverToken

			task.delay(0.35, function()
				if hoverToken ~= mine then
					return
				end

				tooltipText.Text = tip.Text
				tooltipKey.Text = tip.Key or ""
				tooltipKey.Visible = tip.Key ~= nil
				tooltip.Visible = true
				moveTooltip(x, y)
			end)
		end)
		object.MouseMoved:Connect(function(x, y)
			if tooltip.Visible then
				moveTooltip(x, y)
			end
		end)
		object.MouseLeave:Connect(hideTooltip)
	end

	local function attach(object: GuiObject, name: string)
		attachTip(object, Tips.Find(name))
	end

	--
	-- Building blocks
	--

	--[[
		@param title string?
		@param pageName string
		@param scope Scope?

		@return Frame -- a rounded card in that page; rows are added to it
	]]
	local function card(title: string?, pageName: string, scope: Scope?): Frame
		local frame = make("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = CARD,
			BorderSizePixel = 0,
			LayoutOrder = nextOrder(),
		}, if pageName == "Root" then root else pages[pageName])

		style(frame, 8, CARD_STROKE)
		make("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		}, frame)
		make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, frame)

		if title then
			make("TextLabel", {
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
				Text = title,
				TextColor3 = MUTED,
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = nextOrder(),
			}, frame)
		end

		register(frame, scope)

		return frame
	end

	local function newRow(parent: Instance, height: number): Frame
		return make("Frame", {
			Size = UDim2.new(1, 0, 0, height),
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
		}, parent)
	end

	local function text(parent: Instance, content: string, color: Color3?, scope: Scope?): TextLabel
		local label = make("TextLabel", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = content,
			TextColor3 = color or MUTED,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = nextOrder(),
		}, parent)

		register(label, scope)

		return label
	end

	local function button(parent: Instance, label: string, run: () -> (), primary: boolean, scope: Scope?): TextButton
		local frame = newRow(parent, 34)
		local control = make("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = if primary then ACCENT else TILE,
			BorderSizePixel = 0,
			Text = label,
			TextColor3 = if primary then BACKGROUND else TEXT,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			AutoButtonColor = true,
		}, frame)

		style(control, 6, if primary then nil else CARD_STROKE)
		attach(control, label)
		register(frame, scope)
		control.MouseButton1Click:Connect(function()
			local ok, err = pcall(run :: any)

			if not ok then
				say("Action stopped: " .. tostring(err))
				warn(err)
			end
		end)

		return control
	end

	local function buttonRow(
		parent: Instance,
		items: { { Text: string, Run: () -> (), Primary: boolean? } },
		scope: Scope?
	)
		local frame = newRow(parent, 34)
		local count = #items

		register(frame, scope)

		for i, item in items do
			local control = make("TextButton", {
				Size = UDim2.new(1 / count, -4, 1, 0),
				Position = UDim2.fromScale((i - 1) / count, 0),
				BackgroundColor3 = if item.Primary then ACCENT else TILE,
				BorderSizePixel = 0,
				Text = item.Text,
				TextColor3 = if item.Primary then BACKGROUND else TEXT,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextWrapped = true,
			}, frame)

			style(control, 6, if item.Primary then nil else CARD_STROKE)
			attach(control, item.Text)
			control.MouseButton1Click:Connect(function()
				local ok, err = pcall(item.Run :: any)

				if not ok then
					say("Action stopped: " .. tostring(err))
					warn(err)
				end
			end)
		end
	end

	local function stepperButton(parent: Instance, label: string, x: number): TextButton
		local control = make("TextButton", {
			Size = UDim2.fromOffset(34, 28),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, x, 0.5, 0),
			BackgroundColor3 = TILE,
			BorderSizePixel = 0,
			Text = label,
			TextColor3 = TEXT,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
		}, parent)

		style(control, 5, CARD_STROKE)

		return control
	end

	local refresh: () -> ()

	local overrideFlag: { [string]: string } = {}

	for _, row in Settings.Standards do
		overrideFlag[row[1]] = row[3]
	end

	local menuCatcher: TextButton? = nil
	local menuItem: TextButton? = nil
	local menuAction: (() -> ())? = nil

	--[[
		Hides the right-click menu.
	]]
	local function closeMenu()
		if menuCatcher and menuItem then
			menuCatcher.Visible = false
			menuItem.Visible = false
		end

		menuAction = nil
	end

	--[[
		@param position Vector2 -- where the mouse is, in screen pixels
		@param text string
		@param action () -> ()

		Shows a one-item menu at the mouse. Clicking the item runs the action; clicking anywhere else closes it.
	]]
	local function openMenu(position: Vector2, label: string, action: () -> ())
		if not menuCatcher or not menuItem then
			local catcher = make("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 100,
				Visible = false,
			}, deps.Widget)
			local item = make("TextButton", {
				Size = UDim2.fromOffset(210, 28),
				BackgroundColor3 = TILE,
				BorderSizePixel = 0,
				Text = "",
				TextColor3 = TEXT,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				ZIndex = 101,
				Visible = false,
			}, deps.Widget)

			style(item, 6, CARD_STROKE)
			catcher.MouseButton1Click:Connect(closeMenu)
			catcher.MouseButton2Click:Connect(closeMenu)
			item.MouseButton1Click:Connect(function()
				local run = menuAction

				closeMenu()

				if run then
					run()
				end
			end)
			menuCatcher, menuItem = catcher, item
		end

		local catcher, item = menuCatcher :: TextButton, menuItem :: TextButton

		item.Text = label
		item.Position = UDim2.fromOffset(math.min(position.X, deps.Widget.AbsoluteSize.X - 214), position.Y)
		catcher.Visible = true
		item.Visible = true
		menuAction = action
	end

	--[[
		@param frame Frame -- the setting's row
		@param reset () -> ()
		@param defaultText string

		Right-clicking the row offers to put that one setting back to its default.
	]]
	local function resetMenu(frame: Frame, reset: () -> (), defaultText: string)
		frame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				openMenu(
					Vector2.new(input.Position.X, input.Position.Y),
					"Reset to default (" .. defaultText .. ")",
					function()
						reset()
						refresh()
					end
				)
			end
		end)
	end

	local function numeric(
		parent: Instance,
		key: string,
		title: string,
		min: number,
		max: number,
		step: number?,
		scope: Scope?
	)
		local frame = newRow(parent, 36)

		register(frame, scope)
		local rowLabel = make("TextLabel", {
			Size = UDim2.new(1, -170, 1, 0),
			BackgroundTransparency = 1,
			Text = title,
			TextColor3 = TEXT,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, frame)
		attach(rowLabel, key)

		local flagKey = overrideFlag[key]

		local function paintLabel()
			rowLabel.Text = if flagKey and (values :: any)[flagKey] then title .. " *" else title
		end

		paintLabel()
		table.insert(refreshers, paintLabel)

		local group = make("Frame", {
			Size = UDim2.fromOffset(162, 36),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			BackgroundTransparency = 1,
		}, frame)
		local box = make("TextBox", {
			Size = UDim2.fromOffset(82, 28),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 40, 0.5, 0),
			BackgroundColor3 = FIELD,
			BorderSizePixel = 0,
			Text = tostring(values[key]),
			TextColor3 = TEXT,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			ClearTextOnFocus = false,
		}, group)

		style(box, 5, CARD_STROKE)
		fieldBoxes[key] = box
		table.insert(refreshers, function()
			if not box:IsFocused() then
				box.Text = tostring(values[key])
			end
		end)

		local function apply(value: number?)
			if value and value == value and math.abs(value) < math.huge then
				values[key] = math.clamp(value, min, max)

				if key == "Copies" or key == "ArchSegments" then
					values[key] = math.floor(values[key])
				end

				if flagKey then
					(values :: any)[flagKey] = values[key] ~= (values :: any)["Standard" .. key]
					paintLabel()
				elseif string.sub(key, 1, 8) == "Standard" then
					Settings.Sync(values)
					refresh()
				end

				deps.Save()

				if key == "GridTextureSize" then
					SurfaceGrid.Resize(deps.SurfaceGrid)
				elseif key == "GhostTransparency" then
					Hidden.SetGhost(deps.Hidden, values[key])
				end
			end

			box.Text = tostring(values[key])
		end

		box.FocusLost:Connect(function()
			apply(tonumber(box.Text))
		end)
		stepperButton(group, "−", 0).MouseButton1Click:Connect(function()
			apply(
				values[key]
					- (
						if key ~= "FieldStep" and settings.FieldStep > 0
							then settings.FieldStep
							else (step or settings.Grid)
					)
			)
		end)
		stepperButton(group, "+", 128).MouseButton1Click:Connect(function()
			apply(
				values[key]
					+ (
						if key ~= "FieldStep" and settings.FieldStep > 0
							then settings.FieldStep
							else (step or settings.Grid)
					)
			)
		end)

		local initial = (Settings.Defaults() :: any)[key]

		if type(initial) == "number" then
			resetMenu(frame, function()
				apply(initial)
			end, tostring(initial))
		end
	end

	local function switch(
		parent: Instance,
		title: string,
		get: () -> boolean,
		set: (boolean) -> (),
		scope: Scope?,
		danger: boolean?
	)
		local frame = newRow(parent, 36)

		register(frame, scope)
		local rowLabel = make("TextLabel", {
			Size = UDim2.new(1, -60, 1, 0),
			BackgroundTransparency = 1,
			Text = title,
			TextColor3 = if danger then DANGER else TEXT,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, frame)
		attach(rowLabel, title)

		local track = make("TextButton", {
			Size = UDim2.fromOffset(44, 24),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			BackgroundColor3 = SWITCH_OFF,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
		}, frame)
		local knob = make("Frame", {
			Size = UDim2.fromOffset(18, 18),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
		}, track)

		style(track, 12)
		style(knob, 9)
		table.insert(refreshers, function()
			local on = get()

			track.BackgroundColor3 = if on then (if danger then DANGER else ACCENT) else SWITCH_OFF
			knob.Position = UDim2.new(0, if on then 23 else 3, 0.5, 0)
		end)
		track.MouseButton1Click:Connect(function()
			set(not get())
		end)

		local field = SWITCH_KEYS[title]
		local initial = if field then (Settings.Defaults() :: any)[field] else nil

		if type(initial) == "boolean" then
			resetMenu(frame, function()
				set(initial)
			end, if initial then "on" else "off")
		end
	end

	--
	-- Tabs and pages
	--

	for _, name in TABS do
		pages[name] = make("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
		}, root)
		make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, pages[name])
	end

	--[[
		Leaving the current tab drops an unconfirmed folder pick.
	]]
	local function leavePage()
		actions.Stop()

		if deps.GetPicking() then
			actions.CancelPick()
		end
	end

	for i, name in TABS do
		local tab = make("TextButton", {
			Size = UDim2.new(1 / #TABS, -4, 1, -8),
			Position = UDim2.new((i - 1) / #TABS, 4, 0, 4),
			BackgroundColor3 = CARD,
			BorderSizePixel = 0,
			Text = name,
			TextColor3 = TEXT,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			AutoButtonColor = false,
		}, tabBar)

		style(tab, 5)
		attach(tab, name)
		tabButtons[name] = tab
		tab.MouseButton1Click:Connect(function()
			leavePage()
			page = name
			refresh()
		end)
	end

	local hasMode = function()
		return deps.GetMode() ~= nil
	end

	--
	-- Build page
	--

	--
	-- Working folder
	--

	local folderCard = card("WORKING FOLDER", "Root")
	local folderName = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = ACCENT_DIM,
		BorderSizePixel = 0,
		Text = "",
		TextColor3 = ACCENT,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Visible = false,
		LayoutOrder = nextOrder(),
	}, folderCard)

	style(folderName, 6, ACCENT)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, folderName)

	local folderText = text(folderCard, "", MUTED)
	local pickButton = button(
		folderCard,
		"Choose working folder",
		function()
			actions.StartPick()
			refresh()
		end,
		true,
		{
			Condition = function()
				return not deps.GetPicking()
			end,
		}
	)

	local function cancelPick()
		actions.CancelPick()
		refresh()
	end

	buttonRow(folderCard, {
		{
			Text = "Yes",
			Primary = true,
			Run = function()
				actions.ConfirmPick()
				refresh()
			end,
		},
		{ Text = "Cancel", Run = cancelPick, Primary = true },
	}, {
		Condition = function()
			return deps.GetPending() ~= nil
		end,
	})

	local function resolve(choice: string): () -> ()
		return function()
			actions.ResolveTheme(choice)
			refresh()
		end
	end

	buttonRow(folderCard, {
		{ Text = "Use folder's", Run = resolve("Use"), Primary = true },
		{ Text = "Overwrite", Run = resolve("Overwrite"), Primary = true },
		{ Text = "Cancel", Run = resolve("Cancel") },
	}, {
		Condition = function()
			return deps.GetConflict() ~= nil
		end,
	})

	buttonRow(folderCard, { { Text = "Cancel", Run = cancelPick, Primary = true } }, {
		Condition = function()
			return deps.GetPicking() and deps.GetPending() == nil
		end,
	})

	local lockedNote = text(root, "Pick a working folder above to start using the tools.", ACCENT)

	folderCard.LayoutOrder = 2
	tabBar.LayoutOrder = 3
	status.LayoutOrder = 4
	lockedNote.LayoutOrder = 5

	--
	-- Build page
	--

	local toolCard = card("BUILD TOOLS", "Build")
	local grid = make("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
	}, toolCard)

	make("UIGridLayout", {
		CellSize = UDim2.new(0.5, -4, 0, 44),
		CellPadding = UDim2.fromOffset(8, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)

	for index, tool in Tools.Grid do
		local tile = make("TextButton", {
			BackgroundColor3 = TILE,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = true,
			LayoutOrder = index,
		}, grid)

		style(tile, 6)
		attachTip(tile, { Text = tool.Description, Key = if tool.Key then "Ctrl+" .. tool.Key else nil })

		local outline = make("UIStroke", {
			Color = CARD_STROKE,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, tile)

		make("TextLabel", {
			Size = UDim2.new(0, 30, 1, 0),
			Position = UDim2.fromOffset(4, 0),
			BackgroundTransparency = 1,
			Text = tool.Glyph,
			TextColor3 = TEXT,
			Font = Enum.Font.GothamMedium,
			TextSize = 22,
		}, tile)
		make("TextLabel", {
			Size = UDim2.new(1, -56, 1, 0),
			Position = UDim2.fromOffset(38, 0),
			BackgroundTransparency = 1,
			Text = tool.Label,
			TextColor3 = TEXT,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, tile)

		if tool.Key then
			make("TextLabel", {
				Size = UDim2.fromOffset(14, 14),
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -5, 0, 5),
				BackgroundTransparency = 1,
				Text = tool.Key,
				TextColor3 = MUTED,
				Font = Enum.Font.GothamMedium,
				TextSize = 10,
			}, tile)
		end

		tiles[tool.Id] = { Button = tile, Stroke = outline }
		tile.MouseButton1Click:Connect(function()
			actions.Activate(tool.Id)
		end)
	end

	local settingsCard = card(nil, "Build", { Condition = hasMode })
	local headerRow = newRow(settingsCard, 34)
	local headerButton = make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, headerRow)
	local headerGlyph = make("TextLabel", {
		Size = UDim2.new(0, 30, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = TEXT,
		Font = Enum.Font.GothamMedium,
		TextSize = 22,
	}, headerButton)
	local headerName = make("TextLabel", {
		Size = UDim2.new(1, -70, 1, 0),
		Position = UDim2.fromOffset(38, 0),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, headerButton)
	local headerChevron = make("TextLabel", {
		Size = UDim2.new(0, 24, 1, 0),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		Text = "⌃",
		TextColor3 = MUTED,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
	}, headerButton)

	headerButton.MouseButton1Click:Connect(function()
		toolOpen = not toolOpen
		refresh()
	end)

	for _, group in Tools.Grid do
		if #group.Modes > 1 then
			local modeSet: { [string]: boolean } = {}

			for _, id in group.Modes do
				modeSet[id] = true
			end

			local variantRows = math.ceil(#group.Modes / 2)
			local variantRow = newRow(settingsCard, variantRows * 32 - 2)
			local variantButtons: { [string]: TextButton } = {}

			register(variantRow, { Modes = modeSet })

			for i, id in group.Modes do
				local option = Tools.Find(id) :: Tools.Tool
				local choice = make("TextButton", {
					Size = UDim2.new(0.5, -4, 0, 30),
					Position = UDim2.new(((i - 1) % 2) / 2, 0, 0, math.floor((i - 1) / 2) * 32),
					BackgroundColor3 = TILE,
					BorderSizePixel = 0,
					Text = option.Glyph .. "  " .. option.Label,
					TextColor3 = TEXT,
					Font = Enum.Font.GothamMedium,
					TextSize = 12,
				}, variantRow)

				style(choice, 6, CARD_STROKE)
				attachTip(choice, { Text = option.Description, Key = "Alt+" .. (if i == 10 then 0 else i) })
				variantButtons[id] = choice
				choice.MouseButton1Click:Connect(function()
					actions.SetMode(id)
					refresh()
				end)
			end

			table.insert(refreshers, function()
				for id, choice in variantButtons do
					local active = id == deps.GetMode()

					choice.BackgroundColor3 = if active then ACCENT else TILE
					choice.TextColor3 = if active then BACKGROUND else TEXT
				end
			end)
		end
	end

	local function body(modes: { [string]: boolean }?, isAdvanced: boolean?): Scope
		return {
			Modes = modes,
			Advanced = isAdvanced,
			Condition = function()
				return toolOpen
			end,
		}
	end

	local hint = text(settingsCard, "", MUTED, body(nil))
	local drawModes = {
		Wall = true,
		Floor = true,
		PillaredWall = true,
		Corridor = true,
		ArchedCorridor = true,
		Room = true,
		Foundation = true,
		Porch = true,
		Fence = true,
		Roof = true,
		Railing = true,
		HalfWall = true,
		Vent = true,
		VentRamp = true,
		VentShaft = true,
		Block = true,
		Stairs = true,
		Ramp = true,
		Arch = true,
		Pillar = true,
	}
	local heightModes = {
		Wall = true,
		PillaredWall = true,
		Corridor = true,
		ArchedCorridor = true,
		Room = true,
		Block = true,
		Pillar = true,
		Porch = true,
	}
	local scope = settingsCard

	numeric(scope, "Grid", "Snap increment", 0.05, 128, 0.5, body(drawModes))
	numeric(scope, "FineGrid", "Fine snap (hold Shift)", 0.05, 128, 0.5, body(drawModes))
	numeric(scope, "Elevation", "Floor level (Y)", -10000, 10000, nil, body(drawModes))
	button(scope, "Use selected floor height", actions.UseSelectedFloor, false, body(drawModes))
	numeric(scope, "Height", "Height", 0.1, 2048, nil, body(heightModes))
	numeric(
		scope,
		"Thickness",
		"Thickness",
		0.05,
		128,
		nil,
		body({ Wall = true, PillaredWall = true, Corridor = true, ArchedCorridor = true, Room = true, Arch = true })
	)
	numeric(
		scope,
		"Width",
		"Clear width",
		0.1,
		1024,
		nil,
		body({ Corridor = true, ArchedCorridor = true, Stairs = true, Ramp = true })
	)
	numeric(scope, "StairHeight", "Total stair rise", 0.1, 1024, nil, body({ Stairs = true }))
	numeric(scope, "RampHeight", "Ramp rise", 0.1, 1024, nil, body({ Ramp = true }))
	numeric(scope, "ArchHeight", "Clear height", 0.1, 1024, nil, body({ Arch = true }))
	numeric(scope, "ArchDepth", "Frame depth", 0.1, 256, nil, body({ Arch = true }))
	numeric(scope, "OpenWidth", "Archway width", 0.1, 1024, nil, body({ ArchOpening = true }))
	numeric(scope, "OpenHeight", "Archway height", 0.1, 1024, nil, body({ ArchOpening = true }))
	numeric(scope, "DoorWidth", "Doorway width", 0.1, 1024, nil, body({ Door = true }))
	numeric(scope, "DoorHeight", "Doorway height", 0.1, 1024, nil, body({ Door = true }))
	switch(scope, "Door frame", function()
		return settings.DoorFrame
	end, function(on)
		settings.DoorFrame = on
		deps.Save()
		refresh()
	end, body({ Door = true }))
	local function frameShown()
		return settings.DoorFrame
	end
	local function doorShown()
		return settings.DoorPanel
	end
	local function onlyIf(check: () -> boolean): Scope
		return {
			Modes = { Door = true },
			Condition = function()
				return toolOpen and check()
			end,
		}
	end

	numeric(scope, "FrameWidth", "Frame width", 0.05, 8, nil, onlyIf(frameShown))
	numeric(scope, "FrameDepth", "Frame depth", 0.05, 64, nil, onlyIf(frameShown))
	switch(scope, "Door", function()
		return settings.DoorPanel
	end, function(on)
		settings.DoorPanel = on
		deps.Save()
		refresh()
	end, body({ Door = true }))
	numeric(scope, "DoorThickness", "Door thickness", 0.05, 8, nil, onlyIf(doorShown))
	numeric(scope, "DoorTransparency", "Door transparency", 0, 1, 0.1, onlyIf(doorShown))
	switch(scope, "Door blocks movement", function()
		return settings.DoorCollide
	end, function(on)
		settings.DoorCollide = on
		deps.Save()
		refresh()
	end, onlyIf(doorShown))
	numeric(
		scope,
		"WindowWidth",
		"Window width",
		0.1,
		1024,
		nil,
		body({ Window = true, CircleWindow = true, TriangleWindow = true })
	)
	numeric(
		scope,
		"WindowHeight",
		"Window height",
		0.1,
		1024,
		nil,
		body({ Window = true, CircleWindow = true, TriangleWindow = true })
	)
	numeric(
		scope,
		"WindowSill",
		"Bottom above floor",
		0,
		1024,
		nil,
		body({ Window = true, CircleWindow = true, TriangleWindow = true })
	)
	numeric(scope, "PillarWidth", "Pillar width", 0.1, 256, nil, body({ Pillar = true, PillaredWall = true }))

	do
		local styles = { "Gable", "Hip", "Shed", "Pyramid", "Flat" }
		local rows = math.ceil(#styles / 3)
		local styleRow = newRow(scope, rows * 32 - 2)
		local styleButtons: { [string]: TextButton } = {}

		register(styleRow, body({ Roof = true }))

		for i, name in styles do
			local choice = make("TextButton", {
				Size = UDim2.new(1 / 3, -4, 0, 30),
				Position = UDim2.new(((i - 1) % 3) / 3, 0, 0, math.floor((i - 1) / 3) * 32),
				BackgroundColor3 = TILE,
				BorderSizePixel = 0,
				Text = name,
				TextColor3 = TEXT,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
			}, styleRow)

			style(choice, 6, CARD_STROKE)
			attachTip(choice, { Text = name .. " roof." })
			styleButtons[name] = choice
			choice.MouseButton1Click:Connect(function()
				settings.RoofStyle = name
				deps.Save()
				refresh()
			end)
		end

		table.insert(refreshers, function()
			for name, choice in styleButtons do
				local active = name == settings.RoofStyle

				choice.BackgroundColor3 = if active then ACCENT else TILE
				choice.TextColor3 = if active then BACKGROUND else TEXT
			end
		end)
	end

	do
		local joins = {
			{ "Open", "Open: no wall between the rooms." },
			{ "Shared", "Shared: the rooms share one wall." },
			{ "Separate", "Separate: both walls stay." },
		}
		local joinRow = newRow(scope, 30)
		local joinButtons: { [string]: TextButton } = {}

		register(joinRow, body({ Room = true }))

		for i, entry in joins do
			local name, tip = entry[1], entry[2]
			local choice = make("TextButton", {
				Size = UDim2.new(1 / 3, -4, 0, 30),
				Position = UDim2.fromScale((i - 1) / 3, 0),
				BackgroundColor3 = TILE,
				BorderSizePixel = 0,
				Text = name,
				TextColor3 = TEXT,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
			}, joinRow)

			style(choice, 6, CARD_STROKE)
			attachTip(choice, { Text = tip })
			joinButtons[name] = choice
			choice.MouseButton1Click:Connect(function()
				settings.RoomJoin = name
				deps.Save()
				refresh()
			end)
		end

		table.insert(refreshers, function()
			for name, choice in joinButtons do
				local active = name == settings.RoomJoin

				choice.BackgroundColor3 = if active then ACCENT else TILE
				choice.TextColor3 = if active then BACKGROUND else TEXT
			end
		end)
	end

	numeric(scope, "FloorTransparency", "Transparency (0 solid, 1 clear)", 0, 1, 0.1, body({ Floor = true }))
	numeric(scope, "RoofRise", "Roof rise", 0.1, 512, nil, body({ Roof = true }))
	numeric(scope, "RoofOverhang", "Overhang", 0, 128, nil, body({ Roof = true }))
	numeric(scope, "FoundationHeight", "Slab height", 0.1, 256, nil, body({ Foundation = true }))
	numeric(scope, "FoundationMargin", "Margin around", 0, 128, nil, body({ Foundation = true }))
	numeric(scope, "FenceHeight", "Fence height", 0.1, 256, nil, body({ Fence = true }))
	numeric(scope, "FenceSpacing", "Post spacing", 0.5, 256, nil, body({ Fence = true, Porch = true }))
	switch(scope, "Railing", function()
		return settings.PorchRailing
	end, function(on)
		settings.PorchRailing = on
		deps.Save()
		refresh()
	end, body({ Porch = true }))
	numeric(
		scope,
		"RailHeight",
		"Railing height",
		0.1,
		256,
		nil,
		body({ Porch = true, Railing = true, HalfWall = true })
	)
	numeric(scope, "BalusterSpacing", "Bar spacing", 0.3, 64, nil, body({ Railing = true }))
	numeric(
		scope,
		"VentSize",
		"Vent size",
		0.5,
		64,
		nil,
		body({
			Vent = true,
			VentRamp = true,
			VentShaft = true,
			VentCover = true,
			VentCap = true,
			VentFan = true,
			VentPeek = true,
			VentHole = true,
		})
	)
	numeric(
		scope,
		"VentThickness",
		"Vent sheet thickness",
		0.05,
		4,
		0.05,
		body({ Vent = true, VentRamp = true, VentShaft = true, VentHole = true })
	)
	numeric(scope, "RoofThickness", "Roof sheet thickness", 0.05, 64, nil, body({ Roof = true }, true))
	numeric(scope, "Yaw", "Copy rotation", -360, 360, 90, body({ Place = true }))
	numeric(scope, "BrushRadius", "Brush radius", 0, 200, 1, body({ Place = true }))
	numeric(scope, "BrushSpacing", "Brush spacing", 0.5, 100, 0.5, body({ Place = true }))
	numeric(scope, "BrushSizeMin", "Smallest size (x)", 0.05, 20, 0.1, body({ Place = true }))
	numeric(scope, "BrushSizeMax", "Biggest size (x)", 0.05, 20, 0.1, body({ Place = true }))
	switch(scope, "Random rotation", function()
		return settings.BrushRandomYaw
	end, function(on)
		settings.BrushRandomYaw = on
		deps.Save()
	end, body({ Place = true }))

	do
		local list = make("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
		}, scope)

		make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)
		register(list, body({ Place = true }))

		local shown = ""

		local function rebuild()
			local brushes = Brushes.List()
			local key = ""

			for _, entry in brushes do
				key ..= entry.Name .. (if Brushes.IsOn(entry) then "+" else "-") .. "|"
			end

			if key == shown then
				return
			end

			shown = key

			for _, child in list:GetChildren() do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end

			if #brushes == 0 then
				make("TextLabel", {
					Size = UDim2.new(1, 0, 0, 30),
					BackgroundTransparency = 1,
					Text = "No brushes yet. Select something and press Add selected to brushes. With none, the brush paints the current selection.",
					TextColor3 = MUTED,
					Font = Enum.Font.Gotham,
					TextSize = 12,
					TextWrapped = true,
					AutomaticSize = Enum.AutomaticSize.Y,
					TextXAlignment = Enum.TextXAlignment.Left,
				}, list)
			end

			for index, entry in brushes do
				local row = make("Frame", {
					Size = UDim2.new(1, 0, 0, 28),
					BackgroundTransparency = 1,
					LayoutOrder = index,
				}, list)
				local on = Brushes.IsOn(entry)
				local pick = make("TextButton", {
					Size = UDim2.new(1, -34, 1, 0),
					BackgroundColor3 = if on then ACCENT else TILE,
					BorderSizePixel = 0,
					Text = entry.Name,
					TextColor3 = if on then BACKGROUND else MUTED,
					Font = Enum.Font.GothamMedium,
					TextSize = 12,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}, row)
				local remove = make("TextButton", {
					Size = UDim2.fromOffset(28, 28),
					Position = UDim2.new(1, -28, 0, 0),
					BackgroundColor3 = TILE,
					BorderSizePixel = 0,
					Text = "✕",
					TextColor3 = TEXT,
					Font = Enum.Font.GothamMedium,
					TextSize = 12,
				}, row)

				style(pick, 6, CARD_STROKE)
				style(remove, 6, CARD_STROKE)
				attachTip(
					pick,
					{ Text = "Click to switch this brush on or off. Every brush that is on is painted at random." }
				)
				attachTip(remove, { Text = "Remove this brush from the list." })
				pick.MouseButton1Click:Connect(function()
					Brushes.Toggle(entry)
					deps.Actions.BrushesChanged()
					refresh()
				end)
				remove.MouseButton1Click:Connect(function()
					Brushes.Remove(entry)
					deps.Actions.BrushesChanged()
					refresh()
				end)
			end
		end

		table.insert(refreshers, rebuild)
	end

	button(scope, "Add selected to brushes", function()
		local _, message = Brushes.AddSelected()

		deps.Actions.BrushesChanged()
		say(message)
		refresh()
	end, true, body({ Place = true }))

	button(
		scope,
		"Start new chain",
		function()
			actions.ResetPoint()
			say(actions.Instruction(deps.GetMode()))
		end,
		false,
		body({
			Wall = true,
			PillaredWall = true,
			Corridor = true,
			ArchedCorridor = true,
			Fence = true,
			Railing = true,
			HalfWall = true,
			Vent = true,
		})
	)

	switch(scope, "Ceiling", function()
		return settings.Roof
	end, function(on)
		settings.Roof = on
		deps.Save()
		refresh()
	end, body({ Room = true, Corridor = true }))

	switch(scope, "Snap to parts", function()
		return settings.SnapToParts
	end, function(on)
		settings.SnapToParts = on
		deps.Save()
		refresh()
	end, body(drawModes))
	numeric(scope, "SnapRadius", "Snap reach", 0.5, 32, 0.5, body(drawModes))

	switch(scope, "Join rooms and corridors", function()
		return settings.ConnectStructures
	end, function(on)
		settings.ConnectStructures = on
		deps.Save()
		refresh()
	end, body({ Room = true, Corridor = true, ArchedCorridor = true }))

	switch(scope, "Set cut depth with mouse", function()
		return settings.CutDepth
	end, function(on)
		settings.CutDepth = on
		deps.Save()
		refresh()
	end, body({ Door = true, Window = true, CircleWindow = true, TriangleWindow = true, ArchOpening = true }))

	local advancedRow = newRow(scope, 30)
	local advancedButton = make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "▶  Advanced options",
		TextColor3 = TEXT,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
	}, advancedRow)

	register(
		advancedRow,
		body({
			Stairs = true,
			Ramp = true,
			Room = true,
			Corridor = true,
			ArchedCorridor = true,
			Arch = true,
			ArchOpening = true,
			Place = true,
		})
	)
	advancedButton.MouseButton1Click:Connect(function()
		advanced = not advanced
		refresh()
	end)

	numeric(scope, "Run", "Approx. step depth", 0.1, 64, 0.25, body({ Stairs = true }, true))
	numeric(scope, "Landing", "Top landing depth", 0, 256, nil, body({ Stairs = true, Ramp = true }, true))
	numeric(
		scope,
		"Floor",
		"Floor / ceiling thickness",
		0.05,
		128,
		0.25,
		body({ Room = true, Corridor = true, ArchedCorridor = true, Porch = true, Floor = true }, true)
	)
	numeric(
		scope,
		"ArchSegments",
		"Arch smoothness",
		4,
		48,
		4,
		body({ Arch = true, ArchOpening = true, ArchedCorridor = true }, true)
	)
	numeric(scope, "Offset", "Surface gap", -256, 256, 0.25, body({ Place = true }, true))
	switch(scope, "Tilt copy to surface", function()
		return settings.Align
	end, function(on)
		settings.Align = on
		deps.Save()
		refresh()
	end, body({ Place = true }, true))

	--
	-- Viewport display, on Build and again on Display
	--

	local function displayRows(parent: Instance)
		switch(parent, "Pastel colors", function()
			return deps.Colors.On
		end, function(on)
			Colors.Set(deps.Colors, on)
		end)
		do
			local themeRow = newRow(parent, 30)
			local themeButtons: { [string]: TextButton } = {}

			register(themeRow, {
				Condition = function()
					return deps.Colors.On
				end,
			})

			for i, name in Colors.Themes do
				local choice = make("TextButton", {
					Size = UDim2.new(1 / #Colors.Themes, -4, 0, 30),
					Position = UDim2.fromScale((i - 1) / #Colors.Themes, 0),
					BackgroundColor3 = TILE,
					BorderSizePixel = 0,
					Text = name,
					TextColor3 = TEXT,
					Font = Enum.Font.GothamMedium,
					TextSize = 12,
				}, themeRow)

				style(choice, 6, CARD_STROKE)
				attachTip(choice, {
					Text = if name == "Unity"
						then "Unity theme: tall or lopsided parts dark grey, even-sized or tiny parts orange, ceilings lighter grey. Partly see-through parts are purple."
						else "Pastel theme: a random soft color for every part. Partly see-through parts are purple.",
				})
				themeButtons[name] = choice
				choice.MouseButton1Click:Connect(function()
					deps.SetTheme(name)
					Colors.Retheme(deps.Colors)
					refresh()
				end)
			end

			table.insert(refreshers, function()
				for name, choice in themeButtons do
					local active = name == deps.GetTheme()

					choice.BackgroundColor3 = if active then ACCENT else TILE
					choice.TextColor3 = if active then BACKGROUND else TEXT
				end
			end)
		end
		switch(parent, "Surface grid", function()
			return deps.SurfaceGrid.On
		end, function(on)
			SurfaceGrid.Set(deps.SurfaceGrid, on)
		end)
		numeric(parent, "GridTextureSize", "Grid tile size (studs)", 1, 512, 1, {
			Condition = function()
				return deps.SurfaceGrid.On
			end,
		})

		do
			local swatches = { "FFFFFF", "FF8A24", "6CD0E0", "FFB3BA", "BAFFC9", "BAE1FF", "9AA0AA", "000000" }
			local colorRow = newRow(parent, 30)
			local hexBox = make("TextBox", {
				Size = UDim2.new(0, 70, 1, -2),
				Position = UDim2.new(1, -70, 0, 0),
				BackgroundColor3 = FIELD,
				BorderSizePixel = 0,
				Text = settings.GridColor,
				PlaceholderText = "RRGGBB",
				TextColor3 = TEXT,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				ClearTextOnFocus = false,
			}, colorRow)

			style(hexBox, 6, CARD_STROKE)
			register(colorRow, {
				Condition = function()
					return deps.SurfaceGrid.On
				end,
			})

			local function setColor(hex: string)
				if not string.match(hex, "^#?%x%x%x%x%x%x$") then
					hexBox.Text = settings.GridColor

					return
				end

				settings.GridColor = string.upper((string.gsub(hex, "^#", "")))
				hexBox.Text = settings.GridColor
				deps.Save()
				SurfaceGrid.Recolor(deps.SurfaceGrid)
			end

			for i, hex in swatches do
				local swatch = make("TextButton", {
					Size = UDim2.fromOffset(24, 24),
					Position = UDim2.fromOffset((i - 1) * 28, 2),
					BackgroundColor3 = SurfaceGrid.ColorOf(hex),
					BorderSizePixel = 0,
					Text = "",
				}, colorRow)

				style(swatch, 6, CARD_STROKE)
				attachTip(swatch, { Text = "Grid color #" .. hex })
				swatch.MouseButton1Click:Connect(function()
					setColor(hex)
				end)
			end

			hexBox.FocusLost:Connect(function()
				setColor(hexBox.Text)
			end)
		end
	end

	local category = "All"
	local pictureTheme = deps.GetTheme()
	local propBrowsers: { { show: () -> (), paint: () -> (), reload: () -> () } } = {}
	local showAllProps: () -> () = function() end
	local propChoices = { { Id = "All", Label = "All" } }

	for _, entry in PropData.Categories do
		table.insert(propChoices, entry)
	end

	--[[
		@param prop PropData.Prop
		@return ViewportFrame -- a picture of the prop. The parts live only inside the viewport, so they are local to this user and never reach the place.
	]]
	local function picture(prop: PropData.Prop, parent: Instance): ViewportFrame
		local view = make("ViewportFrame", {
			Size = UDim2.new(1, -8, 1, -24),
			Position = UDim2.fromOffset(4, 4),
			BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(150, 150, 160),
			LightColor = Color3.fromRGB(255, 255, 255),
			LightDirection = Vector3.new(-0.5, -1, 0.7),
		}, parent) :: ViewportFrame
		local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		local holder = Instance.new("Model")

		holder:SetAttribute("VluxyBT_Prop", prop.Id)
		holder.Parent = view

		for _, spec in Props.Build(prop, CFrame.new(), 1) do
			local part = Instance.new("Part")

			part.Name = spec.name
			part.Anchored = true
			part.Size = spec.size
			part.CFrame = spec.cf
			part.Material = Enum.Material.SmoothPlastic
			part.Parent = holder
			part.Color = Colors.Preview(deps.Colors, part)

			if spec.shape == "Cylinder" then
				part.Shape = Enum.PartType.Cylinder
			elseif spec.shape == "Ball" then
				part.Shape = Enum.PartType.Ball
			end

			local reach = spec.size.Magnitude / 2

			low = Vector3.new(
				math.min(low.X, spec.cf.Position.X - reach),
				math.min(low.Y, spec.cf.Position.Y - reach),
				math.min(low.Z, spec.cf.Position.Z - reach)
			)
			high = Vector3.new(
				math.max(high.X, spec.cf.Position.X + reach),
				math.max(high.Y, spec.cf.Position.Y + reach),
				math.max(high.Z, spec.cf.Position.Z + reach)
			)
		end

		local middle = (low + high) / 2
		local radius = math.max(2, (high - low).Magnitude / 2)
		local camera = Instance.new("Camera")

		camera.FieldOfView = 40
		camera.CFrame = CFrame.lookAt(middle + Vector3.new(0.9, 0.7, -1.3).Unit * radius * 2.4, middle)
		camera.Parent = view
		view.CurrentCamera = camera

		return view
	end

	--[[
		@param parent Instance -- the card to build the browser in

		Builds the row of sections and the grid of prop pictures. Every browser follows the same chosen section.
	]]
	local function propsBrowser(parent: Instance, compact: boolean)
		local expanded = not compact
		button(parent, "Reload prop pictures", function()
			for _, browser in propBrowsers do
				browser.reload()
			end
		end, false)

		local categoryButtons: { [string]: TextButton } = {}
		local cells: { [string]: { frame: Frame, button: TextButton } } = {}

		local sections = make("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
		}, parent)

		make("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -4, 0, 26),
			CellPadding = UDim2.fromOffset(4, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, sections)

		local shown = make("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
		}, parent)
		local toggle = button(parent, "Show all props", function()
			expanded = not expanded
			refresh()
		end, false)
		local toggleRow = toggle.Parent :: GuiObject

		make("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -4, 0, 104),
			CellPadding = UDim2.fromOffset(4, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, shown)

		local function paint()
			local theme = deps.GetTheme()

			if theme ~= pictureTheme then
				pictureTheme = theme

				for _, browser in propBrowsers do
					browser.reload()
				end

				return
			end

			local collapsed = compact and not expanded

			shown.AutomaticSize = if collapsed then Enum.AutomaticSize.None else Enum.AutomaticSize.Y
			shown.Size = if collapsed then UDim2.new(1, 0, 0, 104) else UDim2.fromScale(1, 0)
			shown.ClipsDescendants = collapsed
			toggleRow.Visible = compact
			toggle.Text = if expanded then "Show first row only" else "Show all props"

			for id, choice in categoryButtons do
				local active = id == category

				choice.BackgroundColor3 = if active then ACCENT else TILE
				choice.TextColor3 = if active then BACKGROUND else TEXT
			end

			local current = if deps.GetMode() == "Prop" then deps.GetProp() else nil
			local row = 0
			local place = 0

			for _, prop in PropData.Props do
				if category == "All" or prop.Category == category then
					if prop.Id == current then
						row = place // 3
					end

					place += 1
				end
			end

			place = 0

			for _, prop in PropData.Props do
				local cell = cells[prop.Id]

				if cell and (category == "All" or prop.Category == category) then
					cell.frame.Visible = not collapsed or place // 3 == row
					place += 1
				end
			end

			for id, cell in cells do
				cell.frame.BackgroundColor3 = if id == current then ACCENT else TILE
			end
		end

		local function show()
			for _, cell in cells do
				cell.frame.Visible = false
			end

			for i, prop in PropData.Props do
				if category == "All" or prop.Category == category then
					local cell = cells[prop.Id]

					if not cell then
						local frame = make("Frame", {
							BackgroundColor3 = TILE,
							BorderSizePixel = 0,
						}, shown)

						style(frame, 6, CARD_STROKE)
						picture(prop, frame)
						make("TextLabel", {
							Size = UDim2.new(1, -4, 0, 18),
							AnchorPoint = Vector2.new(0, 1),
							Position = UDim2.new(0, 2, 1, -2),
							BackgroundTransparency = 1,
							Text = prop.Label,
							TextColor3 = TEXT,
							Font = Enum.Font.GothamMedium,
							TextSize = 11,
							TextTruncate = Enum.TextTruncate.AtEnd,
						}, frame)

						local click = make("TextButton", {
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Text = "",
							ZIndex = 5,
						}, frame)

						attachTip(
							click,
							{ Text = prop.Label .. if prop.Mount == "wall" then " (hangs on a wall)." else "." }
						)
						click.MouseButton1Click:Connect(function()
							if settings.PropAutoCollapse then
								expanded = false
							end

							actions.PickProp(prop.Id)
						end)
						cell = { frame = frame, button = click }
						cells[prop.Id] = cell
					end

					cell.frame.LayoutOrder = i
					cell.frame.Visible = true
				end
			end

			paint()
		end

		for i, entry in propChoices do
			local choice = make("TextButton", {
				BackgroundColor3 = TILE,
				BorderSizePixel = 0,
				Text = entry.Label,
				TextColor3 = TEXT,
				Font = Enum.Font.GothamMedium,
				TextSize = 11,
				LayoutOrder = i,
			}, sections)

			style(choice, 6, CARD_STROKE)
			categoryButtons[entry.Id] = choice
			choice.MouseButton1Click:Connect(function()
				category = entry.Id
				showAllProps()
			end)
		end

		local function reload()
			for _, cell in cells do
				cell.frame:Destroy()
			end

			table.clear(cells)
			show()
		end

		table.insert(propBrowsers, { show = show, paint = paint, reload = reload })
		table.insert(refreshers, paint)
		show()
	end

	showAllProps = function()
		for _, browser in propBrowsers do
			browser.show()
		end
	end

	local function propSelected(): boolean
		return deps.GetMode() == "Prop" and deps.GetProp() ~= nil
	end

	do
		local propsCard = card("PROPS", "Props")

		text(
			propsCard,
			"Pick a section, then a prop, then click a floor (or a wall for wall props) to place it. R turns it.",
			MUTED
		)
		switch(propsCard, "Collapse props after picking one", function()
			return settings.PropAutoCollapse
		end, function(on)
			settings.PropAutoCollapse = on
			deps.Save()
			refresh()
		end)
		propsBrowser(propsCard, false)
		numeric(propsCard, "Yaw", "Rotation", -360, 360, 90, { Modes = { Prop = true }, Condition = propSelected })
		numeric(
			propsCard,
			"PropScale",
			"Prop size (x)",
			0.2,
			5,
			0.1,
			{ Modes = { Prop = true }, Condition = propSelected }
		)
		switch(propsCard, "Randomize prop rotation", function()
			return settings.PropRandomRotation
		end, function(on)
			settings.PropRandomRotation = on
			deps.Save()
			refresh()
		end, { Modes = { Prop = true }, Condition = propSelected })
		numeric(propsCard, "PropRandomAmount", "Random rotation (+/- degrees)", 0, 180, 5, {
			Modes = { Prop = true },
			Condition = function()
				return propSelected() and settings.PropRandomRotation
			end,
		})
	end

	do
		local buildProps = card("PROPS", "Build", { Modes = { Prop = true } })

		propsBrowser(buildProps, true)
		numeric(buildProps, "Yaw", "Rotation", -360, 360, 90, { Modes = { Prop = true }, Condition = propSelected })
		numeric(
			buildProps,
			"PropScale",
			"Prop size (x)",
			0.2,
			5,
			0.1,
			{ Modes = { Prop = true }, Condition = propSelected }
		)
		switch(buildProps, "Randomize prop rotation", function()
			return settings.PropRandomRotation
		end, function(on)
			settings.PropRandomRotation = on
			deps.Save()
			refresh()
		end, { Modes = { Prop = true }, Condition = propSelected })
		numeric(buildProps, "PropRandomAmount", "Random rotation (+/- degrees)", 0, 180, 5, {
			Modes = { Prop = true },
			Condition = function()
				return propSelected() and settings.PropRandomRotation
			end,
		})
	end

	local stepSection = function(delta: number)
		local at = 1

		for i, entry in propChoices do
			if entry.Id == category then
				at = i
			end
		end

		category = propChoices[(at - 1 + delta) % #propChoices + 1].Id
		showAllProps()
	end

	local stepProp = function(delta: number)
		local list: { PropData.Prop } = {}

		for _, prop in PropData.Props do
			if category == "All" or prop.Category == category then
				table.insert(list, prop)
			end
		end

		if #list == 0 then
			return
		end

		local current = if deps.GetMode() == "Prop" then deps.GetProp() else nil
		local at = 0

		for i, prop in list do
			if prop.Id == current then
				at = i
			end
		end

		if at == 0 and delta < 0 then
			at = #list + 1
		end

		actions.PickProp(list[(at - 1 + delta) % #list + 1].Id)
	end

	local displayCard = card("VIEWPORT DISPLAY", "Display")

	switch(displayCard, "Camera light", function()
		return settings.CameraLight
	end, function(on)
		settings.CameraLight = on
		deps.Save()
		refresh()
	end)
	numeric(displayCard, "CameraLightRange", "Light range (studs)", 4, 500, 10, {
		Condition = function()
			return settings.CameraLight
		end,
	})
	numeric(displayCard, "CameraLightBrightness", "Light brightness", 0.1, 20, 0.5, {
		Condition = function()
			return settings.CameraLight
		end,
	})

	displayRows(displayCard)
	switch(displayCard, "Construction grid while drawing", function()
		return settings.ShowGrid
	end, function(on)
		settings.ShowGrid = on
		deps.Save()
		refresh()
	end)
	text(
		displayCard,
		"Pastel colors and the surface grid both change the Parts inside your working folder, so your team sees them and they are saved with the place. Each switch undoes itself completely, even after Studio was closed and reopened. Switch them off before publishing.",
		MUTED
	)

	--
	-- Arrange page
	--

	local hiddenCard = card("HIDDEN PARTS", "Display")
	local hiddenCount = text(hiddenCard, "", TEXT)

	switch(hiddenCard, "Show hidden parts (ghosted)", function()
		return deps.Hidden.View
	end, function()
		actions.ToggleHiddenView()
	end)
	numeric(hiddenCard, "GhostTransparency", "Ghost transparency (0 solid, 1 clear)", 0.3, 0.98, 0.05)
	button(hiddenCard, "Unhide all (Alt+H)", actions.UnhideAll, false)
	text(
		hiddenCard,
		"Select parts and press H to hide them. Hiding is local to you: nothing in the place changes and nothing is saved.",
		MUTED
	)
	table.insert(refreshers, function()
		hiddenCount.Text = Hidden.Count(deps.Hidden) .. " hidden part(s)"
	end)

	--
	-- Arrange page
	--

	local flipCard = card("FLIP SELECTION  (Ctrl+M, then X / Y / Z)", "Arrange")

	text(flipCard, "Mirrors the selection in place, around its own centre.", MUTED)
	buttonRow(flipCard, {
		{
			Text = "Flip X",
			Run = function()
				actions.Flip("X")
			end,
		},
		{
			Text = "Flip Y",
			Run = function()
				actions.Flip("Y")
			end,
		},
		{
			Text = "Flip Z",
			Run = function()
				actions.Flip("Z")
			end,
		},
	})

	local rotateCard = card("ROTATE 90°  (O, then X / Y / Z)", "Arrange")

	buttonRow(rotateCard, {
		{
			Text = "+90° X",
			Run = function()
				actions.RotateBy("X", 90)
			end,
		},
		{
			Text = "+90° Y",
			Run = function()
				actions.RotateBy("Y", 90)
			end,
		},
		{
			Text = "+90° Z",
			Run = function()
				actions.RotateBy("Z", 90)
			end,
		},
	})
	buttonRow(rotateCard, {
		{
			Text = "−90° X",
			Run = function()
				actions.RotateBy("X", -90)
			end,
		},
		{
			Text = "−90° Y",
			Run = function()
				actions.RotateBy("Y", -90)
			end,
		},
		{
			Text = "−90° Z",
			Run = function()
				actions.RotateBy("Z", -90)
			end,
		},
	})

	local repeatCard = card("REPEAT SELECTED OBJECTS", "Arrange")

	numeric(repeatCard, "Copies", "Extra copies", 1, 100, 1)
	numeric(repeatCard, "DX", "X spacing", -2048, 2048)
	numeric(repeatCard, "DY", "Y spacing", -2048, 2048)
	numeric(repeatCard, "DZ", "Z spacing", -2048, 2048)
	button(repeatCard, "Make repeated copies", actions.RepeatCopies, true)

	local quickCard = card("QUICK ACTIONS", "Arrange")

	buttonRow(quickCard, {
		{ Text = "Snap selection", Run = actions.SnapSelection },
		{ Text = "Show dimensions", Run = actions.ShowDimensions },
	})
	button(quickCard, "Anchor selection", actions.AnchorSelection, false)

	--
	-- Settings page
	--

	local editing = card("EDITING", "Settings")

	switch(editing, "Allow untagged folders (not recommended)", function()
		return settings.AllowUntagged
	end, function(on)
		settings.AllowUntagged = on
		deps.Save()
		refresh()
	end, nil, true)

	numeric(editing, "FieldStep", "Arrow step", 0, 100, 0.05)
	numeric(editing, "Grid", "Snap increment", 0.05, 128, 0.5)
	numeric(editing, "FineGrid", "Fine snap (hold Shift)", 0.05, 128, 0.5)
	numeric(editing, "StandardHeight", "Standard wall height", 0.1, 2048)
	numeric(editing, "StandardThickness", "Standard wall thickness", 0.05, 512)
	numeric(editing, "StandardDoorWidth", "Standard doorway width", 0.1, 1024)
	numeric(editing, "StandardDoorHeight", "Standard doorway height", 0.1, 1024)
	numeric(editing, "Extend", "Face extend length", 0.1, 2048)
	switch(editing, "Blender hotkeys", function()
		return settings.Hotkeys
	end, function(on)
		settings.Hotkeys = on
		deps.Save()
		refresh()
		say(
			if on
				then "Blender hotkeys ON. See the Hotkeys tab (F1) for the list."
				else "Blender hotkeys OFF. Only Esc, Enter and [ ] keep working."
		)
	end)
	switch(editing, "Construction grid while drawing", function()
		return settings.ShowGrid
	end, function(on)
		settings.ShowGrid = on
		deps.Save()
		refresh()
	end)

	local reset = card("RESET", "Settings")

	text(reset, "Puts every number and switch on this panel back to its default. Your builds are not touched.", MUTED)
	button(reset, "Reset all settings", function()
		for key, default in Settings.Defaults() :: any do
			values[key] = default
		end

		for key, box in fieldBoxes do
			box.Text = tostring(values[key])
		end

		deps.Save()
		refresh()
		say("Settings reset to the defaults.")
	end, false)

	--
	-- Hotkeys page
	--

	local keys = card("HOTKEYS", "Hotkeys")

	for _, binding in Keymap.Describe() do
		local row = make("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
		}, keys)

		make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, row)

		local chip = make("TextLabel", {
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = TILE,
			BorderSizePixel = 0,
			Text = binding[1],
			TextColor3 = ACCENT,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			LayoutOrder = 1,
		}, row)

		style(chip, 5, CARD_STROKE)
		make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, chip)

		local description = text(row, binding[2], MUTED)

		description.LayoutOrder = 2
		make("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundTransparency = 1, LayoutOrder = 3 }, row)
	end

	local tips = card("TIPS", "Hotkeys")

	text(
		tips,
		"Draw tools: click the first point, move the mouse, then click again. The preview shows the size before you build.",
		MUTED
	)
	text(tips, "Walls and corridors continue from the last point. Start new chain begins somewhere else.", MUTED)
	text(
		tips,
		"Door and arch openings replace a childless rectangular wall with separate Parts. Undo restores the original.",
		MUTED
	)
	text(tips, "Every completed build supports Studio Undo and Redo. The plugin adds no scripts to your game.", MUTED)

	--
	-- Refresh
	--

	refresh = function()
		hideTooltip()

		local mode = deps.GetMode()

		for _, entry in entries do
			local visible = true

			if entry.Modes then
				visible = entry.Modes[mode or "None"] == true
			end

			if entry.Advanced then
				visible = visible and advanced
			end

			if entry.Condition then
				visible = visible and entry.Condition()
			end

			entry.Frame.Visible = visible
		end

		local locked = deps.GetFolder() == nil
		local workingFolder = deps.GetFolder()

		for name, frame in pages do
			frame.Visible = name == page and not (locked and LOCKED[name] == true)
		end

		lockedNote.Visible = locked and LOCKED[page] == true
		local pending = deps.GetPending()
		local shown = pending or (if deps.GetPicking() then nil else workingFolder)

		folderName.Visible = shown ~= nil
		folderName.Text = if shown then shown:GetFullName() else ""
		local conflictTheme = deps.GetConflict()

		folderText.Text = if conflictTheme
			then `This folder has different settings ({conflictTheme}). Use the folder's, overwrite them with yours, or cancel?`
			elseif pending then "Work in this folder?"
			elseif deps.GetPicking() then "Click a Folder in the viewport or select one."
			elseif workingFolder then "Working folder. Select it to outline it."
			else "Press the button, then pick a Folder in Workspace."
		pickButton.Text = if workingFolder then "Change working folder" else "Choose working folder"

		for name, tab in tabButtons do
			local active = name == page

			tab.BackgroundColor3 = if active then ACCENT else CARD
			tab.TextColor3 = if active then BACKGROUND else TEXT
			tab.Font = if active then Enum.Font.GothamBold else Enum.Font.GothamMedium
		end

		for id, tile in tiles do
			local owner = mode and Tools.TileOf(mode)
			local active = owner ~= nil and owner.Id == id

			tile.Button.BackgroundColor3 = if active then ACCENT_DIM else TILE
			tile.Stroke.Color = if active then ACCENT else CARD_STROKE
		end

		local tool = mode and Tools.Find(mode)

		headerGlyph.Text = if tool then tool.Glyph else ""
		headerName.Text = if tool then string.upper(tool.Label) else ""
		headerChevron.Text = if toolOpen then "⌃" else "⌄"
		hint.Text = actions.Instruction(mode)
		advancedButton.Text = (if advanced then "▼  " else "▶  ") .. "Advanced options"

		for _, refresher in refreshers do
			refresher()
		end
	end

	refresh()

	return {
		Say = say,
		Refresh = refresh,
		SetField = function(key: string)
			local box = fieldBoxes[key]

			if box then
				box.Text = tostring(values[key])
			end
		end,
		CycleTab = function(delta: number)
			local index = table.find(TABS, page) or 1

			leavePage()
			page = TABS[(index - 1 + delta) % #TABS + 1]
			refresh()
		end,
		StepSection = function(delta: number)
			stepSection(delta)
		end,
		StepProp = function(delta: number)
			stepProp(delta)
		end,
		OnPropsTab = function(): boolean
			return page == "Props"
		end,
		ShowTab = function(name: string)
			if pages[name] then
				leavePage()
				page = name
				refresh()
			end
		end,
	}
end

return Panel
