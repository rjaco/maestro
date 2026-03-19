---
name: telemetry
description: "Async structured telemetry for all Maestro hooks. Emits JSON lines to .maestro/logs/telemetry.jsonl without blocking hook execution. Consumed by dashboard, retrospective, and cost-routing skills."
---

# Telemetry

Every Maestro hook emits a structured telemetry entry as it completes. Telemetry is non-blocking — hooks append to the log file without waiting for fsync. The log feeds real-time stats (dashboard), performance analysis (retrospective), and latency data (cost-routing).

## Log Location

All entries append to `.maestro/logs/telemetry.jsonl`.

One JSON object per line (JSON Lines format). No trailing commas, no array wrapper.

## Entry Format

```json
{
  "timestamp": "2026-03-18T14:32:01.042Z",
  "event": "hook_name",
  "duration_ms": 84,
  "decision": "approve",
  "context": {}
}
```

### Field Definitions

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | ISO 8601 with ms | Wall-clock time at hook completion |
| `event` | string | Hook name (e.g., `PreToolUse`, `PostToolUse`, `Stop`, `SubagentStop`) |
| `duration_ms` | integer | Hook execution time in milliseconds |
| `decision` | `"approve"` \| `"block"` | Whether the hook approved or blocked the triggering action |
| `context` | object | Hook-specific metadata (see per-hook schema below) |

### Per-Hook Context Schema

Each hook populates `context` with its own relevant fields.

**PreToolUse**
```json
{
  "tool": "Bash",
  "agent_id": "implementer-a3f1",
  "story_id": "story-04",
  "block_reason": null
}
```

**PostToolUse**
```json
{
  "tool": "Bash",
  "agent_id": "implementer-a3f1",
  "exit_code": 0,
  "output_bytes": 412
}
```

**Stop / SubagentStop**
```json
{
  "agent_id": "implementer-a3f1",
  "story_id": "story-04",
  "status": "DONE",
  "total_turns": 18
}
```

**Notification**
```json
{
  "agent_id": "implementer-a3f1",
  "level": "info"
}
```

### Privacy Rules

Never include in `context`:
- File contents of any kind
- API keys, tokens, secrets, or credentials
- Full command strings that may embed user data
- User message text or prompt content
- Model response text

Log tool names, story IDs, agent IDs, exit codes, byte counts, and durations — not the data those tools operate on.

## Non-Blocking Write Protocol

Hooks write telemetry using a fire-and-forget append. The write must not block hook execution or delay the hook's `decision` being returned to the agent.

Pseudocode pattern:

```python
import json, os, threading, time

def emit_telemetry(event, duration_ms, decision, context):
    entry = json.dumps({
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S") + f".{int(time.time() * 1000) % 1000:03d}Z",
        "event": event,
        "duration_ms": duration_ms,
        "decision": decision,
        "context": context,
    })
    threading.Thread(
        target=_append,
        args=(".maestro/logs/telemetry.jsonl", entry),
        daemon=True,
    ).start()

def _append(path, line):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "a") as f:
        f.write(line + "\n")
        # No fsync — OS buffer flush is acceptable for telemetry
```

The hook completes and returns its decision before the file I/O resolves. If the write fails (disk full, permissions), the failure is silently swallowed — telemetry loss is preferable to blocking an agent.

## File Rotation

Rotate `telemetry.jsonl` when it reaches **10 MB**. Keep the last **5 rotations**.

Rotation naming convention:

```
.maestro/logs/telemetry.jsonl          ← current (active writes)
.maestro/logs/telemetry.1.jsonl        ← most recent rotation
.maestro/logs/telemetry.2.jsonl
.maestro/logs/telemetry.3.jsonl
.maestro/logs/telemetry.4.jsonl
.maestro/logs/telemetry.5.jsonl        ← oldest kept rotation (delete beyond this)
```

Rotation is triggered by the hook process before appending if the current file exceeds 10 MB:

