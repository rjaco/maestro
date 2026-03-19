import { readFileSync, existsSync } from 'node:fs'
import { resolve } from 'node:path'
import { config } from './config.js'
import { logger } from './logger.js'

const SOUL_PATHS = [
  // 1. Project-local
  resolve(config.projectRoot, '.maestro', 'SOUL.md'),
  // 2. Plugin data (portable identity)
  ...(process.env.CLAUDE_PLUGIN_DATA
    ? [resolve(process.env.CLAUDE_PLUGIN_DATA, 'SOUL.md')]
    : []),
  // 3. Profile template
  resolve(config.projectRoot, 'templates', 'soul-profiles', `${config.personality}.md`),
  // 4. Fallback
  resolve(config.projectRoot, 'templates', 'soul-profiles', 'casual.md'),
]

let cachedSoul: string | null = null

export function loadSoul(): string {
  if (cachedSoul) return cachedSoul

  for (const soulPath of SOUL_PATHS) {
    if (existsSync(soulPath)) {
      const content = readFileSync(soulPath, 'utf-8')
      // Strip YAML frontmatter
      const stripped = content.replace(/^---[\s\S]*?---\n*/m, '')
      cachedSoul = stripped.trim()
      logger.info({ path: soulPath }, 'SOUL loaded')
      return cachedSoul
    }
  }

  cachedSoul = 'You are Maestro, a helpful and friendly AI companion.'
  logger.warn('No SOUL.md found, using default personality')
  return cachedSoul
}

export function buildSystemContext(memoryContext = ''): string {
  const soul = loadSoul()
  const parts = [soul]

  if (memoryContext) {
    parts.push(`\n[Memory context]\n${memoryContext}`)
  }

  parts.push('\n---\nYou are in Companion Mode. Respond conversationally. Be concise but warm.')

  return parts.join('\n')
}

export function invalidateSoulCache(): void {
  cachedSoul = null
}
