import { Bot, InputFile } from 'grammy'
import type { ChannelAdapter, IncomingMessage, OutgoingMessage } from './types.js'

export class TelegramAdapter implements ChannelAdapter {
  readonly name = 'telegram'
  private bot: Bot
  private handler?: (msg: IncomingMessage) => Promise<void>
  private allowedChatIds: Set<string>

  constructor(token: string, allowedChatIds: string[]) {
    this.bot = new Bot(token)
    this.allowedChatIds = new Set(allowedChatIds)
    this.setupHandlers()
  }

  private isAuthorized(chatId: string): boolean {
    // If no allowlist configured, accept first user (first-run mode)
    if (this.allowedChatIds.size === 0) return true
    return this.allowedChatIds.has(chatId)
  }

  private setupHandlers(): void {
    // /chatid command — always available, returns the chat ID
    this.bot.command('chatid', async (ctx) => {
      await ctx.reply(`Your chat ID: \`${ctx.chat.id}\``, { parse_mode: 'MarkdownV2' })
    })

    // /start command
    this.bot.command('start', async (ctx) => {
      if (!this.isAuthorized(String(ctx.chat.id))) {
        await ctx.reply('Unauthorized. Your chat ID is: ' + ctx.chat.id)
        return
      }
      await ctx.reply(
        '👋 Hey! I\'m Maestro, your AI companion.\n\n' +
        'Send me a message and I\'ll help you out.\n' +
        'Send /newchat to start a fresh conversation.\n' +
        'Send /voice to toggle voice replies.'
      )
    })

    // /newchat command — clear session
    this.bot.command('newchat', async (ctx) => {
      if (!this.isAuthorized(String(ctx.chat.id))) return
      if (this.handler) {
        await this.handler({
          chatId: String(ctx.chat.id),
          userId: String(ctx.from?.id ?? ''),
          username: ctx.from?.username ?? '',
          text: '/newchat',
        })
      }
    })

    // Text messages
    this.bot.on('message:text', async (ctx) => {
      const chatId = String(ctx.chat.id)
      if (!this.isAuthorized(chatId)) return
      if (!this.handler) return

      await this.handler({
        chatId,
        userId: String(ctx.from?.id ?? ''),
        username: ctx.from?.username ?? '',
        text: ctx.message.text,
      })
    })

    // Voice messages
    this.bot.on('message:voice', async (ctx) => {
      const chatId = String(ctx.chat.id)
      if (!this.isAuthorized(chatId)) return
      if (!this.handler) return

      await this.handler({
        chatId,
        userId: String(ctx.from?.id ?? ''),
        username: ctx.from?.username ?? '',
        voiceFileId: ctx.message.voice.file_id,
      })
    })

    // Photo messages
    this.bot.on('message:photo', async (ctx) => {
      const chatId = String(ctx.chat.id)
      if (!this.isAuthorized(chatId)) return
      if (!this.handler) return

      const photos = ctx.message.photo
      const largest = photos[photos.length - 1]

      await this.handler({
        chatId,
        userId: String(ctx.from?.id ?? ''),
        username: ctx.from?.username ?? '',
        text: ctx.message.caption ?? '[Photo]',
        photoFileId: largest.file_id,
      })
    })
  }

  onMessage(handler: (msg: IncomingMessage) => Promise<void>): void {
    this.handler = handler
  }

  async start(): Promise<void> {
    await this.bot.start({ drop_pending_updates: true })
  }

  async stop(): Promise<void> {
    await this.bot.stop()
  }

  async send(msg: OutgoingMessage): Promise<void> {
    if (msg.voiceBuffer) {
      await this.bot.api.sendVoice(msg.chatId, new InputFile(msg.voiceBuffer, 'reply.ogg'))
      return
    }

    const text = msg.html ?? msg.text ?? ''
    if (!text) return

    // Chunk long messages
    const chunks = chunkText(text, 4096)
    for (const chunk of chunks) {
      await this.bot.api.sendMessage(msg.chatId, chunk, {
        parse_mode: msg.html ? 'HTML' : undefined,
        ...(msg.replyToMessageId ? { reply_to_message_id: Number(msg.replyToMessageId) } : {}),
      })
    }
  }

  async sendTyping(chatId: string): Promise<void> {
    try {
      await this.bot.api.sendChatAction(chatId, 'typing')
    } catch {
      // Ignore typing errors
    }
  }
}

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
