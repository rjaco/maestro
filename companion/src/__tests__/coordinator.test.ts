import { describe, it, expect, vi, beforeEach } from 'vitest'

vi.mock('../workers/pool.js', () => ({
  spawnWorker: vi.fn(),
  getWorkerStats: vi.fn(),
}))

vi.mock('../state.js', () => ({
  readState: vi.fn(),
  formatStatus: vi.fn(),
}))

vi.mock('../logger.js', () => ({
  logger: {
    info: vi.fn(),
    error: vi.fn(),
    warn: vi.fn(),
    debug: vi.fn(),
  },
}))

import { isBuildRequest, handleBuildRequest } from '../workers/coordinator.js'
import { spawnWorker, getWorkerStats } from '../workers/pool.js'

beforeEach(() => {
  vi.mocked(spawnWorker).mockReset()
  vi.mocked(getWorkerStats).mockReset()
})

describe('isBuildRequest', () => {
  it('detects "build" as a build request', () => {
    expect(isBuildRequest('build a REST API')).toBe(true)
  })

  it('detects "implement" as a build request', () => {
    expect(isBuildRequest('implement the login flow')).toBe(true)
  })

  it('detects "fix" as a build request', () => {
    expect(isBuildRequest('fix the broken test')).toBe(true)
  })

  it('detects "create" as a build request', () => {
    expect(isBuildRequest('create a new component')).toBe(true)
  })

  it('does not flag a casual greeting as a build request', () => {
    expect(isBuildRequest('how are you today?')).toBe(false)
  })

  it('does not flag a status question as a build request', () => {
    expect(isBuildRequest('what is the current progress?')).toBe(false)
  })

  it('is case-insensitive', () => {
    expect(isBuildRequest('BUILD the feature')).toBe(true)
    expect(isBuildRequest('IMPLEMENT something')).toBe(true)
  })
})

describe('handleBuildRequest', () => {
  it('returns success message when worker completes', async () => {
    vi.mocked(spawnWorker).mockResolvedValue({
      id: 'w1',
      prompt: 'test',
      status: 'completed',
      startedAt: new Date(),
      result: 'Build succeeded! All tests pass.',
      costUsd: 0.0123,
    })
    vi.mocked(getWorkerStats).mockReturnValue({ running: 0, completed: 1, failed: 0, totalCost: 0.0123 })

    const progressCalls: string[] = []
    const result = await handleBuildRequest('build a feature', async (s) => { progressCalls.push(s) })

    expect(result).toContain('Build complete')
    expect(result).toContain('0.0123')
    expect(progressCalls.length).toBeGreaterThan(0)
  })

  it('returns failure message when worker fails', async () => {
    vi.mocked(spawnWorker).mockResolvedValue({
      id: 'w2',
      prompt: 'test',
      status: 'failed',
      startedAt: new Date(),
      costUsd: 0.001,
    })
    vi.mocked(getWorkerStats).mockReturnValue({ running: 0, completed: 0, failed: 1, totalCost: 0.001 })

    const result = await handleBuildRequest('implement something', async () => {})

    expect(result).toContain('failed')
  })

  it('calls onProgress at least once before spawning worker', async () => {
    const order: string[] = []

    vi.mocked(spawnWorker).mockImplementation(async (_prompt, onProg) => {
      order.push('spawn')
      onProg?.('w3', 'started')
      return { id: 'w3', prompt: '', status: 'completed', startedAt: new Date(), result: '', costUsd: 0 }
    })
    vi.mocked(getWorkerStats).mockReturnValue({ running: 0, completed: 1, failed: 0, totalCost: 0 })

    await handleBuildRequest('ship it', async (s) => { order.push(`progress:${s}`) })

    // First progress call should be a "Starting build..." message before spawn
    expect(order[0]).toMatch(/progress:.*[Ss]tarting/)
  })
})
