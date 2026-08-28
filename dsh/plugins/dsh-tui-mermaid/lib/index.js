/**
 * dsh-tui-mermaid — render mermaid code fences in assistant messages as
 * ASCII art inline in the DeepSeek Harness terminal TUI.
 *
 * Port of pi-mermaid (github.com/Gurpartap/pi-mermaid, MIT) to the dsh
 * plugin shape. Upstream hooks pi's input/agent_end events and registers a
 * custom message renderer; dsh's equivalent seams are:
 *
 * - ctx.on('session/event') for assistant/message — the durable stream
 *   event carrying the completed assistant message (data.message.content
 *   blocks with type 'text' or 'reasoning' plus their text);
 * - session.append('mermaid/diagram', payload) — a log-only session event
 *   (never a surface event), so the diagram survives resume/replay;
 * - ctx.tuiRenderers.register('mermaid/diagram', ...) — the TUI's custom
 *   session-entry renderer seam, which projects the payload into
 *   transcript rows live and on replay.
 *
 * Rendering uses beautiful-mermaid's synchronous, zero-DOM ASCII renderer,
 * the same library as upstream. Width-awareness is preserved by rendering
 * several padding presets at append time and letting the renderer pick the
 * widest one that fits the current terminal width.
 *
 * Deviations from upstream (documented, deliberate):
 * - No mermaid-parser pre-validation: the mermaid npm package needs a DOM
 *   in Node; upstream treats it as optional and renders anyway. We always
 *   render and surface render failures as error-issue rows instead.
 * - No user-input rendering or slash command: assistant output only, v1.
 *
 * Caveat: appended events make sessions containing them unreadable by log
 * readers that do not load this plugin (the web profile's strict reader
 * refuses unknown non-ignorable types). Install this plugin into any other
 * profile whose client reads the same session logs, or keep diagrams-only
 * sessions in the TUI.
 */

import { createHash } from 'node:crypto'
import { realpathSync } from 'node:fs'
import { createRequire } from 'node:module'
import { homedir } from 'node:os'
import { join } from 'node:path'
import { renderMermaidASCII } from 'beautiful-mermaid'

/** Cordis plugin name used by loader diagnostics. */
export const name = 'tui-mermaid'

/**
 * The session-event type this plugin publishes and renders. Same
 * plugin/event shape the session-log strict registry expects.
 */
export const EVENT_TYPE = 'mermaid/diagram'

/** Requires the TUI extensions row; cordis delays apply until it is live,
 * * which also puts registration inside a live plugin activation (the seam
 * * requires callers to register during apply, not from event callbacks). */
export const inject = ['tuiRenderers']

// ---------------------------------------------------------------------------
// Boundary decoders
//
// Every value this plugin reads arrives unparsed over the session-event bus
// (assistant message content, patch configs, renderer payloads). These are
// the ONLY places representation checks happen: each helper is the named,
// single decoding seam for one shape, so call sites branch on decoded
// results instead of re-narrowing representations inline.
// ---------------------------------------------------------------------------

/** Decode an unknown value into a plain object record, or undefined. */
function asRecord(value) {
  // oxlint-disable-next-line anti-slop/no-runtime-typeof -- I/O boundary: session-event payloads arrive as raw JSON; this is the decode seam for the record shape.
  return typeof value === 'object' && value !== null ? value : undefined
}

/** Decode an unknown value into a non-empty string, or undefined. */
function asString(value) {
  // oxlint-disable-next-line anti-slop/no-runtime-typeof -- I/O boundary: message content blocks arrive as raw JSON; this is the decode seam for the text shape.
  return typeof value === 'string' && value.length > 0 ? value : undefined
}

// ---------------------------------------------------------------------------
// Limits and caches (upstream parity)
// ---------------------------------------------------------------------------

const MAX_BLOCKS = 5
const MAX_SOURCE_LINES = 400
const MAX_SOURCE_CHARS = 20000

/** Rendering presets tried widest-first; the tightest fits narrow terminals. */
const ASCII_PRESETS = [
  { key: 'default', paddingX: 5, boxBorderPadding: 1 },
  { key: 'compact', paddingX: 3, boxBorderPadding: 1 },
  { key: 'tight', paddingX: 2, boxBorderPadding: 1 },
  { key: 'squeezed', paddingX: 1, boxBorderPadding: 0 },
]

/** Transcript rows shown per diagram before an "... N more lines" hint. */
const MAX_RENDER_LINES = 40

// ---------------------------------------------------------------------------
// Extraction and rendering helpers
// ---------------------------------------------------------------------------

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
  // Fence opener requires "mermaid" as the whole language token (so
  // ```mermaidxyz never matches), lets an info-string follow on the same
  // line without entering the diagram source, and captures lazily to the
  // next closing fence. Local literal so lastIndex state never leaks
  // between calls.
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

/** Longest line of pre-rendered ASCII, for width-aware variant selection. */
function maxLineWidth(ascii) {
  let max = 0
  for (const line of ascii.split(/\r?\n/)) {
    if (line.length > max) max = line.length
  }
  return max
}

