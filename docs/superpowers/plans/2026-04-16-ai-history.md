# AI History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Save every AI explain response to a per-file JSON store and let the user browse history in the panel split via `<leader>ah` with arrow-key navigation and pagination.

**Architecture:** New `lua/history.lua` owns persistence (save/load/open_panel). `lua/ai.lua` gains two `history.save()` call-sites (after explain responses) and one `<leader>ah` keymap. `lua/panel.lua` is untouched.

**Tech Stack:** Neovim Lua API, `vim.fn.json_encode/decode`, `io.open`, `panel.lua` (existing)

---

## File Map

| File | Action |
|------|--------|
| `lua/history.lua` | **Create** — persistence + panel navigation |
| `lua/ai.lua` | **Modify** — add 2 `history.save()` calls + `<leader>ah` keymap |
| `lua/panel.lua` | No change |

---

### Task 1: Create `lua/history.lua`

**Files:**
- Create: `lua/history.lua`

- [ ] **Step 1: Create the file with save/load and open_panel**

```lua
-- lua/history.lua
local M = {}

local HISTORY_DIR = vim.fn.stdpath("config") .. "/.ai"
local MAX_ENTRIES = 50

local function derive_path(buf_path)
    local key = buf_path:gsub("/", "_")
    return HISTORY_DIR .. "/" .. key .. ".json"
end

local function ensure_dir()
    if vim.fn.isdirectory(HISTORY_DIR) == 0 then
        local ok = vim.fn.mkdir(HISTORY_DIR, "p")
        if ok == 0 then
            vim.notify("AI History: could not create " .. HISTORY_DIR, vim.log.levels.ERROR)
        end
    end
end

local function load_by_path(buf_path)
    local path = derive_path(buf_path)
    local f = io.open(path, "r")
    if not f then return {} end
    local content = f:read("*a")
    f:close()
    local ok, entries = pcall(vim.fn.json_decode, content)
    if not ok or type(entries) ~= "table" then
        vim.notify("AI History: corrupt file, treating as empty: " .. path, vim.log.levels.WARN)
        return {}
    end
    return entries
end

function M.save(bufnr, text)
    local buf_path = vim.api.nvim_buf_get_name(bufnr)
    if buf_path == "" then return end
    ensure_dir()
    local entries = load_by_path(buf_path)
    table.insert(entries, {
        timestamp = os.date("%Y-%m-%dT%H:%M:%S"),
        source    = buf_path,
        content   = text,
    })
    while #entries > MAX_ENTRIES do
        table.remove(entries, 1)
    end
    local path = derive_path(buf_path)
    local f = io.open(path, "w")
    if not f then
        vim.notify("AI History: could not write " .. path, vim.log.levels.ERROR)
        return
    end
    f:write(vim.fn.json_encode(entries))
    f:close()
end

function M.load(bufnr)
    local buf_path = vim.api.nvim_buf_get_name(bufnr)
    if buf_path == "" then return {} end
    return load_by_path(buf_path)
end

-- Navigation state
local _nav = { entries = {}, index = 1, buf = nil, source_path = "" }

local function build_panel_lines(entry, index, total, source_path)
    local panel_width = math.floor(vim.o.columns / 2)
    local lines = {}
    table.insert(lines, " AI History — " .. source_path)
    table.insert(lines, " " .. string.rep("─", panel_width - 2))
    table.insert(lines, " " .. entry.timestamp)
    table.insert(lines, "")
    for _, line in ipairs(vim.split(entry.content:gsub("\n+$", ""), "\n")) do
        table.insert(lines, " " .. line)
    end
    local pagination = "[" .. index .. " / " .. total .. "]"
    local padding = string.rep(" ", math.max(0, panel_width - #pagination - 1))
    table.insert(lines, "")
    table.insert(lines, padding .. pagination)
    return lines
end

local function repopulate()
    local entry = _nav.entries[_nav.index]
    local lines = build_panel_lines(entry, _nav.index, #_nav.entries, _nav.source_path)
    vim.api.nvim_set_option_value("modifiable", true,  { buf = _nav.buf })
    vim.api.nvim_buf_set_lines(_nav.buf, 0, -1, false, lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = _nav.buf })
end

function M.open_panel(bufnr)
    local buf_path = vim.api.nvim_buf_get_name(bufnr)
    local entries  = M.load(bufnr)

    if #entries == 0 then
        require("panel").open({ "  No AI history for this file." }, { wrap = true })
        return
    end

    local reversed = {}
    for i = #entries, 1, -1 do
        table.insert(reversed, entries[i])
    end

    _nav.entries     = reversed
    _nav.index       = 1
    _nav.source_path = buf_path

    local first_lines = build_panel_lines(reversed[1], 1, #reversed, buf_path)
    local buf = require("panel").open(first_lines, { wrap = true })
    _nav.buf = buf

    vim.keymap.set("n", "<Right>", function()
        if _nav.index > 1 then
            _nav.index = _nav.index - 1
            repopulate()
        end
    end, { buffer = buf, noremap = true, silent = true })

    vim.keymap.set("n", "<Left>", function()
        if _nav.index < #_nav.entries then
            _nav.index = _nav.index + 1
            repopulate()
        end
    end, { buffer = buf, noremap = true, silent = true })
end

return M
```

