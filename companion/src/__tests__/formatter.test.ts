import { describe, it, expect } from 'vitest'
import { markdownToTelegramHtml, chunkMessage } from '../formatter.js'

describe('markdownToTelegramHtml', () => {
  it('converts bold markdown to HTML bold tags', () => {
    expect(markdownToTelegramHtml('Hello **world**')).toBe('Hello <b>world</b>')
  })

  it('converts italic markdown to HTML italic tags', () => {
    expect(markdownToTelegramHtml('Hello *world*')).toBe('Hello <i>world</i>')
  })

  it('converts inline code to HTML code tags', () => {
    expect(markdownToTelegramHtml('Use `npm install`')).toBe('Use <code>npm install</code>')
  })

  it('converts fenced code blocks to pre/code tags', () => {
    const input = '```ts\nconst x = 1\n```'
    const output = markdownToTelegramHtml(input)
    expect(output).toBe('<pre><code class="language-ts">const x = 1\n</code></pre>')
  })

  it('converts strikethrough to HTML s tags', () => {
    expect(markdownToTelegramHtml('~~deleted~~')).toBe('<s>deleted</s>')
  })

  it('converts markdown links to HTML anchor tags', () => {
    expect(markdownToTelegramHtml('[Click here](https://example.com)')).toBe(
      '<a href="https://example.com">Click here</a>',
    )
  })

  it('leaves plain text unchanged', () => {
    expect(markdownToTelegramHtml('Just plain text.')).toBe('Just plain text.')
  })

  it('wraps code blocks in pre/code tags regardless of inner content', () => {
    const input = '```\nsome code\n```'
    const output = markdownToTelegramHtml(input)
    expect(output).toContain('<pre>')
    expect(output).toContain('<code')
  })
})

describe('chunkMessage', () => {
  it('returns single-element array for short messages', () => {
    const chunks = chunkMessage('Hello world')
    expect(chunks).toHaveLength(1)
    expect(chunks[0]).toBe('Hello world')
  })

  it('returns single-element array for exactly MAX_TELEGRAM_LENGTH message', () => {
    const text = 'a'.repeat(4096)
    const chunks = chunkMessage(text)
    expect(chunks).toHaveLength(1)
  })

  it('splits a long message into multiple chunks', () => {
    // Build a message longer than 4096 chars with newlines for clean splits
    const line = 'x'.repeat(100) + '\n'
    const text = line.repeat(50) // 5050 chars total
    const chunks = chunkMessage(text)
    expect(chunks.length).toBeGreaterThan(1)
    for (const chunk of chunks) {
      expect(chunk.length).toBeLessThanOrEqual(4096)
    }
  })

  it('reassembles chunks to original content (minus trimmed whitespace)', () => {
    const line = 'word '.repeat(20) + '\n'
    const text = line.repeat(40) // ~840 chars, under limit; use larger to force split
    const bigText = text.repeat(6) // ~5040 chars
    const chunks = chunkMessage(bigText)
    const reassembled = chunks.join('\n')
    // All words from original should still be present
    expect(reassembled.replace(/\s+/g, ' ').trim()).toBe(bigText.replace(/\s+/g, ' ').trim())
  })

  it('handles hard split when no good split point exists', () => {
    // A single continuous word longer than MAX_TELEGRAM_LENGTH
    const text = 'a'.repeat(5000)
    const chunks = chunkMessage(text)
    expect(chunks.length).toBeGreaterThan(1)
    for (const chunk of chunks) {
      expect(chunk.length).toBeLessThanOrEqual(4096)
    }
  })
})
