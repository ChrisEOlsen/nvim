# AI History Feature Design

**Date:** 2026-04-16  
**Status:** Approved

## Overview

Save every AI explain response (excluding AutoEdit) to a per-file JSON history store. Allow the user to browse past responses in the existing panel split via `<leader>ah`, navigating with arrow keys and a pagination indicator.

## Scope

**In scope:**
- Save output from `open_explain_window` calls: `:Explain` command and `<leader>ai` visual keymap
- `<leader>ah` keymap to open history panel for the current buffer
- Arrow key navigation between entries with pagination footer
- 50-entry cap per file (oldest dropped)

**Explicitly excluded:**
- AutoEdit responses (diff output, not prose)
- Autogen responses (code inserted into buffer, not explanation)

## Storage

- **Root directory:** `~/.config/nvim/.ai/`
- **One JSON file per source file.** Path derived by replacing every `/` in the absolute source path with `_`, appended with `.json`.
  - Example: `/Users/crispychris/projects/foo/main.c` → `.ai/_Users_crispychris_projects_foo_main.c.json`
- **File format:** JSON array, entries appended chronologically (oldest first, newest last):
  ```json
  [
    { "timestamp": "2026-04-16T14:32:00", "source": "/abs/path/to/file.c", "content": "..." }
  ]
  ```
- **Cap:** 50 entries per file. When exceeded, the oldest entry is dropped before appending the new one.
- **Rename behavior:** History is keyed to the absolute path at save time. If a file is renamed, old history remains under the original path. Acceptable tradeoff.

## Architecture

### New module: `lua/history.lua`

Owns all persistence logic. Public API:

```lua
history.save(bufnr, text)   -- derive path, append entry, enforce 50-entry cap
history.load(bufnr)          -- return array of entries (oldest first), or {} if none
```

Internal helpers:
- `derive_path(buf_path)` — maps absolute source path to `.ai/*.json` path
- `ensure_dir()` — creates `.ai/` if missing (once, on first save)

### Modified: `lua/ai.lua`

Two changes only:

1. After `open_explain_window(result)` in both the `<leader>ai` keymap and the `:Explain` command, call `require("history").save(bufnr, result)`.
2. Register `<leader>ah` normal-mode keymap that calls `history.open_panel(bufnr)`.

`history.open_panel` is a third public function on the history module (see below).

### Untouched: `lua/panel.lua`

No changes. History panel uses `panel.open()` exactly as explain output does.

## Panel UX

### Opening (`<leader>ah`)

- Captures the **current buffer** before switching focus (not the panel buffer).
- Calls `history.load(bufnr)` to get entries.
- If no entries: opens panel with single line `"  No AI history for this file."`.
- Otherwise: displays most recent entry (index 1, reverse of storage order).

### Panel content layout (per entry)

```
 AI History — /abs/path/to/file.c
 ─────────────────────────────────
 2026-04-16 14:32:00

 <entry content lines, left-padded with one space>

                                              [1 / 6]
```

- Title line: full absolute path of the source file.
- Separator line of `─` characters matching panel width.
- Timestamp line.
- Blank line then content (same left-padding as `open_explain_window`).
- Pagination footer: last line, right-aligned `[N / total]`.

### Navigation

- `<Left>` — go to older entry (index + 1 in reversed array). No-op at oldest.
- `<Right>` — go to newer entry (index - 1). No-op at most recent.
- `q` / `<Esc>` — close panel (inherited from `panel.lua` via buffer keymaps).
- Navigation re-populates the existing panel buffer in place; does not open a new split.

### `history.open_panel(bufnr)` implementation notes

- Stores current index in a module-level variable (reset to 1 on each open).
- Calls `panel.open(lines, { wrap = true })` on first open to get `buf`.
- On arrow press: clears buffer, re-populates with new entry lines, re-sets navigation keymaps on the same `buf`.
- Keymaps are buffer-local so they are wiped when the panel closes.

## File listing

| File | Action |
|------|--------|
| `lua/history.lua` | **Create** |
| `lua/ai.lua` | **Modify** — add `history.save()` calls + `<leader>ah` keymap |
| `lua/panel.lua` | No change |
| `init.lua` | No change |

## Error handling

- If `.ai/` directory cannot be created: `vim.notify` error, do not crash.
- If JSON file is corrupt on load: treat as empty history, log a warning.
- If buffer has no name (unnamed buffer): skip save silently.
