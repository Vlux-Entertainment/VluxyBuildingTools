// Runs every mechanical gate and exits non-zero if any fails. Green says the code is
// well-formed, never that the game works: gameplay is verified by hand in Studio.
//
//   node Commands/Verify.mjs          check
//   node Commands/Verify.mjs --fix    reformat with StyLua first
//
// Tools run from rokit's folder first (see Tool.mjs), so a leftover Foreman shim cannot shadow
// them. A gate whose tool is missing reports SKIP and passes; --strict makes a skip a failure.
//
// The types gate runs luau-lsp in strict mode over src. It needs Roblox's type definitions, which
// are downloaded once into .luau-analyze/ (gitignored); offline with no copy, the gate skips.

import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { locate } from "./Tool.mjs";

const args = new Set(process.argv.slice(2));
const strict = args.has("--strict") || process.env.CI === "true";
const scratch = mkdtempSync(join(tmpdir(), "vbt-verify-"));
const DEFS_URL = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.PluginSecurity.d.luau";
const defs = join(".luau-analyze", "globalTypes.d.luau");

/** Downloads the Roblox type definitions unless a copy is already cached. Returns whether one is there. */
async function fetchDefs() {
	if (existsSync(defs)) {
		return true;
	}

	try {
		const response = await fetch(DEFS_URL);

		if (!response.ok) {
			return false;
		}

		mkdirSync(".luau-analyze", { recursive: true });
		writeFileSync(defs, await response.text());

		return true;
	} catch {
		return false;
	}
}

const haveDefs = await fetchDefs();
const sourcemap = join(scratch, "sourcemap.json");

const gates = [
	{ name: "format", cmd: "stylua", args: args.has("--fix") ? ["src", "tests"] : ["--check", "src", "tests"] },
	{ name: "lint", cmd: "selene", args: ["src"] },
	{ name: "tests", cmd: "lune", args: ["run", "tests/runner"] },
	{ name: "build", cmd: "rojo", args: ["build", "default.project.json", "-o", join(scratch, "check.rbxl")] },
	{ name: "plugin", cmd: "rojo", args: ["build", "plugin.project.json", "-o", join(scratch, "check.rbxm")] },
	{ name: "sourcemap", cmd: "rojo", args: ["sourcemap", "default.project.json", "-o", sourcemap], quiet: true },
	{
		name: "types",
		cmd: "luau-lsp",
		args: ["analyze", `--defs=${defs}`, `--sourcemap=${sourcemap}`, "--platform=roblox", "--ignore=Packages/**", "src"],
		skip: haveDefs ? null : "Roblox type definitions could not be downloaded",
		// Type errors say "not found", so only a failed start counts as a missing tool here.
		exactMissing: true,
		filter: (text) => text.split("\n").filter((line) => /Error|error/.test(line)).join("\n"),
	},
];

let failed = 0;

for (const gate of gates) {
	if (gate.skip) {
		console.log(`SKIP  ${gate.name} (${gate.skip})`);
		if (strict) failed++;
		continue;
	}

	const cmd = locate(gate.cmd);
	const result = spawnSync(cmd, gate.args, { encoding: "utf8", shell: cmd === gate.cmd && process.platform === "win32" });
	const missing =
		result.error?.code === "ENOENT" ||
		(!gate.exactMissing && /not recognized|not found|not a known/i.test(result.stderr ?? ""));

	if (missing) {
		console.log(`SKIP  ${gate.name} (${gate.cmd} not on PATH)`);
		if (strict) failed++;
		continue;
	}

	if (result.status === 0) {
		if (!gate.quiet) {
			console.log(`PASS  ${gate.name}`);
		}
	} else {
		failed++;
		const output = `${result.stdout ?? ""}${result.stderr ?? ""}`;
		console.log(`FAIL  ${gate.name}`);
		console.log((gate.filter ? gate.filter(output) : output).trim().replace(/^/gm, "      "));
	}
}

rmSync(scratch, { recursive: true, force: true });
console.log(failed === 0 ? "\nAll gates green." : `\n${failed} gate(s) failed.`);
process.exit(failed === 0 ? 0 : 1);
