import { config } from './config.js'
import { getSession, saveSession } from './db.js'
import { logger } from './logger.js'

export interface QueryResult {
  text: string | null
  sessionId?: string
  costUsd?: number
}

/**
 * Run a Claude Code query via the Agent SDK.
 *
 * NOTE: The Agent SDK API shape may vary between versions. This module
 * uses a try/catch around the import to fail gracefully if the SDK is
 * not installed, and uses defensive field access on events. If the SDK
 * API changes, update the event processing below.
 *
 * Fallback: If the Agent SDK is not available, falls back to spawning
 * `claude` CLI directly via child_process.
 */
export async function runQuery(
  chatId: string,
  message: string,
  systemContext: string,
  onTyping?: () => void,
): Promise<QueryResult> {
  const existingSessionId = getSession(chatId)
  const fullPrompt = systemContext ? `${systemContext}\n\n${message}` : message

  const typingInterval = onTyping ? setInterval(onTyping, 4000) : undefined

  try {
    // Try Agent SDK first
    const result = await runWithAgentSDK(fullPrompt, existingSessionId, chatId)
    return result
  } catch (sdkErr) {
    logger.warn({ err: sdkErr }, 'Agent SDK unavailable, falling back to CLI')
    // Fallback to CLI spawning
    const result = await runWithCLI(fullPrompt, chatId)
    return result
  } finally {
    if (typingInterval) clearInterval(typingInterval)
  }
}

async function runWithAgentSDK(
  prompt: string,
  sessionId: string | null,
  chatId: string,
): Promise<QueryResult> {
  // Dynamic import so the module doesn't crash if SDK not installed
  const sdk = await import('@anthropic-ai/claude-agent-sdk')
  const queryFn = sdk.query ?? sdk.default?.query

  if (!queryFn) {
    throw new Error('Agent SDK query function not found — API may have changed')
  }

  let resultText: string | null = null
  let newSessionId: string | undefined
  let totalCost: number | undefined

  const queryOpts: Record<string, unknown> = {
    prompt,
    cwd: config.projectRoot,
    permissionMode: 'bypassPermissions',
    settingSources: ['project', 'user'],
  }
  if (sessionId) {
    queryOpts.resume = sessionId
  }

  for await (const event of queryFn(queryOpts) as AsyncIterable<Record<string, unknown>>) {
    // Extract session ID from init events
    if (event.type === 'system' && event.subtype === 'init' && typeof event.session_id === 'string') {
      newSessionId = event.session_id
    }

    // Extract result text and cost from result events
    if (event.type === 'result') {
      if (typeof event.result === 'string') resultText = event.result
      if (typeof event.text === 'string') resultText = event.text
      if (typeof event.total_cost_usd === 'number') totalCost = event.total_cost_usd
      if (typeof event.costUsd === 'number') totalCost = event.costUsd
    }
  }

  if (newSessionId) {
    saveSession(chatId, newSessionId)
    logger.debug({ chatId, sessionId: newSessionId }, 'Session saved')
  }

  if (totalCost !== undefined) {
    logger.info({ chatId, costUsd: totalCost }, 'Query cost')
  }

  return { text: resultText, sessionId: newSessionId, costUsd: totalCost }
}

async function runWithCLI(prompt: string, chatId: string): Promise<QueryResult> {
  const { execFile } = await import('node:child_process')
  const { promisify } = await import('node:util')
  const execFileAsync = promisify(execFile)

  try {
    const { stdout } = await execFileAsync('claude', ['-p', prompt, '--yes', '--model', config.chatModel], {
      cwd: config.projectRoot,
      timeout: 300_000, // 5 min timeout
      env: { ...process.env, ANTHROPIC_API_KEY: config.anthropicApiKey },
    })

    return { text: stdout.trim() || null }
  } catch (err) {
    logger.error({ err, chatId }, 'CLI query failed')
    return { text: 'Sorry, I encountered an error processing your request.' }
  }
}
