// Runs every mechanical gate and exits non-zero if any fails. Green says the code is
// well-formed, never that the game works: gameplay is verified by hand in Studio.
//
//   node Commands/Verify.mjs          check
//   node Commands/Verify.mjs --fix    reformat with StyLua first
//
// Tools run from rokit's folder first (see Tool.mjs), so a leftover Foreman shim cannot shadow
// them. A gate whose tool is missing reports SKIP and passes; --strict makes a skip a failure.

import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { locate } from "./Tool.mjs";

const args = new Set(process.argv.slice(2));
const strict = args.has("--strict") || process.env.CI === "true";
const scratch = mkdtempSync(join(tmpdir(), "vbt-verify-"));

const gates = [
	{ name: "format", cmd: "stylua", args: args.has("--fix") ? ["src", "tests"] : ["--check", "src", "tests"] },
	{ name: "lint", cmd: "selene", args: ["src"] },
	{ name: "tests", cmd: "lune", args: ["run", "tests/runner"] },
	{ name: "build", cmd: "rojo", args: ["build", "default.project.json", "-o", join(scratch, "check.rbxl")] },
	{ name: "plugin", cmd: "rojo", args: ["build", "plugin.project.json", "-o", join(scratch, "check.rbxm")] },
];

let failed = 0;

for (const gate of gates) {
	const cmd = locate(gate.cmd);
	const result = spawnSync(cmd, gate.args, { encoding: "utf8", shell: cmd === gate.cmd && process.platform === "win32" });
	const missing = result.error?.code === "ENOENT" || /not recognized|not found|not a known/i.test(result.stderr ?? "");

	if (missing) {
		console.log(`SKIP  ${gate.name} (${gate.cmd} not on PATH)`);
		if (strict) failed++;
		continue;
	}

	if (result.status === 0) {
		console.log(`PASS  ${gate.name}`);
	} else {
		failed++;
		console.log(`FAIL  ${gate.name}`);
		console.log(`${result.stdout ?? ""}${result.stderr ?? ""}`.trim().replace(/^/gm, "      "));
	}
}

rmSync(scratch, { recursive: true, force: true });
console.log(failed === 0 ? "\nAll gates green." : `\n${failed} gate(s) failed.`);
process.exit(failed === 0 ? 0 : 1);
