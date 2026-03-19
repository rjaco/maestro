import { config } from '../config.js'
import { logger } from '../logger.js'

function prepareForTTS(text: string): string {
  // Strip markdown formatting (TTS reads it literally)
  let clean = text
    .replace(/```[\s\S]*?```/g, '[code block]')    // code blocks
    .replace(/`([^`]+)`/g, '$1')                    // inline code
    .replace(/\*\*(.+?)\*\*/g, '$1')                // bold
    .replace(/\*(.+?)\*/g, '$1')                    // italic
    .replace(/~~(.+?)~~/g, '$1')                    // strikethrough
    .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')        // links
    .replace(/^#+\s/gm, '')                          // headings
    .replace(/^[-*]\s/gm, '')                        // list markers

  // Truncate at sentence boundary near 500 chars
  if (clean.length > 500) {
    const sentenceEnd = clean.lastIndexOf('.', 500)
    if (sentenceEnd > 200) {
      clean = clean.slice(0, sentenceEnd + 1)
    } else {
      clean = clean.slice(0, 500) + '...'
    }
  }

  return clean.trim()
}

export async function synthesizeSpeech(text: string): Promise<Buffer> {
  // Split at sentence boundaries for natural-sounding TTS
  const prepared = prepareForTTS(text)

  if (config.elevenlabsApiKey && config.elevenlabsVoiceId) {
    return synthesizeWithElevenLabs(prepared)
  }

  // Fallback: edge-tts via CLI (free, no API key needed)
  return synthesizeWithEdgeTts(prepared)
}

async function synthesizeWithElevenLabs(text: string): Promise<Buffer> {
  const response = await fetch(
    `https://api.elevenlabs.io/v1/text-to-speech/${config.elevenlabsVoiceId}`,
    {
      method: 'POST',
      headers: {
        Accept: 'audio/mpeg',
        'Content-Type': 'application/json',
        'xi-api-key': config.elevenlabsApiKey,
      },
      body: JSON.stringify({
        text,
        model_id: 'eleven_turbo_v2_5',
        voice_settings: {
          stability: 0.5,
          similarity_boost: 0.75,
        },
      }),
    },
  )

  if (!response.ok) {
    const errorText = await response.text()
    logger.error({ status: response.status, error: errorText }, 'ElevenLabs TTS failed')
    throw new Error(`ElevenLabs TTS failed: ${response.status}`)
  }

  const arrayBuffer = await response.arrayBuffer()
  logger.info({ bytes: arrayBuffer.byteLength }, 'TTS synthesis complete')
  return Buffer.from(arrayBuffer)
}

async function synthesizeWithEdgeTts(text: string): Promise<Buffer> {
  // edge-tts is a Python CLI tool that uses Microsoft Edge's free TTS API
  // Install: pip install edge-tts
  const { execFile } = await import('node:child_process')
  const { promisify } = await import('node:util')
  const { readFile, unlink } = await import('node:fs/promises')
  const { resolve } = await import('node:path')
  const execFileAsync = promisify(execFile)

  const outputPath = resolve(config.uploadDir, `tts-${Date.now()}.mp3`)

  try {
    await execFileAsync(
      'edge-tts',
      ['--text', text, '--voice', 'en-US-AriaNeural', '--write-media', outputPath],
      { timeout: 30000 },
    )

    const audioBuffer = await readFile(outputPath)
    await unlink(outputPath).catch(() => {})
    logger.info({ bytes: audioBuffer.byteLength }, 'edge-tts synthesis complete')
    return audioBuffer
  } catch (err) {
    logger.error({ err }, 'edge-tts failed')
    throw new Error('TTS failed: edge-tts not available. Install with: pip install edge-tts')
  }
}
