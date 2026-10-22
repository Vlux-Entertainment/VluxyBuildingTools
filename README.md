<div align="center">
	<img src="assets/icon.png" alt="VluxyBuildingTools" height="128" />
	<br/>
	<a href="https://discord.gg/Ebbp9UgBUD"><img src="https://img.shields.io/discord/757104089984270346.svg?label=discord" /></a>
	<p><a href="https://Vlux-Entertainment.github.io/VluxyBuildingTools/">View Docs</a></p>
</div>

<!--moonwave-hide-before-this-line-->

# VluxyBuildingTools

**VluxyBuildingTools** is a Roblox Studio plugin for building maps fast. Click a start and an end
and get a wall, a room, a corridor or a flight of stairs, with a live preview and exact numbers
typed as you go. The keys work like Blender's, every build is one undo step, and the plugin only
ever edits the one working folder you choose. Version 1.0.0.

## Features

- **Drawing tools:** walls, floors, blocks, pillars, arches, stairs, ramps, rooms, corridors,
  foundations, porches, roofs, railings, half walls, fences and vent ducts.
- **Openings:** doorways with a door and frame, windows, round and triangle windows, archways,
  vent holes, and any shape you outline.
- **Blender hotkeys:** G, R and C grab, rotate and scale with axis locks and typed values; T extrudes
  a face; Ctrl+M mirrors; Ctrl+1 to Ctrl+7 pick a tool.
- **Brush and props:** paint copies of objects onto surfaces, or place built-in props by room type.
- **Array:** Blender-style copies with a live preview.
- **Display:** six color themes, a surface grid, a camera light and parts hidden just for you.
- **Team Create:** themes and the grid are shared through the working folder; hidden parts, the
  camera light and sounds stay local.

## Install

```sh
rokit install
npm run packages:refresh
npm run plugin:build
```

`npm run plugin:build` builds `VluxyBuildingTools.rbxm` into Studio's local Plugins folder. To run it
live from source, serve `default.project.json` with Rojo and save the `VluxyBuildingTools` folder in
`ServerStorage` as a local plugin. See [Installation](https://Vlux-Entertainment.github.io/VluxyBuildingTools/docs/Installation).

## Quick start

1. Make a `Folder` in `Workspace` and give it the tag `VluxyBT_Map` (View > Tag Editor).
2. Open the panel, click **Choose working folder**, click the folder and press **Yes**.
3. Press **Ctrl+4**, pick **Room**, and click two corners.
4. Press **Ctrl+3**, pick **Doorway**, click a wall, then move the mouse through it and click again.
5. Press **F1** for every hotkey.

The [docs site](https://Vlux-Entertainment.github.io/VluxyBuildingTools/) covers every tool, tab and
hotkey.

## Development

| Task | Command |
|---|---|
| All gates (format, lint, Lune tests, both Rojo builds, strict types) | `npm run verify` (`--fix` reformats first) |
| Install packages, sourcemap and package types | `npm run packages:refresh` |
| Tests alone | `lune run tests/runner [pattern]` |
| Build the plugin file | `npm run plugin:build` |

`docs/ARCHITECTURE.md` maps the code. `CLAUDE.md` holds the rules for contributors.

## License

MIT. See [LICENSE](LICENSE).
