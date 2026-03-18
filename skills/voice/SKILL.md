---
name: voice
description: "Voice command mapping for Claude Code's native /voice mode. Maps spoken commands to Maestro operations with TTS-optimized responses."
---

# Voice Integration

Maps Claude Code's native `/voice` mode to Maestro operations. When voice mode is active, spoken commands are transcribed and routed to the appropriate Maestro command.

## Voice Command Patterns

When the user speaks, Claude Code transcribes the audio. This skill helps Claude interpret voice input as Maestro commands:

| Voice Input (examples) | Maps To |
|------------------------|---------|
| "Build [feature]" / "Create [feature]" | `/maestro "[feature]"` |
| "What's the status?" / "How's it going?" | `/maestro status` |
| "Show the board" / "Show my stories" | `/maestro board` |
| "Plan [feature]" / "Let's plan [feature]" | `/maestro plan "[feature]"` |
| "Initialize" / "Set up Maestro" | `/maestro init` |
| "Help" / "What can you do?" | `/maestro help` |
| "Run diagnostics" / "Health check" | `/maestro doctor` |
| "Show settings" / "Show config" | `/maestro config` |
| "Change models" / "Update model" | `/maestro model` |
| "Show history" / "Past sessions" | `/maestro history` |
| "Search [topic]" / "Find in brain" | `/maestro brain search "[topic]"` |
| "Save a note" / "Remember this" | `/maestro brain save` |
| "Daily briefing" / "What's happening?" | `/maestro brain daily` |
| "Pause" / "Stop for now" | `/maestro status pause` |
| "Resume" / "Continue" | `/maestro status resume` |
| "Abort" / "Cancel" | `/maestro status abort` |
| "Send notification" / "Notify team" | `/maestro notify "[message]"` |
| "Show diagram" / "Visualize" | `/maestro viz` |
| "Start opus" / "Build product" | `/maestro opus "[vision]"` |

## TTS-Optimized Responses

When voice mode is active, Maestro should optimize its output for spoken delivery:

### Rules for voice output:
1. **Keep it short**: Max 3 sentences per response
2. **No tables**: Convert to spoken lists ("First, ... Second, ... Third, ...")
3. **No code blocks**: Describe what was done, not the code
4. **No box-drawing**: Plain conversational text
5. **Numbers spoken naturally**: "about three dollars" not "$3.12"
6. **Status as sentences**: "Story three of five is done. QA passed on first try." not a table

### Example voice responses:

**Status query:**
> "You're working on user authentication. Three of five stories are done. The current story is the frontend, and it's being implemented right now. Total cost so far is about two dollars."

**Story checkpoint:**
> "Story three is done. The frontend components are built and QA approved it on the first try. Want me to continue to the next story?"

**Feature complete:**
> "Feature complete. All five stories passed. Total cost was four dollars and twenty cents. Would you like me to create a pull request?"

## How to Activate

1. Start Claude Code normally
2. Press `/voice` to enter voice mode (push-to-talk)
3. Speak your command — Claude transcribes and Maestro routes it
4. Maestro responds in voice-optimized format

## Detection

When a message arrives as `[Voice transcribed]:` prefix (from Claude Code's voice mode), or when the conversation context indicates voice mode is active:

1. Parse the transcribed text for Maestro command patterns
2. Route to the appropriate command/skill
3. Format the response for TTS (short, conversational, no tables/boxes)
4. If the command requires interactive choices (AskUserQuestion), present options verbally: "Would you like to continue, review the changes, or abort?"

## Integration

### With Dev-Loop
At checkpoint phase, if voice mode is active:
- Use TTS-optimized response (short, no tables)
- Read the story summary aloud
- Ask "continue, review, or abort?" verbally

### With Status Command
When voice is active and user asks for status:
- Speak: "You are working on [feature]. [N] of [M] stories done. Current phase is [phase]."

### With Notifications
Voice can complement notifications:
- Audio chime for checkpoint (audio skill)
- Spoken summary for feature completion (voice skill)

## Configuration

```yaml
voice:
  enabled: auto  # auto-detect when /voice is active
  tts_optimization: true
  max_response_sentences: 3
```
