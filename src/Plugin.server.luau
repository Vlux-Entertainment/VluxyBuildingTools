--!strict

--[[
	Entry point of the VluxyBuildingTools plugin. It adds the toolbar button and the dock widget,
	hands them to the controller, and cleans everything up when the plugin unloads.
]]

local RunService = game:GetService("RunService")

local Controller = require("./Core/Controller")
local PluginInfo = require("./Pure/PluginInfo")
local Trove = require("./Packages/Trove")

if not RunService:IsStudio() then
	return
end

local WIDGET_ID = "VluxyBuildingTools_left"

local trove = Trove.new()
local toolbar = plugin:CreateToolbar(PluginInfo.Name)
local button = toolbar:CreateButton(PluginInfo.Name, "Open " .. PluginInfo.Name, "", PluginInfo.Name)

button.ClickableWhenViewportHidden = true

local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left, false, false, 360, 740, 320, 420)
local widget = plugin:CreateDockWidgetPluginGuiAsync(WIDGET_ID, info)

widget.Title = PluginInfo.Name

local controller = Controller.new(plugin, widget, trove :: any)

trove:Connect(button.Click, function()
	widget.Enabled = not widget.Enabled
end)
trove:Connect(widget:GetPropertyChangedSignal("Enabled"), function()
	button:SetActive(widget.Enabled)

	if not widget.Enabled then
		controller.Stop()
	end
end)
button:SetActive(widget.Enabled)

local pastelButton = toolbar:CreateButton("PastelColors", "Pastel colors on or off (P)", "", "Pastel")
local gridButton = toolbar:CreateButton("SurfaceGrid", "Surface grid on or off (L)", "", "Grid")

pastelButton.ClickableWhenViewportHidden = true
gridButton.ClickableWhenViewportHidden = true
trove:Connect(pastelButton.Click, controller.TogglePastel)
trove:Connect(gridButton.Click, controller.ToggleGrid)

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
