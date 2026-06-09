-- ==========================================================================
-- THE "SYSTEMS ENGINEER" MONK CONFIG (SIMPLIFIED & FIXED)
-- ==========================================================================

-- Set <space> as the leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- 1. BOOTSTRAP PACKAGE MANAGER (Lazy.nvim)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- 2. PLUGINS
-- Enable default Neovim syntax highlighting
vim.cmd("syntax on")

require("lazy").setup({
  -- The Brain: Connects Neovim to 'clangd'
  {
    "neovim/nvim-lspconfig",
    tag = "v1.0.0",
  },

  -- The Explorer: File Tree
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        filters = { dotfiles = true },
        view = {
          width = 40,
          relativenumber = true,
        },
        renderer = {
          indent_markers = { enable = true },
          highlight_git = true,
        },
        update_focused_file = {
          enable = true,
          update_cwd = true,
        },
        actions = {
          open_file = {
            quit_on_open = false,
            resize_window = false,
          },
        },
        git = { enable = true, ignore = true },
      })
      -- Map T to open in new tab
      vim.api.nvim_create_autocmd("BufWinEnter", {
        pattern = "NvimTree_*",
        callback = function(args)
          vim.keymap.set("n", "T", function()
            local node = require("nvim-tree.api").tree.get_node_under_cursor()
            if node then
              vim.cmd("tabe " .. node.absolute_path)
            end
          end, { buffer = args.buf, desc = "Open in new tab" })
        end,
      })
      vim.keymap.set("n", "<leader>ee", require("nvim-tree.api").tree.toggle, { desc = "Toggle file explorer" })
      vim.keymap.set("n", "<leader>w", function()
        local buf_name = vim.api.nvim_buf_get_name(0)
        local is_tree = buf_name:find("NvimTree")
        local current_tab = vim.api.nvim_get_current_tabpage()
        local wins_in_tab = vim.tbl_filter(
          function(w) return vim.api.nvim_win_get_tabpage(w) == current_tab end,
          vim.api.nvim_list_wins()
        )
        if is_tree then
          -- Focus first non-tree window in current tab
          for _, win in ipairs(wins_in_tab) do
            if not vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)):find("NvimTree") then
              vim.api.nvim_set_current_win(win)
              return
            end
          end
        else
          -- Focus nvim-tree window in current tab
          for _, win in ipairs(wins_in_tab) do
            if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)):find("NvimTree") then
              vim.api.nvim_set_current_win(win)
              return
            end
          end
        end
      end, { desc = "Toggle focus: nvim-tree / code" })
    end
  },

  -- The Eyes: Fuzzy Finder (Fastest)
  {
    "ibhagwan/fzf-lua",
    dependencies = {
        { "junegunn/fzf", build = "./install --bin" },
    },
    config = function()
      local fzf = require("fzf-lua")
      fzf.setup({ "fzf-native" })
      vim.keymap.set("n", "<leader>ff", fzf.files, { desc = "Fzf Find Files" })
      vim.keymap.set("n", "<leader>fg", fzf.live_grep, { desc = "Fzf Live Grep" })
      vim.keymap.set("n", "<leader>fb", fzf.buffers, { desc = "Fzf Buffers" })
    end
  },

  -- The Hands: Autocompletion
  {
    "hrsh7th/nvim-cmp",
    dependencies = { "hrsh7th/cmp-nvim-lsp", "hrsh7th/cmp-buffer" },
  },
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = true
  },
  {
    "folke/zen-mode.nvim",
    opts = {
        on_close = function()
            vim.opt.number = true
            vim.opt.relativenumber = true
        end
    }
  },

  -- The History: Git integration
  {
    "tpope/vim-fugitive",
    config = function()
        vim.keymap.set("n", "<leader>gs", vim.cmd.Git, { desc = "Git Status" })
        vim.keymap.set("n", "<leader>gd", ":Gdiffsplit<CR>", { desc = "Git Diff Split" })
    end
  },

  -- Theme
  {
    "sainnhe/everforest",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd("colorscheme everforest")
    end
  },
})

