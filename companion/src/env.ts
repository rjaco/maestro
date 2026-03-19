import { readFileSync, existsSync } from 'node:fs'
import { resolve } from 'node:path'

export function readEnvFile(path?: string): Record<string, string> {
  const envPath = path ?? resolve(process.cwd(), '.env')
  if (!existsSync(envPath)) return {}

  const result: Record<string, string> = {}
  const content = readFileSync(envPath, 'utf-8')

  for (const line of content.split('\n')) {
    const trimmed = line.trim()
    if (!trimmed || trimmed.startsWith('#')) continue
    const eqIdx = trimmed.indexOf('=')
    if (eqIdx === -1) continue
    const key = trimmed.slice(0, eqIdx).trim()
    let value = trimmed.slice(eqIdx + 1).trim()
    // Strip surrounding quotes
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1)
    }
    result[key] = value
  }
  return result
}
