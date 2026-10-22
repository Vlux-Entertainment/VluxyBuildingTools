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
	Arrange = { Text = "Copy, flip, rotate and snap what you have selected.", Key = "Tab" },
	Display = { Text = "Color themes, the surface grid and hidden parts.", Key = "Tab" },
	Settings = { Text = "Snap size, hotkeys and resetting the panel.", Key = "Tab" },
	Hotkeys = { Text = "Every hotkey, explained.", Key = "F1" },

	-- Working folder
	["Choose working folder"] = {
		Text = "Then click a Folder in the viewport, or select one in the Explorer. The plugin only works inside the Folder you confirm.",
	},
	["Change working folder"] = { Text = "Pick a different Folder to work in. Themes are switched off first." },
	Yes = {
		Text = "The plugin may build, move, rotate, recolor and delete Parts inside this Folder. Nothing outside it is changed.",
	},
	["Use folder's"] = {
		Text = "Takes the settings saved on this folder (theme, ghost transparency, themes on or off, grid) as your own, then starts working in it.",
	},
	Overwrite = {
		Text = "Starts working in this folder and saves your settings onto it, replacing the ones it had. Everyone who uses the folder gets yours.",
	},
	Cancel = { Text = "Do not change the working folder.", Key = "Esc" },

	-- Switches
	Themes = {
		Text = "Colors every Part in the working folder by the theme picked below. Saved with the place and visible to your team. Switching it off restores each original color.",
		Key = "P",
	},
	["Surface grid"] = {
		Text = "Puts a grid texture on every face of the Parts in the working folder. Saved with the place and visible to your team. Switching it off removes it.",
		Key = "L",
	},
	["Construction grid while drawing"] = {
		Text = "Shows the snap grid under the cursor while you draw. Only you see it.",
	},
	["Show hidden parts (ghosted)"] = {
		Text = "Show the parts you hid as faint ghosts, or hide them completely again.",
		Key = "I",
	},
	["Play sounds"] = {
		Text = "Play small sounds for button clicks, hotkeys, tools and placing things. The sound ids are all in Pure/SoundIds.",
	},
	SoundVolume = { Text = "How loud the plugin sounds are, from 0 (silent) to 1." },
	["Blender hotkeys"] = { Text = "Turn the Blender-style hotkeys on or off. Esc, Enter and [ ] always work." },
	["Railing"] = { Text = "Add a low railing around the porch." },
	["Roof style"] = { Text = "The shape of the roof." },
	RoofRise = { Text = "How high the roof peak is above its edge." },
	RoofOverhang = { Text = "How far the roof sticks out past the corners you click." },
	RoofThickness = { Text = "How thick the roof sheets are on hip and pyramid roofs." },
	FoundationHeight = { Text = "How thick the foundation slab is." },
	FoundationMargin = { Text = "How far the slab sticks out past the corners you click." },
	RailHeight = { Text = "How tall the railing or half wall is." },
	FenceHeight = { Text = "How tall the fence posts are." },
	StandardHeight = {
		Text = "The wall height every tool starts from. A tool can override it; its name then shows a *.",
	},
	StandardThickness = {
		Text = "The wall thickness every tool starts from. A tool can override it; its name then shows a *.",
	},
	StandardDoorWidth = {
		Text = "The doorway width every tool starts from. A tool can override it; its name then shows a *.",
	},
	StandardDoorHeight = {
		Text = "The doorway height every tool starts from. A tool can override it; its name then shows a *.",
	},
	["Join rooms and corridors"] = {
		Text = "Openings are cut through the walls where rooms, corridors and arched corridors meet. They are not merged into one union.",
	},
	RoomJoin = {
		Text = "How a new room meets a room next to it. Open removes the walls between them, Shared keeps one wall, Separate keeps both walls.",
	},
	["Snap to parts"] = {
		Text = "Points snap to the corners and edges of nearby parts, with a marker where they land. Hold Shift to skip it and use the Precise Grid Snap.",
	},
	SnapRadius = { Text = "How close, in studs, the cursor has to be to a corner or edge for the point to snap to it." },
	CutDepth = {
		Text = "After you click a spot, move the mouse to set how deep the cut goes. Past the far side of the wall it cuts all the way through.",
	},
	FloorTransparency = { Text = "How see-through the floor is. 0 is solid, 1 is invisible." },
	BalusterSpacing = { Text = "About how far apart the bars of an indoor railing are." },
	FenceSpacing = { Text = "About how far apart the fence posts are." },
	Ceiling = { Text = "Add a ceiling to rooms and corridors." },
	["Tilt copy to surface"] = { Text = "Tilt stamped copies so they sit flat on a sloped surface." },

	-- Buttons
	["Unhide all (Alt+H)"] = { Text = "Bring back every part you hid.", Key = "Alt+H" },
	["Flip X"] = { Text = "Mirror the selection across the X axis, around its own centre.", Key = "Ctrl+M, then X" },
	["Flip Y"] = { Text = "Mirror the selection across the Y axis, around its own centre.", Key = "Ctrl+M, then Y" },
	["Flip Z"] = { Text = "Mirror the selection across the Z axis, around its own centre.", Key = "Ctrl+M, then Z" },
	["+90° X"] = { Text = "Rotate the selection 90 degrees about X.", Key = "O, then X" },
	["+90° Y"] = { Text = "Rotate the selection 90 degrees about Y.", Key = "O, then Y" },
	["+90° Z"] = { Text = "Rotate the selection 90 degrees about Z.", Key = "O, then Z" },
	["−90° X"] = { Text = "Rotate the selection -90 degrees about X.", Key = "O, then Alt+X" },
	["−90° Y"] = { Text = "Rotate the selection -90 degrees about Y.", Key = "O, then Alt+Y" },
	["−90° Z"] = { Text = "Rotate the selection -90 degrees about Z.", Key = "O, then Alt+Z" },
	["Make repeated copies"] = { Text = "Copy the selection several times, stepping by the X, Y and Z spacing." },
	["Snap selection"] = { Text = "Move the selection onto the snap grid." },
	["Show dimensions"] = { Text = "Show the size of the selection in the viewport." },
	["Anchor selection"] = { Text = "Anchor every selected Part." },
	["Reset all settings"] = { Text = "Put every number and switch on this panel back to its default." },

	-- Number fields, by settings key
	Grid = { Text = "Points you draw land on a grid of this many studs." },
	FineGrid = { Text = "The smaller grid points land on while you hold Shift, for precise placement.", Key = "Shift" },
	Height = { Text = "How tall walls, rooms and blocks are.", Key = "[ and ]" },
	Thickness = { Text = "How thick walls and frames are." },
	Width = { Text = "How wide corridors, stairs and ramps are." },
	StairHeight = { Text = "How high the whole flight of stairs climbs.", Key = "[ and ]" },
	RampHeight = { Text = "How high the ramp climbs.", Key = "[ and ]" },
	ArchHeight = { Text = "The clear height under the arch.", Key = "[ and ]" },
	ArchDepth = { Text = "How deep the arch frame is." },
	OpenWidth = { Text = "How wide the archway is." },
	OpenHeight = { Text = "How tall the archway is." },
	PillarWidth = { Text = "How wide the pillar is on each side." },
	DoorWidth = { Text = "How wide the doorway is." },
	DoorHeight = { Text = "How tall the doorway is." },
	WindowWidth = { Text = "How wide the window is." },
	WindowHeight = { Text = "How tall the window is." },
	WindowSill = { Text = "How far the bottom of the window is above the bottom of the wall." },
	Yaw = { Text = "How much to turn painted copies.", Key = "R" },
	FieldStep = {
		Text = "Arrow step: how much the + and - buttons beside every number change it. Set 0.1 to move by 0.1 everywhere. 0 lets each field use its own step.",
	},
	GhostTransparency = {
		Text = "How see-through hidden parts look when you show them as ghosts. 0 is solid, 1 is clear.",
	},
	PropRandomAmount = {
		Text = "Each prop is turned a random amount up to this many degrees either way from the Rotation setting.",
	},
	["Collapse props after picking one"] = {
		Text = "After you pick a prop, the browser goes back to showing only its first row so the settings are in view. Turn off to keep it open.",
	},
	PropScale = { Text = "Makes the prop bigger or smaller than its normal size. 1 is normal." },
	["Door frame"] = {
		Text = "Adds a frame of three bars around the door: two sides and a top. The opening is cut wider and taller to fit it.",
	},
	Door = {
		Text = "Adds a door panel that fills the doorway. It is half see-through, and can be walked through unless Door CanCollide is on.",
	},
	["Door CanCollide"] = {
		Text = "Makes the door solid so players cannot walk through it. Off by default.",
	},
	FrameWidth = { Text = "How wide each bar of the door frame is, in studs." },
	FrameDepth = { Text = "How thick the door frame is through the wall, in studs. It is centred on the wall." },
	DoorThickness = { Text = "How thick the door panel is, in studs." },
	DoorTransparency = { Text = "How see-through the door is. 0 is solid, 1 is invisible." },
	["Allow untagged folders (not recommended)"] = {
		Text = "Lets the plugin work in any folder. Off by default: a folder needs the VluxyBT_Map tag so the plugin never edits a folder by accident.",
	},
	["Camera light"] = {
		Text = "A light that follows the editor camera, so dark rooms are easy to see. It is never saved in the place.",
	},
	["Random rotation"] = { Text = "Turns each brush copy a random amount around the up axis." },
	["Randomize prop rotation"] = {
		Text = "Turns each prop a small random amount when you place it, so a row of props looks less uniform. The preview stays straight. Set the amount below.",
	},
	["Set cut depth with mouse"] = {
		Text = "After clicking a wall, move the mouse to choose how deep the opening goes before you click again.",
	},
	VentSize = { Text = "The outside width and height of a vent duct, in studs." },
	VentThickness = { Text = "How thick the sheet metal of a vent is." },
	BrushRadius = { Text = "How far from the cursor the brush scatters copies, in studs." },
	BrushSizeMin = { Text = "The smallest a painted copy can be, as a multiple of the original size." },
	BrushSizeMax = { Text = "The biggest a painted copy can be, as a multiple of the original size." },
	BrushSpacing = { Text = "How far the cursor travels before the brush adds the next copy, in studs." },
	CameraLightRange = { Text = "How far the light on the editor camera reaches." },
	CameraLightBrightness = { Text = "How bright the light on the editor camera is." },

	Run = { Text = "Roughly how deep each step is." },
	Landing = { Text = "A flat landing added at the top." },
	Floor = { Text = "How thick floors and ceilings are." },
	ArchSegments = { Text = "More segments make a smoother curve." },
	Offset = { Text = "A gap between a stamped copy and the surface." },
	Copies = { Text = "How many extra copies to make." },
	DX = { Text = "Distance between repeated copies along X." },
	DY = { Text = "Distance between repeated copies along Y." },
	DZ = { Text = "Distance between repeated copies along Z." },
	Extend = { Text = "How far a face extend grows by default." },
	GridTextureSize = { Text = "How many studs one tile of the surface grid covers." },
} :: { [string]: Tip }

--[=[
	@param name string -- a control's label or settings key
	@return Tip? -- its hover description, or nil when it has none
]=]
function Tips.Find(name: string): Tip?
	return Tips.Entries[name]
end

return Tips
