# AGENTS.md

Repo rules are in `CLAUDE.md`; read it first.

## Usage

Usage is limited, so work lean: read only the parts of files you need, batch Studio reads into one
`execute_luau` call, take screenshots only when the job needs them, at most 2 build-and-check rounds,
`npm run verify` once at the end. In a sandbox verify may print SKIP for tools it can't find and still
say "green": report every SKIP as not checked. Don't touch git; Claude commits.
