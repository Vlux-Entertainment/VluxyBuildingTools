--!strict

--[[
	Entry point of the VluxyBuildingTools plugin. It adds the toolbar button; the tools themselves
	are not built yet.
]]

local PluginInfo = require("./Pure/PluginInfo")

local toolbar = plugin:CreateToolbar(PluginInfo.Name)
local button = toolbar:CreateButton(PluginInfo.Name, "Open " .. PluginInfo.Name, "")

button.ClickableWhenViewportHidden = true
