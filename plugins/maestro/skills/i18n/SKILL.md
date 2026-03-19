---
name: i18n
description: "Multi-language support for skill descriptions and user-facing output messages. Supports English (default), Portuguese PT-BR, and Spanish ES. Locale selected via config.yaml or $LANG env var, with English fallback."
---

# i18n

Adds locale-aware output to Maestro. Skill descriptions and user-facing messages can carry translations inline. The i18n skill resolves the active locale and picks the right variant — or falls back to English when a translation is missing.

**Scope:** Descriptions and output messages only. Skill logic, acceptance criteria, and internal state fields stay in English regardless of locale. This is not a full translation layer — it is a targeted localization of what users read.

## Supported Locales

| Code | Language | Status |
|------|----------|--------|
| `en` | English | Default — always available |
| `pt-br` | Portuguese (Brazil) | Supported |
| `es` | Spanish | Supported |

Additional locales may be added by extending the YAML variant blocks. The fallback rule (English if locale missing) applies to all locales, including future ones.

## Locale Detection

Resolve the active locale in this order. First match wins.

```
1. .maestro/config.yaml  →  locale: pt-br
2. $LANG env var         →  pt_BR.UTF-8  →  normalize to "pt-br"
3. Default               →  en
```

### Normalizing $LANG

Strip encoding suffix and map to the canonical code:

| $LANG value | Resolved code |
|-------------|---------------|
| `en_US.UTF-8` | `en` |
| `en_GB.UTF-8` | `en` |
| `pt_BR.UTF-8` | `pt-br` |
| `pt_PT.UTF-8` | `pt-br` (closest supported) |
| `es_ES.UTF-8` | `es` |
| `es_MX.UTF-8` | `es` |
| Anything else | `en` (fallback) |

## Skill Description Localization

A skill's `description` field in its frontmatter can be a scalar (English only) or a locale map:

```yaml
# Scalar — English only, works without i18n skill
description: "Build features autonomously"

# Locale map — i18n skill resolves the correct variant
description:
  en: "Build features autonomously"
  pt-br: "Construa funcionalidades autonomamente"
  es: "Construye funcionalidades autonomamente"
```

When the i18n skill reads a description, it:
1. Checks whether the value is a string or a map.
2. If a string — return it as-is (no locale lookup needed).
3. If a map — look up the active locale key.
4. If the key is missing — fall back to `en`.

## Output Message Localization

Skills that emit user-facing messages can define a `messages` block in their frontmatter:

```yaml
messages:
  session_start:
    en: "Session started. Dispatching first story."
    pt-br: "Sessão iniciada. Despachando primeira história."
    es: "Sesión iniciada. Despachando la primera historia."
  skill_changed:
    en: "Skill {name} changed since session start."
    pt-br: "A skill {name} foi alterada desde o início da sessão."
    es: "La skill {name} cambió desde el inicio de la sesión."
```

Template variables use `{placeholder}` syntax. The i18n skill substitutes values before output.

### Resolving a Message

```
resolve_message(key, locale, variables):
  1. Look up messages[key]
  2. If not found → return key as-is (degrade gracefully, never crash)
  3. Look up messages[key][locale]
  4. If not found → look up messages[key]["en"]
  5. If still not found → return key as-is
  6. Substitute {placeholder} values
  7. Return resolved string
```

## Config Integration

Add to `.maestro/config.yaml`:

```yaml
locale: pt-br    # en | pt-br | es
```

If the `locale` key is absent, i18n falls back to `$LANG` detection, then English.

## Fallback Rules

The fallback chain always terminates at English. No message should ever be silently swallowed or cause an error due to a missing translation.

| Situation | Behavior |
|-----------|----------|
| Locale key present in map | Use it |
| Locale key missing | Use `en` variant |
| `en` variant also missing | Use the raw key as-is |
| `description` is a plain string | Use it directly, no lookup |
| `$LANG` not set, no config locale | Default to `en` |

## Partial Translation Policy

Skills do not need to be fully translated to use locale maps. A skill with only `en` and `pt-br` entries still works correctly for `es` users — they get English output. Adding translations is additive; no existing behavior changes when a new locale entry is added.

## Adding a New Locale

To add a new locale (e.g., French `fr`):

1. Add `fr` entries to any `description` or `messages` blocks you want translated.
2. Update the `$LANG` normalization table in this skill to map French `$LANG` values to `fr`.
3. Add `fr` to the Supported Locales table above.
4. Test with `locale: fr` in config.yaml.

No code changes required — the resolver is locale-agnostic.

## End-to-End Example

This trace shows the full path from skill definition to rendered output.

**Step 1 — Skill defines a locale map in frontmatter:**

