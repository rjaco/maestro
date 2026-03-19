import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { writeFileSync, unlinkSync, existsSync } from 'node:fs'
import { resolve } from 'node:path'
import { tmpdir } from 'node:os'
import { readEnvFile } from '../env.js'

const tmpEnvPath = resolve(tmpdir(), `test-companion-${process.pid}.env`)

function writeTmpEnv(content: string): void {
  writeFileSync(tmpEnvPath, content, 'utf-8')
}

afterEach(() => {
  if (existsSync(tmpEnvPath)) unlinkSync(tmpEnvPath)
})

describe('readEnvFile', () => {
  it('returns empty object when file does not exist', () => {
    const result = readEnvFile('/nonexistent/path/.env')
    expect(result).toEqual({})
  })

  it('parses simple KEY=VALUE pairs', () => {
    writeTmpEnv('FOO=bar\nBAZ=qux\n')
    const result = readEnvFile(tmpEnvPath)
    expect(result).toEqual({ FOO: 'bar', BAZ: 'qux' })
  })

  it('skips blank lines', () => {
    writeTmpEnv('\nFOO=bar\n\nBAZ=qux\n')
    const result = readEnvFile(tmpEnvPath)
    expect(result).toEqual({ FOO: 'bar', BAZ: 'qux' })
  })

  it('skips comment lines starting with #', () => {
    writeTmpEnv('# this is a comment\nFOO=bar\n')
    const result = readEnvFile(tmpEnvPath)
    expect(result).toEqual({ FOO: 'bar' })
  })

  it('strips double quotes from values', () => {
    writeTmpEnv('FOO="hello world"\n')
    const result = readEnvFile(tmpEnvPath)
    expect(result).toEqual({ FOO: 'hello world' })
  })

  it('strips single quotes from values', () => {
    writeTmpEnv("FOO='hello world'\n")
    const result = readEnvFile(tmpEnvPath)
    expect(result).toEqual({ FOO: 'hello world' })
  })

  it('handles values containing = signs', () => {
    writeTmpEnv('URL=https://example.com?a=1&b=2\n')
    const result = readEnvFile(tmpEnvPath)
    expect(result).toEqual({ URL: 'https://example.com?a=1&b=2' })
  })

  it('skips lines without = sign', () => {
    writeTmpEnv('INVALID_LINE\nFOO=bar\n')
    const result = readEnvFile(tmpEnvPath)
    expect(result).toEqual({ FOO: 'bar' })
  })

  it('trims whitespace around keys', () => {
    writeTmpEnv('  FOO  =bar\n')
    const result = readEnvFile(tmpEnvPath)
    expect(result).toEqual({ FOO: 'bar' })
  })

  it('does not pollute process.env', () => {
    writeTmpEnv('COMPANION_SECRET_TEST_KEY=shouldnotleak\n')
    readEnvFile(tmpEnvPath)
    expect(process.env['COMPANION_SECRET_TEST_KEY']).toBeUndefined()
  })
})
