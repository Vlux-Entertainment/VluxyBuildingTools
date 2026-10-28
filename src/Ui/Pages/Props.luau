--!strict
--# selene: allow(mixed_table)

--[=[
	The Props tab: section buttons, a grid of prop pictures, and the options of the picked prop.
	A search box above the grid finds props in every section by name, id or category.

	The pictures are drawn in ViewportFrames, so the parts only exist inside the panel and never
	reach the place. They show their own colors, or the color theme when that setting is off, and are redrawn when either changes.

	@class PropsPage
]=]

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Actions = require("../../App/Actions")
local Colors = require("../../Core/Colors")
local Controls = require("../Controls")
local Geometry = require("../../Core/Geometry")
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
local SPIN_SPEED = math.pi / 4

type Source = { Props: typeof(Props), Data: typeof(PropData) }

--[[ The prop code the pictures are drawn from; the code loaded with the plugin until Reload prop pictures is pressed. ]]
local source: Source = { Props = Props, Data = PropData }
local copy: Instance? = nil

--[[
	Copies the plugin's code and loads the copy, so the pictures come from the prop code as it is
	now, not the version that was loaded when the plugin started. A plugin saved from the place
	is a snapshot, so the live VluxyBuildingTools folder in ServerStorage is copied when it is there.
	The copy before it is thrown away.
]]
local function reconstruct()
	local live = ServerStorage:FindFirstChild("VluxyBuildingTools")
	local root = if live then live else script.Parent and script.Parent.Parent and script.Parent.Parent.Parent
	local previous = copy

	if not root then
		return
	end

	local clone = root:Clone()
	local core, pure = clone:FindFirstChild("Core"), clone:FindFirstChild("Pure")
	local props = if core then core:FindFirstChild("Props") else nil
	local data = if pure then pure:FindFirstChild("PropData") else nil

	if not props or not data or not props:IsA("ModuleScript") or not data:IsA("ModuleScript") then
		clone:Destroy()

		return
	end

	local ok, loadedProps, loadedData = pcall(function()
		return (require :: any)(props), (require :: any)(data)
	end)

	if not ok then
		clone:Destroy()

		return
	end

	source = { Props = loadedProps, Data = loadedData }
	copy = clone

	if previous then
		previous:Destroy()
	end
end

