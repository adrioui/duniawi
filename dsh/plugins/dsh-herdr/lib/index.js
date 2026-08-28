




















import { spawn } from 'node:child_process'


export const name = 'dsh-herdr'


export const inject = []

const SOURCE = 'custom:dsh'
const AGENT = 'dsh'
const MAX_MESSAGE = 120

function inHerdr() {
  return process.env.HERDR_ENV === '1' && !!process.env.HERDR_PANE_ID
}


import { appendFile, mkdir } from 'node:fs/promises'
import { dirname, join } from 'node:path'


async function diag(message) {
  try {
    const path = join(process.env.DSH_HOME || join(process.env.HOME ?? '.', '.dsh'), 'cache', 'dsh-herdr-diag.log')
    await mkdir(dirname(path), { recursive: true })
    await appendFile(path, `${new Date().toISOString()} ${message}\n`)
  } catch {  }
}

function runHerdr(args) {
  try {
    const child = spawn('herdr', args, { stdio: 'ignore', detached: true })


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





  let seq = Math.floor(Date.now() / 1000)
  let lastState = undefined
  let toolMessage = undefined



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



  ctx.effect(
    () => () => {
      seq += 1
      release(seq)
    },
    'dsh-herdr release on dispose',
  )
}
