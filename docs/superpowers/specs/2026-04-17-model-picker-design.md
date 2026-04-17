# Model Picker — Design Spec

**Date:** 2026-04-17

## Overview

Add a favorites-based model picker so the user can save OpenRouter model IDs and switch between them without copy-pasting from the website. Accessed via `<leader>ac`, managed via `:AddModel`.

## Data Layer

`ai_config.json` gains a `favorites` array alongside the existing `model` and `provider` fields:

```json
{
  "model": "anthropic/claude-sonnet-4.6",
  "provider": null,
  "favorites": ["anthropic/claude-sonnet-4.6", "openai/gpt-4o"]
}
```

- `load_ai_config` already decodes the full JSON object — no structural changes needed
- `M.config` default in `ai.lua` gains `favorites = {}` as fallback when the key is absent
- `save_ai_config` already encodes the full `M.config` table — favorites persist automatically

## New Command: `:AddModel <id>`

Defined in `ai.lua`. Appends the model ID to `M.config.favorites` (deduped — silently skips if already present), then calls `save_ai_config()`. Prints confirmation.

## New Module: `lua/models.lua`

Owns the picker UI. Exports one function: `M.open_picker()`.

**Panel content:**
```
 Model Picker — <Enter> to select
 ──────────────────────────────────────
   anthropic/claude-sonnet-4.6
   openai/gpt-4o
   qwen/qwen3-coder
```

Opens via `require("panel").open(lines, { wrap = false })` — same right-side split used by all other AI features.

**Keymaps (buffer-local):**
- `j` / `k` — standard vim motion; `cursorline` highlight follows cursor
- `<Enter>` — reads the model ID from the cursor line, sets `require("ai").config.model`, calls `save_ai_config()` via `require("ai")`, closes panel, prints `"AI model: <id>"`
- `q` / `<Esc>` — close without change (already wired by `panel.lua`)

**Empty state:** if `favorites` is empty, shows `"  No saved models. Use :AddModel <id> to add one."` — matches history.lua empty-state pattern.

**Cursor positioning:** after opening, cursor is placed on the line matching the currently active model (if present in favorites), otherwise line 1 of the list.

## Wiring in `ai.lua`

1. `load_ai_config` default return gains `favorites = {}`
2. `:AddModel` command added after `:Aiconfig`
3. `<leader>ac` keymap added alongside other `<leader>a*` maps

## Files Changed

| File | Change |
|------|--------|
| `lua/ai.lua` | Default config, `:AddModel` command, `<leader>ac` keymap |
| `lua/models.lua` | New file — picker UI |

`panel.lua`, `history.lua`, `init.lua` — no changes.
