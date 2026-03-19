import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { readEnvFile } from './env.js'

const __dirname = dirname(fileURLToPath(import.meta.url))
const env = readEnvFile(resolve(__dirname, '..', '.env'))

function get(key: string, fallback = ''): string {
  return env[key] ?? process.env[key] ?? fallback
}

export const config = {
  projectRoot: get('PROJECT_ROOT', resolve(__dirname, '..', '..')),
  companionRoot: resolve(__dirname, '..'),
  dbPath: resolve(__dirname, '..', 'store', 'companion.db'),
  logPath: resolve(__dirname, '..', 'store', 'companion.log'),
  auditPath: resolve(__dirname, '..', 'store', 'audit.jsonl'),
  pidPath: resolve(__dirname, '..', 'store', 'companion.pid'),
  uploadDir: resolve(__dirname, '..', 'workspace', 'uploads'),

  anthropicApiKey: get('ANTHROPIC_API_KEY'),
  telegramToken: get('MAESTRO_TELEGRAM_TOKEN'),
  allowedChatIds: get('ALLOWED_CHAT_IDS').split(',').map(s => s.trim()).filter(Boolean),

  groqApiKey: get('GROQ_API_KEY'),
  elevenlabsApiKey: get('ELEVENLABS_API_KEY'),
  elevenlabsVoiceId: get('ELEVENLABS_VOICE_ID'),

  personality: get('MAESTRO_PERSONALITY', 'casual'),
  logLevel: get('LOG_LEVEL', 'info'),
  chatModel: get('CHAT_MODEL', 'sonnet'),
  buildModel: get('BUILD_MODEL', 'opus'),
  maxWorkers: parseInt(get('MAX_WORKERS', '3'), 10) || 3,
} as const
