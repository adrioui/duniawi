


































import { createHash } from 'node:crypto'
import { realpathSync } from 'node:fs'
import { createRequire } from 'node:module'
import { homedir } from 'node:os'
import { join } from 'node:path'
import { renderMermaidASCII } from 'beautiful-mermaid'


export const name = 'tui-mermaid'





export const EVENT_TYPE = 'mermaid/diagram'




export const inject = ['tuiRenderers']












function asRecord(value) {

  return typeof value === 'object' && value !== null ? value : undefined
}


function asString(value) {

  return typeof value === 'string' && value.length > 0 ? value : undefined
}





const MAX_BLOCKS = 5
const MAX_SOURCE_LINES = 400
const MAX_SOURCE_CHARS = 20000


const ASCII_PRESETS = [
  { key: 'default', paddingX: 5, boxBorderPadding: 1 },
  { key: 'compact', paddingX: 3, boxBorderPadding: 1 },
  { key: 'tight', paddingX: 2, boxBorderPadding: 1 },
  { key: 'squeezed', paddingX: 1, boxBorderPadding: 0 },
]


const MAX_RENDER_LINES = 40





function extractText(content) {
  const direct = asString(content)
  if (direct !== undefined) return direct
  if (!Array.isArray(content)) return ''
  const parts = []
  for (const block of content) {
    const record = asRecord(block)
    if (record?.type !== 'text') continue
    const text = asString(record.text)
    if (text !== undefined) parts.push(text)
  }
  return parts.join('\n')
}

function extractMermaidBlocks(text) {





  const blockRe = /```mermaid(?![^\s`])[^\n]*\n([\s\S]*?)```/gi
  const blocks = []
  let match
  while ((match = blockRe.exec(text)) !== null) {
    const code = match[1] ? match[1].trim() : ''
    if (code) blocks.push(code)
    if (blocks.length >= MAX_BLOCKS) break
  }
  return blocks
}

function hashMermaid(block) {
  return createHash('sha256').update(block).digest('hex').slice(0, 8)
}


function maxLineWidth(ascii) {
  let max = 0
  for (const line of ascii.split(/\r?\n/)) {
    if (line.length > max) max = line.length
  }
  return max
}


function renderVariants(block) {
  const variants = []
  let lastError
  for (const preset of ASCII_PRESETS) {
    try {
      const ascii = renderMermaidASCII(block, {
        paddingX: preset.paddingX,
        boxBorderPadding: preset.boxBorderPadding,
        colorMode: 'none',
      }).trimEnd()
      variants.push({ key: preset.key, ascii, maxLineWidth: maxLineWidth(ascii) })
    } catch (error) {
      lastError = error
    }
  }
  if (variants.length === 0) {
    throw lastError ?? new Error('No ASCII variant rendered')
  }
  return variants
}


function buildPayload(block, index) {
  const hash = hashMermaid(block)
  try {
    return {
      hash,
      index,
      sourceLines: block.split(/\r?\n/).length,
      variants: renderVariants(block),
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    return {
      hash,
      index,
      sourceLines: block.split(/\r?\n/).length,
      variants: [],
      issues: [{ severity: 'error', message: 'render failed: ' + message }],
    }
  }
}





const PERSISTENCE_PACKAGE = '@deepseek-ai/dsh-session-persistence'
const SESSION_PACKAGE = '@deepseek-ai/dsh-session'


const registered = new Set()

function registerSessionCopy(req) {
  try {
    const resolved = req.resolve(SESSION_PACKAGE)
    let key = resolved
    try {
      key = realpathSync(resolved)
    } catch {

    }
    if (registered.has(key)) return
    registered.add(key)
    req(resolved).KNOWN_SESSION_EVENT_TYPES?.add(EVENT_TYPE)
  } catch {

  }
}








function mountedProfileAnchor(dshHome) {
  const argv = process.argv
  let profile
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i]
    if (arg === '--profile') profile = argv[i + 1]
    else if (arg.startsWith('--profile=')) profile = arg.slice('--profile='.length)
    if (profile !== undefined) break
  }
  if (profile === undefined || profile === '' || profile.startsWith('-')) return undefined
  return join(dshHome, 'profiles', profile, 'node_modules', '_dsh-tui-mermaid-anchor.js')
}














export function registerEventType() {
  const dshHome = process.env.DSH_HOME || join(homedir(), '.dsh')
  const anchors = [import.meta.url, process.argv[1], mountedProfileAnchor(dshHome)]
    .map(asString)
    .filter((anchor) => anchor !== undefined)

  for (const anchor of anchors) {
    let req
    try {
      req = createRequire(anchor)
    } catch {
      continue
    }
    registerSessionCopy(req)
    try {
      registerSessionCopy(createRequire(req.resolve(PERSISTENCE_PACKAGE)))
    } catch {

    }
  }
}






function selectVariant(payload, width) {
  const variants = Array.isArray(payload?.variants) ? payload.variants : []
  if (variants.length === 0) return undefined
  const fitting = variants.find((variant) => variant.maxLineWidth <= width)
  if (fitting) return { variant: fitting, clipped: false }
  return { variant: variants[variants.length - 1], clipped: true }
}






export function renderEntry(payload) {
  const record = asRecord(payload)
  const hash = record === undefined ? undefined : asString(record.hash)
  if (record === undefined || hash === undefined) return undefined

  const lines = []
  const reportedIssues = Array.isArray(record.issues) ? record.issues : []
  for (const issue of reportedIssues) {
    const issueRecord = asRecord(issue)
    const message = issueRecord === undefined ? undefined : asString(issueRecord.message)
    if (message !== undefined) {
      const tag = issueRecord.severity === 'error' ? 'error' : 'warning'
      lines.push('[mermaid:' + tag + '] ' + message)
    }
  }

  const width = Math.max(20, Number(process.stdout?.columns) || 100)
  const selection = selectVariant(record, width)

  if (!selection) {
    lines.push('(diagram ' + hash + ': not rendered)')
  } else {
    const allLines = selection.variant.ascii.split(/\r?\n/)
    const visible = allLines.slice(0, MAX_RENDER_LINES)
    lines.push(...visible)
    if (allLines.length > visible.length) {
      lines.push('... (' + (allLines.length - visible.length) + ' more lines · diagram ' + hash + ')')
    }
    if (selection.clipped) {
      lines.push('... (clipped to fit width; widen terminal for full detail)')
    }
  }

  return { title: '◆ Mermaid (ASCII) · ' + hash, lines }
}





function resolveConfig(config) {
  const cfg = asRecord(config)
  return {
    enabled: cfg?.enabled !== false,
  }
}






export function apply(ctx, config = {}) {
  const resolved = resolveConfig(config)




  registerEventType()




  try {
    ctx.get('tuiRenderers', false)?.register(EVENT_TYPE, renderEntry, ctx)
  } catch {

  }



  if (!resolved.enabled) return

  ctx.on('session/event', (session, event) => {
    if (event?.type !== 'assistant/message') return
    const text = extractText(event.data?.message?.content)
    if (!text.includes('```mermaid')) return

    const blocks = extractMermaidBlocks(text)
    if (blocks.length === 0) return



    queueMicrotask(() => {
      for (const [index, block] of blocks.entries()) {
        const sourceLines = block.split(/\r?\n/).length

        if (sourceLines > MAX_SOURCE_LINES || block.length > MAX_SOURCE_CHARS) continue
        try {
          session.append(EVENT_TYPE, buildPayload(block, index + 1))
        } catch {

        }
      }
    })
  })
}
