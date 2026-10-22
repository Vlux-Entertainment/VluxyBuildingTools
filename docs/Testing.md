---
sidebar_position: 21
title: Testing
---

# Testing

The tests live in `tests/` and come in three layers: unit specs that run under Lune, performance
benchmarks, and a smoke script for Roblox Studio.

| Layer | Where | Command | Runs in `npm run verify` |
|---|---|---|---|
| Unit specs | `tests/Pure/`, `tests/Core/` | `npm test` | yes |
| Benchmarks | `tests/Perf/` | `npm run perf` | no |
| Studio smoke | `tests/Studio/Smoke.luau` | paste into the command bar | no |

## Unit specs

`npm test` runs `lune run tests/runner`, which loads every `*.spec.luau` under `tests/`. Pass a
word to run only the specs whose path holds it, such as `lune run tests/runner Openings`.

A spec returns a table of cases. Each case gets `expect`, whose checks (`equal`, `near`, `truthy`,
`falsy`, `errors`) throw on failure:

```lua
return {
	["a foundation is wider by the margin"] = function(expect)
		expect.equal(#specs, 1)
	end,
}
```

- **`tests/Pure/`** requires `src/Pure` modules directly. They touch no Roblox API.
- **`tests/Core/`** loads the builders, `Geometry`, `Snapper` and `Transform` through
  `tests/Support/Harness.luau`. The harness gives each module its own `require`, real Roblox
  datatypes and Parts from Lune's `@lune/roblox`, and a real DataModel as `game`, so a spec runs
  the plugin's own code.

The harness cannot fake everything. Raycasts, `GetPartBoundsInRadius`, instance signals, CSG,
ChangeHistoryService and plugin APIs are left untested here. Two Lune gaps are worked around:
`Harness.SyncPositions` fills in `BasePart.Position`, which Lune does not derive from `CFrame`,
and `Harness.CFrame` corrects `CFrame.lookAt`, which Lune 0.10.5 gets wrong for any direction
with a Z part.

## Benchmarks

`npm run perf` runs `lune run tests/perf`. Each `*.bench.luau` in `tests/Perf/` returns named
benchmarks with a `Budget` in milliseconds and a `Run` function. The runner times each one,
prints a table of the median time against its budget, and exits with an error if any is over.

Budgets are about three times a measured run, so they fail only on a real slowdown. Timings depend
on the machine, which is why `npm run verify` leaves them out. Raise a budget only when the extra
work is intended.

## Studio smoke script

Some behaviour needs a real place: raycasts, spatial queries and the color sweep.
`tests/Studio/Smoke.luau` is a command-bar script that builds into a temporary folder, prints
one `[VluxyTest] PASS` or `FAIL` line per check, and cleans up. See `tests/Studio/README.md` for
how to run it.
