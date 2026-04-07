# Right-Split Panel & Extended Keymap Reference — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all floating popup windows with a persistent right-side vertical split at 50% width, and extend the `<leader>?` reference to include custom commands that have no keybinding.

**Architecture:** A new `lua/panel.lua` module owns the split lifecycle (create or reuse a window, swap buffer content, set width). Both `lua/ai.lua` and `init.lua` call `require("panel").open(title, lines, opts)` — removing all float-sizing code from those files.

**Tech Stack:** Neovim Lua API (`nvim_open_win` removed; `botright vsplit` + `nvim_win_set_width` used instead). No external plugins.

> **Note on testing:** This config has no Lua unit-test framework. Each task ends with a manual verification step in a live Neovim session.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `lua/panel.lua` | **Create** | Panel lifecycle: open/reuse vsplit, populate buffer, bind q/Esc |
| `lua/ai.lua` | **Modify** lines 207–263 | Replace float in `open_explain_window` with `require("panel").open(...)` |
| `init.lua` | **Modify** lines 754–774, 800–838 | Replace float in `show_keymaps`; add command entries to sections |

---

## Task 1: Create `lua/panel.lua`

**Files:**
- Create: `lua/panel.lua`

- [ ] **Step 1: Create the file with this exact content**

```lua
-- lua/panel.lua
-- Shared right-side vertical split panel.
-- Used by AI explain output and the keymap reference.

local M = {}

local panel_win = nil  -- tracks the last panel window ID

local function populate(win, buf, lines, opts)
    opts = opts or {}

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_option_value("modifiable",     false,    { buf = buf })
    vim.api.nvim_set_option_value("buftype",        "nofile", { buf = buf })
    vim.api.nvim_set_option_value("bufhidden",      "wipe",   { buf = buf })
    vim.api.nvim_set_option_value("swapfile",       false,    { buf = buf })

    vim.api.nvim_set_option_value("number",         false,          { win = win })
    vim.api.nvim_set_option_value("relativenumber", false,          { win = win })
    vim.api.nvim_set_option_value("signcolumn",     "no",           { win = win })
    vim.api.nvim_set_option_value("cursorline",     true,           { win = win })
    vim.api.nvim_set_option_value("wrap",           opts.wrap or false, { win = win })
    if opts.wrap then
        vim.api.nvim_set_option_value("linebreak",  true,           { win = win })
        vim.api.nvim_set_option_value("fillchars",  "eob: ",        { win = win })
    end

    vim.api.nvim_buf_set_keymap(buf, "n", "q",     "<cmd>close<CR>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<cmd>close<CR>", { noremap = true, silent = true })
end

function M.open(title, lines, opts)
    opts = opts or {}
    local width = math.floor(vim.o.columns / 2)

    if panel_win and vim.api.nvim_win_is_valid(panel_win) then
        -- Reuse existing window: swap to a fresh scratch buffer
        local old_buf = vim.api.nvim_win_get_buf(panel_win)
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_win_set_buf(panel_win, buf)
        pcall(vim.api.nvim_buf_delete, old_buf, { force = true })
        vim.api.nvim_win_set_width(panel_win, width)
        vim.api.nvim_set_current_win(panel_win)
        populate(panel_win, buf, lines, opts)
    else
        -- Open a new right-side split
        vim.cmd("botright vsplit")
        panel_win = vim.api.nvim_get_current_win()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_win_set_buf(panel_win, buf)
        vim.api.nvim_win_set_width(panel_win, width)
        populate(panel_win, buf, lines, opts)
    end
end

return M
```

- [ ] **Step 2: Verify Neovim loads the file without errors**

Open Neovim and run:
```
:lua require("panel")
```
Expected: no error message. If you see `module 'panel' not found`, check the file is saved at `~/.config/nvim/lua/panel.lua`.

- [ ] **Step 3: Commit**

```bash
git add lua/panel.lua
git commit -m "feat: add shared right-split panel module"
```

---

## Task 2: Wire `open_explain_window` in `lua/ai.lua` to use the panel

**Files:**
- Modify: `lua/ai.lua` lines 207–263

