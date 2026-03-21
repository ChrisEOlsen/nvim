# Neovim AI Integration — Design Spec
**Date:** 2026-03-20
**Status:** Approved

---

## Overview

Add AI-assisted code generation and explanation to the existing Neovim configuration via a self-contained `lua/ai.lua` module. Uses OpenRouter as the API backend, curl for HTTP (blocking), and no new plugins. Three user-facing commands: `:autogen`, `:explain`, `:aiconfig`.

**Minimum Neovim version:** 0.9 (required for `vim.api.nvim_set_option_value`).

---

## File Structure

```
~/.config/nvim/
├── init.lua                    (existing — add require("ai") and update :MyCommands)
├── lua/
│   └── ai.lua                  (new — all AI logic)
└── ai_prompts/
    ├── autogen.txt             (system prompt for :autogen)
    └── explain.txt             (system prompt for :explain)
```

Config persistence: `~/.local/share/nvim/ai_config.json`

---

## Module: `lua/ai.lua`

### Module Init

Run once at top of file before any command registration:
```lua
vim.api.nvim_set_hl(0, "AIFloatBorder", { fg = "#FFA500" })
```

### Config Layer

- On load: reads `ai_config.json`; if absent, defaults to model `"qwen/qwen3-coder"`.
- `save_ai_config()`: encodes config to JSON, writes `ai_config.json`; creates file if absent.
- Exposes `M.config.model`.

### Context Builder

- `build_autogen_context(bufnr)`:
  - Reads full buffer via `vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)`.
  - Gets buffer directory: `vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':h')`.
  - Scans for `#include "..."` lines, reads resolved `.h` files; silently skips missing.
  - Returns string: headers concatenated, then current file content.

- `get_visual_selection(bufnr, line1, line2)`:
  - `line1` / `line2` are the 1-based line numbers passed from `opts.line1` / `opts.line2`. Do NOT use `'<`/`'>` marks.
  - `vim.api.nvim_buf_get_lines(bufnr, line1 - 1, line2, false)` (converts to 0-based).
  - Returns lines joined with `"\n"`.

- `build_explain_context(bufnr)`:
  - Returns `table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")`.

### Fence Stripper

- `strip_fences(text)`:
  - Strips a leading ` ```[^\n]*\n` and a trailing `\n?` ` ``` ` if present.
  - Returns cleaned text.

### API Caller

- `call_openrouter(system_prompt, user_message)`:
  1. Read `OPENROUTER_API_KEY` via `vim.fn.getenv("OPENROUTER_API_KEY")`. If absent or empty: `vim.notify` error, return `nil`.
  2. Build JSON payload via `vim.fn.json_encode({ model=..., messages=[...] })`.
  3. Write payload to temp file: `tmpfile = vim.fn.tempname()`, `io.open(tmpfile, "w")`.
  4. Call curl in table form (bypasses shell):
     ```lua
     local raw = vim.fn.system({
       "curl", "-s", "-X", "POST",
       "https://openrouter.ai/api/v1/chat/completions",
       "-H", "Authorization: Bearer " .. api_key,
       "-H", "Content-Type: application/json",
       "--data", "@" .. tmpfile,
     })
     local exit_code = vim.v.shell_error
     vim.fn.delete(tmpfile)  -- unconditional: runs before any branching on exit_code or parse errors
     ```
  5. If `exit_code ~= 0`: `vim.notify` error with `raw`, return `nil`.
  6. `pcall(vim.fn.json_decode, raw)` — on throw: `vim.notify` error, return `nil`.
  7. Guard decoded response:
     - `response.choices` nil or not a table → error, return `nil`
     - `#response.choices == 0` → error, return `nil`
     - `response.choices[1].message` nil → error, return `nil`
     - (Lua tables from `json_decode` are 1-based; `choices[1]` is the first result)
  8. Return `strip_fences(response.choices[1].message.content)`.
     - `strip_fences` is called here so both `:autogen` and `:explain` paths receive clean text.

### Display Layer

- `open_explain_window(text)`:
  - `local lines = vim.split(text, "\n")`
  - Create scratch buffer: `nvim_create_buf(false, true)`, set `bufhidden=wipe`.
  - Compute geometry:
    ```lua
    local width  = math.min(80, vim.o.columns - 4)
    local height = math.max(3, math.min(#lines + 2, 25))
    local row    = math.floor((vim.o.lines   - height) / 2)
    local col    = math.floor((vim.o.columns - width)  / 2)
    ```
  - Open window: `nvim_open_win(buf, true, { relative="editor", row=row, col=col, width=width, height=height, border="rounded" })`
  - Apply orange border (highlight already registered at module init):
    ```lua
    vim.api.nvim_set_option_value("winhighlight", "FloatBorder:AIFloatBorder", { win = win_id })
    ```
  - `nvim_buf_set_lines(buf, 0, -1, false, lines)`
  - Close keymaps with `{ noremap=true, silent=true }`:
    ```lua
    vim.api.nvim_buf_set_keymap(buf, "n", "q",     "<cmd>close<CR>", { noremap=true, silent=true })
    vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<cmd>close<CR>", { noremap=true, silent=true })
    ```

