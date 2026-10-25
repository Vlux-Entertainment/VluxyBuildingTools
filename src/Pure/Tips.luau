--!strict

--[=[
	The hover descriptions for the panel's buttons, switches and number fields, and the hotkey for each
	when it has one. Keyed by the control's label, or by the settings key for number fields. The
	tools carry their own descriptions in `Tools`.

	@class Tips
]=]

export type Tip = {
	Text: string,
	Key: string?,
}

local Tips = {}

Tips.Entries = {
	-- Tabs
	Build = { Text = "Pick a building tool and set its numbers.", Key = "Tab" },
	Arrange = { Text = "Flip the selection or make array copies.", Key = "Tab" },
	Display = { Text = "Themes, the surface grid and hidden parts.", Key = "Tab" },
	Settings = { Text = "Snapping, standard sizes, the panel's look and sound.", Key = "Tab" },
	Hotkeys = { Text = "Every hotkey, and the switch for them.", Key = "F1" },

	-- Card titles
	["BUILD TOOLS"] = { Text = "Pick a tool, then click in the viewport." },
	FLIP = { Text = "Mirror the selection; Ctrl+M, then X, Y or Z.", Key = "Ctrl+M" },
	ARRAY = { Text = "Like Blender's Array modifier; copies preview while this tab is open." },
	VIEW = { Text = "Themes and grid save with the place, so switch them off before publishing." },
	["HIDDEN PARTS"] = { Text = "The admin presses H to hide selected parts for everyone.", Key = "H" },
	PROPS = { Text = "Pick a prop, then click a floor or wall; R turns it.", Key = "R" },
	SNAPPING = { Text = "How every drawing tool snaps points." },
	["STANDARD SIZES"] = { Text = "The sizes new builds start from." },
	VIEWPORT = { Text = "What the plugin draws in the 3D view." },
	SOUND = { Text = "The plugin's sounds." },
	RESET = { Text = "Puts this tab back to its defaults; builds are untouched." },
	Tooltips = { Text = "Show these descriptions when you hover." },
	TooltipDelay = { Text = "How long to hover before a description shows." },
	["Previews use the UI color"] = { Text = "Build previews and folder outlines take the UI color, not orange." },
	["Prop rotation"] = { Text = "The hovered or picked prop picture slowly turns." },
	["Hint bar"] = { Text = "Show the active tool's keys at the bottom of the 3D view." },
	["WORKING FOLDER"] = {
		Text = "The plugin only edits this folder; click a face to give, ask for or take over admin.",
	},
	TOOLS = { Text = "Pick tools and their options without the mouse." },
	DRAWING = { Text = "Keys that work while you draw or move something." },
	["MOVE & EDIT"] = { Text = "Act on the selected parts, Blender-style." },
	["SHOW & HIDE"] = { Text = "Themes, grid, camera light and hidden parts." },
	PANEL = { Text = "Move around this panel; Studio keeps its camera keys." },
	INTERFACE = { Text = "How the panel looks and moves." },
	["Zebra rows"] = { Text = "Shade every other row so values line up with their labels." },
	["UI animations"] = { Text = "Buttons pop when clicked or picked." },
	AnimationIntensity = { Text = "How big the button pops are." },

	-- Working folder
	["Choose working folder"] = { Text = "Click a Folder in the viewport or Explorer to work in." },
	["Change working folder"] = { Text = "Pick a different Folder to work in." },
	Give = { Text = "Make them the admin of this folder." },
	Ignore = { Text = "Turn the request down; it also runs out after a minute." },
	Yes = { Text = "Let the plugin edit Parts in this Folder only." },
	["Use folder's"] = { Text = "Use the settings saved on this folder." },
	Overwrite = { Text = "Save your settings onto this folder." },
	Cancel = { Text = "Keep the current working folder.", Key = "Esc" },

	-- Switches
	Themes = { Text = "Color parts by theme; hold P and scroll to switch themes.", Key = "P" },
	["Surface grid"] = { Text = "Put a grid texture on every part; your team sees it too.", Key = "L" },
	["Show hidden parts (ghosted)"] = { Text = "Show hidden parts as faint ghosts.", Key = "I" },
	["Play sounds"] = { Text = "Play small sounds for clicks and tools." },
	SoundVolume = { Text = "How loud the sounds are." },
	["Blender hotkeys"] = { Text = "Turn the Blender-style hotkeys on or off." },
	["Railing"] = { Text = "Add a low railing around the porch." },
	RoofRise = { Text = "How high the roof peak rises." },
	RoofOverhang = { Text = "How far the roof sticks out past the corners." },
	RoofThickness = { Text = "How thick hip and pyramid roof sheets are." },
	FoundationHeight = { Text = "How thick the slab is." },
	FoundationMargin = { Text = "How far the slab sticks out past the corners." },
	RailHeight = { Text = "How tall the railing or half wall is." },
	FenceHeight = { Text = "How tall the fence posts are." },
	StandardHeight = { Text = "The wall height every tool starts from." },
	StandardThickness = { Text = "The wall thickness every tool starts from." },
	StandardDoorWidth = { Text = "The doorway width every tool starts from." },
	StandardDoorHeight = { Text = "The doorway height every tool starts from." },
	["Join rooms and corridors"] = { Text = "Cut openings where rooms and corridors meet." },
	["Grab snaps to measure guides"] = {
		Text = "While grabbing with G, a corner or centre of the selection snaps onto measuring guide points.",
	},
	["Snap to parts"] = { Text = "Snap points to corners and edges of nearby parts." },
	SnapRadius = { Text = "How close the cursor must be to snap to a part." },
	FloorTransparency = { Text = "How see-through the floor is." },
	BalusterSpacing = { Text = "How far apart the railing bars are." },
	FenceSpacing = { Text = "How far apart the posts are." },
	Ceiling = { Text = "Add a ceiling to rooms and corridors." },
	["Tilt copy to surface"] = { Text = "Tilt copies to sit flat on slopes." },

	-- Buttons
	["Unhide all (Alt+H)"] = { Text = "Bring back every hidden part, for everyone.", Key = "Alt+H" },
	["Flip X"] = { Text = "Mirror the selection across X.", Key = "Ctrl+M, then X" },
	["Flip Y"] = { Text = "Mirror the selection across Y.", Key = "Ctrl+M, then Y" },
	["Flip Z"] = { Text = "Mirror the selection across Z.", Key = "Ctrl+M, then Z" },
	["Reset settings"] = { Text = "Put this tab's settings back to their defaults; tools, display and hotkeys stay." },

	-- Number fields, by settings key
	Grid = { Text = "The grid points snap to, in studs." },
	FineGrid = { Text = "The finer grid used while you hold Shift.", Key = "Shift" },
	Height = { Text = "How tall walls, rooms and blocks are.", Key = "[ and ]" },
	Thickness = { Text = "How thick walls and frames are." },
	Width = { Text = "How wide corridors, stairs and ramps are." },
	StairHeight = { Text = "How high the stairs climb.", Key = "[ and ]" },
	RampHeight = { Text = "How high the ramp climbs.", Key = "[ and ]" },
	ArchHeight = { Text = "The clear height under the arch.", Key = "[ and ]" },
	ArchDepth = { Text = "How deep the arch frame is." },
	OpenWidth = { Text = "How wide the archway is." },
	OpenHeight = { Text = "How tall the archway is." },
	PillarWidth = { Text = "How wide the pillar is." },
	DoorWidth = { Text = "How wide the doorway is." },
	DoorHeight = { Text = "How tall the doorway is." },
	WindowWidth = { Text = "How wide the window is." },
	WindowHeight = { Text = "How tall the window is." },
	WindowSill = { Text = "How high the window sits above the floor." },
	Yaw = { Text = "How much to turn each copy or prop.", Key = "R" },
	FieldStep = { Text = "How much the + and - buttons change a number; 0 uses each field's own." },
	GhostTransparency = { Text = "How see-through ghosted parts are." },
	PropRandomAmount = { Text = "The most a prop is randomly turned, in degrees." },
	["Collapse props after picking one"] = { Text = "Fold the prop list after you pick one." },
	PropScale = { Text = "Prop size; 1 is normal." },
	["Door frame"] = { Text = "Add a frame around the door." },
	Door = { Text = "Add a see-through door panel." },
	["Door CanCollide"] = { Text = "Make the door solid." },
	FrameWidth = { Text = "How wide each frame bar is." },
	FrameDepth = { Text = "How thick the frame is through the wall." },
	DoorThickness = { Text = "How thick the door panel is." },
	DoorTransparency = { Text = "How see-through the door is." },
	["Camera light"] = { Text = "A light that follows your camera; never saved.", Key = "Alt+L" },
	["Random rotation"] = { Text = "Turn each brush copy a random amount." },
	["Randomize prop rotation"] = { Text = "Turn each prop a small random amount." },
	["Set cut depth with mouse"] = { Text = "Move the mouse to set how deep the opening goes." },
	StairUnderThickness = {
		Text = "How thick the sloped underside is, square to the slope, under the steps' inner corners.",
	},
	VentSize = { Text = "The clear space inside a vent; the sheets go outside it." },
	VentThickness = { Text = "How thick the vent metal is." },
	BrushRadius = { Text = "How far from the cursor copies scatter." },
	BrushSizeMin = { Text = "The smallest copy, as a multiple of the original." },
	BrushSizeMax = { Text = "The biggest copy, as a multiple of the original." },
	BrushSpacing = { Text = "How far to move before the next copy." },
	CameraLightRange = { Text = "How far the camera light reaches." },
	CameraLightBrightness = { Text = "How bright the camera light is." },

	Run = { Text = "Roughly how deep each step is." },
	Landing = { Text = "How deep the top landing is." },
	Floor = { Text = "How thick floors and ceilings are." },
	ArchSegments = { Text = "More segments make a smoother curve." },
	Offset = { Text = "A gap between a copy and the surface." },
	ArrayCount = { Text = "How many objects in total, the original included." },
	ArrayRelX = { Text = "Spacing along X, in selection widths." },
	ArrayRelY = { Text = "Spacing along Y, in selection heights." },
	ArrayRelZ = { Text = "Spacing along Z, in selection depths." },
	ArrayConstX = { Text = "Extra spacing along X, in studs." },
	ArrayConstY = { Text = "Extra spacing along Y, in studs." },
	ArrayConstZ = { Text = "Extra spacing along Z, in studs." },
	["Relative Offset"] = { Text = "Space copies by the selection's own size." },
	["Constant Offset"] = { Text = "Space copies by a fixed number of studs." },
	["Apply Array"] = { Text = "Make the previewed copies." },
	GridTextureSize = { Text = "How many studs one grid tile covers." },
} :: { [string]: Tip }

--[=[
	@param name string -- a control's label or settings key
	@return Tip? -- its hover description, or nil when it has none
]=]
function Tips.Find(name: string): Tip?
	return Tips.Entries[name]
end

return Tips
