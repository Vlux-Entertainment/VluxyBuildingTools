--!strict

--[=[
	Names spans of plugin work in the MicroProfiler (Ctrl+F6), under labels that start with
	`VluxyBT/`. A label costs next to nothing while the profiler is not recording, so they stay in
	the code for good. `Run` always closes the label, even when the work errors.

	@class Profile
]=]

local PREFIX = "VluxyBT/"

local Profile = {}

--[[
	Closes the label, then passes on what the work returned, or raises its error again.
]]
local function finish(ok: boolean, ...: any): ...any
	debug.profileend()

	if not ok then
		error((...), 0)
	end

	return ...
end

--[=[
	Runs `work` with its arguments inside the label `VluxyBT/<label>`.

	@param label string
	@param work function
	@return ... -- what the work returned; an error in the work is raised again after the label closes
]=]
function Profile.Run(label: string, work: (...any) -> ...any, ...: any): ...any
	debug.profilebegin(PREFIX .. label)

	return finish(pcall(work, ...))
end

return Profile
