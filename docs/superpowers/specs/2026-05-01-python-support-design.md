# Python LSP Support

**Date:** 2026-05-01
**Status:** Approved

## Goal

Add Python edit/navigation support to a Neovim config currently set up for C/C++. No run commands. No formatter. Just LSP: go-to-definition, hover, diagnostics, completion.

## Scope

- LSP: pyright via lspconfig (already installed)
- Venv: uv-style `.venv` detection
- No new plugins
- No Python-specific keymaps beyond the shared LSP set

## Design

### LSP Setup

Add `lspconfig.pyright.setup()` in section 8 of `init.lua`, alongside the existing `clangd` block. Use the identical `on_attach` function as clangd:

```lua
lspconfig.pyright.setup({
  on_attach = function(client, bufnr)
    local opts = { buffer = bufnr, noremap = true, silent = true }
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K',  vim.lsp.buf.hover, opts)
    vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, opts)
    vim.keymap.set('n', '<leader>f', vim.lsp.buf.format, opts)
  end,
  settings = {
    python = {
      venvPath = ".",
      venv = ".venv",
    },
  },
})
```

`venvPath = "."` + `venv = ".venv"` matches uv's default project layout. Pyright resolves the interpreter per-project root automatically.

### Keymap Reference

Update the LSP section title in `show_keymaps()`:

- Before: `"LSP  (active in C/C++ buffers)"`
- After: `"LSP  (active in C/C++ and Python buffers)"`

### External Dependency

`pyright` binary must be on PATH. Recommended install: `uv tool install pyright`.

## What Is Not Included

- No `:RunPython` command
- No formatter (ruff/black)
- No linter beyond pyright's built-in type checking
- No treesitter
- No virtual environment switcher UI
