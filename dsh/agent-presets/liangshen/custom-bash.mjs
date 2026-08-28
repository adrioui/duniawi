










































import { readFileSync } from 'node:fs'


export const name = 'custom-bash'


export const inject = ['subprocess', 'tools']

const DEFAULT_TIMEOUT_MS = 120000
const DEFAULT_MAX_OUTPUT_BYTES = 64000


const commandSchema = {
  type: 'object',
  properties: {
    command: {
      type: 'string',
      description: 'The bash command to execute (`bash -c` string domain).',
    },
    workdir: {
      type: 'string',
      description: 'Optional working directory; defaults to the session cwd.',
    },
  },
  required: ['command'],
  additionalProperties: false,
}

function addCandidate(candidates, seen, candidate) {
  if (typeof candidate !== 'string' || candidate.length === 0) return
  const key = candidate.toLowerCase()
  if (seen.has(key)) return
  seen.add(key)
  candidates.push(candidate)
}


function explicitBashPath(config, environment) {
  for (const value of [config.bashPath, environment.DSH_TUI_LIANGSHEN_BASH_PATH]) {
    if (typeof value === 'string' && value.length > 0) return value
  }
  return undefined
}


export function windowsBashCandidates(config = {}, environment = process.env) {
  const explicit = explicitBashPath(config, environment)
  if (explicit !== undefined) return [explicit]

  const candidates = []
  const seen = new Set()
  for (const root of [
    environment.ProgramFiles,
    environment['ProgramFiles(x86)'],
  ]) {
    if (typeof root !== 'string' || root.length === 0) continue
    addCandidate(candidates, seen, `${root}\\Git\\bin\\bash.exe`)
    addCandidate(candidates, seen, `${root}\\Git\\usr\\bin\\bash.exe`)
  }
  if (typeof environment.LOCALAPPDATA === 'string' && environment.LOCALAPPDATA.length > 0) {
    addCandidate(candidates, seen, `${environment.LOCALAPPDATA}\\Programs\\Git\\bin\\bash.exe`)
    addCandidate(candidates, seen, `${environment.LOCALAPPDATA}\\Programs\\Git\\usr\\bin\\bash.exe`)
  }


  const scoopRoots = []
  if (typeof environment.SCOOP === 'string' && environment.SCOOP.length > 0) {
    scoopRoots.push(environment.SCOOP)
  }
  if (typeof environment.USERPROFILE === 'string' && environment.USERPROFILE.length > 0) {
    scoopRoots.push(`${environment.USERPROFILE}\\scoop`)
  }
  for (const root of scoopRoots) {
    addCandidate(candidates, seen, `${root}\\apps\\git\\current\\bin\\bash.exe`)
    addCandidate(candidates, seen, `${root}\\apps\\git\\current\\usr\\bin\\bash.exe`)
  }
  addCandidate(candidates, seen, 'bash')
  return candidates
}


export function isWindowsSubsystemLauncher(path) {
  return /[\\/]windows[\\/](?:system32|sysnative)[\\/]bash\.exe$/i.test(path)
}






export function resolveShimTarget(exePath, reader = readFileSync) {
  for (const sidecar of [exePath.replace(/\.exe$/i, '') + '.shim', `${exePath}.shim`]) {
    try {
      const text = reader(sidecar, 'utf8')
      const match = text.match(/^\s*path\s*=\s*"?(.+?)"?\s*$/mi)
      if (match !== null) return match[1]
    } catch {  }
  }
  return exePath
}


