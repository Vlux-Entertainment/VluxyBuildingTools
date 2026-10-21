// Installs the Wally packages and gives the editor their types. Run it after changing wally.toml:
//
//   npm run packages:refresh
//
// Three steps: install the packages, write the sourcemap the type tool reads, then rewrite each
// package's link file so it exports the package's types.

import { existsSync } from "node:fs";
import { attempt, run } from "./Tool.mjs";

const SOURCEMAP = "sourcemap.json";

try {
	console.log("Installing packages...");
	run("wally", ["install"]);

	console.log("Writing the sourcemap...");
	run("rojo", ["sourcemap", "default.project.json", "--include-non-scripts", "-o", SOURCEMAP]);

	console.log("Linking package types...");
	run("wally-package-types", ["--sourcemap", SOURCEMAP, "Packages/"]);
} catch (problem) {
	console.error(problem.message);
	process.exit(1);
}

// Server packages are typed on a best-effort basis: one the type tool cannot read should not stop
// the shared packages, which are the ones most code uses, from being typed.
if (existsSync("ServerPackages") && !attempt("wally-package-types", ["--sourcemap", SOURCEMAP, "ServerPackages/"])) {
	console.log("The server packages could not be typed; they still work, without editor types.");
}

console.log("Packages are up to date.");
