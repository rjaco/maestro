import Database from 'better-sqlite3'
import { config } from './config.js'
import { mkdirSync } from 'node:fs'
import { dirname } from 'node:path'
import { logger } from './logger.js'

mkdirSync(dirname(config.dbPath), { recursive: true })

const db = new Database(config.dbPath)
db.pragma('journal_mode = WAL')
db.pragma('synchronous = NORMAL')

// Sessions table
db.exec(`
  CREATE TABLE IF NOT EXISTS sessions (
    chat_id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    updated_at INTEGER NOT NULL DEFAULT (unixepoch())
  )
`)

logger.info({ path: config.dbPath }, 'Database initialized')

export function getSession(chatId: string): string | null {
  const row = db
    .prepare('SELECT session_id FROM sessions WHERE chat_id = ?')
    .get(chatId) as { session_id: string } | undefined
  return row?.session_id ?? null
}

export function saveSession(chatId: string, sessionId: string): void {
  db.prepare(`
    INSERT INTO sessions (chat_id, session_id, updated_at) VALUES (?, ?, unixepoch())
    ON CONFLICT(chat_id) DO UPDATE SET session_id = excluded.session_id, updated_at = unixepoch()
  `).run(chatId, sessionId)
}

export function clearSession(chatId: string): void {
  db.prepare('DELETE FROM sessions WHERE chat_id = ?').run(chatId)
}

export function closeDb(): void {
  db.close()
}

export default db