```yaml
---
name: checkpoint
description:
  en: "Save a milestone checkpoint to git"
  pt-br: "Salvar um checkpoint de milestone no git"
  es: "Guardar un checkpoint de milestone en git"
messages:
  checkpoint_saved:
    en: "Checkpoint {tag} saved at {time}."
    pt-br: "Checkpoint {tag} salvo às {time}."
    es: "Checkpoint {tag} guardado a las {time}."
  checkpoint_failed:
    en: "Checkpoint failed: {reason}"
    pt-br: "Falha no checkpoint: {reason}"
    es: "Error en el checkpoint: {reason}"
---
```

**Step 2 — Config sets locale:**

`.maestro/config.yaml`:
```yaml
locale: pt-br
```

**Step 3 — skill-loader reads the description:**

```
skill-loader calls: i18n.resolve_description(skill.description, active_locale="pt-br")
  → description is a map
  → look up "pt-br" key
  → found: "Salvar um checkpoint de milestone no git"
  → return that string
```

**Step 4 — Skill emits a message at runtime:**

```
checkpoint skill calls: i18n.resolve_message("checkpoint_saved", "pt-br", {tag: "cp/s1/m2", time: "14:32"})
  → messages["checkpoint_saved"] found
  → messages["checkpoint_saved"]["pt-br"] = "Checkpoint {tag} salvo às {time}."
  → substitute: tag="cp/s1/m2", time="14:32"
  → return "Checkpoint cp/s1/m2 salvo às 14:32."
```

**Step 5 — Output rendered to user:**

```
Checkpoint cp/s1/m2 salvo às 14:32.
```

## $LANG Normalization Table

Strip everything from the first `.` or `@` onward, then map the language-region code to a canonical locale. If no match is found, fall back to `en`.

| $LANG value | Stripped code | Resolved locale | Notes |
|-------------|--------------|-----------------|-------|
| `en_US.UTF-8` | `en_US` | `en` | US English |
| `en_GB.UTF-8` | `en_GB` | `en` | British English |
| `en_AU.UTF-8` | `en_AU` | `en` | Australian English |
| `pt_BR.UTF-8` | `pt_BR` | `pt-br` | Brazilian Portuguese |
| `pt_PT.UTF-8` | `pt_PT` | `pt-br` | European Portuguese — closest supported locale |
| `es_ES.UTF-8` | `es_ES` | `es` | Castilian Spanish |
| `es_MX.UTF-8` | `es_MX` | `es` | Mexican Spanish |
| `es_AR.UTF-8` | `es_AR` | `es` | Argentine Spanish |
| `es_419` | `es_419` | `es` | Latin American Spanish |
| `fr_FR.UTF-8` | `fr_FR` | `en` | French — not supported, falls back to English |
| `de_DE.UTF-8` | `de_DE` | `en` | German — not supported, falls back to English |
| `ja_JP.UTF-8` | `ja_JP` | `en` | Japanese — not supported, falls back to English |
| `zh_CN.UTF-8` | `zh_CN` | `en` | Simplified Chinese — not supported |
| `C` | `C` | `en` | POSIX locale — treat as English |
| `POSIX` | `POSIX` | `en` | Same as C |
| (empty or unset) | — | `en` | No env var, no config → default |

**Algorithm:**

```
function normalize_lang(lang_value):
  if lang_value is empty or null:
    return "en"
  stripped = lang_value.split(".")[0].split("@")[0]   # remove .UTF-8, @euro, etc.
  normalized = stripped.replace("_", "-").lower()      # pt_BR → pt-br
  if normalized starts with "en":   return "en"
  if normalized starts with "pt":   return "pt-br"
  if normalized starts with "es":   return "es"
  return "en"   # fallback for all unsupported languages
```

## Error Handling for Malformed Message Blocks

The resolver must never crash. The following table lists failure modes and their required behavior.

| Failure mode | Behavior | Log? |
|-------------|----------|------|
| `messages` key absent from frontmatter | Return the raw key string as-is | No |
| Message key exists but has no locale entries at all (empty map `{}`) | Return raw key string | Yes — warn: "message key '{key}' has no translations" |
| Active locale missing, `en` also missing | Return raw key string | Yes — warn: "message key '{key}' has no 'en' fallback" |
| `{placeholder}` in template has no matching variable | Leave `{placeholder}` in output (do not remove it) | Yes — warn: "unresolved placeholder '{placeholder}' in message '{key}'" |
| Extra variables provided that have no `{placeholder}` | Silently ignore extra variables | No |
| `description` is `null` | Return empty string `""` | Yes — warn: "skill '{name}' has null description" |
| `description` map has no `en` key | Return first available key's value alphabetically | Yes — warn: "skill '{name}' has no 'en' description fallback" |

**Example — missing placeholder variable:**

Template: `"Checkpoint {tag} saved at {time}."`
Call: `resolve_message("checkpoint_saved", "en", {tag: "cp/s1"})`  — `time` is missing.
Output: `"Checkpoint cp/s1 saved at {time}."` — `{time}` remains in the string.
Log: `[i18n] warn: unresolved placeholder '{time}' in message 'checkpoint_saved'`

