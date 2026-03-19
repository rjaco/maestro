#!/usr/bin/env node
import { existsSync, readFileSync, writeFileSync, unlinkSync, mkdirSync, appendFileSync } from 'node:fs'
import { dirname } from 'node:path'
import { config } from './config.js'
import { logger } from './logger.js'
import { closeDb, clearSession } from './db.js'
import { runQuery } from './agent.js'
import { buildSystemContext } from './soul.js'
import { markdownToTelegramHtml } from './formatter.js'
import { TelegramAdapter } from './channels/telegram.js'
import { initMemoryTables, saveMemory, buildMemoryContext, runDecaySweep } from './memory.js'
import { processVoiceInput, synthesizeResponse, isVoiceAvailable } from './voice/pipeline.js'
import { isBuildRequest, handleBuildRequest } from './workers/coordinator.js'
import { formatStatus, listCurrentStories } from './state.js'
import { getWorkerStats } from './workers/pool.js'

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
  writeFileSync(config.pidPath, String(process.pid), { flag: 'wx' })
} catch (e: unknown) {
  if ((e as NodeJS.ErrnoException).code === 'EEXIST') {
    const existingPid = readFileSync(config.pidPath, 'utf-8').trim()
    try {
      process.kill(Number(existingPid), 0)
      logger.error({ pid: existingPid }, 'Another companion instance is running')
      console.error(`Another Maestro Companion is already running (PID ${existingPid}).`)
      console.error('Stop it first: kill ' + existingPid)
      process.exit(1)
    } catch {
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

// --- Initialize Memory ---
initMemoryTables()

// --- Memory Decay Sweep (every hour) ---
setInterval(() => {
  try { runDecaySweep() } catch (err) { logger.warn({ err }, 'Decay sweep failed') }
}, 60 * 60 * 1000)

// --- Voice Toggle (per chat) ---
const voiceEnabled = new Set<string>()

// --- Audit Logger ---
function audit(chatId: string, action: string, details?: Record<string, unknown>): void {
  const entry = JSON.stringify({ timestamp: new Date().toISOString(), chatId, action, ...details })
  try {
    mkdirSync(dirname(config.auditPath), { recursive: true })
    appendFileSync(config.auditPath, entry + '\n')
  } catch (err) {
    logger.debug({ err }, 'Audit log write failed')
  }
}

// --- Channel Setup ---
const channel = new TelegramAdapter(config.telegramToken, config.allowedChatIds)

channel.onMessage(async (msg) => {
  const { chatId, username, text } = msg

  logger.info({ chatId, username, text: text?.slice(0, 50) }, 'Message received')
  audit(chatId, 'message', { username, textLength: text?.length })

  // --- Commands ---
  if (text === '/newchat') {
    clearSession(chatId)
    await channel.send({ chatId, text: '🔄 Fresh conversation started.' })
    return
  }
  if (text === '/status') {
    await channel.send({ chatId, text: formatStatus() })
    return
  }
  if (text === '/cost') {
    const stats = getWorkerStats()
    await channel.send({ chatId, text: `💰 Session Cost\n\nTotal: $${stats.totalCost.toFixed(4)}\nWorkers: ${stats.completed} complete, ${stats.running} running, ${stats.failed} failed` })
    return
  }
  if (text === '/stories') {
    const storyList = listCurrentStories()
    await channel.send({ chatId, text: storyList || 'No stories found.' })
    return
  }
  if (text === '/help') {
    await channel.send({ chatId, text:
      '📋 Maestro Companion Commands\n\n' +
      '/status — Current build progress\n' +
      '/cost — Cumulative spend\n' +
      '/stories — List milestone stories\n' +
      '/voice — Toggle voice replies\n' +
      '/newchat — Fresh conversation\n' +
      '/build <desc> — Explicit build request\n' +
      '/help — This message',
    })
    return
  }
  if (text === '/voice') {
    const voice = isVoiceAvailable()
    if (!voice.stt) {
      await channel.send({ chatId, text: 'Voice not configured. Set GROQ_API_KEY in .env.' })
      return
    }
    if (voiceEnabled.has(chatId)) {
      voiceEnabled.delete(chatId)
      await channel.send({ chatId, text: '🔇 Voice replies disabled.' })
    } else {
      voiceEnabled.add(chatId)
      await channel.send({ chatId, text: '🔊 Voice replies enabled.' })
    }
    return
  }

  if (!text && !msg.voiceFileId && !msg.photoFileId) {
    await channel.send({ chatId, text: 'Send me text, voice, or a photo.' })
    return
  }

  // --- Voice Transcription ---
  let messageText = text ?? ''
  let forceVoiceReply = false

  if (msg.voiceFileId) {
    await channel.sendTyping(chatId)
    try {
      const transcript = await processVoiceInput(msg.voiceFileId, config.telegramToken)
      messageText = `[Voice transcribed]: ${transcript}`
      forceVoiceReply = true
      logger.info({ chatId, transcriptLength: transcript.length }, 'Voice transcribed')
    } catch (err) {
      logger.error({ err, chatId }, 'Voice transcription failed')
      await channel.send({ chatId, text: '🎙️ Could not transcribe voice. Try again or send text.' })
      return
    }
  }

  // --- Build Request Detection ---
  if (text && isBuildRequest(text)) {
    await handleBuildRequest(text, async (status) => {
      await channel.send({ chatId, text: status })
    }).then(async (result) => {
      await channel.send({ chatId, text: result })
    }).catch(async (err) => {
      logger.error({ err, chatId }, 'Build request failed')
      await channel.send({ chatId, text: '❌ Build failed. Check logs.' })
    })
    return
  }

  // --- Memory Context ---
  const memoryContext = buildMemoryContext(chatId, messageText)
  const systemContext = buildSystemContext(memoryContext)

  // --- Send Typing ---
  await channel.sendTyping(chatId)

  // --- Query Claude ---
  const result = await runQuery(
    chatId,
    messageText,
    systemContext,
    () => { void channel.sendTyping(chatId) },
  )

  // --- Save to Memory ---
  if (messageText && !messageText.startsWith('/')) {
    saveMemory(chatId, messageText)
  }
  if (result.text) {
    saveMemory(chatId, result.text.slice(0, 500))
  }

  // --- Send Response ---
  if (result.text) {
    // Voice reply if toggled on or voice message received
    if ((forceVoiceReply || voiceEnabled.has(chatId)) && isVoiceAvailable().tts) {
      const audio = await synthesizeResponse(result.text.slice(0, 500))
      if (audio) {
        await channel.send({ chatId, voiceBuffer: audio })
      }
    }

    // Always send text too (chunking handled by the adapter)
    const html = markdownToTelegramHtml(result.text)
    await channel.send({ chatId, html })
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
  try { await channel.stop() } catch { /* ignore */ }
  closeDb()
  try { unlinkSync(config.pidPath) } catch { /* ignore */ }
  logger.info('Companion stopped')
  process.exitCode = 0
}

process.on('SIGINT', () => { void shutdown('SIGINT') })
process.on('SIGTERM', () => { void shutdown('SIGTERM') })

// --- Start ---
logger.info({ channel: 'telegram', voice: isVoiceAvailable() }, 'Starting companion...')
channel.start().then(() => {
  logger.info('Maestro Companion is live.')
  console.log('  Maestro Companion is live!')
  console.log('  Send a message to your Telegram bot.')
  console.log('  Press Ctrl+C to stop.')
}).catch((err) => {
  logger.error({ err }, 'Failed to start')
  process.exit(1)
})
