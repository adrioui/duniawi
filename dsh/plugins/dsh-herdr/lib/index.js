/**
 * dsh-herdr: report dsh's lifecycle to the Herdr terminal multiplexer.
 *
 * Herdr only ships screen-detection manifests for built-in agents, so an
 * unsupported TUI like dsh never appears in its agents pane. The supported
 * escape hatch is Herdr's reporting API:
 *
 *   herdr pane report-agent <pane> --source custom:dsh --agent dsh --state <s>
 *
 * This plugin calls that API from inside dsh whenever the agent lifecycle
 * changes, so Herdr shows a `dsh` row with accurate idle/working state (and
 * the current tool as the status message). It is inert outside Herdr
 * (HERDR_ENV != 1) and best-effort everywhere: a missing/broken herdr binary
 * never affects the harness itself.
 *
 * Lifecycle signal: the cordis `agent/status` event ({ agent, status }) where
 * status is 'idle' | 'running' — the same signal dsh-working-activity folds
 * into its working line. Tool context comes from `tool/call` session events
 * (event.data.name), cleared at turn/end.
 */

import { spawn } from 'node:child_process'

/** Cordis plugin name used by loader diagnostics. */
export const name = 'dsh-herdr'

/** No service requirements — events arrive on the shared cordis bus. */
export const inject = []

const SOURCE = 'custom:dsh'
const AGENT = 'dsh'
const MAX_MESSAGE = 120

function inHerdr() {
  return process.env.HERDR_ENV === '1' && !!process.env.HERDR_PANE_ID
}

/** Fire-and-forget one herdr CLI invocation; never throws, never blocks. */
import { appendFile, mkdir } from 'node:fs/promises'
import { dirname, join } from 'node:path'

/** Temporary diagnostics: one line per lifecycle attempt. */
async function diag(message) {
  try {
    const path = join(process.env.DSH_HOME || join(process.env.HOME ?? '.', '.dsh'), 'cache', 'dsh-herdr-diag.log')
    await mkdir(dirname(path), { recursive: true })
    await appendFile(path, `${new Date().toISOString()} ${message}\n`)
  } catch { /* diagnostics are best-effort */ }
}

function runHerdr(args) {
  try {
    const child = spawn('herdr', args, { stdio: 'ignore', detached: true })
    // A failed spawn used to vanish silently, which made a dead agents-pane
    // row undebuggable; surface it best-effort instead.
    child.on('error', (error) => diag(`SPAWN-ERR ${args.join(' ')}: ${error.message}`))
    child.unref()
  } catch (error) {
    diag(`THROW ${error?.message}`)
  }
}

function report(state, message, seq) {
  const args = [
    'pane', 'report-agent', process.env.HERDR_PANE_ID,
    '--source', SOURCE,
    '--agent', AGENT,
    '--state', state,
    '--seq', String(seq),
  ]
  if (message) args.push('--message', message.slice(0, MAX_MESSAGE))
  runHerdr(args)
}

function release(seq) {
  runHerdr([
    'pane', 'release-agent', process.env.HERDR_PANE_ID,
    '--source', SOURCE,
    '--agent', AGENT,
    '--seq', String(seq),
  ])
}

export function apply(ctx) {
  void diag(`apply: herdr=${inHerdr()} pane=${process.env.HERDR_PANE_ID ?? 'absent'}`)
  if (!inHerdr()) return

  // Herdr drops reports whose seq is below the pane's high-water mark, so a
  // per-process counter that restarts at 1 gets every report rejected after
  // the first dsh restart. Seed from wall-clock seconds instead: monotonic
  // across restarts, still strictly increasing within one.
  let seq = Math.floor(Date.now() / 1000)
  let lastState = undefined
  let toolMessage = undefined

  // State transitions always publish; message-only updates republish while
  // working so Herdr's status message tracks the current tool.
  const setState = (state) => {
    if (state === lastState) return
    lastState = state
    seq += 1
    report(state, state === 'working' ? (toolMessage || 'working') : undefined, seq)
  }
  const setMessage = (message) => {
    toolMessage = message
    if (lastState === 'working') {
      seq += 1
      report('working', message, seq)
    }
  }

  // Announce presence immediately so the row exists before the first turn.
  setState('idle')

  ctx.on('agent/status', ({ status }) => {
    setState(status === 'running' ? 'working' : 'idle')
  })

  ctx.on('session/event', (session, event) => {
    if (event.type === 'tool/call') {
      const toolName = event?.data?.name
      if (typeof toolName === 'string' && toolName) setMessage(`tool ${toolName}`)
    } else if (event.type === 'turn/end') {
      setMessage(undefined)
    }
  })

  // On unload (profile shutdown or hot-reload), clear the row so Herdr does
  // not keep showing a stale dsh entry for a dead pane process.
  ctx.effect(
    () => () => {
      seq += 1
      release(seq)
    },
    'dsh-herdr release on dispose',
  )
}
