--!strict

--[=[
	The pieces the app is made of, as one record handed to `Actions`, `Input` and the panel. `App`
	builds it; nothing else creates services.

	@class AppTypes
]=]

local AppState = require("../State/AppState")
local Arrange = require("../Core/Arrange")
local CameraLight = require("../Services/CameraLight")
local Cursor = require("../Services/Cursor")
local Display = require("../Services/Display")
local Host = require("../Modal/Host")
local Overlay = require("../Core/Overlay")
local Presence = require("../Services/Presence")
local Runner = require("../Tools/Runner")
local Sounds = require("../Core/Sounds")
local Status = require("../Services/Status")
local Store = require("../State/Store")
local ToolTypes = require("../Tools/Types")
local WorkingFolder = require("../Services/WorkingFolder")

--[=[
	@interface App
	@within AppTypes
	.Plugin Plugin
	.Widget DockWidgetPluginGui
	.Store Store -- the settings
	.State AppState -- what the panel shows
	.Overlay Overlay -- what is drawn in the viewport
	.Cursor Cursor
	.Status Status
	.Context ToolContext -- what tools and modal actions work with
	.Display Display -- pastel colors, surface grid, hidden parts
	.Folder WorkingFolder
	.Runner Runner -- the active tool
	.Modal ModalHost -- the active modal action
	.Arrange Arrange.Actions -- the Arrange tab's actions
	.Sounds Sounds
	.CameraLight CameraLight
	.Presence Presence
	.Say (text: string) -> ()
	.Sound (name: string) -> ()
	.StopAll (keepActive: boolean?) -> () -- ends any tool or modal action; without keepActive the mouse is given back too
]=]
export type App = {
	Plugin: Plugin,
	Widget: DockWidgetPluginGui,
	Store: Store.Store,
	State: AppState.AppState,
	Overlay: Overlay.Overlay,
	Cursor: Cursor.Cursor,
	Status: Status.Status,
	Context: ToolTypes.Context,
	Display: Display.Display,
	Folder: WorkingFolder.WorkingFolder,
	Runner: Runner.Runner,
	Modal: Host.Host,
	Arrange: Arrange.Actions,
	Sounds: Sounds.Sounds,
	CameraLight: CameraLight.CameraLight,
	Presence: Presence.Presence,
	Say: (text: string) -> (),
	Sound: (name: string) -> (),
	StopAll: (keepActive: boolean?) -> (),
}

return nil