/** Render one block under every preset; returns [{ key, ascii, maxLineWidth }]. */
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

/** Lossless-JSON payload for one rendered block; optional fields are omitted. */
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

// ---------------------------------------------------------------------------
// Session-event type registration (ported from dsh-working-activity)
// ---------------------------------------------------------------------------

const PERSISTENCE_PACKAGE = '@deepseek-ai/dsh-session-persistence'
const SESSION_PACKAGE = '@deepseek-ai/dsh-session'

/** Realpaths already registered — require caches by realpath. */
const registered = new Set()

function registerSessionCopy(req) {
  try {
    const resolved = req.resolve(SESSION_PACKAGE)
    let key = resolved
    try {
      key = realpathSync(resolved)
    } catch {
      // Vanished between resolve and realpath — dedupe by the resolved path.
    }
    if (registered.has(key)) return
    registered.add(key)
    req(resolved).KNOWN_SESSION_EVENT_TYPES?.add(EVENT_TYPE)
  } catch {
    // No resolvable dsh-session copy from this anchor — nothing to register into.
  }
}

/**
 * Anchor at the profile tree that mounts us: `dsh --profile <name>` puts our
 * dsh-session copy under profiles/<name>/node_modules, and this plugin lives
 * OUTSIDE that tree (linked from ~/.dsh/plugins/), so its own anchor cannot
 * resolve it (working-activity gets this for free by living inside). Same
 * --profile argv convention as dsh-tui's resolveDshProfileName.
 */
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

/**
 * Register mermaid/diagram as a known session-event type in every reachable
 * dsh-session copy (the strict validators consult only THEIR copy's Set), so
 * append and resume never trip on an unknown type. Idempotent.
 *
 * Anchors — same shape as dsh-working-activity:
 * - this module's tree (covers in-profile installs);
 * - the process entry point, i.e. the CLI tree persistence resolves from;
 * - the mounted profile tree via --profile argv (see mountedProfileAnchor).
 * Each anchor also walks one edge through dsh-session-persistence, whose own
 * resolution can hit a further physical copy. A copy that cannot be resolved
 * simply is not there; registration never throws.
 */
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
      // No persistence package reachable from this anchor.
    }
  }
}

// ---------------------------------------------------------------------------
// Transcript projection (ctx.tuiRenderers)
// ---------------------------------------------------------------------------

/** Pick the widest variant fitting the given width, else the tightest. */
function selectVariant(payload, width) {
  const variants = Array.isArray(payload?.variants) ? payload.variants : []
  if (variants.length === 0) return undefined
  const fitting = variants.find((variant) => variant.maxLineWidth <= width)
  if (fitting) return { variant: fitting, clipped: false }
  return { variant: variants[variants.length - 1], clipped: true }
}

/**
 * Project one mermaid/diagram payload into transcript rows. Runs inside the
 * TUI process, so the live terminal width steers variant selection. Output
 * is sanitized/clipped further by the host, per the seam contract.
 */
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

// ---------------------------------------------------------------------------
// Plugin wiring
// ---------------------------------------------------------------------------

function resolveConfig(config) {
  const cfg = asRecord(config)
  return {
    enabled: cfg?.enabled !== false,
  }
}

/**
 * Wire the plugin.
 * @param ctx - Cordis context (agent loop + TUI services composed).
 * @param config - Optional profile patch config: { enabled?: boolean }.
 */
export function apply(ctx, config = {}) {
  const resolved = resolveConfig(config)

  // Register BEFORE anything can publish: strict readers refuse logs with
  // unknown non-ignorable types, and an unregistered append would make the
  // whole session unresumable.
  registerEventType()

  // The inject contract guarantees tuiRenderers is live before apply runs;
  // registering HERE also satisfies the seam's live-activation caller check
  // (registration from later event callbacks is silently refused).
  try {
    ctx.get('tuiRenderers', false)?.register(EVENT_TYPE, renderEntry, ctx)
  } catch {
    // Projection is best-effort; never block composition.
  }

  // Registration and projection stay active even when extraction is
  // disabled via config: previously logged diagrams must keep replaying.
  if (!resolved.enabled) return

  ctx.on('session/event', (session, event) => {
    if (event?.type !== 'assistant/message') return
    const text = extractText(event.data?.message?.content)
    if (!text.includes('```mermaid')) return

    const blocks = extractMermaidBlocks(text)
    if (blocks.length === 0) return

    // Defer: the session's appending guard is still held while session/event
    // callbacks run (same discipline as dsh-working-activity).
    queueMicrotask(() => {
      for (const [index, block] of blocks.entries()) {
        const sourceLines = block.split(/\r?\n/).length
        // Oversize blocks are skipped silently — same contract as upstream.
        if (sourceLines > MAX_SOURCE_LINES || block.length > MAX_SOURCE_CHARS) continue
        try {
          session.append(EVENT_TYPE, buildPayload(block, index + 1))
        } catch {
          // Session closed mid-append — drop this snapshot.
        }
      }
    })
  })
}
