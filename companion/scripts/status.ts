#!/usr/bin/env node
/**
 * Maestro Companion Status Check
 * Usage: npx maestro-companion status
 */
import { existsSync, readFileSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(__dirname, '..')

console.log('\nMaestro Companion Status\n========================\n')

// Check .env
const envPath = resolve(ROOT, '.env')
if (existsSync(envPath)) {
  console.log('  ✓ .env configured')
} else {
  console.log('  ✗ .env missing — run: npm run setup')
}

// Check PID
const pidPath = resolve(ROOT, 'store', 'companion.pid')
if (existsSync(pidPath)) {
  const pid = readFileSync(pidPath, 'utf-8').trim()
  try {
    process.kill(Number(pid), 0)
    console.log(`  ✓ Companion running (PID ${pid})`)
  } catch {
    console.log(`  ✗ Stale PID file (${pid} not running)`)
  }
} else {
  console.log('  ○ Companion not running')
}

// Check DB
const dbPath = resolve(ROOT, 'store', 'companion.db')
if (existsSync(dbPath)) {
  console.log('  ✓ Database exists')
} else {
  console.log('  ○ No database (will be created on first run)')
}

// Check logs
const logPath = resolve(ROOT, 'store', 'companion.log')
if (existsSync(logPath)) {
  console.log('  ✓ Logs available: store/companion.log')
} else {
  console.log('  ○ No logs yet')
}

console.log('')
