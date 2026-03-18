---
name: voice
description: "Voice command mapping for Claude Code's native /voice mode. Maps spoken commands to Maestro operations with TTS-optimized responses."
---

# Voice Integration

Maps Claude Code's native `/voice` mode to Maestro operations. When voice mode is active, spoken commands are transcribed and routed to the appropriate Maestro command.

## Detection Protocol

A message is in voice mode when either of these conditions is true:

1. The message begins with the prefix `[Voice transcribed]:` — this is the literal prefix Claude Code prepends to transcribed audio.
2. The conversation context explicitly indicates that `/voice` mode was activated this session.

When voice mode is detected, apply TTS formatting to all responses immediately and for the remainder of the session. Do not revert to markdown formatting mid-session.

If neither condition is present, treat the message as a normal text interaction even if the content resembles a voice command. Do not assume voice mode.

## Complete Command Mapping

### Core Orchestration

| Voice Input (examples) | Maps To | Notes |
|------------------------|---------|-------|
| "Build [feature]" / "Create [feature]" / "Make [feature]" | `/maestro "[feature]"` | Extract the feature description verbatim |
| "Plan [feature]" / "Let's plan [feature]" / "Design [feature]" | `/maestro plan "[feature]"` | Planning pass only, no implementation |
| "Initialize" / "Set up Maestro" / "Get started" | `/maestro init` | First-time setup |
| "Help" / "What can you do?" / "Commands" | `/maestro help` | |

### Status and Progress

| Voice Input (examples) | Maps To | Notes |
|------------------------|---------|-------|
| "What's the status?" / "How's it going?" / "Give me an update" | `/maestro status` | Respond in voice format |
| "Show the board" / "Show my stories" / "What stories are there?" | `/maestro board` | Read board aloud as list |
| "What's next?" / "What story is next?" / "Next up?" | `/maestro status` | Extract next story from status |
| "Show progress" / "How far along are we?" | `/maestro status` | Summarize percentage complete |
| "Show history" / "Past sessions" / "What did we do before?" | `/maestro history` | |

### Flow Control

| Voice Input (examples) | Maps To | Notes |
|------------------------|---------|-------|
| "Pause" / "Stop for now" / "Hold on" | `/maestro status pause` | Confirm verbally: "Paused." |
| "Resume" / "Continue" / "Keep going" / "Go ahead" | `/maestro status resume` | Confirm verbally: "Resuming." |
| "Abort" / "Cancel" / "Stop everything" | `/maestro status abort` | Ask for confirmation before aborting |
| "Continue to next story" / "Move on" / "Next story" | Route to next story in queue | Only if at a checkpoint |

### Configuration and Diagnostics

| Voice Input (examples) | Maps To | Notes |
|------------------------|---------|-------|
| "Run diagnostics" / "Health check" / "Check the setup" | `/maestro doctor` | |
| "Show settings" / "Show config" / "What's configured?" | `/maestro config` | |
| "Change models" / "Update model" / "Switch model" | `/maestro model` | |

### Brain and Memory

| Voice Input (examples) | Maps To | Notes |
|------------------------|---------|-------|
| "Search [topic]" / "Find [topic]" / "Look up [topic]" | `/maestro brain search "[topic]"` | Extract topic from voice |
| "Save a note" / "Remember this" / "Take note" | `/maestro brain save` | Prompt for content if not spoken |
| "Daily briefing" / "What's happening today?" / "Morning update" | `/maestro brain daily` | |

### Notifications and Output

| Voice Input (examples) | Maps To | Notes |
|------------------------|---------|-------|
| "Send notification" / "Notify team" / "Alert [person]" | `/maestro notify "[message]"` | |
| "Show diagram" / "Visualize" / "Draw the architecture" | `/maestro viz` | Describe diagram verbally |
| "Start opus" / "Build the product" / "Magnum opus" | `/maestro magnum-opus "[vision]"` | Extract vision from voice |

## Confidence Handling

Voice transcription introduces errors that text input does not. Apply this protocol before routing any command.

### Confidence Levels

**High confidence** — the transcribed text maps cleanly to a known command or command pattern. Route immediately without asking for confirmation.

Example: "What's the status?" → clearly `/maestro status`. Route it.

**Medium confidence** — the transcribed text resembles a command but is ambiguous between two or more interpretations, or a key argument (like a feature name) is unclear.

Example: "Build the auth thing" → feature name is vague. Before routing, say: "I'll build the authentication feature. Is that right?" Wait for confirmation.

**Low confidence** — the transcribed text does not match any known command and could be garbled transcription or an unsupported request.

Example: "Maestro, flurble the widgets" → unrecognizable. Apply the fallback protocol below.

### Ambiguity Resolution

