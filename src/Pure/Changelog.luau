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
		Version = "1.6.2",
		Date = "2026-10-24",
		Changes = {
			"Walls join like Bloxburg: points snap to other walls' ends, middles and middle lines; starting or ending on a wall's end closes the corner with no gap or overlap, and on its side the walls meet flush.",
			"Hold Shift to build a wall on top of another wall.",
		},
	},
	{
		Version = "1.6.1",
		Date = "2026-10-24",
		Changes = {
			"Drawing tools snap to every corner of floors and walls and to the middle of each side and edge, as well as the ends and middle of a wall top.",
			"Railing points snap to the middle of a floor's side too.",
		},
	},
	{
		Version = "1.6.0",
		Date = "2026-10-24",
		Changes = {
			"Railing points on the floor around stairs line up with the stair railing, the stairwell's sides and its ends, even when the floor is one big part.",
			"Railing: click a big post to start a new chain from it, or end on one; no second post is built there.",
		},
	},
	{
		Version = "1.5.9",
		Date = "2026-10-24",
		Changes = {
			"Railing posts keep a small gap from the edge of floors and stairs instead of lining up with it.",
			"Railing points on a floor snap onto a line just inside each edge, and onto its corners.",
		},
	},
	{
		Version = "1.5.8",
		Date = "2026-10-24",
		Changes = {
			"Railing on stairs: the board rises only as far above the step edges as the flat bottom rail does above the floor, so the two match.",
		},
	},
	{
		Version = "1.5.7",
		Date = "2026-10-24",
		Changes = {
			"Stairs and Ramp: Full or Slope underside. Slope builds a sloped slab under the steps, 1.5 thick by default, measured square to the slope from the steps' inner corners.",
		},
	},
	{
		Version = "1.5.6",
		Date = "2026-10-24",
		Changes = {
			"Railing on stairs: the bottom rail is back as a tall board over the step edges that reaches into the steps, with the bars standing on it.",
			"Railings, half walls and fences: a point that nearly continues the last section, or nearly turns square from it, lines up exactly, so a railing runs on from the stairs and wraps around the opening.",
		},
	},
	{
		Version = "1.5.5",
		Date = "2026-10-24",
		Changes = {
			"Railing on stairs and ramps: no bottom rail, and the bars reach down to the steps.",
			"Railing on the flat: the bottom rail lies on the floor.",
			"Railing points on stairs snap to the lip of each step, on the side edge, also on stairs that were joined into one part.",
		},
	},
	{
		Version = "1.5.4",
		Date = "2026-10-24",
		Changes = {
			"Stairs and Ramp: Center, Left or Right picks which line of the stairs your clicks mark, to snap them along the side of a wall.",
			"Vent covers, caps and fans snap onto vent holes, including holes cut into a vent.",
		},
	},
	{
		Version = "1.5.3",
		Date = "2026-10-24",
		Changes = {
			"Vent corners are found again after turning a vent off the end of another: a vent's recorded ends no longer drift when a corner stretches its sheets.",
		},
	},
	{
		Version = "1.5.2",
		Date = "2026-10-24",
		Changes = {
			"Extending a vent from a corner works from anywhere on the corner block: the new vent starts on the face under the cursor, centred on the corner.",
			"Floor: the top of the floor is level with what you click, not a floor thickness above it.",
		},
	},
	{
		Version = "1.5.1",
		Date = "2026-10-24",
		Changes = {
			"A vent started on the side or corner of another vent starts on the face under the cursor and leaves through it.",
			"Railing, half wall and fence posts sit just inside the edges and corners of what they stand on.",
			"A floor started on a floor already built stays level with it instead of a floor thickness above.",
		},
	},
	{
		Version = "1.5.0",
		Date = "2026-10-24",
		Changes = {
			"A corner made at the end a vent was started from is closed; the old vent grows over the corner instead of away from it.",
			"A vent continued from another, or started on its corner, takes that vent's size, so the joint lines up.",
			"A vent drawn toward another stops flush at the first vent in its way, including the corner square of an L.",
			"A branch off the side of a vent of another size starts flush at its side.",
		},
	},
	{
		Version = "1.4.9",
		Date = "2026-10-24",
		Changes = {
			"Slope Vent built down from a high opening to a low one stops flush at the low opening, the same as building it upward.",
		},
	},
	{
		Version = "1.4.8",
		Date = "2026-10-24",
		Changes = {
			"Vent ends follow a vent that is moved, turned or copied, so both ends stay usable.",
			"Aiming into either opening of a vent snaps to it from any angle, also through a wall hole.",
		},
	},
	{
		Version = "1.4.7",
		Date = "2026-10-24",
		Changes = {
			"Slope Vent only starts head on: on an open vent end, a vent hole, or a plain wall or floor, never on the side or top of a vent.",
		},
	},
	{
		Version = "1.4.6",
		Date = "2026-10-24",
		Changes = {
			"Vent holes are remembered on their wall: vents and slope vents can start from a hole and go straight out of it.",
			"Slope Vent: click one vent hole, then another at a different height, and the slope joins them.",
		},
	},
	{
		Version = "1.4.5",
		Date = "2026-10-24",
		Changes = {
			"Vent sheets are 0.25 thick by default, so a default vent is 4 by 4 outside; a thickness left at 0.2 moves to 0.25.",
		},
	},
	{
		Version = "1.4.4",
		Date = "2026-10-24",
		Changes = {
			"Vents are 3.5 studs inside by default; a vent size left at the old default of 3 moves to 3.5.",
		},
	},
	{
		Version = "1.4.3",
		Date = "2026-10-24",
		Changes = {
			"Slope Vent: point at a vent at another height and the slope rises or drops to meet it in one click.",
			"Vents can start on a corner of another vent and leave through any open face of it.",
			"No gap where a vent continues a slope vent, or a slope continues a vent.",
		},
	},
	{
		Version = "1.4.2",
		Date = "2026-10-24",
		Changes = {
			"Vents show an outline with a cross where the duct will start, in place of the red dots.",
			"A vent started on an open vent end turns its corner cleanly, like a chained section.",
			"A vent started on the side of another vent always leaves it at a right angle, never running inside it.",
			"A vent that would run into another vent is not built, and says why.",
			"Joining a vent to a sloped vent no longer cuts a hole in the slope.",
			"Covers on sloped vents sit upright, and end caps sit flush on the vent instead of floating.",
			"Railings snap to the side edge and middle of each stair step.",
		},
	},
	{
		Version = "1.4.1",
		Date = "2026-10-24",
		Changes = {
			"Holes cut by vent holes, vents, openings and Cut Shape can be walked through: cuts use precise collision.",
		},
	},
	{
		Version = "1.4.0",
		Date = "2026-10-24",
		Changes = {
			"Vent size is now the inside of the vent: a 3 vent has 3 studs of clear space, with the sheets outside it.",
			"Vent Hole has an Inside or Outside choice: the vent's inside size, or its outside size so a vent fits through.",
		},
	},
	{
		Version = "1.3.5",
		Date = "2026-10-22",
		Changes = {
			"Peek covers, vent pieces, vent holes and wall props snap on turned walls and vents too.",
			"Measure and the brush's first copy snap to Grid Snap, or Precise Grid Snap with Shift.",
		},
	},
	{
		Version = "1.3.4",
		Date = "2026-10-22",
		Changes = {
			"Vents, vent pieces, vent holes, props and cut depth snap to Grid Snap, and Precise Grid Snap with Shift.",
			"Holding Shift also turns off the vent snaps to heights and vent ends, as it does for part snapping.",
		},
	},
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
