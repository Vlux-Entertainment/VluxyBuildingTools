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
	Arrange = { Text = "Copy, mirror, flip, rotate and snap what you have selected.", Key = "Tab" },
	Display = { Text = "Pastel colors, the surface grid and hidden parts.", Key = "Tab" },
	Settings = { Text = "Snap size, hotkeys and resetting the panel.", Key = "Tab" },
	Hotkeys = { Text = "Every hotkey, explained.", Key = "F1" },

	-- Working folder
	["Choose working folder"] = {
		Text = "Then click a Folder in the viewport, or select one in the Explorer. The plugin only works inside the Folder you confirm.",
	},
	["Change working folder"] = { Text = "Pick a different Folder to work in. Pastel colors is switched off first." },
	Yes = {
		Text = "The plugin may build, move, rotate, recolor and delete Parts inside this Folder. Nothing outside it is changed.",
	},
	Cancel = { Text = "Do not change the working folder.", Key = "Esc" },

	-- Switches
	["Pastel colors"] = {
		Text = "Gives every Part in the working folder a random pastel color. Saved with the place and visible to your team. Switching it off restores each original color.",
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
	["Blender hotkeys"] = { Text = "Turn the Blender-style hotkeys on or off. Esc, Enter and [ ] always work." },
	["Railing"] = { Text = "Add a low railing around the porch." },
	["Roof style"] = { Text = "The shape of the roof." },
	RoofRise = { Text = "How high the roof peak is above its edge." },
	RoofOverhang = { Text = "How far the roof sticks out past the corners you click." },
	RoofThickness = { Text = "How thick the roof sheets are on hip and pyramid roofs." },
	FoundationHeight = { Text = "How thick the foundation slab is." },
	FoundationMargin = { Text = "How far the slab sticks out past the corners you click." },
	RailHeight = { Text = "How tall the porch railing is." },
	FenceHeight = { Text = "How tall the fence posts are." },
	FenceSpacing = { Text = "About how far apart the fence posts are." },
	["Pillared ends"] = {
		Text = "Put a pillar at each end of a wall, wider than the wall, so walls have some depth. Chained walls share their pillars.",
	},
	Ceiling = { Text = "Add a ceiling to rooms and corridors." },
	["Tilt copy to surface"] = { Text = "Tilt stamped copies so they sit flat on a sloped surface." },

	-- Buttons
	["Use selected floor height"] = { Text = "Draw on top of the selected Part instead of at the Floor level number." },
	["Start new chain"] = { Text = "Begin the next wall or corridor somewhere else.", Key = "Enter" },
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
	["Make mirror copy"] = { Text = "Copy the selection, mirrored across world 0 on the chosen axis." },
	["Snap selection"] = { Text = "Move the selection onto the snap grid." },
	["Show dimensions"] = { Text = "Show the size of the selection in the viewport." },
	["Anchor selection"] = { Text = "Anchor every selected Part." },
	["Reset all settings"] = { Text = "Put every number and switch on this panel back to its default." },

	-- Number fields, by settings key
	Grid = { Text = "How far points snap to the grid while drawing. Hold Shift for the fine step." },
	FineGrid = { Text = "The snap step while Shift is held." },
	Elevation = { Text = "The height of the floor you draw on." },
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
	Yaw = { Text = "How much to turn stamped copies.", Key = "R" },
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
