/**
 * dsh-model-autodiscover: omp-style automatic model discovery for llm-pi-ai
 * routes.
 *
 * dsh deliberately keeps a route's model catalog static ("A route's catalog
 * never refreshes itself", dsh-llm-pi-ai § Known Limitations): hand-declared
 * OpenAI-compatible gateways serve exactly the models listed in configuration,
 * so every provider refresh means hand-editing cordis.patch.yml. The harness
 * already ships the two halves needed to close that gap — they are just never
 * connected:
 *
 *   1. ctx.llm.discoverModels('llm-pi-ai', request) interrogates an endpoint's
 *      GET /models listing (bearer auth, 4 MiB ceiling) — but only as a
 *      one-shot draft probe for configuration surfaces; nothing is stored.
 *   2. ctx.settings.update('llm-pi-ai', patch) persists into the user layer,
 *      which deep-merges over the composition base per provider and
 *      hot-applies to the running adapter without a restart.
 *
 * This plugin connects them on a TTL, mirroring what omp's model_cache does
 * for its own providers: periodically ask each configured gateway which models
 * it advertises, merge the answer with the metadata you hand-authored (your
 * contextWindow / reasoningEfforts / compat corrections always win), and adopt
 * the result into the llm-pi-ai user layer so /model sees it immediately.
 *
 * Config (patch entry):
 *
 *   - insert:
 *       - id: dsh-model-autodiscover
 *         name: '@dsh-local/dsh-model-autodiscover'
 *         config:
 *           routes:
 *             bitdeer-ai: {}                       # defaults: live listing, 24 h TTL, prune
 *             openrouter:
 *               refreshHours: 168                  # weekly
 *               source: catalog                    # 'endpoint' (live listing) | 'catalog' (pin pi-ai's bundled catalog)
 *               pruneRemoved: false                # keep ids the endpoint stopped listing
 *
 * Routes must exist in the resolved llm-pi-ai providers dict. Everything here
 * is best-effort: any failure logs a warning and retries later; the harness
 * never sees an error.
 */

import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { homedir } from 'node:os'
/** Host-access requires declaring every service property the plugin reads;
 *  undeclared reads throw `cannot get property ... without inject`. */
export const inject = ['settings', 'llm', 'credentials']
export const name = 'dsh-model-autodiscover'


const NS = "llm-pi-ai"
const DEFAULT_REFRESH_HOURS = 24
/** Backoff while the pi-ai adapter has not registered its discovery offer yet. */
const READY_DELAYS_MS = [2000, 8000, 30000]

/** Endpoint rows that can never answer a chat completion: image generation,
 *  embeddings, rerankers, audio, moderation. OpenAI-compatible /models
 *  listings do not distinguish them from chat models, and adopting them puts
 *  dead entries in /model that fail on first use. Matched against the raw id,
 *  case-insensitively; vision chat models (VL, -vision) intentionally pass. */
const NON_CHAT_PATTERNS = [
  /embed/i,
  /rerank/i,
  /\bbge[-_]/i,
  /\bflux\b|\bflux[.\-_]/i,
  /\bimagen\b/i,
  /seedream/i,
  /flash-image/i,
  /stable-diffusion/i,
  /dall-e/i,
  /\btts\b/i,
  /\bwhisper\b/i,
  /\bmoderation\b/i,
]

/** Route-level escape hatch: `chatOnly: false` adopts everything the
 *  endpoint lists; `exclude: ["regex"]` adds patterns on top. */
function isNonChat(id, options) {
  if (options.chatOnly === false) return false
  const extra = (options.exclude ?? []).map(pattern => new RegExp(pattern, 'i'))
  return [...NON_CHAT_PATTERNS, ...extra].some(pattern => pattern.test(id))
}

function dshHome() {
  return process.env.DSH_HOME || join(homedir(), '.dsh')
}

function statePath() {
  return join(dshHome(), 'cache', 'dsh-model-autodiscover', 'state.json')
}

async function loadState() {
  try {
    return JSON.parse(await readFile(statePath(), 'utf8'))
  } catch {
    return {}
  }
}

/** Append one diagnostic line next to the state file; never throws. */
async function diag(message) {
  try {
    const path = join(dshHome(), 'cache', 'dsh-model-autodiscover', 'diagnostics.log')
    await mkdir(dirname(path), { recursive: true })
    await writeFile(path, `${new Date().toISOString()} ${message}\n`, { flag: 'a' })
  } catch { /* diagnostics are best-effort */ }
}

