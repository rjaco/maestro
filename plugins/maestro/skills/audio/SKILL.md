---
name: audio
description: "Audio alerts when Maestro needs your attention. Terminal bell, macOS sounds, or Linux audio. Inspired by Peon Ping (100K+ users)."
---

# Audio Feedback

Play audio alerts when Maestro needs attention. Keeps you productive while Maestro builds -- you hear a chime when a checkpoint arrives, a success sound when the feature is done, or a warning when something goes wrong.

Inspired by Peon Ping (100K+ users): developers want to know when their autonomous tool needs them, without staring at the terminal.

## Event-Sound Mapping

| Event | Sound | How |
|-------|-------|-----|
| Checkpoint needs input | Chime | Terminal bell `\a` |
| Feature complete | Success | macOS: `afplay /System/Library/Sounds/Glass.aiff` |
| QA rejection | Warning | macOS: `afplay /System/Library/Sounds/Basso.aiff` |
| Self-heal failure | Alert | macOS: `afplay /System/Library/Sounds/Sosumi.aiff` |
| Error / PAUSE | Urgent | macOS: `afplay /System/Library/Sounds/Funk.aiff` |

## Cross-Platform Support

### Universal (works everywhere)

```bash
printf '\a'
```

The terminal bell. Works in every terminal emulator on every OS. Some terminals flash the taskbar instead of playing a sound (configurable in terminal settings).

### macOS

```bash
afplay /System/Library/Sounds/Glass.aiff
```

Uses `afplay` with built-in system sounds. No extra files needed. Available sounds:

| Sound File | Best For |
|------------|----------|
| `Glass.aiff` | Success / completion |
| `Basso.aiff` | Warning / QA rejection |
| `Sosumi.aiff` | Alert / self-heal failure |
| `Funk.aiff` | Urgent / error |
| `Ping.aiff` | Checkpoint / attention needed |
| `Hero.aiff` | Magnum Opus milestone complete |

### Linux

Try providers in order until one works:

```bash
# Option 1: PulseAudio
paplay /usr/share/sounds/freedesktop/stereo/complete.oga

# Option 2: ALSA
aplay /usr/share/sounds/freedesktop/stereo/complete.oga

# Option 3: mpv (lightweight player)
mpv --no-terminal /usr/share/sounds/freedesktop/stereo/complete.oga
```

Common freedesktop sound files:

| Sound File | Best For |
|------------|----------|
| `complete.oga` | Success / completion |
| `bell.oga` | Checkpoint / attention |
| `dialog-warning.oga` | Warning / QA rejection |
| `dialog-error.oga` | Error / failure |

### WSL (Windows Subsystem for Linux)

```bash
powershell.exe -c "[console]::beep(800,200)"
```

Frequency and duration are adjustable:

| Event | Frequency (Hz) | Duration (ms) | Pattern |
|-------|----------------|---------------|---------|
| Checkpoint | 800 | 200 | Single beep |
| Feature complete | 600, 800, 1000 | 150 each | Rising triple |
| QA rejection | 400 | 300 | Low single |
| Self-heal failure | 300, 300 | 200 each | Double low |
| Error / PAUSE | 200 | 500 | Long low |

## Configuration

In `.maestro/config.yaml`:

```yaml
audio:
  enabled: true
  provider: auto  # auto | terminal | macos | linux | wsl | none
  events:
    on_checkpoint: true
    on_complete: true
    on_error: true
    on_qa_rejection: false
```

### Provider Selection

| Provider | Value | When |
|----------|-------|------|
| Auto-detect | `auto` | Default. Detects OS and picks the best provider |
| Terminal bell | `terminal` | Use `printf '\a'` for everything. Simplest |
| macOS sounds | `macos` | Force macOS `afplay` provider |
| Linux sounds | `linux` | Force Linux `paplay`/`aplay`/`mpv` provider |
| WSL beeps | `wsl` | Force WSL `powershell.exe` provider |
| Disabled | `none` | No audio at all |

### Event Toggles

Each event can be individually enabled or disabled. Defaults:

| Event | Default | Why |
|-------|---------|-----|
| `on_checkpoint` | `true` | Most important -- user needs to respond |
| `on_complete` | `true` | Feature done, come celebrate |
| `on_error` | `true` | Something broke, user may need to intervene |
| `on_qa_rejection` | `false` | Usually auto-resolved by re-dispatch, not urgent |

## Play Function

The play function detects the OS, selects the provider, and plays the appropriate sound.

### Detection Logic

```
1. Read audio config from .maestro/config.yaml
2. If audio.enabled is false or provider is "none", return silently
3. If provider is "auto":
   a. Check if running in WSL (grep -qi microsoft /proc/version)
   b. Check if macOS (uname -s == Darwin)
   c. Check if Linux (uname -s == Linux)
   d. Fall back to terminal bell
4. Map the event name to the sound for the detected provider
5. Play the sound asynchronously (do not block Maestro execution)
```

### Async Playback

Always play sounds in the background so they do not block Maestro:

```bash
# macOS example (non-blocking)
afplay /System/Library/Sounds/Glass.aiff &

# Linux example (non-blocking)
paplay /usr/share/sounds/freedesktop/stereo/complete.oga &

# Terminal bell (already instant)
printf '\a'
```

### Error Handling

If the sound command fails (missing binary, missing file), fail silently. Audio is a nice-to-have, never a blocker. Log the failure to `.maestro/logs/` at debug level.

## Integration Points

The audio skill is called by other Maestro components at specific moments:

| Caller | Event | When |
|--------|-------|------|
| `dev-loop` | `on_checkpoint` | Phase 7 (CHECKPOINT) in checkpoint/careful mode |
| `maestro.md` | `on_complete` | Feature completion summary displayed |
| `dev-loop` | `on_qa_rejection` | Phase 5 (QA) returns REJECTED |
| `dev-loop` | `on_error` | Phase 4 (SELF-HEAL) exhausts all attempts |
| `dev-loop` | `on_error` | Any PAUSE event |
| `opus-loop` | `on_checkpoint` | Milestone checkpoint |
| `opus-loop` | `on_complete` | Magnum Opus fully complete |

## YOLO Mode Rule

**NEVER play audio during yolo mode.** In yolo mode, no user is watching the terminal. Playing sounds would be disruptive (the user may be in a meeting, wearing headphones with music, or AFK). The dev-loop should check the execution mode before calling the audio skill:

```
if mode != "yolo" and audio.enabled:
    play_sound(event)
```

The only exception: `on_error` when Maestro PAUSEs even in yolo mode (e.g., self-heal exhausted). If Maestro is paused and waiting for input, a sound is appropriate regardless of mode.
