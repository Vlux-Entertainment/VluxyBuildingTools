--!strict

--[=[
	Everything the user can ask for, by hotkey or from the panel. `Perform` takes a hotkey action
	name from `Pure/Keymap`; the panel calls the named functions directly. Either way the same code
	runs, so a key and its button cannot drift apart.

	@class Actions
]=]

local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")

local Admin = require("../Services/Admin")
local AppState = require("../State/AppState")
local AppTypes = require("./Types")
local AxisLock = require("../Pure/AxisLock")
local Cycle = require("../Pure/Cycle")
local Display = require("../Services/Display")
local Extrude = require("../Modal/Extrude")
local Geometry = require("../Core/Geometry")
local Host = require("../Modal/Host")
local Move = require("../Modal/Move")
local PropData = require("../Pure/PropData")
local Runner = require("../Tools/Runner")
local Settings = require("../Pure/Settings")
local Store = require("../State/Store")
local Tools = require("../Pure/Tools")
local Transform = require("../Core/Transform")
local WorkingFolder = require("../Services/WorkingFolder")

type App = AppTypes.App

local MAX_LENGTH = 2048

local Actions = {}

--[=[
	@param app App
	@return boolean -- true when the place may be edited now: edit mode and a usable working folder; says why when not
]=]
function Actions.CanBuild(app: App): boolean
	if not RunService:IsEdit() then
		app.Say("Stop the playtest before building.")

		return false
	end

	return WorkingFolder.Require(app.Folder)
end

--[=[
	@param app App
	@param run () -> ()
	@return () -> () -- the same action, but it only runs once a working folder is set
]=]
function Actions.Guarded(app: App, run: () -> ()): () -> ()
	return function()
		if WorkingFolder.Require(app.Folder) then
			run()
		end
	end
end

--[=[
	Starts a modal action made by `make`, after ending whatever ran before.

	@param app App
	@param make () -> Modal?
]=]
function Actions.StartModal(app: App, make: () -> any)
	if not RunService:IsEdit() then
		return app.Say("Stop the playtest before building.")
	end

	app.StopAll(true)

	if WorkingFolder.Require(app.Folder) then
		Host.Start(app.Modal, make)
	end
end

--[=[
	@param app App
	@param kind Transform.Kind
	@param duplicate boolean
]=]
function Actions.StartMove(app: App, kind: Transform.Kind, duplicate: boolean)
	Actions.StartModal(app, function()
		return Move.Start(app.Context, kind, duplicate)
	end)
end

--[=[
	@param app App
	@param which Host.Armed -- the action that waits for its axis key
]=]
function Actions.Arm(app: App, which: Host.Armed)
	if not WorkingFolder.Require(app.Folder) then
		return
	end

	app.StopAll(true)
	app.Modal.Armed = which
	app.Say(
		if which == "Flip"
			then "Flip: press X, Y or Z, or Esc to cancel."
			else "Rotate 90°: press X, Y or Z (Alt for -90°), or Esc to cancel."
	)
end

--[=[
	Picks a tool tile, or turns the tool off when its tile is already on.

	@param app App
	@param id string
]=]
function Actions.Select(app: App, id: string)
	Runner.Select(app.Runner, id)
end

--[=[
	@param app App
	@param mode string
]=]
function Actions.SetMode(app: App, mode: string)
	Runner.SetMode(app.Runner, mode)
end

--[=[
	Picks a prop and starts placing it.

	@param app App
	@param id string
]=]
function Actions.PickProp(app: App, id: string)
	app.State.Prop(id)
	Runner.SetMode(app.Runner, "Prop")
end

--[=[
	Tells the brush tool the brush list changed, and redraws the list.

	@param app App
]=]
function Actions.BrushesChanged(app: App)
	Runner.Refresh(app.Runner)
	app.State.BrushRevision(app.State.BrushRevision() + 1)
end

--[=[
	Switches the panel tab. Leaving a tab stops the tool and drops an unconfirmed folder pick.

	@param app App
	@param name string
]=]
function Actions.ShowPage(app: App, name: string)
	if not table.find(AppState.Pages, name) then
		return
	end

	app.StopAll()

	if WorkingFolder.IsPicking(app.Folder) then
		WorkingFolder.CancelPicking(app.Folder)
	end

	app.State.Page(name)
end

