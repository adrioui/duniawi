import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import host from "../index.js";

const root = fileURLToPath(new URL("../", import.meta.url));
const test = spawnSync(process.execPath, ["--test", "test/host.test.mjs"], { cwd: root, encoding: "utf8" });
if (test.status !== 0) {
  process.stderr.write(test.stdout + test.stderr);
  process.exit(test.status ?? 1);
}

const manifest = JSON.parse(await readFile(join(root, "package.json"), "utf8"));
assert.equal(manifest.exports["./client"], "./client.js");
assert.equal(manifest.dsh.client.platform, "web");

const provider = host.createSkillProvider(() => ({
  code: { mode: "model", model: "code-model" },
  judgment: { mode: "model", model: "judge-model" },
  workers: { mode: "inherit" },
}));
const skills = await provider.list();
assert.ok(skills.length >= 20);
for (const skill of skills) {
  const loaded = await provider.get(skill);
  assert.match(loaded.content, /<pstack_model_routes>/);
}

const forbidden = ["deepseek-v4-flash", "glm-5.3", "mimo-v2.5", "pstack-models.json", "export const meta"];
async function markdownFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const nested = await Promise.all(entries.map(async (entry) => {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) return markdownFiles(path);
    return entry.isFile() && entry.name.endsWith(".md") ? [path] : [];
  }));
  return nested.flat();
}
for (const path of await markdownFiles(join(root, "skills"))) {
  const content = await readFile(path, "utf8");
  for (const token of forbidden) assert.equal(content.includes(token), false, path + " contains " + token);
}

const packed = spawnSync("pnpm", ["pack", "--dry-run", "--json"], { cwd: root, encoding: "utf8" });
if (packed.status !== 0) throw new Error(packed.stderr || "pnpm pack failed");
const packResult = JSON.parse(packed.stdout);
const packedFiles = (Array.isArray(packResult) ? packResult[0] : packResult).files.map((entry) => entry.path);
assert.equal(packedFiles.some((path) => path.includes("/node_modules/")), false, "package contains nested node_modules");
for (const required of ["scripts/verify.mjs", "scripts/verify-web.mjs", "scripts/remove-legacy-install.mjs", "legacy-skill-manifest.json"]) {
  assert.equal(packedFiles.includes(required), true, "package omits " + required);
}

process.stdout.write(JSON.stringify({ tests: "passed", packagedSkills: skills.length, packedFiles: packedFiles.length, client: manifest.exports["./client"] }) + "\n");
