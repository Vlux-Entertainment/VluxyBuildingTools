--!strict

--[=[
	The composition root: builds every service, tool host and the panel, and wires them together.
	Nothing else creates services, so this file is the map of how the plugin fits together. The
	entry script gets back a small `Handle` to start, stop and unload it.

	Where to look for what:

	- a tool's behavior: `Tools/` (start at `Tools/Registry`)
	- extrude, grab, rotate, scale: `Modal/`
	- what a key or button does: `App/Actions`; which key is which: `Pure/Keymap`
	- the panel: `Ui/`
	- settings and what they mean: `Pure/Settings`, stored by `State/Store`

	@class App
]=]

local RunService = game:GetService("RunService")

local Actions = require("./Actions")
local Admin = require("../Services/Admin")
local AppState = require("../State/AppState")
local AppTypes = require("./Types")
local Arrange = require("../Core/Arrange")
local CameraLight = require("../Services/CameraLight")
local Cursor = require("../Services/Cursor")
local Display = require("../Services/Display")
local Edit = require("../Services/Edit")
local EditSounds = require("../Services/EditSounds")
local FolderTint = require("../Services/FolderTint")
local GuideSnap = require("../Services/GuideSnap")
local Hidden = require("../Core/Hidden")
local Host = require("../Modal/Host")
local Input = require("./Input")
local Overlay = require("../Core/Overlay")
local Panel = require("../Ui/Panel")
local Runner = require("../Tools/Runner")
local Sounds = require("../Core/Sounds")
local Status = require("../Services/Status")
local Store = require("../State/Store")
local ToolTypes = require("../Tools/Types")
local Trove = require("../Packages/Trove")
local WorkingFolder = require("../Services/WorkingFolder")
local vide = require("../Packages/vide")

--[=[
	What the entry script can do with the running plugin.

	@interface Handle
	@within App
	.Stop () -> () -- ends any tool or action
	.Suspend () -> () -- the panel closed: put the map back to how it looks without the plugin
	.Resume () -> () -- the panel opened again
	.TogglePastel () -> ()
	.ToggleGrid () -> ()
	.State AppState -- for the toolbar buttons
	.Destroy () -> () -- the plugin is unloading
]=]
export type Handle = {
	Stop: () -> (),
	Suspend: () -> (),
	Resume: () -> (),
	TogglePastel: () -> (),
	ToggleGrid: () -> (),
	State: AppState.AppState,
	Destroy: () -> (),
}

local UPDATE_INTERVAL = 0.05

--[[ How long after the plugin changes parts itself the Studio-tool sounds stay quiet. ]]
local PLUGIN_QUIET = 0.5

local App = {}

