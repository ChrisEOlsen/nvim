# Model Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a favorites-based model picker (`<leader>ac`) so the user can save OpenRouter model IDs with `:AddModel` and switch between them via a j/k navigable panel.

**Architecture:** `ai_config.json` gains a `favorites` array persisted alongside `model`/`provider`. A new `lua/models.lua` module owns the picker UI (mirrors `history.lua` pattern). `ai.lua` gets the `:AddModel` command, a `favorites = {}` config default, and the `<leader>ac` keymap.

**Tech Stack:** Lua, Neovim API, `lua/panel.lua` (existing right-split panel), `lua/ai.lua` (existing config persistence)

---

### Task 1: Add `favorites` default to `load_ai_config`

**Files:**
- Modify: `lua/ai.lua:16-27`

- [ ] **Step 1: Update `load_ai_config` to ensure `favorites` key always exists**

In `lua/ai.lua`, change the `load_ai_config` function:

```lua
local function load_ai_config()
    local f = io.open(ai_config_file, "r")
    if f then
        local content = f:read("*a")
        f:close()
        local ok, state = pcall(vim.fn.json_decode, content)
        if ok and state then
            if not state.favorites then
                state.favorites = {}
            end
            return state
        end
    end
    return { model = "anthropic/claude-sonnet-4.6", favorites = {} }
end
```

- [ ] **Step 2: Verify Neovim loads without errors**

Restart Neovim (or `:source %` on `ai.lua`). Run:
```
:lua print(vim.inspect(require("ai").config.favorites))
```
Expected output: `{}`

- [ ] **Step 3: Commit**

```bash
git add lua/ai.lua
git commit -m "feat(models): add favorites array to ai config"
```

---

### Task 2: Add `:AddModel` command

**Files:**
- Modify: `lua/ai.lua` (after the `:Aiconfig` command block, around line 561)

- [ ] **Step 1: Add the `:AddModel` command after the existing `:Aiconfig` command**

Insert after line 561 (`end, { nargs = "+", desc = "Set AI model...` line):

```lua
vim.api.nvim_create_user_command("AddModel", function(opts)
    local id = vim.trim(opts.args)
    if id == "" then
        print("Usage: :AddModel <model-id>")
        return
    end
    for _, existing in ipairs(M.config.favorites) do
        if existing == id then
            print("Already in favorites: " .. id)
            return
        end
    end
    table.insert(M.config.favorites, id)
    save_ai_config()
    print("Added to favorites: " .. id)
end, { nargs = "+", desc = "Add a model ID to the AI favorites list" })
```

- [ ] **Step 2: Verify command works**

Restart Neovim. Run:
```
:AddModel openai/gpt-4o
```
Expected: `Added to favorites: openai/gpt-4o`

Run again:
```
:AddModel openai/gpt-4o
```
Expected: `Already in favorites: openai/gpt-4o`

Check persistence — quit and reopen Neovim, then:
```
:lua print(vim.inspect(require("ai").config.favorites))
```
Expected: `{ "openai/gpt-4o" }`

- [ ] **Step 3: Commit**

```bash
git add lua/ai.lua
git commit -m "feat(models): add :AddModel command"
```

---

### Task 3: Create `lua/models.lua` picker

**Files:**
- Create: `lua/models.lua`

- [ ] **Step 1: Create `lua/models.lua`**

```lua
-- lua/models.lua
-- Favorite model picker: <leader>ac opens a navigable panel.

local M = {}

local HEADER = " Model Picker — j/k navigate, <Enter> select"

local function build_lines(favorites)
    local panel_width = math.floor(vim.o.columns / 2)
    local lines = {}
    table.insert(lines, HEADER)
    table.insert(lines, " " .. string.rep("─", panel_width - 2))
    for _, id in ipairs(favorites) do
        table.insert(lines, "  " .. id)
    end
    return lines
end

-- Returns the 1-based line number in the buffer for favorites[i].
-- Header = line 1, separator = line 2, favorites start at line 3.
local function fav_line(i)
    return i + 2
end

-- Returns the favorites index for the cursor's current line, or nil.
local function line_to_fav_index(lnum)
    local i = lnum - 2
    if i < 1 then return nil end
    return i
end

function M.open_picker()
    local ai = require("ai")
    local favorites = ai.config.favorites

    if not favorites or #favorites == 0 then
        require("panel").open({ "  No saved models. Use :AddModel <id> to add one." }, { wrap = true })
        return
    end

    local lines = build_lines(favorites)
    local buf = require("panel").open(lines, { wrap = false })

    -- Make buffer navigable but not editable
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

    -- Position cursor on the currently active model if it's in the list
    local current = ai.config.model
    local start_line = fav_line(1)
    for i, id in ipairs(favorites) do
        if id == current then
            start_line = fav_line(i)
            break
        end
    end
    vim.api.nvim_win_set_cursor(0, { start_line, 0 })

    -- <Enter>: select model under cursor
    vim.keymap.set("n", "<CR>", function()
        local lnum = vim.api.nvim_win_get_cursor(0)[1]
        local idx = line_to_fav_index(lnum)
        if not idx or idx > #favorites then return end
        local chosen = favorites[idx]
        ai.config.model = chosen
        ai.save_config()
        vim.cmd("close")
        print("AI model: " .. chosen)
    end, { buffer = buf, noremap = true, silent = true })
end

return M
```

- [ ] **Step 2: Expose `save_config` from `ai.lua`**

`models.lua` calls `require("ai").save_config()`. Add this public wrapper to `ai.lua`, just before `return M` at the end of the file:

```lua
function M.save_config()
    save_ai_config()
end
```

- [ ] **Step 3: Verify picker opens**

Restart Neovim. First add a model if not already done:
```
:AddModel anthropic/claude-sonnet-4.6
:AddModel openai/gpt-4o
```

Then open the picker:
```
:lua require("models").open_picker()
```

Expected: right-side split opens, lists both models, cursor on the active one.
Press `j`/`k` — cursor moves. Press `<Enter>` — panel closes, active model changes.
Verify with:
```
:lua print(require("ai").config.model)
```

- [ ] **Step 4: Verify empty-state**

In a fresh Neovim session with no favorites (or temporarily empty the array):
```
:lua require("ai").config.favorites = {}
:lua require("models").open_picker()
```
Expected: panel shows `"  No saved models. Use :AddModel <id> to add one."`

- [ ] **Step 5: Commit**

```bash
git add lua/models.lua lua/ai.lua
git commit -m "feat(models): add model picker panel (models.lua)"
```

---

### Task 4: Wire `<leader>ac` keymap

**Files:**
- Modify: `lua/ai.lua` (after the `<leader>ah` keymap, around line 566)

- [ ] **Step 1: Add `<leader>ac` keymap after `<leader>ah`**

Insert after the `<leader>ah` block:

```lua
vim.keymap.set("n", "<leader>ac", function()
    require("models").open_picker()
end, { noremap = true, silent = true, desc = "AI: pick model from favorites" })
```

- [ ] **Step 2: Verify keymap works end-to-end**

Restart Neovim. Press `<leader>ac`.
Expected: picker panel opens.
Navigate with `j`/`k`, press `<Enter>` on a model.
Expected: panel closes, statusline updates to show new model name.

- [ ] **Step 3: Commit**

```bash
git add lua/ai.lua
git commit -m "feat(models): wire <leader>ac to model picker"
```
