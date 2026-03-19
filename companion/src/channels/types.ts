export interface IncomingMessage {
  chatId: string
  userId: string
  username: string
  text?: string
  voiceFileId?: string
  photoFileId?: string
  replyToMessageId?: string
}

export interface OutgoingMessage {
  chatId: string
  text?: string
  html?: string
  voiceBuffer?: Buffer
  replyToMessageId?: string
}

export interface ChannelAdapter {
  readonly name: string
  start(): Promise<void>
  stop(): Promise<void>
  send(msg: OutgoingMessage): Promise<void>
  sendTyping(chatId: string): Promise<void>
  onMessage(handler: (msg: IncomingMessage) => Promise<void>): void
}
