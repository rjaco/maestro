import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'

// ---- stt.ts tests ----

describe('transcribeAudio', () => {
  beforeEach(() => {
    vi.resetModules()
  })

  it('renames .oga to .ogg before sending to Groq', async () => {
    vi.doMock('../config.js', () => ({
      config: { groqApiKey: 'test-key' },
    }))
    vi.doMock('../logger.js', () => ({
      logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() },
    }))

    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ text: 'hello world' }),
    })
    vi.stubGlobal('fetch', mockFetch)

    const { transcribeAudio } = await import('../voice/stt.js')
    const result = await transcribeAudio(Buffer.from('audio'), 'voice.oga')

    expect(result).toBe('hello world')

    // Verify the FormData was built with the renamed file
    const formData = mockFetch.mock.calls[0][1].body as FormData
    const file = formData.get('file') as File
    expect(file.name ?? (formData as any)._entries?.find((e: any) => e.name === 'file')?.filename).not.toBe('voice.oga')

    vi.unstubAllGlobals()
  })

  it('passes .ogg filenames through unchanged', async () => {
    vi.doMock('../config.js', () => ({
      config: { groqApiKey: 'test-key' },
    }))
    vi.doMock('../logger.js', () => ({
      logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() },
    }))

    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ text: 'transcribed text' }),
    })
    vi.stubGlobal('fetch', mockFetch)

    const { transcribeAudio } = await import('../voice/stt.js')
    const result = await transcribeAudio(Buffer.from('audio'), 'voice.ogg')

    expect(result).toBe('transcribed text')
    expect(mockFetch).toHaveBeenCalledWith(
      'https://api.groq.com/openai/v1/audio/transcriptions',
      expect.objectContaining({
        method: 'POST',
        headers: expect.objectContaining({ Authorization: 'Bearer test-key' }),
      }),
    )

    vi.unstubAllGlobals()
  })

  it('throws when no STT provider is configured', async () => {
    vi.doMock('../config.js', () => ({
      config: { groqApiKey: '' },
    }))
    vi.doMock('../logger.js', () => ({
      logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() },
    }))

    const { transcribeAudio } = await import('../voice/stt.js')
    await expect(transcribeAudio(Buffer.from('audio'), 'voice.ogg')).rejects.toThrow(
      'No STT provider configured',
    )
  })

  it('throws with status code when Groq returns an error', async () => {
    vi.doMock('../config.js', () => ({
      config: { groqApiKey: 'test-key' },
    }))
    vi.doMock('../logger.js', () => ({
      logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() },
    }))

    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: false,
      status: 429,
      text: async () => 'rate limited',
    }))

    const { transcribeAudio } = await import('../voice/stt.js')
    await expect(transcribeAudio(Buffer.from('audio'), 'voice.ogg')).rejects.toThrow('Groq STT failed: 429')

    vi.unstubAllGlobals()
  })
})

// ---- tts.ts tests ----

