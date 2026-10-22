--!strict

--[[
	Entry point of the VluxyBuildingTools plugin. It adds the toolbar button and the dock widget,
	hands them to the controller, and cleans everything up when the plugin unloads.
]]

local RunService = game:GetService("RunService")

local Controller = require("./Core/Controller")
local Icons = require("./Pure/Icons")
local PluginInfo = require("./Pure/PluginInfo")
local Trove = require("./Packages/Trove")

if not RunService:IsStudio() then
	return
end

local WIDGET_ID = "VluxyBuildingTools_left"

local trove = Trove.new()
local toolbar = plugin:CreateToolbar(PluginInfo.Name)
local button = toolbar:CreateButton(PluginInfo.Name, "Open " .. PluginInfo.Name, Icons.Toolbar.Main, PluginInfo.Name)

button.ClickableWhenViewportHidden = true

--[[ Every button is made before the dock widget below, which yields, so Studio lists all of them when you customize your tabs. ]]
local pastelButton = toolbar:CreateButton("PastelColors", "Pastel colors on or off (P)", Icons.Toolbar.Pastel, "Pastel")
local gridButton = toolbar:CreateButton("SurfaceGrid", "Surface grid on or off (L)", Icons.Toolbar.Grid, "Grid")

pastelButton.ClickableWhenViewportHidden = true
gridButton.ClickableWhenViewportHidden = true

local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left, false, false, 360, 740, 320, 420)
local widget = plugin:CreateDockWidgetPluginGuiAsync(WIDGET_ID, info)

widget.Title = PluginInfo.Name

local controller = Controller.new(plugin, widget, trove :: any)

if not widget.Enabled then
	task.defer(controller.Suspend)
end

trove:Connect(button.Click, function()
	widget.Enabled = not widget.Enabled
end)
trove:Connect(widget:GetPropertyChangedSignal("Enabled"), function()
	button:SetActive(widget.Enabled)

	if widget.Enabled then
		controller.Resume()
	else
		controller.Stop()
		controller.Suspend()
	end
end)
button:SetActive(widget.Enabled)

trove:Connect(pastelButton.Click, controller.TogglePastel)
trove:Connect(gridButton.Click, controller.ToggleGrid)

local sinceSync = 0

trove:Connect(RunService.Heartbeat, function(dt)
	sinceSync += dt

	if sinceSync < 0.25 then
		return
	end

	sinceSync = 0
	local pastel, grid = controller.PastelOn(), controller.GridOn()

	pastelButton:SetActive(pastel)
	gridButton:SetActive(grid)
	pastelButton.Icon = if pastel or Icons.Toolbar.PastelOff == ""
		then Icons.Toolbar.Pastel
		else Icons.Toolbar.PastelOff
	gridButton.Icon = if grid or Icons.Toolbar.GridOff == "" then Icons.Toolbar.Grid else Icons.Toolbar.GridOff
end)

trove:Connect(plugin.Unloading, function()
	controller.Destroy()
	trove:Clean()
end)
