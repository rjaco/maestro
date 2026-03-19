import { query, type SDKResultMessage } from '@anthropic-ai/claude-agent-sdk'
import type { Options } from '@anthropic-ai/claude-agent-sdk'
import { config } from './config.js'
import { getSession, saveSession } from './db.js'
import { logger } from './logger.js'

export interface QueryResult {
  text: string | null
  sessionId?: string
  costUsd?: number
}

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
    const result = await runWithAgentSDK(fullPrompt, existingSessionId, chatId)
    return result
  } catch (sdkErr) {
    logger.warn({ err: sdkErr }, 'Agent SDK query failed, falling back to CLI')
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
  let resultText: string | null = null
  let newSessionId: string | undefined
  let totalCost: number | undefined

  const options: Options = {
    cwd: config.projectRoot,
    permissionMode: 'bypassPermissions',
    allowDangerouslySkipPermissions: true,
    settingSources: ['project', 'user'],
    model: config.chatModel,
    ...(sessionId ? { resume: sessionId } : {}),
  }

  const queryResult = query({ prompt, options })

  for await (const event of queryResult) {
    // Extract session ID from system init events
    if (event.type === 'system' && 'subtype' in event) {
      const sysEvent = event as Record<string, unknown>
      if (sysEvent.subtype === 'init' && typeof sysEvent.session_id === 'string') {
        newSessionId = sysEvent.session_id
      }
    }

    // Extract result from result events
    if (event.type === 'result') {
      const resultEvent = event as SDKResultMessage
      totalCost = resultEvent.total_cost_usd
      if (resultEvent.subtype === 'success') {
        resultText = resultEvent.result
        newSessionId = resultEvent.session_id
      }
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
      timeout: 300_000,
      env: { ...process.env, ANTHROPIC_API_KEY: config.anthropicApiKey },
    })

    return { text: stdout.trim() || null }
  } catch (err) {
    logger.error({ err, chatId }, 'CLI query failed')
    return { text: 'Sorry, I encountered an error processing your request.' }
  }
}
