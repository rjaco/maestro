import { query } from '@anthropic-ai/claude-agent-sdk'
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

  let resultText: string | null = null
  let newSessionId: string | undefined
  let totalCost: number | undefined

  const typingInterval = onTyping ? setInterval(onTyping, 4000) : undefined

  try {
    for await (const event of query({
      prompt: fullPrompt,
      cwd: config.projectRoot,
      permissionMode: 'bypassPermissions',
      settingSources: ['project', 'user'],
      ...(existingSessionId ? { resume: existingSessionId } : {}),
    })) {
      if (event.type === 'system' && 'subtype' in event && event.subtype === 'init') {
        newSessionId = (event as any).session_id
      }

      if (event.type === 'result') {
        const result = event as any
        resultText = result.result ?? null
        totalCost = result.total_cost_usd
      }
    }
  } catch (err) {
    logger.error({ err, chatId }, 'Agent SDK query failed')
    resultText = 'Sorry, I encountered an error processing your request.'
  } finally {
    if (typingInterval) clearInterval(typingInterval)
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
