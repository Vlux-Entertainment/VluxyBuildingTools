--!strict
--# selene: allow(mixed_table)

--[=[
	The panel's controls: cards, text, buttons, number fields, switches, a slider and choice rows.
	Each control that shows a setting reads it from the `Store` reactively and writes it back through
	the `Store`, so it always shows the saved value and every change is saved.

	Every control takes a `Visible` that may be a function; the control shows only while it returns
	true. That is how the panel shows just the options of the active tool.

	@class Controls
]=]

local AppTypes = require("../App/Types")
local Kit = require("./Kit")
local Popups = require("./Popups")
local Settings = require("../Pure/Settings")
local Store = require("../State/Store")
local Theme = require("./Theme")
local Tips = require("../Pure/Tips")
local vide = require("../Packages/vide")

type Prop<T> = Kit.Prop<T>

--[=[
	What every control is built with.

	@interface Ui
	@within Controls
	.App App
	.Popups Popups
	.Root GuiObject -- the panel's scrolling root, which sees mouse moves anywhere in the panel
]=]
export type Ui = {
	App: AppTypes.App,
	Popups: Popups.Popups,
	Root: GuiObject,
}

local new = Kit.New

local Controls = {}

--[=[
	@param ui Ui
	@param run () -> ()
	@return () -> () -- runs `run`, and shows an error in the status line instead of letting it escape
]=]
function Controls.Safe(ui: Ui, run: () -> ()): () -> ()
	return function()
		local ok, err = pcall(run :: any)

		if not ok then
			ui.App.Say("Action stopped: " .. tostring(err))
			warn("[VluxyBuildingTools] " .. tostring(err))
		end
	end
end

--[=[
	@param ui Ui
	@param frame GuiObject -- the row to right-click
	@param defaultText string -- the default, as shown in the menu
	@param reset () -> ()

	Right-clicking the row offers to put that one setting back to its default.
]=]
local function resetMenu(ui: Ui, defaultText: string, reset: () -> ()): any
	return vide.action(function(instance: Instance)
		(instance :: GuiObject).InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				ui.Popups.Menu(
					Vector2.new(input.Position.X, input.Position.Y),
					`Reset to default ({defaultText})`,
					reset
				)
			end
		end)
	end)
end

--[=[
	@param ui Ui
	@param title string? -- shown small and muted at the top; hovering it shows its description from `Tips`
	@param children { any }
	@param visible Prop<boolean>?
	@return Frame -- a rounded card holding rows
]=]
function Controls.Card(ui: Ui, title: string?, children: { any }, visible: Prop<boolean>?): Frame
	return new("Frame")({
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Card,
		BorderSizePixel = 0,
		LayoutOrder = Kit.Next(),
		Visible = visible or true,
		Kit.Corner(8),
		Kit.Stroke(),
		Kit.Padding(10, 8),
		Kit.List(4),
		if title
			then new("TextLabel")({
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
				Text = title,
				TextColor3 = Theme.Muted,
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = -1,
				ui.Popups.Tip(Tips.Find(title)),
			})
			else nil,
		children,
	})
end

--[=[
	@param ui Ui
	@param text Prop<string>
	@param color Color3?
	@param visible Prop<boolean>?
	@return TextLabel -- wrapping text, muted by default
]=]
function Controls.Text(_ui: Ui, text: Prop<string>, color: Color3?, visible: Prop<boolean>?): TextLabel
	return new("TextLabel")({
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color or Theme.Muted,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = Kit.Next(),
		Visible = visible or true,
	})
end

--[=[
	@param ui Ui
	@param label Prop<string>
	@param run () -> ()
	@param primary boolean? -- the orange call to action
	@param visible Prop<boolean>?
	@return Frame -- a full-width button row
]=]
function Controls.Button(ui: Ui, label: Prop<string>, run: () -> (), primary: boolean?, visible: Prop<boolean>?): Frame
	return Kit.Row(34, {
		new("TextButton")({
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = if primary then Theme.Accent else Theme.Tile,
			BorderSizePixel = 0,
			Text = label,
			TextColor3 = if primary then Theme.Background else Theme.Text,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			AutoButtonColor = true,
			Kit.Corner(6),
			if primary then nil else Kit.Stroke(),
			ui.Popups.Tip(if type(label) == "string" then Tips.Find(label) else nil),
			MouseButton1Click = function()
				ui.App.Sound("Click")
				Controls.Safe(ui, run)()
			end,
		}),
	}, visible)
