--!strict
--# selene: allow(mixed_table)

--[=[
	The Working Folder card at the top of the panel: which folder the plugin works in, and the
	buttons to pick one, confirm it, or settle differing shared settings.

	@class FolderCard
]=]

local Controls = require("../Controls")
local Kit = require("../Kit")
local Theme = require("../Theme")
local WorkingFolder = require("../../Services/WorkingFolder")

type Ui = Controls.Ui

--[=[
	@param ui Ui
	@return Frame
]=]
return function(ui: Ui): Frame
	local app = ui.App
	local state, folder = app.State, app.Folder

	--[[ The folder to name: the one waiting for a yes, else the working folder unless picking. ]]
	local function shown(): Instance?
		return state.Pending() or (if state.Picking() then nil else state.Folder())
	end

	local function cancelPick()
		WorkingFolder.CancelPicking(folder)
	end

	local function resolve(choice: string): () -> ()
		return function()
			WorkingFolder.Resolve(folder, choice)
		end
	end

	return Controls.Card(ui, "WORKING FOLDER", {
		Kit.New("TextLabel")({
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = Theme.AccentDim,
			BorderSizePixel = 0,
			Text = function()
				local target = shown()

				return if target then target:GetFullName() else ""
			end,
			Visible = function()
				return shown() ~= nil
			end,
			TextColor3 = Theme.Accent,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = Kit.Next(),
			Kit.Corner(6),
			Kit.Stroke(Theme.Accent),
			Kit.New("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
		}),
		Controls.Text(
			ui,
			function()
				local conflict = state.Conflict()

				return if conflict
					then `This folder's settings differ: {conflict}.`
					elseif state.Pending() then "Work in this folder?"
					elseif state.Picking() then "Click a Folder."
					else ""
			end,
			nil,
			function()
				return state.Conflict() ~= nil or state.Pending() ~= nil or state.Picking()
			end
		),
		Controls.Button(
			ui,
			function()
				return if state.Folder() then "Change working folder" else "Choose working folder"
			end,
			function()
				WorkingFolder.StartPicking(folder)
			end,
			true,
			function()
				return not state.Picking()
			end
		),
		Controls.ButtonRow(ui, {
			{
				Text = "Yes",
				Primary = true,
				Run = function()
					WorkingFolder.ConfirmPicking(folder)
				end,
			},
			{ Text = "Cancel", Run = cancelPick, Primary = true },
		}, function()
			return state.Pending() ~= nil
		end),
		Controls.ButtonRow(ui, {
			{ Text = "Use folder's", Run = resolve("Use"), Primary = true },
			{ Text = "Overwrite", Run = resolve("Overwrite"), Primary = true },
			{ Text = "Cancel", Run = resolve("Cancel") },
		}, function()
			return state.Conflict() ~= nil
		end),
		Controls.ButtonRow(ui, { { Text = "Cancel", Run = cancelPick, Primary = true } }, function()
			return state.Picking() and state.Pending() == nil
		end),
	})
end
