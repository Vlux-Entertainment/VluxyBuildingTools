---
sidebar_position: 20
title: Architecture
---

# Architecture

How VluxyBuildingTools fits together, and where to look when something breaks. Every module also
has a Moonwave header comment saying what it is for; start there once you know which file to open.

## The layers

Each layer only requires the layers below it.

```
Plugin.server.luau      entry: toolbar buttons, dock widget, starts the app
App/                    composition root, user actions, raw input
Ui/                     the panel (vide): Panel shell, Controls, one file per tab in Pages/
Tools/  Modal/          the active tool, and the modal actions (extrude, grab/rotate/scale)
Services/  State/       shared state and services the tools and panel use
Core/                   Roblox-facing libraries: geometry, builders, cutting, overlay, colors
Pure/                   plain data and maths, no Roblox API, tested under Lune
```

| Folder | What lives there |
|---|---|
| `App/App.luau` | Creates every service and wires them together. The one place that does. Read it first. |
| `App/Actions.luau` | Every user intent (Esc, Enter, X/Y/Z, H, tab changes, scroll stepping…). Hotkeys and panel buttons both call these. |
| `App/Input.luau` | Raw input → actions: key presses through `Pure/Keymap`, typed digits, clicks, the wheel. |
| `State/Store.luau` | The settings. Tools read `store.Values` freely; all writes go through `Store.Set`/`Mutate`. |
| `State/AppState.luau` | vide sources for what the panel shows: active mode, working folder, status line, tab… |
| `Services/` | `Cursor` (mouse ray, snapping), `Edit` (undo recording), `Status` (messages), `Display` (pastel, grid, hidden parts), `WorkingFolder`, `CameraLight`, `Admin` (who works in the folder, and its admin). |
| `Tools/` | One module per tool family behind the contract in `Tools/Types.luau`; `Runner` runs the active one; `Registry` lists them. |
| `Tools/Draw/` | The 19 point-to-point tools: `Engine` (the shared drawing flow) and one small file per family of shapes. |
| `Modal/` | Extrude (T) and Move (G, R, C, D) behind `Modal/Types.luau`; `Host` runs the active one and the armed flip/rotate. |
| `Ui/` | `Panel` (shell), `Controls` (number field, switch, slider, choice row…), `Popups` (tooltip, reset menu), `Pages/`. |
| `Core/` | `Builders/` (what each shape is made of, one file per family: Paths, Areas, Railings, Slopes, Openings, Vents, Place, with shared `Shapes`), `Geometry` (specs → parts, unions), `Joints` (cutting holes), `Overlay` (viewport drawing), `Colors`, `SurfaceGrid`, `Snapper`, `VentHoles` (remembered vent holes), `Transform`, `Arrange`, `Hidden`, `Brushes`, `Sounds`, `Props`. |
| `Pure/` | `Settings`, `Keymap`, `Tools` (labels, glyphs, instructions, tiles), `PropData`, `AxisLock`, `NumericInput`, `Polygon`, `Snap`, `Cycle`, `Tips`, `SoundIds`, `AdminRules`. |

## How a frame flows

```
Heartbeat ─► Modal/Host.Step            (an active extrude or grab follows the mouse)
          ─► WorkingFolder.Step         (folder outlines, deleted-folder check)
          ─► every 0.05 s: Runner.Step ─► tool.Preview(ctx, state) ─► Overlay draws ghosts,
                                                                      cut, snap mark, holes
Mouse click ─► Input ─► WorkingFolder.Click (while picking)
                     ─► Host.Confirm        (while a modal action runs)
                     ─► Runner.Click ─► fresh Preview ─► tool.Click ─► ctx.Edit(...) builds
Key press ─► Input ─► typed digit? into Host/Runner numeric entry
                   ─► Keymap.Resolve ─► Actions.Perform
```

Every change to the place goes through `ctx.Edit(name, fn)` (`Services/Edit`), which makes it one
undo step, cancels it cleanly on error and hands new parts to pastel colors and the surface grid.

## The tool contract

A tool (see `Tools/Types.luau`) is a table of functions plus a state table it makes in `Begin`.
All of a tool's state lives in that table, so leaving or resetting a tool drops it, and nothing
one tool does can leak into the next. The runner is the only caller.