--[[ A prop picture's spin: how far it has turned, and how to turn its camera to an angle. ]]
type Spin = { Angle: number, Turn: (angle: number) -> () }

--[[
	@param ui Ui
	@param prop PropData.Prop
	@return ViewportFrame -- a picture of the prop, colored like the map
	@return (angle: number) -> () -- turns the picture's camera around the prop; 0 is the starting view
]]
local function picture(ui: Ui, prop: PropData.Prop, original: boolean): (ViewportFrame, (angle: number) -> ())
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

	for _, spec in source.Props.Build(source.Data.Find(prop.Id) or prop, CFrame.new(), 1) do
		if spec.lamp or spec.lights then
			continue
		end

		local part = Instance.new("Part")
		local reach = spec.size.Magnitude / 2

		part.Name = spec.name
		part.Anchored = true
		part.Size = spec.size
		part.CFrame = spec.cf
		part.Material = Enum.Material.SmoothPlastic
		part.Parent = holder
		part.Color = if original then Color3.fromRGB(163, 162, 165) else Colors.Preview(ui.App.Display.Colors, part)

		if spec.glow then
			part.Material = Enum.Material.Neon
			part.Color = Color3.new(spec.glow[1], spec.glow[2], spec.glow[3])
		end

		if spec.paint and (original or not spec.paint.Soft) then
			part.Material = (Enum.Material :: any)[spec.paint.Material]
			part.Color = Color3.new(spec.paint.Color[1], spec.paint.Color[2], spec.paint.Color[3])
			part.Transparency = spec.paint.Transparency
		end

		if spec.shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		elseif spec.shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		end

		if spec.half then
			task.spawn(function()
				local carved = Geometry.Halve(part)

				if carved ~= part then
					carved.Parent = holder
					part:Destroy()
				end
			end)
		end

		low = low:Min(spec.cf.Position - Vector3.one * reach)
		high = high:Max(spec.cf.Position + Vector3.one * reach)
	end

	local middle = (low + high) / 2
	local radius = math.max(2, (high - low).Magnitude / 2)
	local camera = Instance.new("Camera")

	--[[ Puts the camera on its orbit around the prop, turned by an angle about the vertical. ]]
	local function turn(angle: number)
		camera.CFrame = CFrame.lookAt(middle + CFrame.Angles(0, angle, 0) * CAMERA_ANGLE * radius * 2.4, middle)
	end

	camera.FieldOfView = 40
	turn(0)
	camera.Parent = view
	view.CurrentCamera = camera

	return view, turn
end

--[[
	@param ui Ui
	@return { Instance } -- the cards of the Props tab
]]
return function(ui: Ui): { Instance }
	local app = ui.App
	local state, store = app.State, app.Store
	local pictures = vide.source(0)
	local query = vide.source("")

	local function current(): string?
		return if state.Mode() == "Prop" then state.Prop() else nil
	end

	local function picked(): boolean
		return state.Mode() == "Prop" and state.Prop() ~= nil
	end

	--[[ Whether the picked prop has lights to switch. ]]
	local function lit(): boolean
		local id = current()
		local def = if id then PropData.Find(id) else nil

		local parts: { PropData.Part } = if def then def.Parts else {}

		for _, part in parts do
			if part.lights then
				return true
			end
		end

		return false
	end

	--[[ The props the grid shows: the search results when something is typed, else the section on show. ]]
	local function shown(): { PropData.Prop }
		local text = query()

		return if text ~= "" then PropData.Search(text) else PropData.Shown(state.PropSection())
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
				Kit.PopWhen(function()
					return state.PropSection() == section.Id
				end),
				Kit.Corner(6),
				Kit.Stroke(),
				MouseButton1Click = function()
					app.Sound("Click")
					state.PropSection(section.Id)
					query("")
				end,
			})
		)
	end

	--[[
		Every prop cell, built once. Only the picture inside is redrawn, when the pictures are
		reloaded or the theme changes: vide cannot make reactive cells inside a reactive rebuild.
	]]
	local cells: { Instance } = {}
	local spins: { [string]: Spin } = {}
	local hovered: string? = nil

	--[[ The hovered prop and the picked one turn slowly; any other goes back to its starting view. ]]
	vide.cleanup(RunService.Heartbeat:Connect(function(dt: number)
		local chosen = current()
		local animate = store.Values.PropSpin

		for id, spin in spins do
			if animate and (id == hovered or id == chosen) then
				spin.Angle = (spin.Angle + dt * SPIN_SPEED) % (2 * math.pi)
				spin.Turn(spin.Angle)
			elseif spin.Angle ~= 0 then
				spin.Angle = 0
				spin.Turn(0)
			end
		end
	end))

	do
		local out = cells

		for _, prop in PropData.Props do
			local cell = new("Frame")({
				BorderSizePixel = 0,
				BackgroundColor3 = function()
					return if current() == prop.Id then Theme.Accent() else Theme.Tile
				end,
				LayoutOrder = function()
					return table.find(shown(), prop) or 0
				end,
				Visible = function()
					return table.find(shown(), prop) ~= nil
				end,
				Kit.Corner(6),
				Kit.Stroke(),
				function(): Instance
					pictures()
					Store.Get(store, "ColorTheme")

					local original = Store.Get(store, "PropShowOriginal") == true
					local view = vide.untrack(function()
						local made, turn = picture(ui, prop, original)
						local spin = spins[prop.Id]

						if spin then
							spin.Turn = turn
							turn(spin.Angle)
						else
							spins[prop.Id] = { Angle = 0, Turn = turn }
						end

						return made
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
					ui.Popups.Tip({
						Text = prop.Label .. if prop.Mount == "wall"
							then " (hangs on a wall)."
							elseif prop.Mount == "ceiling" then " (hangs from a ceiling)."
							else ".",
					}),
					MouseEnter = function()
						hovered = prop.Id
					end,
					MouseLeave = function()
						if hovered == prop.Id then
							hovered = nil
						end
					end,
					MouseButton1Click = function()
						app.Sound("Click")
						Actions.PickProp(app, prop.Id)
					end,
				}),
			})

			table.insert(out, cell)
		end
	end

	--[[ The search box, which sets `query` as it is typed in. ]]
	local function searchField(): TextBox
		local box = new("TextBox")({
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = Theme.Field,
			BorderSizePixel = 0,
			Text = "",
			PlaceholderText = "Search props",
			PlaceholderColor3 = Theme.Muted,
			TextColor3 = Theme.Text,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
			LayoutOrder = Kit.Next(),
			Kit.Corner(5),
			Kit.Stroke(),
		}) :: TextBox

		vide.cleanup(box:GetPropertyChangedSignal("Text"):Connect(function()
			query(box.Text)
		end))

		return box
	end

	return {
		Controls.Card(ui, "PROPS", {
			Controls.Button(ui, "Reload prop pictures", function()
				reconstruct()
				pictures(pictures() + 1)
			end),
			searchField(),
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
				Title = "Show original colors in the list",
				Key = "PropShowOriginal",
			}),
			Controls.Switch(ui, {
				Title = "Light on",
				Key = "PropLightOn",
				Visible = lit,
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
