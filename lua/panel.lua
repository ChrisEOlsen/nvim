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

function M.open(lines, opts)
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