async function saveState(state) {
  try {
    const path = statePath()
    await mkdir(dirname(path), { recursive: true })
    await writeFile(path, `${JSON.stringify(state, null, 2)}\n`, 'utf8')
  } catch { /* cache loss only costs one extra refresh */ }
}

/** Resolve a route's credential through the seam, falling back to the environment. */
async function resolveApiKey(ctx, apiKeyEnv) {
  if (!apiKeyEnv) return undefined
  try {
    const resolved = await ctx.credentials?.resolve(apiKeyEnv)
    return resolved?.value ?? process.env[apiKeyEnv]
  } catch {
    return process.env[apiKeyEnv]
  }
}

function readSection(ctx) {
  try {
    return ctx.settings.get(NS)
  } catch {
    // Namespace not registered yet (adapter still mounting or dormant).
    return undefined
  }
}

/**
 * Merge an endpoint listing with the currently configured models: discovered
 * ids define membership and order; hand-authored fields of a surviving id win
 * over endpoint-disclosed values (they are deliberate corrections); new ids
 * arrive bare and take the route's default capacities.
 */
/** Copy a configured model's authored fields (never the id): hand-authored
 *  corrections always win over endpoint-disclosed values. */
function definedFields(value) {
  const out = {}
  for (const [key, field] of Object.entries(value)) {
    if (field !== undefined && key !== 'id') out[key] = field
  }
  return out
}
/** Keep only fields the endpoint actually disclosed. Writing structural
 *  empties (`input: []`, `compat: {}`) into settings would freeze them as
 *  declarations and override the route/schema defaults that a missing field
 *  would otherwise fall through to. */
function disclosedFields(value) {
  const out = {}
  for (const [key, field] of Object.entries(value)) {
    if (field === undefined || field === null || key === 'id') continue
    const emptyObject = typeof field === 'object' && !Array.isArray(field) && Object.keys(field).length === 0
    const emptyArray = Array.isArray(field) && field.length === 0
    if (emptyObject || emptyArray) continue
    out[key] = field
  }
  return out
}
function mergeModels(currentModels, discovered, pruneRemoved) {
  const currentById = new Map((currentModels ?? []).map(model => [model.id, model]))
  const merged = discovered.map((discoveredModel) => {
    const disclosed = disclosedFields(discoveredModel)
    const previous = currentById.get(disclosed.id)
    return previous ? { ...disclosed, ...definedFields(previous) } : disclosed
  })
  if (!pruneRemoved) {
    const seen = new Set(merged.map(model => model.id))
    for (const model of currentModels ?? []) {
      if (!seen.has(model.id)) merged.push(model)
    }
  }
  return merged
}