--[=[
	@param app App
	@param delta number -- 1 for the next tab, -1 for the one before
]=]
function Actions.CycleTab(app: App, delta: number)
	local pages = AppState.Pages
	local index = table.find(pages, app.State.Page()) or 1

	Actions.ShowPage(app, pages[Cycle.Step(index, delta, #pages)])
end

--[=[
	Steps the Props tab to the next or previous section.

	@param app App
	@param delta number
]=]
function Actions.StepSection(app: App, delta: number)
	local ids: { string } = {}

	for _, section in PropData.Sections do
		table.insert(ids, section.Id)
	end

	app.State.PropSection(Cycle.Next(ids, app.State.PropSection(), delta) or "All")
end

--[=[
	Picks the next or previous prop of the section on show.

	@param app App
	@param delta number
]=]
function Actions.StepProp(app: App, delta: number)
	local ids: { string } = {}

	for _, prop in PropData.Shown(app.State.PropSection()) do
		table.insert(ids, prop.Id)
	end

	local current = if app.Runner.Mode == "Prop" then app.State.Prop() else nil
	local nextId = Cycle.Next(ids, current, delta)

	if nextId then
		Actions.PickProp(app, nextId)
	end
end

--[=[
	The mouse wheel with Ctrl or Alt: steps tools and their options, or the Props tab's sections and
	props while it is on show.

	@param app App
	@param tiles boolean -- Ctrl: step tiles (or sections); Alt: step options (or props)
	@param step number -- 1 or -1
]=]
function Actions.Scroll(app: App, tiles: boolean, step: number)
	if app.State.Page() == "Props" then
		if tiles then
			Actions.StepSection(app, step)
		else
			Actions.StepProp(app, step)
		end
	elseif tiles then
		Runner.StepTile(app.Runner, step)
	else
		Runner.StepOption(app.Runner, step)
	end
end

--[=[
	[ and ]: raises or lowers the height that matters for the active tool by one grid step.

	@param app App
	@param direction number -- 1 or -1
]=]
function Actions.ChangeHeight(app: App, direction: number)
	local mode = app.Runner.Mode

	if not mode then
		return
	end

	local key = if mode == "Arch"
		then "ArchHeight"
		elseif mode == "Stairs" then "StairHeight"
		elseif mode == "Ramp" then "RampHeight"
		else "Height"
	local values = app.Store.Values :: any

	Store.Set(app.Store, key, math.clamp(values[key] + direction * values.Grid, 0.1, MAX_LENGTH))
end

--[=[
	Esc: the innermost thing running steps back.

	@param app App
]=]
function Actions.Cancel(app: App)
	if WorkingFolder.IsPicking(app.Folder) then
		WorkingFolder.CancelPicking(app.Folder)
		app.Say("Folder pick cancelled.")
	elseif app.Modal.Armed then
		app.Modal.Armed = nil
		app.Say("Cancelled.")
	elseif Host.Running(app.Modal) then
		Host.Cancel(app.Modal)
	elseif app.Runner.Mode then
		local message = Runner.Back(app.Runner)

		if message then
			app.Say(message)
		end
	end
end

--[=[
	Enter: confirms the modal action, or lets the tool finish what it is drawing.

	@param app App
]=]
function Actions.Confirm(app: App)
	local runner = app.Runner

	if Host.Running(app.Modal) then
		Host.Confirm(app.Modal)
	elseif runner.Mode and not Runner.Confirm(runner) then
		Runner.Reset(runner)
		app.Say(Tools.Instruction(runner.Mode))
	end
end

--[=[
	X, Y or Z, with Alt for a plane: picks the axis of an armed flip or turn, else locks the axis of
	the modal action or the tool.

	@param app App
	@param axis AxisLock.Axis
	@param plane boolean
]=]
function Actions.Axis(app: App, axis: AxisLock.Axis, plane: boolean)
	local armed = app.Modal.Armed
	local modal = app.Modal.Active

	if armed then
		app.Modal.Armed = nil

		if WorkingFolder.Require(app.Folder) then
			if armed == "Flip" then
				app.Arrange.Flip(axis)
			else
				app.Arrange.RotateBy(axis, if plane then -90 else 90)
			end
		end
	elseif modal then
		if modal.Lock then
			modal.Lock(axis, plane)
		end
	elseif not Runner.Lock(app.Runner, axis, plane) then
		app.Say("This tool has no axis lock.")
	end
end

--[=[
	H: hides the selected parts for everyone. Only the admin may.

	@param app App
]=]
function Actions.Hide(app: App)
	if not Admin.Allows(app.Admin) then
		return
	end

	local parts = Geometry.PartsOf(Geometry.SelectedRoots(true))

	if #parts == 0 then
		return app.Say("Select something to hide first.")
	end

	if Display.Hide(app.Display, parts) then
		Selection:Set({})
		app.Say(`Hid {#parts} part(s) for everyone; Alt+H brings them back.`)
	end
end

--[=[
	Alt+H: shows every hidden part again, for everyone. Only the admin may.

	@param app App
]=]
function Actions.UnhideAll(app: App)
	if not Admin.Allows(app.Admin) then
		return
	end

	local count = Display.UnhideAll(app.Display)

	app.Say(if count > 0 then `Unhid {count} part(s).` else "Nothing was hidden.")
end

--[=[
	I: shows hidden parts as ghosts, or hides them fully again.

	@param app App
]=]
function Actions.ToggleHiddenView(app: App)
	Display.ToggleHiddenView(app.Display)
	app.Say(if app.Display.Hidden.View then "Hidden parts are shown as ghosts." else "Hidden parts are fully hidden.")
end

--[=[
	P or the toolbar: themes on or off. Only the admin may.

	@param app App
]=]
function Actions.TogglePastel(app: App)
	if Admin.Allows(app.Admin) then
		Display.SetPastel(app.Display, not app.Display.Colors.On)
	end
end

--[=[
	L or the toolbar: the surface grid on or off. Only the admin may.

	@param app App
]=]
function Actions.ToggleGrid(app: App)
	if Admin.Allows(app.Admin) then
		Display.SetGrid(app.Display, not app.Display.Grid.On)
	end
end

--[=[
	Moves to the next or previous color theme, wrapping around, and switches themes on if they are
	off. Only the admin may.

	@param app App
	@param step number -- 1 for the next theme, -1 for the previous
]=]
function Actions.StepTheme(app: App, step: number)
	if not Admin.Allows(app.Admin) then
		return
	end

	local themes = Settings.Themes
	local at = table.find(themes, Display.Theme(app.Display)) or 1
	local name = themes[(at - 1 + step) % #themes + 1]

	Store.Set(app.Store, "ColorTheme", name)

	if not app.Display.Colors.On then
		Display.SetPastel(app.Display, true)
	end

	app.Say(`Theme: {name}.`)
end

--[=[
	@param app App
]=]
function Actions.ToggleCameraLight(app: App)
	local on = not app.Store.Values.CameraLight

	Store.Set(app.Store, "CameraLight", on)
	app.Say(if on then "Camera light on." else "Camera light off.")
end

--[=[
	Hands admin of the working folder to another user. Only the admin may.

	@param app App
	@param userId number
]=]
function Actions.GiveAdmin(app: App, userId: number)
	Admin.Give(app.Admin, userId)
end

--[=[
	Asks the folder's admin to hand admin over.

	@param app App
]=]
function Actions.RequestAdmin(app: App)
	Admin.Request(app.Admin)
end

--[=[
	Turns down the open admin request.

	@param app App
]=]
function Actions.IgnoreRequest(app: App)
	Admin.Ignore(app.Admin)
	app.Say("Request ignored.")
end

local SIMPLE: { [string]: (app: App) -> () } = {
	Cancel = Actions.Cancel,
	Confirm = Actions.Confirm,
	Extrude = function(app)
		Actions.StartModal(app, function()
			return Extrude.Start(app.Context)
		end)
	end,
	Grab = function(app)
		Actions.StartMove(app, "Grab", false)
	end,
	Scale = function(app)
		Actions.StartMove(app, "Scale", false)
	end,
	Duplicate = function(app)
		Actions.StartMove(app, "Grab", true)
	end,
	Rotate = function(app)
		if Runner.Turns(app.Runner) then
			Store.Set(app.Store, "Yaw", (app.Store.Values.Yaw + 90) % 360)
		else
			Actions.StartMove(app, "Rotate", false)
		end
	end,
	Hide = Actions.Hide,
	Unhide = Actions.UnhideAll,
	ToggleHiddenView = Actions.ToggleHiddenView,
	FlipArm = function(app)
		Actions.Arm(app, "Flip")
	end,
	Rotate90Arm = function(app)
		Actions.Arm(app, "Rotate90")
	end,
	NextTab = function(app)
		Actions.CycleTab(app, 1)
	end,
	PrevTab = function(app)
		Actions.CycleTab(app, -1)
	end,
	ShowHotkeys = function(app)
		Actions.ShowPage(app, "Hotkeys")
	end,
	TogglePastel = Actions.TogglePastel,
	ToggleGrid = Actions.ToggleGrid,
	ToggleCameraLight = Actions.ToggleCameraLight,
	TogglePanel = function(app)
		app.Widget.Enabled = not app.Widget.Enabled
	end,
	HeightUp = function(app)
		Actions.ChangeHeight(app, 1)
	end,
	HeightDown = function(app)
		Actions.ChangeHeight(app, -1)
	end,
}

--[=[
	Carries out a hotkey action from `Keymap.Resolve`.

	@param app App
	@param action string
]=]
function Actions.Perform(app: App, action: string)
	local simple = SIMPLE[action]

	if simple then
		return simple(app)
	end

	local tool = string.match(action, "^Tool:(.+)$")

	if tool then
		return Actions.Select(app, tool)
	end

	local option = string.match(action, "^Option:(%d+)$")

	if option then
		return Runner.Option(app.Runner, tonumber(option) :: number)
	end

	local kind, axis = string.match(action, "^(%a+):([XYZ])$")

	if kind == "Lock" or kind == "Plane" then
		Actions.Axis(app, axis :: AxisLock.Axis, kind == "Plane")
	end
end

return Actions
