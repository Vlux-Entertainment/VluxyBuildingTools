# CLAUDE.md

Guidance for Claude Code in this repository. Read `docs/HANDOFF.md` (what is built and what is next)
before starting work.

## Usage

Usage runs out fast, so keep it low. This section loads every turn; keep it short.

- **Agents run on named models, never Fable unless the user asks for that task.** Nothing inherits a
  model. Sessions default to Sonnet; a new main session not on Sonnet asks once, in its first reply,
  whether to `/model sonnet`, unless the user chose the model. Subagents never ask. Haiku for lookups
  and research, Sonnet for building and checking (`.claude/agents/`). The Sonnet main session may hand
  a job to an Opus worker (`model: opus`, one-line reason) when Opus is clearly better at it.
- **No Workflow tool, no `ultracode`, no multi-agent fan-outs.** One cheap subagent at a time, or work
  in the main session.
- **Context is the cost.** Each turn re-reads the whole session, so keep sessions to one job and rely
  on auto-compaction. When a job ends, write a short handoff (done, next, branch, open questions) so a
  summary or `/clear` loses nothing.
- **Keep output small.** Send `npm run verify` and other long logs to a file and show only failures
  or the last ~30 lines. Grep and read line ranges before opening a file. Subagent reports are about
  10 lines.
- **Briefs state the files, a "done when" and a stop rule** (at most 2 fix rounds, then report).
- **The API-credit worker, if present.** On the owner's machine, `~/.claude/claude-api.ps1` runs a
  headless `claude -p` on a limited prepaid API credit instead of the subscription. Use it for medium
  to large self-contained jobs, with a complete brief, `--model sonnet` and `--max-turns`; not for
  quick questions, connector work or loops. Never print or commit the key. Its full guide is in
  `~/.claude/CLAUDE.md`.

## Non-negotiables

1. **`main` changes only through a pull request.** Claude may open and merge its own PRs once `npm run verify` is green. Work on branches; never force-push; never commit to `main` directly.
2. **`npm run verify` before every commit.** Green means well-formed, not working.
3. **Never start a Studio play-test unless the user asks.**
4. **Pure means pure.** Nothing under `src/Pure/` touches a Roblox API; it is tested under Lune.
5. **Never hand-edit generated files:** `Packages/`, `sourcemap.json`.
6. **Clean up every connection.** A plugin that leaks signals or widgets leaks them on every reload;
   functions that connect return their cleanup, and Trove holds the rest.

## Project

**VluxyBuildingTools**, a Roblox Studio plugin for building tools. Luau, `--!strict` everywhere. Rojo
(`default.project.json` serves the plugin source into `ServerStorage.VluxyBuildingTools` of place
88678433007729 for live editing; `plugin.project.json` builds the installable plugin). Wally packages:
Signal, Trove, Dash, Promise, vide. Tools are pinned in `rokit.toml`; run `rokit install`.

Only the skeleton exists: the entry script adds a toolbar button and nothing else.

## Commands

| Task | Command |
|---|---|
| All gates (format, lint, Lune tests, both Rojo builds) | `npm run verify` (`--fix` reformats first) |
| Install packages, sourcemap and package types | `npm run packages:refresh` |
| Tests alone | `lune run tests/runner [pattern]` |
| Build the plugin file | `npm run plugin:build` (writes `VluxyBuildingTools.rbxm`; `rojo build --plugin` also installs it) |

## Conventions

- Folders PascalCase. Locals camelCase, constants PascalCase, never-changing constants UPPER_SNAKE.
  Exported functions PascalCase, local ones camelCase, private `_camelCase`.
- Attributes the plugin writes into the place are named `VluxyBT_<Purpose>`. Older names stay readable.
- Name a cleanup method `Destroy` so Trove picks it up.
- Every function gets a block comment: `--[[ ]]` for locals, Moonwave `--[=[ ]=]` with `@class` for
  exported modules. Three sentences or fewer. No trailing `--` comments.
- Never cast away a nil you then check: write `:: BasePart?`.
- Commits: loose conventional commits, `feat(Scope): ...` and `fix(Scope): ...`.
