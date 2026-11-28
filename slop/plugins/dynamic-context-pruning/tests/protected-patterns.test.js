import assert from "node:assert/strict";
import test from "node:test";
import {
	getFilePathsFromParameters,
	isFilePathProtected,
	isToolNameProtected,
	matchesGlob
} from "../protected-patterns.js";

const BS = String.fromCharCode(92);

const winPath = (...segments) => segments.join(BS);

test("matchesGlob treats a Windows separator as a path separator", () => {
	const path = winPath("C:", "repo", "src", "config", "secrets.ts");

	assert.equal(matchesGlob(path, "**/secrets.ts"), true);
	assert.equal(matchesGlob(path, "**/config/*.ts"), true);
	assert.equal(matchesGlob(path, "C:/repo/src/**"), true);
	assert.equal(matchesGlob(path, "**/*.ts"), true);
});

test("matchesGlob accepts a pattern written with Windows separators", () => {
	const pattern = winPath("**", "config", "*.ts");

	assert.equal(matchesGlob("C:/repo/src/config/secrets.ts", pattern), true);
	assert.equal(matchesGlob(winPath("C:", "repo", "src", "config", "secrets.ts"), pattern), true);
});

test("a single-segment wildcard still does not cross a Windows separator", () => {
	assert.equal(matchesGlob(winPath("src", "config", "secrets.ts"), "src/*"), false);
	assert.equal(matchesGlob(winPath("src", "config", "secrets.ts"), "src/*/*.ts"), true);
	assert.equal(matchesGlob(winPath("src", "secrets.ts"), "src/*"), true);
});

test("isFilePathProtected protects a Windows path the user configured", () => {
	const patterns = ["**/secrets.ts", "**/.env"];

	for (const path of [
		"C:/repo/src/config/secrets.ts",
		winPath("C:", "repo", "src", "config", "secrets.ts")
	]) {
		const paths = getFilePathsFromParameters("read", { filePath: path });

		assert.equal(isFilePathProtected(paths, patterns), true, `not protected: ${path}`);
	}
});

test("isFilePathProtected still returns false for a genuinely unmatched path", () => {
	const paths = getFilePathsFromParameters("read", {
		filePath: winPath("C:", "repo", "src", "main.ts")
	});

	assert.equal(isFilePathProtected(paths, ["**/secrets.ts"]), false);
	assert.equal(isFilePathProtected(paths, []), false);
	assert.equal(isFilePathProtected([], ["**/*.ts"]), false);
});

test("multiedit and apply_patch paths are protected on Windows too", () => {
	const patterns = ["**/secrets.ts"];

	const multiedit = getFilePathsFromParameters("multiedit", {
		filePath: winPath("src", "main.ts"),
		edits: [{ filePath: winPath("src", "config", "secrets.ts") }]
	});

	assert.equal(isFilePathProtected(multiedit, patterns), true);

	const patch = getFilePathsFromParameters("apply_patch", {
		patchText: `*** Update File: ${winPath("src", "config", "secrets.ts")}
@@
-a
+b
`
	});

	assert.equal(isFilePathProtected(patch, patterns), true);
});

test("isToolNameProtected is unaffected by separator normalisation", () => {
	assert.equal(isToolNameProtected("bash", ["bash"]), true);
	assert.equal(isToolNameProtected("bash", ["ba*"]), true);
	assert.equal(isToolNameProtected("bash", ["read"]), false);
	assert.equal(isToolNameProtected("bash", []), false);
	assert.equal(isToolNameProtected("", ["bash"]), false);
});

test("matchesGlob rejects an empty pattern and handles regex metacharacters", () => {
	assert.equal(matchesGlob("a/b.ts", ""), false);
	assert.equal(matchesGlob("src/a+b(1).ts", "src/a+b(1).ts"), true);
	assert.equal(matchesGlob("src/axb1.ts", "src/a+b(1).ts"), false);
});
