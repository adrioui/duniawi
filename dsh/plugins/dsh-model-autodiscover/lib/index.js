









































import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { homedir } from 'node:os'


export const inject = ['settings', 'llm', 'credentials']
export const name = 'dsh-model-autodiscover'


const NS = "llm-pi-ai"
const DEFAULT_REFRESH_HOURS = 24

const READY_DELAYS_MS = [2000, 8000, 30000]






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


async function diag(message) {
  try {
    const path = join(dshHome(), 'cache', 'dsh-model-autodiscover', 'diagnostics.log')
    await mkdir(dirname(path), { recursive: true })
    await writeFile(path, `${new Date().toISOString()} ${message}\n`, { flag: 'a' })
  } catch {  }
}

async function saveState(state) {
  try {
    const path = statePath()
    await mkdir(dirname(path), { recursive: true })
    await writeFile(path, `${JSON.stringify(state, null, 2)}\n`, 'utf8')
  } catch {  }
}


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

    return undefined
  }
}









function definedFields(value) {
  const out = {}
  for (const [key, field] of Object.entries(value)) {
    if (field !== undefined && key !== 'id') out[key] = field
  }
  return out
}




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

  routeNames.forEach((route, index) => {
    schedule(route, () => void refreshRouteGuarded(route), 1500 + index * 1000)
  })



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
