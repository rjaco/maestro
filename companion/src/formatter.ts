const MAX_TELEGRAM_LENGTH = 4096

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
}

export function markdownToTelegramHtml(text: string): string {
  // Extract code blocks first to protect them from escaping
  const codeBlocks: string[] = []
  let processed = text.replace(/```(\w*)\n([\s\S]*?)```/g, (_match, lang: string, code: string) => {
    const idx = codeBlocks.length
    codeBlocks.push(`<pre><code class="language-${escapeHtml(lang)}">${escapeHtml(code)}</code></pre>`)
    return `\x00CODEBLOCK${idx}\x00`
  })

  // Extract inline code
  const inlineCode: string[] = []
  processed = processed.replace(/`([^`]+)`/g, (_match, code: string) => {
    const idx = inlineCode.length
    inlineCode.push(`<code>${escapeHtml(code)}</code>`)
    return `\x00INLINE${idx}\x00`
  })

  // Escape remaining HTML entities in plain text
  processed = escapeHtml(processed)

  // Apply markdown formatting on escaped text
  processed = processed
    .replace(/\*\*(.+?)\*\*/g, '<b>$1</b>')
    .replace(/(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)/g, '<i>$1</i>')
    .replace(/~~(.+?)~~/g, '<s>$1</s>')
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>')

  // Restore code blocks and inline code
  for (let i = 0; i < inlineCode.length; i++) {
    processed = processed.replace(`\x00INLINE${i}\x00`, inlineCode[i])
  }
  for (let i = 0; i < codeBlocks.length; i++) {
    processed = processed.replace(`\x00CODEBLOCK${i}\x00`, codeBlocks[i])
  }

  return processed
}

export function chunkMessage(text: string): string[] {
  if (text.length <= MAX_TELEGRAM_LENGTH) return [text]

  const chunks: string[] = []
  let remaining = text

  while (remaining.length > MAX_TELEGRAM_LENGTH) {
    // Find a good split point (newline near the limit)
    let splitAt = remaining.lastIndexOf('\n', MAX_TELEGRAM_LENGTH)
    if (splitAt < MAX_TELEGRAM_LENGTH * 0.5) {
      // No good newline, split at space
      splitAt = remaining.lastIndexOf(' ', MAX_TELEGRAM_LENGTH)
    }
    if (splitAt < MAX_TELEGRAM_LENGTH * 0.3) {
      // No good space either, hard split
      splitAt = MAX_TELEGRAM_LENGTH
    }
    chunks.push(remaining.slice(0, splitAt))
    remaining = remaining.slice(splitAt).trimStart()
  }

  if (remaining) chunks.push(remaining)
  return chunks
}
