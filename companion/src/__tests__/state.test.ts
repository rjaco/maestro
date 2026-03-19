import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { writeFileSync, mkdirSync, unlinkSync, existsSync, rmSync } from 'node:fs'
import { resolve } from 'node:path'
import { tmpdir } from 'node:os'

// vi.mock and vi.hoisted are both hoisted before any imports resolve.
// We must compute the tmp path using require() or inline literals only.
const { tmpRoot } = vi.hoisted(() => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const os = require('os') as typeof import('os')
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require('path') as typeof import('path')
  return { tmpRoot: path.resolve(os.tmpdir(), `state-test-${process.pid}`) }
})

vi.mock('../config.js', () => ({
  config: {
    projectRoot: tmpRoot,
  },
}))

// Import after mock is set up
import { readState, readHeartbeat, formatStatus } from '../state.js'

function writeMaestroDir(): void {
  mkdirSync(resolve(tmpRoot, '.maestro', 'logs'), { recursive: true })
}

function writeStateFile(content: string): void {
  writeFileSync(resolve(tmpRoot, '.maestro', 'state.local.md'), content, 'utf-8')
}

function writeHeartbeatFile(timestamp: string): void {
  writeFileSync(resolve(tmpRoot, '.maestro', 'logs', 'heartbeat'), timestamp, 'utf-8')
}

beforeEach(() => {
  writeMaestroDir()
})

afterEach(() => {
  if (existsSync(tmpRoot)) rmSync(tmpRoot, { recursive: true, force: true })
})

const SAMPLE_STATE = `---
active: true
feature: my-feature
phase: implementation
layer: backend
opus_mode: magnum
current_milestone: 2
total_milestones: 5
current_story: 3
total_stories: 10
token_spend: 12345
consecutive_failures: 0
---

Some body text.
`

describe('readState', () => {
  it('returns null when state.local.md does not exist', () => {
    expect(readState()).toBeNull()
  })

  it('parses a valid state file', () => {
    writeStateFile(SAMPLE_STATE)
    const state = readState()
    expect(state).not.toBeNull()
    expect(state!.active).toBe(true)
    expect(state!.feature).toBe('my-feature')
    expect(state!.phase).toBe('implementation')
    expect(state!.layer).toBe('backend')
    expect(state!.opusMode).toBe('magnum')
    expect(state!.currentMilestone).toBe(2)
    expect(state!.totalMilestones).toBe(5)
    expect(state!.currentStory).toBe(3)
    expect(state!.totalStories).toBe(10)
    expect(state!.tokenSpend).toBe(12345)
    expect(state!.consecutiveFailures).toBe(0)
  })

  it('treats active: false as false', () => {
    writeStateFile(`---\nactive: false\nfeature: x\nphase: y\nlayer: z\n---\n`)
    const state = readState()
    expect(state!.active).toBe(false)
  })

  it('handles missing optional fields with safe defaults', () => {
    writeStateFile(`---\nactive: true\n---\n`)
    const state = readState()
    expect(state!.feature).toBe('')
    expect(state!.currentMilestone).toBe(0)
    expect(state!.tokenSpend).toBe(0)
  })

  it('strips quotes from yaml values', () => {
    writeStateFile(`---\nfeature: "quoted-feature"\nphase: 'single-quoted'\n---\n`)
    const state = readState()
    expect(state!.feature).toBe('quoted-feature')
    expect(state!.phase).toBe('single-quoted')
  })
})

describe('readHeartbeat', () => {
  it('returns null when heartbeat file does not exist', () => {
    expect(readHeartbeat()).toBeNull()
  })

  it('returns timestamp and age when heartbeat exists', () => {
    const now = new Date().toISOString()
    writeHeartbeatFile(now)
    const hb = readHeartbeat()
    expect(hb).not.toBeNull()
    expect(hb!.timestamp).toBe(now)
    expect(hb!.age).toBeGreaterThanOrEqual(0)
    expect(hb!.age).toBeLessThan(10) // should be very recent
  })

  it('computes age in seconds from timestamp', () => {
    // Write a timestamp 2 minutes ago
    const past = new Date(Date.now() - 120_000).toISOString()
    writeHeartbeatFile(past)
    const hb = readHeartbeat()
    expect(hb!.age).toBeGreaterThanOrEqual(119)
    expect(hb!.age).toBeLessThanOrEqual(121)
  })
})

describe('formatStatus', () => {
  it('returns no-session message when state file is absent', () => {
    const result = formatStatus()
    expect(result).toBe('No active Maestro session.')
  })

  it('includes feature, phase, and milestone in output', () => {
    writeStateFile(SAMPLE_STATE)
    const result = formatStatus()
    expect(result).toContain('my-feature')
    expect(result).toContain('implementation')
    expect(result).toContain('2/5')
    expect(result).toContain('3/10')
  })

  it('includes heartbeat age when heartbeat file is present', () => {
    writeStateFile(SAMPLE_STATE)
    writeHeartbeatFile(new Date().toISOString())
    const result = formatStatus()
    expect(result).toContain('Heartbeat')
  })

  it('includes token spend when non-zero', () => {
    writeStateFile(SAMPLE_STATE)
    const result = formatStatus()
    expect(result).toContain('12345')
  })
})
