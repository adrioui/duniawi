const zModule = require("@deepseek-ai/schemastery");
const z = zModule.default || zModule;

const ROLES = ["code", "judgment", "workers"];
const DEFAULT_MODEL_TARGETS = Object.freeze({
  code: Object.freeze({ mode: "model", model: "gpt-5.6-terra" }),
  judgment: Object.freeze({ mode: "model", model: "gpt-5.6-sol" }),
  workers: Object.freeze({ mode: "model", model: "gpt-5.6-luna" })
});

function isRecord(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isModelTarget(value) {
  if (!isRecord(value)) return false;
  if (value.mode === "inherit") return Object.keys(value).every((key) => key === "mode");
  if (value.mode !== "model" || !isNonEmptyString(value.model)) return false;
  return (value.provider === undefined || isNonEmptyString(value.provider))
    && Object.keys(value).every((key) => key === "mode" || key === "model" || key === "provider");
}

function normalizeModelTarget(value, fallback = { mode: "inherit" }) {
  if (!isModelTarget(value)) return fallback;
  if (value.mode === "inherit") return { mode: "inherit" };
  return {
    mode: "model",
    model: value.model.trim(),
    ...(value.provider === undefined ? {} : { provider: value.provider.trim() })
  };
}

function normalizeModelRoutes(value) {
  const input = isRecord(value) ? value : {};
  return Object.fromEntries(ROLES.map((role) => [
    role,
    normalizeModelTarget(input[role], DEFAULT_MODEL_TARGETS[role])
  ]));
}

function convertLegacyModels(value) {
  if (!isRecord(value)) return {};
  return Object.fromEntries(ROLES.flatMap((role) => {
    const model = value[role];
    return isNonEmptyString(model)
      ? [[role, { mode: "model", model: model.trim() }]]
      : [];
  }));
}

function missingLegacyRoutes(userValue, legacyValue) {
  const user = isRecord(userValue) ? userValue : {};
  const converted = convertLegacyModels(legacyValue);
  return Object.fromEntries(Object.entries(converted).filter(([role]) => user[role] === undefined));
}

function renderModelMapping(value) {
  const routes = normalizeModelRoutes(value);
  const entries = ROLES.map((role) => {
    const target = routes[role];
    if (target.mode === "inherit") return role + "=inherit";
    return role + "=" + (target.provider === undefined ? "" : target.provider + "/") + target.model;
  });
  return "<pstack_model_routes>" + entries.join("; ") + "</pstack_model_routes>";
}

const ModelTargetSchema = z.union([
  z.object({ mode: z.const("inherit") }),
  z.object({
    mode: z.const("model"),
    model: z.string().min(1),
    provider: z.string().min(1).required(false)
  })
]);

const PstackSettingsSchema = z.object({
  code: ModelTargetSchema.default(DEFAULT_MODEL_TARGETS.code),
  judgment: ModelTargetSchema.default(DEFAULT_MODEL_TARGETS.judgment),
  workers: ModelTargetSchema.default(DEFAULT_MODEL_TARGETS.workers)
});

module.exports = {
  ROLES,
  DEFAULT_MODEL_TARGETS,
  ModelTargetSchema,
  PstackSettingsSchema,
  isNonEmptyString,
  isModelTarget,
  normalizeModelTarget,
  normalizeModelRoutes,
  convertLegacyModels,
  missingLegacyRoutes,
  renderModelMapping
};
