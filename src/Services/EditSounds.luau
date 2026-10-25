--!strict

--[=[
	Sounds for building with Studio's own tools: dragging, and the move, rotate and scale handles.
	This watches the selected parts and plays one sound when Studio finishes its undo recording for
	the change, which is when the mouse lets go. If Studio does not record the change, the sound plays
	once the parts stop changing instead. It keeps quiet while the plugin moves things itself and right
	after an undo or redo, which have their own sound.

	@class EditSounds
]=]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local Trove = require("../Packages/Trove")

export type Deps = {
	--[=[ Plays a sound by its `SoundIds` name. ]=]
	Sound: (name: string) -> (),
	--[=[ True while the plugin itself moves or builds, so its own changes make no extra sound. ]=]
	Busy: () -> boolean,
	--[=[ Called when one of Studio's drags has finished, after its sound. ]=]
	Dropped: (() -> ())?,
	--[=[ Called while Studio moves the selected parts, often; the callee throttles. ]=]
	Moving: (() -> ())?,
	--[=[ Called when a change to the selection is over, whatever it was. ]=]
	Finished: (() -> ())?,
}

local SETTLE = 0.3
local QUIET_AFTER_UNDO = 0.4
local MAX_WATCHED = 300

local EditSounds = {}

--[=[
	Starts watching the selection. Every connection goes into the trove.

	@param deps Deps
	@param trove Trove
]=]
function EditSounds.new(deps: Deps, trove: Trove.Trove)
	local watching = trove:Extend()
	local moved, turned, sized = false, false, false
	local token = 0
	local quietUntil = 0
	local studioRecords = false

	--[[ Plays the sound for what changed since the last sound, then forgets it. ]]
	local function play()
		local name = if sized then "StudioScale" elseif turned then "StudioRotate" elseif moved then "StudioDrag" else nil

		moved, turned, sized = false, false, false
		token += 1

		local finished = deps.Finished

		if finished then
			finished()
		end

		if name and not deps.Busy() and os.clock() >= quietUntil then
			deps.Sound(name)

			local dropped = deps.Dropped

			if name == "StudioDrag" and dropped then
				dropped()
			end
		end
	end

	--[[ Without Studio's recordings to go by, plays once the parts have been still for a moment. ]]
	local function settleLater()
		token += 1

		if studioRecords then
			return
		end

		local mine = token

		task.delay(SETTLE, function()
			if token == mine then
				play()
			end
		end)
	end

	--[[ Watches the parts selected now, up to a limit, replacing the parts watched before. ]]
	local function watchSelection()
		watching:Clean()

		local count = 0

		for _, object in Selection:Get() do
			local parts: { Instance } = if object:IsA("BasePart") then { object } else object:GetDescendants()

			for _, part in parts do
				if part:IsA("BasePart") and count < MAX_WATCHED then
					count += 1

					local before = part.CFrame

					watching:Connect(part:GetPropertyChangedSignal("CFrame"), function()
						local now = part.CFrame

						if now.Rotation ~= before.Rotation then
							turned = true
						else
							moved = true

							local moving = deps.Moving

							if moving and not deps.Busy() then
								moving()
							end
						end

						before = now
						settleLater()
					end)
					watching:Connect(part:GetPropertyChangedSignal("Size"), function()
						sized = true
						settleLater()
					end)
				end
			end
		end
	end

	--[[ Studio finished a change of its own: a drag or handle let go, or a typed value. ]]
	local function recorded(name: string)
		if string.sub(name, 1, 5) == "Vlux_" then
			moved, turned, sized = false, false, false

			return
		end

		if not (moved or turned or sized) then
			return
		end

		studioRecords = true
		play()
	end

	--[[ An undo or redo moves parts too; its own sound covers it. ]]
	local function quiet()
		quietUntil = os.clock() + QUIET_AFTER_UNDO
		moved, turned, sized = false, false, false
	end

	trove:Add(function()
		token += 1
	end)
	trove:Connect(Selection.SelectionChanged, watchSelection)
	trove:Connect(ChangeHistoryService.OnRecordingFinished, recorded)
	trove:Connect(ChangeHistoryService.OnUndo, quiet)
	trove:Connect(ChangeHistoryService.OnRedo, quiet)
	watchSelection()
end

return EditSounds
