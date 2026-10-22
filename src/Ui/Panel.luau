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
local Changelog = require("../Pure/Changelog")
local Controls = require("./Controls")
local Kit = require("./Kit")
local Overlay = require("../Core/Overlay")
local PluginInfo = require("../Pure/PluginInfo")
local Popups = require("./Popups")
local Store = require("../State/Store")
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
	@param open () -> () -- shows the version list
	@return Frame -- the logo, name and version; the version opens the list of what changed
]]
local function header(open: () -> ()): Frame
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
		new("TextButton")({
			Size = UDim2.fromOffset(56, 38),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			BackgroundTransparency = 1,
			Text = "v" .. PluginInfo.Version,
			TextColor3 = Theme.Muted,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			MouseButton1Click = open,
		}),
	})
end

--[[
	@param shown vide.Source<boolean> -- whether the list is open
	@return Frame -- a screen over the whole panel listing every release and what changed, newest first
]]
local function versions(shown: vide.Source<boolean>): Frame
	local releases = {}

	for index, release in Changelog do
		local lines = {}

		for line, change in release.Changes do
			table.insert(
				lines,
				new("TextLabel")({
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = "•  " .. change,
					TextColor3 = Theme.Text,
					Font = Enum.Font.Gotham,
					TextSize = 12,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = line,
					ZIndex = 53,
				})
			)
		end

		table.insert(
			releases,
			new("Frame")({
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.Card,
				BorderSizePixel = 0,
				LayoutOrder = index,
				ZIndex = 52,
				Kit.Corner(8),
				Kit.Padding(10, 8),
				Kit.List(4),
				new("TextLabel")({
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundTransparency = 1,
					Text = `v{release.Version}   <font color="#8B8E96">{release.Date}</font>`,
					RichText = true,
					TextColor3 = if index == 1 then Theme.Accent else Theme.Text,
					Font = Enum.Font.GothamBold,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 0,
					ZIndex = 53,
				}),
				lines,
			})
		)
	end

	return new("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Visible = shown,
		ZIndex = 50,
		new("TextLabel")({
			Size = UDim2.new(1, -60, 0, 44),
			Position = UDim2.fromOffset(12, 0),
			BackgroundTransparency = 1,
			Text = "WHAT'S NEW",
			TextColor3 = Theme.Muted,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 51,
		}),
		new("TextButton")({
			Size = UDim2.fromOffset(32, 32),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 6),
			BackgroundColor3 = Theme.Tile,
			BorderSizePixel = 0,
			Text = "✕",
			TextColor3 = Theme.Text,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			ZIndex = 51,
			Kit.Corner(6),
			MouseButton1Click = function()
				shown(false)
			end,
		}),
		new("ScrollingFrame")({
			Size = UDim2.new(1, 0, 1, -44),
			Position = UDim2.fromOffset(0, 44),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ZIndex = 51,
			Kit.Padding(10, 0, 14),
			Kit.List(8),
			releases,
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

		local hovered = vide.source(false)

		table.insert(
			buttons,
			new("TextButton")({
				Size = UDim2.new(1 / #pages, -4, 1, -8),
				Position = UDim2.new((i - 1) / #pages, 4, 0, 4),
				BackgroundColor3 = function()
					local color = if active() then Theme.Accent() else Theme.Card

					return if hovered() then color:Lerp(Theme.White, if active() then 0.15 else 0.08) else color
				end,
				Kit.PopWhen(active),
				MouseEnter = function()
					hovered(true)
				end,
				MouseLeave = function()
					hovered(false)
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
	Kit.Intensity = function()
		return app.Store.Values.AnimationIntensity
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
	local versionList: Frame

	local destroy = vide.root(function()
		local showVersions = vide.source(false)

		versionList = versions(showVersions)
		popups = Popups.new(widget, function()
			local values = app.Store.Values

			return if values.Tooltips then values.TooltipDelay else nil
		end)

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
			header(function()
				showVersions(true)
			end),
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
			Theme.SetAccent(Store.Get(app.Store, "UiAccent"))
		end)
		vide.effect(function()
			Kit.Zebra(Store.Get(app.Store, "ZebraRows") == true)
		end)
		vide.effect(function()
			local follow = Store.Get(app.Store, "PreviewsFollowUi") == true

			Overlay.SetAccent(app.Overlay, if follow then Theme.Accent() else Theme.Accents[1].Color)
		end)
		vide.effect(function()
			Overlay.AllowBar(app.Overlay, Store.Get(app.Store, "HintBar") == true)
		end)
		vide.effect(function()
			app.State.Page()
			app.State.Mode()
			vide.untrack(popups.HideTip)
		end)
	end)

	root.Parent = widget
	versionList.Parent = widget

	for _, frame in popups.Frames do
		frame.Parent = widget
	end

	return function()
		destroy()
		root:Destroy()
		versionList:Destroy()

		for _, frame in popups.Frames do
			frame:Destroy()
		end
	end
end

return Panel
