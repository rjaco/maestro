import pino from 'pino'
import { config } from './config.js'
import { mkdirSync } from 'node:fs'
import { dirname } from 'node:path'

mkdirSync(dirname(config.logPath), { recursive: true })

export const logger = pino({
  level: config.logLevel,
  transport: {
    targets: [
      {
        target: 'pino-pretty',
        options: { colorize: true, translateTime: 'SYS:HH:MM:ss' },
        level: config.logLevel,
      },
      {
        target: 'pino/file',
        options: { destination: config.logPath, mkdir: true },
        level: config.logLevel,
      },
    ],
  },
})
