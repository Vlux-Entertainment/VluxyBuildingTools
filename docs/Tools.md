---
sidebar_position: 4
---

# Tools

The **Build** tab shows a grid of tool tiles. Most tiles hold several tools; pick one from the
buttons under the grid, or press **Alt+1** to **Alt+0**. A tile starts the tool you used last.

Under the buttons are the options for the tool that is on. Some tools have more under
**Advanced options**. Hover any option to see what it does. Right-click a number to put it back to
its default.

Every tool needs a [working folder](GettingStarted#1-make-a-working-folder), and every build is one
undo step.

## Drawing basics

These work in every drawing tool:

| Do this | To |
|---|---|
| Click | Place a point, or build. |
| Hold **Shift** | Snap to the fine grid. |
| **X**, **Y**, **Z** | Lock to an axis. **Alt** with it locks to the plane across that axis. |
| Type `0`–`9` and `.` | Set an exact length. |
| **[** and **]** | Lower or raise the height by one grid step. |
| **Enter** | Start a new chain, or finish. |
| **Esc** or right-click | Drop the current point; again to stop the tool. |

Points also snap to the corners and edges of nearby parts (see [Settings](Settings#snapping)).

## Basic (Ctrl+1)

Walls, floors, blocks, pillars and arches.

| Tool | How to use it |
|---|---|
| **Walls** | Click points; Enter starts a new chain. Y drags the height. |
| **Pillared Wall** | Like Walls, with a pillar at each end. |
| **Floor** | Click two corners. The top of the floor is level with what you click. |
| **Block** | Click two corners, then press Y to drag it up. |
| **Pillar** | Click to place a square pillar. |
| **Arch** | Click the two inner edges at ground level. |

Options: **Height**, **Thickness**, **Pillar width**, the floor's **Transparency**, and for the arch
**Clear height** and **Frame depth**. Advanced: **Floor / ceiling thickness** and **Arch smoothness**.

## Stairs (Ctrl+2)

| Tool | How to use it |
|---|---|
| **Stairs** | Click the bottom step, then the end of the run. **Center**, **Left** or **Right** picks which line of the stairs the clicks mark, so you can snap them along the side of a wall. |
| **Ramp** | Click the bottom, then the top. **Center**, **Left** or **Right** works as for stairs. |

Options: **Clear width**, **Total stair rise** or **Ramp rise**. Advanced: **Approx. step depth**
and **Top landing depth**.

## Additive (Ctrl+3)

Cut openings into walls, or grow blocks.

| Tool | How to use it |
|---|---|
| **Doorway** | Click a plain wall. |
| **Window** | Click a plain wall. |
| **Circle Window** | Click a plain wall. |
| **Triangle Window** | Click a plain wall. |
| **Archway** | Click a plain wall. |
| **Cut Shape** | Click corners on a wall; click the first corner again or press Enter to cut. |
| **Vent Hole** | Click a wall, floor or vent. |
| **Face Extend** | Select a block, then drag a green handle outward. The new block gets handles too. |

Openings are centred on the cursor. With **Set cut depth with mouse** on (the default), the first
click fixes the spot and the mouse sets how deep the cut goes; past the far side it cuts all the
way through. Turn it off to cut through in one click.

Options:

- **Doorway**: width and height, **Door frame**, **Door** (a see-through panel), **Door transparency**
  and **Door CanCollide**. Advanced: frame width and depth, door thickness.
- **Windows**: width, height and **Bottom above floor**.
- **Archway**: width and height. Advanced: **Arch smoothness**.
- **Vent Hole**: **Vent inside size**, and **Inside** or **Outside**: cut the vent's inside size, or its outside size so a vent fits through. Advanced: **Vent sheet thickness**.

## Structures (Ctrl+4)

Rooms, corridors, foundations, porches and roofs.

| Tool | How to use it |
|---|---|
| **Room** | Click two corners. A floor and four walls. |
| **Corridor** | Click a start and an end; keep clicking to chain. |
| **Arched Corridor** | Like Corridor, with an arched ceiling. |
| **Foundation** | Click two corners. A thick slab under a building. |
| **Porch** | Click two corners. A floor with posts and a railing. |
| **Roof** | Click two corners over the top of the walls. |

Options:

- **Room**: **Open**, **Shared** or **Separate** for rooms that touch (no wall between them, one
  shared wall, or both walls).
- **Room** and **Corridor**: **Ceiling** adds a ceiling.
- Rooms and corridors: **Join rooms and corridors** cuts openings where they meet.
- **Height**, **Thickness** and **Clear width** as they apply.
- **Foundation**: **Slab height** and **Margin around**.
- **Porch**: **Post spacing**, **Railing** on or off, **Railing height**.
- **Roof**: **Gable**, **Hip**, **Shed**, **Pyramid** or **Flat**, **Roof rise** and **Overhang**.
  Advanced: **Roof sheet thickness**.

## Vents (Ctrl+5)

Square ducts and their end pieces.

| Tool | How to use it |
|---|---|
| **Vent** | Click points; Enter starts a new chain. Turns at right angles. |
| **Slope Vent** | Click the start and end, then move up or down and click. Pointing at a vent, or a vent hole, at another height instead builds the slope to it with the second click. Starting on a vent hole runs the slope straight out of it. |
| **Shaft Vent** | Click a surface, then move up or down and click. |
| **Vent Cover** | Click a vent opening or any surface. Places a grate. |
| **End Cap** | Click a vent opening or any surface. Closes it with a plate. |
| **Fan End** | Click a vent opening. Closes it with a fan. |
| **Peek Cover** | Click a wall or vent opening. A small cover to look out of. |

Options: **Vent inside size** (the clear space inside, 3.5 by default; the sheets go outside it). Advanced: **Vent sheet thickness**.

## Railings (Ctrl+6)

| Tool | How to use it |
|---|---|
| **Railing** | Click points; Enter starts a new chain. On stairs it snaps to the lip of each step on the side edge, and has no bottom rail; its posts stay just inside edges and corners. |
| **Half Wall** | Click points. A low solid wall. |
| **Fence** | Click points. Posts and rails. |

Options: **Railing height**, **Bar spacing**, **Fence height** and **Post spacing**.

## Brush (Ctrl+7)

Paints copies of objects onto surfaces.

1. Select an object and click **Add selected to brushes**. (Or Ctrl+click an object with the brush on.)
2. Click or drag over surfaces. A drag is one undo step.

Each brush in the list can be switched on or off, or removed with ✕. The brush picks one of the
brushes that are on at random for every copy. With no brushes, it paints the selection.

Options: **Copy rotation**, **Brush radius**, **Brush spacing**, **Random rotation**. Advanced:
**Smallest size** and **Biggest size**, **Surface gap**, **Tilt copy to surface**.

## Props

The **Props** tab holds ready-made props, in sections (**All**, Bathroom, Bedroom, Kitchen and more).
Pick one, then click a floor or wall. Floor props stand on the surface; wall props hang flat on it.
Press **R** to turn the prop 90°. **Ctrl+scroll** steps through the sections.

Options: **Rotation**, **Prop size**, **Randomize prop rotation** with how far (in degrees), and
**Collapse props after picking one**.

## Measure (Ctrl+0)

Click two points to see the distance between them. The label stays until Esc or the next measurement.

## Extrude (T)

Point at a face of a plain block and press **T**. The mouse pulls the face out into a new block;
type a number for an exact length. Click or press Enter to build it, Esc to cancel. With one block
selected and nothing under the cursor, T uses the face that looks most toward the camera.

## Grab, rotate and scale (G, R, C)

Select parts, then press:

| Key | Action |
|---|---|
| **G** | Grab: move the selection. |
| **R** | Rotate. The arrow keys turn it 90°. |
| **C** | Scale. |
| **V** | Duplicate, then grab the copy. |

The selection follows the mouse. **X**, **Y** or **Z** locks an axis, **Alt** with it a plane, and a
typed number sets an exact value. Click or Enter confirms; Esc puts everything back.

Two quick one-key actions:

- **Ctrl+M**, then **X**, **Y** or **Z**: mirror the selection on that axis.
- **O**, then **X**, **Y** or **Z**: turn it 90°. Hold Alt for -90°.
