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

## Integration Points

| Skill / Component | Integration |
|-------------------|-------------|
| `skill-loader` (internal) | Passes active locale to i18n resolver when reading skill descriptions for display |
| `config-profiles/SKILL.md` | Profile YAML may include `locale` — profile activation writes it to config.yaml |
| `preferences/SKILL.md` | User preferences can set `locale`; preferences skill writes to config.yaml on change |
| `output-format/SKILL.md` | Output format skill reads locale to set date/number formatting conventions alongside message locale |
| `dashboard/SKILL.md` | Dashboard status strings use i18n message resolution for locale-aware display |
