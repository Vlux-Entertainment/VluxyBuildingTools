--!strict

--[=[
	The contract every tool follows. A tool is a table of functions plus a state table it makes in
	`Begin`; the runner (`Tools/Runner`) is the only caller. All of a tool's state lives in that
	table, so leaving or resetting a tool is just dropping the table, and a bug in one tool cannot
	leak into another.

	A frame of a tool's life:

	1. `Preview` runs about twenty times a second. It reads the mouse through `ctx.Cursor` and
	   returns what to draw. It must not change the place.
	2. `Click` runs on a left click, right after a fresh `Preview`, which it receives. Changes to
	   the place go through `ctx.Edit`, so each build is one undo step.
	3. `Back` runs on Esc. It undoes one step and says what it did, or returns nil to leave the tool.

	@class ToolTypes
]=]

local AppState = require("../State/AppState")
local AxisLock = require("../Pure/AxisLock")
local Cursor = require("../Services/Cursor")
local Edit = require("../Services/Edit")
local Geometry = require("../Core/Geometry")
local NumericInput = require("../Pure/NumericInput")
local Overlay = require("../Core/Overlay")
local Settings = require("../Pure/Settings")
local Store = require("../State/Store")

--[=[
	What a tool gets to work with. Every field is shared by all tools; a tool keeps its own data in
	its state table, never here.

	@interface Context
	@within ToolTypes
]=]
export type Context = {
	Plugin: Plugin,
	--[=[ The live settings; read freely, write only through `Store`. ]=]
	Settings: Settings.Settings,
	Store: Store.Store,
	State: AppState.AppState,
	Cursor: Cursor.Cursor,
	Overlay: Overlay.Overlay,
	Edit: Edit.Edit,
	Say: (text: string) -> (),
	Sound: (name: string) -> (),
}

--[=[
	What one preview draws. Ghost parts, an optional red cut volume, small markers for holes or
	joins, and a message for the status line.

	@interface Preview
	@within ToolTypes
]=]
export type Preview = {
	Specs: { Geometry.Spec },
	Valid: boolean,
	Message: string?,
	Cut: { cf: CFrame, size: Vector3 }?,
	Holes: { { cf: CFrame, size: Vector3 } }?,
}

--[=[
	One tool, or a family of tools sharing code (each mode is its own `Tool` value).

	@interface Tool
	@within ToolTypes
	.Id string -- the mode, such as `Room`
	.Draws boolean? -- a point-to-point tool: the bar shows Alt and axis-lock hints
	.Locks boolean? -- takes X / Y / Z axis locks without drawing: the bar shows only the axis-lock hint
	.Turns boolean? -- R turns what it places by 90 degrees instead of rotating the selection
	.Begin (ctx) -> any -- makes the tool's state when it is picked; returns nil to refuse, after saying why
	.Preview (ctx, state) -> Preview? -- what to draw now; nil draws nothing
	.Click (ctx, state, preview) -> ()
	.Release ((ctx, state) -> ())? -- left button up
	.Confirm ((ctx, state) -> boolean)? -- Enter; true when it did something
	.Back ((ctx, state) -> string?)? -- Esc; a message when it undid a step, nil to leave the tool
	.Lock ((ctx, state, axis, plane) -> ())? -- X / Y / Z, with Alt for a plane
	.Typing ((state) -> NumericInput?)? -- where typed digits go right now, if anywhere
	.Busy ((state) -> boolean)? -- true while the tool drives the overlay itself, so previews pause
	.Refresh ((ctx, state) -> ())? -- something the tool reads from outside changed, such as the brush list
	.Finish ((ctx, state) -> ())? -- the tool is being left; undo anything it shows
]=]
export type Tool = {
	Id: string,
	Draws: boolean?,
	Locks: boolean?,
	Turns: boolean?,
	Begin: (ctx: Context) -> any,
	Preview: (ctx: Context, state: any) -> Preview?,
	Click: (ctx: Context, state: any, preview: Preview?) -> (),
	Release: ((ctx: Context, state: any) -> ())?,
	Confirm: ((ctx: Context, state: any) -> boolean)?,
	Back: ((ctx: Context, state: any) -> string?)?,
	Lock: ((ctx: Context, state: any, axis: AxisLock.Axis, plane: boolean) -> ())?,
	Typing: ((state: any) -> NumericInput.NumericInput?)?,
	Busy: ((state: any) -> boolean)?,
	Refresh: ((ctx: Context, state: any) -> ())?,
	Finish: ((ctx: Context, state: any) -> ())?,
}

return nil
