--!strict
--# selene: allow(mixed_table)

--[=[
	The Working Folder card at the top of the panel, one compact row. Normally it names the folder,
	offers a button to change folder, and the card's title line shows who is working in it (the admin has a ring). While
	picking, confirming, settling differing settings or answering an admin request, the same row
	shows that step's short text and buttons instead.

	@class FolderCard
]=]

local Actions = require("../../App/Actions")
local Admin = require("../../Services/Admin")
local AppState = require("../../State/AppState")
local Controls = require("../Controls")
local Kit = require("../Kit")
local Theme = require("../Theme")
local Tips = require("../../Pure/Tips")
local WorkingFolder = require("../../Services/WorkingFolder")
local vide = require("../../Packages/vide")

type Ui = Controls.Ui
type Person = AppState.Person

--[=[
	A button of a step's row.

	@interface StepButton
	@within FolderCard
	.Text string
	.Width number
	.Run () -> ()
	.Primary boolean?
]=]
type StepButton = { Text: string, Width: number, Run: () -> (), Primary: boolean? }

local new = Kit.New

local ROW_HEIGHT = 34
local AVATAR = 18
local AVATAR_GAP = 5
local CHANGE_WIDTH = 30
local GAP = 6

--[[ How far above the folder row the card's title line sits: its height plus the card's row gap. ]]
local TITLE_LIFT = 26

--[[
	@param ui Ui
	@param item StepButton
	@param right number -- the space to leave on its right
	@return TextButton -- a small button pinned to the right of the row
]]
local function stepButton(ui: Ui, item: StepButton, right: number): TextButton
	return new("TextButton")({
		Size = UDim2.new(0, item.Width, 1, -4),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -right, 0.5, 0),
		BackgroundColor3 = function()
			return if item.Primary then Theme.Accent() else Theme.Tile
		end,
		BorderSizePixel = 0,
		Text = item.Text,
		TextColor3 = if item.Primary then Theme.Background else Theme.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Kit.Corner(6),
		if item.Primary then nil else Kit.Stroke(),
		ui.Popups.Tip(Tips.Find(item.Text)),
		MouseButton1Click = function()
			ui.App.Sound("Click")
			Controls.Safe(ui, item.Run)()
		end,
	})
end

--[[
	@param ui Ui
	@param text () -> string
	@param buttons { StepButton }
	@param visible () -> boolean
	@return Frame -- one step's short text on the left and its buttons on the right
]]
local function step(ui: Ui, text: () -> string, buttons: { StepButton }, visible: () -> boolean): Frame
	local children: { any } = {}
	local right = 0

	for index = #buttons, 1, -1 do
		table.insert(children, stepButton(ui, buttons[index], right))
		right += buttons[index].Width + GAP
	end

	return new("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = visible,
		new("TextLabel")({
			Size = UDim2.new(1, -right - 2, 1, 0),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = Theme.Text,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			ui.Popups.Tip(function(): Tips.Tip?
				return { Text = text() }
			end),
		}),
		children,
	})
end

