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

trove:Connect(plugin.Unloading, function()
	controller.Destroy()
	trove:Clean()
end)
