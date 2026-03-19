import { logger } from '../logger.js'
import { spawnWorker, getWorkerStats } from './pool.js'

// Require explicit build verbs OR 2+ keywords in context
const EXPLICIT_BUILD = /^(build|implement|develop|deploy|ship)\b/i
const BUILD_CONTEXT = /\b(build|create|implement|develop|code|fix|refactor|deploy|ship)\b/gi

export function isBuildRequest(text: string): boolean {
  // Explicit command always triggers
  if (text.startsWith('/build ')) return true
  // Single explicit build verb at start of message
  if (EXPLICIT_BUILD.test(text)) return true
  // Need 2+ build keywords in the same message for implicit detection
  const matches = text.match(BUILD_CONTEXT)
  return (matches?.length ?? 0) >= 2
}

export async function handleBuildRequest(
  text: string,
  onProgress: (status: string) => Promise<void>,
): Promise<string> {
  await onProgress('🔨 Starting build...')
  const prompt = `You are Maestro. The user requested: "${text}"

Execute this using the Maestro plugin skills. If this is a feature request:
1. Decompose into stories
2. Execute each story via dev-loop
3. Commit all changes
4. Report what was done

Be thorough but concise. The user is monitoring via Telegram.`

  const worker = await spawnWorker(prompt, async (workerId, status) => {
    await onProgress(`Worker ${workerId.slice(-8)}: ${status}`)
  })

  if (worker.status === 'completed') {
    return `✅ Build complete!\n\n${worker.result?.slice(0, 1000) ?? 'Done'}\n\nCost: $${worker.costUsd?.toFixed(4) ?? '?'}`
  }
  return '❌ Build failed. Check logs for details.'
}
