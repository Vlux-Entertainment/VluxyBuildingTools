--!strict
--# selene: allow(mixed_table)

--[=[
	The dock widget's contents: a header, the working folder card, the tab bar, the status line, and
	one page per tab (see `Ui/Pages`). The panel holds no tool logic: it shows `AppState` and the
	settings in `Store`, and every button calls into `App/Actions` or a service.

	Built with vide, so it redraws itself: there is no refresh to call.

	@class Panel
]=]

local Actions = require("../App/Actions")
local AppState = require("../State/AppState")
local AppTypes = require("../App/Types")
local Controls = require("./Controls")
local Kit = require("./Kit")
local PluginInfo = require("../Pure/PluginInfo")
local Popups = require("./Popups")
local Theme = require("./Theme")
local Tips = require("../Pure/Tips")
local vide = require("../Packages/vide")

local PAGES: { [string]: (ui: Controls.Ui) -> { Instance } } = {
	Build = require("./Pages/Build"),
	Props = require("./Pages/Props"),
	Arrange = require("./Pages/Arrange"),
	Display = require("./Pages/Display"),
	Hotkeys = require("./Pages/Hotkeys"),
	Settings = require("./Pages/Settings"),
}
local FolderCard = require("./Pages/Folder")

local new = Kit.New

local Panel = {}

--[[
	@return Frame -- the logo, name and version
]]
local function header(): Frame
	return new("Frame")({
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		new("TextLabel")({
			Size = UDim2.fromOffset(32, 32),
			Position = UDim2.fromOffset(2, 3),
			BackgroundColor3 = Theme.Accent,
			Text = "V",
			TextColor3 = Theme.Background,
			Font = Enum.Font.GothamBlack,
			TextSize = 20,
			Kit.Corner(7),
		}),
		new("TextLabel")({
			Size = UDim2.new(1, -120, 1, 0),
			Position = UDim2.fromOffset(44, 0),
			BackgroundTransparency = 1,
			Text = PluginInfo.Name,
			TextColor3 = Theme.Text,
			Font = Enum.Font.GothamBlack,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		new("TextLabel")({
			Size = UDim2.fromOffset(40, 38),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			BackgroundTransparency = 1,
			Text = PluginInfo.Version,
			TextColor3 = Theme.Muted,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	})
end

--[[
	@param ui Controls.Ui
	@return Frame -- one button per tab, the open one lit
]]
local function tabBar(ui: Controls.Ui): Frame
	local app = ui.App
	local pages = AppState.Pages
	local buttons = {}

	for i, name in pages do
		local function active(): boolean
			return app.State.Page() == name
		end

		table.insert(
			buttons,
			new("TextButton")({
				Size = UDim2.new(1 / #pages, -4, 1, -8),
				Position = UDim2.new((i - 1) / #pages, 4, 0, 4),
				BackgroundColor3 = function()
					return if active() then Theme.Accent else Theme.Card
				end,
				TextColor3 = function()
					return if active() then Theme.Background else Theme.Text
				end,
				Font = function()
					return if active() then Enum.Font.GothamBold else Enum.Font.GothamMedium
				end,
				BorderSizePixel = 0,
				Text = name,
				TextSize = 12,
				AutoButtonColor = false,
				Kit.Corner(5),
				ui.Popups.Tip(Tips.Find(name)),
				MouseButton1Click = function()
					app.Sound("Tab")
					Actions.ShowPage(app, name)
				end,
			})
		)
	end

	return new("Frame")({
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Theme.Card,
		BorderSizePixel = 0,
		LayoutOrder = 3,
		Kit.Corner(7),
		Kit.Stroke(),
		buttons,
	})
end

--[[
	@param app App
	@return boolean -- whether a tab that needs a working folder is locked now
]]
local function locked(app: AppTypes.App, name: string): boolean
	return app.State.Folder() == nil and AppState.Locked[name] == true
end

--[=[
	Builds the panel inside the app's dock widget.

	@param app App
	@return () -> () -- removes the panel
]=]
function Panel.Mount(app: AppTypes.App): () -> ()
	local widget = app.Widget

	Kit.Animate = function()
		return app.Store.Values.UiAnimations
	end

	local root = new("ScrollingFrame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Kit.Padding(10, 10, 14),
		Kit.List(8),
	}) :: ScrollingFrame
	local popups: Popups.Popups

	local destroy = vide.root(function()
		popups = Popups.new(widget)

		local ui: Controls.Ui = { App = app, Popups = popups, Root = root }
		local pages = {}

		for index, name in AppState.Pages do
			table.insert(
				pages,
				new("Frame")({
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 10 + index,
					Visible = function()
						return app.State.Page() == name and not locked(app, name)
					end,
					Kit.List(8),
					PAGES[name](ui),
				})
			)
		end

		local folderCard = FolderCard(ui)
		local lockedNote = Controls.Text(ui, "Pick a working folder above to start.", Theme.Accent, function()
			return locked(app, app.State.Page())
		end)

		folderCard.LayoutOrder = 2
		lockedNote.LayoutOrder = 5

		local children: { any } = {
			header(),
			folderCard,
			tabBar(ui),
			new("TextLabel")({
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = app.State.Status,
				TextColor3 = Theme.Muted,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 4,
			}),
			lockedNote,
			pages,
		}

		vide.apply(root)(children)
		vide.effect(function()
			app.State.Page()
			app.State.Mode()
			vide.untrack(popups.HideTip)
		end)
	end)

	root.Parent = widget

	for _, frame in popups.Frames do
		frame.Parent = widget
	end

	return function()
		destroy()
		root:Destroy()

		for _, frame in popups.Frames do
			frame:Destroy()
		end
	end
end

return Panel
