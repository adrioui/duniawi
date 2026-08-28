


























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


export function apply(ctx, config) {
  const bashPath = typeof config?.bashPath === 'string' && config.bashPath.length > 0 ? config.bashPath : 'bash'
  const timeoutMs = Number.isSafeInteger(config?.timeoutMs) && config.timeoutMs > 0 ? config.timeoutMs : DEFAULT_TIMEOUT_MS
  const maxOutputBytes = Number.isSafeInteger(config?.maxOutputBytes) && config.maxOutputBytes > 0 ? config.maxOutputBytes : DEFAULT_MAX_OUTPUT_BYTES

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
      const shell = await ctx.subprocess.resolveExecutable(bashPath, undefined, exec?.signal)
      const workdir = typeof args.workdir === 'string' && args.workdir.length > 0
        ? args.workdir
        : exec?.agent?.session?.header?.cwd
      const signal = exec?.signal
      const handle = ctx.subprocess.spawn({
        argv: [shell, '-c', args.command],
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
