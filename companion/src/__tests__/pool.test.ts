import { describe, it, expect, vi, beforeEach } from 'vitest'

// Mock the Agent SDK query so we don't make real API calls
vi.mock('@anthropic-ai/claude-agent-sdk', () => ({
  query: vi.fn(),
}))

// Mock config
vi.mock('../config.js', () => ({
  config: {
    projectRoot: '/tmp/pool-test',
    buildModel: 'claude-sonnet',
    maxWorkers: 2,
  },
}))

// Mock logger
vi.mock('../logger.js', () => ({
  logger: {
    info: vi.fn(),
    error: vi.fn(),
    warn: vi.fn(),
    debug: vi.fn(),
  },
}))

// Mock fs operations
vi.mock('node:fs', async (importOriginal) => {
  const actual = await importOriginal<typeof import('node:fs')>()
  return {
    ...actual,
    writeFileSync: vi.fn(),
    mkdirSync: vi.fn(),
    unlinkSync: vi.fn(),
    existsSync: vi.fn().mockReturnValue(true),
    readFileSync: actual.readFileSync,
  }
})

import { query } from '@anthropic-ai/claude-agent-sdk'
import { spawnWorker, spawnParallelWorkers, getActiveWorkers, getWorkerStats } from '../workers/pool.js'

async function* makeSuccessStream(result: string, cost: number) {
  yield { type: 'result', subtype: 'success', result, total_cost_usd: cost, session_id: 'sess-1' }
}

async function* makeFailStream(cost: number) {
  yield { type: 'result', subtype: 'error_max_turns', total_cost_usd: cost }
}

async function* makeThrowStream() {
  throw new Error('SDK exploded')
  yield // make it a generator
}

beforeEach(() => {
  vi.mocked(query).mockReset()
})

describe('spawnWorker', () => {
  it('returns a completed worker on SDK success', async () => {
    vi.mocked(query).mockReturnValue(makeSuccessStream('done!', 0.05) as ReturnType<typeof query>)
    const worker = await spawnWorker('Build something')
    expect(worker.status).toBe('completed')
    expect(worker.result).toBe('done!')
    expect(worker.costUsd).toBe(0.05)
  })

  it('returns a failed worker when SDK emits error subtype', async () => {
    vi.mocked(query).mockReturnValue(makeFailStream(0.01) as ReturnType<typeof query>)
    const worker = await spawnWorker('Build something')
    expect(worker.status).toBe('failed')
    expect(worker.costUsd).toBe(0.01)
  })

  it('returns a failed worker when SDK throws', async () => {
    vi.mocked(query).mockReturnValue(makeThrowStream() as ReturnType<typeof query>)
    const worker = await spawnWorker('Build something')
    expect(worker.status).toBe('failed')
  })

  it('calls onProgress with started and completed', async () => {
    vi.mocked(query).mockReturnValue(makeSuccessStream('ok', 0.01) as ReturnType<typeof query>)
    const calls: string[] = []
    await spawnWorker('prompt', (id, status) => { calls.push(status) })
    expect(calls).toContain('started')
    expect(calls).toContain('completed')
  })

  it('assigns a unique id to each worker', async () => {
    vi.mocked(query).mockReturnValue(makeSuccessStream('ok', 0) as ReturnType<typeof query>)
    const w1 = await spawnWorker('p1')
    vi.mocked(query).mockReturnValue(makeSuccessStream('ok', 0) as ReturnType<typeof query>)
    const w2 = await spawnWorker('p2')
    expect(w1.id).not.toBe(w2.id)
  })
})

describe('spawnParallelWorkers', () => {
  it('runs all prompts and returns results', async () => {
    // Each call to query must return a fresh async generator
    vi.mocked(query).mockImplementation(() => makeSuccessStream('result', 0.01) as ReturnType<typeof query>)
    const workers = await spawnParallelWorkers(['a', 'b', 'c'])
    expect(workers).toHaveLength(3)
    expect(workers.every(w => w.status === 'completed')).toBe(true)
  })

  it('respects maxConcurrent batching', async () => {
    let concurrent = 0
    let maxSeen = 0

    vi.mocked(query).mockImplementation(() => {
      concurrent++
      maxSeen = Math.max(maxSeen, concurrent)
      return (async function* () {
        await new Promise(r => setTimeout(r, 10))
        concurrent--
        yield { type: 'result', subtype: 'success', result: 'done', total_cost_usd: 0, session_id: 'x' }
      })() as ReturnType<typeof query>
    })

    await spawnParallelWorkers(['a', 'b', 'c', 'd'], 2)
    expect(maxSeen).toBeLessThanOrEqual(2)
  })

  it('returns empty array for empty prompts list', async () => {
    const workers = await spawnParallelWorkers([])
    expect(workers).toHaveLength(0)
  })
})

describe('getWorkerStats', () => {
  it('counts completed and failed workers and sums cost', async () => {
    vi.mocked(query).mockReturnValueOnce(makeSuccessStream('ok', 0.10) as ReturnType<typeof query>)
    vi.mocked(query).mockReturnValueOnce(makeFailStream(0.02) as ReturnType<typeof query>)
    await spawnWorker('good')
    await spawnWorker('bad')
    const stats = getWorkerStats()
    expect(stats.completed).toBeGreaterThanOrEqual(1)
    expect(stats.failed).toBeGreaterThanOrEqual(1)
    expect(stats.totalCost).toBeGreaterThan(0)
  })
})
