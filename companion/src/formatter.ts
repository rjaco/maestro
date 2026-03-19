const MAX_TELEGRAM_LENGTH = 4096

export function markdownToTelegramHtml(text: string): string {
  return text
    // Code blocks first (preserve content)
    .replace(/```(\w*)\n([\s\S]*?)```/g, '<pre><code class="language-$1">$2</code></pre>')
    // Inline code
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    // Bold
    .replace(/\*\*(.+?)\*\*/g, '<b>$1</b>')
    // Italic
    .replace(/(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)/g, '<i>$1</i>')
    // Strikethrough
    .replace(/~~(.+?)~~/g, '<s>$1</s>')
    // Links
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>')
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