describe('synthesizeSpeech', () => {
  beforeEach(() => {
    vi.resetModules()
  })

  it('uses ElevenLabs when both key and voiceId are set', async () => {
    vi.doMock('../config.js', () => ({
      config: {
        elevenlabsApiKey: 'el-key',
        elevenlabsVoiceId: 'voice-id',
        uploadDir: '/tmp',
      },
    }))
    vi.doMock('../logger.js', () => ({
      logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() },
    }))

    const audioData = new Uint8Array([1, 2, 3, 4])
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      arrayBuffer: async () => audioData.buffer,
    }))

    const { synthesizeSpeech } = await import('../voice/tts.js')
    const result = await synthesizeSpeech('Hello')

    expect(Buffer.isBuffer(result)).toBe(true)
    expect(result.length).toBe(4)

    vi.unstubAllGlobals()
  })

  it('truncates text longer than 1000 chars for TTS', async () => {
    vi.doMock('../config.js', () => ({
      config: {
        elevenlabsApiKey: 'el-key',
        elevenlabsVoiceId: 'voice-id',
        uploadDir: '/tmp',
      },
    }))
    vi.doMock('../logger.js', () => ({
      logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() },
    }))

    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      arrayBuffer: async () => new ArrayBuffer(8),
    })
    vi.stubGlobal('fetch', mockFetch)

    const { synthesizeSpeech } = await import('../voice/tts.js')
    const longText = 'a'.repeat(1500)
    await synthesizeSpeech(longText)

    const body = JSON.parse(mockFetch.mock.calls[0][1].body as string)
    expect(body.text.length).toBe(1003) // 1000 + '...'
    expect(body.text.endsWith('...')).toBe(true)

    vi.unstubAllGlobals()
  })

  it('throws when ElevenLabs returns an error', async () => {
    vi.doMock('../config.js', () => ({
      config: {
        elevenlabsApiKey: 'el-key',
        elevenlabsVoiceId: 'voice-id',
        uploadDir: '/tmp',
      },
    }))
    vi.doMock('../logger.js', () => ({
      logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() },
    }))

    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: false,
      status: 401,
      text: async () => 'unauthorized',
    }))

    const { synthesizeSpeech } = await import('../voice/tts.js')
    await expect(synthesizeSpeech('Hello')).rejects.toThrow('ElevenLabs TTS failed: 401')

    vi.unstubAllGlobals()
  })

  it('calls ElevenLabs with correct endpoint and headers', async () => {
    vi.doMock('../config.js', () => ({
      config: {
        elevenlabsApiKey: 'my-el-key',
        elevenlabsVoiceId: 'rachel',
        uploadDir: '/tmp',
      },
    }))
    vi.doMock('../logger.js', () => ({
      logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() },
    }))

    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      arrayBuffer: async () => new ArrayBuffer(4),
    })
    vi.stubGlobal('fetch', mockFetch)

    const { synthesizeSpeech } = await import('../voice/tts.js')
    await synthesizeSpeech('Test')

    expect(mockFetch).toHaveBeenCalledWith(
      'https://api.elevenlabs.io/v1/text-to-speech/rachel',
      expect.objectContaining({
        method: 'POST',
        headers: expect.objectContaining({
          'xi-api-key': 'my-el-key',
          Accept: 'audio/mpeg',
        }),
      }),
    )

    vi.unstubAllGlobals()
  })
})

// ---- pipeline.ts tests ----

describe('isVoiceAvailable', () => {
  beforeEach(() => {
    vi.resetModules()
  })

  it('reports stt true when groqApiKey is set', async () => {
    vi.doMock('../config.js', () => ({
      config: {
        groqApiKey: 'key',
        elevenlabsApiKey: '',
        elevenlabsVoiceId: '',
        uploadDir: '/tmp',
      },
    }))
    vi.doMock('../logger.js', () => ({
      logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() },
    }))
    vi.doMock('../voice/stt.js', () => ({ transcribeAudio: vi.fn() }))
    vi.doMock('../voice/tts.js', () => ({ synthesizeSpeech: vi.fn() }))

    const { isVoiceAvailable } = await import('../voice/pipeline.js')
    const result = isVoiceAvailable()
    expect(result.stt).toBe(true)
    expect(result.tts).toBe(false)
  })

  it('reports tts true when both elevenlabs keys are set', async () => {
    vi.doMock('../config.js', () => ({
      config: {
        groqApiKey: '',
        elevenlabsApiKey: 'el-key',
        elevenlabsVoiceId: 'voice-id',
        uploadDir: '/tmp',
      },
    }))
    vi.doMock('../logger.js', () => ({
      logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() },
    }))
    vi.doMock('../voice/stt.js', () => ({ transcribeAudio: vi.fn() }))
    vi.doMock('../voice/tts.js', () => ({ synthesizeSpeech: vi.fn() }))

    const { isVoiceAvailable } = await import('../voice/pipeline.js')
    const result = isVoiceAvailable()
    expect(result.tts).toBe(true)
    expect(result.stt).toBe(false)
  })

  it('reports both false when no keys configured', async () => {
    vi.doMock('../config.js', () => ({
      config: {
        groqApiKey: '',
        elevenlabsApiKey: '',
        elevenlabsVoiceId: '',
        uploadDir: '/tmp',
      },
    }))
    vi.doMock('../logger.js', () => ({
      logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() },
    }))
    vi.doMock('../voice/stt.js', () => ({ transcribeAudio: vi.fn() }))
    vi.doMock('../voice/tts.js', () => ({ synthesizeSpeech: vi.fn() }))

    const { isVoiceAvailable } = await import('../voice/pipeline.js')
    const result = isVoiceAvailable()
    expect(result.stt).toBe(false)
    expect(result.tts).toBe(false)
  })
})

