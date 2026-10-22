# Handoff

## State (2026-10-22)

Branch `exp/modular-rewrite`: a rewrite of the plugin into modules, meant to work the same as `main`
with a few small, listed changes. `npm run verify` is green, including a new strict type check.
**Nothing on this branch has been run in Studio yet.**

The layout, the tool contract and a "where to look when it breaks" table are in
`docs/ARCHITECTURE.md`.

## Done

- The 4,200-line `Core/Controller.luau` closure is gone. In its place: `App/` (composition root,
  actions, input), `Services/`, `State/`, one module per tool family under `Tools/` behind one
  contract, and `Modal/` for extrude and grab/rotate/scale.
- The 2,600-line `Ui/Panel.luau` is rebuilt on vide: it reads the settings and app state
  reactively, so there is no refresh to forget. One file per tab under `Ui/Pages/`.
- `Core/Builders.luau` (2,000 lines) is split by family into `Core/Builders/`.
- A parity review against `main` found one real regression (switching folders with "Use folder's"
  overwrote the old folder's shared settings) and a few small differences; all fixed.
- `npm run verify` gained a strict `luau-lsp` type check. It found a real bug on `main`: the sound
  slider connected to events the dock widget does not have, so building the panel threw.

## Behavior changes (intended)

- Collapse props after picking one now works (the old code for it never ran).
- Changing the theme, grid color or size, or ghost transparency from anywhere, including Reset all,
  restyles the map.
- `[` and `]` mark a field as overridden, as typing in it does.
- An axis key with a tool that has no axis lock says so.
- A vent started from another vent continues the chain from the axis-snapped end.
- The debug prints of the shared theme are gone.
- Pillar's viewport bar no longer lists Alt and axis-lock hints (Pillar never used them).

## Next: test in Studio

Serve this branch (Rojo-Hub `serve_here`, or `rojo serve`), save the plugin as a local plugin from
ServerStorage, and work through this list. Note anything that differs from `main`.

1. Open the panel; pick a working folder (click, Yes). Try a folder without the `VluxyBT_Map` tag.
2. Settings tab: drag the sound volume slider (it was broken on `main`), toggle sounds and hotkeys.
3. Basic: wall chain with a bend, Y height drag, Alt straight line, X lock with a typed length,
   Esc once then twice, Enter for a new chain; pillared wall, floor, block (Y drag), pillar, arch.
4. Stairs and ramp: run, then rise click.
5. Additive: door, window, circle and triangle window, archway, with and without cut depth; cut
   shape (close on the first corner, and with Enter); vent hole; face extend drag.
6. Structures: room (joins with another room), corridor from a doorway with turns, arched corridor
   with a bend, foundation, porch, roof styles.
7. Vents: a chained vent through a wall, starting from an existing vent; slope vent; shaft; cover,
   cap, fan, peek.
8. Railings: railing up stairs, half wall, fence.
9. Brush: click to add a brush, Ctrl-click more, drag a stroke, R, toggle and remove brushes.
10. Props tab: sections, pick a prop, R, Ctrl/Alt + wheel stepping, collapse after pick.
11. Measure; T extrude; G / R / C / D with axis locks, typed values, arrows for Rotate; Ctrl+M and
    O then an axis; H, Alt+H, I.
12. Display: pastel on/off and theme, surface grid on/off, tile size, color; camera light.
13. Undo/redo after each build; close and reopen the panel (pastel and grid come off and back).
14. Reload the plugin and check the Output for errors or leaked overlays.

## Open questions

- Merge into `main` once Studio testing passes, or keep the branch separate for a while?
