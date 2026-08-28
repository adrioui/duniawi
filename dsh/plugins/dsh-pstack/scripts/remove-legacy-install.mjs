import { createHash } from "node:crypto";
import { mkdir, readFile, readdir, rename, stat, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { basename, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const apply = process.argv.includes("--apply");
const forceModified = process.argv.includes("--force-modified");
if (forceModified && !apply) throw new Error("--force-modified requires --apply");
const response = await fetch("http://127.0.0.1:3080/pstack/status");
if (!response.ok) throw new Error("native pstack status endpoint is unavailable");
const status = await response.json();
if (status.provider !== "pstack" || !String(status.path || "").includes("node_modules/@wayanjimmy/dsh-pstack/")) {
  throw new Error("refusing legacy migration because packaged skills are not active");
}

const root = fileURLToPath(new URL("../", import.meta.url));
const manifest = JSON.parse(await readFile(join(root, "legacy-skill-manifest.json"), "utf8"));
const userSkills = join(homedir(), ".dsh", "skills");
async function exists(path) {
  try { await stat(path); return true; } catch (error) { if (error.code === "ENOENT") return false; throw error; }
}
async function files(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const nested = await Promise.all(entries.filter((entry) => entry.name !== "node_modules" && entry.name !== ".DS_Store").map(async (entry) => {
    const path = join(directory, entry.name);
    return entry.isDirectory() ? files(path) : entry.isFile() ? [path] : [];
  }));
  return nested.flat();
}
async function digest(directory) {
  const hash = createHash("sha256");
  for (const path of (await files(directory)).sort()) {
    hash.update(relative(directory, path));
    hash.update("\0");
    hash.update(await readFile(path));
    hash.update("\0");
  }
  return hash.digest("hex");
}

const plan = { owned: [], modified: [], missing: [] };
for (const [name, expected] of Object.entries(manifest.skills)) {
  const path = join(userSkills, name);
  if (!await exists(path)) { plan.missing.push(path); continue; }
  const actual = await digest(path);
  (actual === expected ? plan.owned : plan.modified).push({ path, expected, actual });
}
const legacyMapping = join(homedir(), ".dsh", "pstack-models.json");
const hasLegacyMapping = await exists(legacyMapping);
const legacyRoutes = hasLegacyMapping ? JSON.parse(await readFile(legacyMapping, "utf8")) : {};
const configuredRoles = Array.isArray(status.configuredRoles) ? status.configuredRoles : [];
const unpersistedRoutes = ["code", "judgment", "workers"].flatMap((role) => {
  const model = legacyRoutes[role];
  if (typeof model !== "string" || model.trim().length === 0) return [];
  const route = status.modelRoutes?.[role];
  return configuredRoles.includes(role) && route?.mode === "model" && route.model === model.trim()
    ? []
    : [{ role, model: model.trim(), configured: configuredRoles.includes(role), effective: route ?? null }];
});
if (!apply) {
  process.stdout.write(JSON.stringify({ mode: "dry-run", plan, legacyMapping: hasLegacyMapping ? legacyMapping : null, unpersistedRoutes }, null, 2) + "\n");
  process.exit(0);
}
if (unpersistedRoutes.length > 0) {
  process.stderr.write(JSON.stringify({ error: "legacy model routes are not confirmed in native settings", unpersistedRoutes }, null, 2) + "\n");
  process.exit(3);
}
if (plan.modified.length > 0 && !forceModified) {
  process.stderr.write(JSON.stringify({ error: "modified skill directories require --force-modified", modified: plan.modified }, null, 2) + "\n");
  process.exit(2);
}
const stamp = new Date().toISOString().replaceAll(":", "-") + "-" + process.pid;
const backup = join(homedir(), ".dsh", "pstack-legacy-backup", stamp);
await mkdir(join(backup, "skills"), { recursive: true });
await writeFile(join(backup, "plan.json"), JSON.stringify({ status, plan, legacyMapping: hasLegacyMapping ? legacyMapping : null }, null, 2) + "\n");
for (const entry of [...plan.owned, ...(forceModified ? plan.modified : [])]) {
  await rename(entry.path, join(backup, "skills", basename(entry.path)));
}
if (hasLegacyMapping) await rename(legacyMapping, join(backup, "pstack-models.json"));
process.stdout.write(JSON.stringify({ mode: "applied", backup, movedSkills: plan.owned.length + (forceModified ? plan.modified.length : 0), movedLegacyMapping: hasLegacyMapping }) + "\n");
