--!strict

--[=[
	What changed in each version, newest first, for the panel's version list. The first entry is
	the version the plugin reports, and a test keeps it equal to `PluginInfo.Version`, so add a new
	entry at the top for every release.

	@class Changelog
]=]

--[=[
	@interface Release
	@within Changelog
	.Version string
	.Date string -- year-month-day
	.Changes { string } -- one short line each
]=]
export type Release = { Version: string, Date: string, Changes: { string } }

local Changelog: { Release } = {
	{
		Version = "1.3.3",
		Date = "2026-10-22",
		Changes = {
			"A doorway with a frame or door cuts through in one click, so the frame is no longer dropped.",
		},
	},
	{
		Version = "1.3.2",
		Date = "2026-10-22",
		Changes = {
			"Working folders must carry the VluxyBT_Map tag; the untagged option is gone.",
			"An untagged folder shows a red notice saying how to tag it, and is picked once tagged.",
		},
	},
	{
		Version = "1.3.1",
		Date = "2026-10-22",
		Changes = {
			"Studio's move, rotate and scale handles play a sound when you let go, even with the panel closed.",
			"Blender-style move, rotate and scale play a sound when confirmed.",
			"Vents and other drawn pieces click on each point and chime when Enter finishes them.",
		},
	},
	{
		Version = "1.3.0",
		Date = "2026-10-22",
		Changes = {
			"Someone idle for over 15 minutes shows a faded face and their idle time.",
			"Click an idle admin's face to take over admin at once.",
		},
	},
	{
		Version = "1.2.0",
		Date = "2026-10-22",
		Changes = {
			"Unity colors parts made with Studio's tools too: flat slabs orange, standing slabs grey.",
			"Dragging, rotating and scaling with Studio's own tools plays a sound.",
			"The folder card's avatars are bigger and sit on its title line.",
		},
	},
	{
		Version = "1.1.0",
		Date = "2026-10-22",
		Changes = {
			"Each working folder has one admin: whoever has worked in it longest, passed on when they leave.",
			"Only the admin changes themes, the surface grid and ghost transparency; others see them greyed.",
			"Hiding is shared: parts the admin hides disappear for everyone, as an undo step.",
			"Give admin to a teammate, or ask the admin for it, from their face on the folder card.",
			"A slimmer Working Folder card: the folder, who is in it, and a change button in one row.",
		},
	},
	{
		Version = "1.0.0",
		Date = "2026-10-22",
		Changes = {
			"First release.",
			"Six color themes: Pastel, Unity, Levels, Structures, Facing and Size; hold P and scroll to switch.",
			"Doors are a standard door and frame by default, with a transparency slider and CanCollide switch.",
			"Arrange has a Blender-style Array with a live preview.",
			"A calmer panel: one-line help, hover descriptions, zebra rows, a UI color and button animations.",
			"Snapping settings live once, under Settings.",
			"Alt+L switches the camera light.",
			"Sounds play only for you, also in Team Create.",
			"Room joins follow structures you move.",
			"Docs site and automated tests.",
		},
	},
	{
		Version = "0.2.0",
		Date = "2026-10-22",
		Changes = {
			"The plugin was rebuilt in modules, with one contract for every tool.",
			"The panel was rebuilt on vide.",
			"Plugin sounds and a sound volume slider.",
			"Click objects in the viewport to add them to the brush.",
			"Props got their own tab.",
		},
	},
	{
		Version = "0.1.0",
		Date = "2026-10-21",
		Changes = {
			"Walls, floors, rooms, corridors, stairs, roofs, railings and vents.",
			"Doorways, windows and archways cut into walls.",
			"Blender hotkeys: grab, rotate, scale, extrude and typed values.",
			"A working folder with the VluxyBT_Map tag.",
			"Pastel and Unity colors, the surface grid and hidden parts.",
		},
	},
}

return Changelog