end

--[=[
	@interface Item
	@within Controls
	.Text string
	.Run () -> ()
	.Primary boolean?
]=]
export type Item = { Text: string, Run: () -> (), Primary: boolean? }

--[=[
	@param ui Ui
	@param items { Item }
	@param visible Prop<boolean>?
	@return Frame -- buttons side by side, sharing the row equally
]=]
function Controls.ButtonRow(ui: Ui, items: { Item }, visible: Prop<boolean>?): Frame
	local buttons = {}

	for i, item in items do
		table.insert(
			buttons,
			new("TextButton")({
				Size = UDim2.new(1 / #items, -4, 1, 0),
				Position = UDim2.fromScale((i - 1) / #items, 0),
				BackgroundColor3 = if item.Primary then Theme.Accent else Theme.Tile,
				BorderSizePixel = 0,
				Text = item.Text,
				TextColor3 = if item.Primary then Theme.Background else Theme.Text,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextWrapped = true,
				Kit.Corner(6),
				if item.Primary then nil else Kit.Stroke(),
				ui.Popups.Tip(Tips.Find(item.Text)),
				MouseButton1Click = function()
					ui.App.Sound("Click")
					Controls.Safe(ui, item.Run)()
				end,
			})
		)
	end

	return Kit.Row(34, buttons, visible)
end

--[=[
	A number setting.

	@interface NumberSpec
	@within Controls
	.Key string -- the setting
	.Title string
	.Min number
	.Max number
	.Step number? -- what − and + add; the snap increment by default
	.Integer boolean? -- round down to a whole number
	.Visible Prop<boolean>?
]=]
export type NumberSpec = {
	Key: string,
	Title: string,
	Min: number,
	Max: number,
	Step: number?,
	Integer: boolean?,
	Visible: Prop<boolean>?,
}

--[[
	@param ui Ui
	@param x number
	@param label string
	@param run () -> ()
	@return TextButton -- a small − or + button
]]
local function stepper(ui: Ui, x: number, label: string, run: () -> ()): TextButton
	return new("TextButton")({
		Size = UDim2.fromOffset(34, 28),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, x, 0.5, 0),
		BackgroundColor3 = Theme.Tile,
		BorderSizePixel = 0,
		Text = label,
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		Kit.Corner(5),
		Kit.Stroke(),
		MouseButton1Click = function()
			ui.App.Sound("Click")
			run()
		end,
	})
end

--[=[
	@param ui Ui
	@param spec NumberSpec
	@return Frame -- a labelled number box with − and + buttons. A field that overrides its standard value is marked with *.
]=]
function Controls.Number(ui: Ui, spec: NumberSpec): Frame
	local store = ui.App.Store
	local values = store.Values :: any
	local key = spec.Key
	local flag = Settings.OverrideFlag(key)
	local box: TextBox

	local function apply(value: number?)
		if value and value == value and math.abs(value) < math.huge then
			local clamped = math.clamp(value, spec.Min, spec.Max)

			Store.Set(store, key, if spec.Integer then math.floor(clamped) else clamped)
		end

		box.Text = tostring(values[key])
	end

	local function step(): number
		local fieldStep = values.FieldStep

		return if key ~= "FieldStep" and fieldStep > 0 then fieldStep else (spec.Step or values.Grid)
	end

	box = new("TextBox")({
		Size = UDim2.fromOffset(82, 28),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 40, 0.5, 0),
		BackgroundColor3 = Theme.Field,
		BorderSizePixel = 0,
		Text = function()
			return tostring(Store.Get(store, key))
		end,
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		ClearTextOnFocus = false,
		Kit.Corner(5),
		Kit.Stroke(),
		FocusLost = function()
			apply(tonumber(box.Text))
		end,
	})

	local initial = (Settings.Defaults() :: any)[key]

	return Kit.Row(36, {
		new("TextLabel")({
			Size = UDim2.new(1, -170, 1, 0),
			BackgroundTransparency = 1,
			Text = function()
				return if flag and Store.Get(store, flag) then spec.Title .. " *" else spec.Title
			end,
			TextColor3 = Theme.Text,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			ui.Popups.Tip(Tips.Find(key)),
		}),
		new("Frame")({
			Size = UDim2.fromOffset(162, 36),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			BackgroundTransparency = 1,
			stepper(ui, 0, "−", function()
				apply(values[key] - step())
			end),
			box,
			stepper(ui, 128, "+", function()
				apply(values[key] + step())
			end),
		}),
		if type(initial) == "number"
			then resetMenu(ui, tostring(initial), function()
				apply(initial)
			end)
			else nil,
	}, spec.Visible)
