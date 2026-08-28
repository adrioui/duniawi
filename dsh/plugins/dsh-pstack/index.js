const { readFile, readdir } = require("node:fs/promises");
const { join, dirname } = require("node:path");
const { homedir } = require("node:os");
const { parse } = require("yaml");
const {
  PstackSettingsSchema,
  ROLES,
  missingLegacyRoutes,
  normalizeModelRoutes,
  renderModelMapping
} = require("./lib/model-routes.js");

const name = "pstack";
const inject = ["skills"];
const SKILLS_DIRECTORY = join(__dirname, "skills");
const LEGACY_MODELS_PATH = join(homedir(), ".dsh", "pstack-models.json");

function isRecord(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function frontmatterBoolean(data, key) {
  if (!Object.hasOwn(data, key)) return undefined;
  const value = data[key];
  if (typeof value === "boolean") return value;
  if (value === 1 || value === "1") return true;
  if (value === 0 || value === "0") return false;
  if (typeof value === "string") {
    const normalized = value.toLowerCase();
    if (["true", "yes", "on"].includes(normalized)) return true;
    if (["false", "no", "off"].includes(normalized)) return false;
  }
  throw new TypeError("frontmatter field \"" + key + "\" must be a boolean");
}

function parseSkillFrontmatter(raw) {
  const firstLineEnd = raw.indexOf("\n");
  if (firstLineEnd < 0 || raw.slice(0, firstLineEnd).replace(/\r$/, "") !== "---") return undefined;
  let lineStart = firstLineEnd + 1;
  let closing;
  while (lineStart <= raw.length) {
    const lineEnd = raw.indexOf("\n", lineStart);
    const end = lineEnd < 0 ? raw.length : lineEnd;
    if (raw.slice(lineStart, end).replace(/\r$/, "") === "---") {
      closing = { start: lineStart, bodyStart: lineEnd < 0 ? raw.length : lineEnd + 1 };
      break;
    }
    if (lineEnd < 0) return undefined;
    lineStart = lineEnd + 1;
  }
  if (closing === undefined) return undefined;
  const data = parse(raw.slice(firstLineEnd + 1, closing.start));
  if (!isRecord(data) || typeof data.name !== "string" || data.name.length === 0 || typeof data.description !== "string" || data.description.length === 0) return undefined;
  if (Object.hasOwn(data, "disableModelInvocation") || Object.hasOwn(data, "modelInvocable") || Object.hasOwn(data, "userInvocable")) throw new TypeError("unsupported legacy invocation frontmatter");
  const metadata = isRecord(data.metadata) ? data.metadata : undefined;
  return {
    name: data.name,
    description: data.description,
    ...(typeof data.whenToUse === "string" && data.whenToUse.length > 0 ? { whenToUse: data.whenToUse } : {}),
    invocation: {
      modelInvocable: frontmatterBoolean(data, "disable-model-invocation") !== true,
      userInvocable: frontmatterBoolean(data, "user-invocable") !== false
    },
    ...(metadata === undefined ? {} : { metadata }),
    content: raw.slice(closing.bodyStart).trim()
  };
}

async function readSkill(path, signal) {
  const raw = await readFile(path, { encoding: "utf8", signal });
  return parseSkillFrontmatter(raw);
}

function createSkillProvider(currentRoutes) {
  return {
    name: "pstack",
    async list({ signal } = {}) {
      let entries;
      try {
        entries = await readdir(SKILLS_DIRECTORY, { withFileTypes: true });
      } catch (error) {
        if (error && error.code === "ENOENT") return [];
        throw error;
      }
      const candidates = await Promise.all(entries.filter((entry) => entry.isDirectory()).map(async (entry) => {
        const path = join(SKILLS_DIRECTORY, entry.name, "SKILL.md");
        try {
          const parsed = await readSkill(path, signal);
          if (parsed === undefined) return undefined;
          return {
            name: parsed.name,
            description: parsed.description,
            ...(parsed.whenToUse === undefined ? {} : { whenToUse: parsed.whenToUse }),
            invocation: parsed.invocation,
            source: "bundled",
            provider: "pstack",
            rank: 600,
            locator: { path, directory: dirname(path) },
            resourceBase: { kind: "directory", path: dirname(path) },
            path,
            ...(parsed.metadata === undefined ? {} : { metadata: parsed.metadata })
          };
        } catch (error) {
          if (error && error.code === "ENOENT") return undefined;
          throw error;
        }
      }));
      return candidates.filter(Boolean).sort((a, b) => a.name.localeCompare(b.name));
    },
    async get(candidate, { signal } = {}) {
      const locator = candidate.locator;
      if (!isRecord(locator) || typeof locator.path !== "string" || typeof locator.directory !== "string") return undefined;
      let parsed;
      try {
        parsed = await readSkill(locator.path, signal);
      } catch (error) {
        if (error && error.code === "ENOENT") return undefined;
        throw error;
      }
      if (parsed === undefined) return undefined;
      return {
        name: parsed.name,
        description: parsed.description,
        ...(parsed.whenToUse === undefined ? {} : { whenToUse: parsed.whenToUse }),
        invocation: parsed.invocation,
        source: "bundled",
        provider: "pstack",
        resourceBase: { kind: "directory", path: locator.directory },
        path: locator.path,
        ...(parsed.metadata === undefined ? {} : { metadata: parsed.metadata }),
        content: parsed.content + "\n\n" + renderModelMapping(currentRoutes())
      };
    }
  };
}

async function importLegacyModels(scope, settings) {
  const descriptor = settings.describe().find((entry) => entry.ns === "pstack");
  const user = descriptor?.user && typeof descriptor.user === "object" ? descriptor.user : {};
  let legacy;
  try {
    legacy = JSON.parse(await readFile(LEGACY_MODELS_PATH, "utf8"));
  } catch (error) {
    if (error && error.code === "ENOENT") return;
    console.warn("[pstack] failed to read legacy model routes:", error);
    return;
  }
  const missing = missingLegacyRoutes(user, legacy);
  if (Object.keys(missing).length === 0) return;
  try {
    await scope.update(missing);
  } catch (error) {
    console.warn("[pstack] failed to import legacy model routes:", error);
  }
}

async function buildModelGroups(llm) {
  const entries = await Promise.all(llm.listProviders().map(async (provider) => {
    try {
      const models = await llm.listModels(provider.id);
      return { kind: "group", group: { id: provider.id, name: provider.name, models } };
    } catch (error) {
      return { kind: "failure", failure: { id: provider.id, name: provider.name, message: error instanceof Error ? error.message : String(error) } };
    }
  }));
  return {
    groups: entries.filter((entry) => entry.kind === "group" && entry.group.models.length > 0).map((entry) => entry.group),
    failures: entries.filter((entry) => entry.kind === "failure").map((entry) => entry.failure)
  };
}

function configuredRoles(settings) {
  const descriptor = settings.describe().find((entry) => entry.ns === "pstack");
  const user = descriptor?.user && typeof descriptor.user === "object" ? descriptor.user : {};
  return ROLES.filter((role) => user[role] !== undefined);
}

function apply(ctx) {
  let routes = normalizeModelRoutes();
  let nativeRoles = [];
  let invalidate = () => {};
  ctx.skills.registerProvider((control) => {
    invalidate = control.invalidate;
    return createSkillProvider(() => routes);
  });
  ctx.inject(["settings"], (settingsCtx) => {
    const scope = settingsCtx.settings.register("pstack", PstackSettingsSchema);
    routes = normalizeModelRoutes(scope.get());
    nativeRoles = configuredRoles(settingsCtx.settings);
    void importLegacyModels(scope, settingsCtx.settings).finally(() => {
      nativeRoles = configuredRoles(settingsCtx.settings);
    });
    return scope.watch((next) => {
      routes = normalizeModelRoutes(next);
      nativeRoles = configuredRoles(settingsCtx.settings);
      invalidate();
    });
  });
  ctx.inject(["llm", "webServer"], (serviceCtx) => {
    const disposeModels = serviceCtx.webServer.register({
      kind: "exact",
      path: "/pstack/models",
      async handler(_req, res) {
        const catalog = await buildModelGroups(serviceCtx.llm);
        res.writeHead(200, { "content-type": "application/json" });
        res.end(JSON.stringify(catalog));
      }
    });
    const disposeStatus = serviceCtx.webServer.register({
      kind: "exact",
      path: "/pstack/status",
      async handler(_req, res) {
        const catalog = await serviceCtx.skills.list();
        const loaded = await serviceCtx.skills.get("poteto-mode");
        const body = {
          provider: loaded?.provider ?? null,
          path: loaded?.path ?? null,
          packagedSkills: catalog.filter((skill) => skill.provider === "pstack").length,
          configuredRoles: nativeRoles,
          modelRoutes: routes
        };
        res.writeHead(200, { "content-type": "application/json" });
        res.end(JSON.stringify(body));
      }
    });
    return () => {
      disposeStatus();
      disposeModels();
    };
  });
}


module.exports = {
  name,
  inject,
  apply,
  parseSkillFrontmatter,
  createSkillProvider,
  buildModelGroups
};
