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
