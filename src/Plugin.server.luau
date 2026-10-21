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

--[[ Studio's customize list only shows a toolbar's first button, so the other two also exist as actions, which it lists separately. ]]
local openAction =
	plugin:CreatePluginAction("VluxyBT_Open", PluginInfo.Name, "Open " .. PluginInfo.Name, Icons.Toolbar.Main, true)
local pastelAction = plugin:CreatePluginAction(
	"VluxyBT_Pastel",
	"VluxyBT Pastel colors",
	"Pastel colors on or off",
	Icons.Toolbar.Pastel,
	true
)
local gridAction = plugin:CreatePluginAction(
	"VluxyBT_Grid",
	"VluxyBT Surface grid",
	"Surface grid on or off",
	Icons.Toolbar.Grid,
	true
)

local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left, false, false, 360, 740, 320, 420)
local widget = plugin:CreateDockWidgetPluginGuiAsync(WIDGET_ID, info)

widget.Title = PluginInfo.Name

local controller = Controller.new(plugin, widget, trove :: any)

trove:Connect(button.Click, function()
	widget.Enabled = not widget.Enabled
end)
trove:Connect(openAction.Triggered, function()
	widget.Enabled = not widget.Enabled
end)
trove:Connect(widget:GetPropertyChangedSignal("Enabled"), function()
	button:SetActive(widget.Enabled)

	if not widget.Enabled then
		controller.Stop()
	end
end)
button:SetActive(widget.Enabled)

trove:Connect(pastelButton.Click, controller.TogglePastel)
trove:Connect(gridButton.Click, controller.ToggleGrid)
trove:Connect(pastelAction.Triggered, controller.TogglePastel)
trove:Connect(gridAction.Triggered, controller.ToggleGrid)

local sinceSync = 0

trove:Connect(RunService.Heartbeat, function(dt)
	sinceSync += dt

	if sinceSync < 0.25 then
		return
	end

	sinceSync = 0
	pastelButton:SetActive(controller.PastelOn())
	gridButton:SetActive(controller.GridOn())
end)

trove:Connect(plugin.Unloading, function()
	controller.Destroy()
	trove:Clean()
end)
