--!strict
--# selene: allow(mixed_table)

--[=[
	The smallest building blocks of the panel, on top of vide. A property given as a function is
	reactive: vide re-runs it and updates the property whenever a source it reads changes.

	Children in a list are ordered by `LayoutOrder`, and `Kit.Next` hands out increasing numbers,
	so every block that calls it shows in the order it was built.

	@class Kit
]=]

local TweenService = game:GetService("TweenService")

local Theme = require("./Theme")
local vide = require("../Packages/vide")

--[=[
	@type Prop<T> T | () -> T
	@within Kit

	A plain value, or a function that vide re-reads reactively.
]=]
export type Prop<T> = T | () -> T

local Kit = {}

local order = 0
local POP_SCALE = 1.06
local POP_GROW = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP_SETTLE = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

--[=[
	Whether the panel animates, read at each click and frame; `Panel` points it at the UI animations setting.

	@prop Animate () -> boolean
	@within Kit
]=]
Kit.Animate = function(): boolean
	return true
end

--[=[
	Whether lists of rows are striped; `Panel` points it at the zebra rows setting.

	@prop Zebra vide.Source<boolean>
	@within Kit
]=]
Kit.Zebra = vide.source(true)

local ROW = "Row"
local BAND = "VluxyBT_Band"
local ROW_INSET = 6

--[[
	@param container Instance

	Shades every other row that shows, in LayoutOrder, so a value lines up with its label at a
	glance; hidden rows are skipped so the stripes never double up.
]]
local function stripe(container: Instance)
	local rows: { GuiObject } = {}

	for _, child in container:GetChildren() do
		if child.Name == ROW and child:IsA("GuiObject") and child.Visible then
			table.insert(rows, child)
		end
	end

	table.sort(rows, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)

	local on = Kit.Zebra()

	for index, row in rows do
		if not row:FindFirstChild(BAND) then
			local corner = Instance.new("UICorner")

			corner.Name = BAND
			corner.CornerRadius = UDim.new(0, 5)
			corner.Parent = row

			local inset = Instance.new("UIPadding")

			inset.PaddingLeft = UDim.new(0, ROW_INSET)
			inset.PaddingRight = UDim.new(0, ROW_INSET)
			inset.Parent = row
			row.BackgroundColor3 = Theme.Tile
			row.BorderSizePixel = 0
		end

		row.BackgroundTransparency = if on and index % 2 == 1 then 0 else 1
	end
end

--[=[
	A vide action that stripes the container's rows (see `Kit.Row`), and keeps the stripes right as
	rows show, hide or come and go, and as the zebra rows setting changes.

	@return any -- the action, to put among the container's properties
]=]
function Kit.Striped(): any
	return vide.action(function(instance: Instance)
		local queued = false

		local function later()
			if queued then
				return
			end

			queued = true
			task.defer(function()
				queued = false
				stripe(instance)
			end)
		end

		local function watch(child: Instance)
			if child.Name == ROW and child:IsA("GuiObject") then
				child:GetPropertyChangedSignal("Visible"):Connect(later)
				later()
			end
		end

		for _, child in instance:GetChildren() do
			watch(child)
		end

		instance.ChildAdded:Connect(watch)
		instance.ChildRemoved:Connect(later)
		vide.effect(function()
			Kit.Zebra()
			later()
		end)
	end)
end

--[[ When each target last popped, so a click that also selects the button pops it once, not twice. ]]
local lastPop: { [GuiObject]: number } = setmetatable({}, { __mode = "k" }) :: any

--[=[
	Grows the button a little and settles it back. A see-through button laid over something, such
	as a prop picture, grows what it covers instead. Does nothing while UI animations are off.

	@param button GuiObject
]=]
function Kit.Pop(button: GuiObject)
	if not Kit.Animate() then
		return
	end

	local covers = button:IsA("GuiButton")
		and button.BackgroundTransparency >= 1
		and not (button:IsA("TextButton") and button.Text ~= "")
		and button.Parent
		and button.Parent:IsA("GuiObject")
	local target = (if covers then button.Parent else button) :: GuiObject
	local now = os.clock()

	if now - (lastPop[target] or -1) < 0.1 then
		return
	end

	lastPop[target] = now

	local scale = target:FindFirstChild("VluxyBT_Pop") :: UIScale?

	if not scale then
		local made = Instance.new("UIScale")

		made.Name = "VluxyBT_Pop"
		made.Parent = target
		scale = made
	end

	local grow = TweenService:Create(scale :: UIScale, POP_GROW, { Scale = POP_SCALE })

	grow.Completed:Once(function()
		TweenService:Create(scale :: UIScale, POP_SETTLE, { Scale = 1 }):Play()
	end)
	grow:Play()
end

