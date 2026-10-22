--!strict

--[=[
	The Blender-style hotkeys. `Resolve` turns a key press into an action name; the plugin decides
	what the action does. Ctrl is only used for Ctrl+M and the Ctrl+number tool picks, and Alt for Alt+H, Alt+L, the plane locks and the
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
	@type Binding { Keys: { string }, Meaning: string }
	@within Keymap

	One row of the Hotkeys tab. `Keys` are shown in order as key chips, except the joining words
	that `IsJoiner` picks out.
]=]
export type Binding = { Keys: { string }, Meaning: string }

--[=[
	@type Section { Title: string, Bindings: { Binding } }
	@within Keymap
]=]
export type Section = { Title: string, Bindings: { Binding } }

local JOINERS: { [string]: boolean } = {
	["+"] = true,
	["/"] = true,
	["then"] = true,
	["hold"] = true,
}

--[=[
	@param token string -- one entry of a binding's `Keys`
	@return boolean -- true for the words between keys, such as "+" and "then", which are not keys
]=]
function Keymap.IsJoiner(token: string): boolean
	return JOINERS[token] == true
end

--[=[
	Every binding with a short meaning, grouped into the cards of the Hotkeys tab.

	@return { Section }
]=]
function Keymap.Sections(): { Section }
	return {
		{
			Title = "TOOLS",
			Bindings = {
				{ Keys = { "Ctrl", "+", "1–7", "/", "0" }, Meaning = "Pick a tool; again to stop" },
				{ Keys = { "Alt", "+", "1–0" }, Meaning = "Pick a tool option" },
				{ Keys = { "Ctrl", "+", "Scroll" }, Meaning = "Previous or next tool or prop section" },
				{ Keys = { "Alt", "+", "Scroll" }, Meaning = "Previous or next option" },
			},
		},
		{
			Title = "DRAWING",
			Bindings = {
				{ Keys = { "hold", "Shift" }, Meaning = "Snap to the fine grid" },
				{ Keys = { "X", "/", "Y", "/", "Z" }, Meaning = "Lock to an axis; again to unlock" },
				{ Keys = { "Alt", "+", "X", "/", "Y", "/", "Z" }, Meaning = "Lock to the plane across it" },
				{ Keys = { "0–9", "." }, Meaning = "Type an exact amount" },
				{ Keys = { "[", "]" }, Meaning = "Lower or raise the height" },
				{ Keys = { "Enter", "/", "Click" }, Meaning = "Confirm" },
				{ Keys = { "Esc", "/", "Right-click" }, Meaning = "Cancel, or stop the tool" },
			},
		},
		{
			Title = "MOVE & EDIT",
			Bindings = {
				{ Keys = { "G" }, Meaning = "Grab the selection" },
				{ Keys = { "R" }, Meaning = "Rotate the selection" },
				{ Keys = { "C" }, Meaning = "Scale the selection" },
				{ Keys = { "Arrows" }, Meaning = "Turn 90° while rotating" },
				{ Keys = { "V" }, Meaning = "Duplicate and grab" },
				{ Keys = { "T" }, Meaning = "Extrude the face under the cursor" },
				{ Keys = { "Ctrl", "+", "M", "then", "X/Y/Z" }, Meaning = "Mirror on that axis" },
				{ Keys = { "O", "then", "X/Y/Z" }, Meaning = "Turn 90°; Alt for -90°" },
			},
		},
		{
			Title = "SHOW & HIDE",
			Bindings = {
				{ Keys = { "H" }, Meaning = "Hide selected parts, just for you" },
				{ Keys = { "Alt", "+", "H" }, Meaning = "Unhide everything" },
				{ Keys = { "I" }, Meaning = "Hidden parts as ghosts on or off" },
				{ Keys = { "P" }, Meaning = "Themes on or off" },
				{ Keys = { "hold", "P", "+", "Scroll" }, Meaning = "Switch the theme" },
				{ Keys = { "L" }, Meaning = "Surface grid on or off" },
				{ Keys = { "Alt", "+", "L" }, Meaning = "Camera light on or off" },
			},
		},
		{
			Title = "PANEL",
			Bindings = {
				{ Keys = { "N" }, Meaning = "Show or hide the panel" },
				{ Keys = { "Tab", "/", "`" }, Meaning = "Next or previous tab" },
				{ Keys = { "F1" }, Meaning = "Open this tab" },
				{ Keys = { "W A S D Q E F" }, Meaning = "Left to Studio's camera" },
			},
		},
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

	if alt and not ctrl and not shift and keyName == "L" then
		return "ToggleCameraLight"
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
