--!strict

--[=[
	Runs the active tool. It is the only caller of the tool functions in `Tools/Types`: it starts
	and stops tools, draws each preview, and hands the tool its clicks and keys.

	It also remembers, for every tile with several modes, which mode was used last, so picking the
	tile again starts that one, and which tool was used last, so Enter can bring it back.

	A tool error never escapes: a failing preview stops the tool and says why.

	@class Runner
]=]

local RunService = game:GetService("RunService")

local AxisLock = require("../Pure/AxisLock")
local NumericInput = require("../Pure/NumericInput")
local Overlay = require("../Core/Overlay")
local Registry = require("./Registry")
local Status = require("../Services/Status")
local Tools = require("../Pure/Tools")
local Types = require("./Types")

export type Deps = {
	Context: Types.Context,
	--[=[ True when a tool may start: a usable working folder and edit mode. Says why when not. ]=]
	CanStart: () -> boolean,
	--[=[ Called before a tool starts: ends any modal action. ]=]
	Starting: () -> (),
	--[=[ Called once a tool has started: takes the mouse. ]=]
	Started: () -> (),
	--[=[ Called when the runner turned the tool off by itself, to give the mouse back. ]=]
	Stopped: () -> (),
}

export type Runner = {
	--[=[ The active mode, or nil. Read it; change it only with the functions here. ]=]
	Mode: string?,
	_tool: Types.Tool?,
	_state: any,
	_deps: Deps,
	_lastVariant: { [string]: string },
	_lastMode: string?,
	_scrollTile: number?,
}

local DRAW_HINTS = { { "Alt", "Straight line" }, { "X Y Z", "Axis lock" }, { "Esc", "Exit tool" } }
local LOCK_HINTS = { { "X Y Z", "Axis lock" }, { "Esc", "Exit tool" } }
local PLAIN_HINTS = { { "Esc", "Exit tool" } }

local Runner = {}

--[=[
	@param deps Deps
	@return Runner
]=]
function Runner.new(deps: Deps): Runner
	return {
		Mode = nil,
		_tool = nil,
		_state = nil,
		_deps = deps,
		_lastVariant = {},
		_lastMode = nil,
		_scrollTile = nil,
	}
end

--[[
	@param self Runner

	Clears everything a tool may have drawn.
]]
local function clearOverlay(self: Runner)
	local overlay = self._deps.Context.Overlay

	Overlay.ClearGhosts(overlay)
	Overlay.ClearPlaneGrid(overlay)
	Overlay.ClearMeasurement(overlay)
	Overlay.HideReadout(overlay)
	Overlay.DrawCut(overlay, nil)
	Overlay.DrawSnap(overlay, nil)
	Overlay.DrawHoles(overlay, {})
end

--[=[
	Leaves the active tool, if any. The mouse is not given back; see `Deps.Stopped`.

	@param self Runner
]=]
function Runner.Stop(self: Runner)
	local tool, state = self._tool, self._state

	self._tool, self._state, self.Mode = nil, nil, nil
	self._deps.Context.State.Mode(nil)

	if tool and tool.Finish then
		tool.Finish(self._deps.Context, state)
	end

	clearOverlay(self)
end

--[[
	@param self Runner
	@param name string
	@return boolean -- whether the tool started

	Starts a tool from scratch.
]]
local function start(self: Runner, name: string): boolean
	local deps = self._deps
	local ctx = deps.Context
	local tool = Registry[name]
	local had = self._tool ~= nil

	deps.Starting()
	Runner.Stop(self)

	local state = if tool and deps.CanStart() then tool.Begin(ctx) else nil

	if state == nil then
		if had then
			deps.Stopped()
		end

		return false
	end

	self._tool, self._state, self.Mode = tool, state, name
	ctx.State.Mode(name)
	deps.Started()
	ctx.Sound("Tool")
	ctx.Say(Tools.Instruction(name))

	return true
end

--[=[
	Switches to a mode and remembers it as the one its tile starts with.

	@param self Runner
	@param name string -- a mode such as `Room`
]=]
function Runner.SetMode(self: Runner, name: string)
	if self.Mode == name or not start(self, name) then
		return
	end

	local tile = Tools.TileOf(name)

	if tile then
		self._lastVariant[tile.Id] = name
	end

	self._lastMode = name
end

