--!strict

--[=[
	Runs the one modal action that may be active (see `Modal/Types`), and the armed one-key
	actions: after Ctrl+M (flip) or O (rotate 90), the next X, Y or Z says which axis.

	@class Host
]=]

local ModalTypes = require("./Types")
local NumericInput = require("../Pure/NumericInput")
local Status = require("../Services/Status")

type Modal = ModalTypes.Modal

export type Deps = {
	--[=[ Called after an action started: takes the mouse. ]=]
	Started: () -> (),
	--[=[ Called after an action ended: gives the mouse back. ]=]
	Ended: () -> (),
	Say: (text: string) -> (),
}

--[=[
	A one-key action waiting for its axis.

	@type Armed "Flip" | "Rotate90"
	@within Host
]=]
export type Armed = "Flip" | "Rotate90"

export type Host = {
	Active: Modal?,
	Armed: Armed?,
	_deps: Deps,
}

local Host = {}

--[=[
	@param deps Deps
	@return Host
]=]
function Host.new(deps: Deps): Host
	return { Active = nil, Armed = nil, _deps = deps }
end

--[=[
	@param self Host
	@return boolean -- true while a modal action runs
]=]
function Host.Running(self: Host): boolean
	return self.Active ~= nil
end

--[=[
	Starts an action made by `make`, which returns nil when it cannot start. An error while making it
	is reported instead of thrown.

	@param self Host
	@param make () -> Modal?
]=]
function Host.Start(self: Host, make: () -> Modal?)
	local ok, modal = pcall(make)

	if not ok then
		self._deps.Say("Could not start: " .. tostring(modal))
		warn("[VluxyBuildingTools] " .. tostring(modal))
	elseif modal then
		self.Active = modal
		self._deps.Started()
	end
end

--[[
	@param self Host

	Forgets the action and gives the mouse back.
]]
local function ended(self: Host)
	self.Active = nil
	self._deps.Ended()
end

--[=[
	Click or Enter: finishes the action if it is ready.

	@param self Host
]=]
function Host.Confirm(self: Host)
	local modal = self.Active

	if modal and modal.Confirm() then
		ended(self)
	end
end

--[=[
	Esc or right click: undoes the action.

	@param self Host
]=]
function Host.Cancel(self: Host)
	local modal = self.Active

	if modal then
		self.Active = nil
		modal.Cancel()
		self._deps.Ended()
	end
end

--[=[
	Undoes the action but keeps the mouse: for when something else is about to take over. An armed
	flip or turn stays armed.

	@param self Host
]=]
function Host.Halt(self: Host)
	local modal = self.Active

	self.Active = nil

	if modal then
		modal.Cancel()
	end
end

--[=[
	Every frame. An error cancels the action and says why.

	@param self Host
]=]
function Host.Step(self: Host)
	local modal = self.Active

	if not modal then
		return
	end

	local ok, running = pcall(modal.Step)

	if not ok then
		Host.Cancel(self)
		self._deps.Say("Stopped: " .. tostring(running))
		warn("[VluxyBuildingTools] " .. tostring(running))
	elseif not running and self.Active == modal then
		ended(self)
	end
end

--[=[
	@param self Host
	@return NumericInput? -- where typed digits go while an action runs
]=]
function Host.Typing(self: Host): NumericInput.NumericInput?
	return if self.Active then self.Active.Numeric else nil
end

--[=[
	@param self Host
	@return Status.Activity? -- what the viewport bar shows for the running action
]=]
function Host.Describe(self: Host): Status.Activity?
	return if self.Active then self.Active.Activity else nil
end

return Host
