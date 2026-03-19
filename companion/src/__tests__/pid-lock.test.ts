import { describe, it, before, after } from 'node:test'
import assert from 'node:assert/strict'
import { existsSync, writeFileSync, readFileSync, unlinkSync, mkdirSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

/**
 * Tests for PID lock logic extracted from index.ts as pure functions.
 */

function checkAndWritePid(
  pidPath: string,
  currentPid: number,
): 'started' | 'already_running' | 'stale_removed' {
  if (existsSync(pidPath)) {
    const existingPid = readFileSync(pidPath, 'utf-8').trim()
    try {
      process.kill(Number(existingPid), 0) // Signal 0 = check if alive
      return 'already_running'
    } catch {
      // Stale PID — process not running
    }
    writeFileSync(pidPath, String(currentPid))
    return 'stale_removed'
  }
  writeFileSync(pidPath, String(currentPid))
  return 'started'
}

function releasePid(pidPath: string): void {
  try {
    unlinkSync(pidPath)
  } catch {
    // ignore
  }
}

describe('PID lock logic', () => {
  let tmpDir: string
  let pidPath: string

  before(() => {
    tmpDir = join(tmpdir(), `maestro-test-${Date.now()}`)
    mkdirSync(tmpDir, { recursive: true })
    pidPath = join(tmpDir, 'companion.pid')
  })

  after(() => {
    releasePid(pidPath)
  })

  it('starts and writes PID file when no existing PID', () => {
    releasePid(pidPath) // ensure clean state
    const result = checkAndWritePid(pidPath, 12345)
    assert.equal(result, 'started')
    assert.ok(existsSync(pidPath))
    assert.equal(readFileSync(pidPath, 'utf-8'), '12345')
  })

  it('detects already running process', () => {
    writeFileSync(pidPath, String(process.pid)) // current process is alive
    const result = checkAndWritePid(pidPath, process.pid + 1)
    assert.equal(result, 'already_running')
  })

  it('handles stale PID file and overwrites with new PID', () => {
    writeFileSync(pidPath, '99999999') // unlikely to be running
    const result = checkAndWritePid(pidPath, 42)
    assert.equal(result, 'stale_removed')
    assert.equal(readFileSync(pidPath, 'utf-8'), '42')
  })

  it('releasePid removes the PID file', () => {
    writeFileSync(pidPath, '12345')
    releasePid(pidPath)
    assert.ok(!existsSync(pidPath))
  })

  it('releasePid does not throw if PID file missing', () => {
    releasePid(pidPath) // already removed
    assert.doesNotThrow(() => releasePid(pidPath))
  })
})
