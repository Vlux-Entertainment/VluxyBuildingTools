--!strict

--[=[
	The app-wide state the panel shows, as vide sources. The services and tools that own each value
	write it here; the panel only reads. Call a source with no argument to read it and with one to
	write it.

	@class AppState
]=]

local vide = require("../Packages/vide")

type Source<T> = vide.Source<T>

export type AppState = {
	--[=[ The active tool mode, such as `Room`, or nil when no tool is on. ]=]
	Mode: Source<string?>,
	--[=[ The confirmed working folder. ]=]
	Folder: Source<Instance?>,
	--[=[ A folder that was picked and waits for Yes. ]=]
	Pending: Source<Instance?>,
	--[=[ True while the user is picking a working folder. ]=]
	Picking: Source<boolean>,
	--[=[ The names of the shared settings that differ from the folder's, while the user decides whose to keep. ]=]
	Conflict: Source<string?>,
	--[=[ The prop the Prop tool places. ]=]
	Prop: Source<string?>,
	--[=[ The line of help under the tabs. ]=]
	Status: Source<string>,
	--[=[ The panel tab on show. ]=]
	Page: Source<string>,
	--[=[ The section of the Props tab on show: `All` or a category id. ]=]
	PropSection: Source<string>,
	PastelOn: Source<boolean>,
	GridOn: Source<boolean>,
	HiddenView: Source<boolean>,
	HiddenCount: Source<number>,
	--[=[ Goes up every time the brush list changes, so the panel redraws it. ]=]
	BrushRevision: Source<number>,
}

local AppState = {}

--[=[
	The panel tabs, in order.

	@prop Pages { string }
	@within AppState
]=]
AppState.Pages = { "Build", "Props", "Arrange", "Display", "Hotkeys", "Settings" }

--[=[
	The tabs that only open once a working folder is set.

	@prop Locked { [string]: boolean }
	@within AppState
]=]
AppState.Locked = { Build = true, Arrange = true, Props = true, Display = true } :: { [string]: boolean }

--[=[
	@return AppState -- every value at its starting state
]=]
function AppState.new(): AppState
	return {
		Mode = vide.source(nil :: string?),
		Folder = vide.source(nil :: Instance?),
		Pending = vide.source(nil :: Instance?),
		Picking = vide.source(false),
		Conflict = vide.source(nil :: string?),
		Prop = vide.source(nil :: string?),
		Status = vide.source("Pick a tool, or press a number key. Everything is in studs."),
		Page = vide.source("Build"),
		PropSection = vide.source("All"),
		PastelOn = vide.source(false),
		GridOn = vide.source(false),
		HiddenView = vide.source(false),
		HiddenCount = vide.source(0),
		BrushRevision = vide.source(0),
	}
end

return AppState