end

--[=[
	An on/off switch, for a setting (`Key`) or for anything else (`Get` and `Set`).

	@interface SwitchSpec
	@within Controls
	.Title string
	.Key string? -- the boolean setting it shows and sets
	.Get (() -> boolean)? -- read reactively, when there is no Key
	.Set ((on: boolean) -> ())? -- when there is no Key
	.After ((on: boolean) -> ())? -- runs after a change, such as saying what it did
	.Danger boolean? -- shown in red, for settings that are risky to turn on
	.Visible Prop<boolean>?
]=]
export type SwitchSpec = {
	Title: string,
	Key: string?,
	Get: (() -> boolean)?,
	Set: ((on: boolean) -> ())?,
	After: ((on: boolean) -> ())?,
	Danger: boolean?,
	Visible: Prop<boolean>?,
}

--[=[
	@param ui Ui
	@param spec SwitchSpec
	@return Frame -- a labelled switch
]=]
function Controls.Switch(ui: Ui, spec: SwitchSpec): Frame
	local store = ui.App.Store
	local key = spec.Key
	local get: () -> boolean = if key
		then function()
			return Store.Get(store, key) == true
		end
		else spec.Get :: () -> boolean
	local set: (boolean) -> () = if key
		then function(on: boolean)
			Store.Set(store, key, on)
		end
		else spec.Set :: (boolean) -> ()
	local onColor = if spec.Danger then Theme.Danger else Theme.Accent
	local initial = if key then (Settings.Defaults() :: any)[key] else nil

	local function change(on: boolean)
		set(on)

		if spec.After then
			spec.After(on)
		end
	end

	return Kit.Row(36, {
		new("TextLabel")({
			Size = UDim2.new(1, -60, 1, 0),
			BackgroundTransparency = 1,
			Text = spec.Title,
			TextColor3 = if spec.Danger then Theme.Danger else Theme.Text,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			ui.Popups.Tip(Tips.Find(spec.Title)),
		}),
		new("TextButton")({
			Size = UDim2.fromOffset(44, 24),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			BackgroundColor3 = function()
				return if get() then onColor else Theme.SwitchOff
			end,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			Kit.Corner(12),
			new("Frame")({
				Size = UDim2.fromOffset(18, 18),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = function()
					return UDim2.new(0, if get() then 23 else 3, 0.5, 0)
				end,
				BackgroundColor3 = Theme.White,
				BorderSizePixel = 0,
				Kit.Corner(9),
			}),
			MouseButton1Click = function()
				ui.App.Sound("Click")
				Controls.Safe(ui, function()
					change(not get())
				end)()
			end,
		}),
		if type(initial) == "boolean"
			then resetMenu(ui, if initial then "on" else "off", function()
				change(initial)
			end)
			else nil,
	}, spec.Visible)
end

