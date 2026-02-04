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
require("lazy").setup({
  -- The Theme: GitHub Theme (Reliable, handles cursors well)
  {
    "projekt0n/github-nvim-theme",
    lazy = false,    -- Load immediately
    priority = 1000, -- Load before everything else
    config = function()
      require("github-theme").setup({
        -- Minimal config
        options = {
          compile_path = vim.fn.stdpath("cache") .. "/github-theme",
          compile_file_suffix = "_compiled",
          hide_end_of_buffer = true, -- Hide ~ at end of buffer
          terminal_colors = true,
          dim_inactive = false,
          styles = {
            comments = "italic",
            functions = "NONE",
            keywords = "NONE",
            variables = "NONE",
            conditionals = "NONE",
            constants = "NONE",
            numbers = "NONE",
            operators = "NONE",
            strings = "NONE",
            types = "NONE",
          },
        },
      })
      -- Default to Dark mode initially
      vim.cmd("colorscheme github_dark")
    end,
  },

  -- The Brain: Connects Neovim to 'clangd'
  {
    "neovim/nvim-lspconfig",
    tag = "v1.0.0",
  },

  -- The Eyes: Fuzzy Finder (Fastest)
  {
    "ibhagwan/fzf-lua",
    dependencies = {
        { "junegunn/fzf", build = "./install --bin" },
        "nvim-tree/nvim-web-devicons",
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
})

-- 3. CORE SETTINGS
vim.opt.termguicolors = true  -- Enable true color support
vim.opt.number = true         -- Show line numbers
vim.opt.relativenumber = true -- Relative line numbers
vim.opt.signcolumn = "yes"    -- Keep space for error icons
vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20" -- Standard cursor
vim.opt.cursorline = true     -- Highlight the line the cursor is on

-- Clear search highlights on <Esc>
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- INDENTATION (4 Spaces)
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.softtabstop = 4

-- 4. SIMPLISTIC THEME TOGGLE (Light/Dark)
vim.g.is_dark_mode = true -- Default to Dark

local function fix_cursor()
    -- Force the cursor to be visible by manually setting the highlight group
    if vim.g.is_dark_mode then
        -- DARK MODE: One Dark Background
        local bg_color = "#282c34"
        local fg_color = "#ffffff"

        vim.api.nvim_set_hl(0, "Normal", { bg = bg_color, fg = fg_color, force = true })
        vim.api.nvim_set_hl(0, "NormalNC", { bg = bg_color, fg = fg_color, force = true })
        vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = bg_color, fg = bg_color, force = true })
        vim.api.nvim_set_hl(0, "SignColumn", { bg = bg_color, force = true })
        vim.api.nvim_set_hl(0, "LineNr", { bg = bg_color, force = true })
        vim.api.nvim_set_hl(0, "ZenBg", { bg = bg_color, force = true })

        -- Cursor: White on Background
        vim.api.nvim_set_hl(0, "Cursor", { bg = "#ffffff", fg = bg_color, force = true })
        vim.api.nvim_set_hl(0, "TermCursor", { bg = "#ffffff", fg = bg_color, force = true })
        -- Line highlight: Slightly lighter than background
        vim.api.nvim_set_hl(0, "CursorLine", { bg = "#2c323c", force = true })
    else
        -- LIGHT MODE: Pure White
        local bg_color = "#ffffff"
        local fg_color = "#000000"

        vim.api.nvim_set_hl(0, "Normal", { bg = bg_color, fg = fg_color, force = true })
        vim.api.nvim_set_hl(0, "NormalNC", { bg = bg_color, fg = fg_color, force = true })
        vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = bg_color, fg = bg_color, force = true })
        vim.api.nvim_set_hl(0, "SignColumn", { bg = bg_color, force = true })
        vim.api.nvim_set_hl(0, "LineNr", { bg = bg_color, force = true })
        vim.api.nvim_set_hl(0, "ZenBg", { bg = bg_color, force = true })

        -- Cursor: Black on White
        vim.api.nvim_set_hl(0, "Cursor", { bg = "#000000", fg = "#ffffff", force = true })
        vim.api.nvim_set_hl(0, "TermCursor", { bg = "#000000", fg = "#ffffff", force = true })
        -- Line highlight: Subtle gray
        vim.api.nvim_set_hl(0, "CursorLine", { bg = "#f0f0f0", force = true })
    end
end

local function toggle_theme()
    if vim.g.is_dark_mode then
        vim.cmd("colorscheme github_light")
        vim.g.is_dark_mode = false
        print("Theme: Light")
    else
        vim.cmd("colorscheme github_dark")
        vim.g.is_dark_mode = true
        print("Theme: Dark")
    end
    fix_cursor() -- Apply cursor fix immediately after switching
end

vim.keymap.set("n", "<leader>tm", toggle_theme, { noremap = true, silent = true, desc = "Toggle Theme" })

-- 5. MONK MODE: PLAIN TEXT WITH COMMENTS
-- We MUST have 'syntax on' to detect comments, but we strip all other colors.
vim.api.nvim_create_autocmd({ "ColorScheme", "BufEnter" }, {
    pattern = "*",
    callback = function()
        vim.cmd("syntax on") -- Enable syntax so we know what is a comment

        -- 1. Reset all standard syntax groups to link to "Normal" (plain text)
        local syntax_groups = {
            "Constant", "Identifier", "Statement", "PreProc", "Type", "Special",
            "Underlined", "Error", "Todo", "String", "Function", "Conditional",
            "Repeat", "Operator", "Structure", "Boolean", "Number", "Float",
            "Label", "Keyword", "Exception", "Include", "Define", "Macro",
            "PreCondit", "StorageClass", "Typedef", "Tag", "SpecialChar",
            "Delimiter", "SpecialComment", "Debug"
        }

        for _, group in ipairs(syntax_groups) do
            vim.api.nvim_set_hl(0, group, { link = "Normal" })
        end

        -- 2. Force Comments to be a distinct grey
        vim.api.nvim_set_hl(0, "Comment", { fg = "#808080", italic = true, force = true })

        -- 3. Re-apply cursor/background fixes
        fix_cursor()
    end,
})

-- 6. REMOTE CLIPBOARD (OSC 52)
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