| Function | When | Rule |
|---|---|---|
| `Begin(ctx)` | the tool is picked | return the fresh state |
| `Preview(ctx, state)` | ~20 times a second | read the mouse, return what to draw; never change the place |
| `Click(ctx, state, preview)` | left click | change the place only through `ctx.Edit` |
| `Back(ctx, state)` | Esc | undo one step and return a message, or nil to leave the tool |
| `Confirm`, `Lock`, `Typing`, `Release`, `Refresh`, `Busy`, `Finish` | optional | see the type's doc comment |

### Adding a tool

1. Write `Tools/MyTool.luau` returning `{ tool }` (or add a shape to a `Tools/Draw/` file; a draw
   shape only needs `Id`, `Start` and `Build`).
2. Add it to `FAMILIES` in `Tools/Registry.luau`.
3. Add its label, glyph and description to `Tools.List` and its instruction to
   `Tools.Instructions` in `Pure/Tools.luau`, and put its id in a tile of `Tools.Grid`. The Lune
   tests fail if one of these is missing.
4. Add its option rows to `Ui/Pages/Build.luau`, each with the modes it belongs to.

### Adding a setting

1. Add the field and its default to `Pure/Settings.luau` (`Settings` type and `Defaults`).
2. Show it with `Controls.Number`/`Switch`/`Choice` using its `Key`; the control reads and writes
   the Store, saves, and offers a right-click reset to the default.
3. If changing it must restyle something already in the map, add a `Store.Watch` in
   `Services/Display.luau`. Never special-case it in the panel.

## Where to look when something breaks

| Symptom | Start in |
|---|---|
| A tool's preview or build is wrong | its file under `Tools/` (find it in `Tools/Registry`); for a draw tool, its shape in `Tools/Draw/`, then `Engine` |
| What a shape is made of (sizes, pieces) | its family in `Core/Builders/` |
| A cut or hole is wrong, or rooms do not join | `Core/Joints.luau` |
| A point snaps to the wrong place | `Tools/Draw/Points.luau`, `Services/Cursor.luau`, `Core/Snapper.luau` |
| A key does the wrong thing | `Pure/Keymap.luau` (which action), `App/Input.luau` (when it is ignored), `App/Actions.luau` (what it does) |
| Esc / Enter misbehave | `Actions.Cancel` / `Actions.Confirm`, then the tool's `Back` / `Confirm` |
| A panel row shows at the wrong time | its `Visible` in `Ui/Pages/*.luau` |
| A panel value is stale | it is not reading `Store.Get` / an `AppState` source reactively, or something wrote around the Store |
| Pastel colors, surface grid, hidden parts | `Services/Display.luau`, then `Core/Colors`, `Core/SurfaceGrid`, `Core/Hidden` |
| Working folder, tags, shared settings | `Services/WorkingFolder.luau` |
| Who is admin, a control greyed for someone | `Services/Admin.luau`, then `Pure/AdminRules.luau` |
| Undo is wrong or an edit is half-applied | `Services/Edit.luau` and the `ctx.Edit` call in the tool |
| Something leaks after reloading the plugin | a connection not given to a trove or `vide.cleanup` |

## Rules that keep it this way

- **Settings are written only through the Store.** Assigning into `store.Values` directly leaves
  the panel stale and skips saving.
- **Services are created only in `App/App.luau`.** Pass what a module needs in its `Deps`.
- **A tool keeps its state in its state table**, never in module-level locals.
- **The panel holds no logic.** It shows `AppState` and the Store and calls `App/Actions` or a
  service. Anything worth testing goes in `Pure/`.
- **Connections are cleaned up**: into a Trove (services, tools such as Extend keep their own) or
  `vide.cleanup` (panel).
- **vide runs with `strict` and `defaults` off** (set in `App.new`). Strict mode would run effects
  twice, doubling side effects; vide's instance defaults differ from Roblox's.

## Checks

`npm run verify` runs StyLua, Selene, the Lune tests, both Rojo builds, and a strict `luau-lsp`
type check of `src` (Roblox type definitions are cached in `.luau-analyze/`). Green means the code
is well-formed and type-correct. It does not mean the tools work: that is checked by hand in Studio.
