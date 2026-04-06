# Right-Split Panel & Extended Keymap Reference

**Date:** 2026-04-06  
**Status:** Approved

---

## Overview

Replace all floating popup windows (AI explain output, `<leader>?` keymap reference) with a persistent right-side vertical split panel. Extend the keymap reference to include custom commands that have no keybinding.

---

## Goals

1. AI explain output and the keymap reference open as a true `:vsplit` on the right at 50% screen width, not as floating windows.
2. If the panel is already open, invoking either feature replaces the panel content in-place (no stacking of splits).
3. The `<leader>?` reference lists all custom commands, not just those with keybindings.

---

## Architecture

### New file: `lua/panel.lua`

Owns all panel lifecycle logic. Both `lua/ai.lua` and `init.lua` call `require("panel").open(...)`.

**Public API:**

```lua
require("panel").open(title, lines, opts)
-- title  : string  — shown as the window's header (e.g. " explain ")
-- lines  : table   — array of strings to display
-- opts   : table   — optional:
--   opts.wrap = true   enables word-wrap (used by AI explain)
```

**Internal behaviour:**

- Module-level `panel_win` tracks the last panel window ID.
- On each call:
  - If `panel_win` is valid (`nvim_win_is_valid`): create a fresh scratch buffer, swap it into `panel_win` via `nvim_win_set_buf`, delete the old buffer, resize to `math.floor(vim.o.columns / 2)`, focus the window.
  - Otherwise: `vim.cmd("botright vsplit")`, capture `nvim_get_current_win()` as the new `panel_win`, set width to `math.floor(vim.o.columns / 2)`.
- Set buffer options: `bufhidden = wipe`, `modifiable = false`, `buftype = nofile`.
- Set window options: `number = false`, `relativenumber = false`, `signcolumn = no`, `cursorline = true`, `wrap` per `opts.wrap`.
- Bind `q` and `<Esc>` on the buffer to `<cmd>close<CR>`.
- No floating border or title chrome — it is a plain split window.

---

### Changes to `lua/ai.lua`: `open_explain_window`

Remove the float sizing/positioning block (width, height, col, row calculations) and the `nvim_open_win` call. Replace with:

```lua
require("panel").open(" explain ", padded, { wrap = true })
```

The existing `padded` lines array and left-padding logic are kept unchanged.

---

### Changes to `init.lua`: `show_keymaps`

Remove the float sizing/positioning block (max_len, width, height, col, row, `nvim_open_win`) and associated window-option calls. Replace with:

```lua
require("panel").open(" keymaps ", lines)
```

The existing section/line-building logic is kept unchanged.

---

## Extended Keymap Reference

Commands without a keybinding use `[cmd]` as their mode tag in the reference table.

### New section: `C/C++ Scaffolding`

| Keys / Command | Mode  | Description |
|---|---|---|
| `:MainArgs`   | [cmd] | Insert main() with argc/argv |
| `:MainVoid`   | [cmd] | Insert main() with no args |
| `:AddProto`   | [cmd] | Add function prototype |
| `:CommentBox` | [cmd] | Insert decorated comment box |

### Additions to existing `AI` section

| Keys / Command | Mode  | Description |
|---|---|---|
| `:Aiconfig <model> [provider]` | [cmd] | Set AI model and optional provider |

### Additions to existing `Shortcuts` section

| Keys / Command | Mode  | Description |
|---|---|---|
| `:AddShortcut <text>` | [cmd] | Save text as a shortcut slot |
| `:ClearShortcuts`     | [cmd] | Clear all shortcut slots |

### Additions to existing `Misc` section

| Keys / Command | Mode  | Description |
|---|---|---|
| `:MyCommands` | [cmd] | List all custom commands |

---

## Files Changed

| File | Change |
|---|---|
| `lua/panel.lua` | **New** — panel lifecycle module |
| `lua/ai.lua` | Replace float in `open_explain_window` with `require("panel").open(...)` |
| `init.lua` | Replace float in `show_keymaps` with `require("panel").open(...)`; add command entries to sections |

---

## Out of Scope

- The `Autogen` loading bar / `vim.ui.input` prompts are not affected.
- `:DebugIndent` is excluded (marked as temporary).
- Compile commands (`:Compile` etc.) already appear via their `<leader>` keybindings; no duplicate command entries added.
