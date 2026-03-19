#!/usr/bin/env node
import { existsSync, readFileSync, writeFileSync, unlinkSync, mkdirSync, appendFileSync } from 'node:fs'
import { dirname } from 'node:path'
import { config } from './config.js'
import { logger } from './logger.js'
import { closeDb, clearSession } from './db.js'
import { runQuery } from './agent.js'
import { buildSystemContext } from './soul.js'
import { markdownToTelegramHtml, chunkMessage } from './formatter.js'
import { TelegramAdapter } from './channels/telegram.js'

// --- Banner ---
console.log(`
  ╔══════════════════════════════════════╗
  ║     MAESTRO COMPANION v0.1.0       ║
  ║   Your AI Friend & Builder         ║
  ╚══════════════════════════════════════╝
`)

// --- PID Lock (atomic via exclusive create) ---
mkdirSync(dirname(config.pidPath), { recursive: true })

try {
  // Atomic: fails if file already exists
  writeFileSync(config.pidPath, String(process.pid), { flag: 'wx' })
} catch (e: unknown) {
  if ((e as NodeJS.ErrnoException).code === 'EEXIST') {
    // File exists — check if the process is still alive
    const existingPid = readFileSync(config.pidPath, 'utf-8').trim()
    try {
      process.kill(Number(existingPid), 0)
      logger.error({ pid: existingPid }, 'Another companion instance is running')
      console.error(`Another Maestro Companion is already running (PID ${existingPid}).`)
      console.error('Stop it first: kill ' + existingPid)
      process.exit(1)
    } catch {
      // Stale PID — overwrite
      logger.warn({ pid: existingPid }, 'Removing stale PID file')
      writeFileSync(config.pidPath, String(process.pid))
    }
  } else {
    throw e
  }
}
logger.info({ pid: process.pid }, 'Companion starting')

// --- Validate Config ---
if (!config.telegramToken) {
  console.error('MAESTRO_TELEGRAM_TOKEN is required. Set it in companion/.env')
  process.exit(1)
}
if (!config.anthropicApiKey) {
  console.error('ANTHROPIC_API_KEY is required. Set it in companion/.env')
  process.exit(1)
}

// --- Audit Logger ---
function audit(chatId: string, action: string, details?: Record<string, unknown>): void {
  const entry = JSON.stringify({
    timestamp: new Date().toISOString(),
    chatId,
    action,
    ...details,
  })
  try {
    mkdirSync(dirname(config.auditPath), { recursive: true })
    appendFileSync(config.auditPath, entry + '\n')
  } catch {
    // Audit logging is best-effort
  }
}

// --- Channel Setup ---
const channel = new TelegramAdapter(config.telegramToken, config.allowedChatIds)

channel.onMessage(async (msg) => {
  const { chatId, username, text } = msg

  logger.info({ chatId, username, text: text?.slice(0, 50) }, 'Message received')
  audit(chatId, 'message', { username, textLength: text?.length })

  // Handle commands
  if (text === '/newchat') {
    clearSession(chatId)
    await channel.send({ chatId, text: '🔄 Fresh conversation started.' })
    return
  }

  if (!text && !msg.voiceFileId && !msg.photoFileId) {
    await channel.send({ chatId, text: 'Send me text, voice, or a photo.' })
    return
  }

  // Build context
  const systemContext = buildSystemContext()

  // Send typing indicator
  await channel.sendTyping(chatId)

  // Query Claude
  const result = await runQuery(
    chatId,
    text ?? '[Media message]',
    systemContext,
    () => { void channel.sendTyping(chatId) },
  )

  if (result.text) {
    const html = markdownToTelegramHtml(result.text)
    // Only chunk once — let the channel adapter handle raw sending
    const chunks = chunkMessage(html)
    for (const chunk of chunks) {
      await channel.send({ chatId, html: chunk })
    }
  } else {
    await channel.send({ chatId, text: '🤔 I processed your message but got no response. Try again?' })
  }

  if (result.costUsd) {
    logger.info({ chatId, costUsd: result.costUsd }, 'Response sent')
  }
})

// --- Graceful Shutdown ---
let shuttingDown = false
async function shutdown(signal: string): Promise<void> {
  if (shuttingDown) return
  shuttingDown = true
  logger.info({ signal }, 'Shutting down...')
  try {
    await channel.stop()
  } catch {
    // Ignore stop errors during shutdown
  }
  closeDb()
  try { unlinkSync(config.pidPath) } catch {
    // Ignore PID file removal errors
  }
  logger.info('Companion stopped')
  // Let pino flush, then exit
  process.exitCode = 0
}

process.on('SIGINT', () => { void shutdown('SIGINT') })
process.on('SIGTERM', () => { void shutdown('SIGTERM') })

// --- Start ---
logger.info({ channel: 'telegram' }, 'Starting channel adapter...')
channel.start().then(() => {
  logger.info('Maestro Companion is live. Send a message on Telegram.')
  console.log('  Maestro Companion is live!')
  console.log('  Send a message to your Telegram bot.')
  console.log('  Press Ctrl+C to stop.')
}).catch((err) => {
  logger.error({ err }, 'Failed to start')
  process.exit(1)
})