The current `open_explain_window` function has two parts: (1) build the `padded` lines array, and (2) create a floating window. Keep part 1, replace part 2.

- [ ] **Step 1: Replace `open_explain_window` (lines 207–263 of `lua/ai.lua`) with this**

```lua
local function open_explain_window(text)
    -- Strip trailing blank line that some models append
    local lines = vim.split(text:gsub("\n+$", ""), "\n")

    -- Add one space of left padding to each line for breathing room
    local padded = {}
    for _, line in ipairs(lines) do
        table.insert(padded, " " .. line)
    end

    require("panel").open(" explain ", padded, { wrap = true })
end
```

The removed block starts at the `-- Width: 60% of screen` comment and ends at the closing `end` of `open_explain_window`. The new function body ends at `require("panel").open(...)`.

- [ ] **Step 2: Manually verify AI explain opens in a right split**

1. Open any file in Neovim.
2. Select a few lines in visual mode.
3. Press `<leader>ai` and press Enter (plain explanation).
4. Expected: a vertical split opens on the right at roughly 50% width with the AI output. `q` or `<Esc>` closes the split.
5. Press `<leader>ai` again on another selection.
6. Expected: the same split is reused (not a second split).

- [ ] **Step 3: Commit**

```bash
git add lua/ai.lua
git commit -m "feat: open AI explain output in right-split panel"
```

---

## Task 3: Wire `show_keymaps` in `init.lua` to use the panel

**Files:**
- Modify: `init.lua` lines 800–838

The current `show_keymaps` function builds `lines` then creates a floating window. Keep the line-building logic, replace the float block.

- [ ] **Step 1: Remove the float sizing/creation block**

In `init.lua`, find this block (starting around line 800, after `table.insert(lines, "")`) and **delete everything from `-- Size` through the end of `show_keymaps`** (just before the `end` at line 839):

```lua
    -- Size
    local max_len = 0
    for _, l in ipairs(lines) do
        if #l > max_len then max_len = #l end
    end
    local width  = math.min(max_len + 2, vim.o.columns - 4)
    local height = math.min(#lines, vim.o.lines - 4)

    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        row = row, col = col,
        width = width, height = height,
        border = "rounded",
        title = " keymaps ",
        title_pos = "center",
    })

    vim.api.nvim_set_option_value(
        "winhighlight",
        "FloatBorder:AIFloatBorder,FloatTitle:AIFloatBorder,Normal:Normal",
        { win = win }
    )
    vim.api.nvim_set_option_value("wrap",           false, { win = win })
    vim.api.nvim_set_option_value("number",         false, { win = win })
    vim.api.nvim_set_option_value("relativenumber", false, { win = win })
    vim.api.nvim_set_option_value("signcolumn",     "no",  { win = win })
    vim.api.nvim_set_option_value("cursorline",     true,  { win = win })

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

    vim.api.nvim_buf_set_keymap(buf, "n", "q",     "<cmd>close<CR>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<cmd>close<CR>", { noremap = true, silent = true })
```

- [ ] **Step 2: Replace it with a single panel call**

In place of the deleted block (still inside `show_keymaps`, just before the closing `end`), insert:

```lua
    require("panel").open(" keymaps ", lines)
```

The full tail of `show_keymaps` after the line-building loop should now look like:

```lua
    table.insert(lines, "")

    require("panel").open(" keymaps ", lines)
end
```

- [ ] **Step 3: Manually verify `<leader>?` opens in a right split**

1. Open Neovim.
2. Press `<leader>?`.
3. Expected: a vertical split opens on the right at ~50% width showing the keymap reference. `q` closes it.
4. Press `<leader>?` again.
5. Expected: same split reused, not a second one stacked.
6. Open the explain panel (`<leader>ai`) while keymaps is open.
7. Expected: keymaps panel is replaced by AI output in the same window.

- [ ] **Step 4: Commit**

```bash
git add init.lua
git commit -m "feat: open keymap reference in right-split panel"
```

---

## Task 4: Add command-only entries to `show_keymaps` sections

**Files:**
- Modify: `init.lua` lines 754–774 (the `sections` table in `show_keymaps`)

