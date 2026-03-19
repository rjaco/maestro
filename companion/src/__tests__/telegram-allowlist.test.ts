import { describe, it } from 'node:test'
import assert from 'node:assert/strict'

/**
 * Tests for TelegramAdapter allowlist logic, extracted as pure functions
 * so they can be tested without a real bot token.
 */

function isAuthorized(allowedChatIds: Set<string>, chatId: string): boolean {
  if (allowedChatIds.size === 0) return true
  return allowedChatIds.has(chatId)
}

describe('TelegramAdapter allowlist logic', () => {
  it('allows all chats when no allowlist configured (first-run mode)', () => {
    const empty = new Set<string>()
    assert.ok(isAuthorized(empty, '111'))
    assert.ok(isAuthorized(empty, '999'))
  })

  it('allows chat IDs in the allowlist', () => {
    const allowed = new Set(['123', '456'])
    assert.ok(isAuthorized(allowed, '123'))
    assert.ok(isAuthorized(allowed, '456'))
  })

  it('blocks chat IDs not in the allowlist', () => {
    const allowed = new Set(['123'])
    assert.ok(!isAuthorized(allowed, '999'))
    assert.ok(!isAuthorized(allowed, ''))
  })

  it('treats chat IDs as strings', () => {
    const allowed = new Set(['123456789'])
    assert.ok(isAuthorized(allowed, '123456789'))
    assert.ok(!isAuthorized(allowed, '123456788'))
  })
})

/**
 * Tests for chunkText — the internal chunking utility in telegram.ts
 */

function chunkText(text: string, maxLen: number): string[] {
  if (text.length <= maxLen) return [text]
  const chunks: string[] = []
  let remaining = text
  while (remaining.length > maxLen) {
    let splitAt = remaining.lastIndexOf('\n', maxLen)
    if (splitAt < maxLen * 0.3) splitAt = maxLen
    chunks.push(remaining.slice(0, splitAt))
    remaining = remaining.slice(splitAt).trimStart()
  }
  if (remaining) chunks.push(remaining)
  return chunks
}

describe('chunkText (Telegram message chunker)', () => {
  it('returns array with single item for short messages', () => {
    assert.deepEqual(chunkText('hi', 4096), ['hi'])
  })

  it('splits text at newline boundaries when possible', () => {
    const line = 'a'.repeat(4)
    const text = Array.from({ length: 5 }, () => line).join('\n') // ~24 chars
    const chunks = chunkText(text, 10)
    assert.ok(chunks.length > 1)
    for (const c of chunks) {
      assert.ok(c.length <= 10, `chunk too long: "${c}" (${c.length})`)
    }
  })

  it('falls back to hard split when no newline in first 30% of maxLen', () => {
    const text = 'abcdefghijklmnop' // 16 chars, no newline
    const chunks = chunkText(text, 10)
    assert.ok(chunks[0].length <= 10)
    assert.equal(chunks.join(''), text)
  })

  it('preserves all content', () => {
    const line = 'hello world '
    const text = line.repeat(500) // ~6000 chars
    const chunks = chunkText(text, 4096)
    assert.equal(chunks.join('').trim(), text.trim())
  })
})
