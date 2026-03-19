import { logger } from '../logger.js'
import { spawnWorker, getWorkerStats } from './pool.js'

const BUILD_KEYWORDS = /\b(build|create|implement|develop|make|code|fix|refactor|deploy|ship)\b/i

export function isBuildRequest(text: string): boolean {
  return BUILD_KEYWORDS.test(text)
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