--[[
	@param ui Ui
	@param person () -> Person
	@param index number
	@return ImageButton -- a round head shot; the admin's has a ring, and clicking offers admin
]]
local function avatar(ui: Ui, person: () -> Person, index: number): ImageButton
	local app = ui.App

	--[[ Offers to give admin to this person, or to ask for it, at the mouse. ]]
	local function offer(at: Vector2)
		local who = person()

		if app.State.IsAdmin() and not who.Me then
			ui.Popups.Menu(at, `Give admin to {who.Name}`, function()
				Actions.GiveAdmin(app, who.UserId)
			end)
		elseif not app.State.IsAdmin() then
			ui.Popups.Menu(at, "Request admin", function()
				Actions.RequestAdmin(app)
			end)
		else
			app.Say("You are the admin of this folder.")
		end
	end

	return new("ImageButton")({
		Size = UDim2.fromOffset(AVATAR, AVATAR),
		BackgroundColor3 = Theme.Tile,
		BorderSizePixel = 0,
		LayoutOrder = index,
		Image = function()
			return person().Avatar
		end,
		AutoButtonColor = true,
		Kit.Corner(AVATAR // 2),
		new("UIStroke")({
			Color = Theme.Accent,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = function()
				return if person().Admin then 0 else 1
			end,
		}),
		new("TextLabel")({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = function()
				return string.upper(string.sub(person().Name, 1, 1))
			end,
			Visible = function()
				return person().Avatar == ""
			end,
			TextColor3 = Theme.Text,
			Font = Enum.Font.GothamBold,
			TextSize = 11,
		}),
		ui.Popups.Tip(function(): Tips.Tip?
			local who = person()

			return { Text = if who.Admin then `{who.Name} (admin)` else who.Name }
		end),
		InputBegan = function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				ui.App.Sound("Click")
				offer(Vector2.new(input.Position.X, input.Position.Y))
			end
		end,
	})
end

--[[
	@param ui Ui
	@return Frame
]]
return function(ui: Ui): Frame
	local app = ui.App
	local state, folder = app.State, app.Folder

	--[[ Which step the row shows: a folder pick or conflict first, then an admin request, then the folder. ]]
	local function mode(): string
		return if state.Conflict()
			then "Conflict"
			elseif state.Pending() then "Pending"
			elseif state.Picking() then "Picking"
			elseif state.Folder() and state.AdminRequest() then "Request"
			elseif state.Folder() then "Folder"
			else "None"
	end

	--[[ True while the row shows the named step. ]]
	local function showing(name: string): () -> boolean
		return function()
			return mode() == name
		end
	end

	--[[ Gives up picking a folder. ]]
	local function cancelPick()
		WorkingFolder.CancelPicking(folder)
	end

	--[[ A button's run that settles differing settings with the choice. ]]
	local function resolve(choice: string): () -> ()
		return function()
			WorkingFolder.Resolve(folder, choice)
		end
	end

	local avatars = vide.indexes(state.People, function(person: () -> Person, index: number)
		return avatar(ui, person, index)
	end)

	--[[ The avatars sit at the right of the card's title line, so the folder row keeps its width and the card its height. ]]
	local people = new("Frame")({
		Size = function()
			return UDim2.fromOffset(#state.People() * (AVATAR + AVATAR_GAP), AVATAR)
		end,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, -TITLE_LIFT),
		BackgroundTransparency = 1,
		Visible = function()
			return state.Folder() ~= nil
		end,
		new("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, AVATAR_GAP),
		}),
		avatars,
	})

	local folderRow = new("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = showing("Folder"),
		new("TextLabel")({
			Size = UDim2.new(1, -CHANGE_WIDTH - GAP, 1, -4),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			BackgroundColor3 = Theme.AccentDim,
			BorderSizePixel = 0,
			Text = function()
				local target = state.Folder()

				return if target then target.Name else ""
			end,
			TextColor3 = Theme.Accent,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			Kit.Corner(6),
			Kit.Stroke(Theme.Accent),
			new("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
			ui.Popups.Tip(function(): Tips.Tip?
				local target = state.Folder()

				return if target then { Text = target:GetFullName() } else nil
			end),
		}),
		new("TextButton")({
			Size = UDim2.new(0, CHANGE_WIDTH, 1, -4),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			BackgroundColor3 = Theme.Tile,
			BorderSizePixel = 0,
			Text = "⇄",
			TextColor3 = Theme.Text,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			Kit.Corner(6),
			Kit.Stroke(),
			ui.Popups.Tip(Tips.Find("Change working folder")),
			MouseButton1Click = function()
				ui.App.Sound("Click")
				WorkingFolder.StartPicking(folder)
			end,
		}),
	})

	local choose = new("TextButton")({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Text = "Choose working folder",
		TextColor3 = Theme.Background,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		Visible = showing("None"),
		Kit.Corner(6),
		ui.Popups.Tip(Tips.Find("Choose working folder")),
		MouseButton1Click = function()
			ui.App.Sound("Click")
			WorkingFolder.StartPicking(folder)
		end,
	})

	--[[ The name of whoever asks for admin. ]]
	local function asker(): string
		local id = state.AdminRequest()

		return if id then Admin.NameOf(app.Admin, id) else ""
	end

	return Controls.Card(ui, "WORKING FOLDER", {
		Kit.Row(ROW_HEIGHT, {
			people,
			folderRow,
			choose,
			step(ui, function()
				return `Settings differ: {state.Conflict() or ""}.`
			end, {
				{ Text = "Use folder's", Width = 82, Run = resolve("Use"), Primary = true },
				{ Text = "Overwrite", Width = 72, Run = resolve("Overwrite"), Primary = true },
				{ Text = "Cancel", Width = 56, Run = resolve("Cancel") },
			}, showing("Conflict")),
			step(ui, function()
				local pending = state.Pending()

				return if pending then `Work in "{pending.Name}"?` else ""
			end, {
				{
					Text = "Yes",
					Width = 50,
					Primary = true,
					Run = function()
						WorkingFolder.ConfirmPicking(folder)
					end,
				},
				{ Text = "Cancel", Width = 56, Run = cancelPick },
			}, showing("Pending")),
			step(ui, function()
				return "Click a Folder."
			end, { { Text = "Cancel", Width = 56, Run = cancelPick, Primary = true } }, showing("Picking")),
			step(ui, function()
				return `{asker()} asks for admin`
			end, {
				{
					Text = "Give",
					Width = 50,
					Primary = true,
					Run = function()
						local id = state.AdminRequest()

						if id then
							Actions.GiveAdmin(app, id)
						end
					end,
				},
				{
					Text = "Ignore",
					Width = 56,
					Run = function()
						Actions.IgnoreRequest(app)
					end,
				},
			}, showing("Request")),
		}),
	})
end
