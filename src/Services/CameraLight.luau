--!strict

--[=[
	A point light that follows the editor camera while the Camera light setting is on. It lives
	under the camera, so it is never saved into the place.

	@class CameraLight
]=]

local RunService = game:GetService("RunService")

local Settings = require("../Pure/Settings")
local Trove = require("../Packages/Trove")

export type CameraLight = {
	--[=[ True while the plugin is closed; the light is off then. ]=]
	Suspended: boolean,
	_settings: Settings.Settings,
	_holder: Part?,
}

local CameraLight = {}

--[=[
	@param settings Settings -- the live settings
	@param trove Trove -- removes the light when the plugin unloads
	@return CameraLight
]=]
function CameraLight.new(settings: Settings.Settings, trove: Trove.Trove): CameraLight
	local self: CameraLight = { Suspended = false, _settings = settings, _holder = nil }

	trove:Add(function()
		if self._holder then
			self._holder:Destroy()
			self._holder = nil
		end
	end)

	return self
end

--[[
	@param camera Camera
	@return Part -- an invisible, locked holder with a PointLight, parented to the camera
]]
local function makeHolder(camera: Camera): Part
	local holder = Instance.new("Part")

	holder.Name = "VluxyBT_CameraLight"
	holder.Size = Vector3.one * 0.2
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Locked = true
	holder.Parent = camera

	local light = Instance.new("PointLight")

	light.Shadows = false
	light.Parent = holder

	return holder
end

--[=[
	Runs every frame: makes, moves or removes the light to match the setting.

	@param self CameraLight
]=]
function CameraLight.Step(self: CameraLight)
	local camera = workspace.CurrentCamera
	local settings = self._settings

	if self.Suspended or not settings.CameraLight or not camera or not RunService:IsEdit() then
		if self._holder then
			self._holder:Destroy()
			self._holder = nil
		end

		return
	end

	local holder = self._holder

	if not holder or not holder.Parent then
		holder = makeHolder(camera)
		self._holder = holder
	end

	assert(holder, "the holder was just made")

	local light = holder:FindFirstChildOfClass("PointLight")

	holder.CFrame = camera.CFrame

	if light then
		light.Range = settings.CameraLightRange
		light.Brightness = settings.CameraLightBrightness
	end
end

return CameraLight