- `insert_at_cursor(text)`:
  - `local lines = vim.split(text, "\n")`
  - `local pos = vim.api.nvim_win_get_cursor(0)` — `pos[1]` is the 1-based cursor row.
  - Insert after cursor line:
    ```lua
    -- pos[1] is 1-based. nvim_buf_set_lines is 0-based.
    -- To insert AFTER 1-based row N, pass 0-based index N (== pos[1]) as both start and end.
    -- Example: cursor at line 1 (1-based) → insert at 0-based index 1 → after the first line. Correct.
    -- strict_indexing=false clamps out-of-range indices, handling empty buffers safely.
    vim.api.nvim_buf_set_lines(0, pos[1], pos[1], false, lines)
    ```
  - Restore cursor: `vim.api.nvim_win_set_cursor(0, pos)`.

### System Prompt Loader

- `load_prompt(name)`:
  - Path: `vim.fn.stdpath("config") .. "/ai_prompts/" .. name .. ".txt"`.
  - Returns file content on success.
  - On failure: returns the hardcoded fallback string for that prompt name (constants defined at top of `ai.lua`; text identical to the default file contents documented in the System Prompts section below).

---

## Message Templates

### `:autogen` user message
```
--- CONTEXT START ---
<output of build_autogen_context(bufnr)>
--- CONTEXT END ---

Task: <opts.args>
```

### `:explain` user message
```
--- FILE CONTEXT START ---
<output of build_explain_context(bufnr)>
--- FILE CONTEXT END ---

--- SELECTED CODE ---
<output of get_visual_selection(bufnr, opts.line1, opts.line2)>
--- END SELECTED CODE ---
```

---

## Commands

All callbacks: `bufnr = vim.api.nvim_get_current_buf()` at invocation time.

### `:autogen <prompt>`
- `{ nargs = "+" }`
- No args → Neovim built-in `E471`. Acceptable.
- Flow:
  1. `bufnr = nvim_get_current_buf()`
  2. `system_prompt = load_prompt("autogen")`
  3. `context = build_autogen_context(bufnr)`
  4. Construct user message from autogen template.
  5. `result = call_openrouter(system_prompt, user_message)`
  6. If `result` is non-nil: `insert_at_cursor(result)`.

### `:explain`
- `{ range = 2 }`
- Visual mode: `opts.line1` / `opts.line2` span the selection.
- Normal mode (no explicit range): `opts.line1 == opts.line2 == current line`. Explains one line. Intentional and acceptable.
- Flow:
  1. `bufnr = nvim_get_current_buf()`
  2. `system_prompt = load_prompt("explain")`
  3. `selection = get_visual_selection(bufnr, opts.line1, opts.line2)`
  4. `file_context = build_explain_context(bufnr)`
  5. Construct user message from explain template.
  6. `result = call_openrouter(system_prompt, user_message)`
  7. If `result` is non-nil: `open_explain_window(result)`.

### `:aiconfig <model>`
- `{ nargs = 1 }`
- Flow:
  1. `M.config.model = opts.args`
  2. `save_ai_config()`
  3. `print("AI model set to: " .. opts.args)`

---

## System Prompts

The following text is used both as the default file content AND as the hardcoded fallback in `load_prompt`.

### `ai_prompts/autogen.txt`
```
You are a code generation assistant embedded in a text editor.
Output ONLY valid code. No explanations, no markdown fences, no commentary.
Match the language, style, and conventions of the surrounding code exactly.
If the context is C or C++, follow C89/C99/C++ conventions as shown in the file.
```

### `ai_prompts/explain.txt`
```
You are a concise code explanation assistant embedded in a text editor.
Respond in two short sections:
1. SYNTAX: Identify the language constructs and patterns used (2-4 lines max).
2. PURPOSE: Explain what this code does in the context of the file (3-5 lines max).
Be direct. No preamble, no filler. Fit your entire response within 20 lines.
```

---

## Config Persistence

File: `~/.local/share/nvim/ai_config.json`
Schema: `{ "model": "qwen/qwen3-coder" }`
Read at load. Written on `:aiconfig`. Created on first write if absent.

---

## Integration with `init.lua`

**1.** Add at end of `init.lua`:
```lua
require("ai")
```

**2.** Update `:MyCommands` at line 519 of `init.lua`. Change:
```lua
local cmds = { "MainArgs", "MainVoid", "AddProto", "CommentBox", "Compile", "MyCommands" }
```
To:
```lua
local cmds = { "MainArgs", "MainVoid", "AddProto", "CommentBox", "Compile", "MyCommands", "autogen", "explain", "aiconfig" }
```

---

## Error Handling

| Scenario | Behaviour |
|---|---|
| API key not set or empty | `vim.notify` error, abort |
| curl fails (non-zero exit) | `vim.notify` error + output, abort; temp file already deleted |
| `json_decode` throws | `vim.notify` error via `pcall`, abort |
| `choices` nil / empty / malformed | `vim.notify` error, abort |
| LLM returns markdown fences | `strip_fences()` called in `call_openrouter` before return — covers both commands |
| Temp file write fails | `io.open` returns nil; `vim.notify` error, abort before curl |
| Header `.h` file not found | Silently skip |
| `ai_config.json` missing | Use defaults; created on first `:aiconfig` |
| Prompt file missing | Use hardcoded fallback string |
| `:autogen` called with no args | Neovim built-in `E471` |
| `:explain` from normal mode | Explains current line only |