export function bashCandidatesFromGit(gitPath) {
  if (typeof gitPath !== 'string' || gitPath.length === 0) return []
  const parts = gitPath.replace(/\
  if (parts.at(-1)?.toLowerCase() !== 'git.exe') return []
  const roots = []
  const push = root => {
    if (root.length > 0 && !roots.includes(root)) roots.push(root)
  }

  if (parts.length >= 3) push(parts.slice(0, -2).join('\\'))


  if (parts.length >= 5
    && parts.at(-2)?.toLowerCase() === 'bin'
    && /^mingw(32|64)$/.test(parts.at(-3) ?? '')) {
    push(parts.slice(0, -3).join('\\'))
  }
  const candidates = []
  for (const root of roots) {
    candidates.push(`${root}\\bin\\bash.exe`, `${root}\\usr\\bin\\bash.exe`)
  }
  return candidates
}






async function gitTreeCandidates(subprocess, failures) {
  let gitPath
  try {
    gitPath = await subprocess.resolveExecutable('git')
  } catch (error) {
    failures.push(`git: ${error instanceof Error ? error.message : String(error)}`)
    return []
  }
  return bashCandidatesFromGit(resolveShimTarget(gitPath))
}


export async function resolveWindowsBash(subprocess, config = {}, environment = process.env) {
  const failures = []
  const explicit = explicitBashPath(config, environment)
  const candidates = explicit !== undefined

    ? [explicit]
    : [...await gitTreeCandidates(subprocess, failures), ...windowsBashCandidates(config, environment)]
  for (const candidate of candidates) {
    try {
      const resolved = await subprocess.resolveExecutable(candidate)
      if (isWindowsSubsystemLauncher(resolved)) {
        failures.push(`${candidate}: resolved to the Windows Subsystem for Linux launcher`)
        continue
      }
      return resolved
    } catch (error) {
      failures.push(`${candidate}: ${error instanceof Error ? error.message : String(error)}`)
    }
  }
  throw new Error(`Git Bash executable unavailable (${failures.join('; ')})`)
}

function warn(ctx, message) {
  try {
    ctx.logger.warn(message)
  } catch {

  }
}


export async function apply(ctx, config) {
  const source = config === undefined ? {} : config
  const timeoutMs = Number.isSafeInteger(source.timeoutMs) && source.timeoutMs > 0 ? source.timeoutMs : DEFAULT_TIMEOUT_MS
  const maxOutputBytes = Number.isSafeInteger(source.maxOutputBytes) && source.maxOutputBytes > 0 ? source.maxOutputBytes : DEFAULT_MAX_OUTPUT_BYTES

  let bashPath
  try {
    bashPath = await resolveWindowsBash(ctx.subprocess, source)
  } catch (error) {



    warn(ctx, `custom-bash: ${error instanceof Error ? error.message : String(error)} — the Windows bootstrap bash tool is not registered; the bootstrap filter will expose the full catalog`)
    return
  }

  ctx.tools.register({
    name: 'bash',
    description: [
      'Run commands in a bash shell (Git Bash on Windows)',
      '* When invoking this tool, the contents of the "command" parameter does NOT need to be XML-escaped.',
      "* You don't have access to the internet via this tool.",
      '* You do have access to a mirror of common linux and python packages via apt and pip.',
      '* State does NOT persist across command calls: each call runs in a fresh shell.',
      "* To inspect a particular line range of a file, e.g. lines 10-25, try 'sed -n 10,25p /path/to/the/file'.",
      '* Please avoid commands that may produce a very large amount of output.',
      '* NOTE: runs without OS sandbox confinement on Windows (no landlock); treat output as untrusted.',
    ].join('\n'),
    parameters: commandSchema,
    timeoutMs,
    output: {
      schema: {
        type: 'object',
        additionalProperties: false,
        properties: {
          text: { type: 'string' },
        },
        required: ['text'],
      },
      render: (_args, value) => [{ type: 'text', text: value.text }],
    },
    async execute(args, exec) {
      const workdir = typeof args.workdir === 'string' && args.workdir.length > 0
        ? args.workdir
        : exec?.agent?.session?.header?.cwd
      const signal = exec?.signal
      const handle = ctx.subprocess.spawn({
        argv: [bashPath, '-c', args.command],
        ...workdir !== undefined ? { cwd: workdir } : {},
        stdio: {
          stdin: 'ignore',
          stdout: { maxBytes: maxOutputBytes },
          stderr: { maxBytes: maxOutputBytes },
        },
        ...signal !== undefined ? { signal } : {},
        graceMs: 3000,
      })
      let outcome
      try {
        outcome = await handle.done
      } catch (error) {


        throw new Error(`bash spawn failed: ${String(error)}`)
      }
      let stdout = ''
      let stderr = ''
      try {
        stdout = handle.collected.stdout.readFrom(0).text
        stderr = handle.collected.stderr.readFrom(0).text
      } catch {

      }
      const text = [stdout, stderr].filter((part) => part.length > 0).join('\n')
      const tail = text.length > 0 ? text : `exit code: ${outcome.exitCode} (no output)`
      if (outcome.exitCode !== 0) {


        throw new Error(tail)
      }
      return { text: tail }
    },
  })
}