-- 3. CORE SETTINGS
vim.opt.termguicolors = true  -- Enable true color support
vim.opt.number = true         -- Show line numbers
vim.opt.relativenumber = true -- Relative line numbers
vim.opt.signcolumn = "yes"    -- Keep space for error icons
vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20" -- Standard cursor
vim.opt.cursorline = true     -- Highlight the line the cursor is on
vim.opt.fillchars:append({ eob = " " }) -- Hide end-of-buffer tildes

-- Clear search highlights on <Esc>
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- INDENTATION (4 Spaces)
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.softtabstop = 4

-- 4. REMOTE CLIPBOARD (OSC 52)
vim.opt.clipboard = "unnamedplus"
local function paste() 
  return { vim.fn.split(vim.fn.getreg(''), '\n'), vim.fn.getregtype('') } 
end
vim.g.clipboard = {
  name = 'OSC 52',
  copy = {
    ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
    ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
  },
  paste = { ['+'] = paste, ['*'] = paste },
}

-- 7. SMART QUOTES
local function smart_quote(is_inner)
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1
    local quotes = { '"', "'", "`" }
    local nearest_q = nil
    local min_dist = 10000
    for _, q in ipairs(quotes) do
        local start_idx = line:find(q, col)
        if start_idx and (start_idx - col) < min_dist then
            min_dist = start_idx - col
            nearest_q = q
        end
    end
    if nearest_q then return (is_inner and "i" or "a") .. nearest_q else return "" end
end
vim.keymap.set({ "x", "o" }, "iq", function() return smart_quote(true) end, { expr = true })
vim.keymap.set({ "x", "o" }, "aq", function() return smart_quote(false) end, { expr = true })

-- 8. LSP & CMP SETUP
local lspconfig = require('lspconfig')

-- Configure Diagnostic Signs to use Line Highlights
local signs = { Error = "E", Warn = "W", Hint = "H", Info = "I" }
for type, icon in pairs(signs) do
    local hl = "DiagnosticSign" .. type
    local line_hl = "DiagnosticLine" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, linehl = line_hl, numhl = "" })
end

-- Also ensure diagnostics are enabled with virtual text
vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})

lspconfig.clangd.setup({
  cmd = { "clangd", "--background-index" },
  on_attach = function(client, bufnr)
    local opts = { buffer = bufnr, noremap = true, silent = true }
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, opts)
    vim.keymap.set('n', '<leader>f', vim.lsp.buf.format, opts)
  end,
})

local cmp = require('cmp')
cmp.setup({
  mapping = cmp.mapping.preset.insert({
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<CR>'] = cmp.mapping.confirm({ select = true }),
  }),
  sources = cmp.config.sources({ { name = 'nvim_lsp' }, { name = 'buffer' } }),
})

-- Zen Mode
vim.keymap.set("n", "<leader>z", "<cmd>ZenMode<cr>", { noremap = true, silent = true })

