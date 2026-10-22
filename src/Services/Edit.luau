--!strict

--[=[
	Wraps every change the plugin makes to the place in one ChangeHistory recording, so it is one
	undo step and is cancelled cleanly when it errors. Parts the change creates are handed to the
	pastel colors and the surface grid, so new builds match the rest of the folder.

	@class Edit
]=]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

local Profile = require("../Core/Profile")

export type Deps = {
	Say: (text: string) -> (),
	Sound: (name: string) -> (),
	--[=[ Called once after every change with the Parts it added, still in the same undo step. ]=]
	Sweep: (parts: { BasePart }) -> (),
}

--[=[
	@type Edit (action: string, change: () -> ()) -> boolean
	@within Edit

	Runs `change` as one undo step named `action`. Returns true when it ran without error and was
	committed; an error cancels the recording and is shown to the user.
]=]
export type Edit = (action: string, change: () -> ()) -> boolean

local Edit = {}

--[=[
	@param deps Deps
	@return Edit
]=]
function Edit.new(deps: Deps): Edit
	return function(action: string, change: () -> ()): boolean
		if not RunService:IsEdit() then
			deps.Say("Stop the playtest before building.")

			return false
		end

		local id = ChangeHistoryService:TryBeginRecording("Vlux_" .. action, action)

		if not id then
			deps.Say("Cannot begin an edit right now. Finish the other tool action first.")

			return false
		end

		local added: { BasePart } = {}
		local watch = workspace.DescendantAdded:Connect(function(object)
			if object:IsA("BasePart") then
				table.insert(added, object)
			end
		end)
		local ok, err = pcall(Profile.Run :: any, "Edit", change)

		watch:Disconnect()

		Profile.Run("Sweep", deps.Sweep, added)
		Profile.Run("Commit", function()
			ChangeHistoryService:FinishRecording(
				id,
				if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
			)
		end)

		if ok then
			deps.Sound(if action == "Place prop" then "Prop" else "Build")
		else
			deps.Sound("Warning")
			deps.Say("Action cancelled: " .. tostring(err))
			warn("[VluxyBuildingTools] " .. tostring(err))
		end

		return ok
	end
end

return Edit
