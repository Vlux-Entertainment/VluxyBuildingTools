--!strict

--[=[
	Sounds for building with Studio's own tools: dragging, rotating and scaling selected parts. Studio
	does not say when its tools finish, so this watches the selected parts and plays one sound once
	they stop changing. It keeps quiet while the plugin moves things itself and right after an undo
	or redo, which have their own sound.

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
	--[=[ True while the panel is open. ]=]
	Open: () -> boolean,
}

local SETTLE = 0.15
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

	--[[ Plays the sound for what changed once the parts have been still for a moment. ]]
	local function settleLater()
		token += 1

		local mine = token

		task.delay(SETTLE, function()
			if token ~= mine then
				return
			end

			local name = if sized
				then "StudioScale"
				elseif turned then "StudioRotate"
				elseif moved then "StudioDrag"
				else nil

			moved, turned, sized = false, false, false

			if name and deps.Open() and not deps.Busy() and os.clock() >= quietUntil then
				deps.Sound(name)
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

	--[[ An undo or redo moves parts too; its own sound covers it. ]]
	local function quiet()
		quietUntil = os.clock() + QUIET_AFTER_UNDO
	end

	trove:Add(function()
		token += 1
	end)
	trove:Connect(Selection.SelectionChanged, watchSelection)
	trove:Connect(ChangeHistoryService.OnUndo, quiet)
	trove:Connect(ChangeHistoryService.OnRedo, quiet)
	watchSelection()
end

return EditSounds
