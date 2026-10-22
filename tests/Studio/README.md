# Studio checks

Some of the plugin only works inside Roblox Studio: raycasts, `GetPartBoundsInRadius`, instance
signals, CSG and the color sweep. The Lune specs cannot reach those, so `Smoke.luau` checks them
in a real place. Nothing here runs under `npm run verify`.

## Running the smoke script

1. Open place 88678433007729 in Studio and serve `default.project.json` with Rojo, so
   `ServerStorage.VluxyBuildingTools` holds the code you want to check.
2. Copy the whole of `Smoke.luau` into the command bar (View > Command Bar) and press Enter.
3. Read the Output window. Each check prints `[VluxyTest] PASS <name>` or a warning
   `[VluxyTest] FAIL <name>: <error>`, and the last line counts both.

The script requires a fresh clone of `ServerStorage.VluxyBuildingTools`, so edited modules load
without restarting Studio. It builds 500 studs above the origin in a `Workspace.VluxyTest_Smoke`
folder and removes the folder and the clone when it finishes. It does not start a play-test.

## What it covers

- A room materializes with a floor, four walls and a ceiling.
- `Snapper.Find` pulls a point near the room's corner onto it (a spatial query).
- A door cut into a wall found by a real raycast gives three frame pieces and a see-through panel.
- `Snapper.Doorway` finds that door and points out of the side the point is on.
- The color sweep gives a new part in the folder its theme color.

The color check sets the `VluxGreybox_Enabled_v1` attribute on Workspace for a moment and puts
the old value back. If a check throws before the end, delete `Workspace.VluxyTest_Smoke` and
`ServerStorage.VluxyTest_Clone` by hand.

## Adding a check

Add a `check("what it proves", function() ... end)` block before the cleanup at the end. Fail by
throwing (`assert` or `error`), build only inside `folder`, and keep the script self-contained:
the command bar cannot require files from the repo.