## Translation Maintenance Workflow

How to add PT-BR translations to an existing skill that only has English:

**Before:**
```yaml
messages:
  session_start:
    en: "Session started. Dispatching first story."
  skill_changed:
    en: "Skill {name} changed since session start."
```

**Step 1** — Open the skill's `SKILL.md`.

**Step 2** — For each message key, add the `pt-br` entry immediately after `en`:
```yaml
messages:
  session_start:
    en: "Session started. Dispatching first story."
    pt-br: "Sessão iniciada. Despachando primeira história."
  skill_changed:
    en: "Skill {name} changed since session start."
    pt-br: "A skill {name} foi alterada desde o início da sessão."
```

**Step 3** — Ensure every `{placeholder}` in the English template appears verbatim in the PT-BR template. Placeholder names are language-agnostic identifiers — do not translate them.

**Step 4** — If the skill uses a locale map for `description`, add the `pt-br` entry there too.

**Step 5** — Run validation (see below) to confirm no keys are missing and all placeholders match.

**Step 6** — Test locally: set `locale: pt-br` in `.maestro/config.yaml`, invoke the skill, and verify PT-BR output appears.

No code changes, config changes, or dependency installs are required. Adding a locale is purely additive YAML editing.

## Validation Rules

A valid i18n block must satisfy all of the following. Run these checks when a skill is loaded or when the `i18n validate` command is invoked.

**Rule 1 — Key parity:** Every message key that has more than one locale must have the same set of keys across all present locales.

```
BAD:
  greeting:
    en: "Hello"
    pt-br: "Olá"
  farewell:
    en: "Goodbye"
    # pt-br missing — pt-br users of 'farewell' fall back silently to English, which is OK
    # This is NOT a validation error — partial translation is allowed (see Partial Translation Policy)
```

Validation only flags when a locale key appears in some messages but is entirely absent from others with no `en` fallback — which cannot happen given the fallback chain. The parity check is informational only, not a hard failure.

**Rule 2 — Placeholder parity:** For any given message key, the set of `{placeholder}` tokens in each locale's string must match the set in the `en` string exactly.

```
BAD:
  checkpoint_saved:
    en:    "Checkpoint {tag} saved at {time}."
    pt-br: "Checkpoint {tag} salvo."          ← missing {time}

GOOD:
  checkpoint_saved:
    en:    "Checkpoint {tag} saved at {time}."
    pt-br: "Checkpoint {tag} salvo às {time}."
```

Mismatch causes the warning described in Error Handling above and should be surfaced as a validation error.

**Rule 3 — No empty strings:** A locale entry must not be an empty string `""`. An empty string is treated the same as a missing key (falls back to `en`), but its presence is a maintenance signal that a translation was started and not finished.

**Rule 4 — `en` always present:** Every message key must have an `en` entry. The `en` locale is the fallback anchor — a key with no `en` entry breaks the entire fallback chain.

## Where Translations Live

Choose the storage location based on skill size:

**Inline in `SKILL.md` frontmatter** — for skills with fewer than 10 message keys:

```yaml
---
name: checkpoint
messages:
  checkpoint_saved:
    en: "Checkpoint {tag} saved."
    pt-br: "Checkpoint {tag} salvo."
---
```

**Separate locale files** — for skills with 10+ message keys or when translations are being maintained by a different contributor than the skill logic:

```
skills/
  my-skill/
    SKILL.md          ← skill logic, no inline messages block
    locales/
      en.yaml
      pt-br.yaml
      es.yaml
```

`locales/en.yaml`:
```yaml
session_start: "Session started. Dispatching first story."
skill_changed: "Skill {name} changed since session start."
milestone_complete: "Milestone {name} complete. {stories} stories shipped."
# ... more keys
```

`locales/pt-br.yaml`:
```yaml
session_start: "Sessão iniciada. Despachando primeira história."
skill_changed: "A skill {name} foi alterada desde o início da sessão."
milestone_complete: "Milestone {name} concluída. {stories} histórias entregues."
```

When locale files exist, the i18n resolver reads from them instead of the frontmatter `messages` block. The resolver checks for `locales/` first; if present, frontmatter `messages` is ignored.

**Decision rule:** Start inline. Move to `locales/` files when the frontmatter becomes hard to read (more than ~20 lines of messages) or when a translator contributor needs to edit translations without touching skill logic.

## Integration Points

| Skill / Component | Integration |
|-------------------|-------------|
| `skill-loader` (internal) | Passes active locale to i18n resolver when reading skill descriptions for display |
| `config-profiles/SKILL.md` | Profile YAML may include `locale` — profile activation writes it to config.yaml |
| `preferences/SKILL.md` | User preferences can set `locale`; preferences skill writes to config.yaml on change |
| `output-format/SKILL.md` | Output format skill reads locale to set date/number formatting conventions alongside message locale |
| `dashboard/SKILL.md` | Dashboard status strings use i18n message resolution for locale-aware display |
