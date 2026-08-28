window.__ModuleLoader__.load({
  id: "@wayanjimmy/dsh-pstack",
  factory: (require) => {
    var module = { exports: {} };
    var exports = module.exports;
    Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });
    const React = require("react");
    const { createElement, useEffect, useMemo, useState, useSyncExternalStore } = React;

    const SETTINGS_NS = "pstack";
    const ROLES = [
      { key: "code", label: "Code", detail: "Everyday implementation and code-oriented exploration." },
      { key: "judgment", label: "Judgment", detail: "Architecture, review panels, forensics, and orchestration." },
      { key: "workers", label: "Workers", detail: "Cheap parallel sweeps and batch work." },
    ];
    const inject = ["slots", "settingsScope"];

    const rowStyle = { padding: "14px 0", borderTop: "1px solid var(--dsw-alias-border-l2, rgba(128,128,128,.22))" };
    const inputStyle = { boxSizing: "border-box", width: "100%", padding: "8px 10px", borderRadius: "7px", border: "1px solid var(--dsw-alias-border-l2, rgba(128,128,128,.35))", background: "transparent", color: "inherit", font: "inherit" };
    const labelStyle = { display: "block", fontSize: "12px", fontWeight: 600, marginBottom: "6px" };

    function normalizedTarget(value) {
      if (value && value.mode === "inherit") return { mode: "inherit" };
      return {
        mode: "model",
        model: value && typeof value.model === "string" ? value.model : "",
        provider: value && typeof value.provider === "string" ? value.provider : "",
      };
    }

    function routeLabel(value) {
      const target = normalizedTarget(value);
      if (target.mode === "inherit") return "Current chat model";
      return (target.provider ? target.provider + "/" : "") + target.model;
    }

    function RouteEditor({ role, value, overridden, writable, catalog, onSave, onReset }) {
      const [draft, setDraft] = useState(() => normalizedTarget(value));
      const [saving, setSaving] = useState(false);
      const [error, setError] = useState("");

      useEffect(() => setDraft(normalizedTarget(value)), [value]);

      const providerModels = useMemo(() => {
        if (!catalog || !Array.isArray(catalog.groups)) return [];
        if (draft.provider) {
          const group = catalog.groups.find((item) => item.id === draft.provider);
          return group && Array.isArray(group.models) ? group.models : [];
        }
        const seen = new Set();
        const models = [];
        for (const group of catalog.groups) {
          for (const model of group.models || []) {
            if (seen.has(model.id)) continue;
            seen.add(model.id);
            models.push(model);
          }
        }
        return models;
      }, [catalog, draft.provider]);

      const dirty = JSON.stringify(normalizedTarget(value)) !== JSON.stringify(draft);
      const save = async () => {
        if (draft.mode === "model" && !draft.model.trim()) {
          setError("Choose or enter a model id.");
          return;
        }
        setSaving(true);
        setError("");
        const target = draft.mode === "inherit"
          ? { mode: "inherit" }
          : { mode: "model", model: draft.model.trim(), ...(draft.provider.trim() ? { provider: draft.provider.trim() } : {}) };
        try { await onSave(target); }
        catch (cause) { setError(cause instanceof Error ? cause.message : String(cause)); }
        finally { setSaving(false); }
      };
      const reset = async () => {
        setSaving(true);
        setError("");
        try { await onReset(); }
        catch (cause) { setError(cause instanceof Error ? cause.message : String(cause)); }
        finally { setSaving(false); }
      };

      return createElement("div", { style: rowStyle },
        createElement("div", { style: { display: "flex", justifyContent: "space-between", gap: "16px", alignItems: "baseline" } },
          createElement("div", null,
            createElement("strong", { style: { fontSize: "13px" } }, role.label),
            createElement("div", { style: { marginTop: "3px", opacity: .68, fontSize: "12px" } }, role.detail),
          ),
          createElement("span", { style: { opacity: .72, fontSize: "12px", whiteSpace: "nowrap" } }, (overridden ? "Modified · " : "") + routeLabel(value)),
        ),
        createElement("div", { style: { display: "grid", gridTemplateColumns: "140px minmax(130px, .8fr) minmax(180px, 1.2fr)", gap: "8px", marginTop: "12px" } },
          createElement("div", null,
            createElement("label", { style: labelStyle }, "Route"),
            createElement("select", { value: draft.mode, disabled: saving || !writable, onChange: (event) => setDraft((current) => ({ ...current, mode: event.target.value })), style: inputStyle },
              createElement("option", { value: "model" }, "Configured model"),
              createElement("option", { value: "inherit" }, "Current chat model"),
            ),
          ),
          createElement("div", null,
            createElement("label", { style: labelStyle }, "Provider"),
            createElement("select", { value: draft.provider, disabled: saving || !writable || draft.mode === "inherit", onChange: (event) => setDraft((current) => ({ ...current, provider: event.target.value })), style: inputStyle },
              createElement("option", { value: "" }, "Current provider"),
              ...((catalog && catalog.groups) || []).map((group) => createElement("option", { key: group.id, value: group.id }, group.name || group.id)),
            ),
          ),
          createElement("div", null,
            createElement("label", { style: labelStyle }, "Model"),
            createElement("input", { list: "pstack-models-" + role.key, value: draft.model, disabled: saving || !writable || draft.mode === "inherit", onChange: (event) => setDraft((current) => ({ ...current, model: event.target.value })), placeholder: "model id", style: inputStyle }),
            createElement("datalist", { id: "pstack-models-" + role.key }, ...providerModels.map((model) => createElement("option", { key: model.id, value: model.id }, model.name || model.id))),
          ),
        ),
        error ? createElement("p", { style: { color: "#e5484d", fontSize: "12px", margin: "8px 0 0" } }, error) : null,
        createElement("div", { style: { display: "flex", justifyContent: "flex-end", gap: "8px", marginTop: "10px" } },
          overridden ? createElement("button", { type: "button", disabled: saving || !writable, onClick: reset }, "Reset") : null,
          createElement("button", { type: "button", disabled: saving || !writable || !dirty, onClick: save }, saving ? "Saving…" : "Save"),
        ),
      );
    }

    function PstackSettingsCard({ scope }) {
      const snapshot = useSyncExternalStore(
        (listener) => scope.subscribe(listener),
        () => scope.getSnapshot(),
        () => scope.getSnapshot(),
      );
      const [open, setOpen] = useState(false);
      const [catalog, setCatalog] = useState(null);
      const [catalogError, setCatalogError] = useState("");

      useEffect(() => {
        if (!open || catalog) return;
        let active = true;
        fetch("/pstack/models", { cache: "no-store" })
          .then((response) => response.ok ? response.json() : Promise.reject(new Error("Model catalog request failed")))
          .then((value) => { if (active) setCatalog(value); })
          .catch((cause) => { if (active) setCatalogError(cause instanceof Error ? cause.message : String(cause)); });
        return () => { active = false; };
      }, [open, catalog]);

      if (snapshot.status !== "ready") return null;
      const value = snapshot.value || {};
      const user = snapshot.user && typeof snapshot.user === "object" ? snapshot.user : {};
      const modified = ROLES.some((role) => Object.prototype.hasOwnProperty.call(user, role.key));

      return createElement("li", { style: { listStyle: "none", border: "1px solid var(--dsw-alias-border-l2, rgba(128,128,128,.25))", borderRadius: "10px", overflow: "hidden" } },
        createElement("button", { type: "button", onClick: () => setOpen((current) => !current), style: { width: "100%", padding: "14px 16px", border: 0, background: "transparent", color: "inherit", cursor: "pointer", textAlign: "left", display: "flex", justifyContent: "space-between", gap: "16px" } },
          createElement("span", null,
            createElement("strong", { style: { display: "block", fontSize: "14px" } }, "pstack"),
            createElement("span", { style: { display: "block", marginTop: "4px", opacity: .7, fontSize: "12px" } }, "Model routes for code, judgment, and parallel workers."),
          ),
          createElement("span", { style: { opacity: .7 } }, (modified ? "Modified · " : "") + (open ? "▴" : "▾")),
        ),
        open ? createElement("div", { style: { borderTop: "1px solid var(--dsw-alias-border-l2, rgba(128,128,128,.25))", padding: "0 16px 16px" } },
          catalogError ? createElement("p", { style: { color: "#d99a2b", fontSize: "12px" } }, catalogError + ". You can still enter provider and model ids manually.") : null,
          catalog && Array.isArray(catalog.failures) && catalog.failures.length > 0 ? createElement("p", { style: { color: "#d99a2b", fontSize: "12px" } }, catalog.failures.length + " provider catalog" + (catalog.failures.length === 1 ? "" : "s") + " unavailable.") : null,
          ...ROLES.map((role) => createElement(RouteEditor, {
            key: role.key,
            role,
            value: value[role.key],
            overridden: Object.prototype.hasOwnProperty.call(user, role.key),
            writable: snapshot.writable,
            catalog,
            onSave: (target) => scope.set(role.key, target),
            onReset: () => scope.unset(role.key),
          })),
        ) : null,
      );
    }

    function apply(ctx) {
      const settings = ctx.settingsScope.bind({ namespace: SETTINGS_NS });
      ctx.slots.inject("settings.plugin.item", () => ctx.slots.register({
        name: "settings.plugin.item",
        key: SETTINGS_NS,
        inject: () => ({ scope: settings }),
      }, PstackSettingsCard));
    }

    exports.apply = apply;
    exports.inject = inject;
    return module.exports;
  }
});
