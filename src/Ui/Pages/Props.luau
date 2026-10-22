--!strict
--# selene: allow(mixed_table)

--[=[
	The Props tab: section buttons, a grid of prop pictures, and the options of the picked prop.
	With Collapse props after picking one on, picking a prop folds the grid down to the row that
	holds it, with a button to show all again.

	The pictures are drawn in ViewportFrames, so the parts only exist inside the panel and never
	reach the place. They are colored by the color theme and redrawn when it changes.

	@class PropsPage
]=]

local Actions = require("../../App/Actions")
local Colors = require("../../Core/Colors")
local Controls = require("../Controls")
local Kit = require("../Kit")
local PropData = require("../../Pure/PropData")
local Props = require("../../Core/Props")
local Store = require("../../State/Store")
local Theme = require("../Theme")
local vide = require("../../Packages/vide")

type Ui = Controls.Ui

local new = Kit.New

local COLUMNS = 3
local CELL_HEIGHT = 104
local CAMERA_ANGLE = Vector3.new(0.9, 0.7, -1.3).Unit

--[[
	@param ui Ui
	@param prop PropData.Prop
	@return ViewportFrame -- a picture of the prop, colored like the map
]]
local function picture(ui: Ui, prop: PropData.Prop): ViewportFrame
	local view = new("ViewportFrame")({
		Size = UDim2.new(1, -8, 1, -24),
		Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 150, 160),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-0.5, -1, 0.7),
	}) :: ViewportFrame
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	local holder = Instance.new("Model")

	holder:SetAttribute("VluxyBT_Prop", prop.Id)
	holder.Parent = view

	for _, spec in Props.Build(prop, CFrame.new(), 1) do
		local part = Instance.new("Part")
		local reach = spec.size.Magnitude / 2

		part.Name = spec.name
		part.Anchored = true
		part.Size = spec.size
		part.CFrame = spec.cf
		part.Material = Enum.Material.SmoothPlastic
		part.Parent = holder
		part.Color = Colors.Preview(ui.App.Display.Colors, part)

		if spec.shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		elseif spec.shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		end

		low = low:Min(spec.cf.Position - Vector3.one * reach)
		high = high:Max(spec.cf.Position + Vector3.one * reach)
	end

	local middle = (low + high) / 2
	local radius = math.max(2, (high - low).Magnitude / 2)
	local camera = Instance.new("Camera")

	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(middle + CAMERA_ANGLE * radius * 2.4, middle)
	camera.Parent = view
	view.CurrentCamera = camera

	return view
end

--[=[
	@param ui Ui
	@return { Instance } -- the cards of the Props tab
]=]
return function(ui: Ui): { Instance }
	local app = ui.App
	local state, store = app.State, app.Store
	local collapsed = vide.source(false)
	local pictures = vide.source(0)

	--[[ Showing another section, by click or by wheel, shows all of it again. ]]
	vide.effect(function()
		state.PropSection()
		vide.untrack(function()
			collapsed(false)
		end)
	end)

	local function current(): string?
		return if state.Mode() == "Prop" then state.Prop() else nil
	end

	local function picked(): boolean
		return state.Mode() == "Prop" and state.Prop() ~= nil
	end

	--[[ The row of the picked prop in the section on show, or nil when it is not in it. ]]
	local function pickedRow(): number?
		local id = current()

		for index, prop in PropData.Shown(state.PropSection()) do
			if prop.Id == id then
				return (index - 1) // COLUMNS
			end
		end

		return nil
	end

	local sections = {}

	for i, section in PropData.Sections do
		table.insert(
			sections,
			new("TextButton")({
				BorderSizePixel = 0,
				Text = section.Label,
				Font = Enum.Font.GothamMedium,
				TextSize = 11,
				LayoutOrder = i,
				Kit.Lit(function()
					return state.PropSection() == section.Id
				end),
				Kit.Corner(6),
				Kit.Stroke(),
				MouseButton1Click = function()
					app.Sound("Click")
					state.PropSection(section.Id)
					collapsed(false)
				end,
			})
		)
	end

	--[[
		Every prop cell, built once. Only the picture inside is redrawn, when the pictures are
		reloaded or the theme changes: vide cannot make reactive cells inside a reactive rebuild.
	]]
	local cells: { Instance } = {}

	do
		local out = cells

		for _, prop in PropData.Props do
			local cell = new("Frame")({
				BorderSizePixel = 0,
				BackgroundColor3 = function()
					return if current() == prop.Id then Theme.Accent else Theme.Tile
				end,
				LayoutOrder = function()
					return table.find(PropData.Shown(state.PropSection()), prop) or 0
				end,
				Visible = function()
					local shown = PropData.Shown(state.PropSection())
					local at = table.find(shown, prop)
					local row = pickedRow()

					if not at then
						return false
					end

					return not collapsed() or row == nil or (at - 1) // COLUMNS == row
				end,
				Kit.Corner(6),
				Kit.Stroke(),
				function(): Instance
					pictures()
					Store.Get(store, "ColorTheme")

					local view = vide.untrack(function()
						return picture(ui, prop)
					end)

					vide.cleanup(view)

					return view
				end,
				new("TextLabel")({
					Size = UDim2.new(1, -4, 0, 18),
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 2, 1, -2),
					BackgroundTransparency = 1,
					Text = prop.Label,
					TextColor3 = Theme.Text,
					Font = Enum.Font.GothamMedium,
					TextSize = 11,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
				new("TextButton")({
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "",
					ZIndex = 5,
					ui.Popups.Tip({ Text = prop.Label .. if prop.Mount == "wall" then " (hangs on a wall)." else "." }),
					MouseButton1Click = function()
						app.Sound("Click")
						collapsed(app.Store.Values.PropAutoCollapse)
						Actions.PickProp(app, prop.Id)
					end,
				}),
			})

			table.insert(out, cell)
		end
	end

	return {
		Controls.Card(ui, "PROPS", {
			Controls.Switch(ui, { Title = "Collapse props after picking one", Key = "PropAutoCollapse" }),
			Controls.Button(ui, "Reload prop pictures", function()
				pictures(pictures() + 1)
			end),
			new("Frame")({
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = Kit.Next(),
				Kit.Grid(COLUMNS, 26, 4),
				sections,
			}),
			new("Frame")({
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = Kit.Next(),
				Kit.Grid(COLUMNS, CELL_HEIGHT, 4),
				cells,
			}),
			Controls.Button(ui, "Show all props", function()
				collapsed(false)
			end, false, collapsed),
			Controls.Number(ui, {
				Key = "Yaw",
				Title = "Rotation",
				Min = -360,
				Max = 360,
				Step = 90,
				Visible = picked,
			}),
			Controls.Number(ui, {
				Key = "PropScale",
				Title = "Prop size (x)",
				Min = 0.2,
				Max = 5,
				Step = 0.1,
				Visible = picked,
			}),
			Controls.Switch(ui, {
				Title = "Randomize prop rotation",
				Key = "PropRandomRotation",
				Visible = picked,
			}),
			Controls.Number(ui, {
				Key = "PropRandomAmount",
				Title = "Random rotation (+/- degrees)",
				Min = 0,
				Max = 180,
				Step = 5,
				Visible = function()
					return picked() and Store.Get(store, "PropRandomRotation") == true
				end,
			}),
		}),
	}
end
