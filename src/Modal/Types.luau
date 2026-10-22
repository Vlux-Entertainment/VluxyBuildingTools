--!strict

--[=[
	The contract for modal actions: Blender-style actions that take over the mouse until confirmed
	or cancelled, such as extrude (T) and grab, rotate and scale (G, R, C). At most one runs at a
	time, and while one runs no tool is on. `Modal/Host` runs them.

	@class ModalTypes
]=]

local AxisLock = require("../Pure/AxisLock")
local NumericInput = require("../Pure/NumericInput")
local Status = require("../Services/Status")

--[=[
	@interface Modal
	@within ModalTypes
	.Activity Status.Activity -- the viewport bar's name, glyph and keys
	.Numeric NumericInput -- where typed digits go
	.Step () -> boolean -- every frame: follow the mouse; false when the action had to cancel itself
	.Confirm () -> boolean -- click or Enter; true when the action finished, false when it is not ready
	.Cancel () -> () -- Esc or right click: undo the action
	.Lock ((axis, plane) -> ())? -- X / Y / Z, with Alt for a plane
	.Key ((name: string) -> boolean)? -- any other key; true when used
]=]
export type Modal = {
	Activity: Status.Activity,
	Numeric: NumericInput.NumericInput,
	Step: () -> boolean,
	Confirm: () -> boolean,
	Cancel: () -> (),
	Lock: ((axis: AxisLock.Axis, plane: boolean) -> ())?,
	Key: ((name: string) -> boolean)?,
}

return nil
