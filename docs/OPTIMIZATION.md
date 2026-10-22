# Optimization plan: 80k parts per working folder

Branch `perf/80k-parts`. Goal: a working folder of **80,000 parts** feels the same as a small one.
Most maps will be under 50k, so 80k is the supported maximum with headroom. We test at 80k, and
once at 100k to check nothing falls apart just past the limit.

## The rule

The cost of anything that runs on every click or every frame must not grow with the size of the
folder. Only one-off jobs a user starts on purpose (pastel on, theme change) may touch every part,
and those show their progress.

The recurring problem in the code is "walk everything to find a few things". Each fix below
replaces such a walk with knowing where the few things are: the parts an edit touched, a
CollectionService tag, or a box search near the cursor.

## Budgets at 80k

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
   - `Edit`, and inside it `Adopt`, `Sweep`
   - `Load`, `Pastel`, `Grid`, `Hidden`
2. **Stress place generator**: `tools/StressPlace.luau`, run from the Studio command bar. It fills
   a folder with rooms, corridors, walls, floors, stairs and doorways made by the plugin's own
   builders, to a chosen part count (default 80k). It is not part of the plugin build.
3. **Baseline**: record the numbers for every label at 10k, 50k and 80k in this file before any
   fix, so each phase shows what it changed.

## Phase 1: the sweep after every edit

**Now:** every plugin edit runs `Display.Sweep`. With pastel or the grid on, that walks the whole
working folder twice, `Colors.Sweep` and `SurfaceGrid.Sweep`, and in Unity mode it also runs the
name matching and the shape sizing on every part. Estimated 0.25 to 0.35 s per click at 80k.

**Change:**
- `Services/Edit` already collects the parts an edit adds. It also collects the parts an edit
  changes: a tool reports what it resized or moved through a new `ctx.Touch(part)`, and Move,
  Extend, Arrange and the modal actions call it.
- `Colors.Sweep` and `SurfaceGrid.Sweep` take that list and handle only those parts.
- The whole-folder walk stays only where it is asked for: switching pastel or the grid on, a
  theme change, and an explicit "Recolor folder" pass.

**Risk:** a path that changes a part without reporting it leaves that part with an old color.
Cuts and unions make new parts, which `DescendantAdded` already catches. Covered by testing every
tool with Unity colors on.

## Phase 2: the working folder outline

**Now:** `WorkingFolder.drawBox` walks every part of the selected folder once a second and works
out its bounds. Estimated 0.15 s hitch every second at 80k.

**Change:** compute the bounds once, then mark them stale on `DescendantAdded`,
`DescendantRemoving` and the end of each plugin edit, and recompute at most once a second, only
when stale. A folder nobody touches costs nothing.

## Phase 3: the drawing previews

**Now:** two lookups run on every preview tick and walk every child of the folder:
`Snapper.Doorway` (6 `FindFirstChild` calls on each model) and `Joints.Preview` through
`structures()`. At 80k parts the folder holds roughly 12 to 20 thousand models.

**Change:**
- Builders tag what they make: `VluxyBT_Doorway` on a model with an opening that reaches the
  floor, `VluxyBT_Structure` on rooms and corridors. Both lookups read the tag list instead of the
  folder.
- `Joints.Preview` first skips any structure whose bounds do not touch the bounds of the shape
  being drawn.
- Places built before the tags existed: the first time a folder becomes the working folder, one
  walk tags what it finds, then it never walks again.

## Phase 4: load and switch-off scans

**Now:** at load, `Colors`, `SurfaceGrid` and `Hidden` each walk all of Workspace. Turning pastel
off, and unloading, walk `game:GetDescendants()`, the whole place. Grid off, grid color and grid
size walk all of Workspace.

**Change:** tag the parts the plugin marks (`VluxyBT_Colored`, `VluxyBT_Gridded`, and hidden parts
if they are not tagged yet), and read the tags. Older places without tags get one walk, then
tags from then on. Expected gain: about a quarter second at load and a second or so per switch-off
at 80k. Lowest priority of the four.

## Phase 5: the surface grid (needs a decision)

At 80k parts the grid is about 480,000 Texture instances, six per part. That strains Studio's
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

One branch, a commit per phase, `npm run verify` before each, and a re-measure at 80k after
phases 1, 3 and 6. Phase 0 lands first so every later phase has numbers. One PR at the end, with the
before and after table filled in.

## Results

| Label | 10k before | 80k before | 80k after |
|---|---|---|---|
| (filled in during phase 0 and at the end) | | | |
