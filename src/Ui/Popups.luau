--!strict
--# selene: allow(mixed_table)

--[=[
	The panel's two floating pieces: the hover tooltip (a description and, when there is one, the
	hotkey) and the one-item menu, such as the right-click reset of a setting or an avatar's admin
	choice. There is one of each per panel, drawn above everything else.

	@class Popups
]=]

local Kit = require("./Kit")
local Theme = require("./Theme")
local Tips = require("../Pure/Tips")
local vide = require("../Packages/vide")

--[=[
	@type TipSource Tips.Tip? | () -> Tips.Tip?
	@within Popups

	A tip, or a function read each time the mouse comes to rest, for a tip that changes.
]=]
export type TipSource = Tips.Tip? | () -> Tips.Tip?

export type Popups = {
	--[=[ Returns a vide action that shows the tip while the mouse rests on the instance. ]=]
	Tip: (tip: TipSource) -> any,
	--[=[ Shows the one-item menu at the mouse. ]=]
	Menu: (position: Vector2, label: string, run: () -> ()) -> (),
	HideTip: () -> (),
	Frames: { GuiObject },
}

local Popups = {}

--[=[
	@param widget DockWidgetPluginGui -- where the popups are drawn
	@param delay () -> number? -- how long the mouse rests before a tip shows, read at each hover; nil for no tips
	@return Popups
]=]
function Popups.new(widget: DockWidgetPluginGui, delay: () -> number?): Popups
	local new = Kit.New
	local token = 0
	local text = vide.source("")
	local key = vide.source(nil :: string?)
	local shown = vide.source(false)
	local at = vide.source(Vector2.zero)

	local tooltip = new("Frame")({
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Theme.Tooltip,
		BorderSizePixel = 0,
		ZIndex = 100,
		Visible = shown,
		Kit.Corner(6),
		Kit.Stroke(Theme.TooltipStroke),
		Kit.Padding(9, 7),
		Kit.List(5),
		new("TextLabel")({
			Size = UDim2.fromOffset(220, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = Theme.Text,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 101,
			LayoutOrder = 1,
		}),
		new("TextLabel")({
			Size = UDim2.fromOffset(0, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Theme.Tile,
			BorderSizePixel = 0,
			Text = function()
				return key() or ""
			end,
			Visible = function()
				return key() ~= nil
			end,
			TextColor3 = Theme.Accent,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			ZIndex = 101,
			LayoutOrder = 2,
			Kit.Corner(4),
			Kit.Stroke(),
			new("UIPadding")({ PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }),
		}),
	}) :: Frame

	--[[ Keeps the tooltip next to the mouse and inside the widget. ]]
	local function place()
		local space, size, mouse = widget.AbsoluteSize, tooltip.AbsoluteSize, at()

		tooltip.Position = UDim2.fromOffset(
			math.max(4, math.min(mouse.X + 14, space.X - size.X - 6)),
			math.max(4, math.min(mouse.Y + 18, space.Y - size.Y - 6))
		)
	end

	local function hideTip()
		token += 1
		shown(false)
	end

	local function tip(source: TipSource): any
		return vide.action(function(instance: Instance)
			local object = instance :: GuiObject

			if not source then
				return
			end

			object.Active = true
			object.MouseEnter:Connect(function(x, y)
				token += 1

				local mine = token
				local wait = delay()

				if not wait then
					return
				end

				task.delay(wait, function()
					local info = if type(source) == "function" then source() else source

					if token == mine and info then
						text(info.Text)
						key(info.Key)
						at(Vector2.new(x, y))
						shown(true)
						place()
					end
				end)
			end)
			object.MouseMoved:Connect(function(x, y)
				if shown() then
					at(Vector2.new(x, y))
					place()
				end
			end)
			object.MouseLeave:Connect(hideTip)
		end)
	end

	local menuRun: (() -> ())? = nil
	local menuOpen = vide.source(false)
	local menuLabel = vide.source("")
	local menuAt = vide.source(Vector2.zero)

	local function closeMenu()
		menuOpen(false)
		menuRun = nil
	end

	local catcher = new("TextButton")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 100,
		Visible = menuOpen,
		MouseButton1Click = closeMenu,
		MouseButton2Click = closeMenu,
	})
	local item = new("TextButton")({
		Size = UDim2.fromOffset(210, 28),
		Position = function()
			return UDim2.fromOffset(math.min(menuAt().X, widget.AbsoluteSize.X - 214), menuAt().Y)
		end,
		BackgroundColor3 = Theme.Tile,
		BorderSizePixel = 0,
		Text = menuLabel,
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		ZIndex = 101,
		Visible = menuOpen,
		Kit.Corner(6),
		Kit.Stroke(),
		MouseButton1Click = function()
			local run = menuRun

			closeMenu()

			if run then
				run()
			end
		end,
	})

	return {
		Tip = tip,
		Menu = function(position: Vector2, label: string, run: () -> ())
			menuLabel(label)
			menuAt(position)
			menuRun = run
			menuOpen(true)
		end,
		HideTip = hideTip,
		Frames = { tooltip, catcher, item },
	}
end

return Popups