--[=[
	Picks a tile: starts the mode it was last used with, or turns the tool off when the tile is
	already active. An id that is not a tile is taken as a mode.

	@param self Runner
	@param id string
]=]
function Runner.Select(self: Runner, id: string)
	local tile = Tools.FindTile(id)

	if not tile then
		return Runner.SetMode(self, id)
	end

	if self.Mode and table.find(tile.Modes, self.Mode) then
		Runner.Stop(self)
		self._deps.Stopped()
		self._deps.Context.Sound("ToolOff")

		return self._deps.Context.Say("Tool off.")
	end

	Runner.SetMode(self, self._lastVariant[tile.Id] or tile.Modes[1])
end

--[=[
	Alt plus a number: picks that option of the active tile.

	@param self Runner
	@param index number -- 1 for the first option
]=]
function Runner.Option(self: Runner, index: number)
	local ctx = self._deps.Context
	local tile = if self.Mode then Tools.TileOf(self.Mode) else nil

	if not tile then
		return ctx.Say("Pick a tool first, then Alt plus a number picks an option inside it.")
	end

	local target = tile.Modes[index]

	if #tile.Modes < 2 then
		ctx.Say(`{tile.Label} has no options.`)
	elseif target then
		Runner.SetMode(self, target)
	else
		ctx.Say(`{tile.Label} only has {#tile.Modes} options.`)
	end
end

--[=[
	Steps to the next or previous tile, wrapping around.

	@param self Runner
	@param step number -- 1 or -1
]=]
function Runner.StepTile(self: Runner, step: number)
	local grid = Tools.Grid
	local held = if self.Mode then Tools.TileOf(self.Mode) else nil
	local index = if held
		then table.find(grid, held) :: number
		elseif self._scrollTile then self._scrollTile
		else if step > 0 then 0 else #grid + 1

	index = (index - 1 + step) % #grid + 1
	self._scrollTile = index
	Runner.Select(self, grid[index].Id)
end