describe('synthesizeResponse', () => {
  beforeEach(() => {
    vi.resetModules()
  })

  it('returns audio buffer on successful synthesis', async () => {
    vi.doMock('../config.js', () => ({
      config: {
        groqApiKey: 'key',
        elevenlabsApiKey: 'el-key',
        elevenlabsVoiceId: 'voice-id',
        uploadDir: '/tmp',
      },
    }))
    vi.doMock('../logger.js', () => ({
      logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() },
    }))
    vi.doMock('../voice/stt.js', () => ({ transcribeAudio: vi.fn() }))
    const mockBuffer = Buffer.from([1, 2, 3])
    vi.doMock('../voice/tts.js', () => ({
      synthesizeSpeech: vi.fn().mockResolvedValue(mockBuffer),
    }))

    const { synthesizeResponse } = await import('../voice/pipeline.js')
    const result = await synthesizeResponse('Hello')
    expect(result).toEqual(mockBuffer)
  })

  it('returns null when TTS throws', async () => {
    vi.doMock('../config.js', () => ({
      config: {
        groqApiKey: 'key',
        elevenlabsApiKey: 'el-key',
        elevenlabsVoiceId: 'voice-id',
        uploadDir: '/tmp',
      },
    }))
    vi.doMock('../logger.js', () => ({
      logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() },
    }))
    vi.doMock('../voice/stt.js', () => ({ transcribeAudio: vi.fn() }))
    vi.doMock('../voice/tts.js', () => ({
      synthesizeSpeech: vi.fn().mockRejectedValue(new Error('TTS failed')),
    }))

    const { synthesizeResponse } = await import('../voice/pipeline.js')
    const result = await synthesizeResponse('Hello')
    expect(result).toBeNull()
  })
})

describe('processVoiceInput', () => {
  beforeEach(() => {
    vi.resetModules()
  })

  it('downloads audio from Telegram and returns transcript', async () => {
    vi.doMock('../config.js', () => ({
      config: {
        groqApiKey: 'key',
        elevenlabsApiKey: '',
        elevenlabsVoiceId: '',
        uploadDir: '/tmp',
      },
    }))
    vi.doMock('../logger.js', () => ({
      logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() },
    }))
    vi.doMock('../voice/tts.js', () => ({ synthesizeSpeech: vi.fn() }))
    vi.doMock('../voice/stt.js', () => ({
      transcribeAudio: vi.fn().mockResolvedValue('voice transcript'),
    }))

    const mockFetch = vi.fn()
      .mockResolvedValueOnce({
        json: async () => ({
          ok: true,
          result: { file_path: 'voice/file_123.oga' },
        }),
      })
      .mockResolvedValueOnce({
        arrayBuffer: async () => new ArrayBuffer(16),
      })
    vi.stubGlobal('fetch', mockFetch)

    const { processVoiceInput } = await import('../voice/pipeline.js')
    const transcript = await processVoiceInput('file-id-abc', 'bot-token-xyz')

    expect(transcript).toBe('voice transcript')
    expect(mockFetch).toHaveBeenCalledWith(
      'https://api.telegram.org/botbot-token-xyz/getFile?file_id=file-id-abc',
    )
    expect(mockFetch).toHaveBeenCalledWith(
      'https://api.telegram.org/file/botbot-token-xyz/voice/file_123.oga',
    )

    vi.unstubAllGlobals()
  })

  it('throws when Telegram getFile returns ok: false', async () => {
    vi.doMock('../config.js', () => ({
      config: {
        groqApiKey: 'key',
        elevenlabsApiKey: '',
        elevenlabsVoiceId: '',
        uploadDir: '/tmp',
      },
    }))
    vi.doMock('../logger.js', () => ({
      logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() },
    }))
    vi.doMock('../voice/stt.js', () => ({ transcribeAudio: vi.fn() }))
    vi.doMock('../voice/tts.js', () => ({ synthesizeSpeech: vi.fn() }))

    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      json: async () => ({ ok: false }),
    }))

    const { processVoiceInput } = await import('../voice/pipeline.js')
    await expect(processVoiceInput('bad-id', 'token')).rejects.toThrow(
      'Failed to get file from Telegram',
    )

    vi.unstubAllGlobals()
  })
})