--[=[
	@param plugin Plugin
	@param widget DockWidgetPluginGui -- the panel's dock widget
	@param trove Trove -- takes every connection the plugin makes
	@return Handle
]=]
function App.new(plugin: Plugin, widget: DockWidgetPluginGui, trove: Trove.Trove): Handle
	--[[
		Strict mode runs every effect twice to catch impure ones, which would double side effects such
		as recoloring the map. vide's own instance defaults differ from Roblox's, which the panel is drawn against.
	]]
	vide.strict = false
	vide.defaults = false

	local store = Store.new(plugin)
	local settings = store.Values
	local state = AppState.new()
	local overlay = Overlay.new(trove)
	local mouse = plugin:GetMouse()
	local display: Display.Display
	local cursor = Cursor.new(mouse, settings, function()
		return Hidden.Parts(display.Hidden)
	end)
	local runner: Runner.Runner
	local host: Host.Host
	local status = Status.new(state, overlay, function()
		return Host.Describe(host) or Runner.Describe(runner)
	end)

	local function say(text: string)
		Status.Say(status, text)
	end

	local function warnUser(text: string)
		Status.Warn(status, text)
	end

	local sounds = Sounds.new(plugin, function()
		return settings.SoundEnabled
	end, function()
		return settings.SoundVolume
	end, trove)

	local function sound(name: string)
		Sounds.Play(sounds, name)
	end

	local function release()
		Overlay.HideBar(overlay)
		plugin:Deactivate()
	end

	--[[
		@param keepActive boolean? -- keep the mouse, because something else is about to start

		Ends any modal action and tool.
	]]
	local function stopAll(keepActive: boolean?)
		Host.Halt(host)
		Runner.Stop(runner)

		if not keepActive then
			release()
		end
	end

	local admin = Admin.new({
		State = state,
		Say = say,
		IsOpen = function()
			return widget.Enabled
		end,
	}, trove)

	local function isAdmin(): boolean
		return state.IsAdmin()
	end

	--[[ When the plugin last changed parts itself, so Studio-tool sounds do not also play for it. ]]
	local pluginBusyAt = 0

	local edit = Edit.new({
		Say = say,
		Sound = sound,
		Adopt = function(part)
			Display.Adopt(display, part)
		end,
		Sweep = function()
			pluginBusyAt = os.clock()
			Display.Sweep(display)
		end,
	})

	display = Display.new({
		Store = store,
		State = state,
		Edit = edit,
		Say = say,
		StopTools = function()
			stopAll()
		end,
		IsAdmin = isAdmin,
	}, trove)

	FolderTint.new({ Store = store }, trove)

	local folder = WorkingFolder.new({
		Store = store,
		State = state,
		Overlay = overlay,
		Display = display,
		Cursor = cursor,
		Edit = edit,
		Say = say,
		Warn = function(text)
			warnUser(text)
			sound("Warning")
		end,
		StopTools = function()
			stopAll()
		end,
		IsOpen = function()
			return widget.Enabled
		end,
		IsAdmin = isAdmin,
		OthersOn = function(target)
			return Admin.OthersOn(admin, target)
		end,
	}, trove)

	local context: ToolTypes.Context = {
		Plugin = plugin,
		Settings = settings,
		Store = store,
		State = state,
		Cursor = cursor,
		Overlay = overlay,
		Edit = edit,
		Say = say,
		Sound = sound,
	}

	host = Host.new({
		Started = function()
			plugin:Activate(true)
		end,
		Ended = release,
		Say = say,
	})

	runner = Runner.new({
		Context = context,
		CanStart = function()
			if not WorkingFolder.Require(folder) then
				return false
			end

			if not RunService:IsEdit() then
				say("Stop the playtest before using tools.")

				return false
			end

			return true
		end,
		Starting = function()
			Host.Halt(host)
		end,
		Started = function()
			plugin:Activate(true)
		end,
		Stopped = release,
	})

	local arrange = Arrange.new({
		Settings = settings,
		Edit = edit,
		Say = say,
		Stop = function()
			stopAll()
		end,
		Ghosts = function(specs)
			if #specs == 0 then
				Overlay.ClearGhosts(overlay)
			else
				Overlay.DrawGhosts(overlay, specs)
			end
		end,
	})

	EditSounds.new({
		Sound = sound,
		Busy = function()
			return os.clock() - pluginBusyAt < PLUGIN_QUIET
		end,
		Dropped = function()
			GuideSnap.AfterDrag(
				Store.Get(store, "GrabGuides") == true and Store.Get(store, "SnapToParts") == true,
				edit,
				Store.Get(store, "GuideSnapPixels")
			)
		end,
		Moving = function()
			GuideSnap.Hint(
				Store.Get(store, "GrabGuides") == true and Store.Get(store, "SnapToParts") == true,
				overlay,
				Store.Get(store, "GuideSnapPixels")
			)
		end,
		Finished = function()
			GuideSnap.ClearHint(overlay)
		end,
	}, trove)

	local cameraLight = CameraLight.new(settings, trove)

	local app: AppTypes.App = {
		Plugin = plugin,
		Widget = widget,
		Store = store,
		State = state,
		Overlay = overlay,
		Cursor = cursor,
		Status = status,
		Context = context,
		Display = display,
		Folder = folder,
		Runner = runner,
		Modal = host,
		Arrange = arrange,
		Sounds = sounds,
		CameraLight = cameraLight,
		Admin = admin,
		Say = say,
		Sound = sound,
		StopAll = stopAll,
	}

	Input.Connect(app, mouse, trove)
	trove:Add(Panel.Mount(app))

	trove:Connect(plugin.Deactivation, function()
		Overlay.HideBar(overlay)
		Host.Halt(host)
		Runner.Stop(runner)
	end)

	trove:Connect(widget:GetPropertyChangedSignal("Enabled"), function()
		if not widget.Enabled and WorkingFolder.IsPicking(folder) then
			WorkingFolder.CancelPicking(folder)
		end
	end)

	local elapsed = 0

	trove:Connect(RunService.Heartbeat, function(dt)
		if Host.Running(host) or runner.Mode ~= nil then
			pluginBusyAt = os.clock()
		end

		Overlay.PositionReadout(overlay)
		CameraLight.Step(cameraLight)
		Host.Step(host)
		WorkingFolder.Step(folder, dt)
		Admin.Step(admin, dt)

		elapsed += dt

		if elapsed < UPDATE_INTERVAL then
			return
		end

		elapsed = 0

		if not RunService:IsEdit() then
			if runner.Mode or Host.Running(host) then
				stopAll()
			end

			arrange.PreviewArray(false)

			return
		end

		arrange.PreviewArray(
			widget.Enabled and state.Page() == "Arrange" and runner.Mode == nil and not Host.Running(host)
		)
		Runner.Step(runner)
	end)

	WorkingFolder.Detect(folder)

	--[[
		Puts the map back to normal while the plugin is not in use: grid and pastel come off, hidden
		parts show again and the camera light goes out, unless a teammate still has the plugin open.
		This user stops being present on the working folder, which hands admin on.

		@return boolean -- whether a teammate still has the plugin open
	]]
	local function suspend(): boolean
		stopAll()
		cameraLight.Suspended = true
		CameraLight.Step(cameraLight)

		local others = Admin.OthersHere(admin)

		if not others then
			Display.Suspend(display)
		end

		Admin.Leave(admin)

		return others
	end

	return {
		Stop = function()
			stopAll()
		end,
		Suspend = function()
			suspend()
		end,
		Resume = function()
			cameraLight.Suspended = false
			Admin.Step(admin, 0)

			if WorkingFolder.Get(folder) then
				Display.RestoreAuto(display)
			end
		end,
		TogglePastel = function()
			Actions.TogglePastel(app)
		end,
		ToggleGrid = function()
			Actions.ToggleGrid(app)
		end,
		State = state,
		Destroy = function()
			Store.Save(store)

			if not suspend() then
				Display.Unload(display)
			end
		end,
	}
end

return App
