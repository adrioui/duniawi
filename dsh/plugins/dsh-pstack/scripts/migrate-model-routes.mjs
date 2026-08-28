import { readFile, readdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../skills/", import.meta.url));
const substitutions = new Map([
  ["deepseek-v4-flash", "configured code route"],
  ["glm-5.3", "configured judgment route"],
  ["mimo-v2.5", "configured workers route"],
  ["~/.dsh/pstack-models.json", "Settings > Plugins > pstack"],
]);

async function markdownFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const nested = await Promise.all(entries.map(async (entry) => {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) return markdownFiles(path);
    return entry.isFile() && entry.name.endsWith(".md") ? [path] : [];
  }));
  return nested.flat();
}

let changed = 0;
for (const path of await markdownFiles(root)) {
  const before = await readFile(path, "utf8");
  let after = before;
  for (const [from, to] of substitutions) after = after.replaceAll(from, to);
  if (after === before) continue;
  await writeFile(path, after);
  changed += 1;
}
console.log(JSON.stringify({ changed }));
