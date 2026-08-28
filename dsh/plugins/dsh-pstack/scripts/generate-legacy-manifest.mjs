import { createHash } from "node:crypto";
import { writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { join } from "node:path";

const root = fileURLToPath(new URL("../", import.meta.url));
function git(args) {
  const result = spawnSync("git", args, { cwd: root, encoding: "utf8" });
  if (result.status !== 0) throw new Error(result.stderr || "git command failed");
  return result.stdout;
}
const base = git(["merge-base", "HEAD", "main"]).trim();
const names = git(["ls-tree", "-d", "--name-only", base, "skills/"]).trim().split("\n").filter(Boolean).map((path) => path.split("/").at(-1)).sort();
const manifest = { version: 1, base, skills: {} };
for (const name of names) {
  const prefix = "skills/" + name + "/";
  const files = git(["ls-tree", "-r", "--name-only", base, prefix]).trim().split("\n").filter(Boolean)
    .filter((path) => !path.includes("/node_modules/") && !path.endsWith("/.DS_Store"));
  const hash = createHash("sha256");
  for (const path of files.sort()) {
    hash.update(path.slice(prefix.length));
    hash.update("\0");
    hash.update(git(["show", base + ":" + path]));
    hash.update("\0");
  }
  manifest.skills[name] = hash.digest("hex");
}
await writeFile(join(root, "legacy-skill-manifest.json"), JSON.stringify(manifest, null, 2) + "\n");
process.stdout.write(JSON.stringify({ base, skills: names.length }) + "\n");
