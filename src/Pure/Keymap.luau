--!strict

--[=[
	The Blender-style hotkeys. `Resolve` turns a key press into an action name; the plugin decides
	what the action does. Ctrl is only used for Ctrl+M and the Ctrl+number tool picks, and Alt for Alt+H, the plane locks and the
	Alt+number options, so Studio's
	own shortcuts keep working. W A S D Q E F and Shift are never taken: Studio uses them to fly the
	camera, focus and multi-select.

	@class Keymap
]=]

export type Action = string

local TOOL_KEYS: { [string]: string } = {
	One = "Basic",
	Two = "Stairs",
	Three = "Additive",
	Four = "Structures",
	Five = "Vents",
	Six = "Railings",
	Seven = "Place",
	Zero = "Measure",
}

local OPTION_KEYS: { [string]: number } = {
	One = 1,
	Two = 2,
	Three = 3,
	Four = 4,
	Five = 5,
	Six = 6,
	Seven = 7,
	Eight = 8,
	Nine = 9,
	Zero = 10,
}

local RESERVED: { [string]: boolean } = {
	W = true,
	A = true,
	S = true,
	D = true,
	Q = true,
	E = true,
	F = true,
}

local PLAIN_KEYS: { [string]: Action } = {
	T = "Extrude",
	G = "Grab",
	R = "Rotate",
	C = "Scale",
	Escape = "Cancel",
	Return = "Confirm",
	KeypadEnter = "Confirm",
	RightBracket = "HeightUp",
	LeftBracket = "HeightDown",
	Tab = "NextTab",
	F1 = "ShowHotkeys",
	P = "TogglePastel",
	L = "ToggleGrid",
	V = "Duplicate",
	O = "Rotate90Arm",
	I = "ToggleHiddenView",
	Backquote = "PrevTab",
	N = "TogglePanel",
	H = "Hide",
}

local Keymap = {}

--[=[
	Every binding with its plain-language meaning, for the Help tab.

	@return { { string } } -- pairs of { keys, meaning }
]=]
function Keymap.Describe(): { { string } }
	return {
		{
			"Ctrl+1 … Ctrl+7, Ctrl+0",
			"Pick a tool; press again to turn it off",
		},
		{
			"Alt+1 … Alt+0",
			"Pick an option inside the active tool",
		},
		{ "T", "Extrude the face under the cursor" },
		{ "G / R / C", "Grab, rotate or scale the selection" },
		{ "V", "Duplicate and grab the selection" },
		{
			"W A S D Q E F",
			"Left to Studio for the camera",
		},
		{
			"Hold Shift",
			"Snap to the precise grid",
		},
		{ "X / Y / Z", "Lock to that axis; press again to unlock" },
		{ "Alt+X / Y / Z", "Lock to the plane across that axis" },
		{ "0-9 and .", "Type an exact amount" },
		{ "Enter / click", "Confirm" },
		{ "Esc / right-click", "Cancel, or stop the tool" },
		{ "[ and ]", "Lower or raise the height" },
		{ "Tab / `", "Next or previous panel tab" },
		{
			"Ctrl+Scroll",
			"Previous or next tool, or prop section",
		},
		{
			"Alt+Scroll",
			"Previous or next tool option",
		},
		{ "F1", "Open this tab" },
		{ "P", "Themes on or off" },
		{ "L", "Surface grid on or off" },
		{ "N", "Show or hide the panel" },
		{ "Ctrl+M, then X / Y / Z", "Mirror the selection on that axis" },
		{
			"O, then X / Y / Z",
			"Turn the selection 90 degrees; Alt for -90",
		},
		{ "Arrow keys in Rotate", "Turn by 90 degrees while rotating" },
		{ "H", "Hide the selected parts, just for you" },
		{ "Alt+H", "Unhide everything" },
		{ "I", "Show hidden parts as ghosts, or not" },
	}
end

--[=[
	@param keyName string -- `Enum.KeyCode.Name`
	@param shift boolean
	@param ctrl boolean
	@param alt boolean
	@param axisKeys boolean -- true while drawing or in a modal action, so X, Y and Z mean a lock
	@return Action? -- nil when the key is not a hotkey here. Tool picks are `Tool:<Name>`, locks
		are `Lock:X`, `Lock:Y`, `Lock:Z` and `Plane:X`, `Plane:Y`, `Plane:Z`.
]=]
function Keymap.Resolve(keyName: string, shift: boolean, ctrl: boolean, alt: boolean, axisKeys: boolean): Action?
	if RESERVED[keyName] then
		return nil
	end

	if alt and not ctrl and not shift and keyName == "H" then
		return "Unhide"
	end

	if ctrl and not alt and not shift and keyName == "M" then
		return "FlipArm"
	end

	if ctrl and not alt and not shift and TOOL_KEYS[keyName] then
		return `Tool:{TOOL_KEYS[keyName]}`
	end

	if shift or ctrl then
		return nil
	end

	if axisKeys and (keyName == "X" or keyName == "Y" or keyName == "Z") then
		return `{if alt then "Plane" else "Lock"}:{keyName}`
	end

	if alt then
		local option = OPTION_KEYS[keyName]

		return if option then `Option:{option}` else nil
	end

	return PLAIN_KEYS[keyName]
end

--[=[
	@param ctrl boolean
	@param alt boolean
	@param shift boolean
	@param wheel number -- the wheel movement, positive when scrolled up
	@return Action? -- `Tile:-1` or `Tile:1` for Ctrl+scroll, `Mode:-1` or `Mode:1` for Alt+scroll, else nil.
		Holding both Ctrl and Alt does nothing.
		Scrolling up steps back, scrolling down steps forward.
]=]
function Keymap.Scroll(ctrl: boolean, alt: boolean, shift: boolean, wheel: number): Action?
	if shift or wheel == 0 or ctrl == alt then
		return nil
	end

	local step = if wheel > 0 then -1 else 1

	return `{if alt then "Mode" else "Tile"}:{step}`
end

return Keymap
