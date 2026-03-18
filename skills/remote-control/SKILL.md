---
name: remote-control
description: "Control Maestro from a phone or external service via Telegram, Discord, or HTTP using the Agent SDK. Inspired by ClaudeClaw's Telegram bot pattern and Claude Code's native /remote-control feature."
---

# Remote Control / Bot Integration

Run Maestro from your phone or any external service by routing messages through a bot process that invokes the Agent SDK.

## Architecture

```
Phone (Telegram / Discord / SMS)
    |
    v
Bot process (Node.js, always-on on your machine)
    |
    v
Agent SDK  query()  →  spawns Claude Code
    |
    v
Maestro skills execute (dev-loop, ship, board, …)
    |
    v
Result formatted  →  sent back to phone
```

The bot process is a long-running daemon (launchd / systemd) that bridges inbound messages to `query()` calls and routes results back to the originating channel.

## Platform Patterns

### Telegram (grammY)

```ts
import { Bot } from "grammy";
import { query } from "@anthropic-ai/claude-code";

const bot = new Bot(process.env.TELEGRAM_TOKEN!);
bot.on("message:text", async (ctx) => {
  if (!ALLOWED_IDS.includes(ctx.from.id)) return;
  const { id } = await getOrCreateSession(ctx.chat.id);
  const msg = await ctx.reply("<i>Running…</i>", { parse_mode: "HTML" });
  let result = "";
  for await (const chunk of query({ prompt: ctx.message.text,
      options: { resume: id, cwd: PROJECT_DIR } }))
    if (chunk.type === "result") result = chunk.result;
  await ctx.api.editMessageText(ctx.chat.id, msg.message_id,
    `<pre>${escape(result)}</pre>`, { parse_mode: "HTML" });
});
bot.start(); // long-polling; call bot.handleUpdate() for webhooks
```

Use HTML formatting (`<b>`, `<pre>`) for readable output. Pair with `bot.handleUpdate()` for webhook mode.

### Discord (discord.js)

```ts
import { Client, GatewayIntentBits } from "discord.js";
import { query } from "@anthropic-ai/claude-code";

const client = new Client({ intents: [GatewayIntentBits.MessageContent] });
client.on("messageCreate", async (msg) => {
  if (!ALLOWED_IDS.includes(msg.author.id) || !msg.content.startsWith("!m ")) return;
  const { id } = await getOrCreateSession(msg.channelId);
  let result = "";
  for await (const chunk of query({ prompt: msg.content.slice(3),
      options: { resume: id, cwd: PROJECT_DIR } }))
    if (chunk.type === "result") result = chunk.result;
  for (let i = 0; i < result.length; i += 1900) // Discord 2000-char cap
    await msg.reply("```\n" + result.slice(i, i + 1900) + "\n```");
});
client.login(process.env.DISCORD_TOKEN);
```

Prefer slash commands (`/maestro <prompt>`) over message-content prefix for better Discord UX.

### Claude Code Native (/remote-control)

Claude Code has a built-in remote-control mode — no extra bot process needed:

```bash
claude --remote-control --port 9000          # starts HTTP listener

curl -X POST http://192.168.1.10:9000/message \
  -H "Content-Type: application/json" \
  -d '{"message": "maestro status"}'
```

Pair with Tailscale for secure remote access without opening a public port.

### HTTP API (Express webhook trigger)

```ts
import express from "express";
import { query } from "@anthropic-ai/claude-code";
const app = express();
app.use(express.json());
app.post("/maestro", async (req, res) => {
  if (req.headers["x-api-key"] !== process.env.BOT_SECRET)
    return res.status(401).json({ error: "Unauthorized" });
  const { id } = await getOrCreateSession(req.body.chat_id ?? "default");
  let result = "";
  for await (const chunk of query({ prompt: req.body.prompt,
      options: { resume: id, cwd: PROJECT_DIR } }))
    if (chunk.type === "result") result = chunk.result;
  res.json({ result });
});
app.listen(3100);
```

Use for CI/CD webhooks, n8n automations, or any system that can send HTTP requests.

## Command Mapping

| Phone Command | Maestro Action |
|--------------|----------------|
| "Build auth system" | `/maestro "Add auth"` |
| "Status" | `/maestro status` |
| "Show board" | `/maestro board` |
| "Plan feature X" | `/maestro plan "X"` |
| "Deploy" | `/maestro ship` |
| "Health check" | `scripts/health-dashboard.sh --compact` |
| "New chat" | clear session → `/newchat` |
| "Pause" | `/maestro status pause` |

## Session Management

Each chat ID / channel ID gets its own Claude Code session in SQLite (`sessions(chat_id TEXT PK, session_id TEXT, last_seen INTEGER)`):

```ts
import Database from "better-sqlite3";
const db = new Database(".maestro/bot-sessions.db");
async function getOrCreateSession(chatId: string) {
  const row = db.prepare("SELECT session_id FROM sessions WHERE chat_id = ?")
    .get(chatId) as { session_id: string } | undefined;
  if (row) return { id: row.session_id };
  const id = crypto.randomUUID();
  db.prepare("INSERT INTO sessions (chat_id, session_id) VALUES (?, ?)").run(chatId, id);
  return { id };
}
```

- **Resume**: pass `options.resume = id` from the session to every `query()` call.
- **New session**: `/newchat` deletes the row; next message starts fresh.
- **Expiry**: evict rows where `last_seen` is older than 7 days.

## Notification Bridge

Inspect query results for Maestro event markers and push alerts to the phone:

```ts
function notifyOnEvents(chatId: string, result: string) {
  if (result.includes("[CHECKPOINT]"))   sendToPhone(chatId, "Story complete.");
  if (result.includes("QA REJECTED"))   sendToPhone(chatId, "QA rejected — retrying.");
  if (result.includes("Feature complete")) sendToPhone(chatId, "Feature done. Ready to ship.");
}
```

For async alerts (no active session), use the notify skill providers from a file-watcher on `.maestro/status.md`.

## Security

- **Allowlist**: check `ALLOWED_IDS` before processing any message.
- **bypassPermissions**: only in trusted local environment — never on shared servers.
- **Rate limiting**: 1 query / 30 s per chat to prevent abuse.
- **Lock file**: write `/tmp/maestro-bot.lock` at startup; exit if it exists — prevents duplicates.
- **API secret**: guard the HTTP endpoint with a `BOT_SECRET` header.
- **Redact output**: strip env var values before echoing results to chat.

## Background Service

Run as a daemon so it survives terminal closes. On macOS use a launchd plist (`~/Library/LaunchAgents/com.maestro.bot.plist`) with `RunAtLoad` and `KeepAlive` keys pointing at `node /path/to/bot/index.js`. On Linux, a systemd unit with `Restart=always` works equivalently.

## ClaudeClaw Reference

Production-grade implementation documented in `claudeclaw.md`:

- ~2,800 lines TypeScript, 14 source files
- SQLite session + memory tables, Groq STT, ElevenLabs TTS
- launchd / systemd service, full webhook and long-polling support
