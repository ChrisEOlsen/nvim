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
  -- The Theme: One Dark (Matches Codex App)
  {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("onedark").setup({
        style = "dark", -- Default OneDark style
        colors = {
          bg0 = "#0d1117", -- Codex Code Field Background
          fg = "#d4d4d8",  -- Zinc 300 (Codex Text)
        },
        highlights = {
            Normal = { bg = "#0d1117", fg = "#d4d4d8" },
            NormalNC = { bg = "#0d1117", fg = "#d4d4d8" },
            LineNr = { bg = "#0d1117", fg = "#52525b" }, -- Zinc 600 for line numbers
            CursorLine = { bg = "#18181b" }, -- Zinc 900 for cursor line
            CursorLineNr = { fg = "#ea580c", fmt = "bold" }, -- Orange 600 for active line nr
        }
      })
      require("onedark").load()
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

-- 4. THEME SETTINGS (Simplified)
vim.opt.termguicolors = true

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

-- 5. LSP & CMP SETUP
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
