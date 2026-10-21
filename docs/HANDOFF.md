# Handoff

Set up 2026-10-21, copied from Isoliminality's project setup. Nothing has been run in Studio.

## Built

- Rojo: `default.project.json` (place 88678433007729, serves into `ServerStorage.VluxyBuildingTools`) and
  `plugin.project.json` (builds the plugin).
- Gates: `npm run verify` (StyLua, Selene, Lune tests, both Rojo builds), `npm run packages:refresh`.
- `src/Plugin.server.luau` adds a toolbar button; `src/Pure/PluginInfo`.
- Token-saving setup: `CLAUDE.md` Usage section, four subagents in `.claude/agents/`.

## Next

- Decide what the tools are, then build them.