--[=[
	Follows a condition the way it settles, not every blink: it turns true at once, but only turns
	false if still false once the current change is over. A tool switch that passes through "no
	tool" for an instant therefore never reads as off.

	@param condition () -> boolean -- read reactively
	@return () -> boolean -- the settled value
]=]
function Kit.Settled(condition: () -> boolean): () -> boolean
	local settled = vide.untrack(condition)

	vide.effect(function()
		if condition() then
			task.defer(function()
				settled = true
			end)
		else
			task.defer(function()
				if not vide.untrack(condition) then
					settled = false
				end
			end)
		end
	end)

	return function()
		return settled
	end
end

--[=[
	A vide action that pops the button each time it becomes the selected one, however that
	happened: a click, a hotkey or the wheel. A selection that only blinks off and on does not pop.

	@param selected () -> boolean
	@param allow (() -> boolean)? -- asked when the button becomes selected; false skips the pop
	@return any -- the action, to put among the button's properties
]=]
function Kit.PopWhen(selected: () -> boolean, allow: (() -> boolean)?): any
	return vide.action(function(instance: Instance)
		local was = Kit.Settled(selected)

		vide.effect(function()
			if selected() and not was() and (allow == nil or allow()) then
				Kit.Pop(instance :: GuiObject)
			end
		end)
	end)
end

--[=[
	@param class string
	@return (props: { [any]: any }) -> any -- makes an instance of the class from vide properties; buttons pop when clicked
]=]
function Kit.New(class: string): (props: { [any]: any }) -> any
	local make = (vide.create :: any)(class)

	if class ~= "TextButton" and class ~= "ImageButton" then
		return make
	end

	return function(props: { [any]: any }): any
		local button = make(props) :: GuiButton

		button.Activated:Connect(function()
			Kit.Pop(button)
		end)

		return button
	end
end

--[=[
	@return number -- a LayoutOrder after every one handed out before
]=]
function Kit.Next(): number
	order += 1

	return order
end

--[=[
	@param radius number
	@return UICorner
]=]
function Kit.Corner(radius: number): UICorner
	return Kit.New("UICorner")({ CornerRadius = UDim.new(0, radius) })
end

--[=[
	@param color Prop<Color3>?
	@return UIStroke -- a one-pixel border, the card stroke color by default
]=]
function Kit.Stroke(color: Prop<Color3>?): UIStroke
	return Kit.New("UIStroke")({
		Color = color or Theme.CardStroke,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

--[=[
	@param x number -- left and right padding
	@param y number -- top padding
	@param bottom number? -- bottom padding, y by default
	@return UIPadding
]=]
function Kit.Padding(x: number, y: number, bottom: number?): UIPadding
	return Kit.New("UIPadding")({
		PaddingLeft = UDim.new(0, x),
		PaddingRight = UDim.new(0, x),
		PaddingTop = UDim.new(0, y),
		PaddingBottom = UDim.new(0, bottom or y),
	})
end

--[=[
	@param gap number
	@return UIListLayout -- a vertical list ordered by LayoutOrder
]=]
function Kit.List(gap: number): UIListLayout
	return Kit.New("UIListLayout")({ Padding = UDim.new(0, gap), SortOrder = Enum.SortOrder.LayoutOrder })
end

--[=[
	@param columns number
	@param height number -- the height of each cell
	@param gap number
	@return UIGridLayout -- a grid of equal columns ordered by LayoutOrder
]=]
function Kit.Grid(columns: number, height: number, gap: number): UIGridLayout
	return Kit.New("UIGridLayout")({
		CellSize = UDim2.new(1 / columns, -gap, 0, height),
		CellPadding = UDim2.fromOffset(gap, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

--[=[
	A frame that grows to fit its children, for grouping rows.

	@param children { any }
	@param visible Prop<boolean>?
	@return Frame
]=]
function Kit.Group(children: { any }, visible: Prop<boolean>?): Frame
	return Kit.New("Frame")({
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = Kit.Next(),
		Visible = visible or true,
		Kit.List(4),
		Kit.Striped(),
		children,
	})
end

--[=[
	@param height number
	@param children { any }
	@param visible Prop<boolean>?
	@return Frame -- a fixed-height row to place controls in
]=]
function Kit.Row(height: number, children: { any }, visible: Prop<boolean>?): Frame
	return Kit.New("Frame")({
		Name = ROW,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = Kit.Next(),
		Visible = visible or true,
		children,
	})
end

--[=[
	@param active () -> boolean
	@return { [string]: any } -- background and text color properties for a choice button that lights up when active
]=]
function Kit.Lit(active: () -> boolean): { [string]: any }
	return {
		BackgroundColor3 = function()
			return if active() then Theme.Accent() else Theme.Tile
		end,
		TextColor3 = function()
			return if active() then Theme.Background else Theme.Text
		end,
	}
end

return Kit
