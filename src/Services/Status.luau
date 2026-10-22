--!strict

--[=[
	Where every message to the user goes. `Say` writes the panel's status line and the viewport bar
	together, so they never disagree. The bar also names what is running and lists its keys, which
	it asks the app for through `describe`.

	@class Status
]=]

local AppState = require("../State/AppState")
local Overlay = require("../Core/Overlay")

--[=[
	What the viewport bar shows besides the message.

	@interface Activity
	.Glyph string
	.Name string
	.Hints { { string } } -- { key, what it does } pairs
	@within Status
]=]
export type Activity = {
	Glyph: string,
	Name: string,
	Hints: { { string } },
}

export type Status = {
	_state: AppState.AppState,
	_overlay: Overlay.Overlay,
	_describe: () -> Activity?,
}

local Status = {}

--[=[
	@param state AppState
	@param overlay Overlay
	@param describe () -> Activity? -- what is running now, or nil to hide the bar
	@return Status
]=]
function Status.new(state: AppState.AppState, overlay: Overlay.Overlay, describe: () -> Activity?): Status
	return { _state = state, _overlay = overlay, _describe = describe }
end

--[=[
	Shows a message in the panel and, while something is running, in the viewport bar.

	@param self Status
	@param text string
]=]
function Status.Say(self: Status, text: string)
	self._state.Status(text)

	local activity = self._describe()

	if activity then
		Overlay.SetBar(self._overlay, activity.Glyph, activity.Name, text, activity.Hints)
	else
		Overlay.HideBar(self._overlay)
	end
end

--[=[
	Shows a message and also prints it to the Output window as a warning.

	@param self Status
	@param text string
]=]
function Status.Warn(self: Status, text: string)
	Status.Say(self, text)
	warn("[VluxyBuildingTools] " .. text)
end

return Status
