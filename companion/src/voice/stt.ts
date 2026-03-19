import { config } from '../config.js'
import { logger } from '../logger.js'

export async function transcribeAudio(audioBuffer: Buffer, filename: string): Promise<string> {
  // Rename .oga → .ogg (Groq rejects .oga despite identical format)
  const correctedName = filename.replace(/\.oga$/, '.ogg')

  if (config.groqApiKey) {
    return transcribeWithGroq(audioBuffer, correctedName)
  }

  throw new Error('No STT provider configured. Set GROQ_API_KEY in .env')
}

async function transcribeWithGroq(audioBuffer: Buffer, filename: string): Promise<string> {
  const formData = new FormData()
  formData.append('file', new Blob([audioBuffer]), filename)
  formData.append('model', 'whisper-large-v3')

  const response = await fetch('https://api.groq.com/openai/v1/audio/transcriptions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${config.groqApiKey}`,
    },
    body: formData,
  })

  if (!response.ok) {
    const errorText = await response.text()
    logger.error({ status: response.status, error: errorText }, 'Groq STT failed')
    throw new Error(`Groq STT failed: ${response.status}`)
  }

  const result = (await response.json()) as { text: string }
  logger.info({ length: result.text.length }, 'Transcription complete')
  return result.text
}