-- 9. CUSTOM COMMANDS
vim.api.nvim_create_user_command('CommentBox', function(opts)
    local args = opts.args
    local first_space = string.find(args, " ")
    local func_name = first_space and string.sub(args, 1, first_space - 1) or args
    local desc = first_space and string.sub(args, first_space + 1) or ""

    local max_width = 75
    local lines = {}
    -- Top border: "/" + "*" repeated to match the full width
    table.insert(lines, "/" .. string.rep("*", max_width + 1))

    local first_line_prefix = " * " .. func_name .. ": "
    local indent = string.rep(" ", #first_line_prefix)
    
    local current_line = first_line_prefix
    for word in desc:gmatch("%S+") do
        if #current_line + #word + 1 > max_width then
            table.insert(lines, current_line .. string.rep(" ", max_width - #current_line) .. " *")
            current_line = " * " .. indent:sub(4) .. word
        else
            current_line = current_line .. (#current_line == #first_line_prefix and "" or " ") .. word
        end
    end
    table.insert(lines, current_line .. string.rep(" ", max_width - #current_line) .. " *")
    -- Bottom border: " " + "*" repeated + "/"
    table.insert(lines, " " .. string.rep("*", max_width) .. "/")

    local row = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(0, row - 1, row - 1, false, lines)
end, { nargs = "+", desc = "K.N. King style comment box" })

vim.api.nvim_create_user_command('MainArgs', function()
    local ext = vim.fn.expand('%:e')
    local lines = {}
    if ext == 'cpp' or ext == 'cc' or ext == 'cxx' then
        lines = {
            "#include <iostream>",
            "#include <fstream>",
            "",
            "int main(int argc, char *argv[])",
            "{",
            "    return 0;",
            "}"
        }
    else
        lines = {
            "#include <stdio.h>",
            "#include <stdlib.h>",
            "",
            "int main(int argc, char *argv[])",
            "{",
            "    return 0;",
            "}"
        }
    end
    local row = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(0, row - 1, row - 1, false, lines)
end, { desc = "Insert Allman style main with arguments (C/C++)" })

vim.api.nvim_create_user_command('MainVoid', function()
    local ext = vim.fn.expand('%:e')
    local lines = {}
    if ext == 'cpp' or ext == 'cc' or ext == 'cxx' then
        lines = {
            "#include <iostream>",
            "",
            "int main()",
            "{",
            "    return 0;",
            "}"
        }
    else
        lines = {
            "#include <stdio.h>",
            "#include <stdlib.h>",
            "",
            "int main(void)",
            "{",
            "    return 0;",
            "}"
        }
    end
    local row = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(0, row - 1, row - 1, false, lines)
end, { desc = "Insert Allman style main void (C/C++)" })

vim.api.nvim_create_user_command('AddProto', function(opts)
    local proto = opts.args
    if proto == "" then
        print("Usage: :AddProto <function_signature>")
        return
    end

    -- Append body to end
    local total_lines = vim.api.nvim_buf_line_count(0)
    local body = {
        "",
        proto,
        "{",
        "}"
    }
    vim.api.nvim_buf_set_lines(0, total_lines, total_lines, false, body)

    -- Insert prototype
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local main_line_idx = nil
    
    for i, line in ipairs(lines) do
        if line:match("^int%s+main") then
            main_line_idx = i - 1 -- 0-based
            break
        end
    end

    if main_line_idx then
        vim.api.nvim_buf_set_lines(0, main_line_idx, main_line_idx, false, { proto .. ";", "" })
    else
        -- Fallback: after last include or top
        local insert_idx = 0
        for i, line in ipairs(lines) do
            if line:match("^#include") then
                insert_idx = i
            end
        end
        vim.api.nvim_buf_set_lines(0, insert_idx, insert_idx, false, { "", proto .. ";" })
    end
end, { nargs = "+", desc = "Add function prototype and body" })

local function compile_file(extra_flags)
    local file = vim.fn.expand('%')
    local file_no_ext = vim.fn.expand('%:r')
    local ext = vim.fn.expand('%:e')
    local compiler = ""

    if ext == 'c' then
        compiler = "gcc"
    elseif ext == 'cpp' or ext == 'cc' or ext == 'cxx' then
        compiler = "g++"
    else
        print("Not a C/C++ file")
        return
    end

    local flags = extra_flags or ""
    local cmd = string.format("%s %s -o %s %s", compiler, flags, file_no_ext, file)
    print("Compiling: " .. cmd)
    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        print("Compilation Error:\n" .. output)
    else
        print("Compilation Successful!")
    end
end

vim.api.nvim_create_user_command('Compile',      function() compile_file()           end, { desc = "Compile current C/C++ file" })
vim.api.nvim_create_user_command('CompileO2',    function() compile_file("-O2")      end, { desc = "Compile with -O2 optimization" })
vim.api.nvim_create_user_command('CompileO3',    function() compile_file("-O3")      end, { desc = "Compile with -O3 optimization" })
vim.api.nvim_create_user_command('CompileDebug', function() compile_file("-Og -g")   end, { desc = "Compile with debug symbols (-Og -g)" })

vim.keymap.set("n", "<leader>cc", "<cmd>Compile<CR>",      { noremap = true, silent = true, desc = "Compile current file" })
vim.keymap.set("n", "<leader>c2", "<cmd>CompileO2<CR>",    { noremap = true, silent = true, desc = "Compile with -O2" })
vim.keymap.set("n", "<leader>c3", "<cmd>CompileO3<CR>",    { noremap = true, silent = true, desc = "Compile with -O3" })
vim.keymap.set("n", "<leader>cd", "<cmd>CompileDebug<CR>", { noremap = true, silent = true, desc = "Compile with debug symbols" })
vim.keymap.set("n", "<leader>;",  "A;<Esc>",               { noremap = true, silent = true, desc = "Append ; to line end" })

-- 10a1. SAVED COMPILE COMMAND (per-directory, persisted)
local _compile_cmds_file = vim.fn.stdpath("data") .. "/compile_cmds.json"

local function _load_compile_cmds()
    local f = io.open(_compile_cmds_file, "r")
    if not f then return {} end
    local content = f:read("*a"); f:close()
    local ok, data = pcall(vim.fn.json_decode, content)
    if ok and type(data) == "table" then return data end
    return {}
end

local function _save_compile_cmds(data)
    local json = vim.fn.json_encode(data)
    local f = io.open(_compile_cmds_file, "w")
    if f then f:write(json); f:close() end
end

local function _get_dir_key()
    local dir = vim.fn.expand('%:p:h')
    if dir == "" then
        dir = vim.fn.getcwd()
    end
    return dir
end

vim.api.nvim_create_user_command('SaveCompile', function(opts)
    local cmd = opts.args
    if cmd == "" then
        print("Usage: :SaveCompile <command>")
        print("Example: :SaveCompile gcc -O2 -o %< -Iinclude %")
        return
    end
    local dir_key = _get_dir_key()
    local cmds = _load_compile_cmds()
    cmds[dir_key] = cmd
    _save_compile_cmds(cmds)
    print(string.format('Saved compile command for "%s"', dir_key))
    print("  Command: " .. cmd)
    print("  Run with :QuickCompile or <leader>sc")
end, { nargs = "+", desc = "Save a compile command for the current directory" })

-- 10a2. SAVED RUN COMMAND (per-directory, persisted)
local _run_cmds_file = vim.fn.stdpath("data") .. "/run_cmds.json"

local function _load_run_cmds()
    local f = io.open(_run_cmds_file, "r")
    if not f then return {} end
    local content = f:read("*a"); f:close()
    local ok, data = pcall(vim.fn.json_decode, content)
    if ok and type(data) == "table" then return data end
    return {}
end

local function _save_run_cmds(data)
    local json = vim.fn.json_encode(data)
    local f = io.open(_run_cmds_file, "w")
    if f then f:write(json); f:close() end
end

vim.api.nvim_create_user_command('SaveRun', function(opts)
    local cmd = opts.args
    if cmd == "" then
        print("Usage: :SaveRun <command>")
        print("Example: :SaveRun ./%<")
        return
    end
    local dir_key = _get_dir_key()
    local cmds = _load_run_cmds()
    cmds[dir_key] = cmd
    _save_run_cmds(cmds)
    print(string.format('Saved run command for "%s"', dir_key))
    print("  Command: " .. cmd)
    print("  Run with :QuickRun or <leader>sr")
end, { nargs = "+", desc = "Save a run command for the current directory" })

vim.api.nvim_create_user_command('QuickRun', function()
    local dir_key = _get_dir_key()
    local cmds = _load_run_cmds()
    local cmd = cmds[dir_key]
    if not cmd then
        print(string.format('No saved run command for "%s"', dir_key))
        print("Use :SaveRun <command> to save one first.")
        return
    end
    local file = vim.fn.expand('%:p')
    local cmd_expanded = cmd:gsub('%%', file)
    print("Running: " .. cmd_expanded)
    local output = vim.fn.system(cmd_expanded)
    if vim.v.shell_error ~= 0 then
        print("Run Error:\n" .. output)
    else
        print("Run Successful!")
    end
end, { desc = "Run the saved run command for the current directory" })

vim.api.nvim_create_user_command('QuickCompile', function()
    local dir_key = _get_dir_key()
    local cmds = _load_compile_cmds()
    local cmd = cmds[dir_key]
    if not cmd then
        print(string.format('No saved compile command for "%s"', dir_key))
        print("Use :SaveCompile <command> to save one first.")
        return
    end
    local file = vim.fn.expand('%:p')
    local cmd_expanded = cmd:gsub('%%', file)
    print("Compiling: " .. cmd_expanded)
    local output = vim.fn.system(cmd_expanded)
    if vim.v.shell_error ~= 0 then
        print("Compilation Error:\n" .. output)
    else
        print("Compilation Successful!")
    end
end, { desc = "Run the saved compile command for the current directory" })

vim.keymap.set("n", "<leader>sc", "<cmd>QuickCompile<CR>", { noremap = true, silent = true, desc = "Quick compile (saved command)" })
vim.keymap.set("n", "<leader>sr", "<cmd>QuickRun<CR>",    { noremap = true, silent = true, desc = "Quick run (saved command)" })

vim.api.nvim_create_user_command('MyCommands', function()
    local cmds = { "MainArgs", "MainVoid", "AddProto", "CommentBox", "Compile", "SaveCompile", "QuickCompile", "SaveRun", "QuickRun", "MyCommands", "Autogen", "Explain", "Aiconfig", "AddShortcut", "ClearShortcuts", "ListShortcuts" }
    print("Custom Commands: " .. table.concat(cmds, ", "))
end, { desc = "List custom commands defined in init.lua" })

-- 10b. TEMPORARY SHORTCUTS (<leader>q1-q6)
local _shortcuts = {}       -- [slot] = text string
local _shortcut_count = 0   -- number of active shortcuts
local _shortcuts_file = vim.fn.stdpath("data") .. "/shortcuts_state.json"

local function _save_shortcuts()
    local json = vim.fn.json_encode(_shortcuts)
    local f = io.open(_shortcuts_file, "w")
    if f then f:write(json); f:close() end
end

local function _bind_shortcut(slot, text)
    vim.keymap.set("n", "<leader>s" .. slot, function()
        local row, col = unpack(vim.api.nvim_win_get_cursor(0))
        vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { text })
        vim.api.nvim_win_set_cursor(0, { row, col + #text })
    end, { noremap = true, silent = true, desc = "Shortcut s" .. slot .. ": " .. text })
end

local function _unbind_shortcut(slot)
    pcall(vim.keymap.del, "n", "<leader>s" .. slot)
end

local function _load_shortcuts()
    local f = io.open(_shortcuts_file, "r")
    if not f then return end
    local content = f:read("*a"); f:close()
    local ok, data = pcall(vim.fn.json_decode, content)
    if ok and type(data) == "table" then
        -- json_decode may return string keys ("1","2"...) — normalise to integers
        _shortcuts = {}
        for k, v in pairs(data) do
            local idx = tonumber(k)
            if idx then _shortcuts[idx] = v end
        end
        for i = 1, 6 do
            if _shortcuts[i] then
                _shortcut_count = i
                _bind_shortcut(i, _shortcuts[i])   -- re-create the keymap
            end
        end
    end
end

vim.api.nvim_create_user_command('AddShortcut', function(opts)
    local text = opts.args
    if text == "" then
        print("Usage: :AddShortcut <text>")
        return
    end

    if _shortcut_count < 6 then
        _shortcut_count = _shortcut_count + 1
        _shortcuts[_shortcut_count] = text
        _bind_shortcut(_shortcut_count, text)
        _save_shortcuts()
        print(string.format('"%s" added to <leader>s%d', text, _shortcut_count))
    else
        -- All 6 slots full — offer replacement via ui.select
        local choices = {}
        for i = 1, 6 do
            table.insert(choices, string.format("q%d: %s", i, _shortcuts[i]))
        end
        table.insert(choices, "Cancel")

        vim.ui.select(choices, {
            prompt = "All 6 slots full. Replace which shortcut? (or Cancel)",
        }, function(choice, idx)
            if not choice or choice == "Cancel" then
                print("AddShortcut cancelled.")
                return
            end
            _shortcuts[idx] = text
            _bind_shortcut(idx, text)
            _save_shortcuts()
            print(string.format('"%s" added to <leader>s%d', text, idx))
        end)
    end
end, { nargs = "+", desc = "Add a temporary shortcut to <leader>q1-q6" })

vim.api.nvim_create_user_command('ClearShortcuts', function()
    for i = 1, 6 do
        if _shortcuts[i] then
            _unbind_shortcut(i)
            _shortcuts[i] = nil
        end
    end
    _shortcut_count = 0
    _save_shortcuts()
    print("All temporary shortcuts cleared.")
end, { desc = "Clear all temporary shortcuts (<leader>q1-q6)" })

local function _list_shortcuts()
    local lines = {}
    if _shortcut_count == 0 then
        table.insert(lines, "  No temporary shortcuts set.")
    else
        for i = 1, 6 do
            if _shortcuts[i] then
                table.insert(lines, string.format("  <leader>s%d  →  %s", i, _shortcuts[i]))
            end
        end
    end

    -- Width: wide enough for the longest line (no wrapping), capped at screen
    local max_len = 0
    for _, line in ipairs(lines) do
        if #line > max_len then max_len = #line end
    end
    local width = math.min(max_len + 2, vim.o.columns - 4)
    local height = #lines + 2  -- +2 for top/bottom border breathing room

    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        row = row, col = col,
        width = width, height = height,
        border = "rounded",
        title = " shortcuts ",
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
    vim.api.nvim_set_option_value("cursorline",     false, { win = win })

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

    vim.api.nvim_buf_set_keymap(buf, "n", "q",     "<cmd>close<CR>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<cmd>close<CR>", { noremap = true, silent = true })
end

vim.api.nvim_create_user_command('ListShortcuts', _list_shortcuts, { desc = "List all active temporary shortcuts" })
vim.keymap.set("n", "<leader>sd", _list_shortcuts, { noremap = true, silent = false, desc = "List temporary shortcuts" })

_load_shortcuts()

-- Fix Tab in insert mode for C/C++: prevent cindent from re-indenting on Tab.
-- By default, cinkeys includes "0<Tab>" which makes Tab re-indent the line
-- using cindent rules instead of just inserting spaces.
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "c", "cpp", "cc", "cxx" },
    callback = function()
        vim.opt_local.cinkeys:remove("0<Tab>")
    end,
})

-- DEBUG (temporary)
vim.api.nvim_create_user_command('DebugIndent', function()
    local lines = {
        string.format("tabstop=%d", vim.bo.tabstop),
        string.format("softtabstop=%d", vim.bo.softtabstop),
        string.format("shiftwidth=%d", vim.bo.shiftwidth),
        string.format("expandtab=%s", tostring(vim.bo.expandtab)),
        string.format("cindent=%s", tostring(vim.bo.cindent)),
        string.format("smartindent=%s", tostring(vim.bo.smartindent)),
        string.format("autoindent=%s", tostring(vim.bo.autoindent)),
        string.format("indentexpr=%s", vim.bo.indentexpr == "" and "(none)" or vim.bo.indentexpr),
        string.format("filetype=%s", vim.bo.filetype),
        "--- insert-mode <Tab> maps ---",
    }
    -- Check for any insert-mode Tab remaps
    local maps = vim.api.nvim_buf_get_keymap(0, "i")
    local found = false
    for _, m in ipairs(maps) do
        if m.lhs == "<Tab>" or m.lhs == "\t" then
            table.insert(lines, string.format("  buf: lhs=%s rhs=%s script=%s sid=%s desc=%s",
                m.lhs, m.rhs or "[lua]", tostring(m.script), tostring(m.sid), tostring(m.desc)))
            found = true
        end
    end
    local gmaps = vim.api.nvim_get_keymap("i")
    for _, m in ipairs(gmaps) do
        if m.lhs == "<Tab>" or m.lhs == "\t" then
            table.insert(lines, string.format("  global: lhs=%s rhs=%s script=%s sid=%s desc=%s",
                m.lhs, m.rhs or "[lua]", tostring(m.script), tostring(m.sid), tostring(m.desc)))
            found = true
        end
    end
    if not found then table.insert(lines, "  (none found)") end
    print(table.concat(lines, "\n"))
end, { desc = "Dump indent debug info" })

-- 11. KEYMAP REFERENCE
local function show_keymaps()
    local sections = {
        { title = "Navigation / Search", maps = {
            { keys = "<leader>ee",      mode = "n",   desc = "Toggle file explorer" },
            { keys = "<leader>ff",      mode = "n",   desc = "Find files (fzf)" },
            { keys = "<leader>fg",      mode = "n",   desc = "Live grep (fzf)" },
            { keys = "<leader>fb",      mode = "n",   desc = "List buffers (fzf)" },
        }},
        { title = "File Explorer  (nvim-tree buffer)", maps = {
            { keys = "o",               mode = "n",   desc = "Open file" },
            { keys = "Enter",           mode = "n",   desc = "Open file" },
            { keys = "h",               mode = "n",   desc = "Open parent directory" },
            { keys = "l",               mode = "n",   desc = "Open/expand directory" },
            { keys = "a",               mode = "n",   desc = "Create file or directory" },
            { keys = "d",               mode = "n",   desc = "Create directory (add / at end)" },
            { keys = "D",               mode = "n",   desc = "Delete node" },
            { keys = "r",               mode = "n",   desc = "Rename node" },
            { keys = "x",               mode = "n",   desc = "Cut node" },
            { keys = "c",               mode = "n",   desc = "Copy node" },
            { keys = "p",               mode = "n",   desc = "Paste node" },
            { keys = "i",               mode = "n",   desc = "Toggle hidden files" },
            { keys = "[c",              mode = "n",   desc = "Prev git item" },
            { keys = "]c",              mode = "n",   desc = "Next git item" },
            { keys = "<leader>ee",      mode = "n",   desc = "Toggle explorer" },
            { keys = "P",               mode = "n",   desc = "Toggle cwd" },
        }},
        { title = "Git", maps = {
            { keys = "<leader>gs",      mode = "n",   desc = "Git status" },
            { keys = "<leader>gd",      mode = "n",   desc = "Git diff split" },
        }},
        { title = "LSP  (active in C/C++ buffers)", maps = {
            { keys = "gd",              mode = "n",   desc = "Go to definition" },
            { keys = "K",               mode = "n",   desc = "Hover documentation" },
            { keys = "<leader>e",       mode = "n",   desc = "Open diagnostics float" },
            { keys = "<leader>f",       mode = "n",   desc = "Format buffer" },
        }},
        { title = "Compile  (C/C++)", maps = {
            { keys = "<leader>cc",      mode = "n",   desc = "Compile" },
            { keys = "<leader>c2",      mode = "n",   desc = "Compile with -O2" },
            { keys = "<leader>c3",      mode = "n",   desc = "Compile with -O3" },
            { keys = "<leader>cd",      mode = "n",   desc = "Compile with -Og -g (debug)" },
            { keys = "<leader>sc",      mode = "n",   desc = "Quick compile (saved command)" },
            { keys = ":SaveCompile <c>", mode = "cmd", desc = "Save compile command per directory" },
            { keys = ":QuickCompile",   mode = "cmd", desc = "Run saved compile command" },
            { keys = "<leader>sr",      mode = "n",   desc = "Quick run (saved command)" },
            { keys = ":SaveRun <c>",    mode = "cmd", desc = "Save run command per directory" },
            { keys = ":QuickRun",       mode = "cmd", desc = "Run saved run command" },
            { keys = "<leader>;",       mode = "n",   desc = "Append ; to line end" },
        }},
        { title = "C/C++ Scaffolding", maps = {
            { keys = ":MainArgs",   mode = "cmd", desc = "Insert main() with argc/argv" },
            { keys = ":MainVoid",   mode = "cmd", desc = "Insert main() with no args" },
            { keys = ":AddProto",   mode = "cmd", desc = "Add function prototype" },
            { keys = ":CommentBox", mode = "cmd", desc = "Insert decorated comment box" },
        }},
        { title = "AI", maps = {
            { keys = "<leader>ag",                    mode = "n",   desc = "AI: generate code at cursor" },
            { keys = "<leader>ai",                    mode = "v",   desc = "AI: explain / ask about selection" },
            { keys = "<leader>ac",                    mode = "n",   desc = "AI: pick model from favorites" },
            { keys = "<leader>ah",                    mode = "n",   desc = "AI: history for current file" },
            { keys = ":Aiconfig <model> [provider]",  mode = "cmd", desc = "Set AI model and optional provider" },
            { keys = ":AddModel <model> [provider]", mode = "cmd", desc = "Add model+provider pair to favorites" },
        }},
        { title = "Completion  (insert mode)", maps = {
            { keys = "<C-Space>",       mode = "i",   desc = "Trigger completion" },
            { keys = "<CR>",            mode = "i",   desc = "Confirm completion" },
        }},
        { title = "Text Objects", maps = {
            { keys = "iq / aq",         mode = "x/o", desc = "Inner / around nearest quote" },
        }},
        { title = "Shortcuts", maps = {
            { keys = "<leader>s1-s6",       mode = "n",   desc = "Insert saved shortcut text" },
            { keys = "<leader>sd",          mode = "n",   desc = "List active shortcuts" },
            { keys = ":AddShortcut <text>", mode = "cmd", desc = "Save text as a shortcut slot" },
            { keys = ":ClearShortcuts",     mode = "cmd", desc = "Clear all shortcut slots" },
        }},
        { title = "Misc", maps = {
            { keys = "<leader>z",              mode = "n",   desc = "Zen mode" },
            { keys = "<Esc>",                  mode = "n",   desc = "Clear search highlight" },
            { keys = "<leader>?",              mode = "n",   desc = "Show this keymap reference" },
            { keys = ":SyntaxHighlight <0|1>", mode = "cmd", desc = "Syntax highlight: 1=full colors, 0=monk mode" },
            { keys = ":MyCommands",            mode = "cmd", desc = "List all custom commands" },
        }},
    }

    local lines = {}
    local max_keys_len = 0
    for _, sec in ipairs(sections) do
        for _, m in ipairs(sec.maps) do
            if #m.keys > max_keys_len then max_keys_len = #m.keys end
        end
    end

    local key_col   = max_keys_len + 2

    for _, sec in ipairs(sections) do
        table.insert(lines, "")
        table.insert(lines, "  " .. sec.title)
        table.insert(lines, "  " .. string.rep("─", #sec.title))
        for _, m in ipairs(sec.maps) do
            local pad  = string.rep(" ", key_col - #m.keys)
            local mode = string.format("[%-3s]", m.mode)
            table.insert(lines, string.format("  %s%s%s  %s", m.keys, pad, mode, m.desc))
        end
    end
    table.insert(lines, "")

    require("panel").open(lines, { wrap = false })
end

vim.api.nvim_create_user_command("Keymaps", show_keymaps, { desc = "Show all custom keymaps" })
vim.keymap.set("n", "<leader>?", show_keymaps, { noremap = true, silent = true, desc = "Show keymap reference" })

-- 10. AI INTEGRATION
require("ai")
