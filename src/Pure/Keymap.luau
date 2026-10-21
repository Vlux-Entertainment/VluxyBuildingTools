--!strict

--[=[
	The Blender-style hotkeys. `Resolve` turns a key press into an action name; the plugin decides
	what the action does. Ctrl is only used for Ctrl+M and Alt for Alt+H and the plane locks, so Studio's
	own shortcuts keep working. W A S D Q E F and Shift are never taken: Studio uses them to fly the
	camera, focus and multi-select.

	@class Keymap
]=]

export type Action = string

local TOOL_KEYS: { [string]: string } = {
	One = "Wall",
	Two = "Structures",
	Three = "Block",
	Four = "Stairs",
	Five = "Arches",
	Six = "Opening",
	Seven = "Place",
	Eight = "Measure",
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
			"1 … 8",
			"Pick a tool: Walls, Structures, Block, Stairs, Arches, Door / Window, Stamp, Measure. Press it again to turn it off",
		},
		{ "T", "Extrude the face under the cursor of the selected block" },
		{ "G / R / C", "Grab, rotate or scale the selection" },
		{ "V", "Duplicate the selection and grab the copy" },
		{
			"W A S D Q E F, Shift",
			"Never taken: Studio uses them to fly the camera, focus and multi-select. Hotkeys are also ignored while the right mouse button is held",
		},
		{ "X / Y / Z", "While drawing or in a modal action: lock to that world axis. Press again to unlock" },
		{ "Alt+X / Y / Z", "Lock to the plane the axis is perpendicular to" },
		{ "0-9 and .", "While drawing or in a modal action: type an exact length, angle or factor" },
		{ "Enter / click", "Confirm" },
		{ "Esc / right-click", "Cancel the action, or stop the tool" },
		{ "[ and ]", "Lower or raise the active height by one snap step" },
		{ "Tab / `", "Next or previous panel tab" },
		{ "F1", "Open this Hotkeys tab" },
		{ "P", "Pastel colors on or off" },
		{ "L", "Surface grid on or off" },
		{ "N", "Show or hide the panel" },
		{ "Ctrl+M, then X / Y / Z", "Flip (mirror) the selection in place across that axis" },
		{
			"O, then X / Y / Z",
			"Rotate the selection 90 degrees about that axis. Hold Alt on the axis key for -90",
		},
		{ "Arrow keys in Rotate", "While rotating with R, step the angle by 90 degrees" },
		{ "H", "Hide the selected parts (local to you, nothing is saved)" },
		{ "Alt+H", "Unhide everything you hid" },
		{ "I", "Show hidden parts as faint ghosts, or hide them completely again" },
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

	if shift or ctrl then
		return nil
	end

	if axisKeys and (keyName == "X" or keyName == "Y" or keyName == "Z") then
		return `{if alt then "Plane" else "Lock"}:{keyName}`
	end

	if alt then
		return nil
	end

	local tool = TOOL_KEYS[keyName]

	if tool then
		return `Tool:{tool}`
	end

	return PLAIN_KEYS[keyName]
end

return Keymap