Commands without keybindings use `"cmd"` as their mode string — the format string `[%-3s]` will render it as `[cmd]`.

- [ ] **Step 1: Add `:Aiconfig` to the AI section**

Find:
```lua
        { title = "AI", maps = {
            { keys = "<leader>ag",      mode = "n",   desc = "AI: generate code at cursor" },
            { keys = "<leader>ai",      mode = "v",   desc = "AI: explain / ask about selection" },
        }},
```

Replace with:
```lua
        { title = "AI", maps = {
            { keys = "<leader>ag",                    mode = "n",   desc = "AI: generate code at cursor" },
            { keys = "<leader>ai",                    mode = "v",   desc = "AI: explain / ask about selection" },
            { keys = ":Aiconfig <model> [provider]",  mode = "cmd", desc = "Set AI model and optional provider" },
        }},
```

- [ ] **Step 2: Add a new `C/C++ Scaffolding` section after the Compile section**

Find:
```lua
        { title = "AI", maps = {
```

Insert this block immediately before it:
```lua
        { title = "C/C++ Scaffolding", maps = {
            { keys = ":MainArgs",   mode = "cmd", desc = "Insert main() with argc/argv" },
            { keys = ":MainVoid",   mode = "cmd", desc = "Insert main() with no args" },
            { keys = ":AddProto",   mode = "cmd", desc = "Add function prototype" },
            { keys = ":CommentBox", mode = "cmd", desc = "Insert decorated comment box" },
        }},
```

- [ ] **Step 3: Add `:AddShortcut` and `:ClearShortcuts` to the Shortcuts section**

Find:
```lua
        { title = "Shortcuts", maps = {
            { keys = "<leader>s1-s6",   mode = "n",   desc = "Insert saved shortcut text" },
            { keys = "<leader>sd",      mode = "n",   desc = "List active shortcuts" },
        }},
```

Replace with:
```lua
        { title = "Shortcuts", maps = {
            { keys = "<leader>s1-s6",       mode = "n",   desc = "Insert saved shortcut text" },
            { keys = "<leader>sd",          mode = "n",   desc = "List active shortcuts" },
            { keys = ":AddShortcut <text>", mode = "cmd", desc = "Save text as a shortcut slot" },
            { keys = ":ClearShortcuts",     mode = "cmd", desc = "Clear all shortcut slots" },
        }},
```

- [ ] **Step 4: Add `:MyCommands` to the Misc section**

Find:
```lua
        { title = "Misc", maps = {
            { keys = "<leader>tm",      mode = "n",   desc = "Toggle theme (dark/light/transparent)" },
            { keys = "<leader>z",       mode = "n",   desc = "Zen mode" },
            { keys = "<Esc>",           mode = "n",   desc = "Clear search highlight" },
            { keys = "<leader>?",       mode = "n",   desc = "Show this keymap reference" },
        }},
```

Replace with:
```lua
        { title = "Misc", maps = {
            { keys = "<leader>tm",  mode = "n",   desc = "Toggle theme (dark/light/transparent)" },
            { keys = "<leader>z",   mode = "n",   desc = "Zen mode" },
            { keys = "<Esc>",       mode = "n",   desc = "Clear search highlight" },
            { keys = "<leader>?",   mode = "n",   desc = "Show this keymap reference" },
            { keys = ":MyCommands", mode = "cmd", desc = "List all custom commands" },
        }},
```

- [ ] **Step 5: Manually verify `<leader>?` shows new entries**

1. Open Neovim and press `<leader>?`.
2. Confirm you see:
   - A `C/C++ Scaffolding` section with `:MainArgs`, `:MainVoid`, `:AddProto`, `:CommentBox`
   - `:Aiconfig <model> [provider]` in the AI section
   - `:AddShortcut <text>` and `:ClearShortcuts` in the Shortcuts section
   - `:MyCommands` in the Misc section
3. All should have `[cmd]` as the mode column.

- [ ] **Step 6: Commit**

```bash
git add init.lua
git commit -m "feat: add command-only entries to keymap reference"
```