--[=[
	@param ui Ui
	@param key string -- a number setting from 0 to 1
	@param title string
	@param visible Prop<boolean>?
	@return Frame -- a draggable slider showing the value as a percent. It saves when the drag ends.
]=]
function Controls.Slider(ui: Ui, key: string, title: string, visible: Prop<boolean>?): Frame
	local store = ui.App.Store
	local dragging = false
	local bar: Frame

	local function value(): number
		return math.clamp(Store.Get(store, key) :: number, 0, 1)
	end

	local function setFrom(x: number)
		local fraction = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)

		Store.Hold(store, key, math.round(fraction * 100) / 100)
	end

	bar = new("Frame")({
		Size = UDim2.new(1, 0, 0, 6),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		BackgroundColor3 = Theme.SwitchOff,
		BorderSizePixel = 0,
		Kit.Corner(3),
		new("Frame")({
			Size = function()
				return UDim2.fromScale(value(), 1)
			end,
			BackgroundColor3 = Theme.Accent,
			BorderSizePixel = 0,
			Kit.Corner(3),
		}),
		new("Frame")({
			Size = UDim2.fromOffset(14, 14),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = function()
				return UDim2.fromScale(value(), 0.5)
			end,
			BackgroundColor3 = Theme.White,
			BorderSizePixel = 0,
			Kit.Corner(7),
		}),
	})

	vide.cleanup(ui.Root.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			setFrom(input.Position.X)
		end
	end))
	vide.cleanup(ui.Root.InputEnded:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
			Store.Save(store)
			ui.App.Sound("Tab")
		end
	end))

	local initial = (Settings.Defaults() :: any)[key]

	return Kit.Row(36, {
		new("TextLabel")({
			Size = UDim2.new(1, -190, 1, 0),
			BackgroundTransparency = 1,
			Text = title,
			TextColor3 = Theme.Text,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			ui.Popups.Tip(Tips.Find(key)),
		}),
		new("TextButton")({
			Size = UDim2.fromOffset(130, 28),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -46, 0.5, 0),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			bar,
			InputBegan = function(input: InputObject)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging = true
					setFrom(input.Position.X)
				end
			end,
		}),
		new("TextLabel")({
			Size = UDim2.fromOffset(40, 36),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			BackgroundTransparency = 1,
			TextColor3 = Theme.Text,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			Text = function()
				return string.format("%d%%", math.round(value() * 100))
			end,
		}),
		resetMenu(ui, tostring(initial), function()
			Store.Set(store, key, initial)
		end),
	}, visible)
end

--[=[
	One option of a choice row.

	@interface Option
	@within Controls
	.Value string
	.Label string? -- the button text, the value by default
	.Tip string? -- the tooltip
	.Key string? -- the hotkey shown in the tooltip
]=]
export type Option = { Value: string, Label: string?, Tip: string?, Key: string? }

--[=[
	A row of buttons where one is picked, such as roof styles or color themes.

	@interface ChoiceSpec
	@within Controls
	.Options { Option }
	.Columns number
	.Get () -> string? -- the picked value, read reactively
	.Set (value: string) -> ()
	.Visible Prop<boolean>?
]=]
export type ChoiceSpec = {
	Options: { Option },
	Columns: number,
	Get: () -> string?,
	Set: (value: string) -> (),
	Visible: Prop<boolean>?,
}

--[=[
	@param ui Ui
	@param spec ChoiceSpec
	@return Frame -- the buttons in a grid, the picked one lit
]=]
function Controls.Choice(ui: Ui, spec: ChoiceSpec): Frame
	local buttons = {}
	local columns = spec.Columns

	for i, option in spec.Options do
		table.insert(
			buttons,
			new("TextButton")({
				Size = UDim2.new(1 / columns, -4, 0, 30),
				Position = UDim2.new(((i - 1) % columns) / columns, 0, 0, math.floor((i - 1) / columns) * 32),
				BorderSizePixel = 0,
				Text = option.Label or option.Value,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				Kit.Lit(function()
					return spec.Get() == option.Value
				end),
				Kit.Corner(6),
				Kit.Stroke(),
				ui.Popups.Tip(if option.Tip then { Text = option.Tip, Key = option.Key } else nil),
				MouseButton1Click = function()
					ui.App.Sound("Click")
					Controls.Safe(ui, function()
						spec.Set(option.Value)
					end)()
				end,
			})
		)
	end

	return Kit.Row(math.ceil(#spec.Options / columns) * 32 - 2, buttons, spec.Visible)
end

return Controls
