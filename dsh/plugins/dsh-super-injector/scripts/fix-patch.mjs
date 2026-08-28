#!/usr/bin/env node



















import { readFileSync, writeFileSync, mkdirSync, readdirSync, existsSync, renameSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { homedir } from 'node:os'

const args = process.argv.slice(2)
const onlyProfile = args.includes('--profile') ? args[args.indexOf('--profile') + 1] : null
const checkOnly = args.includes('--check')


function extractBlocks(content) {
  const lines = content.split('\n')
  const blocks = []
  let current = null
  for (const line of lines) {
    const idMatch = /^\s*- id:\s*([^\s#]+)/.exec(line)
    if (idMatch) {
      if (current) blocks.push(current)
      current = { id: idMatch[1], text: line }
    } else if (current) {
      current.text += '\n' + line
    } else if (line.trim() !== '' && !/^\s*#/.test(line) && !/^\s*\[\]\s*$/.test(line)) {
      blocks.push({ id: undefined, text: line })
    }
  }
  if (current) blocks.push(current)
  return blocks
}


function dedupe(content) {
  const blocks = extractBlocks(content)
  const seen = new Set()
  const removed = []
  const kept = []
  for (const b of blocks) {
    if (b.id) {
      if (seen.has(b.id)) {
        const rec = removed.find((r) => r.id === b.id)
        if (rec) rec.count += 1
        else removed.push({ id: b.id, count: 1 })
        continue
      }
      seen.add(b.id)
    }
    kept.push(b.text)
  }
  return { text: kept.join('\n'), removed }
}

function fixFile(patchFile) {
  let content
  try {
    content = readFileSync(patchFile, 'utf8')
  } catch {
    return { ok: false, error: '读取失败（跳过）' }
  }
  const { text, removed } = dedupe(content)
  if (removed.length === 0) return { ok: true, clean: true, removed: [] }
  if (!checkOnly) {
    const bak = patchFile + '.bak-' + Date.now()
    try {
      mkdirSync(dirname(patchFile), { recursive: true })
      renameSync(patchFile, bak)

      writeFileSync(patchFile, text.replace(/\s*$/, '') + '\n', 'utf8')
    } catch (e) {
      return { ok: false, error: String(e?.message ?? e), removed }
    }
  }
  return { ok: true, clean: false, removed, backup: checkOnly ? undefined : patchFile + '.bak-*' }
}

function main() {
  const profilesRoot = join(homedir(), '.dsh', 'profiles')
  let profileDirs = []
  try {
    profileDirs = readdirSync(profilesRoot).filter((d) => !d.startsWith('.'))
  } catch {
    console.error('未找到 profiles 目录: ' + profilesRoot)
    process.exit(2)
  }
  if (onlyProfile) profileDirs = profileDirs.filter((d) => d === onlyProfile)
  if (profileDirs.length === 0) {
    console.error(checkOnly ? '未找到 profile: ' + onlyProfile : '未找到任何 profile')
    process.exit(2)
  }

  let foundAny = false
  let fixedAny = false
  for (const profile of profileDirs) {
    const patchFile = join(profilesRoot, profile, 'cordis.patch.yml')
    if (!existsSync(patchFile)) continue
    const r = fixFile(patchFile)
    if (r.error) {
      console.log(`[${profile}] cordis.patch.yml ${r.error}`)
      continue
    }
    foundAny = true
    if (r.clean) {
      console.log(`[${profile}] 健康：无重复 id`)
      continue
    }
    fixedAny = true
    for (const rec of r.removed) {
      console.log(`[${profile}] 修复：id "${rec.id}" 重复，删除 ${rec.count} 条（保留最后一条）`)
    }
    if (!checkOnly) console.log(`[${profile}] 已重写（原文件备份为 ${patchFile}.bak-<时间戳>）`)
  }
  if (!foundAny) {
    console.log('未找到任何 cordis.patch.yml（全部 profile 都是全新未 patch？）')
    process.exit(0)
  }
  if (checkOnly) {
    process.exit(fixedAny ? 1 : 0)
  }
  console.log(fixedAny ? '\n✅ 修复完成，现在可以重新启动 dsh' : '\n✅ 无需修复')
}

main()
