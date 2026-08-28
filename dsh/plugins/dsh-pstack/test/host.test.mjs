import assert from "node:assert/strict";
import test from "node:test";
import routes from "../lib/model-routes.js";
import host from "../index.js";

const { DEFAULT_MODEL_TARGETS, PstackSettingsSchema, convertLegacyModels, isModelTarget, missingLegacyRoutes, normalizeModelRoutes, renderModelMapping } = routes;
const { buildModelGroups, createSkillProvider, parseSkillFrontmatter } = host;

test("model route validation and defaults", () => {
  assert.equal(isModelTarget({ mode: "inherit" }), true);
  assert.equal(isModelTarget({ mode: "model", model: "  alpha  ", provider: "openai" }), true);
  assert.equal(isModelTarget({ mode: "model", model: " " }), false);
  assert.equal(isModelTarget({ mode: "inherit", model: "alpha" }), false);
  assert.deepEqual(normalizeModelRoutes({ workers: { mode: "inherit" } }), { ...DEFAULT_MODEL_TARGETS, workers: { mode: "inherit" } });
  assert.equal(typeof PstackSettingsSchema.toJSON, "function");
  assert.ok(PstackSettingsSchema.toJSON());
});

test("legacy model JSON converts only known non-empty roles", () => {
  assert.deepEqual(convertLegacyModels({ code: " coder ", judgment: "", workers: "worker", unknown: "ignored" }), {
    code: { mode: "model", model: "coder" },
    workers: { mode: "model", model: "worker" }
  });
  assert.deepEqual(convertLegacyModels(null), {});
});

test("legacy migration fills only roles absent from native settings", () => {
  assert.deepEqual(missingLegacyRoutes(
    { judgment: { mode: "model", model: "native-judge" } },
    { code: "legacy-code", judgment: "legacy-judge", workers: "legacy-worker" }
  ), {
    code: { mode: "model", model: "legacy-code" },
    workers: { mode: "model", model: "legacy-worker" }
  });
});

test("model mapping is compact and preserves provider routing", () => {
  assert.equal(renderModelMapping({ code: { mode: "model", model: "coder", provider: "openai" }, judgment: { mode: "inherit" }, workers: { mode: "model", model: "worker" } }), "<pstack_model_routes>code=openai/coder; judgment=inherit; workers=worker</pstack_model_routes>");
});

test("model catalog isolates provider failures", async () => {
  const catalog = await buildModelGroups({
    listProviders: () => [{ id: "ok", name: "Working" }, { id: "bad", name: "Broken" }, { id: "empty", name: "Empty" }],
    async listModels(id) {
      if (id === "bad") throw new Error("offline");
      return id === "empty" ? [] : [{ id: "alpha", name: "Alpha" }];
    }
  });
  assert.deepEqual(catalog.groups, [{ id: "ok", name: "Working", models: [{ id: "alpha", name: "Alpha" }] }]);
  assert.deepEqual(catalog.failures, [{ id: "bad", name: "Broken", message: "offline" }]);
});

test("host apply registers live settings and disposable endpoints", async () => {
  let provider;
  let watch;
  let invalidations = 0;
  const endpoints = new Map();
  const disposers = [];
  const scope = {
    get: () => ({ code: { mode: "model", model: "configured-code" } }),
    update: async () => {},
    watch(listener) { watch = listener; return () => { watch = undefined; }; }
  };
  const settings = {
    register(namespace) { assert.equal(namespace, "pstack"); return scope; },
    describe: () => [{ ns: "pstack", user: { code: { mode: "model", model: "configured-code" } } }]
  };
  const ctx = {
    skills: {
      registerProvider(factory) {
        provider = factory({ invalidate: () => { invalidations += 1; } });
      }
    },
    inject(names, callback) {
      const services = names.includes("settings")
        ? { settings }
        : {
            llm: { listProviders: () => [], listModels: async () => [] },
            skills: { list: async () => [{ provider: "pstack" }], get: async () => ({ provider: "pstack", path: "/package/skills/poteto-mode/SKILL.md" }) },
            webServer: { register(route) { endpoints.set(route.path, route); return () => endpoints.delete(route.path); } }
          };
      const dispose = callback(services);
      if (typeof dispose === "function") disposers.push(dispose);
    }
  };
  host.apply(ctx);
  assert.ok(provider);
  assert.deepEqual([...endpoints.keys()].sort(), ["/pstack/models", "/pstack/status"]);
  watch({ workers: { mode: "inherit" } });
  assert.equal(invalidations, 1);
  const chunks = [];
  await endpoints.get("/pstack/status").handler({}, { writeHead(status) { assert.equal(status, 200); }, end(chunk) { chunks.push(chunk); } });
  assert.equal(JSON.parse(chunks.join("")).provider, "pstack");
  for (const dispose of disposers.reverse()) dispose();
  assert.equal(endpoints.size, 0);
  assert.equal(watch, undefined);
});

test("frontmatter parser preserves metadata and invocation", () => {
  const raw = ["---", "name: sample", "description: Sample skill", "whenToUse: Tests", "user-invocable: false", "metadata:", "  tier: core", "---", "", "# Sample", ""].join("\n");
  assert.deepEqual(parseSkillFrontmatter(raw), {
    name: "sample", description: "Sample skill", whenToUse: "Tests",
    invocation: { modelInvocable: true, userInvocable: false },
    metadata: { tier: "core" }, content: "# Sample"
  });
});

test("packaged provider loads a bundled skill and appends routes", async () => {
  const provider = createSkillProvider(() => ({ code: { mode: "model", model: "coder" }, judgment: { mode: "inherit" }, workers: { mode: "model", model: "worker", provider: "local" } }));
  const candidates = await provider.list();
  assert.ok(candidates.length > 0);
  assert.equal(candidates.every((candidate) => candidate.source === "bundled" && candidate.rank === 600), true);
  const skill = await provider.get(candidates.find((candidate) => candidate.name === "architect") ?? candidates[0]);
  assert.match(skill.content, /<pstack_model_routes>code=coder; judgment=inherit; workers=local\/worker<\/pstack_model_routes>$/);
});
