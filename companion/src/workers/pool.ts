import { query } from '@anthropic-ai/claude-agent-sdk'
import type { Options, SDKResultMessage } from '@anthropic-ai/claude-agent-sdk'
import { config } from '../config.js'
import { logger } from '../logger.js'
import { writeFileSync, mkdirSync, unlinkSync } from 'node:fs'
import { resolve } from 'node:path'

export interface Worker {
  id: string
  prompt: string
  status: 'running' | 'completed' | 'failed'
  startedAt: Date
  costUsd?: number
  result?: string
}

const activeWorkers = new Map<string, Worker>()
const MAX_WORKER_HISTORY = 100

function cleanupWorkerHistory(): void {
  if (activeWorkers.size <= MAX_WORKER_HISTORY) return
  const completed = [...activeWorkers.entries()]
    .filter(([, w]) => w.status !== 'running')
    .sort((a, b) => a[1].startedAt.getTime() - b[1].startedAt.getTime())
  const toRemove = completed.slice(0, completed.length - MAX_WORKER_HISTORY / 2)
  for (const [id] of toRemove) activeWorkers.delete(id)
}

function generateId(): string {
  return `worker-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`
}

function registerInstance(workerId: string, prompt: string): void {
  const dir = resolve(config.projectRoot, '.maestro', 'instances')
  mkdirSync(dir, { recursive: true })
  writeFileSync(resolve(dir, `${workerId}.json`), JSON.stringify({
    session_id: workerId,
    pid: process.pid,
    started_at: new Date().toISOString(),
    last_heartbeat: new Date().toISOString(),
    feature: prompt.slice(0, 100),
    phase: 'implementing',
  }, null, 2))
}

function unregisterInstance(workerId: string): void {
  try { unlinkSync(resolve(config.projectRoot, '.maestro', 'instances', `${workerId}.json`)) } catch { /* ok */ }
}

export async function spawnWorker(
  prompt: string,
  onProgress?: (workerId: string, status: string) => void,
): Promise<Worker> {
  const workerId = generateId()
  const worker: Worker = { id: workerId, prompt, status: 'running', startedAt: new Date() }
  activeWorkers.set(workerId, worker)
  registerInstance(workerId, prompt)
  logger.info({ workerId }, 'Worker spawned')
  onProgress?.(workerId, 'started')

  try {
    const options: Options = {
      cwd: config.projectRoot,
      permissionMode: 'bypassPermissions',
      allowDangerouslySkipPermissions: true,
      settingSources: ['project', 'user'],
      model: config.buildModel,
      maxTurns: 50,
      maxBudgetUsd: 5.0,
    }
    for await (const event of query({ prompt, options })) {
      if (event.type === 'result') {
        const r = event as SDKResultMessage
        worker.costUsd = r.total_cost_usd
        if (r.subtype === 'success') {
          worker.result = r.result
          worker.status = 'completed'
        } else {
          worker.status = 'failed'
        }
      }
    }
    onProgress?.(workerId, worker.status)
  } catch (err) {
    logger.error({ err, workerId }, 'Worker failed')
    worker.status = 'failed'
    onProgress?.(workerId, 'failed')
  } finally {
    unregisterInstance(workerId)
  }
  logger.info({ workerId, status: worker.status, costUsd: worker.costUsd }, 'Worker finished')
  cleanupWorkerHistory()
  return worker
}

export async function spawnParallelWorkers(
  prompts: string[],
  maxConcurrent?: number,
  onProgress?: (workerId: string, status: string) => void,
): Promise<Worker[]> {
  const max = maxConcurrent ?? config.maxWorkers
  const results: Worker[] = []
  for (let i = 0; i < prompts.length; i += max) {
    const batch = prompts.slice(i, i + max)
    const batchResults = await Promise.all(batch.map(p => spawnWorker(p, onProgress)))
    results.push(...batchResults)
  }
  return results
}

export function getActiveWorkers(): Worker[] {
  return Array.from(activeWorkers.values()).filter(w => w.status === 'running')
}

export function getWorkerStats(): { running: number; completed: number; failed: number; totalCost: number } {
  let running = 0, completed = 0, failed = 0, totalCost = 0
  for (const w of activeWorkers.values()) {
    if (w.status === 'running') running++
    else if (w.status === 'completed') completed++
    else failed++
    totalCost += w.costUsd ?? 0
  }
  return { running, completed, failed, totalCost }
}
