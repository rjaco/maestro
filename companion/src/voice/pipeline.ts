import { config } from '../config.js'
import { logger } from '../logger.js'
import { transcribeAudio } from './stt.js'
import { synthesizeSpeech } from './tts.js'
import { mkdirSync } from 'node:fs'

mkdirSync(config.uploadDir, { recursive: true })

export interface VoiceResult {
  transcript: string
  responseAudio?: Buffer
}

/**
 * Process an incoming voice message:
 * 1. Download the audio file from Telegram
 * 2. Transcribe via STT
 * 3. Return transcript (caller sends to agent, gets response)
 */
export async function processVoiceInput(
  fileId: string,
  botToken: string,
): Promise<string> {
  // Get file path from Telegram
  const fileResponse = await fetch(
    `https://api.telegram.org/bot${botToken}/getFile?file_id=${fileId}`,
  )
  const fileData = (await fileResponse.json()) as {
    ok: boolean
    result: { file_path: string }
  }

  if (!fileData.ok) {
    throw new Error('Failed to get file from Telegram')
  }

  // Download the file
  const downloadUrl = `https://api.telegram.org/file/bot${botToken}/${fileData.result.file_path}`
  const audioResponse = await fetch(downloadUrl)
  const audioBuffer = Buffer.from(await audioResponse.arrayBuffer())

  // Get filename from path
  const filename = fileData.result.file_path.split('/').pop() ?? 'voice.ogg'

  logger.info({ fileId, filename, bytes: audioBuffer.byteLength }, 'Voice downloaded')

  // Transcribe
  const transcript = await transcribeAudio(audioBuffer, filename)
  return transcript
}

/**
 * Synthesize a text response into audio for sending back.
 * Returns null if TTS is not configured or fails.
 */
export async function synthesizeResponse(text: string): Promise<Buffer | null> {
  // Only synthesize if TTS is available
  if (!config.elevenlabsApiKey && !config.groqApiKey) {
    // Check if edge-tts is available as fallback
    try {
      const { execFile } = await import('node:child_process')
      const { promisify } = await import('node:util')
      const execFileAsync = promisify(execFile)
      await execFileAsync('edge-tts', ['--help'], { timeout: 5000 })
    } catch {
      return null // No TTS available
    }
  }

  try {
    return await synthesizeSpeech(text)
  } catch (err) {
    logger.warn({ err }, 'TTS synthesis failed, returning text only')
    return null
  }
}

/**
 * Check if voice features are available.
 */
export function isVoiceAvailable(): { stt: boolean; tts: boolean } {
  return {
    stt: Boolean(config.groqApiKey),
    // ElevenLabs is primary TTS; edge-tts is a free fallback (checked at synthesis time)
    tts: Boolean(config.elevenlabsApiKey && config.elevenlabsVoiceId),
  }
}
