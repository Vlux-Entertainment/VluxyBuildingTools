--!strict
--# selene: allow(mixed_table)

--[=[
	The Build tab: the grid of tool tiles, and under it one card with the options of the active
	tool. Every option row says which modes it belongs to, and shows only while one of them is on.

	@class BuildPage
]=]

local Actions = require("../../App/Actions")
local Brushes = require("../../Core/Brushes")
local Controls = require("../Controls")
local Kit = require("../Kit")
local Store = require("../../State/Store")
local Theme = require("../Theme")
local Tips = require("../../Pure/Tips")
local Tools = require("../../Pure/Tools")
local vide = require("../../Packages/vide")

type Ui = Controls.Ui
type Modes = { [string]: boolean }

local new = Kit.New

local DRAW: Modes = {
	Wall = true,
	Floor = true,
	PillaredWall = true,
	Corridor = true,
	ArchedCorridor = true,
	Room = true,
	Foundation = true,
	Porch = true,
	Fence = true,
	Roof = true,
	Railing = true,
	HalfWall = true,
	Vent = true,
	VentRamp = true,
	VentShaft = true,
	Block = true,
	Stairs = true,
	Ramp = true,
	Arch = true,
	Pillar = true,
}
local HEIGHT: Modes = {
	Wall = true,
	PillaredWall = true,
	Corridor = true,
	ArchedCorridor = true,
	Room = true,
	Block = true,
	Pillar = true,
	Porch = true,
}
local WINDOWS: Modes = { Window = true, CircleWindow = true, TriangleWindow = true }
local OPENINGS: Modes = { Door = true, Window = true, CircleWindow = true, TriangleWindow = true, ArchOpening = true }
local VENT_SIZED: Modes = {
	Vent = true,
	VentRamp = true,
	VentShaft = true,
	VentCover = true,
	VentCap = true,
	VentFan = true,
	VentPeek = true,
	VentHole = true,
}
local ADVANCED_TOOLS: Modes = {
	Stairs = true,
	Ramp = true,
	Room = true,
	Corridor = true,
	ArchedCorridor = true,
	Arch = true,
	ArchOpening = true,
	Place = true,
	Door = true,
	Vent = true,
	VentRamp = true,
	VentShaft = true,
	VentHole = true,
}

--[[
	@param ...string
	@return Modes -- a set of the given modes
]]
local function modes(...: string): Modes
	local set: Modes = {}

	for _, mode in { ... } do
		set[mode] = true
	end

	return set
end

