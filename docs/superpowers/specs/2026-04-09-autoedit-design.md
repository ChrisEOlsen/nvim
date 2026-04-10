# AutoEdit Design Spec
**Date:** 2026-04-09  
**Status:** Approved

## Summary

AutoEdit is a new AI command for the Neovim config that edits the current file in response to a natural-language instruction. Unlike Autogen (which inserts code at cursor), AutoEdit can make changes anywhere in the file. All changes are applied atomically as a single undo unit.

---

## Architecture & Data Flow

Everything is implemented as a new block in `lua/ai.lua`. No new files are required.

```
User invokes AutoEdit (command / <leader>ae / visual <leader>ae)
  → capture: bufnr, cursor line, optional visual range
  → prompt for instruction via vim.ui.input
  → show loading indicator (same ▓▓▓▓▓▓▓▓▓▓▓▓ bar as Autogen)
  → call_openrouter(autoedit_system_prompt, full_file + instruction)
  → AI returns: entire modified file as plain text
  → compute diff: old lines vs new lines (Myers diff in Lua)
  → open diff preview in panel.lua (right split)
  → user presses y to confirm, n/q/Esc to cancel
  → on confirm: nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
```

The single `nvim_buf_set_lines` call at the end is what guarantees the entire edit is one undo unit — pressing `u` removes all changes at once.

---

## Scope

- **Current file only.** AutoEdit does not read or modify local headers (unlike Autogen's context builder). The file sent to the AI is exactly the current buffer contents.
- **Single-pass.** The AI produces the complete modified file in one response. No agentic loop.

---

## System Prompt

Stored at `ai_prompts/autoedit.txt` with a fallback in `FALLBACK_PROMPTS.autoedit`.

Key constraints enforced by the prompt:
1. Return the **full file verbatim** — no markdown fences, no commentary, no preamble. The entire response is the new file content.
2. **Preserve everything not asked to change** — whitespace, comments, formatting, unrelated code must be untouched.
3. **Match existing style** — Allman braces, no-brace single-statement bodies, same conventions as Autogen.

### User Message Structure

```
--- FILE START ---
<full buffer contents>
--- FILE END ---

Cursor is at line N.
[If visual mode: Focus region is lines X–Y.]

Task: <user instruction>
```

---

## Diff Preview Panel

Reuses `panel.lua`'s right-split. Format:

```
AutoEdit diff — y to apply, n/q/Esc to cancel

  line 4   int foo = 1;
- line 5   int bar = old_value;
+ line 5   int bar = new_value;
  line 6   return foo + bar;
```

- **Context:** 3 unchanged lines before/after each changed region, prefixed with line number
- **Removed lines:** `-` prefix, highlighted with `DiffDelete`
- **Added lines:** `+` prefix, highlighted with `DiffAdd`
- **Header line** at top of panel

### Diff Panel Keybindings

| Key | Action |
|-----|--------|
| `y` | Apply changes and close panel |
| `n` | Cancel and close panel |
| `q` | Cancel and close panel |
| `Esc` | Cancel and close panel |

---

## Invocation

| Key / Command | Mode | Behavior |
|---------------|------|----------|
| `<leader>ae` | Normal | Prompt for instruction, AutoEdit full file |
| `<leader>ae` | Visual | Prompt for instruction, AutoEdit with selection noted as focus region |
| `:AutoEdit <task>` | Command | AutoEdit full file (no leader shortcut needed) |

---

## Error Handling & Edge Cases

| Scenario | Behavior |
|----------|----------|
| API error / empty response | `vim.notify` error, no buffer changes |
| Response looks like non-code (error message from API) | `vim.notify` error, no buffer changes |
| AI returns identical file | Notify "AutoEdit: no changes suggested", no panel opened |
| Visual mode invoked with trivial selection | Treated as full-file edit; selection range sent as focus hint only |
| User edits buffer while diff panel is open, then confirms | New content overwrites buffer (same behavior as paste-over) — acceptable |

---

## Implementation Notes

- **Myers diff:** Implement a simple line-level Myers diff in Lua. Files are C/C++ source, typically small — no performance concern.
- **Highlight groups:** Use built-in `DiffAdd` and `DiffDelete` — no custom highlight registration needed.
- **Fallback prompt:** Add `autoedit` key to `FALLBACK_PROMPTS` table in `ai.lua`, matching the pattern of the existing `autogen` entry.
- **Prompt file:** Add `ai_prompts/autoedit.txt` alongside the existing `ai_prompts/` directory convention.
