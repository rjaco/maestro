#!/usr/bin/env node
/**
 * Maestro Companion Setup Wizard
 * Interactive setup: 4 questions → .env → build → service install
 * Usage: npx maestro-companion setup
 */
import { createInterface } from 'node:readline'
import { writeFileSync, chmodSync, existsSync, mkdirSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { execSync } from 'node:child_process'

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(__dirname, '..')
const ENV_PATH = resolve(ROOT, '.env')

const rl = createInterface({ input: process.stdin, output: process.stdout })
const ask = (q: string): Promise<string> => new Promise(r => rl.question(q, r))
const askSecret = (q: string): Promise<string> => new Promise(r => {
  const rl2 = createInterface({ input: process.stdin, output: process.stdout })
  process.stdout.write(q)
  const stdin = process.stdin
  if (typeof stdin.setRawMode === 'function') {
    stdin.setRawMode(true)
    stdin.resume()
    let buf = ''
    const onData = (ch: Buffer) => {
      const c = ch.toString()
      if (c === '\n' || c === '\r') {
        stdin.setRawMode(false)
        stdin.removeListener('data', onData)
        process.stdout.write('\n')
        rl2.close()
        r(buf)
      } else if (c === '\u007F' || c === '\b') {
        buf = buf.slice(0, -1)
        process.stdout.write('\b \b')
      } else {
        buf += c
        process.stdout.write('*')
      }
    }
    stdin.on('data', onData)
  } else {
    // Fallback for non-TTY environments
    rl2.question('', (answer) => { rl2.close(); r(answer) })
  }
})

console.log(`
  ╔══════════════════════════════════════╗
  ║     MAESTRO COMPANION SETUP        ║
  ║   Your AI Friend & Builder         ║
  ╚══════════════════════════════════════╝
`)

async function main() {
  // --- Pre-flight ---
  console.log('Checking requirements...\n')

  try { execSync('claude --version', { stdio: 'pipe' }); console.log('  ✓ claude CLI found') }
  catch { console.error('  ✗ claude CLI not found. Install: npm i -g @anthropic-ai/claude-code'); process.exit(1) }

  const nodeVersion = process.version.match(/v(\d+)/)?.[1]
  if (nodeVersion && parseInt(nodeVersion) >= 20) { console.log(`  ✓ Node ${process.version}`) }
  else { console.error(`  ✗ Node 20+ required (found ${process.version})`); process.exit(1) }

  console.log('')

  // --- Q1: Telegram Token ---
  console.log('Step 1/4: Telegram Bot Token')
  console.log('  Create a bot: talk to @BotFather on Telegram, send /newbot')
  console.log('  Copy the token it gives you.\n')
  const telegramToken = await askSecret('  Telegram bot token: ')
  if (!telegramToken.includes(':')) {
    console.error('  Invalid token format. Should look like: 123456:ABC-DEF...')
    process.exit(1)
  }

  // --- Q2: API Key ---
  console.log('\nStep 2/4: Anthropic API Key')
  console.log('  Get one at: console.anthropic.com/settings/keys\n')
  const apiKey = await askSecret('  Anthropic API key: ')

  // --- Q3: Voice ---
  console.log('\nStep 3/4: Voice Mode')
  console.log('  Voice lets you send voice notes and get spoken replies.')
  const wantVoice = (await ask('  Enable voice? (y/n): ')).toLowerCase().startsWith('y')

  let groqKey = ''
  let elevenLabsKey = ''
  let elevenLabsVoice = ''

  if (wantVoice) {
    console.log('  STT: Groq Whisper (free at console.groq.com)')
    groqKey = await askSecret('  Groq API key: ')
    console.log('  TTS: ElevenLabs (free tier at elevenlabs.io)')
    console.log('  Leave blank to use edge-tts (free, no key needed)')
    elevenLabsKey = await askSecret('  ElevenLabs API key (or blank): ')
    if (elevenLabsKey) {
      elevenLabsVoice = await ask('  ElevenLabs voice ID: ')
    }
  }

  // --- Q4: Personality ---
  console.log('\nStep 4/4: Personality')
  console.log('  1. casual   — friendly, concise, light humor')
  console.log('  2. formal   — professional, structured')
  console.log('  3. mentor   — educational, explains why')
  console.log('  4. peer     — collaborative, direct')
  const personalityChoice = await ask('  Choose (1-4): ')
  const personalities = ['casual', 'formal', 'mentor', 'peer']
  const personality = personalities[parseInt(personalityChoice) - 1] ?? 'casual'

  // --- Write .env ---
  console.log('\nWriting .env...')
  const envContent = [
    '# Maestro Companion Configuration',
    `ANTHROPIC_API_KEY=${apiKey}`,
    `MAESTRO_TELEGRAM_TOKEN=${telegramToken}`,
    'ALLOWED_CHAT_IDS=',
    `MAESTRO_PERSONALITY=${personality}`,
    '',
    '# Voice',
    groqKey ? `GROQ_API_KEY=${groqKey}` : '# GROQ_API_KEY=',
    elevenLabsKey ? `ELEVENLABS_API_KEY=${elevenLabsKey}` : '# ELEVENLABS_API_KEY=',
    elevenLabsVoice ? `ELEVENLABS_VOICE_ID=${elevenLabsVoice}` : '# ELEVENLABS_VOICE_ID=',
  ].join('\n')

  writeFileSync(ENV_PATH, envContent)
  chmodSync(ENV_PATH, 0o600)
  console.log('  ✓ .env written (permissions: 600)')

  // --- Install deps ---
  console.log('\nInstalling dependencies...')
  try {
    execSync('npm install', { cwd: ROOT, stdio: 'inherit' })
    console.log('  ✓ Dependencies installed')
  } catch {
    console.error('  ✗ npm install failed')
  }

  // --- Get chat ID ---
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
  console.log('Almost done! Send /chatid to your bot on Telegram.')
  console.log('Then paste the chat ID here.')
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
  const chatId = await ask('\n  Your chat ID: ')

  // Update .env with chat ID
  const updatedEnv = envContent.replace('ALLOWED_CHAT_IDS=', `ALLOWED_CHAT_IDS=${chatId}`)
  writeFileSync(ENV_PATH, updatedEnv)
  console.log('  ✓ Chat ID saved')

  // --- Service install ---
  const wantService = (await ask('\n  Install as system service (auto-start on boot)? (y/n): ')).toLowerCase().startsWith('y')

  if (wantService) {
    try {
      execSync('bash ../scripts/maestro-service.sh install', { cwd: ROOT, stdio: 'inherit' })
    } catch {
      console.log('  Service install failed. You can start manually with: npm start')
    }
  }

  // --- Done ---
  console.log(`
  ╔══════════════════════════════════════╗
  ║     SETUP COMPLETE! 🎉             ║
  ╚══════════════════════════════════════╝

  Start:    cd companion && npm start
  Dev:      cd companion && bun run dev
  Status:   cd companion && npm run status

  Your bot is ready. Send a message on Telegram!
  `)

  rl.close()
}

main().catch(err => { console.error(err); process.exit(1) })
