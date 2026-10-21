--!strict

--[=[
	The Blender-style hotkeys. `Resolve` turns a key press into an action name; the plugin decides
	what the action does. Ctrl and Alt are never taken, so Studio's own shortcuts keep working.

	@class Keymap
]=]

export type Action = string

local TOOL_KEYS: { [string]: string } = {
	One = "Wall",
	Two = "Corridor",
	Three = "Room",
	Four = "Block",
	Five = "Stairs",
	Six = "Ramp",
	Seven = "Arch",
	Eight = "Opening",
	Nine = "Place",
	Zero = "Measure",
}

local PLAIN_KEYS: { [string]: Action } = {
	E = "Extrude",
	G = "Grab",
	R = "Rotate",
	S = "Scale",
	Escape = "Cancel",
	Return = "Confirm",
	KeypadEnter = "Confirm",
	RightBracket = "HeightUp",
	LeftBracket = "HeightDown",
	Tab = "NextTab",
	F1 = "ShowHotkeys",
	P = "TogglePastel",
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
		{ "1 … 9, 0", "Pick a tool: Wall, Corridor, Room, Block, Stairs, Ramp, Arch, Door, Stamp, Measure" },
		{ "E", "Extrude the face under the cursor of the selected block" },
		{ "G / R / S", "Grab, rotate or scale the selection" },
		{ "Shift+D", "Duplicate the selection and grab the copy" },
		{ "X / Y / Z", "While drawing or in a modal action: lock to that world axis. Press again to unlock" },
		{ "Shift+X / Y / Z", "Lock to the plane the axis is perpendicular to" },
		{ "0-9 and .", "While drawing or in a modal action: type an exact length, angle or factor" },
		{ "Enter / click", "Confirm" },
		{ "Esc / right-click", "Cancel the action, or stop the tool" },
		{ "[ and ]", "Lower or raise the active height by one snap step" },
		{ "Tab / Shift+Tab", "Next or previous panel tab" },
		{ "F1", "Open this Hotkeys tab" },
		{ "P", "Pastel colors on or off" },
		{ "Shift+P", "Surface grid on or off" },
		{ "N", "Show or hide the panel" },
		{ "Ctrl+M, then X / Y / Z", "Flip (mirror) the selection in place across that axis" },
		{
			"Shift+R, then X / Y / Z",
			"Rotate the selection 90 degrees about that axis. Hold Shift on the axis key for -90",
		},
		{ "Arrow keys in Rotate", "While rotating with R, step the angle by 90 degrees" },
		{ "H", "Hide the selected parts (local to you, nothing is saved)" },
		{ "Alt+H", "Unhide everything you hid" },
		{ "Shift+H", "Show hidden parts as faint ghosts, or hide them completely again" },
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
	if alt and not ctrl and not shift and keyName == "H" then
		return "Unhide"
	end

	if ctrl and not alt and not shift and keyName == "M" then
		return "FlipArm"
	end

	if ctrl or alt then
		return nil
	end

	if axisKeys and (keyName == "X" or keyName == "Y" or keyName == "Z") then
		return `{if shift then "Plane" else "Lock"}:{keyName}`
	end

	if shift then
		if keyName == "D" then
			return "Duplicate"
		elseif keyName == "P" then
			return "ToggleGrid"
		elseif keyName == "Tab" then
			return "PrevTab"
		elseif keyName == "R" then
			return "Rotate90Arm"
		elseif keyName == "H" then
			return "ToggleHiddenView"
		end

		return nil
	end

	local tool = TOOL_KEYS[keyName]

	if tool then
		return `Tool:{tool}`
	end

	return PLAIN_KEYS[keyName]
end

return Keymap
