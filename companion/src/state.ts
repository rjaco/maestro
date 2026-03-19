import { readFileSync, existsSync } from 'node:fs'
import { resolve } from 'node:path'
import { config } from './config.js'

export interface MaestroState {
  active: boolean
  feature: string
  phase: string
  layer: string
  opusMode: string
  currentMilestone: number
  totalMilestones: number
  currentStory: number
  totalStories: number
  tokenSpend: number
  consecutiveFailures: number
}

function parseYamlFrontmatter(content: string): Record<string, string> {
  const match = content.match(/^---\n([\s\S]*?)\n---/)
  if (!match) return {}
  const result: Record<string, string> = {}
  for (const line of match[1].split('\n')) {
    const colonIdx = line.indexOf(':')
    if (colonIdx === -1) continue
    const key = line.slice(0, colonIdx).trim()
    let value = line.slice(colonIdx + 1).trim()
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1)
    }
    result[key] = value
  }
  return result
}

export function readState(): MaestroState | null {
  const statePath = resolve(config.projectRoot, '.maestro', 'state.local.md')
  if (!existsSync(statePath)) return null
  const content = readFileSync(statePath, 'utf-8')
  const yaml = parseYamlFrontmatter(content)
  return {
    active: yaml.active === 'true',
    feature: yaml.feature ?? '',
    phase: yaml.phase ?? '',
    layer: yaml.layer ?? '',
    opusMode: yaml.opus_mode ?? '',
    currentMilestone: parseInt(yaml.current_milestone ?? '0', 10) || 0,
    totalMilestones: parseInt(yaml.total_milestones ?? '0', 10) || 0,
    currentStory: parseInt(yaml.current_story ?? '0', 10) || 0,
    totalStories: parseInt(yaml.total_stories ?? '0', 10) || 0,
    tokenSpend: parseInt(yaml.token_spend ?? '0', 10) || 0,
    consecutiveFailures: parseInt(yaml.consecutive_failures ?? '0', 10) || 0,
  }
}

export function readHeartbeat(): { timestamp: string; age: number } | null {
  const hbPath = resolve(config.projectRoot, '.maestro', 'logs', 'heartbeat')
  if (!existsSync(hbPath)) return null
  const timestamp = readFileSync(hbPath, 'utf-8').trim()
  const age = Math.floor((Date.now() - new Date(timestamp).getTime()) / 1000)
  return { timestamp, age }
}

export function formatStatus(): string {
  const state = readState()
  if (!state) return 'No active Maestro session.'
  const heartbeat = readHeartbeat()
  const lines: string[] = []
  lines.push('📊 Maestro Status')
  lines.push(`Feature: ${state.feature}`)
  lines.push(`Phase: ${state.phase}`)
  lines.push(`Mode: ${state.opusMode || state.layer}`)
  lines.push(`Milestone: ${state.currentMilestone}/${state.totalMilestones}`)
  lines.push(`Story: ${state.currentStory}/${state.totalStories}`)
  if (heartbeat) {
    const ageStr = heartbeat.age < 60 ? `${heartbeat.age}s ago` :
                   heartbeat.age < 3600 ? `${Math.floor(heartbeat.age / 60)}m ago` :
                   `${Math.floor(heartbeat.age / 3600)}h ago`
    lines.push(`Heartbeat: ${ageStr}`)
  }
  if (state.tokenSpend > 0) lines.push(`Tokens: ~${state.tokenSpend}`)
  return lines.join('\n')
}
