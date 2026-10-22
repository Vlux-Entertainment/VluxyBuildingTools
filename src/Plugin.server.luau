--!strict

--[[
	Entry point of the VluxyBuildingTools plugin. It adds the toolbar buttons and the dock widget,
	starts the app (`App/App`), and cleans everything up when the plugin unloads.
]]

local RunService = game:GetService("RunService")

local App = require("./App/App")
local Icons = require("./Pure/Icons")
local PluginInfo = require("./Pure/PluginInfo")
local Trove = require("./Packages/Trove")
local vide = require("./Packages/vide")

if not RunService:IsStudio() then
	return
end

local WIDGET_ID = "VluxyBuildingTools_left"

local trove = Trove.new()
local toolbar = plugin:CreateToolbar(PluginInfo.Name)
local button = toolbar:CreateButton(PluginInfo.Name, "Open " .. PluginInfo.Name, Icons.Toolbar.Main, PluginInfo.Name)

button.ClickableWhenViewportHidden = true

--[[ Every button is made before the dock widget below, which yields, so Studio lists all of them when you customize your tabs. ]]
local pastelButton = toolbar:CreateButton("PastelColors", "Themes on or off (P)", Icons.Toolbar.Pastel, "Themes")
local gridButton = toolbar:CreateButton("SurfaceGrid", "Surface grid on or off (L)", Icons.Toolbar.Grid, "Grid")

pastelButton.ClickableWhenViewportHidden = true
gridButton.ClickableWhenViewportHidden = true

local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left, false, false, 360, 740, 320, 420)
local widget = plugin:CreateDockWidgetPluginGuiAsync(WIDGET_ID, info)

widget.Title = PluginInfo.Name

local app = App.new(plugin, widget, trove :: any)

if not widget.Enabled then
	task.defer(app.Suspend)
end

trove:Connect(button.Click, function()
	widget.Enabled = not widget.Enabled
end)
trove:Connect(widget:GetPropertyChangedSignal("Enabled"), function()
	button:SetActive(widget.Enabled)

	if widget.Enabled then
		app.Resume()
	else
		app.Suspend()
	end
end)
button:SetActive(widget.Enabled)

trove:Connect(pastelButton.Click, app.TogglePastel)
trove:Connect(gridButton.Click, app.ToggleGrid)

--[[ The toolbar buttons follow the pastel and grid switches, wherever they were flipped from. ]]
trove:Add(vide.root(function()
	vide.effect(function()
		local on = app.State.PastelOn()

		pastelButton:SetActive(on)
		pastelButton.Icon = if on or Icons.Toolbar.PastelOff == ""
			then Icons.Toolbar.Pastel
			else Icons.Toolbar.PastelOff
	end)
	vide.effect(function()
		local on = app.State.GridOn()

		gridButton:SetActive(on)
		gridButton.Icon = if on or Icons.Toolbar.GridOff == "" then Icons.Toolbar.Grid else Icons.Toolbar.GridOff
	end)
end))

trove:Connect(plugin.Unloading, function()
	app.Destroy()
	trove:Clean()
end)
