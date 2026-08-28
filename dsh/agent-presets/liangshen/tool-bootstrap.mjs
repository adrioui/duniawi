











































































import { createEpochPromotion } from './compaction-epoch.mjs'


export const name = 'anchored-tool-bootstrap'












export const inject = []


const PROMOTE_EVENTS = {
  'tool-call': ['tool/call'],
  'assistant-message': ['assistant/message'],
  either: ['tool/call', 'assistant/message'],
}


const ALLOWED_KEYS = new Set(['bootstrapTools', 'promoteOn', 'bootstrapMaxTokens', 'suppressedContextSources', 'compactionTools', 'includeSubagents'])







const DEFAULT_SUPPRESSED_SOURCES = ['skill-catalog', 'agent-instructions']







const DEFAULT_BOOTSTRAP_TOOLS = ['bash', 'str_replace_editor']

function stringList(value, field) {
  if (!Array.isArray(value) || value.length === 0 || value.some((item) => typeof item !== 'string' || item.length === 0)) {
    throw new TypeError(`${name}: ${field} must be a non-empty array of non-empty strings`)
  }
  return [...new Set(value)]
}

function stringListOrEmpty(value, field) {
  if (value === undefined) return []
  return stringList(value, field)
}

function parsePromoteOn(value) {
  if (value === undefined || value === 'either') return PROMOTE_EVENTS.either
  if (value === 'tool-call' || value === 'assistant-message') return PROMOTE_EVENTS[value]
  throw new TypeError(`${name}: promoteOn must be one of "tool-call", "assistant-message", "either"; got ${JSON.stringify(value)}`)
}






function sourceList(value, field, fallback) {
  if (value === undefined) return new Set(fallback)
  if (!Array.isArray(value) || value.some((item) => typeof item !== 'string' || item.length === 0)) {
    throw new TypeError(`${name}: ${field} must be an array of non-empty strings`)
  }
  return new Set(value)
}







function optionalPositiveInt(value, field) {
  if (value === undefined) return undefined
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new TypeError(`${name}: ${field} must be a positive safe integer`)
  }
  return value
}

function optionalBoolean(value, field) {
  if (value === undefined) return false
  if (typeof value !== 'boolean') throw new TypeError(`${name}: ${field} must be a boolean`)
  return value
}


export function apply(ctx, config) {
  const source = config === undefined ? {} : config
  if (typeof source !== 'object' || source === null || Array.isArray(source)) {
    throw new TypeError(`${name}: config must be an object`)
  }
  const unknown = Object.keys(source).filter((key) => !ALLOWED_KEYS.has(key))
  if (unknown.length > 0) {
    throw new TypeError(
      `${name}: unknown config key(s) ${unknown.join(', ')} — allowed keys: ${[...ALLOWED_KEYS].sort().join(', ')}`,
    )
  }
  const bootstrapTools = stringList(source.bootstrapTools, 'bootstrapTools')
  const promoteEvents = parsePromoteOn(source.promoteOn)
  const bootstrapMaxTokens = optionalPositiveInt(source.bootstrapMaxTokens, 'bootstrapMaxTokens')
  const includeSubagents = optionalBoolean(source.includeSubagents, 'includeSubagents')
  const suppressedSources = sourceList(source.suppressedContextSources, 'suppressedContextSources', DEFAULT_SUPPRESSED_SOURCES)



  const compactionTools = stringListOrEmpty(source.compactionTools, 'compactionTools')

  const promotion = createEpochPromotion(promoteEvents, { includeSubagents })
  ctx.on('session/event', (session, event) => promotion.observe(session, event))

  let warned = false
  const warnOnce = (message) => {
    if (warned) return
    warned = true
    try {
      ctx.logger.warn(message)
    } catch {

    }
  }

  
  const keepTools = (assembled, keep, missingAllowsFullCatalog) => {
    const available = new Set(assembled.tools.map((tool) => tool.name))
    const missing = [...keep].filter((toolName) => !available.has(toolName))
    if (missing.length > 0) {
      warnOnce(
        `${name}: expected every phase tool; missing=${JSON.stringify(missing)} — `
        + (missingAllowsFullCatalog ? 'bootstrap disabled, full catalog exposed' : 'continuing with what is available'),
      )
      if (missingAllowsFullCatalog) return assembled
    }
    return {
      ...assembled,
      tools: assembled.tools.filter((tool) => keep.has(tool.name)),
    }
  }

  ctx.on('system-prompt/assemble', async (_assembly, context, next) => {

    const assembled = await next()
    try {
      const status = promotion.status(context.agent)
      if (status.promoted) {

        return assembled
      }


      const { boundary } = status
      const keep = new Set(bootstrapTools)
      if (boundary >= 0) for (const toolName of compactionTools) keep.add(toolName)
      return keepTools(assembled, keep, true)
    } catch (error) {

      warnOnce(`${name}: bootstrap filter failed, exposing the full catalog: ${String((error && error.message) || error)}`)
      return assembled
    }
  })




  if (bootstrapMaxTokens !== undefined) {






    ctx.on('agent/request', async (payload, next) => {
      const resolved = await next()
      const agent = payload.agent
      if (promotion.status(agent).promoted) {



        if (resolved.maxTokens === bootstrapMaxTokens) {
          const { maxTokens: _bootstrap, ...rest } = resolved
          return rest
        }
        return resolved
      }
      return {
        ...resolved,
        maxTokens: bootstrapMaxTokens,
      }
    }, { prepend: true })
  }






  ctx.on('agent/pre-step', async ({ agent }, next) => {

    const decision = await next()
    if (decision.kind === 'reject') return decision
    try {
      if (promotion.status(agent).promoted || suppressedSources.size === 0) return decision
      if (!Array.isArray(decision.messages)) return decision
      const kept = decision.messages.filter((message) => {
        const kind = message?.source?.kind
        return typeof kind !== 'string' || !suppressedSources.has(kind)
      })
      return kept.length === decision.messages.length ? decision : { ...decision, messages: kept }
    } catch (error) {

      warnOnce(`${name}: pre-step context filter failed, keeping injected context: ${String((error && error.message) || error)}`)
      return decision
    }
  }, { prepend: true })
}
