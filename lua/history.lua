-- lua/history.lua
-- AI response history: persistence and panel navigation.

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

-- Navigation state (module-level, reset on each open_panel call)
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