When a command is ambiguous, ask a single clarifying question. Keep it short and spoken-friendly. Do not present a list of options with numbers — present them as natural spoken alternatives.

- "Did you want to plan the feature, or start building it?"
- "Should I pause the current story, or abort the whole session?"
- "I heard 'build login' — did you mean the login page, or the login API?"

Wait for the user's response before routing. If the user's clarification is also unclear, state what you are doing and proceed with the most likely interpretation: "I'll assume you meant the login page. Starting now."

### Common Transcription Errors

Watch for these patterns and correct before routing:

| Likely heard | Likely meant |
|-------------|-------------|
| "maestro status resume" | "resume" |
| "build the [X] thing" | "build [X]" |
| "what story is" | "what's next" |
| "show me the bored" | "show me the board" |
| "pause it" / "stop it" | "pause" |
| "continue it" / "go" | "continue" |

## Fallback for Unrecognized Commands

When a voice command does not match any known pattern after applying confidence analysis:

1. Do not silently fail.
2. State what you heard: "I heard: [transcription]."
3. Offer the most likely Maestro commands for the situation: "I'm not sure what to do with that. You can say things like: build a feature, check status, pause, resume, or ask for help."
4. Wait for the user to try again.
5. If two consecutive inputs fail to match, ask the user to switch to text: "I'm having trouble understanding. Would you like to type your command instead?"

Never route a low-confidence match without surfacing it. A wrong action (especially `abort` or destructive operations) is worse than no action.

## TTS-Optimized Responses

When voice mode is active, all Maestro output must be reformatted for spoken delivery. Apply these rules to every response.

### Rules

1. **Short sentences** — maximum 20 words per sentence. Break long sentences into two.
2. **No markdown** — no asterisks, no headers, no horizontal rules.
3. **No tables** — replace with spoken lists: "First... Second... Third..."
4. **No code blocks** — describe what the code does, not the code itself.
5. **No box-drawing characters** — no `│`, `─`, `╔`, or similar.
6. **Numbers spoken naturally** — say "about four dollars" not "$3.98". Say "three of five" not "3/5".
7. **Status as sentences** — "Story three is done. QA passed on the first try." Not a table row.
8. **Avoid abbreviations** — say "pull request" not "PR". Say "quality assurance" or just "tests" not "QA".
9. **Confirm actions** — after routing a command, say what you did: "Pausing now." or "Starting the build."
10. **Three-sentence limit** — standard responses should be three sentences or fewer. Summaries may be up to five.

### Example Responses

**Status query:**
"You're working on user authentication. Three of five stories are done. The current story is the frontend, and it's being implemented right now. Total cost so far is about two dollars."

**Story checkpoint — asking to continue:**
"Story three is done. The frontend components are built and tests approved it. Want me to continue to the next story?"

**Feature complete:**
"Feature complete. All five stories passed. Total cost was about four dollars. Would you like me to create a pull request?"

**Ambiguous command:**
"Did you want to pause the current story, or abort the whole session?"

**Unrecognized command:**
"I heard: flurble the widgets. I'm not sure what to do with that. You can say things like: build a feature, check status, or pause."

**Abort confirmation:**
"Are you sure you want to abort? This will stop the current story. Say yes to confirm."

## Checkpoint Behavior in Voice Mode

When a story reaches a checkpoint and voice mode is active:

1. Play the audio chime if the audio skill is available.
2. Speak a short story summary: "[Story name] is done. [One-sentence description of what was built]."
3. Ask for direction verbally: "Should I continue to the next story, or do you want to review the changes first?"
4. Wait for a voice response and route it using the confidence protocol above.

Accepted responses at checkpoints: "continue", "yes", "go ahead", "next", "keep going" → proceed. "review", "show me", "wait" → show a brief verbal summary of the changes. "stop", "pause", "abort" → route to the appropriate flow control command.

## How to Activate

1. Start Claude Code normally.
2. Press `/voice` to enter voice mode (push-to-talk).
3. Speak your command — Claude transcribes and Maestro routes it.
4. Maestro responds in voice-optimized format.

## Integration

### With Dev-Loop
At checkpoint phase, if voice mode is active:
- Use TTS-optimized response (short, no tables).
- Read the story summary aloud.
- Ask "continue, review, or stop?" verbally.

### With Status Command
When voice is active and user asks for status:
- Say: "You are working on [feature]. [N] of [M] stories are done. Current phase is [phase]."

### With Notifications
Voice can complement notifications:
- Audio chime for checkpoint (audio skill).
- Spoken summary for feature completion (voice skill).

## Configuration

```yaml
voice:
  enabled: auto  # auto-detect when /voice is active
  tts_optimization: true
  max_response_sentences: 3
  confirm_destructive: true   # always confirm abort/cancel verbally
  fallback_to_text_after: 2   # suggest text input after 2 consecutive failures
```
