import db from './db.js'
import { logger } from './logger.js'

type Sector = 'semantic' | 'episodic'
const SEMANTIC_SIGNALS = /\b(my|i am|i'm|i prefer|remember|always|never|from now on|don't|stop)\b/i
let ftsAvailable = false

export function initMemoryTables(): void {
  db.exec(`
    CREATE TABLE IF NOT EXISTS memories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      chat_id TEXT NOT NULL,
      content TEXT NOT NULL,
      sector TEXT NOT NULL CHECK(sector IN ('semantic','episodic')),
      salience REAL NOT NULL DEFAULT 1.0,
      created_at INTEGER NOT NULL DEFAULT (unixepoch()),
      accessed_at INTEGER NOT NULL DEFAULT (unixepoch())
    )
  `)
  db.exec(`CREATE INDEX IF NOT EXISTS idx_memories_chat ON memories(chat_id, sector)`)
  db.exec(`CREATE INDEX IF NOT EXISTS idx_memories_salience ON memories(salience)`)

  try {
    db.exec(`CREATE VIRTUAL TABLE IF NOT EXISTS memories_fts USING fts5(content, content=memories, content_rowid=id)`)
    db.exec(`CREATE TRIGGER IF NOT EXISTS memories_ai AFTER INSERT ON memories BEGIN INSERT INTO memories_fts(rowid, content) VALUES (new.id, new.content); END`)
    db.exec(`CREATE TRIGGER IF NOT EXISTS memories_ad AFTER DELETE ON memories BEGIN INSERT INTO memories_fts(memories_fts, rowid, content) VALUES('delete', old.id, old.content); END`)
    ftsAvailable = true
  } catch {
    logger.warn('FTS5 not available, using LIKE search fallback')
  }
  logger.info('Memory tables initialized')
}

export function saveMemory(chatId: string, content: string): void {
  if (content.length < 20 || content.startsWith('/')) return
  const sector: Sector = SEMANTIC_SIGNALS.test(content) ? 'semantic' : 'episodic'
  db.prepare('INSERT INTO memories (chat_id, content, sector) VALUES (?, ?, ?)').run(chatId, content, sector)
}

export function buildMemoryContext(chatId: string, userMessage: string): string {
  type MemRow = { id: number; content: string; sector: string; salience: number }
  const memories: MemRow[] = []

  if (ftsAvailable) {
    try {
      // Sanitize FTS5 operators
      const FTS5_OPERATORS = new Set(['AND', 'OR', 'NOT', 'NEAR'])

      const terms = userMessage
        .replace(/[^\w\s]/g, '')
        .split(/\s+/)
        .filter(w => w.length > 2)
        .filter(w => !FTS5_OPERATORS.has(w.toUpperCase()))
        .slice(0, 5)
        .map(w => `"${w}"`)
        .join(' OR ')
      if (terms) {
        const rows = db.prepare('SELECT m.id, m.content, m.sector, m.salience FROM memories m JOIN memories_fts fts ON m.id = fts.rowid WHERE m.chat_id = ? AND memories_fts MATCH ? ORDER BY fts.rank LIMIT 3').all(chatId, terms) as MemRow[]
        memories.push(...rows)
      }
    } catch { /* FTS query failed */ }
  } else {
    const words = userMessage.split(/\s+/).filter(w => w.length > 3).slice(0, 3)
    for (const word of words) {
      const rows = db.prepare('SELECT id, content, sector, salience FROM memories WHERE chat_id = ? AND content LIKE ? ORDER BY salience DESC LIMIT 1').all(chatId, `%${word}%`) as MemRow[]
      memories.push(...rows)
    }
  }

  const recent = db.prepare('SELECT id, content, sector, salience FROM memories WHERE chat_id = ? ORDER BY accessed_at DESC LIMIT 5').all(chatId) as MemRow[]
  const seen = new Set(memories.map(m => m.id))
  for (const r of recent) { if (!seen.has(r.id)) { memories.push(r); seen.add(r.id) } }

  if (memories.length === 0) return ''

  const ids = memories.map(m => m.id)
  db.prepare(`UPDATE memories SET accessed_at = unixepoch(), salience = MIN(salience + 0.1, 5.0) WHERE id IN (${ids.map(() => '?').join(',')})`).run(...ids)

  return memories.map(m => `- ${m.content} (${m.sector})`).join('\n')
}

export function runDecaySweep(): number {
  const oneDayAgo = Math.floor(Date.now() / 1000) - 86400
  db.prepare('UPDATE memories SET salience = salience * 0.98 WHERE sector = ? AND created_at < ?').run('semantic', oneDayAgo)
  db.prepare('UPDATE memories SET salience = salience * 0.90 WHERE sector = ? AND created_at < ?').run('episodic', oneDayAgo)
  const deleted = db.prepare('DELETE FROM memories WHERE salience < 0.1').run()
  logger.info({ deleted: deleted.changes }, 'Memory decay sweep complete')
  return deleted.changes
}

export function getMemoryStats(chatId: string): { semantic: number; episodic: number; total: number } {
  const s = (db.prepare('SELECT COUNT(*) as c FROM memories WHERE chat_id = ? AND sector = ?').get(chatId, 'semantic') as { c: number }).c
  const e = (db.prepare('SELECT COUNT(*) as c FROM memories WHERE chat_id = ? AND sector = ?').get(chatId, 'episodic') as { c: number }).c
  return { semantic: s, episodic: e, total: s + e }
}
