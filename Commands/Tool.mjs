// Shared by the command scripts: finds and runs the tools pinned in rokit.toml.
//
// A pinned tool is run from rokit's own folder when it is there, and from PATH otherwise. Going
// to rokit's folder first matters on a machine that also has Foreman: Foreman leaves shims on
// PATH under the same names, and a shim for a tool Foreman does not manage fails while looking
// like the real tool.

import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const extension = process.platform === "win32" ? ".exe" : "";

/** The full path of a pinned tool if rokit has installed it, otherwise its bare name. */
export function locate(tool) {
	const pinned = join(homedir(), ".rokit", "bin", tool + extension);

	return existsSync(pinned) ? pinned : tool;
}

/** Runs a pinned tool, showing its output. Throws when it cannot be started or exits non-zero. */
export function run(tool, args) {
	const result = spawnSync(locate(tool), args, { stdio: "inherit" });

	if (result.error) {
		throw new Error(`${tool} could not be started (${result.error.code}). Run "rokit install".`);
	}

	if (result.status !== 0) {
		throw new Error(`${tool} ${args.join(" ")} exited with code ${result.status}.`);
	}
}

/** Runs a pinned tool and says whether it succeeded, without throwing. */
export function attempt(tool, args) {
	try {
		run(tool, args);

		return true;
	} catch {
		return false;
	}
}
