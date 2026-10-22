# Optimization plan: 100k parts per working folder

Branch `perf/100k-parts`. Goal: a working folder of **100,000 parts** feels the same as a small one.
Most maps will be under 50k, so 100k is the target with headroom, and it is what we test at.

## The rule

The cost of anything that runs on every click or every frame must not grow with the size of the
folder. Only one-off jobs a user starts on purpose (pastel on, theme change) may touch every part,
and those show their progress.

The recurring problem in the code is "walk everything to find a few things". Each fix below
replaces such a walk with knowing where the few things are: the parts an edit touched, a
CollectionService tag, or a box search near the cursor.

## Budgets at 100k

| What | Budget |
|---|---|
| Preview tick (20 times a second) | under 2 ms |
| A plugin edit, sweep included | under 16 ms beyond the build itself |
| Steady state with nothing happening | under 0.5 ms a frame |
| Plugin load | under 250 ms |
| One-off full-folder jobs | may take seconds, never freeze without a progress message |

## Phase 0: measure (permanent)

1. **Profiler labels**, kept in the code for good. `debug.profilebegin` and `debug.profileend`
   cost next to nothing while the MicroProfiler (Ctrl+F6) is not recording, and they let anyone
   name a slow spot later. One small helper, `Core/Profile.luau`, wraps a function in a label so a
   missed `profileend` cannot happen. Labels, all prefixed `VluxyBT/`:
   - `Heartbeat`, and inside it `Preview`, `Modal`, `Folder`
   - `Edit` (the change itself), then `Sweep` after it
   - `Load`, `Pastel` (on, off, theme change), `Grid` (on, off)
2. **Stress place generator**: `Commands/StressPlace.luau`, run from the Studio command bar. It fills
   a folder with rooms, corridors, walls, floors, stairs and doorways made by the plugin's own
   builders, to a chosen part count (default 100k). It is not part of the plugin build.
3. **Baseline**: record the numbers for every label at 10k, 50k and 100k in this file before any
   fix, so each phase shows what it changed.

## Phase 1: the sweep after every edit

**Now:** every plugin edit runs `Display.Sweep`. With pastel or the grid on, that walks the whole
working folder twice, `Colors.Sweep` and `SurfaceGrid.Sweep`, and in Unity mode it also runs the
name matching and the shape sizing on every part. Estimated 0.3 to 0.4 s per click at 100k.

**Change (done):**
- `Services/Edit` already collected the parts an edit adds. It now hands that list to
  `Display.Sweep`, and `Colors.Sweep` and `SurfaceGrid.Sweep` handle only those parts. The
  separate `Adopt` pass is gone, since the sweep of the added parts does the same work.
- No edit resizes or renames a part it did not add: cuts, unions, extrusions and copies all make
  new parts. Move, rotate and scale (`Modal/Move`) record their own undo step and never swept, so
  nothing changes for them.
- The whole-folder walk stays only where it is asked for: picking a working folder, and switching
  pastel or the grid on, or changing the theme.

**Behavior change:** before, any plugin edit also repainted parts changed by Studio's own tools
since the last edit, as a side effect. Now those keep their color until the folder is picked
again or pastel is switched off and on.

## Phase 2: the working folder outline

**Now:** `WorkingFolder.drawBox` walks every part of the selected folder once a second and works
out its bounds. Estimated 0.2 s hitch every second at 100k.

**Change (done):** `Core/BoundsScan` measures an outlined folder a little at a time: each frame it
walks the folder for a set time (4 ms until the first box shows, then 0.3 ms) and picks up where it
stopped; each finished walk publishes the box and starts the next one. The outline is redrawn
only when the box changed. So a small folder updates every frame, a 100k folder every second or
two, it follows parts moved with Studio's own tools, and no frame stalls. `Geometry.Bounds` also
works out each part's box from its rotation instead of eight corners, about eight times less math.

## Phase 3: the drawing previews

**Now:** two lookups run on every preview tick and walk every child of the folder:
`Snapper.Doorway` (6 `FindFirstChild` calls on each model) and `Joints.Preview` through
`structures()`. At 100k parts the folder holds roughly 15 to 25 thousand models.

**Change (done):** no tags after all. Both lookups ask Roblox's physics index
(`GetPartBoundsInBox`) for the parts near the space in question, so nothing has to be kept up to
date and older places need no migration.
- `Joints`: the room-join preview and `Joints.Connect` search around the new structure and its
  clear space, plus 4 studs (more than any wall is thick). Stacking (`stackOver`) searches only
  the footprint of the new floor.
- `Snapper.Doorway`: searches a column around the cursor, the snap radius plus 16 studs wide, for
  the sides or header of an opening.

**Behavior changes:**
- *Probable bug fix:* stacking a room with Shared or Open used to cut the ceiling of *every*
  structure in the folder whose top sat at the new floor's height, even far away. Now only the
  ones under the new floor. Needs a Studio check.
- A doorway wider than about 32 studs with no header, snapped from near its middle, may no
  longer be found. Doors that wide are unusual.

## Phase 4: load and switch-off scans

**Now:** at load, `Colors`, `SurfaceGrid` and `Hidden` each walk all of Workspace. Turning pastel
off, and unloading, walk `game:GetDescendants()`, the whole place. Grid off, grid color and grid
size walk all of Workspace.

**Change:** tag the parts the plugin marks (`VluxyBT_Colored`, `VluxyBT_Gridded`, and hidden parts
if they are not tagged yet), and read the tags. Older places without tags get one walk, then
tags from then on. Expected gain: about a quarter second at load and a second or so per switch-off
at 100k. Lowest priority of the four.

## Phase 5: the surface grid (needs a decision)

At 100k parts the grid is about 600,000 Texture instances, six per part. That strains Studio's
memory and rendering whatever our code does. Options:

| Option | Effect |
|---|---|
| **Fewer faces** (recommended, with the warning) | Only floor and stair tops and the two wide sides of walls, using `Pure/PartRole`. About a third of the textures, same look where it is used. |
| **Warn above a part count** (recommended, with fewer faces) | Above about 20k parts, ask before applying. |
| **Leave it** | Current behavior; heavy on big folders. |

**Open:** pick one or both before this phase starts.

## Phase 6: one-off jobs stay responsive

Pastel on, theme change and grid on over a whole folder are one undo step each and stay that way.
Their work moves into chunks of a few thousand parts with a `task.wait()` between, and the status
bar shows "Coloring... 40%". The undo recording stays open across the chunks and the tools stay
stopped until it ends.

**Actors:** only if a one-off job still takes several seconds after this. Parallel Luau can decide
each part's color in parallel; the writes stay serial. First check that Actors actually run in
parallel for a plugin saved from ServerStorage.

## Not planned

- `--!native`: the time goes into Roblox API calls, which native code does not speed up.
- `--!optimize 2`: small gain from inlining, no effect on any of the problems above. It can be
  added to `Pure/Polygon` and `Core/Snapper` later at no risk.
- Anything that only touches the selection or the area under the cursor: hidden-part count,
  Brush, Arrange, Move, Extend, Measure, Openings. Folder size does not change their cost.

## Order and landing

One branch, a commit per phase, `npm run verify` before each, and a re-measure at 100k after
phases 1, 3 and 6. Phase 0 lands first so every later phase has numbers. One PR at the end, with the
before and after table filled in.

## Results

| Label | 10k before | 100k before | 100k after |
|---|---|---|---|
| (filled in during phase 0 and at the end) | | | |