- [ ] **Step 2: Verify the file loads without errors**

Open Neovim and run:
```vim
:lua require("history")
```
Expected: no error. If you see "module not found", check the file is at `~/.config/nvim/lua/history.lua`.

- [ ] **Step 3: Commit**

```bash
git add lua/history.lua
git commit -m "feat(history): add AI history persistence and panel navigation"
```

---

### Task 2: Wire `history.save()` into `lua/ai.lua`

**Files:**
- Modify: `lua/ai.lua` — lines 499 and 514-516

- [ ] **Step 1: Add `history.save()` call in `<leader>ai` keymap**

Find line 499 in `lua/ai.lua`:
```lua
            if result then open_explain_window(result) end
```

Replace with:
```lua
            if result then
                open_explain_window(result)
                require("history").save(bufnr, result)
            end
```

- [ ] **Step 2: Add `history.save()` call in `:Explain` command**

Find lines 514-516 in `lua/ai.lua`:
```lua
    local result = call_openrouter(system_prompt, user_message)
    if result then
        open_explain_window(result)
    end
```

Replace with:
```lua
    local result = call_openrouter(system_prompt, user_message)
    if result then
        open_explain_window(result)
        require("history").save(bufnr, result)
    end
```

- [ ] **Step 3: Add `<leader>ah` keymap**

Add this block anywhere after `require("ai")` loads (end of `lua/ai.lua`, before `return M`):

```lua
vim.keymap.set("n", "<leader>ah", function()
    local bufnr = vim.api.nvim_get_current_buf()
    require("history").open_panel(bufnr)
end, { noremap = true, silent = true, desc = "AI History for current file" })
```

- [ ] **Step 4: Verify no startup errors**

Restart Neovim. Expected: clean startup, no errors in `:messages`.

- [ ] **Step 5: Commit**

```bash
git add lua/ai.lua
git commit -m "feat(ai): save explain responses to history, add <leader>ah keymap"
```

---

### Task 3: End-to-end verification

**Files:** none (manual verification only)

- [ ] **Step 1: Trigger an explain and check the history file was created**

1. Open any C file in Neovim.
2. Select a few lines in visual mode, press `<leader>ai`, press Enter for plain explanation.
3. Wait for the panel to open with the AI response.
4. In a terminal, check:
   ```bash
   ls ~/.config/nvim/.ai/
   cat ~/.config/nvim/.ai/_Users_*.json | python3 -m json.tool
   ```
   Expected: one `.json` file with one entry containing `timestamp`, `source`, and `content`.

- [ ] **Step 2: Trigger a second explain on the same file**

Repeat Step 1 on the same file. Check:
```bash
cat ~/.config/nvim/.ai/_Users_*.json | python3 -m json.tool
```
Expected: two entries in the array, second one has a newer timestamp.

- [ ] **Step 3: Open history panel and check display**

Press `<leader>ah`.  
Expected:
- Panel opens on the right.
- Title line: `" AI History — /abs/path/to/yourfile.c"`
- Separator line of `─` characters.
- Timestamp line.
- Content of most recent explain response.
- Bottom-right pagination: `[1 / 2]`

- [ ] **Step 4: Navigate with arrow keys**

Press `<Left>` arrow.  
Expected: panel content updates to older entry, pagination shows `[2 / 2]`.

Press `<Right>` arrow.  
Expected: panel content updates back to most recent, pagination shows `[1 / 2]`.

Press `<Left>` again at oldest entry.  
Expected: nothing changes (no wrap, no error).

- [ ] **Step 5: Verify file isolation**

Open a different file, press `<leader>ah`.  
Expected: panel shows `"  No AI history for this file."` (assuming no prior explain on that file).

- [ ] **Step 6: Verify AutoEdit is NOT saved**

Run `<leader>ae` on any file, complete a task. Press `<leader>ah`.  
Expected: no new entry added from AutoEdit.

- [ ] **Step 7: Commit**

```bash
git commit --allow-empty -m "chore: verify ai history feature end-to-end"
```
