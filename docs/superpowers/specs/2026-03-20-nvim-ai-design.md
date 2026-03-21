# Neovim AI Integration — Design Spec
**Date:** 2026-03-20
**Status:** Approved

---

## Overview

Add AI-assisted code generation and explanation to the existing Neovim configuration via a self-contained `lua/ai.lua` module. Uses OpenRouter as the API backend, curl for HTTP (blocking), and no new plugins. Three user-facing commands: `:autogen`, `:explain`, `:aiconfig`.

---

## File Structure

```
~/.config/nvim/
├── init.lua                    (existing — add one require("ai") line)
├── lua/
│   └── ai.lua                  (new — all AI logic)
└── ai_prompts/
    ├── autogen.txt             (system prompt for :autogen)
    └── explain.txt             (system prompt for :explain)
```

Config persistence: `~/.local/share/nvim/ai_config.json`
Matches the existing theme state JSON pattern in `init.lua`.

---

## Module: `lua/ai.lua`

### Config Layer

- On load: reads `ai_config.json`; if absent, defaults to model `"qwen/qwen3-coder"`.
- `save_ai_config()`: encodes config to JSON and writes to `ai_config.json`.
- Exposes `M.config.model` for use by the API caller.

### Context Builder

- `build_autogen_context(bufnr)`:
  - Reads full buffer content.
  - Scans for `#include "..."` lines (local headers only — `<system>` headers ignored).
  - Resolves each header path relative to the current file's directory.
  - Reads each resolved `.h` file if it exists on disk.
  - Returns a single concatenated string: headers first, then current file.
- `get_visual_selection(bufnr, line1, line2)`:
  - Returns the selected lines as a string for use in `:explain`.
- `build_explain_context(bufnr)`:
  - Returns the full buffer content as a string (no header resolution).

### API Caller

- `call_openrouter(system_prompt, user_message)`:
  - Reads `OPENROUTER_API_KEY` from env via `vim.fn.getenv("OPENROUTER_API_KEY")`.
  - If key is absent or empty, surfaces an error notification and returns `nil`.
  - Builds JSON payload:
    ```json
    {
      "model": "<config.model>",
      "messages": [
        { "role": "system", "content": "<system_prompt>" },
        { "role": "user",   "content": "<user_message>" }
      ]
    }
    ```
  - Shells out via `vim.fn.system()` using `curl`:
    ```
    curl -s -X POST https://openrouter.ai/api/v1/chat/completions
         -H "Authorization: Bearer <key>"
         -H "Content-Type: application/json"
         -d '<payload>'
    ```
  - Parses response with `vim.fn.json_decode()`.
  - Returns `response.choices[1].message.content` as a string, or `nil` on error.
  - On error (non-zero shell exit or missing `choices`): shows `vim.notify` error.

### Display Layer

- `open_explain_window(text)`:
  - Splits text into lines.
  - Creates a scratch buffer (`nobuflisted`, `bufhidden=wipe`).
  - Opens a centered floating window via `vim.api.nvim_open_win()`:
    - `relative = "editor"`, centered on screen.
    - Width: min(80, editor_width - 4). Height: min(#lines + 2, 25).
    - `border = "rounded"`.
  - After opening, sets the `FloatBorder` highlight group to orange (`#FFA500`) for this window only via `vim.api.nvim_win_set_option` + `winhighlight`.
  - Sets buffer lines to the response text.
  - Maps `q` and `<Esc>` in the float to close it.

- `insert_at_cursor(text)`:
  - Splits text into lines.
  - Gets current cursor row.
  - Inserts lines at cursor position via `vim.api.nvim_buf_set_lines()`.

### System Prompt Loader

- `load_prompt(name)`:
  - Reads `~/.config/nvim/ai_prompts/<name>.txt`.
  - Returns content as string, or a sensible hardcoded fallback if file is missing.

---

## Commands

### `:autogen <prompt>`

- Mode: Normal
- Definition: `vim.api.nvim_create_user_command('autogen', ...)`
- Flow:
  1. Load `ai_prompts/autogen.txt` as system prompt.
  2. Build context string via `build_autogen_context()`.
  3. Construct user message: context block + user's prompt argument.
  4. Call `call_openrouter(system_prompt, user_message)`.
  5. Insert result at cursor via `insert_at_cursor()`.

### `:explain` (visual range)

- Mode: Visual (defined with `range = true`)
- Definition: `vim.api.nvim_create_user_command('explain', ..., { range = true })`
- Flow:
  1. Load `ai_prompts/explain.txt` as system prompt.
  2. Capture selected lines via `get_visual_selection(bufnr, line1, line2)`.
  3. Build full file context via `build_explain_context()`.
  4. Construct user message: selected code block + full file context.
  5. Call `call_openrouter(system_prompt, user_message)`.
  6. Display result via `open_explain_window()`.

### `:aiconfig <model>`

- Mode: Normal
- Definition: `vim.api.nvim_create_user_command('aiconfig', ..., { nargs = 1 })`
- Flow:
  1. Update `M.config.model` with the argument.
  2. Call `save_ai_config()`.
  3. Print `"AI model set to: <model>"`.

---

## System Prompts

### `ai_prompts/autogen.txt` (default content)
```
You are a code generation assistant embedded in a text editor.
Output ONLY valid code. No explanations, no markdown fences, no commentary.
Match the language, style, and conventions of the surrounding code exactly.
If the context is C or C++, follow C89/C99/C++ conventions as shown in the file.
```

### `ai_prompts/explain.txt` (default content)
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

Schema:
```json
{ "model": "qwen/qwen3-coder" }
```

Pattern mirrors the existing `theme_state.json` in `init.lua`: read at module load, written on change.

---

## Integration with `init.lua`

Add a single line at the end of `init.lua`:
```lua
require("ai")
```

Also update the `:MyCommands` listing to include `autogen`, `explain`, `aiconfig`.

---

## Error Handling

| Scenario | Behaviour |
|---|---|
| `OPENROUTER_API_KEY` not set | `vim.notify` error, abort |
| curl fails (network/timeout) | `vim.notify` error with shell output |
| JSON parse fails | `vim.notify` error, abort |
| Header file not found | Silently skip that include |
| `ai_config.json` missing | Use defaults, create on first `:aiconfig` |
| Prompt file missing | Use hardcoded fallback prompt |