--[=[
	Steps to the next or previous option of the active tile, wrapping around.

	@param self Runner
	@param step number -- 1 or -1
]=]
function Runner.StepOption(self: Runner, step: number)
	local held = if self.Mode then Tools.TileOf(self.Mode) else nil

	if not held or #held.Modes < 2 then
		return self._deps.Context.Say("Pick a tool with options first.")
	end

	local at = table.find(held.Modes, self.Mode :: string) or 1

	Runner.SetMode(self, held.Modes[(at - 1 + step) % #held.Modes + 1])
end

--[=[
	Brings back the last tool used, for Enter with no tool on.

	@param self Runner
	@return boolean -- whether there was one
]=]
function Runner.ResumeLast(self: Runner): boolean
	local last = self._lastMode

	if not last then
		return false
	end

	Runner.SetMode(self, last)

	return true
end

--[=[
	Starts the active tool afresh, keeping it on, as Enter does. A tool that cannot begin again is
	turned off.

	@param self Runner
]=]
function Runner.Reset(self: Runner)
	local tool, ctx = self._tool, self._deps.Context

	if not tool then
		return
	end

	if tool.Finish then
		tool.Finish(ctx, self._state)
	end

	clearOverlay(self)

	local state = tool.Begin(ctx)

	if state == nil then
		self._tool, self._state, self.Mode = nil, nil, nil
		ctx.State.Mode(nil)
		self._deps.Stopped()

		return
	end

	self._state = state
end

--[[
	@param self Runner
	@return Preview? -- the active tool's preview, drawn

	Asks the tool what to show for the mouse now and draws it.
]]
local function preview(self: Runner): Types.Preview?
	local tool, ctx = self._tool, self._deps.Context
	local overlay = ctx.Overlay

	if not tool then
		return nil
	end

	ctx.Cursor.Mark = nil
	Overlay.ClearPlaneGrid(overlay)
	Overlay.ResetWireColor(overlay)

	local shown = tool.Preview(ctx, self._state)

	if not shown then
		Overlay.ClearGhosts(overlay)

		return nil
	end

	Overlay.DrawGhosts(overlay, shown.Specs)
	Overlay.DrawCut(overlay, shown.Cut)
	Overlay.DrawSnap(overlay, ctx.Cursor.Mark)
	Overlay.DrawHoles(overlay, shown.Holes or {})

	if shown.Message then
		ctx.Say(shown.Message)
	end

	return shown
end

--[=[
	Runs about twenty times a second: redraws the preview. A tool error stops the tool.

	@param self Runner
]=]
function Runner.Step(self: Runner)
	local tool = self._tool

	if not tool then
		return
	end

	if not RunService:IsEdit() then
		Overlay.ClearGhosts(self._deps.Context.Overlay)

		return
	end

	if tool.Busy and tool.Busy(self._state) then
		return
	end

	local ok, err = pcall(preview, self)

	if not ok then
		Runner.Stop(self)
		self._deps.Stopped()
		self._deps.Context.Say("Preview stopped: " .. tostring(err))
		warn("[VluxyBuildingTools] " .. tostring(err))
	end
end

--[=[
	A left click in the viewport: refreshes the preview so the click acts on what is under the
	mouse now, then hands it to the tool.

	@param self Runner
]=]
function Runner.Click(self: Runner)
	local tool, ctx = self._tool, self._deps.Context

	if not tool or not RunService:IsEdit() or (tool.Busy and tool.Busy(self._state)) then
		return
	end

	local ok, shown = pcall(preview, self)

	if not ok then
		return ctx.Say(tostring(shown))
	end

	local clicked, err = pcall(function()
		tool.Click(ctx, self._state, shown)
	end)

	if not clicked then
		Runner.Stop(self)
		self._deps.Stopped()
		ctx.Say("Tool stopped: " .. tostring(err))
		warn("[VluxyBuildingTools] " .. tostring(err))
	end
end

--[=[
	The left button came up.

	@param self Runner
]=]
function Runner.Release(self: Runner)
	local tool = self._tool

	if tool and tool.Release then
		tool.Release(self._deps.Context, self._state)
	end
end

--[=[
	Enter.

	@param self Runner
	@return boolean -- whether the tool used it
]=]
function Runner.Confirm(self: Runner): boolean
	local tool = self._tool

	return tool ~= nil and tool.Confirm ~= nil and tool.Confirm(self._deps.Context, self._state)
end

--[=[
	Esc: the tool undoes one step, or, when it has none, the tool is left.

	@param self Runner
	@return string? -- what happened, or nil when no tool was on
]=]
function Runner.Back(self: Runner): string?
	local tool = self._tool

	if not tool then
		return nil
	end

	local message = if tool.Back then tool.Back(self._deps.Context, self._state) else nil

	if message then
		return message
	end

	Runner.Stop(self)
	self._deps.Stopped()

	return "Tool stopped; Enter brings it back."
end

--[=[
	X, Y or Z, with Alt for a plane.

	@param self Runner
	@param axis AxisLock.Axis
	@param plane boolean
	@return boolean -- whether the active tool takes axis locks
]=]
function Runner.Lock(self: Runner, axis: AxisLock.Axis, plane: boolean): boolean
	local tool = self._tool

	if not tool or not tool.Lock then
		return false
	end

	tool.Lock(self._deps.Context, self._state, axis, plane)

	return true
end

--[=[
	@param self Runner
	@return NumericInput? -- where typed digits go now, if the active tool takes them
]=]
function Runner.Typing(self: Runner): NumericInput.NumericInput?
	local tool = self._tool

	return if tool and tool.Typing then tool.Typing(self._state) else nil
end

--[=[
	Tells the active tool that something it reads from outside changed.

	@param self Runner
]=]
function Runner.Refresh(self: Runner)
	local tool = self._tool

	if tool and tool.Refresh then
		tool.Refresh(self._deps.Context, self._state)
	end
end

--[=[
	@param self Runner
	@return boolean -- true when R turns what the active tool places
]=]
function Runner.Turns(self: Runner): boolean
	local tool = self._tool

	return tool ~= nil and tool.Turns == true
end

--[=[
	@param self Runner
	@return Status.Activity? -- what the viewport bar shows for the active tool
]=]
function Runner.Describe(self: Runner): Status.Activity?
	local mode, tool = self.Mode, self._tool

	if not mode or not tool then
		return nil
	end

	local info = Tools.Find(mode)

	return {
		Glyph = if info then info.Glyph else "◆",
		Name = if info then info.Label else "",
		Hints = if tool.Draws then DRAW_HINTS elseif tool.Locks then LOCK_HINTS else PLAIN_HINTS,
	}
end

return Runner
