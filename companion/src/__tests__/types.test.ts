import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import type { IncomingMessage, OutgoingMessage, ChannelAdapter } from '../channels/types.js'

describe('ChannelAdapter interface types', () => {
  it('IncomingMessage has required fields', () => {
    const msg: IncomingMessage = {
      chatId: '123',
      userId: '456',
      username: 'testuser',
    }
    assert.equal(msg.chatId, '123')
    assert.equal(msg.userId, '456')
    assert.equal(msg.username, 'testuser')
  })

  it('IncomingMessage supports optional media fields', () => {
    const msg: IncomingMessage = {
      chatId: '123',
      userId: '456',
      username: 'testuser',
      voiceFileId: 'voice_abc',
      photoFileId: 'photo_xyz',
      replyToMessageId: '789',
    }
    assert.equal(msg.voiceFileId, 'voice_abc')
    assert.equal(msg.photoFileId, 'photo_xyz')
    assert.equal(msg.replyToMessageId, '789')
  })

  it('OutgoingMessage supports text and html variants', () => {
    const textMsg: OutgoingMessage = { chatId: '123', text: 'Hello' }
    const htmlMsg: OutgoingMessage = { chatId: '123', html: '<b>Hello</b>' }
    assert.equal(textMsg.text, 'Hello')
    assert.equal(htmlMsg.html, '<b>Hello</b>')
  })

  it('OutgoingMessage supports voiceBuffer', () => {
    const voiceMsg: OutgoingMessage = {
      chatId: '123',
      voiceBuffer: Buffer.from('fake-ogg-data'),
    }
    assert.ok(voiceMsg.voiceBuffer !== undefined)
    assert.ok(Buffer.isBuffer(voiceMsg.voiceBuffer))
  })

  it('ChannelAdapter interface can be implemented', () => {
    class MockAdapter implements ChannelAdapter {
      readonly name = 'mock'
      async start() {}
      async stop() {}
      async send(_msg: OutgoingMessage) {}
      async sendTyping(_chatId: string) {}
      onMessage(_handler: (msg: IncomingMessage) => Promise<void>) {}
    }

    const adapter = new MockAdapter()
    assert.equal(adapter.name, 'mock')
    assert.equal(typeof adapter.start, 'function')
    assert.equal(typeof adapter.stop, 'function')
    assert.equal(typeof adapter.send, 'function')
    assert.equal(typeof adapter.sendTyping, 'function')
    assert.equal(typeof adapter.onMessage, 'function')
  })
})