```python
def _rotate_if_needed(path, max_bytes=10 * 1024 * 1024, keep=5):
    if not os.path.exists(path) or os.path.getsize(path) < max_bytes:
        return
    for i in range(keep, 0, -1):
        src = f"{path}.{i - 1}" if i > 1 else path
        dst = f"{path}.{i}"
        if os.path.exists(src):
            if i == keep and os.path.exists(dst):
                os.remove(dst)
            os.rename(src, dst)
```

Rotation is best-effort. If it fails, writes continue to the current file.

## Consumer Skills

| Consumer | What it reads | How it uses telemetry |
|----------|--------------|----------------------|
| **dashboard** | `telemetry.jsonl` (tail -f) | Real-time hook event stream; computes rolling approve/block rate and per-hook latency |
| **retrospective** | Full `telemetry.jsonl` after milestone | Aggregate hook performance; flags slow hooks (duration_ms p95 > 200ms) |
| **cost-routing** | Hook `duration_ms` per `agent_id` | Latency signal for routing decisions; penalizes hook overhead in scoring |

## Query Helpers

All queries run against `.maestro/logs/telemetry.jsonl` (and rotations if needed).

**How many block decisions today?**
```bash
grep '"decision":"block"' .maestro/logs/telemetry.jsonl \
  | grep "$(date -u +%Y-%m-%d)" \
  | wc -l
```

**Average hook latency (ms)?**
```bash
grep -o '"duration_ms":[0-9]*' .maestro/logs/telemetry.jsonl \
  | awk -F: '{sum+=$2; count++} END {printf "avg: %.1f ms\n", sum/count}'
```

**Block rate by hook type?**
```bash
python3 -c "
import json, sys
from collections import defaultdict
totals, blocks = defaultdict(int), defaultdict(int)
for line in open('.maestro/logs/telemetry.jsonl'):
    e = json.loads(line)
    totals[e['event']] += 1
    if e['decision'] == 'block':
        blocks[e['event']] += 1
for ev in sorted(totals):
    pct = 100 * blocks[ev] / totals[ev]
    print(f'{ev:30s}  {blocks[ev]}/{totals[ev]}  ({pct:.1f}% blocked)')
"
```

**Slowest hook events (top 10)?**
```bash
python3 -c "
import json
entries = [json.loads(l) for l in open('.maestro/logs/telemetry.jsonl')]
for e in sorted(entries, key=lambda x: x['duration_ms'], reverse=True)[:10]:
    print(f\"{e['duration_ms']:6d} ms  {e['event']:30s}  {e['timestamp']}\")
"
```

**Events for a specific story?**
```bash
python3 -c "
import json, sys
story = sys.argv[1]
for line in open('.maestro/logs/telemetry.jsonl'):
    e = json.loads(line)
    if e.get('context', {}).get('story_id') == story:
        print(line.rstrip())
" story-04
```

**Total blocks in last hour?**
```bash
python3 -c "
import json
from datetime import datetime, timezone, timedelta
cutoff = datetime.now(timezone.utc) - timedelta(hours=1)
count = sum(
    1 for line in open('.maestro/logs/telemetry.jsonl')
    if json.loads(line).get('decision') == 'block'
    and datetime.fromisoformat(json.loads(line)['timestamp'].replace('Z','+00:00')) > cutoff
)
print(f'Blocks in last hour: {count}')
"
```

## Integration Points

| Skill | Integration |
|-------|-------------|
| **hooks-integration** | Each hook defined in hooks-integration emits a telemetry entry on completion via `emit_telemetry()`. Telemetry is the last operation before the hook returns. |
| **dashboard** | Tails `telemetry.jsonl` for live hook event counts and latency percentiles. |
| **retrospective** | Reads the full log after milestone completion for aggregate performance metrics. |
| **cost-routing** | Reads `duration_ms` per agent to factor hook overhead into model routing decisions. |
| **audit-log** | Distinct from telemetry. Audit-log records agent decisions in human-readable markdown; telemetry records hook execution metrics in machine-readable JSONL. |
| **background-workers** | The `health-check` worker can run the block-rate query above as part of its periodic check and surface anomalies to `.maestro/notes.md`. |