export function apply(ctx, config = {}) {
  void diag(`apply: routes=${Object.keys(config.routes ?? {}).join(',') || '(none)'}`)
  const routes = config.routes ?? {}
  const log = message => { void diag(message); ctx.logger?.info(`model-autodiscover: ${message}`) }
  const warn = message => { void diag(`WARN ${message}`); ctx.logger?.warn(`model-autodiscover: ${message}`) }

  /** One pending timer per route: a re-schedule replaces, never stacks. */
  const timers = new Map()
  const readyAttempts = new Map()
  let disposed = false
  function schedule(route, fn, delayMs) {
    if (disposed) return
    clearTimeout(timers.get(route))
    timers.set(route, setTimeout(() => {
      timers.delete(route)
      void fn()
    }, delayMs))
  }

  async function refreshRoute(route, options, state) {
    const section = readSection(ctx)
    const profile = section?.providers?.[route]
    await diag(`refresh ${route}: section=${section ? 'present' : 'absent'} profile=${profile ? 'found' : 'missing'}`)
    if (!profile) throw Object.assign(new Error(`no llm-pi-ai provider route "${route}"`), { code: 'NO_ROUTE' })
    if (options.source !== 'catalog' && !profile.baseURL) {
      warn(`${route}: profile names no baseURL; nothing to interrogate`)
      return
    }

    const apiKey = await resolveApiKey(ctx, profile.apiKeyEnv)
    // source 'endpoint' omits the route name on purpose: naming an existing
    // route makes the adapter answer from whatever configuration already
    // says, which is exactly the staleness this plugin exists to fix.
    const request = { baseURL: profile.baseURL, api: profile.api }
    if (options.source === 'catalog') request.provider = route
    if (apiKey !== undefined) request.apiKey = apiKey

    if (!ctx.llm?.discoverModels) throw Object.assign(new Error('llm seam unavailable'), { code: 'NO_DISCOVERY' })
    const discovered = await ctx.llm.discoverModels(NS, request)
    await diag(`refresh ${route}: discovered=${Array.isArray(discovered) ? discovered.length : 'non-array'}`)
    if (!Array.isArray(discovered) || discovered.length === 0) {
      warn(`${route}: endpoint answered an empty listing; keeping current models`)
      return
    }
    const usable = discovered.filter(model => !isNonChat(String(model?.id ?? ''), options))
    const excluded = discovered.length - usable.length
    if (excluded > 0) log(`${route}: filtered ${excluded} non-chat endpoint rows (image gen / embed / rerank)`)
    if (usable.length === 0) {
      warn(`${route}: every listed row filtered as non-chat; keeping current models`)
      return
    }

    const merged = mergeModels(profile.models, usable, options.pruneRemoved)
    const fingerprint = JSON.stringify(merged.map(model => model.id))
    const currentFingerprint = JSON.stringify((profile.models ?? []).map(model => model.id))

    if (fingerprint !== currentFingerprint) {
      await ctx.settings.update(NS, { providers: { [route]: { models: merged } } })
      log(`${route}: adopted ${merged.length} models from ${profile.baseURL}/models`)
    } else {
      log(`${route}: model list already current (${merged.length} models)`)
    }
    state[route] = { updatedAt: Date.now(), fingerprint }
    await saveState(state)
  }

  async function refreshRouteGuarded(route) {
    const options = { refreshHours: DEFAULT_REFRESH_HOURS, source: 'endpoint', pruneRemoved: true, chatOnly: true, ...routes[route] }
    const state = await loadState()
    const ageHours = (Date.now() - (state[route]?.updatedAt ?? 0)) / 3_600_000
    if (ageHours < options.refreshHours) {
      schedule(route, () => void refreshRouteGuarded(route), (options.refreshHours - ageHours) * 3_600_000)
      return
    }

    try {
      await refreshRoute(route, options, state)
      readyAttempts.delete(route)
    } catch (error) {
      // Both codes mean "the seam this route needs is not up yet": the
      // settings document still loading, or the pi-ai adapter not having
      // registered its discovery offer. Patch entries activate concurrently,
      // so escalate through the boot backoff before giving up to the TTL.
      const transient = error?.code === 'NO_DISCOVERY' || error?.code === 'NO_ROUTE'
      if (transient) {
        const attempt = readyAttempts.get(route) ?? 0
        if (attempt < READY_DELAYS_MS.length) {
          readyAttempts.set(route, attempt + 1)
          schedule(route, () => void refreshRouteGuarded(route), READY_DELAYS_MS[attempt])
          return
        }
        warn(`${route}: ${error.message}; giving up until the next TTL`)
      } else {
        warn(`${route}: discovery failed (${error?.message ?? error}); retrying after the TTL`)
      }
      readyAttempts.delete(route)
    }
    schedule(route, () => void refreshRouteGuarded(route), options.refreshHours * 3_600_000)
  }

  const routeNames = Object.keys(routes)
  if (routeNames.length === 0) return

  log(`tracking ${routeNames.join(', ')}`)
  // Stagger initial probes so several routes never burst the same instant.
  routeNames.forEach((route, index) => {
    schedule(route, () => void refreshRouteGuarded(route), 1500 + index * 1000)
  })

  // A changed route set (patch edit, dormant→mounted adapter) re-runs a route
  // whose readiness is still unresolved; settled routes wait for their TTL.
  ctx.on('llm/adapters-updated', () => {
    for (const route of routeNames) {
      if (!timers.has(route) || readyAttempts.has(route)) {
        schedule(route, () => void refreshRouteGuarded(route), 5000)
      }
    }
  })

  ctx.effect(
    () => () => {
      disposed = true
      for (const timer of timers.values()) clearTimeout(timer)
      timers.clear()
    },
    'dsh-model-autodiscover timers on dispose',
  )
}
