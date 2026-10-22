--!strict

--[=[
	Turns raw input into actions: key presses through `Pure/Keymap`, typed digits into the active
	numeric entry, mouse clicks into the tool or modal action, and Ctrl/Alt with the wheel into tool
	stepping. Every connection goes into the trove it is given.

	@class Input
]=]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Actions = require("./Actions")
local AppTypes = require("./Types")
local Cursor = require("../Services/Cursor")
local Host = require("../Modal/Host")
local Keymap = require("../Pure/Keymap")
local NumericInput = require("../Pure/NumericInput")
local Runner = require("../Tools/Runner")
local Trove = require("../Packages/Trove")
local WorkingFolder = require("../Services/WorkingFolder")

type App = AppTypes.App

--[=[
	Actions that start something new. They are ignored while a modal action runs, or when Studio
	already used the key.

	@prop STARTS { [string]: boolean }
	@within Input
]=]
local STARTS: { [string]: boolean } = {
	Extrude = true,
	Grab = true,
	Rotate = true,
	Scale = true,
	Duplicate = true,
	NextTab = true,
	PrevTab = true,
	ShowHotkeys = true,
	TogglePastel = true,
	ToggleGrid = true,
	ToggleCameraLight = true,
	TogglePanel = true,
	Hide = true,
	Unhide = true,
	ToggleHiddenView = true,
	FlipArm = true,
	Rotate90Arm = true,
}

--[[ Hotkeys that keep working when Blender hotkeys are switched off. ]]
local ALWAYS_ON: { [string]: boolean } = { Cancel = true, Confirm = true, HeightUp = true, HeightDown = true }

local CAMERA_HOLD = 0.25

local Input = {}

--[[
	@param action string
	@return boolean -- true for a tool pick or an option pick
]]
local function isPick(action: string): boolean
	return string.sub(action, 1, 5) == "Tool:" or string.sub(action, 1, 7) == "Option:"
end

--[[
	@param app App
	@param key string -- `Enum.KeyCode.Name`
	@param processed boolean -- whether Studio already used the key

	Handles one key press.

	@return boolean -- true when the key was P for themes, which acts on release unless the wheel turned while it was held
]]
local function keyPressed(app: App, key: string, processed: boolean): boolean
	local runner, modal = app.Runner, app.Modal
	local active = modal.Active
	local running = active ~= nil

	if active and active.Key and active.Key(key) then
		return false
	end

	if app.Store.Values.Hotkeys then
		local entry = Host.Typing(modal) or Runner.Typing(runner)

		if entry and NumericInput.Press(entry, key) then
			return false
		end
	end

	local action = Keymap.Resolve(
		key,
		Cursor.Fine(),
		Cursor.Ctrl(),
		Cursor.Alt(),
		running or runner.Mode ~= nil or modal.Armed ~= nil
	)

	if not action then
		return false
	end

	local turns = action == "Rotate" and Runner.Turns(runner)

	if (STARTS[action] or isPick(action)) and (processed or running) and not turns then
		if string.sub(action, 1, 5) == "Tool:" then
			app.Say(
				`Key {key} is {action}, but it was ignored: Studio took the key = {processed}, a tool action is running = {running}.`
			)
		end

		return false
	end

	if not app.Store.Values.Hotkeys and not ALWAYS_ON[action] and not turns then
		if string.sub(action, 1, 5) == "Tool:" then
			app.Say(`Key {key} is {action}, but Blender hotkeys are switched off on the Hotkeys tab.`)
		end

		return false
	end

	local idle = not running and not runner.Mode and not modal.Armed and not WorkingFolder.IsPicking(app.Folder)

	if idle and (action == "Cancel" or action == "Confirm") then
		if action == "Confirm" and not processed then
			Runner.ResumeLast(runner)
		end

		return false
	end

	if action == "TogglePastel" then
		return true
	end

	if action == "Cancel" then
		app.Sound("Cancel")
	elseif not isPick(action) then
		app.Sound("Hotkey")
	end

	Actions.Perform(app, action)

	return false
end

--[=[
	Connects every input the plugin listens to.

	@param app App
	@param mouse PluginMouse
	@param trove Trove
]=]
function Input.Connect(app: App, mouse: PluginMouse, trove: Trove.Trove)
	--[[ While P is held: whether the wheel turned, which makes letting go of P not toggle themes. ]]
	local themeHold: { Scrolled: boolean }? = nil

	trove:Connect(UserInputService.InputEnded, function(input)
		if input.KeyCode ~= Enum.KeyCode.P or not themeHold then
			return
		end

		local scrolled = themeHold.Scrolled

		themeHold = nil

		if not scrolled then
			app.Sound("Hotkey")
			Actions.Perform(app, "TogglePastel")
		end
	end)

	trove:Connect(UserInputService.InputBegan, function(input, processed)
		if UserInputService:GetFocusedTextBox() or not RunService:IsEdit() then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			if Host.Running(app.Modal) then
				Actions.Cancel(app)
			end

			return
		end

		if
			input.UserInputType ~= Enum.UserInputType.Keyboard
			or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		then
			return
		end

		if keyPressed(app, input.KeyCode.Name, processed) then
			themeHold = { Scrolled = false }
		end
	end)

	trove:Connect(mouse.Button1Down, function()
		if WorkingFolder.Click(app.Folder) then
			return
		end

		if Host.Running(app.Modal) then
			return Host.Confirm(app.Modal)
		end

		Runner.Click(app.Runner)
	end)

	trove:Connect(mouse.Button1Up, function()
		Runner.Release(app.Runner)
	end)

	local cameraBefore: CFrame? = nil
	local focusBefore: CFrame? = nil
	local cameraHeldUntil = 0

	--[[ Ctrl or Alt with the wheel steps tools; the camera is held still meanwhile, so it does not zoom too. ]]
	trove:Connect(RunService.RenderStepped, function()
		local camera = workspace.CurrentCamera

		if not camera then
			return
		end

		if os.clock() < cameraHeldUntil and cameraBefore and focusBefore then
			camera.CFrame = cameraBefore
			camera.Focus = focusBefore
		else
			cameraBefore, focusBefore = camera.CFrame, camera.Focus
		end
	end)

	trove:Connect(UserInputService.InputChanged, function(input, processed)
		if
			input.UserInputType ~= Enum.UserInputType.MouseWheel
			or processed
			or UserInputService:GetFocusedTextBox()
			or not RunService:IsEdit()
		then
			return
		end

		if themeHold and UserInputService:IsKeyDown(Enum.KeyCode.P) and input.Position.Z ~= 0 then
			themeHold.Scrolled = true
			cameraHeldUntil = os.clock() + CAMERA_HOLD
			Actions.StepTheme(app, if input.Position.Z > 0 then -1 else 1)

			return
		end

		local action = Keymap.Scroll(Cursor.Ctrl(), Cursor.Alt(), Cursor.Fine(), input.Position.Z)
		local kind, step = string.match(action or "", "^(%a+):(%-?%d)$")

		if not kind then
			return
		end

		cameraHeldUntil = os.clock() + CAMERA_HOLD
		Actions.Scroll(app, kind == "Tile", tonumber(step) :: number)
	end)

	trove:Connect(ChangeHistoryService.OnUndo, function()
		app.Sound("Undo")
	end)
	trove:Connect(ChangeHistoryService.OnRedo, function()
		app.Sound("Undo")
	end)
end

return Input