--[[
	@param ui Ui
	@param tool Tools.Tile
	@return TextButton -- one tile of the tool grid, lit while one of its modes is on
]]
local function tile(ui: Ui, tool: Tools.Tile, index: number): TextButton
	local state = ui.App.State

	local function active(): boolean
		local mode = state.Mode()
		local owner = if mode then Tools.TileOf(mode) else nil

		return owner ~= nil and owner.Id == tool.Id
	end

	return new("TextButton")({
		BackgroundColor3 = function()
			return if active() then Theme.AccentDim() else Theme.Tile
		end,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = true,
		LayoutOrder = index,
		Kit.PopWhen(active),
		Kit.Corner(6),
		new("UIStroke")({
			Color = function()
				return if active() then Theme.Accent() else Theme.CardStroke
			end,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		ui.Popups.Tip({ Text = tool.Description, Key = if tool.Key then "Ctrl+" .. tool.Key else nil }),
		new("TextLabel")({
			Size = UDim2.new(0, 30, 1, 0),
			Position = UDim2.fromOffset(4, 0),
			BackgroundTransparency = 1,
			Text = tool.Glyph,
			TextColor3 = Theme.Text,
			Font = Enum.Font.GothamMedium,
			TextSize = 22,
		}),
		new("TextLabel")({
			Size = UDim2.new(1, -56, 1, 0),
			Position = UDim2.fromOffset(38, 0),
			BackgroundTransparency = 1,
			Text = tool.Label,
			TextColor3 = Theme.Text,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		if tool.Key
			then new("TextLabel")({
				Size = UDim2.fromOffset(14, 14),
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -5, 0, 5),
				BackgroundTransparency = 1,
				Text = tool.Key,
				TextColor3 = Theme.Muted,
				Font = Enum.Font.GothamMedium,
				TextSize = 10,
			})
			else nil,
		MouseButton1Click = function()
			Actions.Select(ui.App, tool.Id)
		end,
	})
end

--[[
	@param ui Ui
	@param visible () -> boolean
	@return Frame -- the brush list: each brush switches on or off, or is removed
]]
local function brushList(ui: Ui, visible: () -> boolean): Frame
	local app = ui.App

	local function changed()
		Actions.BrushesChanged(app)
	end

	local function rows(): { Instance }
		app.State.BrushRevision()

		local brushes = Brushes.List()
		local out: { Instance } = {}

		if #brushes == 0 then
			local empty = Controls.Text(ui, "No brushes yet.")

			vide.cleanup(empty)
			table.insert(out, empty)
		end

		for index, entry in brushes do
			local on = Brushes.IsOn(entry)

			local row = new("Frame")({
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundTransparency = 1,
				LayoutOrder = index,
				new("TextButton")({
					Size = UDim2.new(1, -34, 1, 0),
					BackgroundColor3 = function()
						return if on then Theme.Accent() else Theme.Tile
					end,
					BorderSizePixel = 0,
					Text = entry.Name,
					TextColor3 = if on then Theme.Background else Theme.Muted,
					Font = Enum.Font.GothamMedium,
					TextSize = 12,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Kit.Corner(6),
					Kit.Stroke(),
					ui.Popups.Tip({
						Text = "Click to switch this brush on or off.",
					}),
					MouseButton1Click = function()
						app.Sound("Click")
						Brushes.Toggle(entry)
						changed()
					end,
				}),
				new("TextButton")({
					Size = UDim2.fromOffset(28, 28),
					Position = UDim2.new(1, -28, 0, 0),
					BackgroundColor3 = Theme.Tile,
					BorderSizePixel = 0,
					Text = "✕",
					TextColor3 = Theme.Text,
					Font = Enum.Font.GothamMedium,
					TextSize = 12,
					Kit.Corner(6),
					Kit.Stroke(),
					ui.Popups.Tip({ Text = "Remove this brush from the list." }),
					MouseButton1Click = function()
						app.Sound("Click")
						Brushes.Remove(entry)
						changed()
					end,
				}),
			})

			vide.cleanup(row)
			table.insert(out, row)
		end

		return out
	end

	return new("Frame")({
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = Kit.Next(),
		Visible = visible,
		Kit.List(4),
		rows,
	})
end

--[=[
	@param ui Ui
	@return { Instance } -- the cards of the Build tab
]=]
return function(ui: Ui): { Instance }
	local app = ui.App
	local state, store = app.State, app.Store
	local toolOpen = vide.source(true)
	local advanced = vide.source(false)

	--[[
		@param set Modes? -- the modes the row belongs to, or nil for every mode
		@param isAdvanced boolean? -- shown only with Advanced options open
		@param extra (() -> boolean)? -- a further condition
		@return () -> boolean -- whether the row shows now
	]]
	local function when(set: Modes?, isAdvanced: boolean?, extra: (() -> boolean)?): () -> boolean
		return function()
			local mode = state.Mode()

			return toolOpen()
				and (set == nil or set[mode or "None"] == true)
				and (not isAdvanced or advanced())
				and (extra == nil or extra())
		end
	end

	local function setting(key: string): () -> boolean
		return function()
			return Store.Get(store, key) == true
		end
	end

	local function number(key: string, title: string, min: number, max: number, step: number?, visible: () -> boolean)
		return Controls.Number(ui, {
			Key = key,
			Title = title,
			Min = min,
			Max = max,
			Step = step,
			Integer = key == "ArchSegments",
			Visible = visible,
		})
	end

	local tiles = {}

	for index, entry in Tools.Grid do
		table.insert(tiles, tile(ui, entry, index))
	end

	local howTo: Tips.Tip = { Text = "" }

	vide.effect(function()
		howTo.Text = Tools.Instruction(state.Mode())
	end)

	local header = Kit.Row(34, {
		new("TextButton")({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ui.Popups.Tip(howTo),
			MouseButton1Click = function()
				app.Sound("Click")
				toolOpen(not toolOpen())
			end,
			new("TextLabel")({
				Size = UDim2.new(0, 30, 1, 0),
				BackgroundTransparency = 1,
				Text = function()
					local tool = state.Mode() and Tools.Find(state.Mode() :: string)

					return if tool then tool.Glyph else ""
				end,
				TextColor3 = Theme.Text,
				Font = Enum.Font.GothamMedium,
				TextSize = 22,
			}),
			new("TextLabel")({
				Size = UDim2.new(1, -70, 1, 0),
				Position = UDim2.fromOffset(38, 0),
				BackgroundTransparency = 1,
				Text = function()
					local tool = state.Mode() and Tools.Find(state.Mode() :: string)

					return if tool then string.upper(tool.Label) else ""
				end,
				TextColor3 = Theme.Text,
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			new("TextLabel")({
				Size = UDim2.new(0, 24, 1, 0),
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				BackgroundTransparency = 1,
				Text = function()
					return if toolOpen() then "⌃" else "⌄"
				end,
				TextColor3 = Theme.Muted,
				Font = Enum.Font.GothamBold,
				TextSize = 14,
			}),
		}),
	})

	local variants = {}

	for _, group in Tools.Grid do
		if #group.Modes > 1 then
			local options: { Controls.Option } = {}

			for i, id in group.Modes do
				local tool = Tools.Find(id) :: Tools.Tool

				table.insert(options, {
					Value = id,
					Label = tool.Glyph .. "  " .. tool.Label,
					Tip = tool.Description,
					Key = "Alt+" .. (if i == 10 then 0 else i),
				})
			end

			table.insert(
				variants,
				Controls.Choice(ui, {
					Options = options,
					Columns = 2,
					Get = state.Mode,
					Set = function(id)
						Actions.SetMode(app, id)
					end,
					Visible = when(modes(table.unpack(group.Modes))),
				})
			)
		end
	end

	local door = modes("Door")

	return {
		Controls.Card(ui, "BUILD TOOLS", {
			new("Frame")({
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = Kit.Next(),
				new("UIGridLayout")({
					CellSize = UDim2.new(0.5, -4, 0, 44),
					CellPadding = UDim2.fromOffset(8, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				tiles,
			}),
		}),
		Controls.Card(ui, nil, {
			header,
			variants,
			number("Height", "Height", 0.1, 2048, nil, when(HEIGHT)),
			number(
				"Thickness",
				"Thickness",
				0.05,
				128,
				nil,
				when(modes("Wall", "PillaredWall", "Corridor", "ArchedCorridor", "Room", "Arch"))
			),
			number("Width", "Clear width", 0.1, 1024, nil, when(modes("Corridor", "ArchedCorridor", "Stairs", "Ramp"))),
			number("StairHeight", "Total stair rise", 0.1, 1024, nil, when(modes("Stairs"))),
			number("RampHeight", "Ramp rise", 0.1, 1024, nil, when(modes("Ramp"))),
			number("ArchHeight", "Clear height", 0.1, 1024, nil, when(modes("Arch"))),
			number("ArchDepth", "Frame depth", 0.1, 256, nil, when(modes("Arch"))),
			number("OpenWidth", "Archway width", 0.1, 1024, nil, when(modes("ArchOpening"))),
			number("OpenHeight", "Archway height", 0.1, 1024, nil, when(modes("ArchOpening"))),
			number("DoorWidth", "Doorway width", 0.1, 1024, nil, when(door)),
			number("DoorHeight", "Doorway height", 0.1, 1024, nil, when(door)),
			Controls.Switch(ui, { Title = "Door frame", Key = "DoorFrame", Visible = when(door) }),
			Controls.Switch(ui, { Title = "Door", Key = "DoorPanel", Visible = when(door) }),
			Controls.Slider(ui, "DoorTransparency", "Door transparency", when(door, false, setting("DoorPanel"))),
			Controls.Switch(ui, {
				Title = "Door CanCollide",
				Key = "DoorCollide",
				Visible = when(door, false, setting("DoorPanel")),
			}),
			number("WindowWidth", "Window width", 0.1, 1024, nil, when(WINDOWS)),
			number("WindowHeight", "Window height", 0.1, 1024, nil, when(WINDOWS)),
			number("WindowSill", "Bottom above floor", 0, 1024, nil, when(WINDOWS)),
			number("PillarWidth", "Pillar width", 0.1, 256, nil, when(modes("Pillar", "PillaredWall"))),
			Controls.Choice(ui, {
				Options = {
					{ Value = "Gable", Tip = "Gable roof." },
					{ Value = "Hip", Tip = "Hip roof." },
					{ Value = "Shed", Tip = "Shed roof." },
					{ Value = "Pyramid", Tip = "Pyramid roof." },
					{ Value = "Flat", Tip = "Flat roof." },
				},
				Columns = 3,
				Get = function()
					return Store.Get(store, "RoofStyle")
				end,
				Set = function(value)
					Store.Set(store, "RoofStyle", value)
				end,
				Visible = when(modes("Roof")),
			}),
			Controls.Choice(ui, {
				Options = {
					{ Value = "Open", Tip = "Open: no wall between the rooms." },
					{ Value = "Shared", Tip = "Shared: the rooms share one wall." },
					{ Value = "Separate", Tip = "Separate: both walls stay." },
				},
				Columns = 3,
				Get = function()
					return Store.Get(store, "RoomJoin")
				end,
				Set = function(value)
					Store.Set(store, "RoomJoin", value)
				end,
				Visible = when(modes("Room")),
			}),
			number("FloorTransparency", "Transparency (0 solid, 1 clear)", 0, 1, 0.1, when(modes("Floor"))),
			number("RoofRise", "Roof rise", 0.1, 512, nil, when(modes("Roof"))),
			number("RoofOverhang", "Overhang", 0, 128, nil, when(modes("Roof"))),
			number("FoundationHeight", "Slab height", 0.1, 256, nil, when(modes("Foundation"))),
			number("FoundationMargin", "Margin around", 0, 128, nil, when(modes("Foundation"))),
			number("FenceHeight", "Fence height", 0.1, 256, nil, when(modes("Fence"))),
			number("FenceSpacing", "Post spacing", 0.5, 256, nil, when(modes("Fence", "Porch"))),
			Controls.Switch(ui, { Title = "Railing", Key = "PorchRailing", Visible = when(modes("Porch")) }),
			number("RailHeight", "Railing height", 0.1, 256, nil, when(modes("Porch", "Railing", "HalfWall"))),
			number("BalusterSpacing", "Bar spacing", 0.3, 64, nil, when(modes("Railing"))),
			number("VentSize", "Vent size", 0.5, 64, nil, when(VENT_SIZED)),
			number("RoofThickness", "Roof sheet thickness", 0.05, 64, nil, when(modes("Roof"), true)),
			number("Yaw", "Copy rotation", -360, 360, 90, when(modes("Place"))),
			number("BrushRadius", "Brush radius", 0, 200, 1, when(modes("Place"))),
			number("BrushSpacing", "Brush spacing", 0.5, 100, 0.5, when(modes("Place"))),
			Controls.Switch(ui, { Title = "Random rotation", Key = "BrushRandomYaw", Visible = when(modes("Place")) }),
			brushList(ui, when(modes("Place"))),
			Controls.Button(ui, "Add selected to brushes", function()
				local _, message = Brushes.AddSelected()

				Actions.BrushesChanged(app)
				app.Say(message)
			end, true, when(modes("Place"))),
			Controls.Switch(ui, { Title = "Ceiling", Key = "Roof", Visible = when(modes("Room", "Corridor")) }),
			Controls.Switch(ui, { Title = "Snap to parts", Key = "SnapToParts", Visible = when(DRAW) }),
			number("SnapRadius", "Part snap distance", 0.25, 32, 0.25, when(DRAW, false, setting("SnapToParts"))),
			Controls.Switch(ui, {
				Title = "Join rooms and corridors",
				Key = "ConnectStructures",
				Visible = when(modes("Room", "Corridor", "ArchedCorridor")),
			}),
			Controls.Switch(ui, { Title = "Set cut depth with mouse", Key = "CutDepth", Visible = when(OPENINGS) }),
			Kit.Row(30, {
				new("TextButton")({
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = function()
						return (if advanced() then "▼  " else "▶  ") .. "Advanced options"
					end,
					TextColor3 = Theme.Text,
					Font = Enum.Font.Gotham,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					AutoButtonColor = false,
					MouseButton1Click = function()
						app.Sound("Click")
						advanced(not advanced())
					end,
				}),
			}, when(ADVANCED_TOOLS)),
			number("Run", "Approx. step depth", 0.1, 64, 0.25, when(modes("Stairs"), true)),
			number("Landing", "Top landing depth", 0, 256, nil, when(modes("Stairs", "Ramp"), true)),
			number(
				"Floor",
				"Floor / ceiling thickness",
				0.05,
				128,
				0.25,
				when(modes("Room", "Corridor", "ArchedCorridor", "Porch", "Floor"), true)
			),
			number(
				"ArchSegments",
				"Arch smoothness",
				4,
				48,
				4,
				when(modes("Arch", "ArchOpening", "ArchedCorridor"), true)
			),
			number("FrameWidth", "Frame width", 0.05, 8, nil, when(door, true, setting("DoorFrame"))),
			number("FrameDepth", "Frame depth", 0.05, 64, nil, when(door, true, setting("DoorFrame"))),
			number("DoorThickness", "Door thickness", 0.05, 8, nil, when(door, true, setting("DoorPanel"))),
			number(
				"VentThickness",
				"Vent sheet thickness",
				0.05,
				4,
				0.05,
				when(modes("Vent", "VentRamp", "VentShaft", "VentHole"), true)
			),
			number("BrushSizeMin", "Smallest size (x)", 0.05, 20, 0.1, when(modes("Place"), true)),
			number("BrushSizeMax", "Biggest size (x)", 0.05, 20, 0.1, when(modes("Place"), true)),
			number("Offset", "Surface gap", -256, 256, 0.25, when(modes("Place"), true)),
			Controls.Switch(
				ui,
				{ Title = "Tilt copy to surface", Key = "Align", Visible = when(modes("Place"), true) }
			),
		}, function()
			return state.Mode() ~= nil
		end),
	}
end
